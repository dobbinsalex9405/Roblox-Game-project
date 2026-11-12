--!strict
-- Makes a full-screen window safe to open in first person.
--
-- In first person (or shift lock) Roblox locks the mouse to the middle of
-- the screen, so a window opened there cannot be clicked: its X is out of
-- reach and the player is stuck behind it (Staging playtest, Nov 12: the
-- Tower window opened from the elevator). Every window that opens over the
-- game therefore goes through `Modal.attach`, which, while the window shows:
--
--   * puts a dim backdrop behind it: a button with `Modal = true`, which is
--     Roblox's own way to free the mouse while a GUI is up, in first person
--     and shift lock alike, for as long as it shows;
--   * closes the window when the backdrop (anywhere outside it) is tapped;
--   * closes it on a gamepad's B button, and when the Roblox menu opens
--     (Escape on a keyboard, Back on Android), so there is always a way out
--     even without a pointer.
--
-- The window counts as open while its ScreenGui is enabled and the window
-- itself is visible; callers open and close it as before, by `Enabled` or
-- `Visible`, and the guard follows.

local Modal = {}

-- What the guard needs from Roblox, so the tests can run it without one.
export type Env = {
	new: (className: string) -> any,
	-- Calls `fn` whenever `property` of `instance` changes.
	watch: (instance: Instance, property: string, fn: () -> ()) -> (),
	-- Calls `fn` when `button` is activated (clicked or tapped).
	activated: (button: GuiButton, fn: () -> ()) -> (),
	-- Calls `fn` when the Roblox menu opens (Escape, or Back on Android).
	menuOpened: (fn: () -> ()) -> (),
	-- Binds `fn` to the gamepad's back button under `name`, or unbinds it.
	bindBack: (name: string, fn: () -> ()) -> (),
	unbindBack: (name: string) -> (),
}

export type Guard = {
	backdrop: TextButton,
	isOpen: () -> boolean,
}

local BACKDROP_TRANSPARENCY = 0.6
local count = 0

local function robloxEnv(): Env
	local ContextActionService = game:GetService("ContextActionService")
	local GuiService = game:GetService("GuiService")
	return {
		new = function(className: string): any
			return Instance.new(className)
		end,
		watch = function(instance: Instance, property: string, fn: () -> ())
			instance:GetPropertyChangedSignal(property):Connect(fn)
		end,
		activated = function(button: GuiButton, fn: () -> ())
			button.Activated:Connect(fn)
		end,
		menuOpened = function(fn: () -> ())
			GuiService.MenuOpened:Connect(fn)
		end,
		bindBack = function(name: string, fn: () -> ())
			ContextActionService:BindActionAtPriority(name, function(_, state: Enum.UserInputState)
				if state == Enum.UserInputState.Begin then
					fn()
					return Enum.ContextActionResult.Sink
				end
				return Enum.ContextActionResult.Pass
			end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonB)
		end,
		unbindBack = function(name: string)
			ContextActionService:UnbindAction(name)
		end,
	}
end

-- Guards `window` (a child of `gui`); `close` closes it the way the caller's
-- own X does.
function Modal.attach(gui: ScreenGui, window: GuiObject, close: () -> (), env: Env?): Guard
	local e = env or robloxEnv()
	count += 1
	local action = `CoreModalBack{count}`

	local backdrop = e.new("TextButton") :: TextButton
	backdrop.Name = "ModalBackdrop"
	backdrop.Modal = true
	backdrop.AutoButtonColor = false
	backdrop.Text = ""
	backdrop.BorderSizePixel = 0
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = BACKDROP_TRANSPARENCY
	-- Over the whole screen, top bar included, behind the window.
	backdrop.AnchorPoint = Vector2.new(0.5, 0.5)
	backdrop.Position = UDim2.fromScale(0.5, 0.5)
	backdrop.Size = UDim2.new(1, 200, 1, 200)
	backdrop.ZIndex = math.min(window.ZIndex, 1) - 1
	backdrop.Selectable = false
	backdrop.Visible = false
	backdrop.Parent = gui
	-- Clicks on the window itself stay in the window, not the backdrop.
	window.Active = true

	local function isOpen(): boolean
		return gui.Enabled and window.Visible and window.Parent ~= nil
	end

	local bound = false
	local function sync()
		local open = isOpen()
		backdrop.Visible = open
		if open and not bound then
			bound = true
			e.bindBack(action, function()
				if isOpen() then
					close()
				end
			end)
		elseif not open and bound then
			bound = false
			e.unbindBack(action)
		end
	end

	e.activated(backdrop, function()
		if isOpen() then
			close()
		end
	end)
	e.menuOpened(function()
		if isOpen() then
			close()
		end
	end)
	e.watch(gui, "Enabled", sync)
	e.watch(window, "Visible", sync)
	sync()

	return { backdrop = backdrop, isOpen = isOpen }
end

return Modal
