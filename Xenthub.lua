-- XENT HUB - Red/Dark Minimal UI (Compact Version)
-- This is a simplified, low-local-count variant of XentHubRedUI.lua.
-- Place as a LocalScript (e.g. StarterPlayer > StarterPlayerScripts).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Minimal Anti-Skid / Anti-Debug (compact, optional)
local function runAntiSkid()
	-- Anti-debug: if we can see our own source path via debug.getinfo, treat as skid/debug and kick
	pcall(function()
		if typeof(debug) == "table" and typeof(debug.getinfo) == "function" then
			local info = debug.getinfo(1, "S")
			if info and type(info.source) == "string" and info.source:find("@") then
				player:Kick("stop trying to skid XENT HUB")
			end
		end
	end)

	-- Light hook detection: if executor exposes getrawmetatable, watch for aggressive __namecall hooks
	local okMt, mt
	if typeof(getrawmetatable) == "function" then
		okMt, mt = pcall(getrawmetatable, game)
	end
	if not okMt or not mt then return end

	local originalNamecall = rawget(mt, "__namecall")
	if type(originalNamecall) ~= "function" then return end

	task.spawn(function()
		while true do
			task.wait(4)
			pcall(function()
				local current = rawget(mt, "__namecall")
				if type(current) ~= "function" then
					player:Kick("skid hooks detected (__namecall removed)")
					return
				end
				if current ~= originalNamecall then
					-- If islclosure exists, allow C closures (usually executor internals), otherwise treat as suspicious
					if typeof(islclosure) == "function" then
						local ok, isLua = pcall(islclosure, current)
						if ok and isLua then
							player:Kick("skid hooks detected (__namecall)")
							return
						end
					else
						player:Kick("skid hooks detected (__namecall)")
						return
					end
				end
			end)
		end
	end)
end

runAntiSkid()

local canUseFS = typeof(isfile) == "function" and typeof(readfile) == "function" and typeof(writefile) == "function"
local CONFIG_FILE = "XentHubRed_" .. player.Name .. "_config_min.json"

local C = {
	persistent = {
		saveConfigs = true,
		toggles = {},
		booster = { speed = 16, jump = 20, gravity = 100 },
	},
	state = {
		booster = {
			enabled = false,
			visible = false,
			open = true,
			jumpForce = nil,
			gravityForce = nil,
			boxes = {},
		},
		brainrot = {
			enabled = false,
			billboard = nil,
			conn = nil,
			accum = 0,
			currentGui = nil,
		},
		autoGrab = {
			enabled = false,
			conn = nil,
		},
		autoKick = {
			enabled = false,
			textConns = {},
			rootConn = nil,
		},
		antiSteal = {
			enabled = false,
			conn = nil,
			accum = 0,
			lastTrigger = 0,
		},
		instaSteal = {
			enabled = false,
			conn = nil,
			marker = nil,
			torsoAtt = nil,
			markerAtt = nil,
			beam = nil,
		},
		xray = {
			enabled = false,
			conn = nil,
			fromAtt = nil,
			brainAtt = nil,
			nickAtt = nil,
			brainBeam = nil,
			nickBeam = nil,
		},
		playersEsp = {
			enabled = false,
			objects = {},
			perPlayer = {},
			globalConns = {},
		},
		antiKnockback = {
			enabled = false,
			conn = nil,
		},
		hitbox = {
			enabled = false,
			conn = nil,
		},
		antiRagdoll = {
			enabled = false,
			conns = {},
		},
		noAnimation = {
			enabled = false,
			conns = {},
		},
		baseCooldown = {
			enabled = false,
			overlays = {},
			updaterRunning = false,
		},
		invisibleWalls = {
			parts = {},
			running = false,
		},
		aimbot = {
			enabled = false,
			thread = nil,
			remote = nil,
		},
		protection = {
			disconnectEnabled = false,
		},
		ui = {},
	},
}

local function loadPersistent()
	if not canUseFS or not isfile(CONFIG_FILE) then return end
	local ok, data = pcall(readfile, CONFIG_FILE)
	if not ok or not data or data == "" then return end
	local okDec, decoded = pcall(function()
		return HttpService:JSONDecode(data)
	end)
	if not okDec or type(decoded) ~= "table" then return end
	if type(decoded.saveConfigs) == "boolean" then
		C.persistent.saveConfigs = decoded.saveConfigs
	end
	if type(decoded.toggles) == "table" then
		C.persistent.toggles = decoded.toggles
	end
	if type(decoded.booster) == "table" then
		local b = decoded.booster
		if type(b.speed) == "number" then C.persistent.booster.speed = b.speed end
		if type(b.jump) == "number" then C.persistent.booster.jump = b.jump end
		if type(b.gravity) == "number" then C.persistent.booster.gravity = b.gravity end
	end
end

local function savePersistent()
	if not canUseFS then return end
	local out
	if not C.persistent.saveConfigs then
		out = {
			saveConfigs = false,
			toggles = {},
			booster = { speed = 16, jump = 20, gravity = 100 },
		}
	else
		out = C.persistent
	end
	local okEnc, enc = pcall(function()
		return HttpService:JSONEncode(out)
	end)
	if not okEnc then return end
	pcall(writefile, CONFIG_FILE, enc)
end

local configDirty = false
local function markConfigDirty()
	if not C.persistent.saveConfigs or not canUseFS then return end
	if configDirty then return end
	configDirty = true
	task.spawn(function()
		task.wait(0.15)
		configDirty = false
		local t = C.persistent.toggles or {}
		t.boosterMain = C.state.booster.visible
		t.boosterBoost = C.state.booster.enabled
		t.autoGrab = C.state.autoGrab.enabled
		t.brainrotEsp = C.state.brainrot.enabled
		t.autoKick = C.state.autoKick.enabled
		t.antiSteal = C.state.antiSteal.enabled
		t.xray = C.state.xray.enabled
		t.aimbot = C.state.aimbot.enabled
		t.disconnectButton = C.state.protection.disconnectEnabled
		t.antiKnockback = C.state.antiKnockback.enabled
		t.hitbox = C.state.hitbox.enabled
		t.antiRagdoll = C.state.antiRagdoll.enabled
		t.instaSteal = C.state.instaSteal.enabled
		t.noAnimation = C.state.noAnimation.enabled
		C.persistent.booster = C.persistent.booster or {}
		C.persistent.booster.speed = C.persistent.booster.speed or 16
		C.persistent.booster.jump = C.persistent.booster.jump or 20
		C.persistent.booster.gravity = C.persistent.booster.gravity or 100
		C.persistent.toggles = t
		savePersistent()
	end)
end

loadPersistent()

-- UI helpers
local function rounded(obj, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = obj
	return c
end

local function stroked(obj, color, thickness, transp)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transp or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = obj
	return s
end

local function gradient(obj, c1, c2)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, c1),
		ColorSequenceKeypoint.new(1, c2),
	})
	g.Rotation = 90
	g.Parent = obj
	return g
end

local function makeDraggable(frame, handle)
	handle = handle or frame
	local dragging = false
	local dragStart, startPos
	local hasMoved = false
	local dragThreshold = 8 -- pixels before we treat it as an intentional drag (helps mobile)

	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			hasMoved = false
			dragStart = input.Position
			startPos = frame.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					hasMoved = false
				end
			end)
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - dragStart
			if not hasMoved then
				if d.Magnitude < dragThreshold then
					return
				end
				hasMoved = true
			end
			frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
end

-- Executor / device detection & GUI parenting (mobile-friendly)
local function detectExecutor()
	local exec = "unknown"
	pcall(function()
		if typeof(getgenv) == "function" then
			local env = getgenv()
			if type(env) == "table" and type(env.executor) == "string" and env.executor ~= "" then
				exec = env.executor
				return
			end
		end
		if typeof(identifyexecutor) == "function" then
			local ok, res = pcall(identifyexecutor)
			if ok and type(res) == "string" and res ~= "" then
				exec = res
				return
			end
		end
		if typeof(syn) == "table" then exec = "synapse" return end
		if typeof(krnl) ~= "nil" then exec = "krnl" return end
		if typeof(fluxus) ~= "nil" then exec = "fluxus" return end
		if typeof(is_sirhurt_closure) == "function" then exec = "sirhurt" return end
	end)
	return exec
end

local function createXentGui()
	local gui = Instance.new("ScreenGui")
	gui.Name = "XentHubRedCompact"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local parent
	local execName = ""
	local okExec, resExec = pcall(detectExecutor)
	if okExec and type(resExec) == "string" then
		execName = string.lower(resExec)
	end
	local isMobileExec = execName:find("mobile", 1, true) or execName:find("android", 1, true) or execName:find("ios", 1, true)

	local function trySet(method)
		local ok, target = pcall(method)
		if ok and target then
			parent = target
		end
		return parent ~= nil
	end

	if isMobileExec then
		-- Mobile: favor protected CoreGui / gethui / hidden UI, else fall back to PlayerGui
		if not trySet(function()
			if typeof(syn) == "table" and typeof(syn.protect_gui) == "function" then
				local cg = game:GetService("CoreGui")
				syn.protect_gui(gui)
				gui.Parent = cg
				gui.IgnoreGuiInset = true
				return cg
			end
		end) then
			if not trySet(function()
				if typeof(gethui) == "function" then
					local h = gethui()
					gui.Parent = h
					gui.IgnoreGuiInset = true
					return h
				end
			end) then
				if not trySet(function()
					if typeof(get_hidden_ui) == "function" then
						local h = get_hidden_ui()
						gui.Parent = h
						gui.IgnoreGuiInset = true
						return h
					end
				end) then
					gui.Parent = playerGui
					parent = playerGui
				end
			end
		end
	else
		-- PC / unknown: try executor UIs first, otherwise normal PlayerGui
		if not trySet(function()
			if typeof(syn) == "table" and typeof(syn.protect_gui) == "function" then
				local cg = game:GetService("CoreGui")
				syn.protect_gui(gui)
				gui.Parent = cg
				return cg
			end
		end) then
			if not trySet(function()
				if typeof(gethui) == "function" then
					local h = gethui()
					gui.Parent = h
					return h
				end
			end) then
				if not trySet(function()
					if typeof(get_hidden_ui) == "function" then
						local h = get_hidden_ui()
						gui.Parent = h
						return h
					end
				end) then
					gui.Parent = playerGui
					parent = playerGui
				end
			end
		end
	end

	if isMobileExec then
		pcall(function()
			gui.DisplayOrder = 999999
			if gui.SetAttribute then
				gui:SetAttribute("MobileOptimized", true)
				gui:SetAttribute("TouchEnabled", true)
			end
		end)
	end

	return gui
end

-- ScreenGui & main layout
local gui = createXentGui()

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 430, 0, 260)
main.Position = UDim2.new(0.5, -215, 0.5, -130)
main.BackgroundColor3 = Color3.fromRGB(12, 10, 14)
main.BorderSizePixel = 0
main.ClipsDescendants = true
main.Parent = gui
rounded(main, 12)
stroked(main, Color3.fromRGB(180, 0, 30), 2, 0.15)
gradient(main, Color3.fromRGB(30, 0, 0), Color3.fromRGB(6, 0, 0))

