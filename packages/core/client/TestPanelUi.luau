--!strict
-- Studio-only test panel (server half: server/TestPanel.luau). A "Test" button
-- next to Shop opens buttons to add currency, own passes for the session, run
-- fake product purchases through the real receipt path (and replay them to
-- prove nothing is granted twice), run the game's own test actions (such as
-- giving any creature), and reset the save. It is never created
-- outside Studio, and the server ignores it outside Studio anyway.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ShopRemotes = require(ReplicatedStorage.Core.ShopRemotes)

local ClientNet = require(script.Parent.ClientNet)
local UiKit = require(script.Parent.UiKit)

type GameAction = { name: string, title: string, choices: { string } }

type Info = {
	currencies: { { key: string, balance: number } },
	passes: { { key: string, owned: boolean } },
	products: { string },
	actions: { GameAction }?,
}

local AMOUNTS = { 1000, 100000, 10000000 }

local TestPanelUi = {}

local function short(n: number): string
	if n >= 1e6 then
		return `{n // 1e6}M`
	elseif n >= 1e3 then
		return `{n // 1e3}K`
	end
	return tostring(n)
end

function TestPanelUi.start()
	if not RunService:IsStudio() then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "CoreTestPanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 35
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local button = UiKit.topbarButton(gui, "Test", 1, 72)
	button.BackgroundColor3 = Color3.fromRGB(120, 60, 160)

	local window, body = UiKit.window(gui, "Studio test panel", function()
		(gui:FindFirstChild("Window") :: Frame).Visible = false
	end)
	window.Position = UDim2.new(0, 16, 0.5, 0)
	window.AnchorPoint = Vector2.new(0, 0.5)

	local resultText = "Studio only. Nothing here exists on a live server."
	local info: Info? = nil
	local confirmResetUntil = 0
	local typed: { [string]: string } = {} -- each game action's text box, kept across redraws

	local function command(action: string, key: string, amount: number)
		ClientNet.fire(ShopRemotes["Test:Command"], action, key, amount)
	end

	local function render()
		UiKit.clear(body)
		local result = UiKit.label(body, resultText, 48)
		result.TextColor3 = Color3.fromRGB(255, 220, 90)
		result.LayoutOrder = 0
		if info == nil then
			UiKit.label(body, "Loading...", 20).LayoutOrder = 1
			return
		end
		local current = info :: Info
		local order = 1

		local function section(title: string): Frame
			order += 1
			local card = UiKit.card(body)
			card.LayoutOrder = order
			UiKit.label(card, title, 22, true)
			return card
		end

		local currencies = section("Currency")
		for _, c in current.currencies do
			UiKit.label(currencies, `{c.key}: {c.balance}`, 18)
			local row = UiKit.row(currencies, 32)
			for _, amount in AMOUNTS do
				UiKit.button(row, `+{short(amount)}`, 70, 30).Activated:Connect(function()
					command("currency", c.key, amount)
				end)
			end
			UiKit.button(row, "-1K", 60, 30, UiKit.WARN).Activated:Connect(function()
				command("currency", c.key, -1000)
			end)
		end

		local passes = section("Game passes (this session only)")
		if #current.passes == 0 then
			UiKit.label(passes, "This game has no passes.", 18)
		end
		for _, p in current.passes do
			local row = UiKit.row(passes, 32)
			local name = UiKit.label(row, `{p.key}{if p.owned then " (owned)" else ""}`, 30)
			name.Size = UDim2.new(1, -110, 0, 30)
			UiKit.button(
				row,
				if p.owned then "Remove" else "Give",
				100,
				30,
				if p.owned then UiKit.WARN else nil
			).Activated
				:Connect(function()
					command("pass", p.key, if p.owned then 0 else 1)
				end)
		end

		local products = section("Products (fake receipt through the real path)")
		if #current.products == 0 then
			UiKit.label(products, "No products are registered for this game yet.", 18)
		end
		for _, key in current.products do
			local row = UiKit.row(products, 32)
			local name = UiKit.label(row, key, 30)
			name.Size = UDim2.new(1, -196, 0, 30)
			UiKit.button(row, "Buy", 90, 30).Activated:Connect(function()
				command("product", key, 0)
			end)
			UiKit.button(row, "Replay", 90, 30, UiKit.MUTED).Activated:Connect(function()
				command("replay", key, 0)
			end)
		end

		-- The game's own actions (CoreServer addTestAction): a box to type any
		-- choice, then a button per choice.
		local gameActions: { GameAction } = current.actions or {}
		for _, action in gameActions do
			local card = section(action.title)
			local row = UiKit.row(card, 32)
			local box = Instance.new("TextBox")
			box.Size = UDim2.new(1, -100, 0, 30)
			box.PlaceholderText = "Type an id"
			box.Text = typed[action.name] or ""
			box.ClearTextOnFocus = false
			box.TextScaled = true
			box.Font = Enum.Font.Gotham
			box.TextColor3 = Color3.new(1, 1, 1)
			box.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
			box.LayoutOrder = 1
			box.Parent = row
			box:GetPropertyChangedSignal("Text"):Connect(function()
				typed[action.name] = box.Text
			end)
			local give = UiKit.button(row, "Give", 90, 30)
			give.LayoutOrder = 2
			give.Activated:Connect(function()
				local choice = string.gsub(box.Text, "%s", "")
				if choice ~= "" then
					command("game", `{action.name}/{choice}`, 0)
				end
			end)
			local choiceRow: Frame? = nil
			for index, choice in action.choices do
				if (index - 1) % 3 == 0 then
					choiceRow = UiKit.row(card, 32)
				end
				local b = UiKit.button(choiceRow :: Frame, choice, 110, 30, UiKit.MUTED)
				b.LayoutOrder = index
				b.Activated:Connect(function()
					command("game", `{action.name}/{choice}`, 0)
				end)
			end
		end

		local reset = section("Save")
		local resetButton = UiKit.button(
			reset,
			if os.clock() < confirmResetUntil then "Tap again to wipe the save" else "Reset my save",
			240,
			32,
			UiKit.WARN
		)
		resetButton.Activated:Connect(function()
			if os.clock() < confirmResetUntil then
				confirmResetUntil = 0
				command("reset", "", 0)
			else
				confirmResetUntil = os.clock() + 4
				render()
				task.delay(4.1, render)
			end
		end)
	end

	ClientNet.on(ShopRemotes["Test:Info"], function(newInfo: Info)
		info = newInfo
		render()
	end)
	ClientNet.on(ShopRemotes["Test:Result"], function(text: string)
		resultText = text
		render()
	end)

	button.Activated:Connect(function()
		window.Visible = not window.Visible
		if window.Visible then
			render()
			command("info", "", 0)
		end
	end)
end

return TestPanelUi
