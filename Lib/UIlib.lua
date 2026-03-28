--[[
	TKLib UIlib.lua
	UI Framework for TKHub
	
	API:
	  local Window = UIlib.MainWindow(name)
	  local Section = UIlib.Section(window, name)
	  local Btn     = UIlib.CreateButton(section, name, callback)
	  local Toggle  = UIlib.CreateToggle(section, name, default, callback)
	  local Slider  = UIlib.CreateSlider(section, name, min, max, default, callback)
	  local DD      = UIlib.CreateDropdown(section, name, options, callback)
	  local TB      = UIlib.CreateTextbox(section, name, placeholder, callback)
	  local Lbl     = UIlib.CreateLabel(section, text)
	               UIlib.CreateSeparator(section)
	  local Setting = UIlib.AddSetting(window, name, settingType, ...)
	               UIlib.Notify(title, body, duration)
	               UIlib.SetTheme(colorTable)
	               UIlib.Destroy()
]]

-- ======================================================
-- SERVICES
-- ======================================================
local Players        = game:GetService("Players")
local TweenService   = game:GetService("TweenService")
local UIS            = game:GetService("UserInputService")

local Player         = Players.LocalPlayer
local PlayerGui      = Player:WaitForChild("PlayerGui")

-- ======================================================
-- DEFAULTS
-- ======================================================
local UIlib = {}
UIlib.__windows = {}
UIlib.__screenGui = nil

local THEME = {
	Background       = Color3.fromRGB(27,  27,  27),
	BackgroundLight  = Color3.fromRGB(50,  50,  50),
	SideBar          = Color3.fromRGB(35,  35,  35),
	SideBarBtn       = Color3.fromRGB(45,  45,  45),
	SideBarBtnActive = Color3.fromRGB(60,  60,  60),
	Accent           = Color3.fromRGB(80,  120, 200),
	Text             = Color3.fromRGB(255, 255, 255),
	TextDim          = Color3.fromRGB(150, 150, 150),
	ButtonBG         = Color3.fromRGB(60,  60,  60),
	ButtonHover      = Color3.fromRGB(75,  75,  75),
	ToggleOff        = Color3.fromRGB(80,  80,  80),
	ToggleOn         = Color3.fromRGB(80,  180, 80),
	SliderBG         = Color3.fromRGB(50,  50,  50),
	SliderFill       = Color3.fromRGB(80,  120, 200),
	SectionHeader    = Color3.fromRGB(40,  40,  40),
	Separator        = Color3.fromRGB(60,  60,  60),
	NotifyBG         = Color3.fromRGB(35,  35,  35),
}

local FONT      = Enum.Font.GothamSemibold
local FONT_BODY = Enum.Font.Gotham

-- ======================================================
-- INTERNAL HELPERS
-- ======================================================
local function tween(obj, props, t, style, dir)
	t     = t     or 0.2
	style = style or Enum.EasingStyle.Quad
	dir   = dir   or Enum.EasingDirection.Out
	TweenService:Create(obj, TweenInfo.new(t, style, dir), props):Play()
end

local function corner(parent, radius)
	local c = Instance.new("UICorner", parent)
	c.CornerRadius = UDim.new(0, radius or 6)
	return c
end

local function pad(parent, top, bottom, left, right)
	local p = Instance.new("UIPadding", parent)
	p.PaddingTop    = UDim.new(0, top    or 6)
	p.PaddingBottom = UDim.new(0, bottom or 6)
	p.PaddingLeft   = UDim.new(0, left   or 8)
	p.PaddingRight  = UDim.new(0, right  or 8)
	return p
end

local function listLayout(parent, spacing, dir, halign, valign)
	local l = Instance.new("UIListLayout", parent)
	l.Padding          = UDim.new(0, spacing or 6)
	l.FillDirection    = dir    or Enum.FillDirection.Vertical
	l.HorizontalAlignment = halign or Enum.HorizontalAlignment.Left
	l.VerticalAlignment   = valign or Enum.VerticalAlignment.Top
	l.SortOrder        = Enum.SortOrder.LayoutOrder
	return l
end

local function autoSize(frame, axis)
	frame.AutomaticSize = axis or Enum.AutomaticSize.Y
end

