-- XENT HUB - Red/Dark Minimal UI
-- Place this as a LocalScript (e.g. StarterPlayer > StarterPlayerScripts)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- simple JSON-based config (uses exploit filesystem if available)
local canUseFS = typeof(isfile) == "function" and typeof(readfile) == "function" and typeof(writefile) == "function"
local CONFIG_FILE = "XentHubRed_" .. player.Name .. "_config.json"

local persistentConfig = {
	saveConfigs = true,
	toggles = {},
	booster = {
		speed = 16,
		jump = 20,
		gravity = 100,
	},
}

local function loadPersistentConfig()
	if not canUseFS then return end
	if not isfile(CONFIG_FILE) then return end
	local ok, data = pcall(readfile, CONFIG_FILE)
	if not ok or not data or data == "" then return end
	local okDecode, decoded = pcall(function()
		return HttpService:JSONDecode(data)
	end)
	if not okDecode or type(decoded) ~= "table" then return end
	if type(decoded.saveConfigs) == "boolean" then
		persistentConfig.saveConfigs = decoded.saveConfigs
	end
	if type(decoded.toggles) == "table" then
		persistentConfig.toggles = decoded.toggles
	end
	if type(decoded.booster) == "table" then
		local b = decoded.booster
		if type(b.speed) == "number" then persistentConfig.booster.speed = b.speed end
		if type(b.jump) == "number" then persistentConfig.booster.jump = b.jump end
		if type(b.gravity) == "number" then persistentConfig.booster.gravity = b.gravity end
	end
end

local function savePersistentConfig()
	if not canUseFS then return end
	local toWrite
	if not persistentConfig.saveConfigs then
		toWrite = {
			saveConfigs = false,
			toggles = {},
			booster = {
				speed = 16,
				jump = 20,
				gravity = 100,
			},
		}
	else
		toWrite = persistentConfig
	end
	local okEncode, encoded = pcall(function()
		return HttpService:JSONEncode(toWrite)
	end)
	if not okEncode then return end
	pcall(writefile, CONFIG_FILE, encoded)
end

local configDirty = false
local function markConfigDirty()
	if not persistentConfig.saveConfigs or not canUseFS then return end
	if configDirty then return end
	configDirty = true
	task.spawn(function()
		task.wait(0.1)
		configDirty = false
		savePersistentConfig()
	end)
end

loadPersistentConfig()

-- // Utility
local function createRounded(frame, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = frame
	return corner
end

local function createStroke(frame, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency or 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
	return stroke
end

local function createGradient(frame, c1, c2)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, c1),
		ColorSequenceKeypoint.new(1, c2),
	})
	gradient.Rotation = 90
	gradient.Parent = frame
	return gradient
end

local function makeDraggable(frame, dragHandle)
	dragHandle = dragHandle or frame
	local dragging = false
	local dragStart
	local startPos

	dragHandle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = frame.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
end

-- // ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "XentHubRedGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- // Main frame
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 430, 0, 260)
mainFrame.Position = UDim2.new(0.5, -215, 0.5, -130)
mainFrame.BackgroundColor3 = Color3.fromRGB(12, 10, 14)
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

createRounded(mainFrame, 12)
createStroke(mainFrame, Color3.fromRGB(180, 0, 30), 2, 0.15)
createGradient(mainFrame, Color3.fromRGB(30, 0, 0), Color3.fromRGB(6, 0, 0))

-- Top bar
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, 0, 0, 32)
topBar.BackgroundColor3 = Color3.fromRGB(20, 0, 4)
topBar.BorderSizePixel = 0
topBar.Parent = mainFrame

createRounded(topBar, 12)
createStroke(topBar, Color3.fromRGB(220, 20, 40), 1.2, 0.2)

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.BackgroundTransparency = 1
titleLabel.Size = UDim2.new(0, 220, 1, 0)
titleLabel.Position = UDim2.new(0, 14, 0, 0)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Text = "XENT HUB"
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.TextSize = 18
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
createGradient(titleLabel, Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 180, 180))

titleLabel.Parent = topBar

local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.AnchorPoint = Vector2.new(1, 0.5)
closeButton.Position = UDim2.new(1, -8, 0.5, 0)
closeButton.Size = UDim2.new(0, 22, 0, 22)
closeButton.BackgroundColor3 = Color3.fromRGB(40, 0, 8)
closeButton.Text = "X"
closeButton.Font = Enum.Font.GothamBold
closeButton.TextColor3 = Color3.fromRGB(255, 120, 120)
closeButton.TextSize = 14
closeButton.AutoButtonColor = false
closeButton.Parent = topBar

createRounded(closeButton, 6)
createStroke(closeButton, Color3.fromRGB(255, 70, 90), 1.4, 0.15)

-- Restore circle button (shown when main frame is hidden)
local restoreButton = Instance.new("TextButton")
restoreButton.Name = "XentRestoreButton"
restoreButton.Size = UDim2.new(0, 52, 0, 52)
restoreButton.Position = UDim2.new(0, 26, 0.78, 0)
restoreButton.BackgroundColor3 = Color3.fromRGB(30, 0, 4)
restoreButton.Text = "X"
restoreButton.Font = Enum.Font.GothamBold
restoreButton.TextSize = 20
restoreButton.TextColor3 = Color3.fromRGB(255, 130, 130)
restoreButton.AutoButtonColor = false
restoreButton.Visible = false
restoreButton.Parent = screenGui

createRounded(restoreButton, 26)
createStroke(restoreButton, Color3.fromRGB(255, 60, 90), 2, 0.12)

makeDraggable(mainFrame, topBar)
makeDraggable(restoreButton, restoreButton)

closeButton.MouseButton1Click:Connect(function()
	mainFrame.Visible = false
	restoreButton.Visible = true
end)

restoreButton.MouseButton1Click:Connect(function()
	mainFrame.Visible = true
	restoreButton.Visible = false
end)

-- // Nav + content
-- Left-side nav frame (similar layout to original XentHubUI, but red themed)
local navBar = Instance.new("Frame")
navBar.Name = "NavBar"
navBar.Size = UDim2.new(0, 110, 1, -40)
navBar.Position = UDim2.new(0, 0, 0, 36)
navBar.BackgroundColor3 = Color3.fromRGB(20, 0, 6)
navBar.BorderSizePixel = 0
navBar.Parent = mainFrame

createStroke(navBar, Color3.fromRGB(40, 0, 16), 1, 0.45)

local mainButton = Instance.new("TextButton")
mainButton.Name = "MainPageButton"
mainButton.Size = UDim2.new(1, -14, 0, 30)
mainButton.Position = UDim2.new(0, 7, 0, 4)
mainButton.BackgroundColor3 = Color3.fromRGB(60, 0, 10)
mainButton.Text = "Main"
mainButton.Font = Enum.Font.GothamSemibold
mainButton.TextSize = 16
mainButton.TextColor3 = Color3.fromRGB(255, 230, 230)
mainButton.AutoButtonColor = false
mainButton.Parent = navBar

createRounded(mainButton, 8)
createStroke(mainButton, Color3.fromRGB(255, 70, 90), 1.3, 0.12)

local miscButton = Instance.new("TextButton")
miscButton.Name = "MiscPageButton"
miscButton.Size = UDim2.new(1, -14, 0, 30)
miscButton.Position = UDim2.new(0, 7, 0, 40)
miscButton.BackgroundColor3 = Color3.fromRGB(40, 0, 8)
miscButton.Text = "Misc"
miscButton.Font = Enum.Font.GothamSemibold
miscButton.TextSize = 16
miscButton.TextColor3 = Color3.fromRGB(230, 210, 210)
miscButton.AutoButtonColor = false
miscButton.Parent = navBar

createRounded(miscButton, 8)
createStroke(miscButton, Color3.fromRGB(200, 40, 70), 1.1, 0.1)

local settingsButton = Instance.new("TextButton")
settingsButton.Name = "SettingsPageButton"
settingsButton.Size = UDim2.new(1, -14, 0, 30)
settingsButton.Position = UDim2.new(0, 7, 0, 76)
settingsButton.BackgroundColor3 = Color3.fromRGB(40, 0, 8)
settingsButton.Text = "Settings"
settingsButton.Font = Enum.Font.GothamSemibold
settingsButton.TextSize = 16
settingsButton.TextColor3 = Color3.fromRGB(230, 210, 210)
settingsButton.AutoButtonColor = false
settingsButton.Parent = navBar

createRounded(settingsButton, 8)
createStroke(settingsButton, Color3.fromRGB(200, 40, 70), 1.1, 0.1)

local contentFrame = Instance.new("Frame")
contentFrame.Name = "Content"
contentFrame.Size = UDim2.new(1, -128, 1, -46)
contentFrame.Position = UDim2.new(0, 118, 0, 40)
contentFrame.BackgroundColor3 = Color3.fromRGB(18, 0, 6)
contentFrame.BorderSizePixel = 0
contentFrame.ClipsDescendants = true
contentFrame.Parent = mainFrame

createRounded(contentFrame, 10)
createStroke(contentFrame, Color3.fromRGB(120, 0, 26), 1.4, 0.2)

local mainPage = Instance.new("Frame")
mainPage.Name = "MainPage"
mainPage.Size = UDim2.new(1, 0, 1, 0)
mainPage.BackgroundTransparency = 1
mainPage.Parent = contentFrame

local miscPage = Instance.new("Frame")
miscPage.Name = "MiscPage"
miscPage.Size = UDim2.new(1, 0, 1, 0)
miscPage.BackgroundTransparency = 1
miscPage.Visible = false
miscPage.Parent = contentFrame

local settingsPage = Instance.new("Frame")
settingsPage.Name = "SettingsPage"
settingsPage.Size = UDim2.new(1, 0, 1, 0)
settingsPage.BackgroundTransparency = 1
settingsPage.Visible = false
settingsPage.Parent = contentFrame

