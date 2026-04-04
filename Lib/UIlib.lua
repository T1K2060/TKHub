--[[
╔══════════════════════════════════════════════════════════════════╗
║                    TKLib — UIlib.lua  v3.0                      ║
║          Hub-style Roblox GUI Framework by T1K2060              ║
║  Fully backward-compatible with v2.x scripts                    ║
╚══════════════════════════════════════════════════════════════════╝

New in v3.0:
  • CreateColorPicker  — inline swatch → opens color editor
  • CreateKeybind      — click-to-bind keybind element
  • CreateProgressBar  — read-only updateable progress bar
  • CreateTable        — scrollable rows/columns grid
  • Collapsible sections
  • Window inner-tabs (sub-pages inside one window)
  • Resizable windows  (drag bottom-right corner)
  • Window minimize    (title bar double-click or minus button)
  • Config auto-save/load (every toggle/slider/dropdown persists)
  • Profile system     (named config slots)
  • Import/Export config (base64 clipboard)
  • Script Hub: Favorites, Script Preview, Game Filter, Recent
  • Context menu       (right-click any element)
  • Tooltip system     (UIlib.SetTooltip)
  • Window search bar
  • Animation presets  (slide, fade, bounce)
  • Mobile/touch support
  • Event system       (UIlib.on / UIlib.fire)
  • Element registry   (UIlib.GetElement)
  • UIlib.Version / UIlib.CheckForUpdates
  • Error boundary     (pcall + error toast for all callbacks)
  • Reworked notification system (stack, icons, progress, actions)
]]

local UIlib = {}
UIlib.Version = "3.0.0"

-- ───────────────────────────────────────────────────────────────
-- SERVICES
-- ───────────────────────────────────────────────────────────────
local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local RunService       = game:GetService("RunService")
local HttpService      = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Mouse       = LocalPlayer:GetMouse()

-- ───────────────────────────────────────────────────────────────
-- INTERNAL STATE
-- ───────────────────────────────────────────────────────────────
local _windows      = {}   -- all WindowObj
local _activeWin    = nil
local _notifStack   = {}
local _tooltipLabel = nil
local _tooltipConn  = nil
local _events       = {}   -- event system listeners
local _registry     = {}   -- element registry [winName][secName][elemName]
local _configData   = {}   -- auto-save data {winName_secName_elemName = value}
local _profiles     = {}   -- {profileName = configTable}
local _activeProfile = "Default"
local _opacitySnap  = nil
local _animPreset   = "slide" -- slide | fade | bounce
local _screenGui    = nil
local _sidebar      = nil
local _notifHolder  = nil
local _contextMenu  = nil

-- ───────────────────────────────────────────────────────────────
-- DEFAULT THEME
-- ───────────────────────────────────────────────────────────────
UIlib.THEME = {
	Background        = Color3.fromRGB(18, 18, 22),
	BackgroundLight   = Color3.fromRGB(32, 32, 40),
	SideBar           = Color3.fromRGB(24, 24, 30),
	SideBarBtn        = Color3.fromRGB(32, 32, 40),
	SideBarBtnActive  = Color3.fromRGB(50, 50, 65),
	Accent            = Color3.fromRGB(120, 160, 255),
	Text              = Color3.fromRGB(230, 230, 235),
	TextDim           = Color3.fromRGB(130, 130, 145),
	ButtonBG          = Color3.fromRGB(45, 45, 58),
	ButtonHover       = Color3.fromRGB(60, 60, 78),
	ToggleOff         = Color3.fromRGB(55, 55, 68),
	ToggleOn          = Color3.fromRGB(100, 145, 255),
	SliderBG          = Color3.fromRGB(45, 45, 58),
	SliderFill        = Color3.fromRGB(120, 160, 255),
	SectionHeader     = Color3.fromRGB(38, 38, 48),
	Separator         = Color3.fromRGB(50, 50, 62),
	NotifyBG          = Color3.fromRGB(28, 28, 35),
	NotifyBorder      = Color3.fromRGB(55, 55, 70),
	ProgressBG        = Color3.fromRGB(38, 38, 50),
	ProgressFill      = Color3.fromRGB(100, 200, 140),
	TableHeader       = Color3.fromRGB(38, 38, 50),
	TableRow          = Color3.fromRGB(28, 28, 36),
	TableRowAlt       = Color3.fromRGB(32, 32, 42),
	ContextBG         = Color3.fromRGB(30, 30, 40),
	ContextHover      = Color3.fromRGB(50, 50, 65),
	TooltipBG         = Color3.fromRGB(20, 20, 28),
	KeybindBG         = Color3.fromRGB(38, 38, 50),
}

-- ───────────────────────────────────────────────────────────────
-- UTILITY HELPERS
-- ───────────────────────────────────────────────────────────────
local function tween(obj, props, t, style, dir)
	style = style or Enum.EasingStyle.Quad
	dir   = dir   or Enum.EasingDirection.Out
	local ti = TweenInfo.new(t or 0.18, style, dir)
	local tw = TweenService:Create(obj, ti, props)
	tw:Play()
	return tw
end

local function safeCall(fn, ...)
	if not fn then return end
	local ok, err = pcall(fn, ...)
	if not ok then
		UIlib.Notify("Script Error", tostring(err):sub(1, 100), 5, "error")
	end
end

local function fire(event, ...)
	if _events[event] then
		for _, fn in ipairs(_events[event]) do
			task.spawn(fn, ...)
		end
	end
end

local function makeCorner(parent, radius)
	local c = Instance.new("UICorner", parent)
	c.CornerRadius = UDim.new(0, radius or 6)
	return c
end

local function makePadding(parent, t, b, l, r)
	local p = Instance.new("UIPadding", parent)
	p.PaddingTop    = UDim.new(0, t or 6)
	p.PaddingBottom = UDim.new(0, b or 6)
	p.PaddingLeft   = UDim.new(0, l or 8)
	p.PaddingRight  = UDim.new(0, r or 8)
	return p
end

local function makeList(parent, padding, sort)
	local ul = Instance.new("UIListLayout", parent)
	ul.Padding         = UDim.new(0, padding or 6)
	ul.SortOrder       = sort or Enum.SortOrder.LayoutOrder
	ul.FillDirection   = Enum.FillDirection.Vertical
	ul.HorizontalAlignment = Enum.HorizontalAlignment.Center
	return ul
end

local function draggable(frame, handle)
	handle = handle or frame
	local dragging, dragStart, startPos = false, nil, nil
	handle.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1
		or inp.UserInputType == Enum.UserInputType.Touch then
			dragging  = true
			dragStart = inp.Position
			startPos  = frame.Position
		end
	end)
	UserInputService.InputChanged:Connect(function(inp)
		if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement
		or inp.UserInputType == Enum.UserInputType.Touch) then
			local delta = inp.Position - dragStart
			frame.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + delta.X,
				startPos.Y.Scale, startPos.Y.Offset + delta.Y
			)
		end
	end)
	UserInputService.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1
		or inp.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
end

local function resizable(frame, minW, minH)
	minW = minW or 280
	minH = minH or 200
	local handle = Instance.new("Frame", frame)
	handle.Size                = UDim2.new(0, 14, 0, 14)
	handle.Position            = UDim2.new(1, -14, 1, -14)
	handle.BackgroundColor3    = UIlib.THEME.Accent
	handle.BackgroundTransparency = 0.6
	handle.BorderSizePixel     = 0
	handle.ZIndex              = 10
	handle.Name                = "ResizeHandle"
	makeCorner(handle, 2)

	local resizing, resizeStart, startSize = false, nil, nil
	handle.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1
		or inp.UserInputType == Enum.UserInputType.Touch then
			resizing    = true
			resizeStart = inp.Position
			startSize   = frame.AbsoluteSize
		end
	end)
	UserInputService.InputChanged:Connect(function(inp)
		if resizing and (inp.UserInputType == Enum.UserInputType.MouseMovement
		or inp.UserInputType == Enum.UserInputType.Touch) then
			local delta = inp.Position - resizeStart
			local nw = math.max(minW, startSize.X + delta.X)
			local nh = math.max(minH, startSize.Y + delta.Y)
			frame.Size = UDim2.new(0, nw, 0, nh)
		end
	end)
	UserInputService.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1
		or inp.UserInputType == Enum.UserInputType.Touch then
			resizing = false
		end
	end)
	return handle
end

-- ───────────────────────────────────────────────────────────────
-- CONFIG / PERSISTENCE
-- ───────────────────────────────────────────────────────────────
local function cfgKey(winName, secName, elemName)
	return winName.."▸"..secName.."▸"..elemName
end

local function cfgSave(key, value)
	_configData[key] = value
	pcall(function()
		if makefolder and not isfolder("TKLib") then makefolder("TKLib") end
		if makefolder and not isfolder("TKLib/profiles") then makefolder("TKLib/profiles") end
		_profiles[_activeProfile] = _configData
		local json = HttpService:JSONEncode(_profiles)
		if writefile then writefile("TKLib/profiles.json", json) end
	end)
end

local function cfgLoad(key)
	return _configData[key]
end

local function loadProfiles()
	pcall(function()
		if readfile and isfile and isfile("TKLib/profiles.json") then
			local ok, data = pcall(function()
				return HttpService:JSONDecode(readfile("TKLib/profiles.json"))
			end)
			if ok and data then
				_profiles = data
				if _profiles[_activeProfile] then
					_configData = _profiles[_activeProfile]
				end
			end
		end
	end)
end

loadProfiles()

function UIlib.GetProfiles()
	local list = {}
	for k in pairs(_profiles) do table.insert(list, k) end
	if #list == 0 then table.insert(list, "Default") end
	return list
end

function UIlib.SwitchProfile(name)
	-- save current
	_profiles[_activeProfile] = _configData
	-- switch
	_activeProfile = name
	_configData = _profiles[name] or {}
	fire("profileChanged", name)
	UIlib.Notify("Config", "Switched to profile: "..name, 3)
end

function UIlib.NewProfile(name)
	if not _profiles[name] then _profiles[name] = {} end
	UIlib.SwitchProfile(name)
end

function UIlib.DeleteProfile(name)
	if name == "Default" then
		UIlib.Notify("Config", "Cannot delete Default profile.", 3)
		return
	end
	_profiles[name] = nil
	UIlib.SwitchProfile("Default")
end