local function makeLabel(parent, text, size, color, font, xAlign)
	local l = Instance.new("TextLabel", parent)
	l.BackgroundTransparency = 1
	l.Text      = text or ""
	l.TextSize  = size or 14
	l.TextColor3 = color or THEME.Text
	l.Font      = font or FONT_BODY
	l.TextXAlignment = xAlign or Enum.TextXAlignment.Left
	l.Size      = UDim2.new(1, 0, 0, size and size + 6 or 20)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.TextWrapped = true
	return l
end

local function hoverEffect(btn, normal, hover)
	btn.MouseEnter:Connect(function()
		tween(btn, {BackgroundColor3 = hover})
	end)
	btn.MouseLeave:Connect(function()
		tween(btn, {BackgroundColor3 = normal})
	end)
end

-- ======================================================
-- DRAG SYSTEM
-- ======================================================
local function makeDraggable(frame, handle)
	handle = handle or frame
	local dragging, dragInput, mousePos, framePos

	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging  = true
			mousePos  = input.Position
			framePos  = frame.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	handle.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			dragInput = input
		end
	end)

	UIS.InputChanged:Connect(function(input)
		if dragging and input == dragInput then
			local delta = input.Position - mousePos
			frame.Position = UDim2.new(
				framePos.X.Scale,
				framePos.X.Offset + delta.X,
				framePos.Y.Scale,
				framePos.Y.Offset + delta.Y
			)
		end
	end)
end

-- ======================================================
-- ROOT SCREENGUI
-- ======================================================
local function getScreenGui()
	if UIlib.__screenGui and UIlib.__screenGui.Parent then
		return UIlib.__screenGui
	end
	local sg = Instance.new("ScreenGui", PlayerGui)
	sg.Name            = "TKLib"
	sg.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
	sg.ResetOnSpawn    = false
	UIlib.__screenGui  = sg
	return sg
end

-- ======================================================
-- SIDEBAR
-- ======================================================
local function buildSideBar(sg, onTabClick)
	local sidebar = Instance.new("Frame", sg)
	sidebar.Name             = "TKLibSidebar"
	sidebar.Size             = UDim2.new(0, 120, 0, 0)
	sidebar.Position         = UDim2.new(0, 20, 0.5, 0)
	sidebar.AnchorPoint      = Vector2.new(0, 0.5)
	sidebar.BackgroundColor3 = THEME.SideBar
	sidebar.BorderSizePixel  = 0
	sidebar.AutomaticSize    = Enum.AutomaticSize.Y
	corner(sidebar, 8)
	pad(sidebar, 8, 8, 6, 6)
	listLayout(sidebar, 4)

	-- Title label
	local titleLbl = Instance.new("TextLabel", sidebar)
	titleLbl.Size                = UDim2.new(1, 0, 0, 24)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text                = "TKHub"
	titleLbl.TextColor3          = THEME.Accent
	titleLbl.Font                = FONT
	titleLbl.TextSize            = 15
	titleLbl.TextXAlignment      = Enum.TextXAlignment.Center
	titleLbl.LayoutOrder         = -1

	local sep = Instance.new("Frame", sidebar)
	sep.Size             = UDim2.new(1, 0, 0, 1)
	sep.BackgroundColor3 = THEME.Separator
	sep.BorderSizePixel  = 0
	sep.LayoutOrder      = 0

	return sidebar
end

local function addSidebarButton(sidebar, name, order, onClick)
	local btn = Instance.new("TextButton", sidebar)
	btn.Name                = "SideBtn_" .. name
	btn.Size                = UDim2.new(1, 0, 0, 30)
	btn.BackgroundColor3    = THEME.SideBarBtn
	btn.BorderSizePixel     = 0
	btn.Text                = name
	btn.TextColor3          = THEME.TextDim
	btn.Font                = FONT_BODY
	btn.TextSize            = 13
	btn.LayoutOrder         = order or 999
	corner(btn, 5)
	hoverEffect(btn, THEME.SideBarBtn, THEME.SideBarBtnActive)

	btn.MouseButton1Click:Connect(function()
		-- Dim all sidebar buttons
		for _, child in ipairs(sidebar:GetChildren()) do
			if child:IsA("TextButton") then
				child.TextColor3 = THEME.TextDim
				tween(child, {BackgroundColor3 = THEME.SideBarBtn})
			end
		end
		-- Activate this one
		btn.TextColor3 = THEME.Text
		tween(btn, {BackgroundColor3 = THEME.SideBarBtnActive})
		onClick()
	end)

	return btn