local header = Instance.new("TextLabel")
header.Name = "Header"
header.Size = UDim2.new(1, -10, 0, 26)
header.Position = UDim2.new(0, 6, 0, 0)
header.BackgroundTransparency = 1
header.Font = Enum.Font.GothamBold
header.TextSize = 18
header.TextXAlignment = Enum.TextXAlignment.Left
header.Text = "Main"
header.TextColor3 = Color3.fromRGB(255, 240, 240)
header.Parent = mainPage

local optionsHolder = Instance.new("Frame")
optionsHolder.Name = "OptionsHolder"
optionsHolder.Size = UDim2.new(1, -12, 1, -34)
optionsHolder.Position = UDim2.new(0, 6, 0, 30)
optionsHolder.BackgroundTransparency = 1
optionsHolder.Parent = mainPage

local optionsList = Instance.new("UIListLayout")
optionsList.Padding = UDim.new(0, 8)
optionsList.FillDirection = Enum.FillDirection.Vertical
optionsList.HorizontalAlignment = Enum.HorizontalAlignment.Center
optionsList.VerticalAlignment = Enum.VerticalAlignment.Top
optionsList.SortOrder = Enum.SortOrder.LayoutOrder
optionsList.Parent = optionsHolder

local miscHeader = Instance.new("TextLabel")
miscHeader.Name = "Header"
miscHeader.Size = UDim2.new(1, -10, 0, 26)
miscHeader.Position = UDim2.new(0, 6, 0, 0)
miscHeader.BackgroundTransparency = 1
miscHeader.Font = Enum.Font.GothamBold
miscHeader.TextSize = 18
miscHeader.TextXAlignment = Enum.TextXAlignment.Left
miscHeader.Text = "Misc"
miscHeader.TextColor3 = Color3.fromRGB(255, 240, 240)
miscHeader.Parent = miscPage

local miscOptionsHolder = Instance.new("Frame")
miscOptionsHolder.Name = "OptionsHolder"
miscOptionsHolder.Size = UDim2.new(1, -12, 1, -34)
miscOptionsHolder.Position = UDim2.new(0, 6, 0, 30)
miscOptionsHolder.BackgroundTransparency = 1
miscOptionsHolder.Parent = miscPage

local miscOptionsList = Instance.new("UIListLayout")
miscOptionsList.Padding = UDim.new(0, 8)
miscOptionsList.FillDirection = Enum.FillDirection.Vertical
miscOptionsList.HorizontalAlignment = Enum.HorizontalAlignment.Center
miscOptionsList.VerticalAlignment = Enum.VerticalAlignment.Top
miscOptionsList.SortOrder = Enum.SortOrder.LayoutOrder
miscOptionsList.Parent = miscOptionsHolder

local settingsHeader = Instance.new("TextLabel")
settingsHeader.Name = "Header"
settingsHeader.Size = UDim2.new(1, -10, 0, 26)
settingsHeader.Position = UDim2.new(0, 6, 0, 0)
settingsHeader.BackgroundTransparency = 1
settingsHeader.Font = Enum.Font.GothamBold
settingsHeader.TextSize = 18
settingsHeader.TextXAlignment = Enum.TextXAlignment.Left
settingsHeader.Text = "Settings"
settingsHeader.TextColor3 = Color3.fromRGB(255, 240, 240)
settingsHeader.Parent = settingsPage

local settingsOptionsHolder = Instance.new("Frame")
settingsOptionsHolder.Name = "OptionsHolder"
settingsOptionsHolder.Size = UDim2.new(1, -12, 1, -34)
settingsOptionsHolder.Position = UDim2.new(0, 6, 0, 30)
settingsOptionsHolder.BackgroundTransparency = 1
settingsOptionsHolder.Parent = settingsPage

local settingsOptionsList = Instance.new("UIListLayout")
settingsOptionsList.Padding = UDim.new(0, 8)
settingsOptionsList.FillDirection = Enum.FillDirection.Vertical
settingsOptionsList.HorizontalAlignment = Enum.HorizontalAlignment.Center
settingsOptionsList.VerticalAlignment = Enum.VerticalAlignment.Top
settingsOptionsList.SortOrder = Enum.SortOrder.LayoutOrder
settingsOptionsList.Parent = settingsOptionsHolder

local function createToggleRow(labelText)
	local row = Instance.new("Frame")
	row.Name = labelText .. "Row"
	row.Size = UDim2.new(1, 0, 0, 46)
	row.BackgroundColor3 = Color3.fromRGB(22, 0, 6)
	row.BorderSizePixel = 0
	row.Parent = optionsHolder

	createRounded(row, 10)
	createStroke(row, Color3.fromRGB(120, 0, 25), 1.3, 0.2)

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -90, 0, 20)
	label.Position = UDim2.new(0, 10, 0, 4)
	label.Font = Enum.Font.GothamSemibold
	label.Text = labelText
	label.TextSize = 16
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(255, 225, 225)
	label.Parent = row

	local toggleButton = Instance.new("TextButton")
	toggleButton.Name = "ToggleButton"
	toggleButton.AnchorPoint = Vector2.new(1, 0.5)
	toggleButton.Position = UDim2.new(1, -10, 0.5, 0)
	toggleButton.Size = UDim2.new(0, 52, 0, 22)
	toggleButton.BackgroundColor3 = Color3.fromRGB(40, 0, 10)
	toggleButton.Text = ""
	toggleButton.AutoButtonColor = false
	toggleButton.Parent = row

	createRounded(toggleButton, 12)
	createStroke(toggleButton, Color3.fromRGB(255, 80, 110), 1.4, 0.2)

	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.Size = UDim2.new(0, 20, 0, 18)
	knob.Position = UDim2.new(0, 2, 0.5, -9)
	knob.BackgroundColor3 = Color3.fromRGB(255, 220, 220)
	knob.BorderSizePixel = 0
	knob.Parent = toggleButton

	createRounded(knob, 10)
	createStroke(knob, Color3.fromRGB(255, 255, 255), 1, 0.1)

	return row, toggleButton, knob
end

local function createSettingsButton(labelText)
	local button = Instance.new("TextButton")
	button.Name = labelText .. "Button"
	button.Size = UDim2.new(1, 0, 0, 34)
	button.BackgroundColor3 = Color3.fromRGB(22, 0, 6)
	button.Text = labelText
	button.Font = Enum.Font.GothamSemibold
	button.TextSize = 14
	button.TextColor3 = Color3.fromRGB(255, 225, 225)
	button.AutoButtonColor = true
	button.BorderSizePixel = 0
	button.Parent = settingsOptionsHolder

	createRounded(button, 10)
	createStroke(button, Color3.fromRGB(120, 0, 25), 1.3, 0.2)

	return button
end

local function createMiscToggleRow(labelText)
	local row = Instance.new("Frame")
	row.Name = labelText .. "Row"
	row.Size = UDim2.new(1, 0, 0, 38)
	row.BackgroundColor3 = Color3.fromRGB(22, 0, 6)
	row.BorderSizePixel = 0
	row.Parent = miscOptionsHolder

	createRounded(row, 10)
	createStroke(row, Color3.fromRGB(120, 0, 25), 1.3, 0.2)

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -90, 0, 20)
	label.Position = UDim2.new(0, 10, 0, 4)
	label.Font = Enum.Font.GothamSemibold
	label.Text = labelText
	label.TextSize = 16
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(255, 225, 225)
	label.Parent = row

	local toggleButton = Instance.new("TextButton")
	toggleButton.Name = "ToggleButton"
	toggleButton.AnchorPoint = Vector2.new(1, 0.5)
	toggleButton.Position = UDim2.new(1, -10, 0.5, 0)
	toggleButton.Size = UDim2.new(0, 52, 0, 22)
	toggleButton.BackgroundColor3 = Color3.fromRGB(40, 0, 10)
	toggleButton.Text = ""
	toggleButton.AutoButtonColor = false
	toggleButton.Parent = row

	createRounded(toggleButton, 12)
	createStroke(toggleButton, Color3.fromRGB(255, 80, 110), 1.4, 0.2)

	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.Size = UDim2.new(0, 20, 0, 18)
	knob.Position = UDim2.new(0, 2, 0.5, -9)
	knob.BackgroundColor3 = Color3.fromRGB(255, 220, 220)
	knob.BorderSizePixel = 0
	knob.Parent = toggleButton

	createRounded(knob, 10)
	createStroke(knob, Color3.fromRGB(255, 255, 255), 1, 0.1)

	return row, toggleButton, knob
end

local boosterRow, boosterToggleButton, boosterKnob = createToggleRow("XENT BOOSTER")

local boosterHint = Instance.new("TextLabel")
boosterHint.Name = "Hint"
boosterHint.BackgroundTransparency = 1
boosterHint.Size = UDim2.new(1, -90, 0, 16)
boosterHint.Position = UDim2.new(0, 10, 0, 26)
boosterHint.Font = Enum.Font.Gotham
boosterHint.TextSize = 12
boosterHint.TextXAlignment = Enum.TextXAlignment.Left
boosterHint.TextColor3 = Color3.fromRGB(230, 180, 180)
boosterHint.Text = "Speed, jump and gravity booster"
boosterHint.Parent = boosterRow

-- Auto Grab toggle row under XENT BOOSTER
local autoGrabRow, autoGrabToggleButton, autoGrabKnob = createToggleRow("Auto Grab")
autoGrabRow.Size = UDim2.new(1, 0, 0, 38)

-- Xray toggle row under Auto Grab
local xrayRow, xrayToggleButton, xrayKnob = createToggleRow("Xray")