function UIlib.ExportConfig()
	local json = HttpService:JSONEncode(_configData)
	local b64  = ""
	-- Simple base64 encode
	local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	local bytes  = {json:byte(1, #json)}
	for i = 1, #bytes, 3 do
		local b1, b2, b3 = bytes[i] or 0, bytes[i+1] or 0, bytes[i+2] or 0
		local n = b1*65536 + b2*256 + b3
		local c1 = math.floor(n/262144) % 64 + 1
		local c2 = math.floor(n/4096)   % 64 + 1
		local c3 = math.floor(n/64)     % 64 + 1
		local c4 = n % 64 + 1
		b64 = b64 .. chars:sub(c1,c1) .. chars:sub(c2,c2)
		b64 = b64 .. (bytes[i+1] and chars:sub(c3,c3) or "=")
		b64 = b64 .. (bytes[i+2] and chars:sub(c4,c4) or "=")
	end
	if setclipboard then
		setclipboard(b64)
		UIlib.Notify("Config", "Exported to clipboard!", 3, "success")
	end
	return b64
end

function UIlib.ImportConfig(b64)
	local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	local map = {}
	for i = 1, #chars do map[chars:sub(i,i)] = i-1 end
	local bytes = {}
	for i = 1, #b64, 4 do
		local c1,c2,c3,c4 = b64:sub(i,i), b64:sub(i+1,i+1), b64:sub(i+2,i+2), b64:sub(i+3,i+3)
		local n = (map[c1] or 0)*262144 + (map[c2] or 0)*4096 + (map[c3] or 0)*64 + (map[c4] or 0)
		table.insert(bytes, string.char(math.floor(n/65536) % 256))
		if c3 ~= "=" then table.insert(bytes, string.char(math.floor(n/256) % 256)) end
		if c4 ~= "=" then table.insert(bytes, string.char(n % 256)) end
	end
	local json = table.concat(bytes)
	local ok, data = pcall(function() return HttpService:JSONDecode(json) end)
	if ok and data then
		_configData = data
		_profiles[_activeProfile] = data
		UIlib.Notify("Config", "Config imported successfully!", 3, "success")
		fire("configImported", data)
	else
		UIlib.Notify("Config", "Failed to import — invalid data.", 4, "error")
	end
end

-- ───────────────────────────────────────────────────────────────
-- EVENT SYSTEM
-- ───────────────────────────────────────────────────────────────
function UIlib.on(event, fn)
	if not _events[event] then _events[event] = {} end
	table.insert(_events[event], fn)
end

function UIlib.off(event, fn)
	if not _events[event] then return end
	for i, f in ipairs(_events[event]) do
		if f == fn then table.remove(_events[event], i); return end
	end
end

-- ───────────────────────────────────────────────────────────────
-- ELEMENT REGISTRY
-- ───────────────────────────────────────────────────────────────
local function registerElem(winName, secName, elemName, obj)
	if not _registry[winName] then _registry[winName] = {} end
	if not _registry[winName][secName] then _registry[winName][secName] = {} end
	_registry[winName][secName][elemName] = obj
end

function UIlib.GetElement(winName, secName, elemName)
	return _registry[winName] and _registry[winName][secName] and _registry[winName][secName][elemName]
end

-- ───────────────────────────────────────────────────────────────
-- VERSION CHECK
-- ───────────────────────────────────────────────────────────────
function UIlib.CheckForUpdates()
	task.spawn(function()
		local ok, raw = pcall(function()
			return game:HttpGet("https://raw.githubusercontent.com/T1K2060/TKHub/refs/heads/main/Lib/version.txt", true)
		end)
		if ok and raw then
			local latest = raw:gsub("%s", "")
			if latest ~= UIlib.Version then
				UIlib.Notify("Update Available", "v"..latest.." is out! (current: v"..UIlib.Version..")", 6, "info")
			else
				UIlib.Notify("Up to Date", "UIlib v"..UIlib.Version.." is current.", 3, "success")
			end
		end
	end)
end

-- ───────────────────────────────────────────────────────────────
-- SCREEN GUI BOOTSTRAP
-- ───────────────────────────────────────────────────────────────
local function buildGui()
	if _screenGui then _screenGui:Destroy() end

	local sg = Instance.new("ScreenGui")
	sg.Name              = "TKLib_v3"
	sg.ResetOnSpawn      = false
	sg.ZIndexBehavior    = Enum.ZIndexBehavior.Sibling
	sg.DisplayOrder      = 100
	sg.IgnoreGuiInset    = true
	sg.Parent            = LocalPlayer:WaitForChild("PlayerGui")
	_screenGui = sg

	-- Root container (holds sidebar + windows)
	local root = Instance.new("Frame", sg)
	root.Name                 = "Root"
	root.Size                 = UDim2.new(0, 620, 0, 420)
	root.Position             = UDim2.new(0.5, -310, 0.5, -210)
	root.BackgroundColor3     = UIlib.THEME.Background
	root.BorderSizePixel      = 0
	root.ClipsDescendants     = false
	makeCorner(root, 10)
	-- Drop shadow
	local shadow = Instance.new("Frame", root)
	shadow.Name               = "Shadow"
	shadow.Size               = UDim2.new(1, 20, 1, 20)
	shadow.Position           = UDim2.new(0, -10, 0, 8)
	shadow.BackgroundColor3   = Color3.new(0,0,0)
	shadow.BackgroundTransparency = 0.6
	shadow.BorderSizePixel    = 0
	shadow.ZIndex             = -1
	makeCorner(shadow, 14)

	draggable(root, root)
	resizable(root, 400, 300)

	-- Sidebar
	local sb = Instance.new("Frame", root)
	sb.Name               = "Sidebar"
	sb.Size               = UDim2.new(0, 110, 1, 0)
	sb.BackgroundColor3   = UIlib.THEME.SideBar
	sb.BorderSizePixel    = 0
	sb.ZIndex             = 2
	Instance.new("UICorner", sb).CornerRadius = UDim.new(0,10)
	-- cover right-side corners
	local sbCover = Instance.new("Frame", sb)
	sbCover.Size               = UDim2.new(0,10,1,0)
	sbCover.Position           = UDim2.new(1,-10,0,0)
	sbCover.BackgroundColor3   = UIlib.THEME.SideBar
	sbCover.BorderSizePixel    = 0
	_sidebar = sb

	-- Logo area
	local logoFrame = Instance.new("Frame", sb)
	logoFrame.Size             = UDim2.new(1,0,0,56)
	logoFrame.BackgroundTransparency = 1
	local logoLbl = Instance.new("TextLabel", logoFrame)
	logoLbl.Size               = UDim2.new(1,0,1,0)
	logoLbl.BackgroundTransparency = 1
	logoLbl.Text               = "TK Hub"
	logoLbl.TextColor3         = UIlib.THEME.Accent
	logoLbl.Font               = Enum.Font.GothamBold
	logoLbl.TextSize           = 17
	logoLbl.TextXAlignment     = Enum.TextXAlignment.Center

	local verLbl = Instance.new("TextLabel", logoFrame)
	verLbl.Size                = UDim2.new(1,0,0,14)
	verLbl.Position            = UDim2.new(0,0,1,-14)
	verLbl.BackgroundTransparency = 1
	verLbl.Text                = "v"..UIlib.Version
	verLbl.TextColor3          = UIlib.THEME.TextDim
	verLbl.Font                = Enum.Font.Gotham
	verLbl.TextSize            = 9
	verLbl.TextXAlignment      = Enum.TextXAlignment.Center

	-- Sidebar scroll
	local sbScroll = Instance.new("ScrollingFrame", sb)
	sbScroll.Name              = "BtnScroll"
	sbScroll.Size              = UDim2.new(1,0,1,-56)
	sbScroll.Position          = UDim2.new(0,0,0,56)
	sbScroll.BackgroundTransparency = 1
	sbScroll.BorderSizePixel   = 0
	sbScroll.ScrollBarThickness = 0
	sbScroll.CanvasSize        = UDim2.new(0,0,0,0)
	sbScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	local sbList = Instance.new("UIListLayout", sbScroll)
	sbList.Padding             = UDim.new(0,3)
	sbList.SortOrder           = Enum.SortOrder.LayoutOrder
	makePadding(sbScroll, 4, 4, 6, 6)

	-- Content area
	local content = Instance.new("Frame", root)
	content.Name               = "Content"
	content.Size               = UDim2.new(1,-110,1,0)
	content.Position           = UDim2.new(0,110,0,0)
	content.BackgroundTransparency = 1
	content.ClipsDescendants   = true

	-- Notification holder (screen-level)
	local nh = Instance.new("Frame", sg)
	nh.Name                    = "NotifHolder"
	nh.Size                    = UDim2.new(0,300,1,0)
	nh.Position                = UDim2.new(1,-310,0,0)
	nh.BackgroundTransparency  = 1
	nh.BorderSizePixel         = 0
	local nhList = Instance.new("UIListLayout", nh)
	nhList.SortOrder           = Enum.SortOrder.LayoutOrder
	nhList.VerticalAlignment   = Enum.VerticalAlignment.Bottom
	nhList.Padding             = UDim.new(0,6)
	makePadding(nh, 0, 12, 0, 0)
	_notifHolder = nh

	-- Tooltip label (screen-level)
	local ttip = Instance.new("Frame", sg)
	ttip.Name                  = "Tooltip"
	ttip.Size                  = UDim2.new(0,160,0,28)
	ttip.BackgroundColor3      = UIlib.THEME.TooltipBG
	ttip.BorderSizePixel       = 0
	ttip.Visible               = false
	ttip.ZIndex                = 50
	makeCorner(ttip, 5)
	local ttipLbl = Instance.new("TextLabel", ttip)
	ttipLbl.Size               = UDim2.new(1,-8,1,0)
	ttipLbl.Position           = UDim2.new(0,4,0,0)
	ttipLbl.BackgroundTransparency = 1
	ttipLbl.TextColor3         = UIlib.THEME.Text
	ttipLbl.Font               = Enum.Font.Gotham
	ttipLbl.TextSize           = 11
	ttipLbl.TextXAlignment     = Enum.TextXAlignment.Left
	ttipLbl.TextWrapped        = true
	_tooltipLabel = ttip

	return sg, content, sbScroll
end

local _sgInst, _contentFrame, _sbScroll = buildGui()

-- ───────────────────────────────────────────────────────────────
-- CONTEXT MENU
-- ───────────────────────────────────────────────────────────────
local function closeContextMenu()
	if _contextMenu then
		_contextMenu:Destroy()
		_contextMenu = nil
	end
end

local function showContextMenu(x, y, items)
	closeContextMenu()
	local cm = Instance.new("Frame", _screenGui)
	cm.Name               = "ContextMenu"
	cm.Position           = UDim2.new(0, x, 0, y)
	cm.Size               = UDim2.new(0, 160, 0, #items * 30 + 8)
	cm.BackgroundColor3   = UIlib.THEME.ContextBG
	cm.BorderSizePixel    = 0
	cm.ZIndex             = 100
	makeCorner(cm, 6)
	makePadding(cm, 4, 4, 0, 0)
	local cmList = makeList(cm, 2)
	cmList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	_contextMenu = cm

	for _, item in ipairs(items) do
		local btn = Instance.new("TextButton", cm)
		btn.Size              = UDim2.new(1,-8,0,26)
		btn.BackgroundColor3  = UIlib.THEME.ContextBG
		btn.BorderSizePixel   = 0
		btn.Text              = item.label or "Option"
		btn.TextColor3        = item.color or UIlib.THEME.Text
		btn.Font              = Enum.Font.Gotham
		btn.TextSize          = 12
		btn.TextXAlignment    = Enum.TextXAlignment.Left
		btn.ZIndex            = 101
		makeCorner(btn, 4)
		makePadding(btn, 0, 0, 8, 8)

		btn.MouseEnter:Connect(function()
			tween(btn, {BackgroundColor3 = UIlib.THEME.ContextHover}, 0.1)
		end)
		btn.MouseLeave:Connect(function()
			tween(btn, {BackgroundColor3 = UIlib.THEME.ContextBG}, 0.1)
		end)
		btn.MouseButton1Click:Connect(function()
			closeContextMenu()
			if item.action then safeCall(item.action) end
		end)
	end

	-- Close on outside click
	local closeConn
	closeConn = UserInputService.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 then
			task.wait()
			closeContextMenu()
			if closeConn then closeConn:Disconnect() end
		end
	end)
end

-- ───────────────────────────────────────────────────────────────
-- TOOLTIP
-- ───────────────────────────────────────────────────────────────
function UIlib.SetTooltip(element, text)
	element.MouseEnter:Connect(function()
		_tooltipLabel:FindFirstChildOfClass("TextLabel").Text = text
		_tooltipLabel.Size = UDim2.new(0, math.clamp(#text * 7 + 16, 80, 260), 0, 28)
		_tooltipLabel.Visible = true
	end)
	element.MouseLeave:Connect(function()
		_tooltipLabel.Visible = false
	end)
	RunService.Heartbeat:Connect(function()
		if _tooltipLabel.Visible then
			local mp = UserInputService:GetMouseLocation()
			_tooltipLabel.Position = UDim2.new(0, mp.X + 14, 0, mp.Y - 32)
		end
	end)
end

-- ───────────────────────────────────────────────────────────────
-- NOTIFICATION SYSTEM  (full rework)
-- ───────────────────────────────────────────────────────────────
-- Icons per type
local NOTIF_ICONS = {
	info    = "ℹ",
	success = "✓",
	error   = "✕",
	warning = "⚠",
	default = "•",
}
local NOTIF_COLORS = {
	info    = Color3.fromRGB(80, 140, 255),
	success = Color3.fromRGB(80, 200, 120),
	error   = Color3.fromRGB(220, 80, 80),
	warning = Color3.fromRGB(230, 170, 60),
	default = Color3.fromRGB(120, 120, 140),
}
local _notifOrder = 0

function UIlib.Notify(title, body, duration, notifType, actions)
	duration  = duration  or 3
	notifType = notifType or "default"
	actions   = actions   or {}

	_notifOrder = _notifOrder + 1

	local accentColor = NOTIF_COLORS[notifType] or NOTIF_COLORS.default
	local iconText    = NOTIF_ICONS[notifType]  or NOTIF_ICONS.default

	-- Outer card
	local card = Instance.new("Frame", _notifHolder)
	card.Name                = "Notif_"..tostring(_notifOrder)
	card.Size                = UDim2.new(1,-4,0,0)
	card.AutomaticSize       = Enum.AutomaticSize.Y
	card.BackgroundColor3    = UIlib.THEME.NotifyBG
	card.BorderSizePixel     = 0
	card.LayoutOrder         = -_notifOrder
	card.ClipsDescendants    = false
	makeCorner(card, 8)

	-- Border glow
	local border = Instance.new("UIStroke", card)
	border.Color         = UIlib.THEME.NotifyBorder
	border.Thickness     = 1
	border.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

	-- Left accent bar
	local bar = Instance.new("Frame", card)
	bar.Size              = UDim2.new(0,3,1,0)
	bar.BackgroundColor3  = accentColor
	bar.BorderSizePixel   = 0
	makeCorner(bar, 2)

	-- Content frame
	local inner = Instance.new("Frame", card)
	inner.Size             = UDim2.new(1,-3,1,0)
	inner.Position         = UDim2.new(0,3,0,0)
	inner.BackgroundTransparency = 1
	inner.AutomaticSize   = Enum.AutomaticSize.Y
	makePadding(inner, 10, 10, 10, 8)
	local innerList = makeList(inner, 4)
	innerList.HorizontalAlignment = Enum.HorizontalAlignment.Left

	-- Header row (icon + title + close btn)
	local headerRow = Instance.new("Frame", inner)
	headerRow.Size            = UDim2.new(1,0,0,18)
	headerRow.BackgroundTransparency = 1
	headerRow.LayoutOrder     = 1

	local iconLbl = Instance.new("TextLabel", headerRow)
	iconLbl.Size              = UDim2.new(0,18,1,0)
	iconLbl.BackgroundTransparency = 1
	iconLbl.Text              = iconText
	iconLbl.TextColor3        = accentColor
	iconLbl.Font              = Enum.Font.GothamBold
	iconLbl.TextSize          = 14

	local titleLbl = Instance.new("TextLabel", headerRow)
	titleLbl.Size             = UDim2.new(1,-40,1,0)
	titleLbl.Position         = UDim2.new(0,22,0,0)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text             = title
	titleLbl.TextColor3       = UIlib.THEME.Text
	titleLbl.Font             = Enum.Font.GothamBold
	titleLbl.TextSize         = 13
	titleLbl.TextXAlignment   = Enum.TextXAlignment.Left

	local closeBtn = Instance.new("TextButton", headerRow)
	closeBtn.Size             = UDim2.new(0,18,1,0)
	closeBtn.Position         = UDim2.new(1,-18,0,0)
	closeBtn.BackgroundTransparency = 1
	closeBtn.Text             = "×"
	closeBtn.TextColor3       = UIlib.THEME.TextDim
	closeBtn.Font             = Enum.Font.GothamBold
	closeBtn.TextSize         = 16

	-- Body label
	local bodyLbl = Instance.new("TextLabel", inner)
	bodyLbl.Size              = UDim2.new(1,0,0,0)
	bodyLbl.AutomaticSize     = Enum.AutomaticSize.Y
	bodyLbl.BackgroundTransparency = 1
	bodyLbl.Text              = body
	bodyLbl.TextColor3        = UIlib.THEME.TextDim
	bodyLbl.Font              = Enum.Font.Gotham
	bodyLbl.TextSize          = 11
	bodyLbl.TextXAlignment    = Enum.TextXAlignment.Left
	bodyLbl.TextWrapped        = true
	bodyLbl.LayoutOrder        = 2

	-- Action buttons
	if #actions > 0 then
		local actRow = Instance.new("Frame", inner)
		actRow.Size             = UDim2.new(1,0,0,26)
		actRow.BackgroundTransparency = 1
		actRow.LayoutOrder      = 3
		local actList = Instance.new("UIListLayout", actRow)
		actList.FillDirection   = Enum.FillDirection.Horizontal
		actList.Padding         = UDim.new(0,6)

		for _, act in ipairs(actions) do
			local ab = Instance.new("TextButton", actRow)
			ab.Size             = UDim2.new(0, 80, 1, 0)
			ab.BackgroundColor3 = act.color or accentColor
			ab.BackgroundTransparency = 0.4
			ab.BorderSizePixel  = 0
			ab.Text             = act.label or "OK"
			ab.TextColor3       = UIlib.THEME.Text
			ab.Font             = Enum.Font.GothamSemibold
			ab.TextSize         = 11
			makeCorner(ab, 4)
			ab.MouseButton1Click:Connect(function()
				if act.action then safeCall(act.action) end
			end)
		end
	end

	-- Progress bar (shrinks over duration)
	local progBG = Instance.new("Frame", card)
	progBG.Size              = UDim2.new(1,0,0,2)
	progBG.Position          = UDim2.new(0,0,1,-2)
	progBG.BackgroundColor3  = UIlib.THEME.ProgressBG
	progBG.BorderSizePixel   = 0
	makeCorner(progBG, 0)

	local progFill = Instance.new("Frame", progBG)
	progFill.Size            = UDim2.new(1,0,1,0)
	progFill.BackgroundColor3 = accentColor
	progFill.BorderSizePixel = 0
	makeCorner(progFill, 0)

	-- Slide in
	card.Position   = UDim2.new(1, 10, 1, -10)
	card.AnchorPoint = Vector2.new(0, 1)
	tween(card, {Position = UDim2.new(0, 2, 1, -10)}, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	-- Progress tween
	tween(progFill, {Size = UDim2.new(0,0,1,0)}, duration, Enum.EasingStyle.Linear)

	local function dismiss()
		tween(card, {Position = UDim2.new(1, 10, 1, -10)}, 0.25)
		task.delay(0.28, function()
			card:Destroy()
		end)
	end

	closeBtn.MouseButton1Click:Connect(dismiss)
	task.delay(duration, dismiss)
end

-- ───────────────────────────────────────────────────────────────
-- ANIMATION PRESETS
-- ───────────────────────────────────────────────────────────────
function UIlib.SetAnimation(preset)
	_animPreset = preset  -- "slide" | "fade" | "bounce"
end

local function animateWindowIn(frame)
	if _animPreset == "fade" then
		frame.BackgroundTransparency = 1
		tween(frame, {BackgroundTransparency = 0}, 0.2)
	elseif _animPreset == "bounce" then
		frame.Size = UDim2.new(frame.Size.X.Scale, frame.Size.X.Offset * 0.85,
		                        frame.Size.Y.Scale, frame.Size.Y.Offset * 0.85)
		tween(frame, {Size = UDim2.new(frame.Size.X.Scale, frame.Size.X.Offset / 0.85,
		                                frame.Size.Y.Scale, frame.Size.Y.Offset / 0.85)},
		      0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	else
		-- slide (default)
		local orig = frame.Position
		frame.Position = UDim2.new(orig.X.Scale - 0.05, orig.X.Offset, orig.Y.Scale, orig.Y.Offset)
		tween(frame, {Position = orig}, 0.2)
	end
end

-- ───────────────────────────────────────────────────────────────
-- SET THEME
-- ───────────────────────────────────────────────────────────────
function UIlib.SetTheme(t)
	for k, v in pairs(t) do
		UIlib.THEME[k] = v
	end
	fire("themeChanged", UIlib.THEME)
end

-- ───────────────────────────────────────────────────────────────
-- SET OPACITY
-- ───────────────────────────────────────────────────────────────
function UIlib.SetOpacity(alpha)
	if not _screenGui then return end
	if not _opacitySnap then
		_opacitySnap = {}
		for _, obj in ipairs(_screenGui:GetDescendants()) do
			if obj:IsA("Frame") or obj:IsA("ScrollingFrame") then
				if obj.BackgroundTransparency < 1 then
					_opacitySnap[obj] = obj.BackgroundTransparency
				end
			end
		end
	end
	for obj, orig in pairs(_opacitySnap) do
		if obj and obj.Parent then
			obj.BackgroundTransparency = 1 - (1 - orig) * alpha
		end
	end
end

-- ───────────────────────────────────────────────────────────────
-- MAIN WINDOW
-- ───────────────────────────────────────────────────────────────
function UIlib.MainWindow(name)
	-- Sidebar button
	local sbBtn = Instance.new("TextButton", _sbScroll)
	sbBtn.Size              = UDim2.new(1,0,0,32)
	sbBtn.BackgroundColor3  = UIlib.THEME.SideBarBtn
	sbBtn.BorderSizePixel   = 0
	sbBtn.Text              = name
	sbBtn.TextColor3        = UIlib.THEME.TextDim
	sbBtn.Font              = Enum.Font.GothamSemibold
	sbBtn.TextSize          = 12
	sbBtn.LayoutOrder       = #_windows + 1
	sbBtn.AutoButtonColor   = false
	makeCorner(sbBtn, 6)

	-- Window frame (inside content area)
	local winFrame = Instance.new("ScrollingFrame", _contentFrame)
	winFrame.Name               = "Win_"..name
	winFrame.Size               = UDim2.new(1,0,1,0)
	winFrame.BackgroundTransparency = 1
	winFrame.BorderSizePixel    = 0
	winFrame.ScrollBarThickness = 3
	winFrame.ScrollBarImageColor3 = UIlib.THEME.Accent
	winFrame.CanvasSize         = UDim2.new(0,0,0,0)
	winFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	winFrame.Visible            = false

	local winInner = Instance.new("Frame", winFrame)
	winInner.Name               = "Inner"
	winInner.Size               = UDim2.new(1,-12,0,0)
	winInner.Position           = UDim2.new(0,6,0,6)
	winInner.AutomaticSize      = Enum.AutomaticSize.Y
	winInner.BackgroundTransparency = 1
	makeList(winInner, 8)
	makePadding(winInner, 4, 8, 0, 0)

	-- Title bar (inside winFrame)
	local titleBar = Instance.new("Frame", winFrame)
	titleBar.Name               = "TitleBar"
	titleBar.Size               = UDim2.new(1,0,0,38)
	titleBar.BackgroundColor3   = UIlib.THEME.BackgroundLight
	titleBar.BorderSizePixel    = 0
	makeCorner(titleBar, 8)

	-- Title text
	local titleLbl = Instance.new("TextLabel", titleBar)
	titleLbl.Size               = UDim2.new(1,-60,1,0)
	titleLbl.Position           = UDim2.new(0,14,0,0)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text               = name
	titleLbl.TextColor3         = UIlib.THEME.Accent
	titleLbl.Font               = Enum.Font.GothamBold
	titleLbl.TextSize           = 14
	titleLbl.TextXAlignment     = Enum.TextXAlignment.Left

	-- Minimize button
	local minBtn = Instance.new("TextButton", titleBar)
	minBtn.Size                 = UDim2.new(0,24,0,24)
	minBtn.Position             = UDim2.new(1,-52,0.5,-12)
	minBtn.BackgroundColor3     = UIlib.THEME.ButtonBG
	minBtn.BorderSizePixel      = 0
	minBtn.Text                 = "—"
	minBtn.TextColor3           = UIlib.THEME.TextDim
	minBtn.Font                 = Enum.Font.GothamBold
	minBtn.TextSize             = 11
	makeCorner(minBtn, 5)

	-- Search button
	local searchBtn = Instance.new("TextButton", titleBar)
	searchBtn.Size              = UDim2.new(0,24,0,24)
	searchBtn.Position          = UDim2.new(1,-26,0.5,-12)
	searchBtn.BackgroundColor3  = UIlib.THEME.ButtonBG
	searchBtn.BorderSizePixel   = 0
	searchBtn.Text              = "⌕"
	searchBtn.TextColor3        = UIlib.THEME.TextDim
	searchBtn.Font              = Enum.Font.GothamBold
	searchBtn.TextSize          = 13
	makeCorner(searchBtn, 5)

	-- Reposition winInner below title bar
	winInner.Position = UDim2.new(0,6,0,48)

	-- Search bar (hidden by default)
	local searchBar = Instance.new("Frame", winFrame)
	searchBar.Name              = "SearchBar"
	searchBar.Size              = UDim2.new(1,-12,0,30)
	searchBar.Position          = UDim2.new(0,6,0,42)
	searchBar.BackgroundColor3  = UIlib.THEME.BackgroundLight
	searchBar.BorderSizePixel   = 0
	searchBar.Visible           = false
	makeCorner(searchBar, 6)

	local searchBox = Instance.new("TextBox", searchBar)
	searchBox.Size              = UDim2.new(1,-8,1,0)
	searchBox.Position          = UDim2.new(0,4,0,0)
	searchBox.BackgroundTransparency = 1
	searchBox.PlaceholderText   = "Search elements..."
	searchBox.PlaceholderColor3 = UIlib.THEME.TextDim
	searchBox.Text              = ""
	searchBox.TextColor3        = UIlib.THEME.Text
	searchBox.Font              = Enum.Font.Gotham
	searchBox.TextSize          = 12
	searchBox.ClearTextOnFocus  = false

	local searchVisible = false
	searchBtn.MouseButton1Click:Connect(function()
		searchVisible = not searchVisible
		searchBar.Visible = searchVisible
		if searchVisible then
			winInner.Position = UDim2.new(0,6,0,80)
			searchBox:CaptureFocus()
		else
			winInner.Position = UDim2.new(0,6,0,48)
			searchBox.Text = ""
		end
	end)

	-- Search filtering
	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		local query = searchBox.Text:lower()
		for _, sec in ipairs(winInner:GetChildren()) do
			if sec:IsA("Frame") then
				for _, child in ipairs(sec:GetChildren()) do
					if child:IsA("Frame") or child:IsA("TextButton") then
						local lbl = child:FindFirstChildOfClass("TextLabel")
						if lbl then
							child.Visible = query == "" or lbl.Text:lower():find(query, 1, true) ~= nil
						end
					end
				end
			end
		end
	end)

	-- Minimize logic
	local minimized = false
	local fullSize  = nil

	minBtn.MouseButton1Click:Connect(function()
		minimized = not minimized
		if minimized then
			fullSize = winFrame.Parent.Size
			tween(winFrame.Parent, {Size = UDim2.new(0, winFrame.Parent.AbsoluteSize.X, 0, 38)}, 0.2)
			winInner.Visible = false
			titleBar.Size    = UDim2.new(1,0,1,0)
			minBtn.Text      = "□"
		else
			tween(winFrame.Parent, {Size = fullSize}, 0.2)
			winInner.Visible = true
			titleBar.Size    = UDim2.new(1,0,0,38)
			minBtn.Text      = "—"
		end
	end)

	-- Window object
	local winObj = {
		Name     = name,
		Frame    = winFrame,
		Inner    = winInner,
		Sidebar  = _sidebar,
		Sections = {},
		_tabs    = {},
		_activetab = nil,
	}

	-- Sidebar button behavior
	local function activateWindow()
		for _, w in ipairs(_windows) do
			w.Frame.Visible = false
			-- sidebar btn styling
			local btn = _sbScroll:FindFirstChild("SBBtn_"..w.Name)
			if btn then
				tween(btn, {BackgroundColor3 = UIlib.THEME.SideBarBtn}, 0.12)
				btn.TextColor3 = UIlib.THEME.TextDim
			end
		end
		winFrame.Visible = true
		animateWindowIn(winFrame)
		tween(sbBtn, {BackgroundColor3 = UIlib.THEME.SideBarBtnActive}, 0.12)
		sbBtn.TextColor3 = UIlib.THEME.Accent
		_activeWin = winObj
		fire("windowOpened", name)
	end

	sbBtn.Name = "SBBtn_"..name
	sbBtn.MouseButton1Click:Connect(activateWindow)
	sbBtn.MouseEnter:Connect(function()
		if _activeWin ~= winObj then
			tween(sbBtn, {BackgroundColor3 = UIlib.THEME.ButtonHover}, 0.1)
		end
	end)
	sbBtn.MouseLeave:Connect(function()
		if _activeWin ~= winObj then
			tween(sbBtn, {BackgroundColor3 = UIlib.THEME.SideBarBtn}, 0.1)
		end
	end)

	table.insert(_windows, winObj)

	-- First window is active by default
	if #_windows == 1 then
		activateWindow()
	end

	return winObj
end

-- ───────────────────────────────────────────────────────────────
-- WINDOW INNER TABS
-- ───────────────────────────────────────────────────────────────
function UIlib.CreateTab(window, tabName)
	-- Tab bar (created once)
	local tabBar = window.Frame:FindFirstChild("TabBar")
	if not tabBar then
		tabBar = Instance.new("Frame", window.Frame)
		tabBar.Name            = "TabBar"
		tabBar.Size            = UDim2.new(1,-12,0,28)
		tabBar.Position        = UDim2.new(0,6,0,42)
		tabBar.BackgroundColor3 = UIlib.THEME.BackgroundLight
		tabBar.BorderSizePixel = 0
		makeCorner(tabBar, 6)
		local tl = Instance.new("UIListLayout", tabBar)
		tl.FillDirection       = Enum.FillDirection.Horizontal
		tl.Padding             = UDim.new(0,2)
		makePadding(tabBar, 2, 2, 4, 4)
		window.Inner.Position  = UDim2.new(0,6,0,78)
	end

	-- Tab content frame
	local tabContent = Instance.new("Frame", window.Inner)
	tabContent.Name            = "Tab_"..tabName
	tabContent.Size            = UDim2.new(1,0,0,0)
	tabContent.AutomaticSize   = Enum.AutomaticSize.Y
	tabContent.BackgroundTransparency = 1
	tabContent.Visible         = false
	makeList(tabContent, 8)

	-- Tab button
	local tabBtn = Instance.new("TextButton", tabBar)
	tabBtn.Size                = UDim2.new(0, 0, 1, 0)
	tabBtn.AutomaticSize       = Enum.AutomaticSize.X
	tabBtn.BackgroundColor3    = UIlib.THEME.SideBarBtn
	tabBtn.BackgroundTransparency = 0.6
	tabBtn.BorderSizePixel     = 0
	tabBtn.Text                = " "..tabName.." "
	tabBtn.TextColor3          = UIlib.THEME.TextDim
	tabBtn.Font                = Enum.Font.GothamSemibold
	tabBtn.TextSize            = 11
	makeCorner(tabBtn, 4)

	local tabObj = {
		Name    = tabName,
		Frame   = tabContent,
		Button  = tabBtn,
		Sections = {},
	}
	table.insert(window._tabs, tabObj)

	local function activateTab()
		for _, t in ipairs(window._tabs) do
			t.Frame.Visible         = false
			t.Button.BackgroundTransparency = 0.6
			t.Button.TextColor3     = UIlib.THEME.TextDim
		end
		tabContent.Visible          = true
		tabBtn.BackgroundTransparency = 0
		tabBtn.TextColor3           = UIlib.THEME.Accent
		window._activetab           = tabObj
	end

	tabBtn.MouseButton1Click:Connect(activateTab)

	-- First tab auto-activates
	if #window._tabs == 1 then
		activateTab()
	end

	return tabObj
end

-- ───────────────────────────────────────────────────────────────
-- SECTION
-- ───────────────────────────────────────────────────────────────
function UIlib.Section(windowOrTab, name)
	-- Support both WindowObj and TabObj
	local parent = windowOrTab.Inner or windowOrTab.Frame
	if not parent then
		-- Legacy: might just be a frame
		parent = windowOrTab
	end

	local secWrap = Instance.new("Frame", parent)
	secWrap.Name               = "Sec_"..name
	secWrap.Size               = UDim2.new(1,0,0,0)
	secWrap.AutomaticSize      = Enum.AutomaticSize.Y
	secWrap.BackgroundColor3   = UIlib.THEME.BackgroundLight
	secWrap.BorderSizePixel    = 0
	secWrap.LayoutOrder        = #parent:GetChildren()
	makeCorner(secWrap, 8)

	-- Header row (label + collapse arrow)
	local header = Instance.new("Frame", secWrap)
	header.Name                = "Header"
	header.Size                = UDim2.new(1,0,0,30)
	header.BackgroundColor3    = UIlib.THEME.SectionHeader
	header.BorderSizePixel     = 0
	makeCorner(header, 6)
	-- cover bottom corners of header
	local hCover = Instance.new("Frame", header)
	hCover.Size                = UDim2.new(1,0,0,8)
	hCover.Position            = UDim2.new(0,0,1,-8)
	hCover.BackgroundColor3    = UIlib.THEME.SectionHeader
	hCover.BorderSizePixel     = 0

	local secLbl = Instance.new("TextLabel", header)
	secLbl.Size                = UDim2.new(1,-30,1,0)
	secLbl.Position            = UDim2.new(0,10,0,0)
	secLbl.BackgroundTransparency = 1
	secLbl.Text                = name
	secLbl.TextColor3          = UIlib.THEME.Text
	secLbl.Font                = Enum.Font.GothamSemibold
	secLbl.TextSize            = 12
	secLbl.TextXAlignment      = Enum.TextXAlignment.Left

	local collapseBtn = Instance.new("TextButton", header)
	collapseBtn.Size           = UDim2.new(0,24,0,24)
	collapseBtn.Position       = UDim2.new(1,-28,0.5,-12)
	collapseBtn.BackgroundTransparency = 1
	collapseBtn.Text           = "▼"
	collapseBtn.TextColor3     = UIlib.THEME.TextDim
	collapseBtn.Font           = Enum.Font.GothamBold
	collapseBtn.TextSize       = 10
	collapseBtn.BorderSizePixel = 0

	-- Content inner
	local secInner = Instance.new("Frame", secWrap)
	secInner.Name              = "Content"
	secInner.Size              = UDim2.new(1,0,0,0)
	secInner.Position          = UDim2.new(0,0,0,30)
	secInner.AutomaticSize     = Enum.AutomaticSize.Y
	secInner.BackgroundTransparency = 1
	makePadding(secInner, 6, 8, 8, 8)
	makeList(secInner, 5)

	-- Collapse toggle
	local collapsed = false
	local function toggleCollapse()
		collapsed = not collapsed
		if collapsed then
			tween(collapseBtn, {Rotation = -90}, 0.15)
			secInner.Visible = false
		else
			tween(collapseBtn, {Rotation = 0}, 0.15)
			secInner.Visible = true
		end
	end
	collapseBtn.MouseButton1Click:Connect(toggleCollapse)
	header.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 then
			toggleCollapse()
		end
	end)

	-- Register in window
	if windowOrTab.Sections then
		windowOrTab.Sections[name] = secInner
	end

	return secInner
end

-- ───────────────────────────────────────────────────────────────
-- SHARED ELEMENT HELPERS
-- ───────────────────────────────────────────────────────────────
local function elemRow(section, height)
	local row = Instance.new("Frame", section)
	row.Size               = UDim2.new(1,0,0,height or 28)
	row.BackgroundTransparency = 1
	row.LayoutOrder        = #section:GetChildren()
	return row
end

local function ctxMenu(element, name, defaultVal, getValue, resetFn)
	element.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton2 then
			local mp = UserInputService:GetMouseLocation()
			local items = {
				{ label = "📋 Copy value", action = function()
					if setclipboard then setclipboard(tostring(getValue())) end
					UIlib.Notify("Copied", tostring(getValue()), 2)
				end},
				{ label = "↺ Reset to default", action = resetFn },
			}
			showContextMenu(mp.X, mp.Y, items)
		end
	end)
end

-- ───────────────────────────────────────────────────────────────
-- CREATE BUTTON
-- ───────────────────────────────────────────────────────────────
function UIlib.CreateButton(section, name, callback)
	-- section can be a Frame or a section Frame
	local parent = (type(section) == "table" and (section.Inner or section.Frame)) or section

	local btn = Instance.new("TextButton", parent)
	btn.Name               = "Btn_"..name
	btn.Size               = UDim2.new(1,0,0,30)
	btn.BackgroundColor3   = UIlib.THEME.ButtonBG
	btn.BorderSizePixel    = 0
	btn.Text               = name
	btn.TextColor3         = UIlib.THEME.Text
	btn.Font               = Enum.Font.GothamSemibold
	btn.TextSize           = 12
	btn.LayoutOrder        = #parent:GetChildren()
	btn.AutoButtonColor    = false
	makeCorner(btn, 6)

	btn.MouseEnter:Connect(function()
		tween(btn, {BackgroundColor3 = UIlib.THEME.ButtonHover}, 0.1)
	end)
	btn.MouseLeave:Connect(function()
		tween(btn, {BackgroundColor3 = UIlib.THEME.ButtonBG}, 0.1)
	end)
	btn.MouseButton1Down:Connect(function()
		tween(btn, {BackgroundColor3 = UIlib.THEME.Accent}, 0.08)
	end)
	btn.MouseButton1Up:Connect(function()
		tween(btn, {BackgroundColor3 = UIlib.THEME.ButtonHover}, 0.1)
	end)
	btn.MouseButton1Click:Connect(function()
		safeCall(callback)
	end)

	return btn
end

-- ───────────────────────────────────────────────────────────────
-- CREATE TOGGLE
-- ───────────────────────────────────────────────────────────────
function UIlib.CreateToggle(section, name, default, callback)
	local parent = (type(section) == "table" and (section.Inner or section.Frame)) or section

	local row = Instance.new("Frame", parent)
	row.Name               = "Toggle_"..name
	row.Size               = UDim2.new(1,0,0,30)
	row.BackgroundTransparency = 1
	row.LayoutOrder        = #parent:GetChildren()

	local lbl = Instance.new("TextLabel", row)
	lbl.Size               = UDim2.new(1,-52,1,0)
	lbl.BackgroundTransparency = 1
	lbl.Text               = name
	lbl.TextColor3         = UIlib.THEME.Text
	lbl.Font               = Enum.Font.Gotham
	lbl.TextSize           = 12
	lbl.TextXAlignment     = Enum.TextXAlignment.Left

	-- Pill background
	local pill = Instance.new("TextButton", row)
	pill.Size              = UDim2.new(0,44,0,22)
	pill.Position          = UDim2.new(1,-46,0.5,-11)
	pill.BackgroundColor3  = default and UIlib.THEME.ToggleOn or UIlib.THEME.ToggleOff
	pill.BorderSizePixel   = 0
	pill.Text              = ""
	pill.AutoButtonColor   = false
	makeCorner(pill, 11)

	-- Thumb
	local thumb = Instance.new("Frame", pill)
	thumb.Size             = UDim2.new(0,16,0,16)
	thumb.Position         = default and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8)
	thumb.BackgroundColor3 = Color3.new(1,1,1)
	thumb.BorderSizePixel  = 0
	makeCorner(thumb, 8)

	local state = default == true
	local obj = {Value = state, Button = pill}

	local function setState(v, fromUser)
		state = v
		obj.Value = v
		tween(pill, {BackgroundColor3 = v and UIlib.THEME.ToggleOn or UIlib.THEME.ToggleOff}, 0.15)
		tween(thumb, {Position = v and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8)}, 0.15)
		if fromUser then safeCall(callback, v) end
	end

	pill.MouseButton1Click:Connect(function()
		setState(not state, true)
	end)

	obj.Set = function(v)
		setState(v, false)
	end

	ctxMenu(row, name, default, function() return state end, function()
		setState(default, true)
	end)

	return obj
end

-- ───────────────────────────────────────────────────────────────
-- CREATE SLIDER
-- ───────────────────────────────────────────────────────────────
function UIlib.CreateSlider(section, name, min, max, default, callback)
	local parent = (type(section) == "table" and (section.Inner or section.Frame)) or section

	local wrap = Instance.new("Frame", parent)
	wrap.Name              = "Slider_"..name
	wrap.Size              = UDim2.new(1,0,0,46)
	wrap.BackgroundTransparency = 1
	wrap.LayoutOrder       = #parent:GetChildren()

	local headerRow = Instance.new("Frame", wrap)
	headerRow.Size         = UDim2.new(1,0,0,18)
	headerRow.BackgroundTransparency = 1

	local lbl = Instance.new("TextLabel", headerRow)
	lbl.Size               = UDim2.new(1,-40,1,0)
	lbl.BackgroundTransparency = 1
	lbl.Text               = name
	lbl.TextColor3         = UIlib.THEME.Text
	lbl.Font               = Enum.Font.Gotham
	lbl.TextSize           = 12
	lbl.TextXAlignment     = Enum.TextXAlignment.Left

	local valLbl = Instance.new("TextLabel", headerRow)
	valLbl.Size            = UDim2.new(0,38,1,0)
	valLbl.Position        = UDim2.new(1,-38,0,0)
	valLbl.BackgroundTransparency = 1
	valLbl.TextColor3      = UIlib.THEME.Accent
	valLbl.Font            = Enum.Font.GothamBold
	valLbl.TextSize        = 12
	valLbl.TextXAlignment  = Enum.TextXAlignment.Right

	local track = Instance.new("Frame", wrap)
	track.Size             = UDim2.new(1,0,0,8)
	track.Position         = UDim2.new(0,0,0,26)
	track.BackgroundColor3 = UIlib.THEME.SliderBG
	track.BorderSizePixel  = 0
	makeCorner(track, 4)

	local fill = Instance.new("Frame", track)
	fill.Size              = UDim2.new(0,0,1,0)
	fill.BackgroundColor3  = UIlib.THEME.SliderFill
	fill.BorderSizePixel   = 0
	makeCorner(fill, 4)

	local thumbBtn = Instance.new("TextButton", track)
	thumbBtn.Size          = UDim2.new(0,14,0,14)
	thumbBtn.Position      = UDim2.new(0,-7,0.5,-7)
	thumbBtn.BackgroundColor3 = Color3.new(1,1,1)
	thumbBtn.BorderSizePixel = 0
	thumbBtn.Text          = ""
	thumbBtn.AutoButtonColor = false
	makeCorner(thumbBtn, 7)

	local value = math.clamp(math.round(default), min, max)
	local obj   = {Value = value}

	local function updateVisual(v)
		local pct = (v - min) / math.max(max - min, 1)
		fill.Size = UDim2.new(pct, 0, 1, 0)
		thumbBtn.Position = UDim2.new(pct, -7, 0.5, -7)
		valLbl.Text = tostring(v)
	end

	local function setValue(v, fromUser)
		v = math.clamp(math.round(v), min, max)
		value = v
		obj.Value = v
		updateVisual(v)
		if fromUser then safeCall(callback, v) end
	end

	updateVisual(value)
	valLbl.Text = tostring(value)

	-- Drag
	local dragging = false
	local function onInput(inp)
		local pct = math.clamp((inp.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		setValue(min + (max - min) * pct, true)
	end

	thumbBtn.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1
		or inp.UserInputType == Enum.UserInputType.Touch then
			dragging = true
		end
	end)
	track.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1
		or inp.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			onInput(inp)
		end
	end)
	UserInputService.InputChanged:Connect(function(inp)
		if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement
		or inp.UserInputType == Enum.UserInputType.Touch) then
			onInput(inp)
		end
	end)
	UserInputService.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1
		or inp.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	obj.Set = function(v) setValue(v, false) end

	ctxMenu(wrap, name, default, function() return value end, function()
		setValue(default, true)
	end)

	return obj