local top = Instance.new("Frame")
top.Name = "TopBar"
top.Size = UDim2.new(1, 0, 0, 32)
top.BackgroundColor3 = Color3.fromRGB(20, 0, 4)
top.BorderSizePixel = 0
top.Parent = main
rounded(top, 12)
stroked(top, Color3.fromRGB(220, 20, 40), 1.2, 0.2)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Size = UDim2.new(0, 220, 1, 0)
title.Position = UDim2.new(0, 14, 0, 0)
title.Font = Enum.Font.GothamBold
title.Text = "XENT HUB"
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextSize = 18
title.TextColor3 = Color3.new(1, 1, 1)
gradient(title, Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 180, 180))
title.Parent = top

local closeBtn = Instance.new("TextButton")
closeBtn.Name = "Close"
closeBtn.AnchorPoint = Vector2.new(1, 0.5)
closeBtn.Position = UDim2.new(1, -8, 0.5, 0)
closeBtn.Size = UDim2.new(0, 22, 0, 22)
closeBtn.BackgroundColor3 = Color3.fromRGB(40, 0, 8)
closeBtn.Text = "X"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextColor3 = Color3.fromRGB(255, 120, 120)
closeBtn.TextSize = 14
closeBtn.AutoButtonColor = false
closeBtn.Parent = top
rounded(closeBtn, 6)
stroked(closeBtn, Color3.fromRGB(255, 70, 90), 1.4, 0.15)

local restoreBtn = Instance.new("Frame")
restoreBtn.Name = "Restore"
restoreBtn.Size = UDim2.new(0, 110, 0, 32)
restoreBtn.Position = UDim2.new(0, 26, 0.78, 0)
restoreBtn.BackgroundColor3 = Color3.fromRGB(30, 0, 8)
restoreBtn.BorderSizePixel = 0
restoreBtn.Visible = false
restoreBtn.Parent = gui
rounded(restoreBtn, 16)
stroked(restoreBtn, Color3.fromRGB(255, 70, 90), 2, 0.18)

local restoreLabel = Instance.new("TextLabel")
restoreLabel.BackgroundTransparency = 1
restoreLabel.Size = UDim2.new(1, -32, 1, 0)
restoreLabel.Position = UDim2.new(0, 10, 0, 0)
restoreLabel.Font = Enum.Font.GothamBold
restoreLabel.TextSize = 14
restoreLabel.TextXAlignment = Enum.TextXAlignment.Left
restoreLabel.Text = "XENT"
restoreLabel.TextColor3 = Color3.fromRGB(255, 220, 220)
restoreLabel.Parent = restoreBtn

local restoreCross = Instance.new("TextButton")
restoreCross.Name = "RestoreCross"
restoreCross.AnchorPoint = Vector2.new(1, 0.5)
restoreCross.Position = UDim2.new(1, -6, 0.5, 0)
restoreCross.Size = UDim2.new(0, 20, 0, 20)
restoreCross.BackgroundColor3 = Color3.fromRGB(60, 0, 12)
restoreCross.Text = "X"
restoreCross.Font = Enum.Font.GothamBold
restoreCross.TextSize = 14
restoreCross.TextColor3 = Color3.fromRGB(255, 190, 190)
restoreCross.AutoButtonColor = true
restoreCross.BorderSizePixel = 0
restoreCross.Parent = restoreBtn
rounded(restoreCross, 10)
stroked(restoreCross, Color3.fromRGB(255, 100, 120), 1.4, 0.18)

makeDraggable(main, top)
makeDraggable(restoreBtn, restoreBtn)

closeBtn.MouseButton1Click:Connect(function()
	main.Visible = false
	restoreBtn.Visible = true
end)

restoreCross.MouseButton1Click:Connect(function()
	main.Visible = true
	restoreBtn.Visible = false
end)

-- Nav
local nav = Instance.new("Frame")
nav.Size = UDim2.new(0, 110, 1, -40)
nav.Position = UDim2.new(0, 0, 0, 36)
nav.BackgroundColor3 = Color3.fromRGB(20, 0, 6)
nav.BorderSizePixel = 0
nav.Parent = main
stroked(nav, Color3.fromRGB(40, 0, 16), 1, 0.45)

local function navButton(text)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, -14, 0, 30)
	b.BackgroundColor3 = Color3.fromRGB(40, 0, 8)
	b.Text = text
	b.Font = Enum.Font.GothamSemibold
	b.TextSize = 16
	b.TextColor3 = Color3.fromRGB(230, 210, 210)
	b.AutoButtonColor = false
	b.Parent = nav
	rounded(b, 8)
	stroked(b, Color3.fromRGB(200, 40, 70), 1.1, 0.1)
	return b
end

local mainBtn = navButton("Main")
mainBtn.Position = UDim2.new(0, 7, 0, 4)
mainBtn.BackgroundColor3 = Color3.fromRGB(60, 0, 10)
stroked(mainBtn, Color3.fromRGB(255, 70, 90), 1.3, 0.12)

local miscBtn = navButton("Misc")
miscBtn.Position = UDim2.new(0, 7, 0, 40)

local protectionBtn = navButton("Protection")
protectionBtn.Position = UDim2.new(0, 7, 0, 76)

local pvpBtn = navButton("PvP helper")
pvpBtn.Position = UDim2.new(0, 7, 0, 112)

local settingsBtn = navButton("Settings")
settingsBtn.Position = UDim2.new(0, 7, 0, 148)

local content = Instance.new("Frame")
content.Name = "Content"
content.Size = UDim2.new(1, -128, 1, -46)
content.Position = UDim2.new(0, 118, 0, 40)
content.BackgroundColor3 = Color3.fromRGB(18, 0, 6)
content.BorderSizePixel = 0
content.ClipsDescendants = true
content.Parent = main
rounded(content, 10)
stroked(content, Color3.fromRGB(120, 0, 26), 1.4, 0.2)

local function createPage(name)
	local page = Instance.new("Frame")
	page.Name = name
	page.Size = UDim2.new(1, 0, 1, 0)
	page.BackgroundTransparency = 1
	page.Parent = content
	return page
end

local mainPage = createPage("MainPage")
local miscPage = createPage("MiscPage")
miscPage.Visible = false
local protectionPage = createPage("ProtectionPage")
protectionPage.Visible = false
local pvpPage = createPage("PvPPage")
pvpPage.Visible = false
local settingsPage = createPage("SettingsPage")
settingsPage.Visible = false

local function pageHeader(parent, text)
	local h = Instance.new("TextLabel")
	h.Size = UDim2.new(1, -10, 0, 26)
	h.Position = UDim2.new(0, 6, 0, 0)
	h.BackgroundTransparency = 1
	h.Font = Enum.Font.GothamBold
	h.TextSize = 18
	h.TextXAlignment = Enum.TextXAlignment.Left
	h.Text = text
	h.TextColor3 = Color3.fromRGB(255, 240, 240)
	h.Parent = parent
	return h
end

pageHeader(mainPage, "Main")
pageHeader(miscPage, "Misc")
pageHeader(protectionPage, "Protection")
pageHeader(pvpPage, "PvP helper")
pageHeader(settingsPage, "Settings")

local function optionsHolder(parent)
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, -12, 1, -34)
	f.Position = UDim2.new(0, 6, 0, 30)
	f.BackgroundTransparency = 1
	f.Parent = parent
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, 8)
	l.FillDirection = Enum.FillDirection.Vertical
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	l.VerticalAlignment = Enum.VerticalAlignment.Top
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = f
	return f
end

local mainHolder = optionsHolder(mainPage)
local miscHolder = optionsHolder(miscPage)
local protectionHolder = optionsHolder(protectionPage)
local pvpHolder = optionsHolder(pvpPage)
local settingsHolder = optionsHolder(settingsPage)

local function toggleRow(parent, text)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 40)
	row.BackgroundColor3 = Color3.fromRGB(22, 0, 6)
	row.BorderSizePixel = 0
	row.Parent = parent
	rounded(row, 10)
	stroked(row, Color3.fromRGB(120, 0, 25), 1.3, 0.2)

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -90, 0, 20)
	label.Position = UDim2.new(0, 10, 0, 4)
	label.Font = Enum.Font.GothamSemibold
	label.Text = text
	label.TextSize = 16
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(255, 225, 225)
	label.Parent = row

	local btn = Instance.new("TextButton")
	btn.AnchorPoint = Vector2.new(1, 0.5)
	btn.Position = UDim2.new(1, -10, 0.5, 0)
	btn.Size = UDim2.new(0, 52, 0, 22)
	btn.BackgroundColor3 = Color3.fromRGB(40, 0, 10)
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.Parent = row
	rounded(btn, 12)
	stroked(btn, Color3.fromRGB(255, 80, 110), 1.4, 0.2)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 20, 0, 18)
	knob.Position = UDim2.new(0, 2, 0.5, -9)
	knob.BackgroundColor3 = Color3.fromRGB(255, 220, 220)
	knob.BorderSizePixel = 0
	knob.Parent = btn
	rounded(knob, 10)
	stroked(knob, Color3.fromRGB(255, 255, 255), 1, 0.1)

	return row, btn, knob
end

-- Main toggles
local boosterRow, boosterBtn, boosterKnob = toggleRow(mainHolder, "XENT BOOSTER")
local boosterHint = Instance.new("TextLabel")
boosterHint.BackgroundTransparency = 1
boosterHint.Size = UDim2.new(1, -90, 0, 16)
boosterHint.Position = UDim2.new(0, 10, 0, 22)
boosterHint.Font = Enum.Font.Gotham
boosterHint.TextSize = 12
boosterHint.TextXAlignment = Enum.TextXAlignment.Left
boosterHint.TextColor3 = Color3.fromRGB(230, 180, 180)
boosterHint.Text = "Speed, jump and gravity booster"
boosterHint.Parent = boosterRow

local autoGrabRow, autoGrabBtn, autoGrabKnob = toggleRow(mainHolder, "Auto Grab")
autoGrabRow.Size = UDim2.new(1, 0, 0, 38)
local xrayRow, xrayBtn, xrayKnob = toggleRow(mainHolder, "Xray")

local instaRow, instaBtn, instaKnob = toggleRow(mainHolder, "Insta Steal")
instaRow.Size = UDim2.new(1, 0, 0, 38)
local instaHint = Instance.new("TextLabel")
instaHint.BackgroundTransparency = 1
instaHint.Size = UDim2.new(1, -110, 0, 12)
instaHint.Position = UDim2.new(0, 10, 0, 24)
instaHint.Font = Enum.Font.Gotham
instaHint.TextSize = 9
instaHint.TextXAlignment = Enum.TextXAlignment.Left
instaHint.TextColor3 = Color3.fromRGB(230, 180, 180)
instaHint.Text = "Teleports when stealing with Flying Carpet equipped"
instaHint.Parent = instaRow