end

-- ======================================================
-- MAINWINDOW
-- ======================================================
--[[
	UIlib.MainWindow(name) -> WindowObject
	  .Frame        : the main content Frame
	  .Sidebar      : reference to the root sidebar
	  .Name         : string
	  .Sections     : { [sectionName] = Frame }
	  :AddSetting(name, settingType, ...)  -> see AddSetting
]]
function UIlib.MainWindow(name)
	local sg      = getScreenGui()
	local winCount = #UIlib.__windows
	
	-- Sidebar (shared across all windows if exists, or create)
	local sidebar = sg:FindFirstChild("TKLibSidebar") or buildSideBar(sg)
	if not sg:FindFirstChild("TKLibSidebar") then
		sidebar.Parent = sg
	end

	-- Content frame for this window
	local contentFrame = Instance.new("ScrollingFrame", sg)
	contentFrame.Name                = "TKWin_" .. name
	contentFrame.Size                = UDim2.new(0, 400, 0, 480)
	contentFrame.Position            = UDim2.new(0, 150, 0.5, 0)
	contentFrame.AnchorPoint         = Vector2.new(0, 0.5)
	contentFrame.BackgroundColor3    = THEME.Background
	contentFrame.BorderSizePixel     = 0
	contentFrame.ScrollBarThickness  = 4
	contentFrame.ScrollBarImageColor3 = THEME.Accent
	contentFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	contentFrame.CanvasSize          = UDim2.new(0, 0, 0, 0)
	contentFrame.Visible             = (winCount == 0)
	corner(contentFrame, 8)
	pad(contentFrame, 10, 10, 10, 10)
	listLayout(contentFrame, 8)

	-- Title bar row
	local titleBar = Instance.new("Frame", contentFrame)
	titleBar.Size            = UDim2.new(1, 0, 0, 28)
	titleBar.BackgroundColor3 = THEME.BackgroundLight
	titleBar.BorderSizePixel = 0
	titleBar.LayoutOrder     = -100
	corner(titleBar, 6)

	local titleLbl = makeLabel(titleBar, name, 14, THEME.Accent, FONT)
	titleLbl.Size            = UDim2.new(1, -40, 1, 0)
	titleLbl.Position        = UDim2.new(0, 8, 0, 0)
	titleLbl.TextXAlignment  = Enum.TextXAlignment.Left

	-- Close button
	local closeBtn = Instance.new("TextButton", titleBar)
	closeBtn.Size               = UDim2.new(0, 24, 0, 24)
	closeBtn.Position           = UDim2.new(1, -28, 0.5, -12)
	closeBtn.BackgroundColor3   = Color3.fromRGB(200, 60, 60)
	closeBtn.Text               = "×"
	closeBtn.TextColor3         = THEME.Text
	closeBtn.Font               = FONT
	closeBtn.TextSize           = 16
	closeBtn.BorderSizePixel    = 0
	corner(closeBtn, 4)
	closeBtn.MouseButton1Click:Connect(function()
		contentFrame.Visible = false
	end)

	makeDraggable(contentFrame, titleBar)

	-- Sidebar entry for this window
	local sideBtn = addSidebarButton(sidebar, name, winCount + 1, function()
		for _, win in ipairs(UIlib.__windows) do
			win.Frame.Visible = false
		end
		contentFrame.Visible = true
	end)

	-- If this is the first window, highlight its sidebar button
	if winCount == 0 then
		sideBtn.TextColor3 = THEME.Text
		sideBtn:SetAttribute("Active", true)
	end

	local windowObj = {
		Name     = name,
		Frame    = contentFrame,
		Sidebar  = sidebar,
		Sections = {},
		_order   = winCount,
	}

	table.insert(UIlib.__windows, windowObj)
	return windowObj
end

