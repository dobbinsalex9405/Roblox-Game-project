--!strict
-- Module 14: Feedback.
-- The in-game Feedback button (packages/core/client/FeedbackUi.luau) sends a
-- category, a rating and a short text. This module checks it, rate-limits it
-- per player, runs the text through Roblox's filter, tags it with everything
-- a bug fix needs (build, place version, device, session, the player's last
-- client errors and the game's own context) and writes the reports in
-- batches: at most one DataStore write per server per `interval` seconds.
--
-- Batches are stored under dated keys ("YYYYMMDD-HHMMSS-<server>-<n>"), so
-- the daily reader (tools/feedback) can list exactly one day with a key
-- prefix through Open Cloud. See ops/FEEDBACK.md for how reports become fixes.
--
-- Only the filtered text is ever stored: players may type names, numbers or
-- places, and Roblox's filter removes personal information. If the filter
-- cannot run, the report is refused (the player is told to try again), never
-- stored unfiltered.

local Log = require("./Log")
local Util = require("./Util")

export type Category = "bug" | "idea" | "other"
export type Platform = "touch" | "keyboard" | "gamepad" | "vr" | "unknown"

export type ClientInfo = {
	platform: Platform,
	screen: string, -- "1920x1080"
	fps: number, -- frames per second averaged over the last few seconds
}

-- What the player sent (already shape-checked by Net; checked again here).
export type Submission = {
	category: Category,
	text: string,
	rating: number, -- 1..5, or 0 for no rating
	client: ClientInfo,
}

-- What the server knows about the player at the moment they send.
export type PlayerInfo = {
	userId: number,
	accountAgeDays: number,
	locale: string,
	sessionSeconds: number,
	pingMs: number,
	position: string, -- "x,y,z" rounded, or "" when the character is not loaded
	context: { [string]: any }?, -- from the game's feedbackContext hook
}

export type RecentError = {
	signature: string,
	message: string,
	secondsAgo: number,
}

export type Report = {
	id: string,
	at: number,
	game: string,
	build: string,
	placeVersion: number,
	server: string,
	category: Category,
	rating: number,
	text: string,
	userId: number,
	accountAgeDays: number,
	locale: string,
	sessionSeconds: number,
	pingMs: number,
	position: string,
	platform: Platform,
	screen: string,
	fps: number,
	context: { [string]: string | number | boolean },
	recentErrors: { RecentError },
}

export type Batch = {
	schema: number,
	game: string,
	build: string,
	placeVersion: number,
	server: string,
	at: number,
	reports: { Report },
}

export type Options = {
	game: string,
	build: string,
	placeVersion: number,
	server: string, -- game.JobId ("" in Studio)
	-- Stores one batch under `key`; may yield; returns false if the write failed.
	write: (key: string, batch: Batch) -> boolean,
	-- Filters `text` written by `userId`; may yield. Returns (true, filtered) or
	-- (false, nil) when the filter could not run.
	filter: (userId: number, text: string) -> (boolean, string?),
	interval: number?, -- seconds between writes, default 60
	cooldown: number?, -- seconds between reports per player, default 60
	dailyLimit: number?, -- reports per player per UTC day on one server, default 10
	minLength: number?, -- characters, default 3
	maxLength: number?, -- characters, default 500
	maxPending: number?, -- reports held between writes, default 200
	errorsPerPlayer: number?, -- recent client errors attached to a report, default 5
	errorMaxAge: number?, -- seconds a client error stays "recent", default 600
}

export type Feedback = {
	submit: (self: Feedback, info: PlayerInfo, submission: Submission, now: number) -> (boolean, string),
	noteError: (self: Feedback, userId: number, signature: string, message: string, now: number) -> (),
	forget: (self: Feedback, userId: number) -> (),
	flush: (self: Feedback, now: number, force: boolean?) -> boolean,
	pending: (self: Feedback) -> number,
}

local SCHEMA_VERSION = 1
local DAY = 86400
local CONTEXT_MAX_KEYS = 12
local CONTEXT_MAX_STRING = 100
local CONTEXT_KEY_PATTERN = "^[%a][%w_]*$"
local ERROR_MESSAGE_MAX = 200

local log = Log.new("Feedback")

local Feedback = {}

-- Must list every member of the Category and Platform types above.
Feedback.CATEGORIES = table.freeze({ "bug", "idea", "other" }) :: { string }
Feedback.PLATFORMS = table.freeze({ "touch", "keyboard", "gamepad", "vr", "unknown" }) :: { string }

-- What players are told. Kept here so tests and the UI agree on the wording.
Feedback.MESSAGES = table.freeze({
	sent = "Thanks! Your feedback was sent. We read every report.",
	badCategory = "Pick Bug, Idea or Other first.",
	tooShort = "Please write a little more.",
	badText = "Your message has characters we can't send. Please retype it.",
	cooldown = "Thanks! Please wait a minute before sending more.",
	daily = "You've sent a lot of feedback today. Thank you! Try again tomorrow.",
	duplicate = "We already got that one. Thanks!",
	busy = "Your last report is still sending.",
	full = "Lots of feedback right now. Please try again in a minute.",
	filter = "We couldn't send that right now. Please try again in a minute.",
	empty = "Your message was removed by Roblox's text filter. Please reword it.",
})

local function utf8Length(text: string): number?
	return utf8.len(text)
end

-- Cuts `text` to at most `max` characters (not bytes), on a character boundary.
local function clipChars(text: string, max: number): string
	local length = utf8Length(text)
	if length == nil or length <= max then
		return text
	end
	local cut = utf8.offset(text, max + 1)
	return if cut then string.sub(text, 1, cut - 1) else text
end

-- Control characters become spaces (newlines are kept, at most two in a row),
-- runs of spaces collapse, and the ends are trimmed.
function Feedback.clean(text: string): string
	local cleaned = string.gsub(text, "\r\n?", "\n")
	cleaned = string.gsub(cleaned, "[\0-\9\11-\31\127]", " ")
	cleaned = string.gsub(cleaned, "[ \t]+", " ")
	cleaned = string.gsub(cleaned, " ?\n ?", "\n")
	cleaned = string.gsub(cleaned, "\n\n\n+", "\n\n")
	return string.match(cleaned, "^%s*(.-)%s*$") or ""
end

-- Keeps up to 12 simple values from the game's context hook: whole keys,
-- finite numbers, booleans and short strings. Everything else is dropped, so
-- a buggy hook can never make a batch unsavable.
function Feedback.sanitizeContext(context: any): { [string]: string | number | boolean }
	local out: { [string]: string | number | boolean } = {}
	if type(context) ~= "table" then
		return out
	end
	local keys = {}
	for key in context do
		if type(key) == "string" and #key <= 32 and string.match(key, CONTEXT_KEY_PATTERN) then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	local count = 0
	for _, key in keys do
		if count >= CONTEXT_MAX_KEYS then
			break
		end
		local value = context[key]
		local kept: (string | number | boolean)? = nil
		if type(value) == "number" then
			if value == value and value ~= math.huge and value ~= -math.huge then
				kept = value
			end
		elseif type(value) == "boolean" then
			kept = value
		elseif type(value) == "string" then
			kept = clipChars(Feedback.clean(value), CONTEXT_MAX_STRING)
		end
		if kept ~= nil then
			out[key] = kept
			count += 1
		end
	end
	return out
end

-- "YYYYMMDD-HHMMSS-<server>-<n>": sorts by time, lists by day with a prefix,
-- and stays under the 50-character DataStore key limit.
function Feedback.batchKey(at: number, server: string, sequence: number): string
	local short = string.sub(string.gsub(server, "[^%w]", ""), 1, 24)
	if short == "" then
		short = "studio"
	end
	return `{os.date("!%Y%m%d-%H%M%S", at)}-{short}-{sequence}`
end

-- The key prefix that lists every batch written on one UTC day.
function Feedback.dayPrefix(at: number): string
	return os.date("!%Y%m%d", at)
end

-- Form helpers, shared with the client so the form and the server agree.

Feedback.MAX_LENGTH = 500
Feedback.MIN_LENGTH = 3

Feedback.PLACEHOLDERS = table.freeze({
	bug = "What went wrong? What were you doing just before?",
	idea = "What would make the game more fun?",
	other = "Tell us anything!",
	none = "Pick Bug, Idea or Other above, then write here.",
})

-- Cuts text to `max` characters (not bytes) without splitting a character.
Feedback.clip = clipChars

function Feedback.platformFrom(
	flags: { touch: boolean, keyboard: boolean, gamepad: boolean, vr: boolean }
): Platform
	if flags.vr then
		return "vr"
	elseif flags.keyboard then
		return "keyboard"
	elseif flags.touch then
		return "touch"
	elseif flags.gamepad then
		return "gamepad"
	end
	return "unknown"
end

function Feedback.screenString(width: number, height: number): string
	return `{math.max(0, math.floor(width))}x{math.max(0, math.floor(height))}`
end

-- Why the Send button is off, or nil when it can send. The text doubles as the
-- button label.
function Feedback.sendBlocker(category: string?, text: string, sending: boolean, waitSeconds: number): string?
	if sending then
		return "Sending..."
	end
	if waitSeconds > 0 then
		return `Wait {math.ceil(waitSeconds)}s`
	end
	if category == nil or table.find(Feedback.CATEGORIES, category) == nil then
		return "Pick a type"
	end
	if (utf8Length(Feedback.clean(text)) or 0) < Feedback.MIN_LENGTH then
		return "Write a little more"
	end
	return nil
end

local function validSubmission(submission: any): boolean
	if type(submission) ~= "table" then
		return false
	end
	if type(submission.text) ~= "string" then
		return false
	end
	local rating = submission.rating
	if type(rating) ~= "number" or rating // 1 ~= rating or rating < 0 or rating > 5 then
		return false
	end
	local client = submission.client
	if type(client) ~= "table" then
		return false
	end
	return table.find(Feedback.PLATFORMS, client.platform) ~= nil
		and type(client.screen) == "string"
		and #client.screen <= 20
		and type(client.fps) == "number"
		and client.fps == client.fps
		and client.fps >= 0
		and client.fps <= 1000
end

type PlayerState = {
	lastAt: number,
	day: number,
	dayCount: number,
	lastText: string,
	inFlight: boolean,
}

function Feedback.new(options: Options): Feedback
	local interval = options.interval or 60
	local cooldown = options.cooldown or 60
	local dailyLimit = options.dailyLimit or 10
	local minLength = options.minLength or Feedback.MIN_LENGTH
	local maxLength = options.maxLength or Feedback.MAX_LENGTH
	local maxPending = options.maxPending or 200
	local errorsPerPlayer = options.errorsPerPlayer or 5
	local errorMaxAge = options.errorMaxAge or 600

	local players: { [number]: PlayerState } = {}
	local recentErrors: { [number]: { { signature: string, message: string, at: number } } } = {}
	local pendingReports: { Report } = {}
	local lastWriteAt = -math.huge
	local sequence = 0
	local reportCount = 0
	local writing = false

	local feedback = {}

	local function state(userId: number): PlayerState
		local s = players[userId]
		if s == nil then
			s = { lastAt = -math.huge, day = -1, dayCount = 0, lastText = "", inFlight = false }
			players[userId] = s
		end
		return s
	end

	function feedback.submit(
		_self: Feedback,
		info: PlayerInfo,
		submission: Submission,
		now: number
	): (boolean, string)
		if not validSubmission(submission) then
			return false, Feedback.MESSAGES.badText
		end
		if table.find(Feedback.CATEGORIES, submission.category) == nil then
			return false, Feedback.MESSAGES.badCategory
		end
		if utf8Length(submission.text) == nil then
			return false, Feedback.MESSAGES.badText
		end
		local text = clipChars(Feedback.clean(submission.text), maxLength)
		local length = utf8Length(text) or 0
		if length < minLength then
			return false, Feedback.MESSAGES.tooShort
		end

		local s = state(info.userId)
		if s.inFlight then
			return false, Feedback.MESSAGES.busy
		end
		local today = now // DAY
		if s.day ~= today then
			s.day = today
			s.dayCount = 0
		end
		if s.dayCount >= dailyLimit then
			return false, Feedback.MESSAGES.daily
		end
		if string.lower(text) == s.lastText then
			return false, Feedback.MESSAGES.duplicate
		end
		if now - s.lastAt < cooldown then
			return false, Feedback.MESSAGES.cooldown
		end
		if #pendingReports >= maxPending then
			return false, Feedback.MESSAGES.full
		end

		-- The filter yields; hold the player's slot so a second report cannot
		-- slip in meanwhile.
		s.inFlight = true
		local ok, passed, filtered = pcall(options.filter, info.userId, text)
		s.inFlight = false
		if not ok or not passed or type(filtered) ~= "string" then
			log:warn("text filter failed; report refused", { userId = info.userId, err = passed })
			return false, Feedback.MESSAGES.filter
		end
		-- A message the filter removed completely ("####") tells us nothing.
		if not string.find(filtered, "[%w\128-\255]") then
			return false, Feedback.MESSAGES.empty
		end
		if #pendingReports >= maxPending then
			return false, Feedback.MESSAGES.full
		end

		s.lastAt = now
		s.dayCount += 1
		s.lastText = string.lower(text)

		local errorsOut: { RecentError } = {}
		local list = recentErrors[info.userId]
		if list then
			for i = #list, 1, -1 do
				local entry = list[i]
				if now - entry.at <= errorMaxAge then
					table.insert(errorsOut, {
						signature = entry.signature,
						message = entry.message,
						secondsAgo = math.max(0, math.floor(now - entry.at)),
					})
				end
			end
		end

		reportCount += 1
		local client = submission.client
		table.insert(pendingReports, {
			id = `{math.floor(now)}-{Util.hash(`{options.server}|{info.userId}|{reportCount}`)}`,
			at = math.floor(now),
			game = options.game,
			build = options.build,
			placeVersion = options.placeVersion,
			server = options.server,
			category = submission.category,
			rating = submission.rating,
			text = filtered,
			userId = info.userId,
			accountAgeDays = info.accountAgeDays,
			locale = info.locale,
			sessionSeconds = math.max(0, math.floor(info.sessionSeconds)),
			pingMs = math.max(0, math.floor(info.pingMs)),
			position = info.position,
			platform = client.platform,
			screen = client.screen,
			fps = math.floor(client.fps),
			context = Feedback.sanitizeContext(info.context),
			recentErrors = errorsOut,
		})
		return true, Feedback.MESSAGES.sent
	end

	-- Remembers the last few client errors each player hit, so a bug report
	-- arrives with the errors that likely caused it.
	function feedback.noteError(
		_self: Feedback,
		userId: number,
		signature: string,
		message: string,
		now: number
	)
		local list = recentErrors[userId]
		if list == nil then
			list = {}
			recentErrors[userId] = list
		end
		for index, entry in list do
			if entry.signature == signature then
				table.remove(list, index)
				break
			end
		end
		table.insert(
			list,
			{ signature = signature, message = clipChars(message, ERROR_MESSAGE_MAX), at = now }
		)
		while #list > errorsPerPlayer do
			table.remove(list, 1)
		end
	end

	-- Call when a player leaves. Rate limits are kept (rejoining the same
	-- server does not reset them); only the error history goes.
	function feedback.forget(_self: Feedback, userId: number)
		recentErrors[userId] = nil
	end

	-- Writes the pending reports if `interval` has passed since the last write
	-- (or `force`). A failed write keeps the reports for the next try.
	function feedback.flush(_self: Feedback, now: number, force: boolean?): boolean
		if writing or #pendingReports == 0 then
			return false
		end
		if not force and now - lastWriteAt < interval then
			return false
		end

		local reports = pendingReports
		pendingReports = {}
		lastWriteAt = now
		sequence += 1
		local key = Feedback.batchKey(now, options.server, sequence)
		local batch: Batch = {
			schema = SCHEMA_VERSION,
			game = options.game,
			build = options.build,
			placeVersion = options.placeVersion,
			server = options.server,
			at = math.floor(now),
			reports = reports,
		}

		writing = true
		local ok, written = pcall(options.write, key, batch)
		writing = false
		if ok and written then
			return true
		end

		-- Put them back in front of anything that arrived while writing, up to the cap.
		local kept = table.clone(reports)
		for _, report in pendingReports do
			table.insert(kept, report)
		end
		local dropped = math.max(0, #kept - maxPending)
		while #kept > maxPending do
			table.remove(kept, 1)
		end
		pendingReports = kept
		log:warn(
			"feedback write failed; will retry",
			{ reports = #reports, dropped = dropped, err = written }
		)
		return false
	end

	function feedback.pending(_self: Feedback): number
		return #pendingReports
	end

	return (feedback :: any) :: Feedback
end

return Feedback