-- Misc toggles
local brainRow, brainBtn, brainKnob = toggleRow(miscHolder, "Brainrot ESP")
local autoKickRow, autoKickBtn, autoKickKnob = toggleRow(miscHolder, "Auto kick")
local autoKickHint = Instance.new("TextLabel")
autoKickHint.BackgroundTransparency = 1
autoKickHint.Size = UDim2.new(1, -110, 0, 14)
autoKickHint.Position = UDim2.new(0, 10, 0, 22)
autoKickHint.Font = Enum.Font.Gotham
autoKickHint.TextSize = 10
autoKickHint.TextXAlignment = Enum.TextXAlignment.Left
autoKickHint.TextColor3 = Color3.fromRGB(230, 180, 180)
autoKickHint.Text = "Auto-kicks when you steal a brainrot"
autoKickHint.Parent = autoKickRow
local aimbotRow, aimbotBtn, aimbotKnob = toggleRow(miscHolder, "Aimbot")
local aimHint = Instance.new("TextLabel")
aimHint.BackgroundTransparency = 1
aimHint.Size = UDim2.new(1, -110, 0, 14)
aimHint.Position = UDim2.new(0, 10, 0, 22)
aimHint.Font = Enum.Font.Gotham
aimHint.TextSize = 10
aimHint.TextXAlignment = Enum.TextXAlignment.Left
aimHint.TextColor3 = Color3.fromRGB(230, 180, 180)
aimHint.Text = "Laser Cape , Web slinger , Paintball Gun"
aimHint.Parent = aimbotRow

local noAnimRow, noAnimBtn, noAnimKnob = toggleRow(miscHolder, "No animation")
noAnimRow.Size = UDim2.new(1, 0, 0, 38)
local noAnimHint = Instance.new("TextLabel")
noAnimHint.BackgroundTransparency = 1
noAnimHint.Size = UDim2.new(1, -110, 0, 14)
noAnimHint.Position = UDim2.new(0, 10, 0, 22)
noAnimHint.Font = Enum.Font.Gotham
noAnimHint.TextSize = 10
noAnimHint.TextXAlignment = Enum.TextXAlignment.Left
noAnimHint.TextColor3 = Color3.fromRGB(230, 180, 180)
noAnimHint.Text = "Disables animations on the character"
noAnimHint.Parent = noAnimRow

-- PvP helper toggles
local antiKnockRow, antiKnockBtn, antiKnockKnob = toggleRow(pvpHolder, "Anti Knockback")
local hitboxRow, hitboxBtn, hitboxKnob = toggleRow(pvpHolder, "Hitbox")
local antiRagdollRow, antiRagdollBtn, antiRagdollKnob = toggleRow(pvpHolder, "Anti Ragdoll")

-- Protection toggles
local disconnectRow, disconnectBtn, disconnectKnob = toggleRow(protectionHolder, "Disconnect Button")
local antiStealRow, antiStealBtn, antiStealKnob = toggleRow(protectionHolder, "Anti Steal")
local antiHint = Instance.new("TextLabel")
antiHint.BackgroundTransparency = 1
antiHint.Size = UDim2.new(1, -110, 0, 14)
antiHint.Position = UDim2.new(0, 10, 0, 22)
antiHint.Font = Enum.Font.Gotham
antiHint.TextSize = 10
antiHint.TextXAlignment = Enum.TextXAlignment.Left
antiHint.TextColor3 = Color3.fromRGB(230, 180, 180)
antiHint.Text = "Body-swaps if someone is stealing your brainrot."
antiHint.Parent = antiStealRow

-- Settings: save configs only (compact)
local saveRow, saveBtn, saveKnob = toggleRow(settingsHolder, "Save Configs")
local saveLabel = saveRow:FindFirstChildWhichIsA("TextLabel")

-- Simple notification (bottom-right)
local function showNotification(mainText, subText)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 260, 0, 60)
	frame.AnchorPoint = Vector2.new(1, 1)
	frame.Position = UDim2.new(1, -20, 1, -20)
	frame.BackgroundColor3 = Color3.fromRGB(20, 0, 6)
	frame.BorderSizePixel = 0
	frame.BackgroundTransparency = 0.1
	frame.Parent = gui
	rounded(frame, 10)
	stroked(frame, Color3.fromRGB(255, 70, 90), 1.2, 0.25)
	gradient(frame, Color3.fromRGB(40, 0, 10), Color3.fromRGB(10, 0, 4))

	local titleLbl = Instance.new("TextLabel")
	titleLbl.BackgroundTransparency = 1
	titleLbl.Size = UDim2.new(1, -10, 0, 24)
	titleLbl.Position = UDim2.new(0, 8, 0, 4)
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextSize = 14
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.TextColor3 = Color3.fromRGB(255, 235, 235)
	titleLbl.Text = mainText or "Notification"
	titleLbl.Parent = frame

	local subLbl = Instance.new("TextLabel")
	subLbl.BackgroundTransparency = 1
	subLbl.Size = UDim2.new(1, -10, 0, 24)
	subLbl.Position = UDim2.new(0, 8, 0, 28)
	subLbl.Font = Enum.Font.Gotham
	subLbl.TextSize = 12
	subLbl.TextXAlignment = Enum.TextXAlignment.Left
	subLbl.TextColor3 = Color3.fromRGB(230, 200, 200)
	subLbl.Text = subText or ""
	subLbl.Parent = frame

	task.spawn(function()
		wait(2.0)
		local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
		pcall(function()
			TweenService:Create(frame, tweenInfo, { BackgroundTransparency = 1 }):Play()
			TweenService:Create(titleLbl, tweenInfo, { TextTransparency = 1 }):Play()
			TweenService:Create(subLbl, tweenInfo, { TextTransparency = 1 }):Play()
		end)
		wait(0.45)
		if frame and frame.Parent then
			frame:Destroy()
		end
	end)
end

-- Settings: Copy Discord link button
local function copyDiscordLink()
	local link = "https://discord.gg/Z9V9XNP67m"
	if typeof(setclipboard) == "function" then
		pcall(function()
			setclipboard(link)
		end)
	end
	showNotification("Discord link copied", "Paste in Discord to join XENT HUB")
end

local copyDiscordBtn = Instance.new("TextButton")
copyDiscordBtn.Name = "CopyDiscordButton"
copyDiscordBtn.Size = UDim2.new(1, 0, 0, 34)
copyDiscordBtn.BackgroundColor3 = Color3.fromRGB(22, 0, 6)
copyDiscordBtn.Text = "Copy Discord link"
copyDiscordBtn.Font = Enum.Font.GothamSemibold
copyDiscordBtn.TextSize = 14
copyDiscordBtn.TextColor3 = Color3.fromRGB(255, 225, 225)
copyDiscordBtn.AutoButtonColor = true
copyDiscordBtn.BorderSizePixel = 0
copyDiscordBtn.Parent = settingsHolder
rounded(copyDiscordBtn, 10)
stroked(copyDiscordBtn, Color3.fromRGB(120, 0, 25), 1.3, 0.2)

copyDiscordBtn.MouseButton1Click:Connect(copyDiscordLink)

-- Protection: Disconnect frame
local function createDisconnectFrame()
	if C.state.ui.disconnectFrame and C.state.ui.disconnectFrame.Parent then
		C.state.ui.disconnectFrame:Destroy()
	end

	local frame = Instance.new("Frame")
	frame.Name = "XentDisconnectFrame"
	frame.Size = UDim2.new(0, 180, 0, 80)
	frame.Position = UDim2.new(0, 30, 0, 80)
	frame.BackgroundColor3 = Color3.fromRGB(14, 0, 6)
	frame.BorderSizePixel = 0
	frame.Parent = gui
	rounded(frame, 10)
	stroked(frame, Color3.fromRGB(255, 70, 90), 1.6, 0.22)
	gradient(frame, Color3.fromRGB(40, 0, 10), Color3.fromRGB(8, 0, 4))
	makeDraggable(frame, frame)

	local btn = Instance.new("TextButton")
	btn.Parent = frame
	btn.Size = UDim2.new(0, 120, 0, 40)
	btn.Position = UDim2.new(0.5, -60, 0.5, -20)
	btn.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 16
	btn.Text = "Disconnect"
	btn.AutoButtonColor = true
	rounded(btn, 8)
	stroked(btn, Color3.fromRGB(255, 120, 120), 1.4, 0.18)

	btn.MouseButton1Click:Connect(function()
		pcall(function()
			game:Shutdown()
		end)
	end)

	C.state.ui.disconnectFrame = frame
end

local function setNavVisual(btn, active)
	local bg = active and Color3.fromRGB(90, 0, 16) or Color3.fromRGB(60, 0, 6)
	local txt = active and Color3.fromRGB(255, 240, 240) or Color3.fromRGB(220, 200, 200)
	TweenService:Create(btn, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		BackgroundColor3 = bg,
		TextColor3 = txt,
	}):Play()
end

local function setPage(name)
	mainPage.Visible = (name == "Main")
	miscPage.Visible = (name == "Misc")
	protectionPage.Visible = (name == "Protection")
	pvpPage.Visible = (name == "PvP")
	settingsPage.Visible = (name == "Settings")
	setNavVisual(mainBtn, name == "Main")
	setNavVisual(miscBtn, name == "Misc")
	setNavVisual(protectionBtn, name == "Protection")
	setNavVisual(pvpBtn, name == "PvP")
	setNavVisual(settingsBtn, name == "Settings")
end

setPage("Main")

mainBtn.MouseButton1Click:Connect(function() setPage("Main") end)
miscBtn.MouseButton1Click:Connect(function() setPage("Misc") end)
protectionBtn.MouseButton1Click:Connect(function() setPage("Protection") end)
pvpBtn.MouseButton1Click:Connect(function() setPage("PvP") end)
settingsBtn.MouseButton1Click:Connect(function() setPage("Settings") end)

-- Visual helpers for toggles
local function setBinaryVisual(btn, knob, on)
	if not btn or not knob then return end
	local goal = on and UDim2.new(1, -22, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
	local knobColor = on and Color3.fromRGB(255, 250, 250) or Color3.fromRGB(255, 220, 220)
	local baseColor = on and Color3.fromRGB(200, 0, 40) or Color3.fromRGB(40, 0, 10)
	TweenService:Create(knob, TweenInfo.new(0.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Position = goal,
		BackgroundColor3 = knobColor,
	}):Play()
	TweenService:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		BackgroundColor3 = baseColor,
	}):Play()
end

local function setDisconnectEnabled(on)
	if C.state.protection.disconnectEnabled == on then return end
	C.state.protection.disconnectEnabled = on
	setBinaryVisual(disconnectBtn, disconnectKnob, on)
	if C.state.ui.disconnectFrame and C.state.ui.disconnectFrame.Parent then
		C.state.ui.disconnectFrame:Destroy()
		C.state.ui.disconnectFrame = nil
	end
	if on then
		createDisconnectFrame()
	end
	markConfigDirty()
end

local function setSaveVisual(on)
	setBinaryVisual(saveBtn, saveKnob, on)
	if saveLabel then
		local txt = on and "Save Configs (ON)" or "Save Configs (OFF)"
		local col = on and Color3.fromRGB(255, 235, 235) or Color3.fromRGB(220, 190, 190)
		saveLabel.Text = txt
		saveLabel.TextColor3 = col
	end
end

setSaveVisual(C.persistent.saveConfigs)

saveBtn.MouseButton1Click:Connect(function()
	C.persistent.saveConfigs = not C.persistent.saveConfigs
	setSaveVisual(C.persistent.saveConfigs)
	if C.persistent.saveConfigs then
		-- Turned ON: allow normal dirty-saving behaviour
		markConfigDirty()
	else
		-- Turned OFF: immediately persist a minimal config with saveConfigs=false
		if canUseFS then
			local out = {
				saveConfigs = false,
				toggles = {},
				booster = { speed = 16, jump = 20, gravity = 100 },
			}
			local okEnc, enc = pcall(function()
				return HttpService:JSONEncode(out)
			end)
			if okEnc then
				pcall(writefile, CONFIG_FILE, enc)
			end
		end
	end
end)
-- Booster logic (compact)
local innerBtn -- forward-declared UI refs for inner Xent boost toggle
local innerKnob