-- Misc: Brainrot ESP toggle row
local brainrotRow, brainrotEspToggleButton, brainrotEspKnob = createMiscToggleRow("Brainrot ESP")

-- Misc: Auto kick after steal toggle row
local autoKickRow, autoKickToggleButton, autoKickKnob = createMiscToggleRow("Auto kick")

-- Misc: Anti Steal toggle row
local antiStealRow, antiStealToggleButton, antiStealKnob = createMiscToggleRow("Anti Steal")

local antiStealHint = Instance.new("TextLabel")
antiStealHint.Name = "Hint"
antiStealHint.BackgroundTransparency = 1
antiStealHint.Size = UDim2.new(1, -90, 0, 16)
antiStealHint.Position = UDim2.new(0, 10, 0, 22)
antiStealHint.Font = Enum.Font.Gotham
antiStealHint.TextSize = 11
antiStealHint.TextXAlignment = Enum.TextXAlignment.Left
antiStealHint.TextColor3 = Color3.fromRGB(230, 180, 180)
antiStealHint.Text = "Body-swaps if someone is stealing your brainrot."
antiStealHint.Parent = antiStealRow

local copyDiscordButton = createSettingsButton("Copy discord link")

local saveConfigRow = Instance.new("Frame")
saveConfigRow.Name = "SaveConfigRow"
saveConfigRow.Size = UDim2.new(1, 0, 0, 40)
saveConfigRow.BackgroundColor3 = Color3.fromRGB(22, 0, 6)
saveConfigRow.BorderSizePixel = 0
saveConfigRow.Parent = settingsOptionsHolder

createRounded(saveConfigRow, 10)
createStroke(saveConfigRow, Color3.fromRGB(120, 0, 25), 1.3, 0.2)

local saveLabel = Instance.new("TextLabel")
saveLabel.Name = "Label"
saveLabel.BackgroundTransparency = 1
saveLabel.Size = UDim2.new(1, -90, 0, 20)
saveLabel.Position = UDim2.new(0, 10, 0, 4)
saveLabel.Font = Enum.Font.GothamSemibold
saveLabel.Text = "Save Configs"
saveLabel.TextSize = 16
saveLabel.TextXAlignment = Enum.TextXAlignment.Left
saveLabel.TextColor3 = Color3.fromRGB(255, 225, 225)
saveLabel.Parent = saveConfigRow

local saveToggleButton = Instance.new("TextButton")
saveToggleButton.Name = "ToggleButton"
saveToggleButton.AnchorPoint = Vector2.new(1, 0.5)
saveToggleButton.Position = UDim2.new(1, -10, 0.5, 0)
saveToggleButton.Size = UDim2.new(0, 52, 0, 22)
saveToggleButton.BackgroundColor3 = Color3.fromRGB(40, 0, 10)
saveToggleButton.Text = ""
saveToggleButton.AutoButtonColor = false
saveToggleButton.Parent = saveConfigRow

createRounded(saveToggleButton, 12)
createStroke(saveToggleButton, Color3.fromRGB(255, 80, 110), 1.4, 0.2)

local saveKnob = Instance.new("Frame")
saveKnob.Name = "Knob"
saveKnob.Size = UDim2.new(0, 20, 0, 18)
saveKnob.Position = UDim2.new(0, 2, 0.5, -9)
saveKnob.BackgroundColor3 = Color3.fromRGB(255, 220, 220)
saveKnob.BorderSizePixel = 0
saveKnob.Parent = saveToggleButton

createRounded(saveKnob, 10)
createStroke(saveKnob, Color3.fromRGB(255, 255, 255), 1, 0.1)

local saveConfigsOn = true

local function showDiscordToast()
	local toast = Instance.new("Frame")
	toast.Name = "DiscordToast"
	toast.AnchorPoint = Vector2.new(1, 1)
	toast.Size = UDim2.new(0, 230, 0, 60)
	toast.Position = UDim2.new(1, -16, 1, -16)
	toast.BackgroundColor3 = Color3.fromRGB(20, 0, 6)
	toast.BorderSizePixel = 0
	toast.Parent = screenGui

	createRounded(toast, 10)
	createStroke(toast, Color3.fromRGB(200, 40, 70), 1.2, 0.2)

	local mainLabel = Instance.new("TextLabel")
	mainLabel.BackgroundTransparency = 1
	mainLabel.Size = UDim2.new(1, -12, 0, 30)
	mainLabel.Position = UDim2.new(0, 6, 0, 4)
	mainLabel.Font = Enum.Font.GothamSemibold
	mainLabel.TextSize = 14
	mainLabel.TextXAlignment = Enum.TextXAlignment.Left
	mainLabel.TextColor3 = Color3.fromRGB(255, 240, 240)
	mainLabel.Text = "Paste Discord link in Discord"
	mainLabel.Parent = toast

	local subLabel = Instance.new("TextLabel")
	subLabel.BackgroundTransparency = 1
	subLabel.Size = UDim2.new(1, -12, 0, 20)
	subLabel.Position = UDim2.new(0, 6, 0, 34)
	subLabel.Font = Enum.Font.Gotham
	subLabel.TextSize = 12
	subLabel.TextXAlignment = Enum.TextXAlignment.Left
	subLabel.TextColor3 = Color3.fromRGB(220, 180, 180)
	subLabel.Text = "XENT HUB"
	subLabel.Parent = toast

	toast.BackgroundTransparency = 0
	mainLabel.TextTransparency = 0
	subLabel.TextTransparency = 0

	task.spawn(function()
		task.wait(2.2)
		local info = TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		TweenService:Create(toast, info, {BackgroundTransparency = 1}):Play()
		TweenService:Create(mainLabel, info, {TextTransparency = 1}):Play()
		TweenService:Create(subLabel, info, {TextTransparency = 1}):Play()
		task.wait(0.4)
		if toast then
			toast:Destroy()
		end
	end)
end

local function copyDiscordLink()
	local link = "https://discord.gg/xenthub"
	if typeof(setclipboard) == "function" then
		pcall(function()
			setclipboard(link)
		end)
	end
	showDiscordToast()
end

-- Booster UI state and separate floating frame
local speedBox
local jumpBox
local gravityBox
local boosterFrame
local boosterHeader
local boosterContent
local boosterSwitchButton
local boosterSwitchKnob
local boosterVisible = false
local boosterOpen = true

-- Nav highlighting / page switching
local function setNavButtonVisual(button, active)
	local bg = active and Color3.fromRGB(90, 0, 16) or Color3.fromRGB(60, 0, 6)
	local txt = active and Color3.fromRGB(255, 240, 240) or Color3.fromRGB(220, 200, 200)
	TweenService:Create(button, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		BackgroundColor3 = bg,
		TextColor3 = txt,
	}):Play()
end

-- Brainrot ESP visual for Misc toggle
local function setBrainrotEspVisual(on)
	local goalPos = on and UDim2.new(1, -22, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
	local knobColor = on and Color3.fromRGB(255, 250, 250) or Color3.fromRGB(255, 220, 220)
	local baseColor = on and Color3.fromRGB(200, 0, 40) or Color3.fromRGB(40, 0, 10)

	TweenService:Create(brainrotEspKnob, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Position = goalPos,
		BackgroundColor3 = knobColor,
	}):Play()

	TweenService:Create(brainrotEspToggleButton, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		BackgroundColor3 = baseColor,
	}):Play()
end

local function setActivePage(name)
	mainPage.Visible = (name == "Main")
	miscPage.Visible = (name == "Misc")
	settingsPage.Visible = (name == "Settings")
	setNavButtonVisual(mainButton, name == "Main")
	setNavButtonVisual(miscButton, name == "Misc")
	setNavButtonVisual(settingsButton, name == "Settings")
end

setActivePage("Main")

mainButton.MouseButton1Click:Connect(function()
	setActivePage("Main")
end)

miscButton.MouseButton1Click:Connect(function()
	setActivePage("Misc")
end)

settingsButton.MouseButton1Click:Connect(function()
	setActivePage("Settings")
end)
copyDiscordButton.MouseButton1Click:Connect(function()
	copyDiscordLink()
end)
saveToggleButton.MouseButton1Click:Connect(function()
	saveConfigsOn = not saveConfigsOn
	setSaveConfigsVisual(saveConfigsOn)
end)

-- // XENT BOOSTER logic (copied from XentHubUI with same behavior)

local function getHumanoid()
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")
	return humanoid
end

local humanoid = getHumanoid()
local defaultWalkSpeed = humanoid.WalkSpeed
local useJumpPower = humanoid.UseJumpPower
local defaultJumpValue = useJumpPower and humanoid.JumpPower or humanoid.JumpHeight
local defaultGravity = workspace.Gravity
local autoGrabEnabled = false
local autoGrabConnection
local brainrotBillboard = nil
local brainrotEspEnabled = false
local brainrotEspConn = nil
local brainrotEspAccum = 0
local brainrotCurrentSource = nil
local autoKickAfterStealEnabled = false
local autoKickTextConnections = {}
local autoKickDescendantConnection
local antiStealEnabled = false
local antiStealConn = nil
local antiStealAccum = 0
local antiStealLastTrigger = 0
local xrayEnabled = false
local xrayConnection
local xrayFromAttachment
local xrayBrainrotAttachment
local xrayNicknameAttachment
local xrayBrainrotBeam
local xrayNicknameBeam

local speedBoostActive = false
local jumpVectorForce = nil
local gravityVectorForce = nil

local savedConfig = {
	speed = persistentConfig.booster.speed or 16,
	jump = persistentConfig.booster.jump or 20,
	gravity = persistentConfig.booster.gravity or 100,
}