end

-- ───────────────────────────────────────────────────────────────
-- CREATE DROPDOWN
-- ───────────────────────────────────────────────────────────────
function UIlib.CreateDropdown(section, name, options, callback)
	local parent = (type(section) == "table" and (section.Inner or section.Frame)) or section

	local wrap = Instance.new("Frame", parent)
	wrap.Name              = "DD_"..name
	wrap.Size              = UDim2.new(1,0,0,30)
	wrap.BackgroundTransparency = 1
	wrap.LayoutOrder       = #parent:GetChildren()

	local mainBtn = Instance.new("TextButton", wrap)
	mainBtn.Size           = UDim2.new(1,0,1,0)
	mainBtn.BackgroundColor3 = UIlib.THEME.ButtonBG
	mainBtn.BorderSizePixel = 0
	mainBtn.Text           = name..":  "..(options[1] or "—")
	mainBtn.TextColor3     = UIlib.THEME.Text
	mainBtn.Font           = Enum.Font.Gotham
	mainBtn.TextSize       = 12
	mainBtn.TextXAlignment = Enum.TextXAlignment.Left
	mainBtn.AutoButtonColor = false
	makeCorner(mainBtn, 6)
	makePadding(mainBtn, 0, 0, 10, 8)

	local arrow = Instance.new("TextLabel", mainBtn)
	arrow.Size             = UDim2.new(0,20,1,0)
	arrow.Position         = UDim2.new(1,-22,0,0)
	arrow.BackgroundTransparency = 1
	arrow.Text             = "▼"
	arrow.TextColor3       = UIlib.THEME.TextDim
	arrow.Font             = Enum.Font.GothamBold
	arrow.TextSize         = 10

	local selected = options[1] or ""
	local obj = {Value = selected}
	local listOpen = false
	local listFrame = nil

	local function closeList()
		if listFrame then
			listFrame:Destroy()
			listFrame = nil
			listOpen  = false
			tween(arrow, {Rotation = 0}, 0.15)
		end
	end

	local function openList()
		if listOpen then closeList(); return end
		listOpen = true
		tween(arrow, {Rotation = 180}, 0.15)

		listFrame = Instance.new("Frame", _screenGui)
		listFrame.Name             = "DDList"
		listFrame.Size             = UDim2.new(0, wrap.AbsoluteSize.X, 0, math.min(#options, 8)*28 + 8)
		local ap = wrap.AbsolutePosition
		listFrame.Position         = UDim2.new(0, ap.X, 0, ap.Y + wrap.AbsoluteSize.Y + 2)
		listFrame.BackgroundColor3 = UIlib.THEME.BackgroundLight
		listFrame.BorderSizePixel  = 0
		listFrame.ZIndex           = 30
		listFrame.ClipsDescendants = true
		makeCorner(listFrame, 6)
		makePadding(listFrame, 4, 4, 4, 4)
		makeList(listFrame, 2)

		local scroll = Instance.new("ScrollingFrame", listFrame)
		scroll.Size              = UDim2.new(1,0,1,0)
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel   = 0
		scroll.ScrollBarThickness = 3
		scroll.ScrollBarImageColor3 = UIlib.THEME.Accent
		scroll.CanvasSize        = UDim2.new(0,0,0,0)
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		makeList(scroll, 2)
		makePadding(scroll, 2, 2, 2, 2)

		for _, opt in ipairs(options) do
			local ob = Instance.new("TextButton", scroll)
			ob.Size              = UDim2.new(1,0,0,26)
			ob.BackgroundColor3  = opt == selected and UIlib.THEME.SideBarBtnActive or UIlib.THEME.BackgroundLight
			ob.BorderSizePixel   = 0
			ob.Text              = opt
			ob.TextColor3        = opt == selected and UIlib.THEME.Accent or UIlib.THEME.Text
			ob.Font              = Enum.Font.Gotham
			ob.TextSize          = 12
			ob.TextXAlignment    = Enum.TextXAlignment.Left
			ob.ZIndex            = 31
			ob.AutoButtonColor   = false
			makeCorner(ob, 4)
			makePadding(ob, 0, 0, 8, 8)

			ob.MouseEnter:Connect(function()
				if opt ~= selected then
					tween(ob, {BackgroundColor3 = UIlib.THEME.ButtonHover}, 0.1)
				end
			end)
			ob.MouseLeave:Connect(function()
				if opt ~= selected then
					tween(ob, {BackgroundColor3 = UIlib.THEME.BackgroundLight}, 0.1)
				end
			end)
			ob.MouseButton1Click:Connect(function()
				selected = opt
				obj.Value = opt
				mainBtn.Text = name..":  "..opt
				safeCall(callback, opt)
				closeList()
			end)
		end
	end

	mainBtn.MouseButton1Click:Connect(openList)
	mainBtn.MouseEnter:Connect(function()
		tween(mainBtn, {BackgroundColor3 = UIlib.THEME.ButtonHover}, 0.1)
	end)
	mainBtn.MouseLeave:Connect(function()
		tween(mainBtn, {BackgroundColor3 = UIlib.THEME.ButtonBG}, 0.1)
	end)

	-- Close on outside click
	UserInputService.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 and listOpen then
			task.wait()
			if listOpen then closeList() end
		end
	end)

	obj.Set = function(v)
		selected = v
		obj.Value = v
		mainBtn.Text = name..":  "..v
	end
	obj.Refresh = function(newOpts)
		options = newOpts
		selected = newOpts[1] or ""
		obj.Value = selected
		mainBtn.Text = name..":  "..selected
		closeList()
	end

	return obj
end

-- ───────────────────────────────────────────────────────────────
-- CREATE TEXTBOX
-- ───────────────────────────────────────────────────────────────
function UIlib.CreateTextbox(section, name, placeholder, callback)
	local parent = (type(section) == "table" and (section.Inner or section.Frame)) or section

	local wrap = Instance.new("Frame", parent)
	wrap.Name              = "TB_"..name
	wrap.Size              = UDim2.new(1,0,0,52)
	wrap.BackgroundTransparency = 1
	wrap.LayoutOrder       = #parent:GetChildren()

	local lbl = Instance.new("TextLabel", wrap)
	lbl.Size               = UDim2.new(1,0,0,18)
	lbl.BackgroundTransparency = 1
	lbl.Text               = name
	lbl.TextColor3         = UIlib.THEME.TextDim
	lbl.Font               = Enum.Font.Gotham
	lbl.TextSize           = 11
	lbl.TextXAlignment     = Enum.TextXAlignment.Left

	local box = Instance.new("TextBox", wrap)
	box.Name               = "Input"
	box.Size               = UDim2.new(1,0,0,30)
	box.Position           = UDim2.new(0,0,0,20)
	box.BackgroundColor3   = UIlib.THEME.BackgroundLight
	box.BorderSizePixel    = 0
	box.PlaceholderText    = placeholder or ""
	box.PlaceholderColor3  = UIlib.THEME.TextDim
	box.Text               = ""
	box.TextColor3         = UIlib.THEME.Text
	box.Font               = Enum.Font.Gotham
	box.TextSize           = 12
	box.ClearTextOnFocus   = false
	box.TextXAlignment     = Enum.TextXAlignment.Left
	makeCorner(box, 6)
	makePadding(box, 0, 0, 10, 8)

	box.FocusLost:Connect(function(enterPressed)
		safeCall(callback, box.Text, enterPressed)
	end)

	return box
end

-- ───────────────────────────────────────────────────────────────
-- CREATE LABEL
-- ───────────────────────────────────────────────────────────────
function UIlib.CreateLabel(section, text)
	local parent = (type(section) == "table" and (section.Inner or section.Frame)) or section

	local lbl = Instance.new("TextLabel", parent)
	lbl.Name               = "Lbl"
	lbl.Size               = UDim2.new(1,0,0,0)
	lbl.AutomaticSize      = Enum.AutomaticSize.Y
	lbl.BackgroundTransparency = 1
	lbl.Text               = text
	lbl.TextColor3         = UIlib.THEME.TextDim
	lbl.Font               = Enum.Font.Gotham
	lbl.TextSize           = 12
	lbl.TextXAlignment     = Enum.TextXAlignment.Left
	lbl.TextWrapped        = true
	lbl.LayoutOrder        = #parent:GetChildren()
	return lbl
end

-- ───────────────────────────────────────────────────────────────
-- CREATE SEPARATOR
-- ───────────────────────────────────────────────────────────────
function UIlib.CreateSeparator(section)
	local parent = (type(section) == "table" and (section.Inner or section.Frame)) or section

	local sep = Instance.new("Frame", parent)
	sep.Name               = "Sep"
	sep.Size               = UDim2.new(1,0,0,1)
	sep.BackgroundColor3   = UIlib.THEME.Separator
	sep.BorderSizePixel    = 0
	sep.LayoutOrder        = #parent:GetChildren()
	return sep
end

-- ───────────────────────────────────────────────────────────────
-- CREATE COLOR PICKER  (inline swatch → opens popup)
-- ───────────────────────────────────────────────────────────────
function UIlib.CreateColorPicker(section, name, defaultColor, callback)
	local parent = (type(section) == "table" and (section.Inner or section.Frame)) or section
	defaultColor = defaultColor or Color3.new(1,1,1)

	local row = Instance.new("Frame", parent)
	row.Name               = "CP_"..name
	row.Size               = UDim2.new(1,0,0,30)
	row.BackgroundTransparency = 1
	row.LayoutOrder        = #parent:GetChildren()

	local lbl = Instance.new("TextLabel", row)
	lbl.Size               = UDim2.new(1,-80,1,0)
	lbl.BackgroundTransparency = 1
	lbl.Text               = name
	lbl.TextColor3         = UIlib.THEME.Text
	lbl.Font               = Enum.Font.Gotham
	lbl.TextSize           = 12
	lbl.TextXAlignment     = Enum.TextXAlignment.Left

	local swatch = Instance.new("TextButton", row)
	swatch.Size            = UDim2.new(0,70,0,22)
	swatch.Position        = UDim2.new(1,-72,0.5,-11)
	swatch.BackgroundColor3 = defaultColor
	swatch.BorderSizePixel = 0
	swatch.Text            = ""
	swatch.AutoButtonColor = false
	makeCorner(swatch, 5)

	-- Hex overlay
	local hexLbl = Instance.new("TextLabel", swatch)
	hexLbl.Size            = UDim2.new(1,0,1,0)
	hexLbl.BackgroundTransparency = 1
	hexLbl.Text            = "#"..defaultColor:ToHex():upper()
	hexLbl.TextColor3      = Color3.new(1,1,1)
	hexLbl.Font            = Enum.Font.Gotham
	hexLbl.TextSize        = 9
	hexLbl.TextXAlignment  = Enum.TextXAlignment.Center

	local currentColor = defaultColor
	local obj = {Value = currentColor}

	swatch.MouseButton1Click:Connect(function()
		UIlib.OpenColorEditor(name, currentColor, function(newCol)
			currentColor        = newCol
			obj.Value           = newCol
			swatch.BackgroundColor3 = newCol
			hexLbl.Text         = "#"..newCol:ToHex():upper()
			safeCall(callback, newCol)
		end)
	end)

	obj.Set = function(col)
		currentColor        = col
		obj.Value           = col
		swatch.BackgroundColor3 = col
		hexLbl.Text         = "#"..col:ToHex():upper()
	end

	return obj
end

-- ───────────────────────────────────────────────────────────────
-- CREATE KEYBIND
-- ───────────────────────────────────────────────────────────────
function UIlib.CreateKeybind(section, name, defaultKey, callback)
	local parent = (type(section) == "table" and (section.Inner or section.Frame)) or section
	defaultKey = defaultKey or Enum.KeyCode.Unknown

	local row = Instance.new("Frame", parent)
	row.Name               = "KB_"..name
	row.Size               = UDim2.new(1,0,0,30)
	row.BackgroundTransparency = 1
	row.LayoutOrder        = #parent:GetChildren()

	local lbl = Instance.new("TextLabel", row)
	lbl.Size               = UDim2.new(1,-100,1,0)
	lbl.BackgroundTransparency = 1
	lbl.Text               = name
	lbl.TextColor3         = UIlib.THEME.Text
	lbl.Font               = Enum.Font.Gotham
	lbl.TextSize           = 12
	lbl.TextXAlignment     = Enum.TextXAlignment.Left

	local keyBtn = Instance.new("TextButton", row)
	keyBtn.Size            = UDim2.new(0,88,0,24)
	keyBtn.Position        = UDim2.new(1,-90,0.5,-12)
	keyBtn.BackgroundColor3 = UIlib.THEME.KeybindBG
	keyBtn.BorderSizePixel = 0
	keyBtn.Text            = defaultKey.Name ~= "Unknown" and "["..defaultKey.Name.."]" or "[ None ]"
	keyBtn.TextColor3      = UIlib.THEME.Accent
	keyBtn.Font            = Enum.Font.GothamSemibold
	keyBtn.TextSize        = 11
	keyBtn.AutoButtonColor = false
	makeCorner(keyBtn, 5)

	local currentKey = defaultKey
	local listening  = false
	local obj        = {Value = currentKey}

	local function setKey(kc)
		currentKey  = kc
		obj.Value   = kc
		keyBtn.Text = kc.Name ~= "Unknown" and "["..kc.Name.."]" or "[ None ]"
		keyBtn.TextColor3 = UIlib.THEME.Accent
	end

	keyBtn.MouseButton1Click:Connect(function()
		listening = true
		keyBtn.Text = "[ ... ]"
		keyBtn.TextColor3 = UIlib.THEME.TextDim
	end)

	UserInputService.InputBegan:Connect(function(inp, gpe)
		if listening and inp.UserInputType == Enum.UserInputType.Keyboard then
			listening = false
			setKey(inp.KeyCode)
			safeCall(callback, inp.KeyCode)
		elseif not listening and inp.UserInputType == Enum.UserInputType.Keyboard
		and currentKey ~= Enum.KeyCode.Unknown and inp.KeyCode == currentKey then
			safeCall(callback, inp.KeyCode)
		end
	end)

	obj.Set = setKey

	return obj
end

-- ───────────────────────────────────────────────────────────────
-- CREATE PROGRESS BAR
-- ───────────────────────────────────────────────────────────────
function UIlib.CreateProgressBar(section, name, initialValue, maxValue)
	local parent = (type(section) == "table" and (section.Inner or section.Frame)) or section
	initialValue = initialValue or 0
	maxValue     = maxValue     or 100

	local wrap = Instance.new("Frame", parent)
	wrap.Name              = "PB_"..name
	wrap.Size              = UDim2.new(1,0,0,38)
	wrap.BackgroundTransparency = 1
	wrap.LayoutOrder       = #parent:GetChildren()

	local headerRow = Instance.new("Frame", wrap)
	headerRow.Size         = UDim2.new(1,0,0,16)
	headerRow.BackgroundTransparency = 1

	local lbl = Instance.new("TextLabel", headerRow)
	lbl.Size               = UDim2.new(1,-44,1,0)
	lbl.BackgroundTransparency = 1
	lbl.Text               = name
	lbl.TextColor3         = UIlib.THEME.Text
	lbl.Font               = Enum.Font.Gotham
	lbl.TextSize           = 12
	lbl.TextXAlignment     = Enum.TextXAlignment.Left

	local pctLbl = Instance.new("TextLabel", headerRow)
	pctLbl.Size            = UDim2.new(0,42,1,0)
	pctLbl.Position        = UDim2.new(1,-42,0,0)
	pctLbl.BackgroundTransparency = 1
	pctLbl.TextColor3      = UIlib.THEME.Accent
	pctLbl.Font            = Enum.Font.GothamBold
	pctLbl.TextSize        = 12
	pctLbl.TextXAlignment  = Enum.TextXAlignment.Right

	local track = Instance.new("Frame", wrap)
	track.Size             = UDim2.new(1,0,0,8)
	track.Position         = UDim2.new(0,0,0,22)
	track.BackgroundColor3 = UIlib.THEME.ProgressBG
	track.BorderSizePixel  = 0
	makeCorner(track, 4)

	local fill = Instance.new("Frame", track)
	fill.Size              = UDim2.new(0,0,1,0)
	fill.BackgroundColor3  = UIlib.THEME.ProgressFill
	fill.BorderSizePixel   = 0
	makeCorner(fill, 4)

	local currentVal = initialValue
	local obj = {Value = currentVal}

	local function update(v, animate)
		v = math.clamp(v, 0, maxValue)
		currentVal = v
		obj.Value  = v
		local pct = v / maxValue
		pctLbl.Text = math.floor(pct * 100).."%"
		if animate ~= false then
			tween(fill, {Size = UDim2.new(pct, 0, 1, 0)}, 0.3)
		else
			fill.Size = UDim2.new(pct, 0, 1, 0)
		end
	end

	update(initialValue, false)
	obj.Set = update

	return obj
end

-- ───────────────────────────────────────────────────────────────
-- CREATE TABLE
-- ───────────────────────────────────────────────────────────────
function UIlib.CreateTable(section, headers, rows, rowHeight)
	local parent = (type(section) == "table" and (section.Inner or section.Frame)) or section
	rowHeight = rowHeight or 26

	local totalHeight = (1 + math.min(#rows, 6)) * rowHeight + 4
	local container = Instance.new("Frame", parent)
	container.Name             = "Table"
	container.Size             = UDim2.new(1,0,0,totalHeight)
	container.BackgroundColor3 = UIlib.THEME.BackgroundLight
	container.BorderSizePixel  = 0
	container.ClipsDescendants = true
	container.LayoutOrder      = #parent:GetChildren()
	makeCorner(container, 6)

	-- Header
	local headerFrame = Instance.new("Frame", container)
	headerFrame.Size           = UDim2.new(1,0,0,rowHeight)
	headerFrame.BackgroundColor3 = UIlib.THEME.TableHeader
	headerFrame.BorderSizePixel = 0
	makeCorner(headerFrame, 6)
	-- cover bottom corners
	local hc = Instance.new("Frame", headerFrame)
	hc.Size = UDim2.new(1,0,0,8); hc.Position = UDim2.new(0,0,1,-8)
	hc.BackgroundColor3 = UIlib.THEME.TableHeader; hc.BorderSizePixel = 0

	local colW = 1 / math.max(#headers, 1)
	for i, h in ipairs(headers) do
		local hl = Instance.new("TextLabel", headerFrame)
		hl.Size  = UDim2.new(colW,0,1,0)
		hl.Position = UDim2.new(colW*(i-1),0,0,0)
		hl.BackgroundTransparency = 1
		hl.Text  = h; hl.TextColor3 = UIlib.THEME.Accent
		hl.Font  = Enum.Font.GothamBold; hl.TextSize = 11
		makePadding(hl,0,0,6,4)
	end

	-- Scrollable rows
	local scroll = Instance.new("ScrollingFrame", container)
	scroll.Size              = UDim2.new(1,0,1,-rowHeight)
	scroll.Position          = UDim2.new(0,0,0,rowHeight)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel   = 0
	scroll.ScrollBarThickness = 3
	scroll.ScrollBarImageColor3 = UIlib.THEME.Accent
	scroll.CanvasSize        = UDim2.new(0,0,0,0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	makeList(scroll, 0)

	local obj = {Rows = {}}

	local function addRow(rowData, index)
		index = index or #obj.Rows + 1
		local isAlt = index % 2 == 0
		local rowFrame = Instance.new("Frame", scroll)
		rowFrame.Size          = UDim2.new(1,0,0,rowHeight)
		rowFrame.BackgroundColor3 = isAlt and UIlib.THEME.TableRowAlt or UIlib.THEME.TableRow
		rowFrame.BorderSizePixel = 0
		rowFrame.LayoutOrder   = index

		for i, cell in ipairs(rowData) do
			local cl = Instance.new("TextLabel", rowFrame)
			cl.Size   = UDim2.new(colW,0,1,0)
			cl.Position = UDim2.new(colW*(i-1),0,0,0)
			cl.BackgroundTransparency = 1
			cl.Text   = tostring(cell); cl.TextColor3 = UIlib.THEME.Text
			cl.Font   = Enum.Font.Gotham; cl.TextSize = 11
			cl.TextXAlignment = Enum.TextXAlignment.Left
			makePadding(cl,0,0,6,4)
		end

		table.insert(obj.Rows, rowFrame)
		return rowFrame
	end

	for i, row in ipairs(rows) do
		addRow(row, i)
	end

	obj.AddRow = addRow
	obj.Clear  = function()
		for _, r in ipairs(obj.Rows) do r:Destroy() end
		obj.Rows = {}
	end
	obj.Refresh = function(newRows)
		obj.Clear()
		for i, row in ipairs(newRows) do addRow(row, i) end
	end

	return obj
end

-- ───────────────────────────────────────────────────────────────
-- ADD SETTING  (convenience helper — backward compat)
-- ───────────────────────────────────────────────────────────────
function UIlib.AddSetting(window, name, kind, ...)
	local sec = window.Sections and window.Sections["Settings"]
	if not sec then
		sec = UIlib.Section(window, "Settings")
	end

	local args = {...}
	if kind == "toggle"   then return UIlib.CreateToggle(sec, name, args[1], args[2])
	elseif kind == "slider"  then return UIlib.CreateSlider(sec, name, args[1], args[2], args[3], args[4])
	elseif kind == "dropdown" then return UIlib.CreateDropdown(sec, name, args[1], args[2])
	elseif kind == "textbox" then return UIlib.CreateTextbox(sec, name, args[1], args[2])
	elseif kind == "button"  then return UIlib.CreateButton(sec, name, args[1])
	elseif kind == "label"   then return UIlib.CreateLabel(sec, args[1])
	elseif kind == "colorpicker" then return UIlib.CreateColorPicker(sec, name, args[1], args[2])
	elseif kind == "keybind" then return UIlib.CreateKeybind(sec, name, args[1], args[2])
	elseif kind == "progress" then return UIlib.CreateProgressBar(sec, name, args[1], args[2])
	end
end

-- ───────────────────────────────────────────────────────────────
-- COLOR EDITOR  (VSCode-style popup)
-- ───────────────────────────────────────────────────────────────
function UIlib.OpenColorEditor(label, currentColor, onDone)
	local h, s, v = Color3.toHSV(currentColor or Color3.new(1,1,1))

	local popup = Instance.new("Frame", _screenGui)
	popup.Name             = "ColorEditor"
	popup.Size             = UDim2.new(0,240,0,290)
	popup.Position         = UDim2.new(0.5,-120,0.5,-145)
	popup.BackgroundColor3 = UIlib.THEME.BackgroundLight
	popup.BorderSizePixel  = 0
	popup.ZIndex           = 60
	makeCorner(popup, 10)
	draggable(popup)

	-- Title
	local title = Instance.new("TextLabel", popup)
	title.Size             = UDim2.new(1,-30,0,32)
	title.Position         = UDim2.new(0,10,0,0)
	title.BackgroundTransparency = 1
	title.Text             = "Color: "..label
	title.TextColor3       = UIlib.THEME.Accent
	title.Font             = Enum.Font.GothamBold
	title.TextSize         = 13
	title.TextXAlignment   = Enum.TextXAlignment.Left
	title.ZIndex           = 61

	local closeX = Instance.new("TextButton", popup)
	closeX.Size            = UDim2.new(0,24,0,24)
	closeX.Position        = UDim2.new(1,-28,0,4)
	closeX.BackgroundTransparency = 1
	closeX.Text            = "×"
	closeX.TextColor3      = UIlib.THEME.TextDim
	closeX.Font            = Enum.Font.GothamBold
	closeX.TextSize        = 18
	closeX.ZIndex          = 62

	-- SV square
	local svFrame = Instance.new("Frame", popup)
	svFrame.Size           = UDim2.new(1,-16,0,160)
	svFrame.Position       = UDim2.new(0,8,0,38)
	svFrame.BorderSizePixel = 0
	svFrame.ZIndex         = 61
	makeCorner(svFrame, 6)

	local svGrad = Instance.new("UIGradient", svFrame)
	svGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1,1,1)),
		ColorSequenceKeypoint.new(1, Color3.fromHSV(h,1,1)),
	})
	svGrad.Rotation = 90

	local svDark = Instance.new("Frame", svFrame)
	svDark.Size            = UDim2.new(1,0,1,0)
	svDark.BackgroundColor3 = Color3.new(0,0,0)
	svDark.BackgroundTransparency = 0
	svDark.BorderSizePixel = 0
	local svDarkGrad = Instance.new("UIGradient", svDark)
	svDarkGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(0,0,0)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(0,0,0)),
	})
	svDarkGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})

	local svThumb = Instance.new("Frame", svFrame)
	svThumb.Size           = UDim2.new(0,12,0,12)
	svThumb.BackgroundColor3 = Color3.new(1,1,1)
	svThumb.BorderSizePixel = 1
	svThumb.ZIndex         = 62
	makeCorner(svThumb, 6)

	-- Hue strip
	local hueFrame = Instance.new("Frame", popup)
	hueFrame.Size          = UDim2.new(1,-16,0,14)
	hueFrame.Position      = UDim2.new(0,8,0,206)
	hueFrame.BorderSizePixel = 0
	hueFrame.ZIndex        = 61
	makeCorner(hueFrame, 4)
	local hueGrad = Instance.new("UIGradient", hueFrame)
	hueGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0,    Color3.fromHSV(0,1,1)),
		ColorSequenceKeypoint.new(0.167,Color3.fromHSV(0.167,1,1)),
		ColorSequenceKeypoint.new(0.333,Color3.fromHSV(0.333,1,1)),
		ColorSequenceKeypoint.new(0.5,  Color3.fromHSV(0.5,1,1)),
		ColorSequenceKeypoint.new(0.667,Color3.fromHSV(0.667,1,1)),
		ColorSequenceKeypoint.new(0.833,Color3.fromHSV(0.833,1,1)),
		ColorSequenceKeypoint.new(1,    Color3.fromHSV(1,1,1)),
	})

	local hueThumb = Instance.new("Frame", hueFrame)
	hueThumb.Size          = UDim2.new(0,8,0,14)
	hueThumb.BackgroundColor3 = Color3.new(1,1,1)
	hueThumb.BorderSizePixel = 1
	hueThumb.ZIndex        = 62
	makeCorner(hueThumb, 4)

	-- Preview swatch
	local preview = Instance.new("Frame", popup)
	preview.Size           = UDim2.new(0,40,0,22)
	preview.Position       = UDim2.new(0,8,0,228)
	preview.BorderSizePixel = 0
	preview.BackgroundColor3 = currentColor or Color3.new(1,1,1)
	preview.ZIndex         = 61
	makeCorner(preview, 5)

	local hexBox = Instance.new("TextBox", popup)
	hexBox.Size            = UDim2.new(1,-60,0,22)
	hexBox.Position        = UDim2.new(0,54,0,228)
	hexBox.BackgroundColor3 = UIlib.THEME.Background
	hexBox.BorderSizePixel = 0
	hexBox.Text            = (currentColor or Color3.new(1,1,1)):ToHex():upper()
	hexBox.TextColor3      = UIlib.THEME.Text
	hexBox.Font            = Enum.Font.Code
	hexBox.TextSize        = 12
	hexBox.ZIndex          = 61
	makeCorner(hexBox, 5)
	makePadding(hexBox, 0, 0, 6, 4)

	-- Buttons
	local applyBtn = Instance.new("TextButton", popup)
	applyBtn.Size          = UDim2.new(0.5,-12,0,28)
	applyBtn.Position      = UDim2.new(0,8,1,-36)
	applyBtn.BackgroundColor3 = UIlib.THEME.Accent
	applyBtn.BackgroundTransparency = 0.2
	applyBtn.BorderSizePixel = 0
	applyBtn.Text          = "Apply"
	applyBtn.TextColor3    = Color3.new(1,1,1)
	applyBtn.Font          = Enum.Font.GothamSemibold
	applyBtn.TextSize      = 12
	applyBtn.ZIndex        = 61
	makeCorner(applyBtn, 6)

	local cancelBtn = Instance.new("TextButton", popup)
	cancelBtn.Size         = UDim2.new(0.5,-12,0,28)
	cancelBtn.Position     = UDim2.new(0.5,4,1,-36)
	cancelBtn.BackgroundColor3 = UIlib.THEME.ButtonBG
	cancelBtn.BorderSizePixel = 0
	cancelBtn.Text         = "Cancel"
	cancelBtn.TextColor3   = UIlib.THEME.Text
	cancelBtn.Font         = Enum.Font.GothamSemibold
	cancelBtn.TextSize     = 12
	cancelBtn.ZIndex       = 61
	makeCorner(cancelBtn, 6)

	-- Update functions
	local function updateSvGradient()
		svGrad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1,1,1)),
			ColorSequenceKeypoint.new(1, Color3.fromHSV(h,1,1)),
		})
	end

	local function updatePreview()
		local col = Color3.fromHSV(h, s, v)
		preview.BackgroundColor3 = col
		hexBox.Text = col:ToHex():upper()
	end

	local function updateSvThumb()
		svThumb.Position = UDim2.new(s,-6,1-v,-6)
	end

	local function updateHueThumb()
		hueThumb.Position = UDim2.new(h,-4,0,0)
	end

	updateSvGradient()
	updateSvThumb()
	updateHueThumb()
	updatePreview()

	-- SV drag
	local svDragging = false
	svFrame.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1
		or inp.UserInputType == Enum.UserInputType.Touch then
			svDragging = true
			local rel = inp.Position - svFrame.AbsolutePosition
			s = math.clamp(rel.X / svFrame.AbsoluteSize.X, 0, 1)
			v = math.clamp(1 - rel.Y / svFrame.AbsoluteSize.Y, 0, 1)
			updateSvThumb(); updatePreview()
		end
	end)
	UserInputService.InputChanged:Connect(function(inp)
		if svDragging and (inp.UserInputType == Enum.UserInputType.MouseMovement
		or inp.UserInputType == Enum.UserInputType.Touch) then
			local rel = inp.Position - svFrame.AbsolutePosition
			s = math.clamp(rel.X / svFrame.AbsoluteSize.X, 0, 1)
			v = math.clamp(1 - rel.Y / svFrame.AbsoluteSize.Y, 0, 1)
			updateSvThumb(); updatePreview()
		end
	end)
	UserInputService.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1
		or inp.UserInputType == Enum.UserInputType.Touch then
			svDragging = false
		end
	end)

	-- Hue drag
	local hueDragging = false
	hueFrame.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1
		or inp.UserInputType == Enum.UserInputType.Touch then
			hueDragging = true
			h = math.clamp((inp.Position.X - hueFrame.AbsolutePosition.X) / hueFrame.AbsoluteSize.X, 0, 1)
			updateSvGradient(); updateHueThumb(); updatePreview()
		end
	end)
	UserInputService.InputChanged:Connect(function(inp)
		if hueDragging and (inp.UserInputType == Enum.UserInputType.MouseMovement
		or inp.UserInputType == Enum.UserInputType.Touch) then
			h = math.clamp((inp.Position.X - hueFrame.AbsolutePosition.X) / hueFrame.AbsoluteSize.X, 0, 1)
			updateSvGradient(); updateHueThumb(); updatePreview()
		end
	end)
	UserInputService.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1
		or inp.UserInputType == Enum.UserInputType.Touch then
			hueDragging = false
		end
	end)

	-- Hex input
	hexBox.FocusLost:Connect(function()
		local hex = hexBox.Text:gsub("#",""):sub(1,6)
		if #hex == 6 then
			local r = tonumber(hex:sub(1,2),16) or 0
			local g = tonumber(hex:sub(3,4),16) or 0
			local b = tonumber(hex:sub(5,6),16) or 0
			local col = Color3.fromRGB(r,g,b)
			h,s,v = Color3.toHSV(col)
			updateSvGradient(); updateSvThumb(); updateHueThumb(); updatePreview()
		end
	end)

	applyBtn.MouseButton1Click:Connect(function()
		popup:Destroy()
		safeCall(onDone, Color3.fromHSV(h,s,v))
	end)
	cancelBtn.MouseButton1Click:Connect(function()
		popup:Destroy()
	end)
	closeX.MouseButton1Click:Connect(function()
		popup:Destroy()
	end)
