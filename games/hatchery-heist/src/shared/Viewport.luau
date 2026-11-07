--!strict
-- Calls `onResize` now and whenever the screen changes size: the current
-- camera's ViewportSize, and a new CurrentCamera (Roblox can swap it). A
-- swapped-out camera no longer calls it. `world` is Workspace (any, so the
-- tests can pass a stand-in).
local Viewport = {}

function Viewport.watch(world: any, onResize: () -> ())
	local watched: any = nil
	local function watchCamera()
		local cam = world.CurrentCamera
		if cam and cam ~= watched then
			watched = cam
			cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				if watched == cam then
					onResize()
				end
			end)
		end
		onResize()
	end
	world:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	watchCamera()
end

return Viewport