local function setSaveConfigsVisual(on)
	local goalPos = on and UDim2.new(1, -22, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
	local knobColor = on and Color3.fromRGB(255, 250, 250) or Color3.fromRGB(255, 220, 220)
	local baseColor = on and Color3.fromRGB(200, 0, 40) or Color3.fromRGB(40, 0, 10)
	local textColor = on and Color3.fromRGB(255, 235, 235) or Color3.fromRGB(220, 190, 190)
	local labelText = on and "Save Configs (ON)" or "Save Configs (OFF)"

	TweenService:Create(saveKnob, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Position = goalPos,
		BackgroundColor3 = knobColor,
	}):Play()

	TweenService:Create(saveToggleButton, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		BackgroundColor3 = baseColor,
	}):Play()

	if saveLabel then
		saveLabel.Text = labelText
		saveLabel.TextColor3 = textColor
	end
end

local function snapRuntimeToPersistent()
	persistentConfig.toggles = persistentConfig.toggles or {}
	local t = persistentConfig.toggles
	t.boosterMain = boosterVisible
	t.boosterBoost = speedEnabled
	t.autoGrab = autoGrabEnabled
	t.xray = xrayEnabled
	t.brainrotEsp = brainrotEspEnabled
	t.autoKick = autoKickAfterStealEnabled
	t.antiSteal = antiStealEnabled

	persistentConfig.booster = persistentConfig.booster or {}
	persistentConfig.booster.speed = savedConfig.speed
	persistentConfig.booster.jump = savedConfig.jump
	persistentConfig.booster.gravity = savedConfig.gravity
end

local function setSaveConfigsEnabled(on)
	if persistentConfig.saveConfigs == on then
		return
	end
	persistentConfig.saveConfigs = on
	setSaveConfigsVisual(on)
	if not canUseFS then return end
	if on then
		snapRuntimeToPersistent()
		savePersistentConfig()
	else
		savePersistentConfig()
	end
end

local speedEnabled = false

local function setBoosterVisual(on)
	local goalPos = on and UDim2.new(1, -22, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
	local knobColor = on and Color3.fromRGB(255, 250, 250) or Color3.fromRGB(255, 220, 220)
	local baseColor = on and Color3.fromRGB(200, 0, 40) or Color3.fromRGB(40, 0, 10)

	TweenService:Create(boosterKnob, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Position = goalPos,
		BackgroundColor3 = knobColor,
	}):Play()

	TweenService:Create(boosterToggleButton, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		BackgroundColor3 = baseColor,
	}):Play()
end

local function setBoosterSwitchVisual(on)
	if not boosterSwitchKnob or not boosterSwitchButton then return end
	local goalPos = on and UDim2.new(1, -20, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
	local knobColor = on and Color3.fromRGB(255, 250, 250) or Color3.fromRGB(255, 220, 220)
	local baseColor = on and Color3.fromRGB(200, 0, 40) or Color3.fromRGB(40, 0, 10)

	TweenService:Create(boosterSwitchKnob, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Position = goalPos,
		BackgroundColor3 = knobColor,
	}):Play()

	TweenService:Create(boosterSwitchButton, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		BackgroundColor3 = baseColor,
	}):Play()
end

local function clampValues()
	-- Same clamping logic as in XentHubUI.lua, driven by the three TextBoxes
	local s = tonumber(speedBox and speedBox.Text)
	local j = tonumber(jumpBox and jumpBox.Text)
	local g = tonumber(gravityBox and gravityBox.Text)
	local changed = false

	if s then
		s = math.clamp(s, 0, 50)
		savedConfig.speed = s
		persistentConfig.booster.speed = s
		changed = true
	end
	if j then
		j = math.clamp(j, 0, 50)
		savedConfig.jump = j
		persistentConfig.booster.jump = j
		changed = true
	end
	if g then
		g = math.clamp(g, 0, 400)
		savedConfig.gravity = g
		persistentConfig.booster.gravity = g
		changed = true
	end

	if changed then
		markConfigDirty()
	end
end

-- Brainrot ESP (ported from XentHubUI.lua)

local function clearBrainrotBillboard()
	if brainrotBillboard and brainrotBillboard.Parent then
		brainrotBillboard:Destroy()
	end
	brainrotBillboard = nil
end

local function findHighestBrainrotSource()
	local bestGui = nil
	local bestValue = nil
	local inspected = 0
	for _, inst in ipairs(workspace:GetDescendants()) do
		if inst:IsA("TextLabel") or inst:IsA("TextBox") then
			local text = inst.Text
			if type(text) == "string" and text ~= "" and string.find(text, "M/s", 1, true) then
				local numStr = string.match(text, "%$?%s*([%d%.]+)%s*[Mm]/s")
				if numStr then
					local value = tonumber(numStr)
					if value then
						local guiAncestor = inst:FindFirstAncestorWhichIsA("BillboardGui")
							or inst:FindFirstAncestorWhichIsA("SurfaceGui")
						if guiAncestor and (not bestValue or value > bestValue) then
							bestValue = value
							bestGui = guiAncestor
						end
					end
				end
			end
		end
		inspected = inspected + 1
		if inspected % 400 == 0 then
			task.wait()
		end
	end
	return bestGui, bestValue
end

local function getBrainrotNameFromGui(sourceGui)
	if not sourceGui then return nil end
	for _, inst in ipairs(sourceGui:GetDescendants()) do
		if inst:IsA("TextLabel") or inst:IsA("TextBox") then
			local text = inst.Text
			if type(text) == "string" and text ~= "" then
				if not string.find(text, "M/s", 1, true)
					and not string.find(text, "%$", 1, true)
					and string.find(text, "%a") then
					return text
				end
			end
		end
	end
	return nil
end

local function createBrainrotBillboard(sourceGui, value)
	if not sourceGui then return end
	local adornee = sourceGui.Adornee
	local parentForNew
	if adornee then
		parentForNew = adornee
	else
		parentForNew = sourceGui.Parent
	end
	if not parentForNew then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "BrainrotESPBillboard"
	billboard.Size = UDim2.new(0, 140, 0, 40)
	billboard.StudsOffset = Vector3.new(0, 2.2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parentForNew

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "BrainrotNameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
	nameLabel.Position = UDim2.new(0, 0, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = getBrainrotNameFromGui(sourceGui) or "?"
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	nameLabel.TextStrokeTransparency = 0
	nameLabel.Parent = billboard

	local moneyLabel = Instance.new("TextLabel")
	moneyLabel.Name = "BrainrotMoneyLabel"
	moneyLabel.Size = UDim2.new(1, 0, 0.5, 0)
	moneyLabel.Position = UDim2.new(0, 0, 0.5, 0)
	moneyLabel.BackgroundTransparency = 1
	moneyLabel.Text = string.format("$%sM/s", tostring(value or "?"))
	moneyLabel.Font = Enum.Font.GothamBold
	moneyLabel.TextScaled = true
	moneyLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
	moneyLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	moneyLabel.TextStrokeTransparency = 0
	moneyLabel.Parent = billboard

	brainrotBillboard = billboard
end

local function runBrainrotScan()
	local sourceGui, value = findHighestBrainrotSource()
	if not brainrotEspEnabled then
		clearBrainrotBillboard()
		brainrotCurrentSource = nil
		return
	end

	if not sourceGui then
		return
	end

	if brainrotBillboard and brainrotCurrentSource == sourceGui and brainrotBillboard.Parent then
		local nameLabel = brainrotBillboard:FindFirstChild("BrainrotNameLabel")
		local moneyLabel = brainrotBillboard:FindFirstChild("BrainrotMoneyLabel")
		if nameLabel and nameLabel:IsA("TextLabel") then
			nameLabel.Text = getBrainrotNameFromGui(sourceGui) or "?"
		end
		if moneyLabel and moneyLabel:IsA("TextLabel") then
			moneyLabel.Text = string.format("$%sM/s", tostring(value or "?"))
		end
		return
	end

	brainrotCurrentSource = sourceGui
	clearBrainrotBillboard()
	createBrainrotBillboard(sourceGui, value)
end

local function startBrainrotEsp()
	if brainrotEspConn then
		brainrotEspConn:Disconnect()
		brainrotEspConn = nil
	end
	brainrotEspAccum = 0
	brainrotEspConn = RunService.Heartbeat:Connect(function(dt)
		if not brainrotEspEnabled then
			return
		end
		brainrotEspAccum = brainrotEspAccum + dt
		if brainrotEspAccum >= 1 then
			brainrotEspAccum = 0
			runBrainrotScan()
		end
	end)
	runBrainrotScan()
end

local function stopBrainrotEsp()
	if brainrotEspConn then
		brainrotEspConn:Disconnect()
		brainrotEspConn = nil
	end
	clearBrainrotBillboard()
end

local function setBrainrotEspEnabled(on)
	if brainrotEspEnabled == on then return end
	brainrotEspEnabled = on
	setBrainrotEspVisual(on)
	if on then
		startBrainrotEsp()
	else
		stopBrainrotEsp()
	end
end

local function setAutoKickVisual(on)
	local goalPos = on and UDim2.new(1, -22, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
	local knobColor = on and Color3.fromRGB(255, 250, 250) or Color3.fromRGB(255, 220, 220)
	local baseColor = on and Color3.fromRGB(200, 0, 40) or Color3.fromRGB(40, 0, 10)

	TweenService:Create(autoKickKnob, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Position = goalPos,
		BackgroundColor3 = knobColor,
	}):Play()

	TweenService:Create(autoKickToggleButton, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		BackgroundColor3 = baseColor,
	}):Play()
end

local function setAutoGrabVisual(on)
	local goalPos = on and UDim2.new(1, -22, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
	local knobColor = on and Color3.fromRGB(255, 250, 250) or Color3.fromRGB(255, 220, 220)
	local baseColor = on and Color3.fromRGB(200, 0, 40) or Color3.fromRGB(40, 0, 10)

	TweenService:Create(autoGrabKnob, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Position = goalPos,
		BackgroundColor3 = knobColor,
	}):Play()

	TweenService:Create(autoGrabToggleButton, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		BackgroundColor3 = baseColor,
	}):Play()