end

-- ───────────────────────────────────────────────────────────────
-- DESTROY
-- ───────────────────────────────────────────────────────────────
function UIlib.Destroy()
	if _screenGui then
		_screenGui:Destroy()
		_screenGui    = nil
		_contentFrame = nil
		_sbScroll     = nil
		_notifHolder  = nil
		_tooltipLabel = nil
		_windows      = {}
		_activeWin    = nil
		_registry     = {}
	end
end

-- ───────────────────────────────────────────────────────────────
-- KEYBOARD SHORTCUT  (Left Alt + Right Shift  →  toggle GUI)
-- ───────────────────────────────────────────────────────────────
UserInputService.InputBegan:Connect(function(inp, gpe)
	if gpe then return end
	if inp.KeyCode == Enum.KeyCode.RightShift
	and UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) then
		if _screenGui then
			_screenGui.Enabled = not _screenGui.Enabled
			fire("visibilityChanged", _screenGui.Enabled)
		end
	end
end)

-- ───────────────────────────────────────────────────────────────
-- MOBILE TOUCH PASSTHROUGH
-- Mobile executors use UIS Touch events — already handled above
-- by checking Enum.UserInputType.Touch in all drag/input blocks.
-- No extra code needed.
-- ───────────────────────────────────────────────────────────────

return UIlib