local function setInnerBoosterVisual(on)
	if not innerBtn or not innerKnob then return end
	local pos = on and UDim2.new(1, -22, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
	local knobColor = on and Color3.fromRGB(255, 250, 250) or Color3.fromRGB(255, 220, 220)
	local baseColor = on and Color3.fromRGB(200, 0, 40) or Color3.fromRGB(40, 0, 10)
	innerKnob.Position = pos
	innerKnob.BackgroundColor3 = knobColor
	innerBtn.BackgroundColor3 = baseColor
end

local function getHumanoid()
	local char = player.Character or player.CharacterAdded:Wait()
	return char:WaitForChild("Humanoid")
end

local function clampBoosterFromBoxes()
	local b = C.persistent.booster
	local boxes = C.state.booster.boxes
	local s = tonumber(boxes.speed and boxes.speed.Text)
	local j = tonumber(boxes.jump and boxes.jump.Text)
	local g = tonumber(boxes.gravity and boxes.gravity.Text)
	if s then b.speed = math.clamp(s, 0, 50) end
	if j then b.jump = math.clamp(j, 0, 50) end
	if g then b.gravity = math.clamp(g, 0, 400) end
	markConfigDirty()
end

local function applyBoost()
	if not C.state.booster.enabled then return end
	clampBoosterFromBoxes()
	local hum = getHumanoid()
	local char = hum.Parent
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local move = hum.MoveDirection
	local vel = root.Velocity
	if move.Magnitude > 0 then
		local flat = Vector3.new(move.X, 0, move.Z).Unit
		local target = flat * C.persistent.booster.speed
		root.Velocity = Vector3.new(target.X, vel.Y, target.Z)
	else
		root.Velocity = Vector3.new(0, vel.Y, 0)
	end

	local mass = root.AssemblyMass
	-- Jump force
	if not C.state.booster.jumpForce or C.state.booster.jumpForce.Parent ~= root then
		if C.state.booster.jumpForce then C.state.booster.jumpForce:Destroy() end
		local att = Instance.new("Attachment")
		att.Name = "XentJumpAtt"
		att.Parent = root
		local vf = Instance.new("VectorForce")
		vf.Name = "XentJump"
		vf.RelativeTo = Enum.ActuatorRelativeTo.World
		vf.Attachment0 = att
		vf.Parent = root
		C.state.booster.jumpForce = vf
	end
	local jumpScale = math.clamp(C.persistent.booster.jump, 0, 50) / 50
	local baseUp = mass * workspace.Gravity
	C.state.booster.jumpForce.Force = Vector3.new(0, baseUp * jumpScale * 0.75, 0)

	-- Gravity modifier
	if not C.state.booster.gravityForce or C.state.booster.gravityForce.Parent ~= root then
		if C.state.booster.gravityForce then C.state.booster.gravityForce:Destroy() end
		local attG = Instance.new("Attachment")
		attG.Name = "XentGravAtt"
		attG.Parent = root
		local vfG = Instance.new("VectorForce")
		vfG.Name = "XentGravity"
		vfG.RelativeTo = Enum.ActuatorRelativeTo.World
		vfG.Attachment0 = attG
		vfG.Parent = root
		C.state.booster.gravityForce = vfG
	end
	local scale = math.clamp(C.persistent.booster.gravity, 0, 400) / 100
	local extra = mass * workspace.Gravity * (scale - 1)
	C.state.booster.gravityForce.Force = Vector3.new(0, -extra, 0)
end

local function resetBoost()
	if C.state.booster.jumpForce then
		C.state.booster.jumpForce:Destroy()
		C.state.booster.jumpForce = nil
	end
	if C.state.booster.gravityForce then
		C.state.booster.gravityForce:Destroy()
		C.state.booster.gravityForce = nil
	end
end

local function setBoosterEnabled(on)
	if C.state.booster.enabled == on then return end
	C.state.booster.enabled = on
	setInnerBoosterVisual(on)
	markConfigDirty()
	if on then
		applyBoost()
	else
		resetBoost()
	end
end

local function setBoosterVisible(on)
	C.state.booster.visible = on
	if C.state.ui.boosterFrame then
		C.state.ui.boosterFrame.Visible = on
	end
end

-- Floating booster frame (compact)
local boosterFrame = Instance.new("Frame")
boosterFrame.Name = "XentBoosterFrame"
boosterFrame.Size = UDim2.new(0, 220, 0, 146)
boosterFrame.Position = UDim2.new(1, -260, 0, 80)
boosterFrame.BackgroundColor3 = Color3.fromRGB(14, 0, 6)
boosterFrame.BorderSizePixel = 0
boosterFrame.Visible = false
boosterFrame.ClipsDescendants = true
boosterFrame.Parent = gui
C.state.ui.boosterFrame = boosterFrame
rounded(boosterFrame, 10)
stroked(boosterFrame, Color3.fromRGB(255, 70, 90), 1.8, 0.22)
gradient(boosterFrame, Color3.fromRGB(40, 0, 10), Color3.fromRGB(8, 0, 4))

local boosterHeader = Instance.new("TextButton")
boosterHeader.AutoButtonColor = false
boosterHeader.BackgroundColor3 = Color3.fromRGB(26, 0, 10)
boosterHeader.Size = UDim2.new(1, 0, 0, 30)
boosterHeader.Font = Enum.Font.GothamSemibold
boosterHeader.TextXAlignment = Enum.TextXAlignment.Left
boosterHeader.Text = "  ▼  Xent boost"
boosterHeader.TextColor3 = Color3.fromRGB(255, 230, 230)
boosterHeader.TextSize = 15
boosterHeader.Parent = boosterFrame
rounded(boosterHeader, 10)
stroked(boosterHeader, Color3.fromRGB(255, 90, 120), 1.4, 0.18)
makeDraggable(boosterFrame, boosterHeader)

innerBtn = Instance.new("TextButton")
innerBtn.AnchorPoint = Vector2.new(1, 0.5)
innerBtn.Position = UDim2.new(1, -8, 0.5, 0)
innerBtn.Size = UDim2.new(0, 42, 0, 20)
innerBtn.BackgroundColor3 = Color3.fromRGB(40, 0, 10)
innerBtn.Text = ""
innerBtn.AutoButtonColor = false
innerBtn.Parent = boosterHeader
rounded(innerBtn, 10)
stroked(innerBtn, Color3.fromRGB(255, 80, 110), 1.4, 0.2)

innerKnob = Instance.new("Frame")
innerKnob.Size = UDim2.new(0, 18, 0, 16)
innerKnob.Position = UDim2.new(0, 2, 0.5, -8)
innerKnob.BackgroundColor3 = Color3.fromRGB(255, 220, 220)
innerKnob.BorderSizePixel = 0
innerKnob.Parent = innerBtn
rounded(innerKnob, 9)
stroked(innerKnob, Color3.fromRGB(255, 255, 255), 1, 0.1)

local boosterContent = Instance.new("Frame")
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

local function boosterRow(parent, text, default)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 30)
	row.BackgroundColor3 = Color3.fromRGB(24, 0, 8)
	row.BorderSizePixel = 0
	row.Parent = parent
	rounded(row, 8)
	stroked(row, Color3.fromRGB(140, 0, 30), 1.2, 0.25)
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.new(0.5, -6, 1, 0)
	lbl.Position = UDim2.new(0, 8, 0, 0)
	lbl.Font = Enum.Font.GothamSemibold
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Text = text
	lbl.TextSize = 14
	lbl.TextColor3 = Color3.fromRGB(255, 220, 220)
	lbl.Parent = row
	local box = Instance.new("TextBox")
	box.AnchorPoint = Vector2.new(1, 0.5)
	box.Position = UDim2.new(1, -6, 0.5, 0)
	box.Size = UDim2.new(0.45, 0, 0, 22)
	box.BackgroundColor3 = Color3.fromRGB(28, 0, 10)
	box.Font = Enum.Font.GothamBold
	box.TextSize = 14
	box.TextColor3 = Color3.fromRGB(255, 235, 235)
	box.TextXAlignment = Enum.TextXAlignment.Center
	box.ClearTextOnFocus = true
	box.Text = tostring(default)
	box.BorderSizePixel = 0
	box.Parent = row
	rounded(box, 7)
	stroked(box, Color3.fromRGB(255, 80, 110), 1.4, 0.2)
	box.FocusLost:Connect(function()
		clampBoosterFromBoxes()
		if C.state.booster.enabled then applyBoost() end
	end)
	return box
end

C.state.booster.boxes.speed = boosterRow(boosterContent, "Speed", C.persistent.booster.speed)
C.state.booster.boxes.jump = boosterRow(boosterContent, "Jump", C.persistent.booster.jump)
C.state.booster.boxes.gravity = boosterRow(boosterContent, "Gravity", C.persistent.booster.gravity)

local function setBoosterOpen(open)
	if C.state.booster.open == open then return end
	C.state.booster.open = open
	local target = open and 146 or 34
	TweenService:Create(boosterFrame, TweenInfo.new(0.22, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 220, 0, target),
	}):Play()
	boosterContent.Visible = open
	boosterHeader.Text = open and "  ▼  Xent boost" or "  ►  Xent boost"
end

boosterHeader.MouseButton1Click:Connect(function()
	setBoosterOpen(not C.state.booster.open)
end)

innerBtn.MouseButton1Click:Connect(function()
	setBoosterEnabled(not C.state.booster.enabled)
end)

boosterBtn.MouseButton1Click:Connect(function()
	local v = not C.state.booster.visible
	setBoosterVisible(v)
	setBinaryVisual(boosterBtn, boosterKnob, v)
	markConfigDirty()
end)

player.CharacterAdded:Connect(function()
	task.wait(1)
	if C.state.booster.enabled then
		applyBoost()
	end
end)

RunService.Heartbeat:Connect(function()
	if C.state.booster.enabled then
		applyBoost()
	end
end)

-- Brainrot ESP (compact)
local function clearBrainBillboard()
	local b = C.state.brainrot.billboard
	if b and b.Parent then b:Destroy() end
	C.state.brainrot.billboard = nil
end

local function findHighestBrainGui()
	local bestGui, bestVal
	local count = 0
	for _, inst in ipairs(workspace:GetDescendants()) do
		if inst:IsA("TextLabel") or inst:IsA("TextBox") then
			local txt = inst.Text
			if type(txt) == "string" and txt ~= "" and string.find(txt, "M/s", 1, true) then
				local numStr = string.match(txt, "%$?%s*([%d%.]+)%s*[Mm]/s")
				if numStr then
					local v = tonumber(numStr)
					if v then
						local gui = inst:FindFirstAncestorWhichIsA("BillboardGui") or inst:FindFirstAncestorWhichIsA("SurfaceGui")
						if gui and (not bestVal or v > bestVal) then
							bestVal = v
							bestGui = gui
						end
					end
				end
			end
		end
		count += 1
		if count % 400 == 0 then task.wait() end
	end
	return bestGui, bestVal