end

local function applyBoost()
	clampValues()

	humanoid = getHumanoid()

	local character = humanoid.Parent
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		local moveDir = humanoid.MoveDirection
		local currentVel = root.Velocity
		if moveDir.Magnitude > 0 then
			local flatDir = Vector3.new(moveDir.X, 0, moveDir.Z).Unit
			local targetXZ = flatDir * savedConfig.speed
			root.Velocity = Vector3.new(targetXZ.X, currentVel.Y, targetXZ.Z)
		else
			root.Velocity = Vector3.new(0, currentVel.Y, 0)
		end

		if not jumpVectorForce or jumpVectorForce.Parent ~= root then
			if jumpVectorForce then
				jumpVectorForce:Destroy()
			end
			jumpVectorForce = Instance.new("VectorForce")
			jumpVectorForce.Name = "XentJump"
			jumpVectorForce.RelativeTo = Enum.ActuatorRelativeTo.World
			local att = Instance.new("Attachment")
			att.Name = "XentJumpAttachment"
			att.Parent = root
			jumpVectorForce.Attachment0 = att
			jumpVectorForce.Parent = root
		end

		local mass = root.AssemblyMass
		local jumpScale = math.clamp(savedConfig.jump, 0, 50) / 50
		local baseUp = mass * workspace.Gravity
		local extraUp = baseUp * jumpScale * 0.75
		jumpVectorForce.Force = Vector3.new(0, extraUp, 0)

		if not gravityVectorForce or gravityVectorForce.Parent ~= root then
			if gravityVectorForce then
				gravityVectorForce:Destroy()
			end
			gravityVectorForce = Instance.new("VectorForce")
			gravityVectorForce.Name = "XentGravity"
			gravityVectorForce.RelativeTo = Enum.ActuatorRelativeTo.World
			local gAtt = Instance.new("Attachment")
			gAtt.Name = "XentGravityAttachment"
			gAtt.Parent = root
			gravityVectorForce.Attachment0 = gAtt
			gravityVectorForce.Parent = root
		end

		local scale = math.clamp(savedConfig.gravity, 0, 400) / 100
		local extra = mass * workspace.Gravity * (scale - 1)
		gravityVectorForce.Force = Vector3.new(0, -extra, 0)
	end

	speedBoostActive = true
end

local function resetBoost()
	humanoid = getHumanoid()
	if jumpVectorForce then
		jumpVectorForce.Force = Vector3.new()
		jumpVectorForce:Destroy()
		jumpVectorForce = nil
	end
	if gravityVectorForce then
		gravityVectorForce.Force = Vector3.new()
		gravityVectorForce:Destroy()
		gravityVectorForce = nil
	end
	speedBoostActive = false
end

local function setSpeedEnabled(on)
	if speedEnabled == on then
		return
	end

	speedEnabled = on
	setBoosterSwitchVisual(on)
	persistentConfig.toggles = persistentConfig.toggles or {}
	persistentConfig.toggles.boosterBoost = speedEnabled
	markConfigDirty()

	if on then
		applyBoost()
	else
		clampValues()
		resetBoost()
	end
end
-- main row toggle controls visibility of the floating booster frame
local function setBoosterVisible(visible)
	boosterVisible = visible
	if boosterFrame then
		boosterFrame.Visible = visible
		if visible then
			boosterFrame.Size = UDim2.new(0, 210, 0, boosterOpen and 140 or 34)
			up = 0
		end
	end
end

-- Initialize Save Configs visual state at startup so the knob matches our local flag
setSaveConfigsVisual(saveConfigsOn)

-- Auto Grab logic (ProximityPrompt auto-steal)

local function isStealPrompt(prompt)
	if not prompt then return false end
	local text = ((prompt.ActionText or "") .. " " .. (prompt.ObjectText or "")):lower()
	return string.find(text, "steal", 1, true) ~= nil
end

local function processStealPrompt(prompt)
	if not autoGrabEnabled then return end
	if not prompt or not prompt.Parent or not prompt.Enabled then return end
	if not isStealPrompt(prompt) then return end

	local duration = prompt.HoldDuration or 0
	if duration <= 0 then
		pcall(function()
			prompt:InputHoldBegin()
			prompt:InputHoldEnd()
		end)
		return
	end

	task.spawn(function()
		pcall(function()
			prompt:InputHoldBegin()
			local holdTime = duration + 0.05
			task.delay(holdTime, function()
				if autoGrabEnabled and prompt and prompt.Parent and prompt.Enabled then
					prompt:InputHoldEnd()
				end
			end)
		end)
	end)
end

local function onPromptShown(prompt)
	if not autoGrabEnabled then return end
	processStealPrompt(prompt)
end

local function triggerExistingStealPrompts()
	for _, inst in ipairs(workspace:GetDescendants()) do
		if inst:IsA("ProximityPrompt") and inst.Enabled and isStealPrompt(inst) then
			processStealPrompt(inst)
		end
	end
end

local function startAutoGrab()
	if autoGrabConnection then
		autoGrabConnection:Disconnect()
		autoGrabConnection = nil
	end
	autoGrabConnection = ProximityPromptService.PromptShown:Connect(onPromptShown)
	triggerExistingStealPrompts()
end

local function stopAutoGrab()
	if autoGrabConnection then
		autoGrabConnection:Disconnect()
		autoGrabConnection = nil
	end
end

local function setAutoGrabEnabled(on)
	if autoGrabEnabled == on then
		return
	end
	autoGrabEnabled = on
	setAutoGrabVisual(on)
	if on then
		startAutoGrab()
	else
		stopAutoGrab()
	end
end

-- Auto kick after steal (ported from VexuHub_UI_Base.lua)

local function textStartsWithYouStole(text)
	if type(text) ~= "string" or text == "" then return false end
	text = string.lower(text)
	return string.find(text, "you stole", 1, true) ~= nil
end

local function clearAutoKickConnections()
	for inst, conn in pairs(autoKickTextConnections) do
		if conn.Connected then
			conn:Disconnect()
		end
		autoKickTextConnections[inst] = nil
	end
	if autoKickDescendantConnection and autoKickDescendantConnection.Connected then
		autoKickDescendantConnection:Disconnect()
		autoKickDescendantConnection = nil
	end
end

local function maybeKickForTextInstance(inst)
	if not autoKickAfterStealEnabled then return end
	if not inst then return end
	local text = inst.Text
	if textStartsWithYouStole(text) then
		player:Kick("Auto kick after steal: You stole.")
	end
end

local function attachAutoKickWatcher(inst)
	if not (inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox")) then
		return
	end
	if autoKickTextConnections[inst] then
		return
	end

	maybeKickForTextInstance(inst)

	autoKickTextConnections[inst] = inst:GetPropertyChangedSignal("Text"):Connect(function()
		maybeKickForTextInstance(inst)
	end)
end

local function startAutoKickAfterSteal()
	clearAutoKickConnections()
	local root = playerGui
	if not root then
		return
	end

	local count = 0
	for _, inst in ipairs(root:GetDescendants()) do
		attachAutoKickWatcher(inst)
		count = count + 1
		if count % 200 == 0 then
			task.wait()
		end
	end

	autoKickDescendantConnection = root.DescendantAdded:Connect(function(inst)
		attachAutoKickWatcher(inst)
	end)
end

local function stopAutoKickAfterSteal()
	clearAutoKickConnections()
end

local function setAutoKickEnabled(on)
	if autoKickAfterStealEnabled == on then
		return
	end
	autoKickAfterStealEnabled = on
	setAutoKickVisual(on)
	if on then
		startAutoKickAfterSteal()
	else
		stopAutoKickAfterSteal()
	end
end

-- Anti Steal (ported from XentHubUI.lua)

local function setAntiStealVisual(on)
	local goalPos = on and UDim2.new(1, -22, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
	local knobColor = on and Color3.fromRGB(255, 250, 250) or Color3.fromRGB(255, 220, 220)
	local baseColor = on and Color3.fromRGB(200, 0, 40) or Color3.fromRGB(40, 0, 10)

	TweenService:Create(antiStealKnob, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Position = goalPos,
		BackgroundColor3 = knobColor,
	}):Play()

	TweenService:Create(antiStealToggleButton, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		BackgroundColor3 = baseColor,
	}):Play()
end

local function equipAndUseBodySwap()
	local char = player.Character or player.CharacterAdded:Wait()
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return end

	local tool = backpack:FindFirstChild("Body Swap Potion") or char:FindFirstChild("Body Swap Potion")
	if not tool or not tool:IsA("Tool") then return end

	tool.Parent = char
	hum:EquipTool(tool)

	task.spawn(function()
		task.wait(0.05)
		local handle = tool:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			tool:Activate()
		end
	end)
end

local function startAntiStealDetector()
	if antiStealConn then
		antiStealConn:Disconnect()
		antiStealConn = nil
	end

	antiStealAccum = 0
	antiStealConn = RunService.Heartbeat:Connect(function(dt)
		if not antiStealEnabled then
			return
		end

		antiStealAccum = antiStealAccum + dt
		if antiStealAccum < 0.25 then
			return
		end
		antiStealAccum = 0

		local now = tick()
		if now - antiStealLastTrigger < 1.5 then
			return
		end

		local lowerSearch = "someone is stealing your"
		for _, gui in ipairs(playerGui:GetDescendants()) do
			if gui:IsA("TextLabel") or gui:IsA("TextBox") then
				local text = gui.Text
				if type(text) == "string" and text ~= "" then
					local lower = string.lower(text)
					if string.find(lower, lowerSearch, 1, true) then
						antiStealLastTrigger = now
						equipAndUseBodySwap()
						break
					end
				end
			end
		end
	end)
