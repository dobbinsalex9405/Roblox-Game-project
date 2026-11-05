--!nocheck
-- A thin Roblox runtime for Lune, just enough to boot a game's server and
-- client scripts from a built place (tools/boot/run.luau).
--
-- @lune/roblox gives us the instance tree, Instance.new, properties and the
-- data types. What it lacks is everything that runs: services, signals,
-- players, DataStores, the text filter. This module fills that in with stubs
-- that behave like an empty, quiet server: no players, every async call
-- succeeds with an empty answer, every signal connects and never fires unless
-- the runner fires it. Game code therefore runs its real start-up path
-- (config asserts, requires, world building, remote registration) and any
-- error it raises is the game's own.
--
-- A member the shim does not know raises Roblox's own "not a valid member"
-- error, which the report shows like any other error: the fix is to teach the
-- shim that member (see defineServices and Shim.install), never to loosen the
-- game. The few places where the shim answers with a guess instead are counted
-- in `Shim.gaps`, so the report shows what the game touched that the shim only
-- approximated.

local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local task = require("@lune/task")
local serde = require("@lune/serde")
local datetime = require("@lune/datetime")

local Instance = roblox.Instance
local Enum = roblox.Enum

local Shim = {}

Shim.gaps = {} :: { [string]: number }
Shim.errors = {} :: { { where: string, message: string } }
Shim.output = {} :: { string }
Shim.studio = false
Shim.unpublished = false -- DataStores throw, as in an unpublished place
Shim.quiet = false
-- Destroy() in game scripts detaches instead, so later reads work as in
-- Roblox (the player's-eye audit turns this on; see Shim.runScript).
Shim.detachOnDestroy = false
-- What MarketplaceService:GetProductInfo answers for an id (a harness can
-- fill it from the game's monetization listings); unknown ids cost 0.
Shim.productInfo = {} :: { [number]: { [string]: any } }

local function gap(name: string)
	Shim.gaps[name] = (Shim.gaps[name] or 0) + 1
end

-- Lune's Instances cannot take nil for an Instance-valued property other than
-- Parent ("Failed to convert from 'nil' into 'Ref'"), and the shim cannot
-- override built-in properties. In Roblox `box.Adornee = nil` is always legal,
-- so this is a gap in the shim, never a bug in the game: it is counted with
-- the other gaps instead of failing the boot check.
local LUNE_NIL_REF = "Failed to convert from 'nil' into 'Ref'"

local function record(where: string, message: any)
	local text = tostring(message)
	if string.find(text, LUNE_NIL_REF, 1, true) then
		gap("setting an Instance property to nil (legal in Roblox; Lune cannot)")
		return
	end
	table.insert(Shim.errors, { where = where, message = text })
end

local function say(prefix: string, ...: any)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring(select(i, ...))
	end
	local line = `{prefix}{table.concat(parts, " ")}`
	table.insert(Shim.output, line)
	if not Shim.quiet then
		print(line)
	end
end

-- Signals -------------------------------------------------------------------

local Signal = {}
Signal.__index = Signal

function Signal.new(name: string)
	return setmetatable({ name = name, handlers = {} }, Signal)
end

function Signal:Connect(fn)
	local entry = { fn = fn, Connected = true }
	function entry.Disconnect(self)
		self.Connected = false
	end
	table.insert(self.handlers, entry)
	return entry
end

function Signal:Once(fn)
	local entry
	entry = self:Connect(function(...)
		entry:Disconnect()
		fn(...)
	end)
	return entry
end

function Signal:ConnectParallel(fn)
	return self:Connect(fn)
end

function Signal:Wait()
	-- Nothing fires on its own; a waiting thread simply never resumes.
	coroutine.yield()
end

-- Runs every handler in its own thread (like Roblox) and records errors.
function Signal:Fire(...)
	for _, entry in table.clone(self.handlers) do
		if entry.Connected then
			local args = table.pack(...)
			task.spawn(function()
				local ok, err = pcall(entry.fn, table.unpack(args, 1, args.n))
				if not ok then
					record(`signal {self.name}`, err)
				end
			end)
		end
	end
end

Shim.Signal = Signal

-- Plays `frames` frames of 1/60 s: the per-frame signals a server (or, with
-- `client`, a client) gets each frame, so code that runs every frame (guard
-- AI, conveyors, timers) runs at least once. Nothing fires them otherwise.
function Shim.stepFrames(frames: number, client: boolean?)
	local rs = Shim.runService
	if rs == nil then
		return
	end
	local dt = 1 / 60
	for frame = 1, frames do
		local now = frame * dt
		if client then
			rs.PreRender:Fire(dt)
			rs.RenderStepped:Fire(dt)
		end
		rs.PreAnimation:Fire(dt)
		rs.Stepped:Fire(now, dt)
		rs.PreSimulation:Fire(dt)
		rs.PostSimulation:Fire(dt)
		rs.Heartbeat:Fire(dt)
	end
end

-- Signals that belong to instances, by instance then member name.
local instanceSignals = {}

local function signalOf(inst: any, name: string)
	local set = instanceSignals[inst]
	if set == nil then
		set = {}
		instanceSignals[inst] = set
	end
	local s = set[name]
	if s == nil then
		s = Signal.new(`{tostring(inst)}.{name}`)
		set[name] = s
	end
	return s
end
Shim.signalOf = signalOf

-- Something that works whether it is called or connected to.
local function stub(name: string)
	gap(name)
	local s = Signal.new(name)
	return setmetatable({}, {
		__index = s,
		__call = function()
			return nil
		end,
		__tostring = function()
			return `<stub {name}>`
		end,
	})
end

-- Properties stored outside the instance (read-only or defaultless ones).
local side = {}
local function sideGet(inst, name, default)
	local t = side[inst]
	if t and t[name] ~= nil then
		return t[name]
	end
	return default
end
local function sideSet(inst, name, value)
	local t = side[inst]
	if t == nil then
		t = {}
		side[inst] = t
	end
	t[name] = value
end

-- Instance members -----------------------------------------------------------

local function hasMember(className: string, member: string): boolean
	local ok, inst = pcall(Instance.new, className)
	if not ok then
		return false
	end
	local fine = pcall(function()
		return inst[member]
	end)
	return fine
end

local function event(className: string, name: string)
	roblox.implementProperty(className, name, function(inst)
		return signalOf(inst, name)
	end, function() end)
end

local function method(className: string, name: string, fn, concrete: string?)
	if hasMember(concrete or className, name) then
		return
	end
	roblox.implementMethod(className, name, fn)
end

local function property(className: string, name: string, default: any)
	roblox.implementProperty(className, name, function(inst)
		return sideGet(inst, name, default)
	end, function(inst, value)
		sideSet(inst, name, value)
	end)
end

local installed = false
function Shim.install()
	if installed then
		return
	end
	installed = true

	local V2 = roblox.Vector2
	local V3 = roblox.Vector3
	local CF = roblox.CFrame

	for _, name in
		{
			"Changed",
			"AncestryChanged",
			"ChildAdded",
			"ChildRemoved",
			"DescendantAdded",
			"DescendantRemoving",
			"Destroying",
			"AttributeChanged",
		}
	do
		event("Instance", name)
	end
	method("Instance", "GetPropertyChangedSignal", function(inst, name)
		return signalOf(inst, `Changed:{name}`)
	end, "Folder")
	method("Instance", "GetAttributeChangedSignal", function(inst, name)
		return signalOf(inst, `Attribute:{name}`)
	end, "Folder")
	method("Instance", "WaitForChild", function(inst, name)
		return inst:FindFirstChild(name)
	end, "Folder")
	method("Instance", "FindFirstChildWhichIsA", function(inst, className, recursive)
		for _, child in (if recursive then inst:GetDescendants() else inst:GetChildren()) do
			if child:IsA(className) then
				return child
			end
		end
		return nil
	end, "Folder")
	method("Instance", "FindFirstAncestorWhichIsA", function(inst, className)
		local p = inst.Parent
		while p do
			if p:IsA(className) then
				return p
			end
			p = p.Parent
		end
		return nil
	end, "Folder")
	method("Instance", "GetDebugId", function(inst)
		return tostring(inst)
	end, "Folder")

	for _, name in { "Touched", "TouchEnded" } do
		event("BasePart", name)
	end
	for _, name in
		{
			"SetNetworkOwner",
			"SetNetworkOwnershipAuto",
			"ApplyImpulse",
			"ApplyAngularImpulse",
			"ApplyImpulseAtPosition",
		}
	do
		method("BasePart", name, function() end, "Part")
	end
	method("BasePart", "GetMass", function()
		return 1
	end, "Part")
	method("BasePart", "GetTouchingParts", function()
		return {}
	end, "Part")
	method("BasePart", "GetConnectedParts", function()
		return {}
	end, "Part")
	method("BasePart", "CanSetNetworkOwnership", function()
		return true
	end, "Part")
	method("BasePart", "GetNetworkOwner", function()
		return nil
	end, "Part")
	method("BasePart", "IsGrounded", function()
		return true
	end, "Part")

	method("Model", "GetPivot", function(inst)
		return sideGet(inst, "__pivot", CF.identity)
	end)
	method("Model", "PivotTo", function(inst, cf)
		sideSet(inst, "__pivot", cf)
	end)
	method("Model", "GetBoundingBox", function(inst)
		return sideGet(inst, "__pivot", CF.identity), V3.new(4, 4, 4)
	end)
	method("Model", "GetExtentsSize", function()
		return V3.new(4, 4, 4)
	end)
	method("Model", "MoveTo", function() end)
	method("Model", "SetPrimaryPartCFrame", function(inst, cf)
		sideSet(inst, "__pivot", cf)
	end)
	method("Model", "GetPrimaryPartCFrame", function(inst)
		return sideGet(inst, "__pivot", CF.identity)
	end)
	method("Model", "ScaleTo", function() end)
	method("Model", "GetScale", function()
		return 1
	end)
	if not hasMember("Model", "PrimaryPart") then
		property("Model", "PrimaryPart", nil)
	end

	for _, name in
		{
			"Died",
			"Seated",
			"StateChanged",
			"HealthChanged",
			"Running",
			"Jumping",
			"FreeFalling",
			"MoveToFinished",
			"Climbing",
			"Swimming",
			"FallingDown",
			"GettingUp",
			"PlatformStanding",
			"Ragdoll",
			"Strafing",
		}
	do
		event("Humanoid", name)
	end
	method("Humanoid", "MoveTo", function() end)
	method("Humanoid", "Move", function() end)
	method("Humanoid", "TakeDamage", function() end)
	method("Humanoid", "ChangeState", function() end)
	method("Humanoid", "SetStateEnabled", function() end)
	method("Humanoid", "GetState", function()
		return Enum.HumanoidStateType.Running
	end)
	method("Humanoid", "GetStateEnabled", function()
		return true
	end)
	method("Humanoid", "EquipTool", function() end)
	method("Humanoid", "UnequipTools", function() end)
	method("Humanoid", "GetAccessories", function()
		return {}
	end)
	method("Humanoid", "AddAccessory", function() end)
	method("Humanoid", "RemoveAccessories", function() end)
	method("Humanoid", "ApplyDescription", function() end)
	method("Humanoid", "ApplyDescriptionReset", function() end)
	method("Humanoid", "GetAppliedDescription", function()
		return Instance.new("HumanoidDescription")
	end)
	method("Humanoid", "LoadAnimation", function()
		return Shim.animationTrack()
	end)
	for _, name in
		{
			"MoveDirection",
			"SeatPart",
			"RootPart",
			"FloorMaterial",
			"WalkToPoint",
			"WalkToPart",
			"TargetPoint",
		}
	do
		if not hasMember("Humanoid", name) then
			property(
				"Humanoid",
				name,
				if name == "MoveDirection"
						or name == "WalkToPoint"
						or name == "TargetPoint"
					then V3.zero
					elseif name == "FloorMaterial" then Enum.Material.Plastic
					else nil
			)
		end
	end

	event("Animator", "AnimationPlayed")
	method("Animator", "LoadAnimation", function()
		return Shim.animationTrack()
	end)
	method("Animator", "GetPlayingAnimationTracks", function()
		return {}
	end)
	method("AnimationController", "LoadAnimation", function()
		return Shim.animationTrack()
	end)

	for _, name in
		{
			"Triggered",
			"TriggerEnded",
			"PromptButtonHoldBegan",
			"PromptButtonHoldEnded",
			"PromptShown",
			"PromptHidden",
		}
	do
		event("ProximityPrompt", name)
	end
	method("ProximityPrompt", "InputHoldBegin", function() end)
	method("ProximityPrompt", "InputHoldEnd", function() end)
	for _, name in { "MouseClick", "RightMouseClick", "MouseHoverEnter", "MouseHoverLeave" } do
		event("ClickDetector", name)
	end
	for _, name in { "Activated", "Deactivated", "Equipped", "Unequipped" } do
		event("Tool", name)
	end
	method("Tool", "Activate", function() end)

	for _, name in { "OnServerEvent", "OnClientEvent" } do
		event("RemoteEvent", name)
		event("UnreliableRemoteEvent", name)
	end
	for _, name in { "FireClient", "FireAllClients", "FireServer" } do
		method("RemoteEvent", name, function() end)
		method("UnreliableRemoteEvent", name, function() end)
	end
	property("RemoteFunction", "OnServerInvoke", nil)
	property("RemoteFunction", "OnClientInvoke", nil)
	method("RemoteFunction", "InvokeServer", function() end)
	method("RemoteFunction", "InvokeClient", function() end)
	event("BindableEvent", "Event")
	method("BindableEvent", "Fire", function(inst, ...)
		signalOf(inst, "Event"):Fire(...)
	end)
	property("BindableFunction", "OnInvoke", nil)
	method("BindableFunction", "Invoke", function(inst, ...)
		local fn = sideGet(inst, "OnInvoke", nil)
		if fn then
			return fn(...)
		end
		return nil
	end)

	for _, name in
		{
			"Activated",
			"MouseButton1Click",
			"MouseButton1Down",
			"MouseButton1Up",
			"MouseButton2Click",
			"MouseButton2Down",
			"MouseButton2Up",
		}
	do
		event("GuiButton", name)
	end
	for _, name in
		{
			"InputBegan",
			"InputEnded",
			"InputChanged",
			"MouseEnter",
			"MouseLeave",
			"MouseMoved",
			"MouseWheelForward",
			"MouseWheelBackward",
			"SelectionGained",
			"SelectionLost",
			"TouchTap",
			"TouchLongPress",
			"TouchPan",
			"TouchPinch",
			"TouchRotate",
			"TouchSwipe",
			"DragBegin",
			"DragStopped",
		}
	do
		event("GuiObject", name)
	end
	for _, name in { "TweenPosition", "TweenSize", "TweenSizeAndPosition" } do
		method("GuiObject", name, function()
			return true
		end, "Frame")
	end
	for _, name in
		{
			"AbsoluteSize",
			"AbsolutePosition",
			"AbsoluteContentSize",
			"AbsoluteCanvasSize",
			"AbsoluteWindowSize",
		}
	do
		for _, className in { "GuiBase2d", "UIGridStyleLayout", "ScrollingFrame" } do
			if
				not hasMember(
					if className == "GuiBase2d"
						then "Frame"
						elseif className == "UIGridStyleLayout" then "UIListLayout"
						else className,
					name
				)
			then
				property(className, name, V2.zero)
			end
		end
	end
	if not hasMember("GuiBase2d", "AbsoluteRotation") then
		property("GuiBase2d", "AbsoluteRotation", 0)
	end
	for _, name in { "TextBounds", "TextFits", "ContentText" } do
		for _, className in { "TextLabel", "TextButton", "TextBox" } do
			if not hasMember(className, name) then
				property(
					className,
					name,
					if name == "TextBounds" then V2.zero elseif name == "TextFits" then true else ""
				)
			end
		end
	end
	for _, name in { "FocusLost", "Focused", "ReturnPressedFromOnScreenKeyboard" } do
		event("TextBox", name)
	end
	method("TextBox", "ReleaseFocus", function() end)
	method("TextBox", "CaptureFocus", function() end)
	method("TextBox", "IsFocused", function()
		return false
	end)
	method("ScrollingFrame", "ScrollToTop", function() end)
	for _, name in { "Ended", "Played", "Stopped", "Paused", "Resumed", "Loaded", "DidLoop" } do
		event("Sound", name)
	end
	for _, name in { "Play", "Stop", "Pause", "Resume" } do
		method("Sound", name, function() end)
	end
	method("ParticleEmitter", "Emit", function() end)
	method("ParticleEmitter", "Clear", function() end)
	method("Beam", "SetTextureOffset", function() end)
	if not hasMember("Seat", "Occupant") then
		property("Seat", "Occupant", nil)
		property("VehicleSeat", "Occupant", nil)
	end
	method("Seat", "Sit", function() end)
	method("VehicleSeat", "Sit", function() end)

	for _, name in
		{
			"CharacterAdded",
			"CharacterRemoving",
			"CharacterAppearanceLoaded",
			"Chatted",
			"Idled",
			"OnTeleport",
		}
	do
		event("Player", name)
	end
	method("Player", "Kick", function(inst, message)
		say("[kick] ", inst.Name, message or "")
	end)
	method("Player", "LoadCharacter", function() end)
	method("Player", "GetNetworkPing", function()
		return 0.05
	end)
	method("Player", "GetMouse", function()
		return stub("PlayerMouse")
	end)
	method("Player", "GetJoinData", function()
		return {}
	end)
	method("Player", "IsFriendsWithAsync", function()
		return false
	end)
	method("Player", "IsInGroup", function()
		return false
	end)
	method("Player", "GetRankInGroup", function()
		return 0
	end)
	method("Player", "DistanceFromCharacter", function()
		return 0
	end)
	method("Player", "RequestStreamAroundAsync", function() end)
	method("Player", "HasAppearanceLoaded", function()
		return true
	end)
	method("Player", "SetAccountAge", function(inst, days)
		sideSet(inst, "AccountAge", days)
	end)
	if not hasMember("Player", "Character") then
		property("Player", "Character", nil)
	end
	for _, name in { "AccountAge", "LocaleId", "MembershipType", "FollowUserId", "GameplayPaused" } do
		if not hasMember("Player", name) then
			property(
				"Player",
				name,
				if name == "AccountAge"
					then 30
					elseif name == "LocaleId" then "en-us"
					elseif name == "MembershipType" then Enum.MembershipType.None
					elseif name == "FollowUserId" then 0
					else false
			)
		end
	end

	for _, name in { "WorldToScreenPoint", "WorldToViewportPoint" } do
		method("Camera", name, function()
			return V3.zero, false
		end)
	end
	for _, name in { "ScreenPointToRay", "ViewportPointToRay" } do
		method("Camera", name, function()
			return roblox.Ray.new(V3.zero, V3.new(0, 0, -1))
		end)
	end
	method("Camera", "GetPartsObscuringTarget", function()
		return {}
	end)
	if not hasMember("Camera", "ViewportSize") then
		property("Camera", "ViewportSize", V2.new(1280, 720))
	end

	method("DataStoreOptions", "SetExperimentalFeatures", function() end)
	method("DataStoreSetOptions", "SetMetadata", function() end)
	method("DataStoreSetOptions", "GetMetadata", function()
		return {}
	end)
	method("DataStoreGetOptions", "SetUseCache", function() end)
	method("DataStoreIncrementOptions", "SetMetadata", function() end)

	for _, name in
		{
			"FillBlock",
			"FillBall",
			"FillRegion",
			"FillCylinder",
			"FillWedge",
			"Clear",
			"WriteVoxels",
			"SetMaterialColor",
		}
	do
		method("Terrain", name, function() end)
	end
	method("Terrain", "ReadVoxels", function()
		return {}, {}
	end)
end

function Shim.animationTrack()
	return {
		IsPlaying = false,
		Length = 1,
		Looped = false,
		Priority = Enum.AnimationPriority.Core,
		Speed = 1,
		TimePosition = 0,
		WeightCurrent = 1,
		WeightTarget = 1,
		Stopped = Signal.new("AnimationTrack.Stopped"),
		Ended = Signal.new("AnimationTrack.Ended"),
		DidLoop = Signal.new("AnimationTrack.DidLoop"),
		KeyframeReached = Signal.new("AnimationTrack.KeyframeReached"),
		Play = function() end,
		Stop = function() end,
		AdjustSpeed = function() end,
		AdjustWeight = function() end,
		GetTimeOfKeyframe = function()
			return 0
		end,
		GetMarkerReachedSignal = function()
			return Signal.new("AnimationTrack.Marker")
		end,
	}
end

-- Data types @lune/roblox lacks -----------------------------------------------

local Random = {}
Random.__index = Random
function Random.new(seed: number?)
	local state = (seed or os.clock() * 1e6) % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	return setmetatable({ state = state }, Random)
end
local function nextState(self)
	self.state = (self.state * 48271) % 2147483647
	return self.state / 2147483647
end
function Random:NextNumber(min: number?, max: number?)
	local r = nextState(self)
	if min == nil then
		return r
	end
	return min + r * ((max or 1) - min)
end
function Random:NextInteger(min: number, max: number)
	return min + math.floor(nextState(self) * (max - min + 1))
end
function Random:NextUnitVector()
	local v = roblox.Vector3.new(self:NextNumber(-1, 1), self:NextNumber(-1, 1), self:NextNumber(-1, 1))
	return if v.Magnitude > 0 then v.Unit else roblox.Vector3.new(0, 1, 0)
end
function Random:Shuffle(t)
	for i = #t, 2, -1 do
		local j = self:NextInteger(1, i)
		t[i], t[j] = t[j], t[i]
	end
end
function Random:Clone()
	return setmetatable({ state = self.state }, Random)
end

local TweenInfo = {}
function TweenInfo.new(time, style, direction, repeatCount, reverses, delayTime)
	return {
		Time = time or 1,
		EasingStyle = style or Enum.EasingStyle.Quad,
		EasingDirection = direction or Enum.EasingDirection.Out,
		RepeatCount = repeatCount or 0,
		Reverses = reverses or false,
		DelayTime = delayTime or 0,
	}
end

local function dateTimeOf(d)
	return {
		UnixTimestamp = d.unixTimestamp,
		UnixTimestampMillis = d.unixTimestampMillis,
		ToIsoDate = function()
			return d:toIsoDate()
		end,
		ToUniversalTime = function()
			local u = d:toUniversalTime()
			return {
				Year = u.year,
				Month = u.month,
				Day = u.day,
				Hour = u.hour,
				Minute = u.minute,
				Second = u.second,
				Millisecond = u.millisecond,
			}
		end,
		ToLocalTime = function()
			local u = d:toLocalTime()
			return {
				Year = u.year,
				Month = u.month,
				Day = u.day,
				Hour = u.hour,
				Minute = u.minute,
				Second = u.second,
				Millisecond = u.millisecond,
			}
		end,
		FormatUniversalTime = function(_, fmt, locale)
			return d:formatUniversalTime(fmt, locale)
		end,
		FormatLocalTime = function(_, fmt, locale)
			return d:formatLocalTime(fmt, locale)
		end,
	}
end
local DateTime = {
	now = function()
		return dateTimeOf(datetime.now())
	end,
	fromUnixTimestamp = function(s)
		return dateTimeOf(datetime.fromUnixTimestamp(s))
	end,
	fromUnixTimestampMillis = function(ms)
		return dateTimeOf(datetime.fromUnixTimestamp(ms / 1000))
	end,
	fromIsoDate = function(iso)
		return dateTimeOf(datetime.fromIsoDate(iso))
	end,
}

-- Services -----------------------------------------------------------------

local DataStoreKeyInfo = {}
DataStoreKeyInfo.__index = DataStoreKeyInfo
function DataStoreKeyInfo.new()
	local now = os.time() * 1000
	return setmetatable({ CreatedTime = now, UpdatedTime = now, Version = "1" }, DataStoreKeyInfo)
end
function DataStoreKeyInfo:GetMetadata()
	return {}
end
function DataStoreKeyInfo:GetUserIds()
	return {}
end

-- An in-memory DataStore: enough for ProfileStore and the queues.
local function newDataStore(name: string)
	local values: { [string]: any } = {}
	local store = {}
	function store:GetAsync(key)
		return values[key], DataStoreKeyInfo.new()
	end
	function store:SetAsync(key, value)
		values[key] = value
		return "1"
	end
	function store:UpdateAsync(key, transform)
		local new = transform(values[key], DataStoreKeyInfo.new())
		if new ~= nil then
			values[key] = new
		end
		return values[key], DataStoreKeyInfo.new()
	end
	function store:RemoveAsync(key)
		local old = values[key]
		values[key] = nil
		return old, DataStoreKeyInfo.new()
	end
	function store:IncrementAsync(key, delta)
		values[key] = (values[key] or 0) + (delta or 1)
		return values[key]
	end
	function store:GetSortedAsync()
		return {
			GetCurrentPage = function()
				return {}
			end,
			IsFinished = true,
			AdvanceToNextPageAsync = function() end,
		}
	end
	function store:ListKeysAsync()
		return {
			GetCurrentPage = function()
				return {}
			end,
			IsFinished = true,
			AdvanceToNextPageAsync = function() end,
		}
	end
	function store:ListVersionsAsync()
		return {
			GetCurrentPage = function()
				return {}
			end,
			IsFinished = true,
			AdvanceToNextPageAsync = function() end,
		}
	end
	function store:GetVersionAsync()
		return nil
	end
	store.Name = name
	return store
end
local dataStores: { [string]: any } = {}

local stubPolicy = {
	ArePaidRandomItemsRestricted = false,
	AllowedExternalLinkReferences = {},
	IsPaidItemTradingAllowed = true,
	IsSubjectToChinaPolicies = false,
	IsEligibleToPurchaseSubscription = true,
	IsEligibleToPurchaseCommerceProduct = true,
	IsContentSharingAllowed = true,
}

local function textFilterResult(text: string)
	return {
		GetNonChatStringForBroadcastAsync = function()
			return text
		end,
		GetNonChatStringForUserAsync = function()
			return text
		end,
		GetChatForUserAsync = function()
			return text
		end,
	}
end

-- Overrides per service class: members the shim answers itself. Services stay
-- the real instances (game code parents things to them), so each override is
-- installed on the class with implementMethod / implementProperty.
local serviceOverrides: { [string]: { [string]: any } } = {}
local serviceValues: { [string]: { [string]: any } } = {}
local implementedMembers: { [string]: boolean } = {}
local NIL = {} -- a property whose default is nil
Shim.NIL = NIL

local function overridesFor(className: string): { [string]: any }
	local o = serviceOverrides[className]
	if o == nil then
		o = {}
		serviceOverrides[className] = o
	end
	return o
end

local function applyOverrides(game: any)
	for className, members in serviceOverrides do
		local values = {}
		serviceValues[className] = values
		local inst
		if className == "DataModel" then
			inst = game
		else
			local ok, found = pcall(game.GetService, game, className)
			inst = if ok then found else nil
		end
		for member, value in members do
			local key = `{className}.{member}`
			if type(value) == "function" then
				if not implementedMembers[key] then
					local native = inst ~= nil and pcall(function()
						return inst[member]
					end)
					if not native then
						implementedMembers[key] = true
						roblox.implementMethod(className, member, value)
					end
				end
			elseif member == "Terrain" then
				if not implementedMembers[key] then
					implementedMembers[key] = true
					roblox.implementProperty(className, member, function(ws)
						local terrain = ws:FindFirstChildOfClass("Terrain")
						if terrain == nil then
							terrain = Instance.new("Terrain")
							terrain.Parent = ws
						end
						return terrain
					end, function() end)
				end
			else
				local plain = if value == NIL then nil else value
				values[member] = plain
				-- A property the class really has (even one without a default)
				-- can simply be written; anything else is implemented on the class.
				local written = inst ~= nil and pcall(function()
					inst[member] = plain
				end)
				if not written and not implementedMembers[key] then
					implementedMembers[key] = true
					roblox.implementProperty(className, member, function()
						local current = serviceValues[className]
						return if current then current[member] else nil
					end, function(_, v)
						local current = serviceValues[className]
						if current then
							current[member] = v
						end
					end)
				end
			end
		end
	end
end

-- Read-only properties the runtime would compute; a built place and
-- Instance.new leave them unset, which reads as an error. Seed them.
local SEEDS = {
	{
		"GuiBase2d",
		{ AbsoluteSize = roblox.Vector2.zero, AbsolutePosition = roblox.Vector2.zero, AbsoluteRotation = 0 },
	},
	{ "UIGridStyleLayout", { AbsoluteContentSize = roblox.Vector2.zero } },
	{
		"ScrollingFrame",
		{ AbsoluteCanvasSize = roblox.Vector2.zero, AbsoluteWindowSize = roblox.Vector2.zero },
	},
	{ "TextLabel", { TextBounds = roblox.Vector2.zero, TextFits = true, ContentText = "" } },
	{ "TextButton", { TextBounds = roblox.Vector2.zero, TextFits = true, ContentText = "" } },
	{ "TextBox", { TextBounds = roblox.Vector2.zero, TextFits = true, ContentText = "" } },
	{
		"Humanoid",
		{ Health = 100, MoveDirection = roblox.Vector3.zero, FloorMaterial = Enum.Material.Plastic },
	},
	{ "Camera", { ViewportSize = roblox.Vector2.new(1280, 720) } },
	{
		"Player",
		{
			AccountAge = 30,
			LocaleId = "en-us",
			MembershipType = Enum.MembershipType.None,
			FollowUserId = 0,
			CameraMaxZoomDistance = 128,
			CameraMinZoomDistance = 0.5,
		},
	},
	{
		"BasePart",
		{
			Position = roblox.Vector3.zero,
			Orientation = roblox.Vector3.zero,
			Rotation = roblox.Vector3.zero,
			AssemblyLinearVelocity = roblox.Vector3.zero,
			AssemblyAngularVelocity = roblox.Vector3.zero,
			AssemblyMass = 1,
			AssemblyCenterOfMass = roblox.Vector3.zero,
			ExtentsSize = roblox.Vector3.one,
			ExtentsCFrame = roblox.CFrame.identity,
		},
	},
	{ "Sound", { IsPlaying = false, IsLoaded = true, TimeLength = 1 } },
}
function Shim.seed(inst: any)
	for _, entry in SEEDS do
		if inst:IsA(entry[1]) then
			for prop, value in entry[2] do
				pcall(function()
					if not pcall(function()
						return inst[prop]
					end) then
						inst[prop] = value
					end
				end)
			end
		end
	end
	return inst
end
function Shim.seedTree(root: any)
	Shim.seed(root)
	for _, d in root:GetDescendants() do
		Shim.seed(d)
	end
end

function Shim.proxyFor(inst: any)
	return inst
end

local function defineServices()
	local dm = overridesFor("DataModel")
	dm.PlaceId = 0
	dm.PlaceVersion = 0
	dm.GameId = 0
	dm.JobId = ""
	dm.CreatorId = 0
	dm.CreatorType = Enum.CreatorType.User
	dm.PrivateServerId = ""
	dm.PrivateServerOwnerId = 0
	dm.Loaded = Signal.new("DataModel.Loaded")
	dm.Close = Signal.new("DataModel.Close")
	dm.FindService = function(self, name)
		local ok, s = pcall(self.GetService, self, name)
		return if ok then s else nil
	end
	dm.BindToClose = function(_, fn)
		Shim.closeHandlers = Shim.closeHandlers or {}
		table.insert(Shim.closeHandlers, fn)
	end
	dm.IsLoaded = function()
		return true
	end
	dm.GetJobsInfo = function()
		return {}
	end
	dm.SetPlaceId = function() end
	dm.SetUniverseId = function() end

	local rs = overridesFor("RunService")
	rs.IsStudio = function()
		return Shim.studio
	end
	rs.IsServer = function()
		return Shim.side == "server"
	end
	rs.IsClient = function()
		return Shim.side == "client"
	end
	rs.IsRunning = function()
		return true
	end
	rs.IsRunMode = function()
		return false
	end
	rs.IsEdit = function()
		return false
	end
	rs.Heartbeat = Signal.new("RunService.Heartbeat")
	rs.Stepped = Signal.new("RunService.Stepped")
	rs.RenderStepped = Signal.new("RunService.RenderStepped")
	rs.PreRender = Signal.new("RunService.PreRender")
	rs.PreAnimation = Signal.new("RunService.PreAnimation")
	rs.PreSimulation = Signal.new("RunService.PreSimulation")
	rs.PostSimulation = Signal.new("RunService.PostSimulation")
	Shim.runService = rs
	rs.BindToRenderStep = function() end
	rs.UnbindFromRenderStep = function() end

	local players = overridesFor("Players")
	players.PlayerAdded = Signal.new("Players.PlayerAdded")
	players.PlayerRemoving = Signal.new("Players.PlayerRemoving")
	players.PlayerMembershipChanged = Signal.new("Players.PlayerMembershipChanged")
	players.GetPlayers = function()
		return table.clone(Shim.players)
	end
	players.GetPlayerByUserId = function(_, id)
		for _, p in Shim.players do
			if p.UserId == id then
				return p
			end
		end
		return nil
	end
	players.GetPlayerFromCharacter = function(_, character)
		for _, p in Shim.players do
			if p.Character == character then
				return p
			end
		end
		return nil
	end
	players.GetUserIdFromNameAsync = function()
		return 1
	end
	players.GetNameFromUserIdAsync = function(_, id)
		return `Player{id}`
	end
	players.GetUserThumbnailAsync = function()
		return "rbxassetid://0", true
	end
	players.GetHumanoidDescriptionFromUserId = function()
		return Instance.new("HumanoidDescription")
	end
	players.CreateHumanoidModelFromDescription = function()
		return Instance.new("Model")
	end
	players.CreateHumanoidModelFromUserId = function()
		return Instance.new("Model")
	end
	players.BanAsync = function() end
	players.UnbanAsync = function() end
	players.LocalPlayer = NIL

	local ds = overridesFor("DataStoreService")
	ds.GetDataStore = function(_, name, scope)
		if Shim.unpublished then
			-- What Roblox raises in a place that was never published (a built
			-- .rbxl opened in Studio).
			error("You must publish this place to the web to access DataStore.", 2)
		end
		local key = `{name}/{scope or "global"}`
		dataStores[key] = dataStores[key] or newDataStore(name)
		return dataStores[key]
	end
	ds.GetOrderedDataStore = ds.GetDataStore
	ds.GetGlobalDataStore = function()
		return ds.GetDataStore(nil, "__global")
	end
	ds.GetRequestBudgetForRequestType = function()
		return 100
	end
	ds.ListDataStoresAsync = function()
		return {
			GetCurrentPage = function()
				return {}
			end,
			IsFinished = true,
			AdvanceToNextPageAsync = function() end,
		}
	end

	local ms = overridesFor("MemoryStoreService")
	ms.GetSortedMap = function()
		return {
			GetAsync = function()
				return nil
			end,
			SetAsync = function()
				return true
			end,
			UpdateAsync = function(_, _key, transform)
				return transform(nil)
			end,
			RemoveAsync = function() end,
			GetRangeAsync = function()
				return {}
			end,
		}
	end
	ms.GetQueue = function()
		return {
			AddAsync = function() end,
			ReadAsync = function()
				return {}, ""
			end,
			RemoveAsync = function() end,
		}
	end
	ms.GetHashMap = ms.GetSortedMap

	local mp = overridesFor("MarketplaceService")
	mp.PromptProductPurchaseFinished = Signal.new("MarketplaceService.PromptProductPurchaseFinished")
	mp.PromptGamePassPurchaseFinished = Signal.new("MarketplaceService.PromptGamePassPurchaseFinished")
	mp.PromptPurchaseFinished = Signal.new("MarketplaceService.PromptPurchaseFinished")
	mp.PromptBundlePurchaseFinished = Signal.new("MarketplaceService.PromptBundlePurchaseFinished")
	mp.PromptSubscriptionPurchaseFinished =
		Signal.new("MarketplaceService.PromptSubscriptionPurchaseFinished")
	mp.UserOwnsGamePassAsync = function()
		return false
	end
	mp.PlayerOwnsAsset = function()
		return false
	end
	mp.GetProductInfo = function(_, id)
		local known = Shim.productInfo[id]
		if known then
			return table.clone(known)
		end
		return { Name = `Product {id}`, PriceInRobux = 0, Description = "", IsForSale = true }
	end
	mp.GetDeveloperProductsAsync = function()
		return {
			GetCurrentPage = function()
				return {}
			end,
			IsFinished = true,
			AdvanceToNextPageAsync = function() end,
		}
	end
	mp.PromptProductPurchase = function(_, player, id)
		say("[prompt] ", "product", id, "for", player and player.Name or "?")
	end
	mp.PromptGamePassPurchase = function(_, player, id)
		say("[prompt] ", "pass", id, "for", player and player.Name or "?")
	end
	mp.PromptPurchase = function() end
	mp.ProcessReceipt = NIL
	mp.GetUserSubscriptionStatusAsync = function()
		return { IsSubscribed = false }
	end

	local policy = overridesFor("PolicyService")
	policy.GetPolicyInfoForPlayerAsync = function()
		return table.clone(stubPolicy)
	end
	policy.CanViewBrandProjectAsync = function()
		return false
	end

	local text = overridesFor("TextService")
	text.FilterStringAsync = function(_, textIn)
		return textFilterResult(textIn)
	end
	text.FilterAndTranslateStringAsync = function(_, textIn)
		return textFilterResult(textIn)
	end
	text.GetTextSize = function(_, s, size)
		return roblox.Vector2.new(#s * (size or 14) * 0.5, size or 14)
	end
	text.GetTextBoundsAsync = function()
		return roblox.Vector2.new(100, 20)
	end
	text.GetFamilyInfoAsync = function()
		return { Name = "Gotham", Faces = {} }
	end

	local http = overridesFor("HttpService")
	http.JSONEncode = function(_, value)
		return serde.encode("json", value)
	end
	http.JSONDecode = function(_, s)
		return serde.decode("json", s)
	end
	http.GenerateGUID = function(_, wrap)
		local function hex(n: number): string
			local out = {}
			for _ = 1, n do
				out[#out + 1] = string.format("%x", math.random(0, 15))
			end
			return table.concat(out)
		end
		local guid = `{hex(8)}-{hex(4)}-4{hex(3)}-{hex(4)}-{hex(12)}`
		return if wrap == false then guid else `\{{guid}\}`
	end
	http.UrlEncode = function(_, s)
		return (
			string.gsub(s, "[^%w%-%._~]", function(c)
				return string.format("%%%02X", string.byte(c))
			end)
		)
	end
	http.GetAsync = function()
		error("HttpService is not available in the boot check")
	end
	http.PostAsync = http.GetAsync
	http.RequestAsync = http.GetAsync

	local groups = overridesFor("GroupService")
	groups.GetGroupInfoAsync = function(_, id)
		return { Name = `Group {id}`, Id = id, Owner = { Name = "Owner", Id = 1 }, Roles = {} }
	end
	groups.GetGroupsAsync = function()
		return {}
	end

	local sc = overridesFor("ScriptContext")
	sc.Error = Signal.new("ScriptContext.Error")
	sc.SetTimeout = function() end

	local logs = overridesFor("LogService")
	logs.MessageOut = Signal.new("LogService.MessageOut")
	logs.GetLogHistory = function()
		return {}
	end

	local cs = overridesFor("CollectionService")
	local tags = setmetatable({}, { __mode = "k" })
	cs.AddTag = function(_, inst, tag)
		tags[inst] = tags[inst] or {}
		tags[inst][tag] = true
	end
	cs.RemoveTag = function(_, inst, tag)
		if tags[inst] then
			tags[inst][tag] = nil
		end
	end
	cs.HasTag = function(_, inst, tag)
		return tags[inst] ~= nil and tags[inst][tag] == true
	end
	cs.GetTagged = function(_, tag)
		local out = {}
		for inst, set in tags do
			if set[tag] then
				table.insert(out, inst)
			end
		end
		return out
	end
	cs.GetTags = function(_, inst)
		local out = {}
		for tag in tags[inst] or {} do
			table.insert(out, tag)
		end
		return out
	end
	cs.GetAllTags = function()
		return {}
	end
	cs.GetInstanceAddedSignal = function(_, tag)
		return Signal.new(`CollectionService.Added:{tag}`)
	end
	cs.GetInstanceRemovedSignal = function(_, tag)
		return Signal.new(`CollectionService.Removed:{tag}`)
	end

	local tween = overridesFor("TweenService")
	tween.Create = function(_, inst, info, goals)
		local completed = Signal.new("Tween.Completed")
		return {
			Instance = inst,
			TweenInfo = info,
			PlaybackState = Enum.PlaybackState.Begin,
			Completed = completed,
			Play = function()
				-- Apply the goals at once; the game sees the end state.
				for k, v in goals or {} do
					pcall(function()
						inst[k] = v
					end)
				end
				task.defer(function()
					completed:Fire(Enum.PlaybackState.Completed)
				end)
			end,
			Pause = function() end,
			Cancel = function() end,
			Destroy = function() end,
		}
	end
	tween.GetValue = function(_, alpha)
		return alpha
	end

	local debris = overridesFor("Debris")
	debris.AddItem = function(_, inst, lifetime)
		task.delay(lifetime or 10, function()
			pcall(function()
				inst:Destroy()
			end)
		end)
	end

	local physics = overridesFor("PhysicsService")
	physics.RegisterCollisionGroup = function() end
	physics.CollisionGroupSetCollidable = function() end
	physics.CollisionGroupsAreCollidable = function()
		return true
	end
	physics.IsCollisionGroupRegistered = function()
		return true
	end
	physics.UnregisterCollisionGroup = function() end
	physics.GetRegisteredCollisionGroups = function()
		return {}
	end

	local badges = overridesFor("BadgeService")
	badges.AwardBadge = function()
		return true
	end
	badges.UserHasBadgeAsync = function()
		return false
	end
	badges.GetBadgeInfoAsync = function()
		return { Name = "Badge", IsEnabled = true }
	end

	local chat = overridesFor("Chat")
	chat.FilterStringAsync = function(_, s)
		return s
	end
	chat.FilterStringForBroadcast = function(_, s)
		return s
	end
	chat.Chat = function() end

	local tcs = overridesFor("TextChatService")
	tcs.ChatVersion = Enum.ChatVersion.TextChatService
	tcs.MessageReceived = Signal.new("TextChatService.MessageReceived")
	tcs.SendingMessage = Signal.new("TextChatService.SendingMessage")
	tcs.DisplaySystemMessage = function() end

	local analytics = overridesFor("AnalyticsService")
	for _, name in
		{
			"LogCustomEvent",
			"LogEconomyEvent",
			"LogProgressionEvent",
			"LogOnboardingFunnelStepEvent",
			"LogFunnelStepEvent",
			"LogProgressionStartEvent",
			"LogProgressionCompleteEvent",
			"LogProgressionFailEvent",
		}
	do
		analytics[name] = function() end
	end

	local messaging = overridesFor("MessagingService")
	messaging.PublishAsync = function() end
	messaging.SubscribeAsync = function()
		return { Disconnect = function() end, Connected = true }
	end

	local teleport = overridesFor("TeleportService")
	teleport.GetLocalPlayerTeleportData = function()
		return nil
	end
	teleport.GetPlayerPlaceInstanceAsync = function()
		return false, "", 0, ""
	end
	teleport.Teleport = function() end
	teleport.TeleportAsync = function() end
	teleport.TeleportInitFailed = Signal.new("TeleportService.TeleportInitFailed")

	local lighting = overridesFor("Lighting")
	lighting.LightingChanged = Signal.new("Lighting.LightingChanged")
	lighting.GetMinutesAfterMidnight = function()
		return 14 * 60
	end
	lighting.SetMinutesAfterMidnight = function() end
	lighting.GetSunDirection = function()
		return roblox.Vector3.new(0, 1, 0)
	end
	lighting.GetMoonDirection = function()
		return roblox.Vector3.new(0, -1, 0)
	end

	local sound = overridesFor("SoundService")
	sound.PlayLocalSound = function() end
	sound.SetListener = function() end
	sound.GetListener = function()
		return Enum.ListenerType.Camera, nil
	end

	local ws = overridesFor("Workspace")
	ws.GetServerTimeNow = function()
		return os.time()
	end
	ws.GetRealPhysicsFPS = function()
		return 60
	end
	ws.Raycast = function()
		return nil
	end
	ws.Blockcast = ws.Raycast
	ws.Spherecast = ws.Raycast
	ws.Shapecast = ws.Raycast
	ws.GetPartsInPart = function()
		return {}
	end
	ws.GetPartBoundsInBox = function()
		return {}
	end
	ws.GetPartBoundsInRadius = function()
		return {}
	end
	ws.FindPartOnRay = function()
		return nil
	end
	ws.FindPartOnRayWithIgnoreList = function()
		return nil
	end
	ws.FindPartOnRayWithWhitelist = function()
		return nil
	end
	ws.FindPartsInRegion3 = function()
		return {}
	end
	ws.FindPartsInRegion3WithIgnoreList = function()
		return {}
	end
	ws.FindPartsInRegion3WithWhiteList = function()
		return {}
	end
	ws.BulkMoveTo = function() end
	ws.Terrain = true -- built lazily by applyOverrides
	ws.CurrentCamera = NIL -- set by the client boot
	ws.PersistentLoaded = Signal.new("Workspace.PersistentLoaded")

	-- Client-side services.
	local uis = overridesFor("UserInputService")
	for _, name in
		{
			"InputBegan",
			"InputEnded",
			"InputChanged",
			"TouchTap",
			"TouchStarted",
			"TouchEnded",
			"TouchMoved",
			"TouchSwipe",
			"TouchPinch",
			"TouchLongPress",
			"TouchPan",
			"TouchRotate",
			"JumpRequest",
			"LastInputTypeChanged",
			"GamepadConnected",
			"GamepadDisconnected",
			"WindowFocused",
			"WindowFocusReleased",
			"TextBoxFocused",
			"TextBoxFocusReleased",
			"DeviceAccelerationChanged",
			"DeviceGravityChanged",
			"DeviceRotationChanged",
		}
	do
		uis[name] = Signal.new(`UserInputService.{name}`)
	end
	uis.TouchEnabled = false
	uis.KeyboardEnabled = true
	uis.MouseEnabled = true
	uis.GamepadEnabled = false
	uis.VREnabled = false
	uis.AccelerometerEnabled = false
	uis.GyroscopeEnabled = false
	uis.OnScreenKeyboardVisible = false
	uis.MouseIconEnabled = true
	uis.MouseBehavior = Enum.MouseBehavior.Default
	uis.ModalEnabled = false
	uis.MouseDeltaSensitivity = 1
	uis.GetLastInputType = function()
		return Enum.UserInputType.MouseMovement
	end
	uis.GetMouseLocation = function()
		return roblox.Vector2.new(640, 360)
	end
	uis.GetMouseDelta = function()
		return roblox.Vector2.zero
	end
	uis.IsKeyDown = function()
		return false
	end
	uis.IsMouseButtonPressed = function()
		return false
	end
	uis.GetKeysPressed = function()
		return {}
	end
	uis.GetConnectedGamepads = function()
		return {}
	end
	uis.GetNavigationGamepads = function()
		return {}
	end
	uis.GetGamepadState = function()
		return {}
	end
	uis.GamepadSupports = function()
		return false
	end
	uis.GetFocusedTextBox = function()
		return nil
	end
	uis.GetDeviceType = function()
		return Enum.DeviceType.Desktop
	end
	uis.GetPlatform = function()
		return Enum.Platform.Windows
	end
	uis.GetStringForKeyCode = function(_, key)
		return key.Name
	end
	uis.GetImageForKeyCode = function()
		return ""
	end
	uis.SetNavigationGamepad = function() end

	local gui = overridesFor("GuiService")
	gui.TopbarInset = roblox.Rect.new(104, 2, 1176, 56)
	gui.SelectedObject = NIL
	gui.SelectedCoreObject = NIL
	gui.AutoSelectGuiEnabled = true
	gui.GuiNavigationEnabled = true
	gui.CoreGuiNavigationEnabled = true
	gui.MenuIsOpen = false
	gui.ReducedMotionEnabled = false
	gui.PreferredTransparency = 1
	gui.PreferredTextSize = Enum.PreferredTextSize.Medium
	gui.TouchControlsEnabled = true
	gui.ViewportDisplaySize = roblox.Vector2.new(1280, 720)
	gui.MenuOpened = Signal.new("GuiService.MenuOpened")
	gui.MenuClosed = Signal.new("GuiService.MenuClosed")
	gui.ErrorMessageChanged = Signal.new("GuiService.ErrorMessageChanged")
	gui.GetGuiInset = function()
		return roblox.Vector2.new(0, 58), roblox.Vector2.zero
	end
	gui.GetScreenResolution = function()
		return roblox.Vector2.new(1280, 720)
	end
	gui.IsTenFootInterface = function()
		return false
	end
	gui.GetEmotesMenuOpen = function()
		return false
	end
	gui.SetEmotesMenuOpen = function() end
	gui.GetInspectMenuEnabled = function()
		return false
	end
	gui.SetInspectMenuEnabled = function() end
	gui.Select = function() end
	gui.CloseInspectMenu = function() end
	gui.InspectPlayerFromUserId = function() end
	gui.GetHardwareSafeViewport = function()
		return roblox.Vector2.new(1280, 720)
	end
	gui.GetSafeZoneOffsets = function()
		return { top = 0, bottom = 0, left = 0, right = 0 }
	end
	gui.GetErrorType = function()
		return Enum.ConnectionError.OK
	end

	local cas = overridesFor("ContextActionService")
	cas.BindAction = function() end
	cas.BindActionAtPriority = function() end
	cas.UnbindAction = function() end
	cas.UnbindAllActions = function() end
	cas.SetTitle = function() end
	cas.SetImage = function() end
	cas.SetPosition = function() end
	cas.SetDescription = function() end
	cas.GetButton = function()
		return nil
	end
	cas.GetAllBoundActionInfo = function()
		return {}
	end
	cas.LocalToolEquipped = Signal.new("ContextActionService.LocalToolEquipped")
	cas.LocalToolUnequipped = Signal.new("ContextActionService.LocalToolUnequipped")

	local sg = overridesFor("StarterGui")
	sg.SetCoreGuiEnabled = function() end
	sg.SetCore = function() end
	sg.GetCore = function()
		return nil
	end
	sg.GetCoreGuiEnabled = function()
		return true
	end

	local vr = overridesFor("VRService")
	vr.VREnabled = false
	vr.AutomaticScaling = Enum.VRScaling.World
	vr.GetUserCFrame = function()
		return roblox.CFrame.identity
	end
	vr.GetUserCFrameEnabled = function()
		return false
	end
	vr.UserCFrameChanged = Signal.new("VRService.UserCFrameChanged")
	vr.NavigationRequested = Signal.new("VRService.NavigationRequested")

	local haptics = overridesFor("HapticService")
	haptics.SetMotor = function() end
	haptics.IsVibrationSupported = function()
		return false
	end
	haptics.IsMotorSupported = function()
		return false
	end

	local lang = overridesFor("LocalizationService")
	lang.RobloxLocaleId = "en-us"
	lang.SystemLocaleId = "en-us"
	lang.GetTranslatorForPlayerAsync = function()
		return {
			FormatByKey = function(_, key)
				return key
			end,
			Translate = function(_, _ctx, s)
				return s
			end,
			LocaleId = "en-us",
		}
	end
	lang.GetTranslatorForPlayer = lang.GetTranslatorForPlayerAsync
	lang.GetCountryRegionForPlayerAsync = function()
		return "US"
	end

	local cp = overridesFor("ContentProvider")
	cp.PreloadAsync = function() end
	cp.RequestQueueSize = 0

	local pf = overridesFor("PathfindingService")
	pf.CreatePath = function()
		return {
			Status = Enum.PathStatus.NoPath,
			ComputeAsync = function() end,
			GetWaypoints = function()
				return {}
			end,
			CheckOcclusionAsync = function()
				return -1
			end,
			Blocked = Signal.new("Path.Blocked"),
			Unblocked = Signal.new("Path.Unblocked"),
			Destroy = function() end,
		}
	end
	pf.FindPathAsync = pf.CreatePath

	local ss = overridesFor("SocialService")
	ss.CanSendGameInviteAsync = function()
		return false
	end
	ss.PromptGameInvite = function() end
	ss.GameInvitePromptClosed = Signal.new("SocialService.GameInvitePromptClosed")

	local ins = overridesFor("InsertService")
	ins.LoadAsset = function()
		return Instance.new("Model")
	end
	ins.LoadAssetVersion = ins.LoadAsset

	local stats = overridesFor("Stats")
	stats.GetTotalMemoryUsageMb = function()
		return 100
	end
	stats.GetMemoryUsageMbForTag = function()
		return 10
	end

	local experience = overridesFor("ExperienceNotificationService")
	experience.CanPromptOptInAsync = function()
		return false
	end
	experience.PromptOptIn = function() end

	local pps = overridesFor("ProximityPromptService")
	for _, name in
		{
			"PromptShown",
			"PromptHidden",
			"PromptTriggered",
			"PromptTriggerEnded",
			"PromptButtonHoldBegan",
			"PromptButtonHoldEnded",
		}
	do
		pps[name] = Signal.new(`ProximityPromptService.{name}`)
	end
	pps.Enabled = true
	pps.MaxPromptsVisible = 16

	local vas = overridesFor("VoiceChatService")
	vas.IsVoiceEnabledForUserIdAsync = function()
		return false
	end
end

-- Players ------------------------------------------------------------------

Shim.players = {} :: { any }

-- A player with a character standing at the spawn.
function Shim.newPlayer(game: any, userId: number, name: string?)
	local player = Shim.seed(Instance.new("Player"))
	player.Name = name or `Player{userId}`
	pcall(function()
		player.UserId = userId
	end)
	pcall(function()
		player.DisplayName = player.Name
	end)
	local character = Instance.new("Model")
	character.Name = player.Name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = roblox.Vector3.new(2, 2, 1)
	root.CFrame = roblox.CFrame.new(0, 3, 0)
	root.Position = roblox.Vector3.new(0, 3, 0)
	Shim.seed(root)
	root.Parent = character
	local humanoid = Shim.seed(Instance.new("Humanoid"))
	humanoid.Parent = character
	for _, limb in { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" } do
		local part = Instance.new("Part")
		part.Name = limb
		part.Size = roblox.Vector3.new(1, 1, 1)
		part.Parent = character
	end
	pcall(function()
		character.PrimaryPart = root
	end)
	character.Parent = game:GetService("Workspace")
	player.Character = character
	local gui = Instance.new("Folder")
	gui.Name = "PlayerGui"
	pcall(function()
		local real = Instance.new("PlayerGui")
		gui = real
	end)
	gui.Parent = player
	local scripts = Instance.new("Folder")
	scripts.Name = "PlayerScripts"
	scripts.Parent = player
	local backpack = Instance.new("Backpack")
	backpack.Parent = player
	player.Parent = game:GetService("Players")
	return player
end

-- Running code ---------------------------------------------------------------

local modules = {}
local loading = {}

-- Resolves "./X", "../X", "@self/X" the way Roblox does, from `from`.
local function resolveString(from: any, path: string): any
	local base
	local rest
	if string.sub(path, 1, 2) == "./" then
		base, rest = from.Parent, string.sub(path, 3)
	elseif string.sub(path, 1, 3) == "../" then
		base, rest = from.Parent and from.Parent.Parent, string.sub(path, 4)
	elseif string.sub(path, 1, 6) == "@self/" then
		base, rest = from, string.sub(path, 7)
	else
		error(`require("{path}") from {from:GetFullName()}: only ./, ../ and @self/ paths run in Roblox`, 3)
	end
	for _, segment in string.split(rest, "/") do
		if segment == ".." then
			base = base and base.Parent
		elseif segment ~= "." and segment ~= "" then
			base = base and base:FindFirstChild(segment)
		end
	end
	if base == nil then
		error(`require("{path}") from {from:GetFullName()}: nothing there`, 3)
	end
	return base
end

local baseEnv

function Shim.baseEnvironment(game: any)
	if baseEnv then
		return baseEnv
	end
	defineServices()
	applyOverrides(game)
	Shim.seedTree(game)

	local function wrapTask(name: string, fn)
		return function(f, ...)
			if type(f) ~= "function" then
				return fn(f, ...)
			end
			local args = table.pack(...)
			return fn(function()
				local ok, err = pcall(f, table.unpack(args, 1, args.n))
				if not ok then
					record(`task.{name}`, err)
				end
			end)
		end
	end
	local function wrapDelay(seconds, f, ...)
		local args = table.pack(...)
		return task.delay(seconds, function()
			local ok, err = pcall(f, table.unpack(args, 1, args.n))
			if not ok then
				record("task.delay", err)
			end
		end)
	end
	local taskLib = {
		spawn = wrapTask("spawn", task.spawn),
		defer = wrapTask("defer", task.defer),
		delay = wrapDelay,
		wait = task.wait,
		cancel = task.cancel,
		synchronize = function() end,
		desynchronize = function() end,
	}

	baseEnv = {
		-- Luau
		assert = assert,
		error = error,
		getmetatable = getmetatable,
		ipairs = ipairs,
		next = next,
		pairs = pairs,
		pcall = pcall,
		rawequal = rawequal,
		rawget = rawget,
		rawlen = rawlen,
		rawset = rawset,
		select = select,
		setmetatable = setmetatable,
		tonumber = tonumber,
		tostring = tostring,
		type = type,
		typeof = typeof,
		unpack = unpack,
		xpcall = xpcall,
		newproxy = newproxy,
		collectgarbage = collectgarbage,
		gcinfo = function()
			return collectgarbage("count")
		end,
		bit32 = bit32,
		buffer = buffer,
		coroutine = coroutine,
		debug = debug,
		math = math,
		os = os,
		string = string,
		table = table,
		utf8 = utf8,
		vector = vector,
		_G = {},
		shared = {},
		_VERSION = "Luau",
		print = function(...)
			say("", ...)
		end,
		warn = function(...)
			say("[warn] ", ...)
		end,
		-- Roblox
		game = game,
		Game = game,
		workspace = game:GetService("Workspace"),
		Workspace = game:GetService("Workspace"),
		task = taskLib,
		wait = task.wait,
		delay = wrapDelay,
		spawn = taskLib.spawn,
		tick = function()
			return os.time() + (os.clock() % 1)
		end,
		time = os.clock,
		elapsedTime = os.clock,
		settings = function()
			return { Rendering = {}, Physics = {}, Studio = {} }
		end,
		UserSettings = function()
			return {
				IsUserFeatureEnabled = function()
					return false
				end,
				GetService = function()
					return {
						SavedQualityLevel = Enum.SavedQualitySetting.Automatic,
						GetCameraYInvertValue = function()
							return 1
						end,
					}
				end,
			}
		end,
		Instance = setmetatable({
			new = function(className, parent)
				local inst = Shim.seed(Instance.new(className))
				if parent ~= nil then
					inst.Parent = parent
				end
				return inst
			end,
			fromExisting = function(existing)
				return Shim.seed(existing:Clone())
			end,
		}, { __index = Instance }),
		Enum = Enum,
		Axes = roblox.Axes,
		BrickColor = roblox.BrickColor,
		CFrame = roblox.CFrame,
		Color3 = roblox.Color3,
		ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		DateTime = DateTime,
		Faces = roblox.Faces,
		Font = roblox.Font,
		NumberRange = roblox.NumberRange,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		PhysicalProperties = roblox.PhysicalProperties,
		Random = Random,
		Ray = roblox.Ray,
		Rect = roblox.Rect,
		Region3 = roblox.Region3,
		Region3int16 = roblox.Region3int16,
		TweenInfo = TweenInfo,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		Vector2 = roblox.Vector2,
		Vector2int16 = roblox.Vector2int16,
		Vector3 = roblox.Vector3,
		Vector3int16 = roblox.Vector3int16,
		OverlapParams = {
			new = function()
				return {
					FilterDescendantsInstances = {},
					FilterType = Enum.RaycastFilterType.Exclude,
					MaxParts = 0,
					CollisionGroup = "Default",
					RespectCanCollide = false,
					AddToFilter = function() end,
				}
			end,
		},
		RaycastParams = {
			new = function()
				return {
					FilterDescendantsInstances = {},
					FilterType = Enum.RaycastFilterType.Exclude,
					IgnoreWater = false,
					CollisionGroup = "Default",
					RespectCanCollide = false,
					AddToFilter = function() end,
				}
			end,
		},
		PathWaypoint = {
			new = function(position, action, label)
				return { Position = position, Action = action, Label = label or "" }
			end,
		},
		CatalogSearchParams = {
			new = function()
				return {}
			end,
		},
		FloatCurveKey = {
			new = function(t, v)
				return { Time = t, Value = v }
			end,
		},
		RotationCurveKey = {
			new = function(t, v)
				return { Time = t, Value = v }
			end,
		},
		SharedTable = {
			new = function()
				return {}
			end,
		},
	}
	return baseEnv
end

-- Runs a script-like instance's Source with its own `script` and `require`.
-- What `x:Destroy()` becomes under Shim.detachOnDestroy: Destroying fires,
-- then x and its descendants leave the tree.
local function detach(inst: any)
	if inst == nil then
		return
	end
	signalOf(inst, "Destroying"):Fire()
	inst.Parent = nil
end

-- `x:Destroy()` on a plain name or field becomes `__shimDetach(x)`. A
-- rewrite that does not compile (an unusual expression) keeps the source.
function Shim.detachSource(source: string): string
	local rewritten = string.gsub(source, "([%w_][%w_%.%[%]\"']*):Destroy%(%)", "__shimDetach(%1)")
	if rewritten ~= source and pcall(luau.compile, rewritten) then
		return rewritten
	end
	return source
end

function Shim.runScript(game: any, inst: any, isModule: boolean): any
	local base = Shim.baseEnvironment(game)
	local env = setmetatable({ script = inst }, { __index = base })
	env.require = function(target)
		if type(target) == "string" then
			target = resolveString(inst, target)
		end
		if typeof(target) ~= "Instance" then
			error(`require expects a ModuleScript, got {typeof(target)} from {inst:GetFullName()}`, 2)
		end
		if not target:IsA("ModuleScript") then
			error(
				`{target:GetFullName()} is a {target.ClassName}, not a ModuleScript (required from {inst:GetFullName()})`,
				2
			)
		end
		if modules[target] ~= nil then
			return modules[target].value
		end
		if loading[target] then
			error(
				`require cycle: {target:GetFullName()} is already being required (from {inst:GetFullName()})`,
				2
			)
		end
		loading[target] = true
		local value = Shim.runScript(game, target, true)
		loading[target] = nil
		modules[target] = { value = value }
		return value
	end
	local source = inst.Source
	if Shim.detachOnDestroy then
		-- Lune refuses every read of a destroyed instance; Roblox allows it,
		-- and UI code often reads a label it just cleared. `x:Destroy()` on a
		-- plain name or field becomes a detach, which stays readable.
		local rewritten = Shim.detachSource(source)
		if rewritten ~= source then
			source = rewritten
			env.__shimDetach = detach
		end
	end
	local chunk = luau.load(source, {
		debugName = inst:GetFullName(),
		environment = env,
		injectGlobals = false,
	})
	local result = chunk()
	if isModule and result == nil then
		error(`{inst:GetFullName()} did not return a value`, 2)
	end
	return result
end

-- Forgets every loaded module (the client runs its own copies) but keeps the
-- tree, signals and services as the server left them.
function Shim.resetModules()
	modules = {}
	loading = {}
end

function Shim.reset()
	Shim.gaps = {}
	Shim.errors = {}
	Shim.output = {}
	Shim.players = {}
	Shim.closeHandlers = nil
	modules = {}
	loading = {}
	for k in instanceSignals do
		instanceSignals[k] = nil
	end
	for k in side do
		side[k] = nil
	end
	baseEnv = nil
	for k in serviceOverrides do
		serviceOverrides[k] = nil
	end
	for k in serviceValues do
		serviceValues[k] = nil
	end
	for k in dataStores do
		dataStores[k] = nil
	end
end

return Shim
