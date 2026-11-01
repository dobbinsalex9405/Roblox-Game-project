--!strict
-- Module 12: ErrorReporter and Feedback.
-- Collects server and client errors, groups them by a short signature, and
-- writes at most one batch per server per `interval` seconds to the error
-- queue (a DataStore the nightly GitHub Action reads). A storm of 10,000
-- identical errors becomes one record with count = 10000, not 10,000 writes.
--
-- The in-game feedback button writes into the same batch. Feedback is never
-- shown to other players, so it needs no chat filtering, but it is trimmed,
-- length-capped and rate-limited per player.

local Log = require("./Log")
local Util = require("./Util")

export type Source = "server" | "client"

export type ErrorRecord = {
	signature: string,
	source: Source,
	message: string,
	trace: string,
	count: number,
	firstSeen: number,
	lastSeen: number,
}

export type FeedbackRecord = {
	userId: number,
	text: string,
	at: number,
}

export type Batch = {
	game: string,
	build: string,
	at: number,
	errors: { ErrorRecord },
	feedback: { FeedbackRecord },
	droppedSignatures: number,
}

export type Options = {
	game: string,
	build: string,
	write: (batch: Batch) -> boolean, -- may yield; returns false if the write failed
	interval: number?, -- seconds between writes, default 60
	maxSignatures: number?, -- distinct errors kept per batch, default 50
	maxFeedback: number?, -- feedback entries kept per batch, default 50
	feedbackCooldown: number?, -- seconds between submissions per player, default 60
	feedbackMaxLength: number?, -- default 500 characters
}

export type Reporter = {
	record: (self: Reporter, source: Source, message: string, trace: string?, now: number) -> string,
	submitFeedback: (self: Reporter, userId: number, text: string, now: number) -> (boolean, string?),
	flush: (self: Reporter, now: number, force: boolean?) -> boolean,
	pending: (self: Reporter) -> (number, number),
}

local MAX_MESSAGE = 500
local MAX_TRACE = 1000

local log = Log.new("ErrorReporter")

local ErrorReporter = {}

-- Normalizes the parts of a message that change between occurrences of the
-- same bug (numbers, quoted names, instance paths with player names).
function ErrorReporter.normalize(message: string): string
	local text = string.gsub(message, "%d+", "N")
	text = string.gsub(text, '"[^"]*"', '"*"')
	text = string.gsub(text, "'[^']*'", "'*'")
	text = string.gsub(text, "Players%.[%w_]+", "Players.*")
	return text
end

function ErrorReporter.signature(source: Source, message: string, trace: string?): string
	local firstFrame = trace and string.match(trace, "[^\n]+") or ""
	return Util.hash(source .. "|" .. ErrorReporter.normalize(message) .. "|" .. firstFrame)
end

local function clip(text: string, max: number): string
	if #text <= max then
		return text
	end
	return string.sub(text, 1, max - 3) .. "..."
end

function ErrorReporter.new(options: Options): Reporter
	local interval = options.interval or 60
	local maxSignatures = options.maxSignatures or 50
	local maxFeedback = options.maxFeedback or 50
	local cooldown = options.feedbackCooldown or 60
	local maxLength = options.feedbackMaxLength or 500

	local errors: { [string]: ErrorRecord } = {}
	local errorCount = 0
	local droppedSignatures = 0
	local feedback: { FeedbackRecord } = {}
	local lastFeedbackAt: { [number]: number } = {}
	local lastWriteAt = -math.huge
	local writing = false

	local reporter = {}

	function reporter.record(
		_self: Reporter,
		source: Source,
		message: string,
		trace: string?,
		now: number
	): string
		local sig = ErrorReporter.signature(source, message, trace)
		local existing = errors[sig]
		if existing then
			existing.count += 1
			existing.lastSeen = now
		elseif errorCount < maxSignatures then
			errors[sig] = {
				signature = sig,
				source = source,
				message = clip(message, MAX_MESSAGE),
				trace = clip(trace or "", MAX_TRACE),
				count = 1,
				firstSeen = now,
				lastSeen = now,
			}
			errorCount += 1
		else
			droppedSignatures += 1
		end
		return sig
	end

	function reporter.submitFeedback(
		_self: Reporter,
		userId: number,
		text: string,
		now: number
	): (boolean, string?)
		if type(text) ~= "string" then
			return false, "feedback must be text"
		end
		-- Strip control characters and surrounding whitespace.
		local cleaned = string.gsub(text, "%c", " ")
		cleaned = string.match(cleaned, "^%s*(.-)%s*$") or ""
		if #cleaned < 3 then
			return false, "feedback is too short"
		end
		local last = lastFeedbackAt[userId]
		if last and now - last < cooldown then
			return false, "please wait before sending more feedback"
		end
		if #feedback >= maxFeedback then
			return false, "feedback queue is full, try again in a minute"
		end
		lastFeedbackAt[userId] = now
		table.insert(feedback, { userId = userId, text = clip(cleaned, maxLength), at = now })
		return true, nil
	end

	-- Writes the pending batch if `interval` has passed since the last write (or `force`).
	-- Returns true when a batch was written.
	function reporter.flush(_self: Reporter, now: number, force: boolean?): boolean
		if writing or (errorCount == 0 and #feedback == 0) then
			return false
		end
		if not force and now - lastWriteAt < interval then
			return false
		end

		local list: { ErrorRecord } = {}
		for _, record in errors do
			table.insert(list, record)
		end
		table.sort(list, function(a, b)
			return a.count > b.count
		end)
		local batch: Batch = {
			game = options.game,
			build = options.build,
			at = now,
			errors = list,
			feedback = feedback,
			droppedSignatures = droppedSignatures,
		}

		-- Clear first, so errors raised while the write yields go into the next batch.
		errors = {}
		errorCount = 0
		droppedSignatures = 0
		feedback = {}
		lastWriteAt = now

		writing = true
		local ok, written = pcall(options.write, batch)
		writing = false
		if not ok or not written then
			log:warn(
				"error queue write failed; batch dropped",
				{ errors = #batch.errors, feedback = #batch.feedback }
			)
			return false
		end
		return true
	end

	function reporter.pending(_self: Reporter): (number, number)
		return errorCount, #feedback
	end

	return (reporter :: any) :: Reporter
end

return ErrorReporter