end

local function stopAntiStealDetector()
	if antiStealConn then
		antiStealConn:Disconnect()
		antiStealConn = nil
	end
end

local function setAntiStealEnabled(on)
	if antiStealEnabled == on then
		return
	end
	antiStealEnabled = on
	setAntiStealVisual(on)
	if on then
		startAntiStealDetector()
	else
		stopAntiStealDetector()
	end
end

-- Xray beams (ported from VexuHub_UI_Base.lua, using our brainrot helpers)

local function setXrayVisual(on)
	local goalPos = on and UDim2.new(1, -22, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
	local knobColor = on and Color3.fromRGB(255, 250, 250) or Color3.fromRGB(255, 220, 220)
	local baseColor = on and Color3.fromRGB(200, 0, 40) or Color3.fromRGB(40, 0, 10)

	TweenService:Create(xrayKnob, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Position = goalPos,
		BackgroundColor3 = knobColor,
	}):Play()

	TweenService:Create(xrayToggleButton, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		BackgroundColor3 = baseColor,
	}):Play()
end

local function clearXrayVisuals()
	if xrayConnection then
		xrayConnection:Disconnect()
		xrayConnection = nil
	end
	if xrayBrainrotBeam then
		xrayBrainrotBeam:Destroy()
		xrayBrainrotBeam = nil
	end
	if xrayNicknameBeam then
		xrayNicknameBeam:Destroy()
		xrayNicknameBeam = nil
	end
	if xrayFromAttachment then
		xrayFromAttachment:Destroy()
		xrayFromAttachment = nil
	end
	if xrayBrainrotAttachment then
		xrayBrainrotAttachment:Destroy()
		xrayBrainrotAttachment = nil
	end
	if xrayNicknameAttachment then
		xrayNicknameAttachment:Destroy()
		xrayNicknameAttachment = nil
	end
end

local function startXray()
	clearXrayVisuals()

	local bestGui = select(1, findHighestBrainrotSource())
	if not bestGui then
		return
	end

	local char = player.Character or player.CharacterAdded:Wait()
	local root = char:FindFirstChild("HumanoidRootPart")
		or char:FindFirstChild("Torso")
		or char:FindFirstChild("UpperTorso")
	if not root then
		return
	end

	xrayFromAttachment = Instance.new("Attachment")
	xrayFromAttachment.Name = "XentXrayFromAttachment"
	xrayFromAttachment.Parent = root

	xrayBrainrotAttachment = Instance.new("Attachment")
	xrayBrainrotAttachment.Name = "XentXrayBrainrotAttachment"
	xrayBrainrotAttachment.Position = Vector3.new(-2, -5, 0)
	xrayBrainrotAttachment.Parent = bestGui.Adornee or bestGui.Parent

	local nicknameParent
	local myNameLower = string.lower(player.Name)
	local displayNameLower = string.lower(player.DisplayName or player.Name)
	for _, inst in ipairs(workspace:GetDescendants()) do
		if inst:IsA("SurfaceGui") or inst:IsA("BillboardGui") then
			for _, guiChild in ipairs(inst:GetDescendants()) do
				if guiChild:IsA("TextLabel") or guiChild:IsA("TextBox") then
					local text = guiChild.Text
					if type(text) == "string" and text ~= "" then
						local lower = string.lower(text)
						local hasBase = string.find(lower, "base", 1, true) ~= nil
						local hasUserName = string.find(lower, myNameLower, 1, true) ~= nil
						local hasDisplayName = string.find(lower, displayNameLower, 1, true) ~= nil
						if hasBase and (hasUserName or hasDisplayName) then
							local parentPart = inst.Adornee or inst.Parent
							if parentPart and parentPart:IsA("BasePart") then
								nicknameParent = parentPart
								break
							end
						end
					end
				end
			end
		end
		if nicknameParent then
			break
		end
	end

	xrayNicknameAttachment = Instance.new("Attachment")
	xrayNicknameAttachment.Name = "XentXrayNicknameAttachment"
	xrayNicknameAttachment.Position = Vector3.new(0, -15, 0)
	xrayNicknameAttachment.Parent = nicknameParent or root

	xrayBrainrotBeam = Instance.new("Beam")
	xrayBrainrotBeam.Name = "XentXrayBrainrotBeam"
	xrayBrainrotBeam.Attachment0 = xrayFromAttachment
	xrayBrainrotBeam.Attachment1 = xrayBrainrotAttachment
	xrayBrainrotBeam.Width0 = 0.35
	xrayBrainrotBeam.Width1 = 0.35
	xrayBrainrotBeam.FaceCamera = true
	xrayBrainrotBeam.Transparency = NumberSequence.new(0.05)
	xrayBrainrotBeam.Parent = root

	xrayNicknameBeam = Instance.new("Beam")
	xrayNicknameBeam.Name = "XentXrayNicknameBeam"
	xrayNicknameBeam.Attachment0 = xrayFromAttachment
	xrayNicknameBeam.Attachment1 = xrayNicknameAttachment
	xrayNicknameBeam.Width0 = 0.35
	xrayNicknameBeam.Width1 = 0.35
	xrayNicknameBeam.FaceCamera = true
	xrayNicknameBeam.Transparency = NumberSequence.new(0.05)
	xrayNicknameBeam.Parent = root

	local colorAccum = 0
	local refreshAccum = 0
	xrayConnection = RunService.Heartbeat:Connect(function(dt)
		if not xrayEnabled then
			clearXrayVisuals()
			return
		end

		colorAccum = colorAccum + dt
		refreshAccum = refreshAccum + dt
		local hue = (os.clock() * 0.3) % 1
		local color = Color3.fromHSV(hue, 1, 1)
		local seq = ColorSequence.new(color)
		if xrayBrainrotBeam then
			xrayBrainrotBeam.Color = seq
		end
		if xrayNicknameBeam then
			xrayNicknameBeam.Color = seq
		end

		-- Refresh target if attachments got destroyed (brainrot moved/owner left)
		if refreshAccum >= 1.0 then
			refreshAccum = 0
			if (not xrayBrainrotAttachment) or (not xrayBrainrotAttachment.Parent) then
				startXray()
			end
		end
	end)
end

local function setXrayEnabled(on)
	if xrayEnabled == on then
		return
	end
	xrayEnabled = on
	setXrayVisual(on)
	if on then
		startXray()
	else
		clearXrayVisuals()
	end
end

-- // Smooth world pass: lighting + materials for better FPS feel

local function applySmoothWorld()
	local Lighting = game:GetService("Lighting")
	if Lighting then
		Lighting.GlobalShadows = false
		Lighting.Brightness = math.min(Lighting.Brightness, 2)
		Lighting.EnvironmentDiffuseScale = 0
		Lighting.EnvironmentSpecularScale = 0
		for _, inst in ipairs(Lighting:GetDescendants()) do
			if inst:IsA("BloomEffect") or inst:IsA("ColorCorrectionEffect")
				or inst:IsA("DepthOfFieldEffect") or inst:IsA("SunRaysEffect")
				or inst:IsA("BlurEffect") then
				inst.Enabled = false
			end
		end
	end

	-- Convert non-character parts to SmoothPlastic with smooth surfaces
	task.spawn(function()
		local processed = 0
		for _, inst in ipairs(workspace:GetDescendants()) do
			if inst:IsA("BasePart") then
				local model = inst:FindFirstAncestorOfClass("Model")
				local isCharacterPart = false
				if model and model:FindFirstChildOfClass("Humanoid") then
					isCharacterPart = true
				end

				if not isCharacterPart then
					inst.Material = Enum.Material.SmoothPlastic
					inst.Reflectance = 0
					inst.CastShadow = false
					inst.TopSurface = Enum.SurfaceType.Smooth
					inst.BottomSurface = Enum.SurfaceType.Smooth
					inst.FrontSurface = Enum.SurfaceType.Smooth
					inst.BackSurface = Enum.SurfaceType.Smooth
					inst.LeftSurface = Enum.SurfaceType.Smooth
					inst.RightSurface = Enum.SurfaceType.Smooth
					processed += 1
					if processed % 300 == 0 then
						task.wait()
					end
				end
			end
		end
	end)
end

local function setMainBoosterToggle(on)
	if boosterVisible == on then
		return
	end
	setBoosterVisual(on)
	setBoosterVisible(on)
	if not on and speedEnabled then
		setSpeedEnabled(false)
	end
	persistentConfig.toggles = persistentConfig.toggles or {}
	persistentConfig.toggles.boosterMain = boosterVisible
	markConfigDirty()
end

local function toggleMainBooster()
	setMainBoosterToggle(not boosterVisible)
end

local function toggleBoost()
	setSpeedEnabled(not speedEnabled)
end

player.CharacterAdded:Connect(function()
	task.wait(1)
	humanoid = getHumanoid()
	defaultWalkSpeed = humanoid.WalkSpeed
	useJumpPower = humanoid.UseJumpPower
	defaultJumpValue = useJumpPower and humanoid.JumpPower or humanoid.JumpHeight
	if speedEnabled then
		applyBoost()
	end
end)

RunService.Heartbeat:Connect(function()
	if speedEnabled then
		applyBoost()
	end
end)

-- Keep text boxes and config in sync when user edits values
local function onBoosterBoxFocusLost()
	clampValues()
	if speedBox then
		speedBox.Text = tostring(savedConfig.speed)
	end
	if jumpBox then
		jumpBox.Text = tostring(savedConfig.jump)
	end
	if gravityBox then
		gravityBox.Text = tostring(savedConfig.gravity)
	end
	if speedEnabled then
		applyBoost()
	end
end