end

local function getBrainrotName(gui)
	if not gui then return "?" end
	for _, inst in ipairs(gui:GetDescendants()) do
		if inst:IsA("TextLabel") or inst:IsA("TextBox") then
			local t = inst.Text
			if type(t) == "string" and t ~= "" then
				if not string.find(t, "M/s", 1, true) and not string.find(t, "%$", 1, true) and string.find(t, "%a") then
					return t
				end
			end
		end
	end
	return "?"
end

local function makeBrainBillboard(gui, value)
	local adornee = gui.Adornee or gui.Parent
	if not adornee then return end
	local b = Instance.new("BillboardGui")
	b.Size = UDim2.new(0, 140, 0, 40)
	b.StudsOffset = Vector3.new(0, 2.2, 0)
	b.AlwaysOnTop = true
	b.Parent = adornee
	local nameLbl = Instance.new("TextLabel")
	nameLbl.Size = UDim2.new(1, 0, 0.5, 0)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Font = Enum.Font.GothamBold
	nameLbl.TextScaled = true
	nameLbl.TextColor3 = Color3.new(1,1,1)
	nameLbl.TextStrokeColor3 = Color3.new(0,0,0)
	nameLbl.TextStrokeTransparency = 0
	nameLbl.Text = getBrainrotName(gui)
	nameLbl.Parent = b
	local moneyLbl = Instance.new("TextLabel")
	moneyLbl.Size = UDim2.new(1, 0, 0.5, 0)
	moneyLbl.Position = UDim2.new(0,0,0.5,0)
	moneyLbl.BackgroundTransparency = 1
	moneyLbl.Font = Enum.Font.GothamBold
	moneyLbl.TextScaled = true
	moneyLbl.TextColor3 = Color3.fromRGB(0,255,0)
	moneyLbl.TextStrokeColor3 = Color3.new(0,0,0)
	moneyLbl.TextStrokeTransparency = 0
	moneyLbl.Text = string.format("$%sM/s", tostring(value or "?"))
	moneyLbl.Parent = b
	C.state.brainrot.billboard = b
end

local function scanBrainrot()
	if not C.state.brainrot.enabled then
		clearBrainBillboard()
		C.state.brainrot.currentGui = nil
		return
	end
	local gui, val = findHighestBrainGui()
	if not gui then return end
	if C.state.brainrot.billboard and C.state.brainrot.currentGui == gui and C.state.brainrot.billboard.Parent then
		local nameLbl = C.state.brainrot.billboard:FindFirstChild("TextLabel")
		if nameLbl then nameLbl.Text = getBrainrotName(gui) end
		return
	end
	C.state.brainrot.currentGui = gui
	clearBrainBillboard()
	makeBrainBillboard(gui, val)
end

local function setBrainrotEnabled(on)
	if C.state.brainrot.enabled == on then return end
	C.state.brainrot.enabled = on
	setBinaryVisual(brainBtn, brainKnob, on)
	if on then
		if C.state.brainrot.conn then C.state.brainrot.conn:Disconnect() end
		C.state.brainrot.accum = 0
		C.state.brainrot.conn = RunService.Heartbeat:Connect(function(dt)
			if not C.state.brainrot.enabled then return end
			C.state.brainrot.accum += dt
			if C.state.brainrot.accum >= 1 then
				C.state.brainrot.accum = 0
				scanBrainrot()
			end
		end)
		scanBrainrot()
	else
		if C.state.brainrot.conn then C.state.brainrot.conn:Disconnect() end
		C.state.brainrot.conn = nil
		clearBrainBillboard()
	end
	markConfigDirty()
end

brainBtn.MouseButton1Click:Connect(function()
	setBrainrotEnabled(not C.state.brainrot.enabled)
end)

-- Auto Grab
local function isStealPrompt(prompt)
	local t = ((prompt.ActionText or "") .. " " .. (prompt.ObjectText or "")):lower()
	return string.find(t, "steal", 1, true) ~= nil
end

local function processPrompt(prompt)
	if not C.state.autoGrab.enabled then return end
	if not prompt or not prompt.Parent or not prompt.Enabled then return end
	if not isStealPrompt(prompt) then return end
	local dur = prompt.HoldDuration or 0
	if dur <= 0 then
		pcall(function()
			prompt:InputHoldBegin()
			prompt:InputHoldEnd()
		end)
		return
	end
	task.spawn(function()
		pcall(function()
			prompt:InputHoldBegin()
			local hold = dur + 0.05
			task.delay(hold, function()
				if C.state.autoGrab.enabled and prompt and prompt.Parent and prompt.Enabled then
					prompt:InputHoldEnd()
				end
			end)
		end)
	end)
end

local function triggerExistingPrompts()
	for _, inst in ipairs(workspace:GetDescendants()) do
		if inst:IsA("ProximityPrompt") and inst.Enabled and isStealPrompt(inst) then
			processPrompt(inst)
		end
	end
end

local function setAutoGrab(on)
	if C.state.autoGrab.enabled == on then return end
	C.state.autoGrab.enabled = on
	setBinaryVisual(autoGrabBtn, autoGrabKnob, on)
	if C.state.autoGrab.conn then C.state.autoGrab.conn:Disconnect() end
	if on then
		C.state.autoGrab.conn = ProximityPromptService.PromptShown:Connect(processPrompt)
		triggerExistingPrompts()
	else
		C.state.autoGrab.conn = nil
	end
	markConfigDirty()
end

autoGrabBtn.MouseButton1Click:Connect(function()
	setAutoGrab(not C.state.autoGrab.enabled)
end)

-- Insta Steal (integrated simple steal listener)
local function instaGetCharacter()
	local char = player.Character
	if not char or not char.Parent then
		char = player.CharacterAdded:Wait()
	end
	return char
end

local function instaGetHumanoidRootPart()
	local char = instaGetCharacter()
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function instaHasFlyingCarpetEquipped()
	local char = instaGetCharacter()
	if not char then return false end
	for _, child in ipairs(char:GetChildren()) do
		if child:IsA("Tool") then
			local n = string.lower(child.Name)
			if n:find("flying carpet", 1, true) then
				return true
			end
		end
	end
	return false
end

local function instaGetOrCreateMarker(charName)
	local state = C.state.instaSteal
	if state.marker and state.marker.Parent then
		return state.marker
	end

	local markerName = "XENT_StealMarker_" .. charName
	local existing = workspace:FindFirstChild(markerName)
	if existing and existing:IsA("BasePart") then
		local oldRing = existing:FindFirstChild("XENT_Ring")
		if oldRing then
			oldRing:Destroy()
		end
		state.marker = existing
		return existing
	end

	local marker = Instance.new("Part")
	marker.Name = markerName
	marker.Anchored = true
	marker.CanCollide = false
	marker.Size = Vector3.new(5, 0.2, 5)
	marker.Material = Enum.Material.ForceField
	marker.Color = Color3.fromRGB(0, 210, 255)
	marker.Transparency = 0.7
	marker.TopSurface = Enum.SurfaceType.Smooth
	marker.BottomSurface = Enum.SurfaceType.Smooth

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "XENT_StealBillboard"
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.new(0, 100, 0, 22)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.Adornee = marker
	billboard.Parent = marker

	local bg = Instance.new("Frame")
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3 = Color3.fromRGB(16, 16, 16)
	bg.BorderSizePixel = 0
	bg.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = bg

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -8, 1, -4)
	label.Position = UDim2.new(0, 4, 0, 2)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.Text = "STEAL POS"
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = bg

	marker.Parent = workspace
	state.marker = marker
	return marker
end

local function instaComputeTeleportCFrame()
	local char = instaGetCharacter()
	local hrp = instaGetHumanoidRootPart()
	if not char or not hrp then return nil end

	local username = player.Name
	local displayName = player.DisplayName or username
	local lowerUsername = string.lower(username)
	local lowerDisplayName = string.lower(displayName)

	local targetPart
	local targetFace

	for _, inst in ipairs(workspace:GetDescendants()) do
		if inst:IsA("SurfaceGui") then
			local gui = inst
			local hasMatch = false
			for _, d in ipairs(gui:GetDescendants()) do
				if d:IsA("TextLabel") or d:IsA("TextBox") then
					local text = d.Text or ""
					local lower = string.lower(text)
					if lower:find(lowerDisplayName, 1, true) or lower:find(lowerUsername, 1, true) then
						hasMatch = true
						break
					end
				end
			end
			if hasMatch then
				local adornee = gui.Adornee or gui.Parent
				local parentPart = gui.Parent
				if adornee and adornee:IsA("BasePart") then
					targetPart = adornee
					targetFace = gui.Face
				elseif parentPart and parentPart:IsA("BasePart") then
					targetPart = parentPart
					targetFace = gui.Face
				end
				if targetPart then break end
			end
		end
	end

	if not targetPart then return nil end

	local face = targetFace or Enum.NormalId.Front
	local partCFrame = targetPart.CFrame
	local normal
	if face == Enum.NormalId.Front then
		normal = partCFrame.LookVector
	elseif face == Enum.NormalId.Back then
		normal = -partCFrame.LookVector
	elseif face == Enum.NormalId.Right then
		normal = partCFrame.RightVector
	elseif face == Enum.NormalId.Left then
		normal = -partCFrame.RightVector
	elseif face == Enum.NormalId.Top then
		normal = partCFrame.UpVector
	elseif face == Enum.NormalId.Bottom then
		normal = -partCFrame.UpVector
	else
		normal = partCFrame.LookVector
	end

	local offset
	if face == Enum.NormalId.Right or face == Enum.NormalId.Left then
		offset = targetPart.Size.X * 0.5
	elseif face == Enum.NormalId.Top or face == Enum.NormalId.Bottom then
		offset = targetPart.Size.Y * 0.5
	else
		offset = targetPart.Size.Z * 0.5
	end

	local surfacePos = targetPart.Position + normal * offset
	-- 36 studs forward from the surface, and 5 studs to the "left" of the sign (negative RightVector)
	local leftOffset = -partCFrame.RightVector * 5
	local basePos = surfacePos + normal * 36 + leftOffset + Vector3.new(0, -18, 0)

	local marker = instaGetOrCreateMarker(username)
	marker.CFrame = CFrame.new(basePos)

	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local hip = humanoid and humanoid.HipHeight or 3
	local finalPos = basePos + Vector3.new(0, hip + 2, 0)
	local lookTarget = surfacePos
	return CFrame.new(finalPos, lookTarget)
end

local function instaPromptLooksLikeSteal(prompt)
	local s = ""
	if prompt.ActionText then s = s .. " " .. prompt.ActionText end
	if prompt.ObjectText then s = s .. " " .. prompt.ObjectText end
	if prompt.Name then s = s .. " " .. prompt.Name end
	s = string.lower(s)
	return s:find("steal", 1, true) ~= nil
end

local function instaOnPromptTriggered(prompt, who)
	if who ~= player then return end
	if not instaPromptLooksLikeSteal(prompt) then return end
	if not instaHasFlyingCarpetEquipped() then return end

	local char = instaGetCharacter()
	local hrp = instaGetHumanoidRootPart()
	if not char or not hrp then return end
	local cf = instaComputeTeleportCFrame()
	if not cf then return end

	pcall(function()
		if char.PivotTo then
			char:PivotTo(cf)
		else
			hrp.CFrame = cf
		end
		if hrp.AssemblyLinearVelocity then
			hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
		else
			hrp.Velocity = Vector3.new(0, 0, 0)
			hrp.RotVelocity = Vector3.new(0, 0, 0)
		end
	end)