-- ======================================================
-- SECTION
-- ======================================================
--[[
	UIlib.Section(window, name) -> SectionFrame
]]
function UIlib.Section(window, name)
	local parent = window.Frame

	local container = Instance.new("Frame", parent)
	container.Name             = "Section_" .. name
	container.BackgroundColor3 = THEME.BackgroundLight
	container.BorderSizePixel  = 0
	container.AutomaticSize    = Enum.AutomaticSize.Y
	container.Size             = UDim2.new(1, 0, 0, 0)
	container.LayoutOrder      = 100 + #parent:GetChildren()
	corner(container, 6)
	pad(container, 6, 8, 8, 8)
	listLayout(container, 5)

	-- Section header
	local header = Instance.new("Frame", container)
	header.Size             = UDim2.new(1, 0, 0, 22)
	header.BackgroundColor3 = THEME.SectionHeader
	header.BorderSizePixel  = 0
	header.LayoutOrder      = -1
	corner(header, 4)

	local headerLbl = makeLabel(header, name, 12, THEME.TextDim, FONT)
	headerLbl.Size          = UDim2.new(1, 0, 1, 0)
	headerLbl.Position      = UDim2.new(0, 6, 0, 0)
	headerLbl.TextXAlignment = Enum.TextXAlignment.Left

	-- Separator line
	local sep = Instance.new("Frame", container)
	sep.Size             = UDim2.new(1, 0, 0, 1)
	sep.BackgroundColor3 = THEME.Separator
	sep.BorderSizePixel  = 0
	sep.LayoutOrder      = 0

	window.Sections[name] = container
	return container
end

-- ======================================================
-- CREATEBUTTON
-- ======================================================
--[[
	UIlib.CreateButton(section, name, callback) -> TextButton
	
	Example:
	  local VapeBtn = UIlib.CreateButton(MySection, "Vape V4")
	  VapeBtn.MouseButton1Click:Connect(function()
	      loadstring(game:HttpGet("..."))()
	  end)
	
	Or with inline callback:
	  UIlib.CreateButton(MySection, "Vape V4", function()
	      loadstring(game:HttpGet("..."))()
	  end)
]]
function UIlib.CreateButton(section, name, callback)
	local btn = Instance.new("TextButton", section)
	btn.Name             = name
	btn.Size             = UDim2.new(1, 0, 0, 32)
	btn.BackgroundColor3 = THEME.ButtonBG
	btn.BorderSizePixel  = 0
	btn.Text             = name
	btn.TextColor3       = THEME.Text
	btn.Font             = FONT_BODY
	btn.TextSize         = 13
	btn.LayoutOrder      = #section:GetChildren()
	corner(btn, 5)
	hoverEffect(btn, THEME.ButtonBG, THEME.ButtonHover)

	-- Click flash
	btn.MouseButton1Down:Connect(function()
		tween(btn, {BackgroundColor3 = THEME.Accent}, 0.08)
	end)
	btn.MouseButton1Up:Connect(function()
		tween(btn, {BackgroundColor3 = THEME.ButtonBG}, 0.15)
	end)

	if callback then
		btn.MouseButton1Click:Connect(callback)
	end

	return btn
end

-- ======================================================
-- CREATETOGGLE
-- ======================================================
--[[
	UIlib.CreateToggle(section, name, default, callback) -> { Value, Button, Set }
]]
function UIlib.CreateToggle(section, name, default, callback)
	local state = default == true

	local row = Instance.new("Frame", section)
	row.Size             = UDim2.new(1, 0, 0, 32)
	row.BackgroundTransparency = 1
	row.LayoutOrder      = #section:GetChildren()

	local lbl = makeLabel(row, name, 13, THEME.Text, FONT_BODY)
	lbl.Size  = UDim2.new(1, -52, 1, 0)
	lbl.Position = UDim2.new(0, 0, 0, 0)

	local pill = Instance.new("TextButton", row)
	pill.Size             = UDim2.new(0, 44, 0, 22)
	pill.Position         = UDim2.new(1, -44, 0.5, -11)
	pill.BackgroundColor3 = state and THEME.ToggleOn or THEME.ToggleOff
	pill.BorderSizePixel  = 0
	pill.Text             = ""
	corner(pill, 11)

	local knob = Instance.new("Frame", pill)
	knob.Size             = UDim2.new(0, 16, 0, 16)
	knob.Position         = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
	knob.BackgroundColor3 = THEME.Text
	knob.BorderSizePixel  = 0
	corner(knob, 8)

	local obj = { Value = state }

	local function setState(v)
		state     = v
		obj.Value = v
		tween(pill, {BackgroundColor3 = v and THEME.ToggleOn or THEME.ToggleOff})
		tween(knob, {Position = v and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)})
		if callback then
			callback(v)
		end
	end

	pill.MouseButton1Click:Connect(function()
		setState(not state)
	end)

	obj.Set    = setState
	obj.Button = pill
	return obj