if speedBox then
	speedBox.FocusLost:Connect(onBoosterBoxFocusLost)
end
if jumpBox then
	jumpBox.FocusLost:Connect(onBoosterBoxFocusLost)
end
if gravityBox then
	gravityBox.FocusLost:Connect(onBoosterBoxFocusLost)
end

-- Connect main-row booster toggle after helper functions are defined
boosterToggleButton.MouseButton1Click:Connect(toggleMainBooster)

-- // Create floating booster frame (outside main hub frame)
boosterFrame = Instance.new("Frame")
boosterFrame.Name = "XentBoosterFrame"
boosterFrame.Size = UDim2.new(0, 220, 0, 146)
boosterFrame.Position = UDim2.new(1, -240, 1, -180)
boosterFrame.BackgroundColor3 = Color3.fromRGB(14, 0, 6)
boosterFrame.BorderSizePixel = 0
boosterFrame.Visible = false
boosterFrame.ClipsDescendants = true
boosterFrame.Parent = screenGui

createRounded(boosterFrame, 10)
createStroke(boosterFrame, Color3.fromRGB(255, 70, 90), 1.8, 0.22)
createGradient(boosterFrame, Color3.fromRGB(40, 0, 10), Color3.fromRGB(8, 0, 4))

boosterHeader = Instance.new("TextButton")
boosterHeader.Name = "Header"
boosterHeader.AutoButtonColor = false
boosterHeader.BackgroundColor3 = Color3.fromRGB(26, 0, 10)
boosterHeader.Size = UDim2.new(1, 0, 0, 30)
boosterHeader.Font = Enum.Font.GothamSemibold
boosterHeader.TextXAlignment = Enum.TextXAlignment.Left
boosterHeader.Text = "  ▼  Xent boost"
boosterHeader.TextColor3 = Color3.fromRGB(255, 230, 230)
boosterHeader.TextSize = 15
boosterHeader.Parent = boosterFrame

createRounded(boosterHeader, 10)
createStroke(boosterHeader, Color3.fromRGB(255, 90, 120), 1.4, 0.18)

makeDraggable(boosterFrame, boosterHeader)

-- inner on/off switch inside booster frame
boosterSwitchButton = Instance.new("TextButton")
boosterSwitchButton.Name = "SwitchButton"
boosterSwitchButton.AnchorPoint = Vector2.new(1, 0.5)
boosterSwitchButton.Position = UDim2.new(1, -8, 0.5, 0)
boosterSwitchButton.Size = UDim2.new(0, 42, 0, 20)
boosterSwitchButton.BackgroundColor3 = Color3.fromRGB(40, 0, 10)
boosterSwitchButton.Text = ""
boosterSwitchButton.AutoButtonColor = false
boosterSwitchButton.Parent = boosterHeader

createRounded(boosterSwitchButton, 10)
createStroke(boosterSwitchButton, Color3.fromRGB(255, 80, 110), 1.4, 0.2)

boosterSwitchKnob = Instance.new("Frame")
boosterSwitchKnob.Name = "Knob"
boosterSwitchKnob.Size = UDim2.new(0, 18, 0, 16)
boosterSwitchKnob.Position = UDim2.new(0, 2, 0.5, -8)
boosterSwitchKnob.BackgroundColor3 = Color3.fromRGB(255, 220, 220)
boosterSwitchKnob.BorderSizePixel = 0
boosterSwitchKnob.Parent = boosterSwitchButton

createRounded(boosterSwitchKnob, 9)
createStroke(boosterSwitchKnob, Color3.fromRGB(255, 255, 255), 1, 0.1)

boosterContent = Instance.new("Frame")
boosterContent.Name = "Content"
boosterContent.Size = UDim2.new(1, -12, 1, -40)
boosterContent.Position = UDim2.new(0, 6, 0, 34)
boosterContent.BackgroundTransparency = 1
boosterContent.Parent = boosterFrame

local boosterList = Instance.new("UIListLayout")
boosterList.Padding = UDim.new(0, 6)
boosterList.FillDirection = Enum.FillDirection.Vertical
boosterList.HorizontalAlignment = Enum.HorizontalAlignment.Center
boosterList.VerticalAlignment = Enum.VerticalAlignment.Top
boosterList.SortOrder = Enum.SortOrder.LayoutOrder
boosterList.Parent = boosterContent

-- booster value rows now live inside the floating booster frame
local function createBoosterRow(parent, labelText, defaultValue)
	local row = Instance.new("Frame")
	row.Name = labelText .. "Row"
	row.Size = UDim2.new(1, 0, 0, 30)
	row.BackgroundColor3 = Color3.fromRGB(24, 0, 8)
	row.BorderSizePixel = 0
	row.Parent = parent

	createRounded(row, 8)
	createStroke(row, Color3.fromRGB(140, 0, 30), 1.2, 0.25)

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(0.5, -6, 1, 0)
	label.Position = UDim2.new(0, 8, 0, 0)
	label.Font = Enum.Font.GothamSemibold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = labelText
	label.TextSize = 14
	label.TextColor3 = Color3.fromRGB(255, 220, 220)
	label.Parent = row

	local box = Instance.new("TextBox")
	box.Name = labelText .. "Box"
	box.AnchorPoint = Vector2.new(1, 0.5)
	box.Position = UDim2.new(1, -6, 0.5, 0)
	box.Size = UDim2.new(0.45, 0, 0, 22)
	box.BackgroundColor3 = Color3.fromRGB(28, 0, 10)
	box.Font = Enum.Font.GothamBold
	box.TextSize = 14
	box.TextColor3 = Color3.fromRGB(255, 235, 235)
	box.TextXAlignment = Enum.TextXAlignment.Center
	box.ClearTextOnFocus = true
	box.Text = tostring(defaultValue or 0)
	box.BorderSizePixel = 0
	box.Parent = row

	createRounded(box, 7)
	createStroke(box, Color3.fromRGB(255, 80, 110), 1.4, 0.2)

	return box
end

speedBox = createBoosterRow(boosterContent, "Speed", savedConfig.speed)
jumpBox = createBoosterRow(boosterContent, "Jump", savedConfig.jump)
gravityBox = createBoosterRow(boosterContent, "Gravity", savedConfig.gravity)

boosterSwitchButton.MouseButton1Click:Connect(toggleBoost)

-- collapse / expand booster content when header is clicked
local function setBoosterOpen(open)
	if boosterOpen == open then return end
	boosterOpen = open
	if boosterFrame then
		local targetHeight = open and 146 or 34
		TweenService:Create(boosterFrame, TweenInfo.new(0.22, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, 220, 0, targetHeight),
		}):Play()
	end
	boosterContent.Visible = open
	boosterHeader.Text = open and "  ▼  Xent boost" or "  ►  Xent boost"
end

boosterHeader.MouseButton1Click:Connect(function()
	setBoosterOpen(not boosterOpen)
end)

-- Connect Auto Grab row toggle
autoGrabToggleButton.MouseButton1Click:Connect(function()
	setAutoGrabEnabled(not autoGrabEnabled)
	persistentConfig.toggles = persistentConfig.toggles or {}
	persistentConfig.toggles.autoGrab = autoGrabEnabled
	markConfigDirty()
end)

-- Connect Xray toggle (under Auto Grab)
xrayToggleButton.MouseButton1Click:Connect(function()
	setXrayEnabled(not xrayEnabled)
	persistentConfig.toggles = persistentConfig.toggles or {}
	persistentConfig.toggles.xray = xrayEnabled
	markConfigDirty()
end)

-- Connect Brainrot ESP toggle in Misc page
brainrotEspToggleButton.MouseButton1Click:Connect(function()
	setBrainrotEspEnabled(not brainrotEspEnabled)
	persistentConfig.toggles = persistentConfig.toggles or {}
	persistentConfig.toggles.brainrotEsp = brainrotEspEnabled
	markConfigDirty()
end)

-- Connect Auto kick toggle in Misc page
autoKickToggleButton.MouseButton1Click:Connect(function()
	setAutoKickEnabled(not autoKickAfterStealEnabled)
	persistentConfig.toggles = persistentConfig.toggles or {}
	persistentConfig.toggles.autoKick = autoKickAfterStealEnabled
	markConfigDirty()
end)

-- Connect Anti Steal toggle in Misc page
antiStealToggleButton.MouseButton1Click:Connect(function()
	setAntiStealEnabled(not antiStealEnabled)
	persistentConfig.toggles = persistentConfig.toggles or {}
	persistentConfig.toggles.antiSteal = antiStealEnabled
	markConfigDirty()
end)

-- Restore toggle states from config on startup (after UI + functions are ready)
if persistentConfig.saveConfigs and persistentConfig.toggles then
	local t = persistentConfig.toggles
	if t.boosterMain then
		setMainBoosterToggle(true)
	end
	if t.boosterBoost then
		setSpeedEnabled(true)
	end
	if t.autoGrab then
		setAutoGrabEnabled(true)
	end
	if t.xray then
		setXrayEnabled(true)
	end
	if t.brainrotEsp then
		setBrainrotEspEnabled(true)
	end
	if t.autoKick then
		setAutoKickEnabled(true)
	end
	if t.antiSteal then
		setAntiStealEnabled(true)
	end
	if speedBox then speedBox.Text = tostring(savedConfig.speed) end
	if jumpBox then jumpBox.Text = tostring(savedConfig.jump) end
	if gravityBox then gravityBox.Text = tostring(savedConfig.gravity) end
end

-- // ESP players (auto-enabled)

local espPlayerObjects = {}
local espPlayerConns = {}
local espPlayersGlobalConns = {}
local espPlayersEnabled = false