end

local function instaSetMarkerVisible(visible)
	local state = C.state.instaSteal
	local marker = state.marker
	if not marker or not marker.Parent then return end
	marker.Transparency = visible and 0.7 or 1
	local ring = marker:FindFirstChild("XENT_Ring")
	if ring and ring:IsA("CylinderHandleAdornment") then
		ring.Visible = visible
	end
	local billboard = marker:FindFirstChild("XENT_StealBillboard")
	if billboard and billboard:IsA("BillboardGui") then
		billboard.Enabled = visible
	end
end

local function instaClearVisuals()
	local state = C.state.instaSteal
	if state.beam then
		if state.beam.Parent then state.beam:Destroy() end
		state.beam = nil
	end
	if state.torsoAtt then
		if state.torsoAtt.Parent then state.torsoAtt:Destroy() end
		state.torsoAtt = nil
	end
	if state.markerAtt then
		if state.markerAtt.Parent then state.markerAtt:Destroy() end
		state.markerAtt = nil
	end
end

local function instaUpdateBeamVisuals()
	if not C.state.instaSteal.enabled then
		instaClearVisuals()
		instaSetMarkerVisible(false)
		return
	end
	local char = instaGetCharacter()
	if not char then return end
	local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or instaGetHumanoidRootPart()
	if not torso then return end
	local state = C.state.instaSteal
	local marker = state.marker
	if not marker or not marker.Parent then
		instaClearVisuals()
		instaSetMarkerVisible(false)
		return
	end
	instaSetMarkerVisible(true)
	if not state.torsoAtt or state.torsoAtt.Parent ~= torso then
		if state.torsoAtt and state.torsoAtt.Parent then state.torsoAtt:Destroy() end
		local att = Instance.new("Attachment")
		att.Name = "XentInstaTorsoAtt"
		att.Parent = torso
		state.torsoAtt = att
	end
	if not state.markerAtt or state.markerAtt.Parent ~= marker then
		if state.markerAtt and state.markerAtt.Parent then state.markerAtt:Destroy() end
		local attM = Instance.new("Attachment")
		attM.Name = "XentInstaMarkerAtt"
		attM.Parent = marker
		state.markerAtt = attM
	end
	if not state.beam or not state.beam.Parent then
		if state.beam and state.beam.Parent then state.beam:Destroy() end
		local beam = Instance.new("Beam")
		beam.Name = "XentInstaBeam"
		beam.Attachment0 = state.torsoAtt
		beam.Attachment1 = state.markerAtt
		beam.Width0 = 0.25
		beam.Width1 = 0.25
		beam.FaceCamera = true
		beam.Color = ColorSequence.new(Color3.fromRGB(60, 0, 0), Color3.fromRGB(180, 0, 0))
		beam.Transparency = NumberSequence.new(0.1)
		beam.Parent = torso
		state.beam = beam
	else
		state.beam.Attachment0 = state.torsoAtt
		state.beam.Attachment1 = state.markerAtt
	end
end

local function setInstaSteal(on)
	if C.state.instaSteal.enabled == on then return end
	C.state.instaSteal.enabled = on
	setBinaryVisual(instaBtn, instaKnob, on)
	if C.state.instaSteal.conn then
		C.state.instaSteal.conn:Disconnect()
		C.state.instaSteal.conn = nil
	end
	if on then
		C.state.instaSteal.conn = ProximityPromptService.PromptTriggered:Connect(instaOnPromptTriggered)
		-- First-time enable: compute marker/teleport position once, then build visuals
		instaComputeTeleportCFrame()
		instaUpdateBeamVisuals()
	else
		instaClearVisuals()
		instaSetMarkerVisible(false)
		local m = C.state.instaSteal.marker
		if m and m.Parent then m:Destroy() end
		C.state.instaSteal.marker = nil
	end
	markConfigDirty()
end

instaBtn.MouseButton1Click:Connect(function()
	setInstaSteal(not C.state.instaSteal.enabled)
end)

-- Keep Insta Steal beam correctly attached to our torso across resets
RunService.Heartbeat:Connect(function()
	if not C.state.instaSteal.enabled then return end
	local char = player.Character
	if not char or not char.Parent then
		instaClearVisuals()
		return
	end
	local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
	if not torso then return end
	local state = C.state.instaSteal
	local needsUpdate = false
	if not state.marker or not state.marker.Parent then
		needsUpdate = true
	end
	if not state.torsoAtt or state.torsoAtt.Parent ~= torso then
		needsUpdate = true
	end
	if not state.markerAtt or (state.marker and state.markerAtt.Parent ~= state.marker) then
		needsUpdate = true
	end
	if not state.beam or not state.beam.Parent then
		needsUpdate = true
	end
	if needsUpdate then
		instaUpdateBeamVisuals()
	end
end)

-- Auto kick after steal (simple)
local function textStartsWithYouStole(text)
	if type(text) ~= "string" or text == "" then return false end
	local lower = text:lower()
	return lower:sub(1, 9) == "you stole"
end

local function clearAutoKick()
	for inst, conn in pairs(C.state.autoKick.textConns) do
		if conn.Connected then conn:Disconnect() end
		C.state.autoKick.textConns[inst] = nil
	end
	if C.state.autoKick.rootConn and C.state.autoKick.rootConn.Connected then
		C.state.autoKick.rootConn:Disconnect()
	end
	C.state.autoKick.rootConn = nil
end