end

-- ======================================================
-- CREATESLIDER
-- ======================================================
--[[
	UIlib.CreateSlider(section, name, min, max, default, callback) -> { Value, Set }
]]
function UIlib.CreateSlider(section, name, min, max, default, callback)
	min     = min or 0
	max     = max or 100
	default = default or min

	local container = Instance.new("Frame", section)
	container.Size             = UDim2.new(1, 0, 0, 48)
	container.BackgroundTransparency = 1
	container.LayoutOrder      = #section:GetChildren()

	local lbl = makeLabel(container, name, 12, THEME.TextDim, FONT_BODY)
	lbl.Size     = UDim2.new(1, -50, 0, 18)
	lbl.Position = UDim2.new(0, 0, 0, 0)

	local valLbl = makeLabel(container, tostring(default), 12, THEME.Accent, FONT)
	valLbl.Size          = UDim2.new(0, 48, 0, 18)
	valLbl.Position      = UDim2.new(1, -48, 0, 0)
	valLbl.TextXAlignment = Enum.TextXAlignment.Right

	local track = Instance.new("Frame", container)
	track.Size             = UDim2.new(1, 0, 0, 8)
	track.Position         = UDim2.new(0, 0, 0, 24)
	track.BackgroundColor3 = THEME.SliderBG
	track.BorderSizePixel  = 0
	corner(track, 4)

	local fill = Instance.new("Frame", track)
	fill.Size             = UDim2.new((default - min) / (max - min), 0, 1, 0)
	fill.BackgroundColor3 = THEME.SliderFill
	fill.BorderSizePixel  = 0
	corner(fill, 4)

	local thumb = Instance.new("Frame", track)
	thumb.Size             = UDim2.new(0, 14, 0, 14)
	thumb.AnchorPoint      = Vector2.new(0.5, 0.5)
	thumb.Position         = UDim2.new((default - min) / (max - min), 0, 0.5, 0)
	thumb.BackgroundColor3 = THEME.Text
	thumb.BorderSizePixel  = 0
	corner(thumb, 7)

	local obj = { Value = default }
	local dragging = false

	local function update(inputX)
		local relX = math.clamp(
			(inputX - track.AbsolutePosition.X) / track.AbsoluteSize.X,
			0, 1
		)
		local val = math.floor(min + relX * (max - min) + 0.5)
		obj.Value = val
		valLbl.Text = tostring(val)
		fill.Size   = UDim2.new(relX, 0, 1, 0)
		thumb.Position = UDim2.new(relX, 0, 0.5, 0)
		if callback then callback(val) end
	end

	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			update(input.Position.X)
		end
	end)

	UIS.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			update(input.Position.X)
		end
	end)

	UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)

	obj.Set = function(v)
		v = math.clamp(v, min, max)
		obj.Value = v
		local relX = (v - min) / (max - min)
		valLbl.Text    = tostring(v)
		fill.Size      = UDim2.new(relX, 0, 1, 0)
		thumb.Position = UDim2.new(relX, 0, 0.5, 0)
		if callback then callback(v) end
	end

	return obj
end