local function clearEspForPlayer(plr)
	local objs = espPlayerObjects[plr]
	if objs then
		for _, inst in ipairs(objs) do
			if inst and inst.Parent then
				inst:Destroy()
			end
		end
	end
	espPlayerObjects[plr] = nil

	local conns = espPlayerConns[plr]
	if conns then
		for _, conn in ipairs(conns) do
			if conn then
				conn:Disconnect()
			end
		end
	end
	espPlayerConns[plr] = nil
end

local function clearAllEsp()
	for plr, _ in pairs(espPlayerObjects) do
		clearEspForPlayer(plr)
	end
	for _, conn in ipairs(espPlayersGlobalConns) do
		if conn then
			conn:Disconnect()
		end
	end
	espPlayersGlobalConns = {}
end

local function createEspForCharacter(plr, character)
	if not character or not character.Parent then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	clearEspForPlayer(plr)

	local highlight = Instance.new("Highlight")
	highlight.Name = "XentEspHighlight"
	highlight.Adornee = character
	highlight.FillTransparency = 0.65
	highlight.OutlineTransparency = 0
	highlight.OutlineColor = Color3.fromRGB(255, 90, 90)
	highlight.Parent = character

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "XentEspBillboard"
	billboard.Adornee = root
	billboard.Size = UDim2.new(0, 80, 0, 20)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 0
	billboard.Parent = root

	local label = Instance.new("TextLabel")
	label.Name = "NameLabel"
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = false
	label.TextSize = 14
	label.Text = plr.Name
	label.TextColor3 = Color3.fromRGB(255, 120, 120)
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.TextWrapped = true
	label.Parent = billboard

	espPlayerObjects[plr] = { highlight, billboard }

	local conns = {}
	conns[#conns+1] = character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			clearEspForPlayer(plr)
		end
	end)

	espPlayerConns[plr] = conns
end

local function enableEspPlayers()
	if espPlayersEnabled then return end
	espPlayersEnabled = true

	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= player then
			local char = plr.Character or plr.CharacterAdded:Wait()
			createEspForCharacter(plr, char)
		end
	end

	espPlayersGlobalConns[#espPlayersGlobalConns+1] = Players.PlayerAdded:Connect(function(plr)
		if not espPlayersEnabled then return end
		if plr == player then return end
		local char = plr.Character or plr.CharacterAdded:Wait()
		createEspForCharacter(plr, char)
	end)

	espPlayersGlobalConns[#espPlayersGlobalConns+1] = Players.PlayerRemoving:Connect(function(plr)
		clearEspForPlayer(plr)
	end)

	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= player then
			espPlayersGlobalConns[#espPlayersGlobalConns+1] = plr.CharacterAdded:Connect(function(char)
				if espPlayersEnabled then
					createEspForCharacter(plr, char)
				end
			end)
		end
	end
end

-- // Invisible walls (VexuHub-style implementation)

local invisibleWallParts = {}

local function collectBaseParts()
	invisibleWallParts = {}
	local count = 0
	for _, inst in ipairs(workspace:GetDescendants()) do
		if inst:IsA("BasePart") then
			-- Skip character parts
			local model = inst:FindFirstAncestorOfClass("Model")
			local isCharacterPart = false
			if model then
				local humanoid = model:FindFirstChildOfClass("Humanoid")
				if humanoid then
					isCharacterPart = true
				end
			end

			if not isCharacterPart then
				if inst.Transparency == 0 then
					-- Treat mostly-horizontal parts as "ground" and keep them solid
					local up = inst.CFrame.UpVector
					local isGroundLike = up.Y > 0.7

					if not isGroundLike then
						invisibleWallParts[inst] = inst.Transparency
						count = count + 1
						if count % 500 == 0 then
							task.wait()
						end
					end
				end
			end
		end
	end
end

local function applyInvisibleWalls()
	if not next(invisibleWallParts) then
		collectBaseParts()
	end
	local processed = 0
	for part in pairs(invisibleWallParts) do
		if part and part.Parent then
			part.Transparency = 0.69
			processed = processed + 1
			if processed % 500 == 0 then
				task.wait()
			end
		end
	end
end

-- Periodically refresh invisible walls to catch new bases/parts
task.spawn(function()
	while true do
		collectBaseParts()
		applyInvisibleWalls()
		for _ = 1, 50 do
			task.wait(0.2)
		end
	end
end)

-- // Base Timer (lock base overlays)

local baseCooldownOverlays = {}
local baseCooldownEnabled = false
local baseCooldownUpdaterRunning = false

local function getBaseCooldownInfoFromGui(sourceGui)
	if not sourceGui then
		return nil, nil
	end

	local hasBaseWord = false
	local hasLockWord = false
	local hasLockBasePhrase = false
	local seconds = nil

	for _, inst in ipairs(sourceGui:GetDescendants()) do
		if inst:IsA("TextLabel") or inst:IsA("TextBox") then
			local text = inst.Text
			if type(text) == "string" and text ~= "" then
				local lower = string.lower(text)
				if string.find(lower, "lock base", 1, true) then
					hasLockBasePhrase = true
				end
				if string.find(lower, "base", 1, true) then
					hasBaseWord = true
				end
				if string.find(lower, "locked", 1, true) then
					hasLockWord = true
				end
				if not seconds then
					local num = string.match(text, "(%d+)%s*[sS]")
					if num then
						seconds = tonumber(num)
					end
				end
			end
		end
	end

	if hasLockWord and hasBaseWord and seconds then
		return seconds, true
	end

	if hasLockBasePhrase and not hasLockWord then
		return 0, false
	end

	return nil, nil
end

local function clearBaseCooldownOverlays()
	for _, data in pairs(baseCooldownOverlays) do
		local billboard = data.billboard
		if billboard and billboard.Parent then
			billboard:Destroy()
		end
	end
	baseCooldownOverlays = {}
end

local function createBaseCooldownOverlays()
	clearBaseCooldownOverlays()

	local candidatesPerBase = {}
	local cellSize = 35
	local inspected = 0
	for _, inst in ipairs(workspace:GetDescendants()) do
		if inst:IsA("BillboardGui") then
			local secs, isLocked = getBaseCooldownInfoFromGui(inst)
			if secs ~= nil then
				local adornee = inst.Adornee or inst.Parent
				local pos
				if adornee and adornee:IsA("BasePart") then
					pos = adornee.Position
				elseif inst.Parent and inst.Parent:IsA("BasePart") then
					pos = inst.Parent.Position
				end

				if pos then
					local keyX = math.floor(pos.X / cellSize + 0.5)
					local keyZ = math.floor(pos.Z / cellSize + 0.5)
					local baseKey = tostring(keyX) .. ":" .. tostring(keyZ)

					local y = pos.Y
					local existing = candidatesPerBase[baseKey]
					if not existing or y < existing.y then
						candidatesPerBase[baseKey] = {
							sourceGui = inst,
							adornee = adornee,
							secs = secs,
							isLocked = isLocked,
							position = pos,
							y = y,
						}
					end
				end
			end
		end

		inspected = inspected + 1
		if inspected % 400 == 0 then
			task.wait()
		end
	end

	for _, data in pairs(candidatesPerBase) do
		local parentForNew = data.adornee or data.sourceGui.Parent
		if parentForNew and parentForNew:IsA("BasePart") then
			local billboard = Instance.new("BillboardGui")
			billboard.Name = "XentBaseCooldownOverlay"
			billboard.Size = UDim2.new(0, 70, 0, 28)
			billboard.StudsOffset = Vector3.new(0, 5.2, 0)
			billboard.AlwaysOnTop = true
			billboard.MaxDistance = 0
			billboard.Adornee = parentForNew
			billboard.Parent = parentForNew

			local label = Instance.new("TextLabel")
			label.Name = "CooldownLabel"
			label.Size = UDim2.new(1, 0, 1, 0)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.GothamBold
			label.TextScaled = true
			label.TextColor3 = Color3.fromRGB(255, 120, 120)
			label.TextStrokeColor3 = Color3.new(0, 0, 0)
			label.TextStrokeTransparency = 0
			label.TextWrapped = true
			label.Parent = billboard

			baseCooldownOverlays[data.sourceGui] = {
				source = data.sourceGui,
				billboard = billboard,
				label = label,
			}
		end
	end
end

local function startBaseCooldownUpdater()
	if baseCooldownUpdaterRunning then
		return
	end
	baseCooldownUpdaterRunning = true

	task.spawn(function()
		while baseCooldownEnabled do
			for sourceGui, data in pairs(baseCooldownOverlays) do
				local billboard = data.billboard
				local label = data.label
				if (not sourceGui) or (not sourceGui.Parent) then
					if billboard and billboard.Parent then
						billboard:Destroy()
					end
					baseCooldownOverlays[sourceGui] = nil
				else
					local secs, isLocked = getBaseCooldownInfoFromGui(sourceGui)
					if label then
						if not isLocked or (secs ~= nil and secs <= 0) then
							label.Text = "UNLOCKED"
						else
							if secs then
								label.Text = tostring(math.floor(secs)) .. "s"
							else
								label.Text = "LOCKED"
							end
						end
					end
				end
			end
			for _ = 1, 10 do
				if not baseCooldownEnabled then
					break
				end
				task.wait(0.1)
			end
		end

		clearBaseCooldownOverlays()
		baseCooldownUpdaterRunning = false
	end)
end

local function setBaseCooldownEnabled(on)
	if baseCooldownEnabled == on then
		return
	end
	baseCooldownEnabled = on
	if on then
		createBaseCooldownOverlays()
		startBaseCooldownUpdater()
	else
		-- updater loop cleans up when it exits
	end
end

-- // Auto-enable features when script loads

task.spawn(function()
	-- small delay so world UI is present
	task.wait(2)
	applySmoothWorld()
	applyInvisibleWalls()
	enableEspPlayers()
	setBaseCooldownEnabled(true)
end)