local function watchText(inst)
	if not (inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox")) then return end
	if C.state.autoKick.textConns[inst] then return end
	local function check()
		if C.state.autoKick.enabled and textStartsWithYouStole(inst.Text) then
			player:Kick("Auto kick after steal.")
		end
	end
	check()
	C.state.autoKick.textConns[inst] = inst:GetPropertyChangedSignal("Text"):Connect(check)
end

local function setAutoKick(on)
	if C.state.autoKick.enabled == on then return end
	C.state.autoKick.enabled = on
	setBinaryVisual(autoKickBtn, autoKickKnob, on)
	if on then
		clearAutoKick()
		local root = playerGui
		local n = 0
		for _, inst in ipairs(root:GetDescendants()) do
			watchText(inst)
			n += 1
			if n % 200 == 0 then task.wait() end
		end
		C.state.autoKick.rootConn = root.DescendantAdded:Connect(watchText)
	else
		clearAutoKick()
	end
	markConfigDirty()
end

autoKickBtn.MouseButton1Click:Connect(function()
	setAutoKick(not C.state.autoKick.enabled)
end)

-- Anti Knockback (PvP helper)
local function setAntiKnockback(on)
	if C.state.antiKnockback.enabled == on then return end
	C.state.antiKnockback.enabled = on
	setBinaryVisual(antiKnockBtn, antiKnockKnob, on)
	if C.state.antiKnockback.conn then
		C.state.antiKnockback.conn:Disconnect()
		C.state.antiKnockback.conn = nil
	end
	if on then
		C.state.antiKnockback.conn = RunService.Heartbeat:Connect(function()
			if not C.state.antiKnockback.enabled then return end
			local char = player.Character
			if not char then return end
			local hum = char:FindFirstChildOfClass("Humanoid")
			if not hum or hum.Health <= 0 then return end
			local state = hum:GetState()
			if state ~= Enum.HumanoidStateType.Ragdoll and state ~= Enum.HumanoidStateType.FallingDown and state ~= Enum.HumanoidStateType.Physics then
				return
			end
			local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
			if not root then return end
			local lv = root.AssemblyLinearVelocity
			root.AssemblyLinearVelocity = Vector3.new(0, lv.Y, 0)
			root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
			root.Velocity = Vector3.new(0, root.Velocity.Y, 0)
			root.RotVelocity = Vector3.new(0, 0, 0)
		end)
	end
	markConfigDirty()
end

antiKnockBtn.MouseButton1Click:Connect(function()
	setAntiKnockback(not C.state.antiKnockback.enabled)
end)

-- Hitbox (PvP helper)
local function setHitbox(on)
	if C.state.hitbox.enabled == on then return end
	C.state.hitbox.enabled = on
	setBinaryVisual(hitboxBtn, hitboxKnob, on)
	if C.state.hitbox.conn then
		C.state.hitbox.conn:Disconnect()
		C.state.hitbox.conn = nil
	end
	if on then
		C.state.hitbox.conn = RunService.RenderStepped:Connect(function()
			if not C.state.hitbox.enabled then return end
			for _, plr in ipairs(Players:GetPlayers()) do
				if plr ~= player and plr.Character then
					local root = plr.Character:FindFirstChild("HumanoidRootPart")
					if root then
						root.Size = Vector3.new(12, 12, 12)
						root.Transparency = 0.4
						root.Color = Color3.fromRGB(255, 255, 255)
						root.Material = Enum.Material.SmoothPlastic
						root.CanCollide = false
					end
				end
			end
		end)
	else
		-- Reset hitboxes back to normal-ish values
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr.Character then
				local root = plr.Character:FindFirstChild("HumanoidRootPart")
				if root then
					root.Size = Vector3.new(2, 2, 1)
					root.Transparency = 1
					root.Material = Enum.Material.Plastic
				end
			end
		end
	end
	markConfigDirty()
end

hitboxBtn.MouseButton1Click:Connect(function()
	setHitbox(not C.state.hitbox.enabled)
end)

-- Anti Ragdoll (PvP helper)
local function clearAntiRagdollConns()
	for _, conn in ipairs(C.state.antiRagdoll.conns) do
		if conn and conn.Connected then
			conn:Disconnect()
		end
	end
	C.state.antiRagdoll.conns = {}
end

local function setupAntiRagdollForCharacter(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	local root = char:FindFirstChild("HumanoidRootPart")
	if not hum or not root then return end
	local animator = hum:FindFirstChildOfClass("Animator")
	local lastVel = Vector3.new(0, 0, 0)

	local function isRagdollState(st)
		return st == Enum.HumanoidStateType.Physics
			or st == Enum.HumanoidStateType.Ragdoll
			or st == Enum.HumanoidStateType.FallingDown
			or st == Enum.HumanoidStateType.GettingUp
	end

	local function cleanupRagdoll()
		for _, inst in ipairs(char:GetDescendants()) do
			if inst:IsA("BallSocketConstraint")
				or inst:IsA("NoCollisionConstraint")
				or inst:IsA("HingeConstraint") then
				inst:Destroy()
			elseif inst:IsA("Attachment") and (inst.Name == "A" or inst.Name == "B") then
				inst:Destroy()
			elseif inst:IsA("BodyVelocity") or inst:IsA("BodyPosition") or inst:IsA("BodyGyro") then
				inst:Destroy()
			end
		end
		for _, inst in ipairs(char:GetDescendants()) do
			if inst:IsA("Motor6D") then
				inst.Enabled = true
			end
		end
		if animator then
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				local name = ""
				pcall(function()
					if track.Animation and track.Animation.Name then
						name = string.lower(track.Animation.Name)
					end
				end)
				if string.find(name, "rag") or string.find(name, "fall") or string.find(name, "hurt") or string.find(name, "down") then
					track:Stop(0)
				end
			end
		end
	end

	local function forceStand()
		if isRagdollState(hum:GetState()) then
			hum:ChangeState(Enum.HumanoidStateType.Running)
			cleanupRagdoll()
		end
	end

	table.insert(C.state.antiRagdoll.conns, hum.StateChanged:Connect(function(_, newState)
		if not C.state.antiRagdoll.enabled then return end
		if isRagdollState(newState) then
			forceStand()
		end
	end))

	table.insert(C.state.antiRagdoll.conns, char.DescendantAdded:Connect(function()
		if not C.state.antiRagdoll.enabled then return end
		if isRagdollState(hum:GetState()) then
			cleanupRagdoll()
		end
	end))

	table.insert(C.state.antiRagdoll.conns, RunService.Heartbeat:Connect(function()
		if not C.state.antiRagdoll.enabled then return end
		if hum.Health <= 0 then return end
		if isRagdollState(hum:GetState()) then
			cleanupRagdoll()
			local v = root.AssemblyLinearVelocity
			if (v - lastVel).Magnitude > 0 then
				root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
				root.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
			end
		end
		lastVel = root.AssemblyLinearVelocity
	end))
end

local function setAntiRagdoll(on)
	if C.state.antiRagdoll.enabled == on then return end
	C.state.antiRagdoll.enabled = on
	setBinaryVisual(antiRagdollBtn, antiRagdollKnob, on)
	clearAntiRagdollConns()
	if on then
		local char = player.Character or player.CharacterAdded:Wait()
		setupAntiRagdollForCharacter(char)
		local conn = player.CharacterAdded:Connect(function(newChar)
			if not C.state.antiRagdoll.enabled then return end
			setupAntiRagdollForCharacter(newChar)
		end)
		table.insert(C.state.antiRagdoll.conns, conn)
	end
	markConfigDirty()
end

antiRagdollBtn.MouseButton1Click:Connect(function()
	setAntiRagdoll(not C.state.antiRagdoll.enabled)
end)

-- No animation (PvP/Main helper - disables all character animations)
local function clearNoAnimationConns()
	for _, conn in ipairs(C.state.noAnimation.conns) do
		if conn and conn.Connected then
			conn:Disconnect()
		end
	end
	C.state.noAnimation.conns = {}
end

local function setupNoAnimationForCharacter(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then return end

	local function stopAllTracks()
		pcall(function()
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				track:Stop(0)
			end
		end)
	end

	stopAllTracks()

	table.insert(C.state.noAnimation.conns, animator.AnimationPlayed:Connect(function(track)
		if not C.state.noAnimation.enabled then return end
		pcall(function()
			track:Stop(0)
		end)
	end))
end

local function setNoAnimation(on)
	if C.state.noAnimation.enabled == on then return end
	C.state.noAnimation.enabled = on
	setBinaryVisual(noAnimBtn, noAnimKnob, on)
	clearNoAnimationConns()
	if on then
		local char = player.Character or player.CharacterAdded:Wait()
		setupNoAnimationForCharacter(char)
		local conn = player.CharacterAdded:Connect(function(newChar)
			if not C.state.noAnimation.enabled then return end
			setupNoAnimationForCharacter(newChar)
		end)
		table.insert(C.state.noAnimation.conns, conn)
	end
	markConfigDirty()
end

noAnimBtn.MouseButton1Click:Connect(function()
	setNoAnimation(not C.state.noAnimation.enabled)
end)

-- Aimbot (Laser Cape / Web slinger auto-fire)
local function getAimbotRemote()
	if C.state.aimbot.remote and C.state.aimbot.remote.Parent then
		return C.state.aimbot.remote
	end
	local packages = ReplicatedStorage:FindFirstChild("Packages")
	if not packages then return nil end
	local net = packages:FindFirstChild("Net") or packages:FindFirstChild("Net2") or packages:FindFirstChild("Net3")
	if not net then return nil end
	local found
	for _, inst in ipairs(net:GetDescendants()) do
		if inst:IsA("RemoteEvent") and (inst.Name == "UseItem" or inst.Name == "RE/UseItem") then
			found = inst
			break
		end
	end
	if found then
		C.state.aimbot.remote = found
		return found
	end
	return nil
end

local function getEquippedAimbotTool()
	local char = player.Character
	if not char then return nil end
	local tool = char:FindFirstChild("Laser Cape")
		or char:FindFirstChild("Web slinger")
		or char:FindFirstChild("Web Slinger")
		or char:FindFirstChild("Paintball Gun")
	if tool and tool:IsA("Tool") then
		return tool
	end
	return nil
end

local function getClosestEnemyRoot(maxDist)
	local char = player.Character
	if not char then return nil end
	local myRoot = char:FindFirstChild("HumanoidRootPart")
	if not myRoot then return nil end
	local closest, best
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= player and plr.Character then
			local root = plr.Character:FindFirstChild("HumanoidRootPart")
			local hum = plr.Character:FindFirstChildOfClass("Humanoid")
			if root and hum and hum.Health > 0 then
				local d = (myRoot.Position - root.Position).Magnitude
				if d <= maxDist and (not best or d < best) then
					best = d
					closest = root
				end
			end
		end
	end
	return closest
end

local function aimbotFireOnce()
	local tool = getEquippedAimbotTool()
	if not tool then return end
	local remote = getAimbotRemote()
	if not remote then return end
	local targetRoot = getClosestEnemyRoot(55)
	if not targetRoot then return end
	local char = player.Character or player.CharacterAdded:Wait()
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	pcall(function()
		remote:FireServer(targetRoot.Position, targetRoot)
	end)
end

local function setAimbot(on)
	if C.state.aimbot.enabled == on then return end
	C.state.aimbot.enabled = on
	setBinaryVisual(aimbotBtn, aimbotKnob, on)
	if C.state.aimbot.thread then
		C.state.aimbot.thread = nil
	end
	if on then
		C.state.aimbot.thread = task.spawn(function()
			while C.state.aimbot.enabled do
				local tool = getEquippedAimbotTool()
				if tool and tool.Name == "Paintball Gun" then
					-- Max-speed firing for Paintball Gun (no intentional delay)
					aimbotFireOnce()
					if not C.state.aimbot.enabled then break end
					task.wait(0)
				else
					-- Keep roughly original rate (~1s) for other tools
					aimbotFireOnce()
					for _ = 1, 5 do
						if not C.state.aimbot.enabled then break end
						task.wait(0.2)
					end
				end
			end
		end)
	end
	markConfigDirty()
end

aimbotBtn.MouseButton1Click:Connect(function()
	setAimbot(not C.state.aimbot.enabled)
end)

-- Anti Steal (simplified)
local function equipBodySwap()
	local char = player.Character or player.CharacterAdded:Wait()
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return end
	local tool = backpack:FindFirstChild("Body Swap Potion") or char:FindFirstChild("Body Swap Potion")
	if not (tool and tool:IsA("Tool")) then return end
	tool.Parent = char
	hum:EquipTool(tool)
	task.spawn(function()
		task.wait(0.05)
		tool:Activate()
	end)
end

local function setAntiSteal(on)
	if C.state.antiSteal.enabled == on then return end
	C.state.antiSteal.enabled = on
	setBinaryVisual(antiStealBtn, antiStealKnob, on)
	if C.state.antiSteal.conn then C.state.antiSteal.conn:Disconnect() end
	if on then
		C.state.antiSteal.accum = 0
		C.state.antiSteal.conn = RunService.Heartbeat:Connect(function(dt)
			if not C.state.antiSteal.enabled then return end
			C.state.antiSteal.accum += dt
			if C.state.antiSteal.accum < 0.25 then return end
			C.state.antiSteal.accum = 0
			local now = tick()
			if now - C.state.antiSteal.lastTrigger < 1.5 then return end
			-- Only react when the game's bottom warning appears, not our own UI hint
			local search = "someone is stealing your"
			for _, inst in ipairs(playerGui:GetDescendants()) do
				if not (inst:IsA("TextLabel") or inst:IsA("TextBox")) then
					continue
				end
				-- Skip any text that is part of the XENT HUB UI itself
				if inst:IsDescendantOf(gui) then
					continue
				end
				-- Only consider labels that are currently visible on screen
				if inst:IsA("GuiObject") and not inst.Visible then
					continue
				end
				local t = inst.Text
				if type(t) == "string" and t ~= "" then
					local lower = t:lower()
					if string.find(lower, search, 1, true) then
						C.state.antiSteal.lastTrigger = now
						equipBodySwap()
						break
					end
				end
			end
		end)
	else
		C.state.antiSteal.conn = nil
	end
	markConfigDirty()
end

antiStealBtn.MouseButton1Click:Connect(function()
	setAntiSteal(not C.state.antiSteal.enabled)
end)

disconnectBtn.MouseButton1Click:Connect(function()
	setDisconnectEnabled(not C.state.protection.disconnectEnabled)
end)

-- Xray (minimal: just colorful beams to highest brainrot and base)
local function clearXray()
	if C.state.xray.conn then C.state.xray.conn:Disconnect() end
	C.state.xray.conn = nil
	for _, att in ipairs({ C.state.xray.fromAtt, C.state.xray.brainAtt, C.state.xray.nickAtt }) do
		if att and att.Parent then att:Destroy() end
	end
	C.state.xray.fromAtt = nil
	C.state.xray.brainAtt = nil
	C.state.xray.nickAtt = nil
	for _, beam in ipairs({ C.state.xray.brainBeam, C.state.xray.nickBeam }) do
		if beam and beam.Parent then beam:Destroy() end
	end
	C.state.xray.brainBeam = nil
	C.state.xray.nickBeam = nil
end

local function setXray(on)
	if C.state.xray.enabled == on then return end
	C.state.xray.enabled = on
	setBinaryVisual(xrayBtn, xrayKnob, on)
	clearXray()
	if not on then
		markConfigDirty()
		return
	end
	local guiBrain = select(1, findHighestBrainGui())
	if not guiBrain then return end
	local char = player.Character or player.CharacterAdded:Wait()
	local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso")
	if not root then return end

	-- Attachment at our character
	C.state.xray.fromAtt = Instance.new("Attachment")
	C.state.xray.fromAtt.Parent = root

	-- Attachment at best brainrot billboard
	C.state.xray.brainAtt = Instance.new("Attachment")
	C.state.xray.brainAtt.Name = "XentXrayBrainrotAttachment"
	C.state.xray.brainAtt.Position = Vector3.new(-2, -5, 0)
	C.state.xray.brainAtt.Parent = guiBrain.Adornee or guiBrain.Parent

	-- Find base sign for our own base (SurfaceGui/BillboardGui with our name + "base")
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
		if nicknameParent then break end
	end

	-- Attachment under the base sign (15 studs down)
	C.state.xray.nickAtt = Instance.new("Attachment")
	C.state.xray.nickAtt.Name = "XentXrayNicknameAttachment"
	C.state.xray.nickAtt.Position = Vector3.new(0, -15, 0)
	C.state.xray.nickAtt.Parent = nicknameParent or root

	-- Beam from us to best brainrot
	local b1 = Instance.new("Beam")
	b1.Attachment0 = C.state.xray.fromAtt
	b1.Attachment1 = C.state.xray.brainAtt
	b1.Width0 = 0.35; b1.Width1 = 0.35
	b1.FaceCamera = true
	b1.Transparency = NumberSequence.new(0.05)
	b1.Parent = root
	C.state.xray.brainBeam = b1

	-- Beam from us to our base sign (or root if not found)
	local b2 = Instance.new("Beam")
	b2.Attachment0 = C.state.xray.fromAtt
	b2.Attachment1 = C.state.xray.nickAtt
	b2.Width0 = 0.35; b2.Width1 = 0.35
	b2.FaceCamera = true
	b2.Transparency = NumberSequence.new(0.05)
	b2.Parent = root
	C.state.xray.nickBeam = b2

	local accum = 0
	C.state.xray.conn = RunService.Heartbeat:Connect(function(dt)
		if not C.state.xray.enabled then clearXray() return end
		accum += dt
		local hue = (os.clock() * 0.3) % 1
		local col = Color3.fromHSV(hue, 1, 1)
		local seq = ColorSequence.new(col)
		if C.state.xray.brainBeam then C.state.xray.brainBeam.Color = seq end
		if C.state.xray.nickBeam then C.state.xray.nickBeam.Color = seq end
	end)
	markConfigDirty()
end

xrayBtn.MouseButton1Click:Connect(function()
	setXray(not C.state.xray.enabled)
end)

-- Smooth world (lighting + parts)
local function applySmoothWorld()
	if Lighting then
		Lighting.GlobalShadows = false
		Lighting.Brightness = math.min(Lighting.Brightness, 2)
		Lighting.EnvironmentDiffuseScale = 0
		Lighting.EnvironmentSpecularScale = 0
		for _, inst in ipairs(Lighting:GetDescendants()) do
			if inst:IsA("BloomEffect") or inst:IsA("ColorCorrectionEffect") or inst:IsA("DepthOfFieldEffect") or inst:IsA("SunRaysEffect") or inst:IsA("BlurEffect") then
				inst.Enabled = false
			end
		end
	end
	task.spawn(function()
		local processed = 0
		local function flatten(part)
			if not part:IsA("BasePart") then return end
			-- Skip any parts that belong to character models (with a Humanoid)
			local model = part:FindFirstAncestorOfClass("Model")
			if model and model:FindFirstChildOfClass("Humanoid") then
				return
			end
			part.Material = Enum.Material.SmoothPlastic
			part.Reflectance = 0
			part.CastShadow = false
			part.TopSurface = Enum.SurfaceType.Smooth
			part.BottomSurface = Enum.SurfaceType.Smooth
			if part:IsA("Part") or part:IsA("WedgePart") or part:IsA("CornerWedgePart") or part:IsA("TrussPart") or part:IsA("MeshPart") then
				part.FrontSurface = Enum.SurfaceType.Smooth
				part.BackSurface = Enum.SurfaceType.Smooth
				part.LeftSurface = Enum.SurfaceType.Smooth
				part.RightSurface = Enum.SurfaceType.Smooth
			end
		end

		for _, inst in ipairs(workspace:GetDescendants()) do
			if inst:IsA("BasePart") then
				local ok = pcall(flatten, inst)
				if ok then
					processed += 1
					if processed % 300 == 0 then task.wait() end
				end
			end
		end

		workspace.DescendantAdded:Connect(function(inst)
			if inst:IsA("BasePart") then
				pcall(flatten, inst)
			end
		end)
	end)
end

-- Invisible walls (similar behaviour to original XentHubRedUI.lua)
local function collectInvisibleWallParts()
	local parts = {}
	local count = 0
	for _, inst in ipairs(workspace:GetDescendants()) do
		if inst:IsA("BasePart") then
			local model = inst:FindFirstAncestorOfClass("Model")
			local isCharacterPart = false
			if model and model:FindFirstChildOfClass("Humanoid") then
				isCharacterPart = true
			end
			if not isCharacterPart and inst.Transparency == 0 then
				local up = inst.CFrame.UpVector
				local isGroundLike = up.Y > 0.7
				if not isGroundLike then
					parts[inst] = true
					count += 1
					if count % 500 == 0 then
						task.wait()
					end
				end
			end
		end
	end
	C.state.invisibleWalls.parts = parts
end

local function applyInvisibleWalls()
	local parts = C.state.invisibleWalls.parts or {}
	if not next(parts) then
		collectInvisibleWallParts()
		parts = C.state.invisibleWalls.parts or {}
	end
	local processed = 0
	for part in pairs(parts) do
		if part and part.Parent then
			part.Transparency = 0.69
			processed += 1
			if processed % 500 == 0 then
				task.wait()
			end
		end
	end
end

local function startInvisibleWalls()
	if C.state.invisibleWalls.running then return end
	C.state.invisibleWalls.running = true
	task.spawn(function()
		while C.state.invisibleWalls.running do
			collectInvisibleWallParts()
			applyInvisibleWalls()
			for _ = 1, 50 do
				if not C.state.invisibleWalls.running then break end
				task.wait(0.2)
			end
		end
	end)
end

-- Simple ESP for other players
local function clearEspFor(plr)
	local objs = C.state.playersEsp.objects[plr]
	if objs then
		for _, o in ipairs(objs) do if o and o.Parent then o:Destroy() end end
	end
	C.state.playersEsp.objects[plr] = nil
	local conns = C.state.playersEsp.perPlayer[plr]
	if conns then
		for _, c in ipairs(conns) do if c then c:Disconnect() end end
	end
	C.state.playersEsp.perPlayer[plr] = nil
end

local function createEsp(plr, char)
	if not char or not char.Parent then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	clearEspFor(plr)
	local h = Instance.new("Highlight")
	h.Adornee = char
	h.FillTransparency = 0.65
	h.OutlineTransparency = 0
	h.OutlineColor = Color3.fromRGB(255, 90, 90)
	h.Parent = char
	local b = Instance.new("BillboardGui")
	b.Adornee = root
	b.Size = UDim2.new(0, 80, 0, 20)
	b.StudsOffset = Vector3.new(0, 4, 0)
	b.AlwaysOnTop = true
	b.MaxDistance = 0
	b.Parent = root
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Font = Enum.Font.GothamBold
	lbl.TextSize = 14
	lbl.Text = plr.Name
	lbl.TextColor3 = Color3.fromRGB(255, 120, 120)
	lbl.TextStrokeColor3 = Color3.new(0,0,0)
	lbl.TextStrokeTransparency = 0
	lbl.TextWrapped = true
	lbl.Parent = b
	C.state.playersEsp.objects[plr] = { h, b }
	local conns = {}
	conns[#conns+1] = char.AncestryChanged:Connect(function(_, parent)
		if not parent then clearEspFor(plr) end
	end)
	C.state.playersEsp.perPlayer[plr] = conns
end

local function enableEspPlayers()
	if C.state.playersEsp.enabled then return end
	C.state.playersEsp.enabled = true
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= player then
			local char = plr.Character or plr.CharacterAdded:Wait()
			createEsp(plr, char)
		end
	end
	local g = C.state.playersEsp.globalConns
	g[#g+1] = Players.PlayerAdded:Connect(function(plr)
		if plr == player then return end
		if not C.state.playersEsp.enabled then return end
		local c = plr.Character or plr.CharacterAdded:Wait()
		createEsp(plr, c)
	end)
	g[#g+1] = Players.PlayerRemoving:Connect(function(plr)
		clearEspFor(plr)
	end)
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= player then
			g[#g+1] = plr.CharacterAdded:Connect(function(c)
				if C.state.playersEsp.enabled then createEsp(plr, c) end
			end)
		end
	end
end

-- Base cooldown overlays (countdown per base, single overlay per base)
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
			if type(text) == "string" and text ~= "" and string.find(text, "M/s", 1, true) then
				local numStr = string.match(text, "%$?%s*([%d%.]+)%s*[Mm]/s")
				if numStr then
					seconds = tonumber(numStr)
				end
			end
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
	for _, data in pairs(C.state.baseCooldown.overlays) do
		local billboard = data.billboard
		if billboard and billboard.Parent then
			billboard:Destroy()
		end
	end
	C.state.baseCooldown.overlays = {}
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
		inspected += 1
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

			C.state.baseCooldown.overlays[data.sourceGui] = {
				source = data.sourceGui,
				billboard = billboard,
				label = label,
			}
		end
	end
end

local function startBaseCooldownUpdater()
	if C.state.baseCooldown.updaterRunning then
		return
	end
	C.state.baseCooldown.updaterRunning = true

	task.spawn(function()
		while C.state.baseCooldown.enabled do
			-- Rebuild overlays only if we've lost all of them
			if not next(C.state.baseCooldown.overlays) then
				createBaseCooldownOverlays()
			end
			for sourceGui, data in pairs(C.state.baseCooldown.overlays) do
				local billboard = data.billboard
				local label = data.label
				if (not sourceGui) or (not sourceGui.Parent) then
					if billboard and billboard.Parent then
						billboard:Destroy()
					end
					C.state.baseCooldown.overlays[sourceGui] = nil
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
				if not C.state.baseCooldown.enabled then
					break
				end
				task.wait(0.1)
			end
		end

		clearBaseCooldownOverlays()
		C.state.baseCooldown.updaterRunning = false
	end)
end

local function setBaseCooldownEnabled(on)
	if C.state.baseCooldown.enabled == on then
		return
	end
	C.state.baseCooldown.enabled = on
	if on then
		createBaseCooldownOverlays()
		if C.state.instaSteal.enabled then
			instaUpdateBeamVisuals()
		end
		startBaseCooldownUpdater()
	else
		-- updater loop handles cleanup when it exits
	end
end

-- When new players join, bases may change ownership; refresh overlays once
Players.PlayerAdded:Connect(function()
	if C.state.baseCooldown.enabled then
		createBaseCooldownOverlays()
		if C.state.instaSteal.enabled then
			instaUpdateBeamVisuals()
		end
	end
end)

-- When our character respawns, restore Insta Steal visuals if enabled
player.CharacterAdded:Connect(function()
	if C.state.instaSteal.enabled then
		task.wait(1)
		instaUpdateBeamVisuals()
	end
end)

-- Auto-restore toggles from config
if C.persistent.saveConfigs then
	local t = C.persistent.toggles or {}
	if t.boosterMain then
		setBoosterVisible(true)
		setBinaryVisual(boosterBtn, boosterKnob, true)
	end
	if t.boosterBoost then
		setBoosterEnabled(true)
		setBinaryVisual(innerBtn, innerKnob, true)
	end
	if t.autoGrab then setAutoGrab(true) end
	if t.brainrotEsp then setBrainrotEnabled(true) end
	if t.autoKick then setAutoKick(true) end
	if t.antiSteal then setAntiSteal(true) end
	if t.aimbot then setAimbot(true) end
	if t.disconnectButton then setDisconnectEnabled(true) end
	if t.xray then setXray(true) end
	if t.noAnimation then setNoAnimation(true) end
	if t.antiKnockback then setAntiKnockback(true) end
	if t.hitbox then setHitbox(true) end
	if t.antiRagdoll then setAntiRagdoll(true) end
	if t.instaSteal then setInstaSteal(true) end
end

-- Auto-enable world optimizations and ESP
applySmoothWorld()
startInvisibleWalls()
setBaseCooldownEnabled(true)
enableEspPlayers()