-- ======================================================
-- CREATEDROPDOWN
-- ======================================================
--[[
	UIlib.CreateDropdown(section, name, options, callback) -> { Value, Set }
]]
function UIlib.CreateDropdown(section, name, options, callback)
	options = options or {}

	local selected  = options[1] or ""
	local isOpen    = false

	local wrapper = Instance.new("Frame", section)
	wrapper.Size             = UDim2.new(1, 0, 0, 32)
	wrapper.BackgroundTransparency = 1
	wrapper.LayoutOrder      = #section:GetChildren()
	wrapper.ClipsDescendants = false
	wrapper.ZIndex           = 10

	local btn = Instance.new("TextButton", wrapper)
	btn.Size             = UDim2.new(1, 0, 0, 32)
	btn.BackgroundColor3 = THEME.ButtonBG
	btn.BorderSizePixel  = 0
	btn.Text             = name .. ": " .. selected
	btn.TextColor3       = THEME.Text
	btn.Font             = FONT_BODY
	btn.TextSize         = 13
	btn.ZIndex           = 10
	corner(btn, 5)

	local dropFrame = Instance.new("Frame", wrapper)
	dropFrame.Size             = UDim2.new(1, 0, 0, 0)
	dropFrame.Position         = UDim2.new(0, 0, 1, 4)
	dropFrame.BackgroundColor3 = THEME.BackgroundLight
	dropFrame.BorderSizePixel  = 0
	dropFrame.Visible          = false
	dropFrame.ZIndex           = 20
	dropFrame.ClipsDescendants = true
	corner(dropFrame, 5)
	listLayout(dropFrame, 2)
	pad(dropFrame, 4, 4, 4, 4)

	local obj = { Value = selected }

	local function setSelected(v)
		selected    = v
		obj.Value   = v
		btn.Text    = name .. ": " .. v
		isOpen      = false
		dropFrame.Visible = false
		tween(dropFrame, {Size = UDim2.new(1, 0, 0, 0)}, 0.15)
		if callback then callback(v) end
	end

	local function buildOptions()
		for _, child in ipairs(dropFrame:GetChildren()) do
			if child:IsA("TextButton") then child:Destroy() end
		end
		for _, opt in ipairs(options) do
			local optBtn = Instance.new("TextButton", dropFrame)
			optBtn.Size             = UDim2.new(1, 0, 0, 26)
			optBtn.BackgroundColor3 = THEME.SideBarBtn
			optBtn.BorderSizePixel  = 0
			optBtn.Text             = opt
			optBtn.TextColor3       = THEME.Text
			optBtn.Font             = FONT_BODY
			optBtn.TextSize         = 12
			optBtn.ZIndex           = 25
			corner(optBtn, 4)
			hoverEffect(optBtn, THEME.SideBarBtn, THEME.SideBarBtnActive)
			optBtn.MouseButton1Click:Connect(function()
				setSelected(opt)
			end)
		end
	end

	buildOptions()

	btn.MouseButton1Click:Connect(function()
		isOpen = not isOpen
		if isOpen then
			dropFrame.Visible = true
			local h = math.min(#options, 5) * 30 + 8
			tween(dropFrame, {Size = UDim2.new(1, 0, 0, h)}, 0.15)
		else
			tween(dropFrame, {Size = UDim2.new(1, 0, 0, 0)}, 0.15)
			task.delay(0.15, function()
				dropFrame.Visible = false
			end)
		end
	end)

	obj.Set     = setSelected
	obj.Refresh = function(newOptions)
		options = newOptions
		buildOptions()
	end

	return obj
end

-- ======================================================
-- CREATETEXTBOX
-- ======================================================
--[[
	UIlib.CreateTextbox(section, name, placeholder, callback) -> TextBox
]]
function UIlib.CreateTextbox(section, name, placeholder, callback)
	local container = Instance.new("Frame", section)
	container.Size             = UDim2.new(1, 0, 0, 50)
	container.BackgroundTransparency = 1
	container.LayoutOrder      = #section:GetChildren()

	local lbl = makeLabel(container, name, 12, THEME.TextDim, FONT_BODY)
	lbl.Size     = UDim2.new(1, 0, 0, 18)
	lbl.Position = UDim2.new(0, 0, 0, 0)

	local box = Instance.new("TextBox", container)
	box.Size             = UDim2.new(1, 0, 0, 28)
	box.Position         = UDim2.new(0, 0, 0, 20)
	box.BackgroundColor3 = THEME.BackgroundLight
	box.BorderSizePixel  = 0
	box.Text             = ""
	box.PlaceholderText  = placeholder or "Enter text..."
	box.TextColor3       = THEME.Text
	box.PlaceholderColor3 = THEME.TextDim
	box.Font             = FONT_BODY
	box.TextSize         = 13
	box.ClearTextOnFocus = false
	corner(box, 5)
	pad(box, 0, 0, 6, 6)

	if callback then
		box.FocusLost:Connect(function(enter)
			callback(box.Text, enter)
		end)
	end

	return box
end

-- ======================================================
-- CREATELABEL
-- ======================================================
function UIlib.CreateLabel(section, text)
	local lbl = makeLabel(section, text, 13, THEME.TextDim, FONT_BODY)
	lbl.Size        = UDim2.new(1, 0, 0, 0)
	lbl.LayoutOrder = #section:GetChildren()
	return lbl
end

-- ======================================================
-- CREATESEPARATOR
-- ======================================================
function UIlib.CreateSeparator(section)
	local sep = Instance.new("Frame", section)
	sep.Size             = UDim2.new(1, 0, 0, 1)
	sep.BackgroundColor3 = THEME.Separator
	sep.BorderSizePixel  = 0
	sep.LayoutOrder      = #section:GetChildren()
	return sep
end

-- ======================================================
-- ADDSETTING (for the Settings window)
-- ======================================================
--[[
	UIlib.AddSetting(settingsWindow, name, settingType, ...)
	
	settingType options:
	  "toggle"    -> ...(default, callback)
	  "slider"    -> ...(min, max, default, callback)
	  "dropdown"  -> ...(options, callback)
	  "textbox"   -> ...(placeholder, callback)
	  "button"    -> ...(callback)
	  "label"     -> ...(text)
]]
function UIlib.AddSetting(settingsWindow, name, settingType, ...)
	local section = settingsWindow.Sections["Settings"]
	if not section then
		section = UIlib.Section(settingsWindow, "Settings")
	end

	local args = {...}

	if settingType == "toggle" then
		return UIlib.CreateToggle(section, name, args[1], args[2])
	elseif settingType == "slider" then
		return UIlib.CreateSlider(section, name, args[1], args[2], args[3], args[4])
	elseif settingType == "dropdown" then
		return UIlib.CreateDropdown(section, name, args[1], args[2])
	elseif settingType == "textbox" then
		return UIlib.CreateTextbox(section, name, args[1], args[2])
	elseif settingType == "button" then
		return UIlib.CreateButton(section, name, args[1])
	elseif settingType == "label" then
		return UIlib.CreateLabel(section, args[1] or name)
	end
end

-- ======================================================
-- NOTIFY
-- ======================================================
--[[
	UIlib.Notify(title, body, duration)
]]
function UIlib.Notify(title, body, duration)
	duration = duration or 3
	local sg = getScreenGui()

	local notif = Instance.new("Frame", sg)
	notif.Size             = UDim2.new(0, 260, 0, 0)
	notif.Position         = UDim2.new(1, -270, 1, -10)
	notif.AnchorPoint      = Vector2.new(0, 1)
	notif.BackgroundColor3 = THEME.NotifyBG
	notif.BorderSizePixel  = 0
	notif.AutomaticSize    = Enum.AutomaticSize.Y
	notif.ZIndex           = 100
	corner(notif, 8)
	pad(notif, 8, 10, 10, 10)
	listLayout(notif, 4)

	local accent = Instance.new("Frame", notif)
	accent.Size             = UDim2.new(0, 3, 1, 0)
	accent.Position         = UDim2.new(0, 0, 0, 0)
	accent.BackgroundColor3 = THEME.Accent
	accent.BorderSizePixel  = 0

	local titleLbl = makeLabel(notif, title, 14, THEME.Text, FONT)
	titleLbl.LayoutOrder = 1

	local bodyLbl = makeLabel(notif, body, 12, THEME.TextDim, FONT_BODY)
	bodyLbl.LayoutOrder = 2

	-- Animate in
	notif.Position = UDim2.new(1, 10, 1, -10)
	tween(notif, {Position = UDim2.new(1, -270, 1, -10)}, 0.3)

	-- Animate out
	task.delay(duration, function()
		tween(notif, {Position = UDim2.new(1, 10, 1, -10)}, 0.3)
		task.delay(0.35, function()
			notif:Destroy()
		end)
	end)
end

-- ======================================================
-- SETTHEME
-- ======================================================
function UIlib.SetTheme(colorTable)
	for k, v in pairs(colorTable) do
		THEME[k] = v
	end
end

-- ======================================================
-- DESTROY
-- ======================================================
function UIlib.Destroy()
	if UIlib.__screenGui then
		UIlib.__screenGui:Destroy()
		UIlib.__screenGui = nil
	end
	UIlib.__windows = {}
end

-- ======================================================
-- TOGGLE KEYBIND (Alt + RightShift)
-- ======================================================
UIS.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.RightShift and UIS:IsKeyDown(Enum.KeyCode.LeftAlt) then
		local sg = UIlib.__screenGui
		if sg then
			sg.Enabled = not sg.Enabled
		end
	end
end)

return UIlib
