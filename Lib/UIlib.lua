--[[
╔══════════════════════════════════════════════════════════════════╗
║                  TKLib  ·  UIlib.lua  ·  v2.1                    ║
║                       Roblox UI Lib                              ║
╚══════════════════════════════════════════════════════════════════╝

  UIlib.MainWindow(name)                               → WindowObj
  UIlib.Section(window, name)                          → Frame
  UIlib.CreateButton(section, name [,callback])        → TextButton
  UIlib.CreateToggle(section, name, default, cb)       → ToggleObj
  UIlib.CreateSlider(section, name, min, max, def, cb) → SliderObj
  UIlib.CreateDropdown(section, name, options, cb)     → DropdownObj
  UIlib.CreateTextbox(section, name, placeholder, cb)  → TextBox
  UIlib.CreateLabel(section, text)                     → TextLabel
  UIlib.CreateSeparator(section)                       → Frame
  UIlib.AddSetting(window, name, type, ...)            → element
  UIlib.Notify(title, body [, duration])
  UIlib.SetTheme(colorTable)
  UIlib.SetOpacity(0‑1)
  UIlib.OpenColorEditor(label, currentColor, onDone)
  UIlib.Destroy()
  UIlib.THEME  (read/write theme table)
]]

-- ─────────────────────────────────────────────────────────────────
-- SERVICES
-- ─────────────────────────────────────────────────────────────────
local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS          = game:GetService("UserInputService")

local Player    = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui")

-- ─────────────────────────────────────────────────────────────────
-- MODULE
-- ─────────────────────────────────────────────────────────────────
local UIlib           = {}
UIlib.__windows       = {}
UIlib.__screenGui     = nil
UIlib.__notifyStack   = {}   -- {frame, cachedH}
UIlib.__opacity       = 1    -- current global opacity (0‑1)

-- ─────────────────────────────────────────────────────────────────
-- DEFAULT THEME
-- ─────────────────────────────────────────────────────────────────
local THEME = {
	Background       = Color3.fromRGB(27,  27,  27),
	BackgroundLight  = Color3.fromRGB(50,  50,  50),
	SideBar          = Color3.fromRGB(35,  35,  35),
	SideBarBtn       = Color3.fromRGB(45,  45,  45),
	SideBarBtnActive = Color3.fromRGB(60,  60,  60),
	Accent           = Color3.fromRGB(255, 255, 255),
	Text             = Color3.fromRGB(255, 255, 255),
	TextDim          = Color3.fromRGB(150, 150, 150),
	ButtonBG         = Color3.fromRGB(60,  60,  60),
	ButtonHover      = Color3.fromRGB(80,  80,  80),
	ToggleOff        = Color3.fromRGB(80,  80,  80),
	ToggleOn         = Color3.fromRGB(119, 119, 119),
	SliderBG         = Color3.fromRGB(50,  50,  50),
	SliderFill       = Color3.fromRGB(255, 255, 255),
	SectionHeader    = Color3.fromRGB(40,  40,  40),
	Separator        = Color3.fromRGB(60,  60,  60),
	NotifyBG         = Color3.fromRGB(35,  35,  35),
}
UIlib.THEME = THEME

local FONT      = Enum.Font.GothamSemibold
local FONT_BODY = Enum.Font.Gotham

-- ─────────────────────────────────────────────────────────────────
-- HELPERS
-- ─────────────────────────────────────────────────────────────────
local function tw(obj, props, t, style, dir)
	pcall(function()
		TweenService:Create(obj,
			TweenInfo.new(t or 0.18, style or Enum.EasingStyle.Quad,
				dir or Enum.EasingDirection.Out), props):Play()
	end)
end

local function mkCorner(p, r)
	local c = Instance.new("UICorner", p)
	c.CornerRadius = UDim.new(0, r or 6)
	return c
end

local function mkPad(p, t, b, l, r)
	local pad = Instance.new("UIPadding", p)
	pad.PaddingTop    = UDim.new(0, t or 6)
	pad.PaddingBottom = UDim.new(0, b or 6)
	pad.PaddingLeft   = UDim.new(0, l or 8)
	pad.PaddingRight  = UDim.new(0, r or 8)
end

local function mkList(p, sp, dir)
	local l = Instance.new("UIListLayout", p)
	l.Padding             = UDim.new(0, sp or 6)
	l.FillDirection       = dir or Enum.FillDirection.Vertical
	l.HorizontalAlignment = Enum.HorizontalAlignment.Left
	l.VerticalAlignment   = Enum.VerticalAlignment.Top
	l.SortOrder           = Enum.SortOrder.LayoutOrder
	return l
end

local function mkLabel(p, txt, sz, col, fnt, xAlign)
	local l = Instance.new("TextLabel", p)
	l.BackgroundTransparency = 1
	l.Text           = txt   or ""
	l.TextSize       = sz    or 13
	l.TextColor3     = col   or THEME.Text
	l.Font           = fnt   or FONT_BODY
	l.TextXAlignment = xAlign or Enum.TextXAlignment.Left
	l.Size           = UDim2.new(1, 0, 0, (sz or 13) + 6)
	l.AutomaticSize  = Enum.AutomaticSize.Y
	l.TextWrapped    = true
	return l
end

local function hoverFX(btn, norm, hov)
	btn.MouseEnter:Connect(function() tw(btn, {BackgroundColor3 = hov}) end)
	btn.MouseLeave:Connect(function() tw(btn, {BackgroundColor3 = norm}) end)
end

-- ─────────────────────────────────────────────────────────────────
-- HSV ↔ RGB  (used by color editor)
-- ─────────────────────────────────────────────────────────────────
local function hsvToRgb(h, s, v)
	h = h % 1
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t2 = v*(1-s), v*(1-f*s), v*(1-(1-f)*s)
	local combos = {{v,t2,p},{q,v,p},{p,v,t2},{p,q,v},{t2,p,v},{v,p,q}}
	local c = combos[(i % 6)+1]
	return Color3.new(c[1], c[2], c[3])
end

local function rgbToHsv(c)
	local r, g, b = c.R, c.G, c.B
	local mx, mn = math.max(r,g,b), math.min(r,g,b)
	local d = mx - mn
	local h, s, v = 0, 0, mx
	if mx ~= 0 then s = d/mx end
	if d ~= 0 then
		if     mx == r then h = (g-b)/d % 6
		elseif mx == g then h = (b-r)/d + 2
		else               h = (r-g)/d + 4 end
		h = h / 6
	end
	return h, s, v
end

-- ─────────────────────────────────────────────────────────────────
-- DRAG  (attaches drag to any frame via a handle)
-- ─────────────────────────────────────────────────────────────────
local function makeDraggable(frame, handle)
	handle = handle or frame
	local drag, dragInput, mStart, fStart

	handle.InputBegan:Connect(function(inp)
		if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		drag = true; mStart = inp.Position; fStart = frame.Position
		inp.Changed:Connect(function()
			if inp.UserInputState == Enum.UserInputState.End then drag = false end
		end)
	end)
	handle.InputChanged:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseMovement then dragInput = inp end
	end)
	UIS.InputChanged:Connect(function(inp)
		if drag and inp == dragInput then
			local d = inp.Position - mStart
			frame.Position = UDim2.new(fStart.X.Scale, fStart.X.Offset+d.X,
				fStart.Y.Scale, fStart.Y.Offset+d.Y)
		end
	end)
end

-- ─────────────────────────────────────────────────────────────────
-- ROOT SCREENGUI
-- ─────────────────────────────────────────────────────────────────
local function getSG()
	if UIlib.__screenGui and UIlib.__screenGui.Parent then
		return UIlib.__screenGui
	end
	local sg = Instance.new("ScreenGui", PlayerGui)
	sg.Name           = "TKLib"
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.ResetOnSpawn   = false
	UIlib.__screenGui = sg
	return sg
end

-- ─────────────────────────────────────────────────────────────────
-- NOTIFICATION  (bottom-right stack, correct anchoring)
-- ─────────────────────────────────────────────────────────────────
local NOTIF_W   = 260
local NOTIF_R   = 14    -- gap from right edge
local NOTIF_BOT = 14    -- gap from bottom edge
local NOTIF_GAP = 6     -- gap between stacked notifications

-- Reposition all live notifications from bottom up
local function restack()
	local stack = UIlib.__notifyStack
	-- Remove dead entries
	for i = #stack, 1, -1 do
		if not (stack[i].f and stack[i].f.Parent) then
			table.remove(stack, i)
		end
	end
	local y = NOTIF_BOT
	for i = #stack, 1, -1 do
		local entry = stack[i]
		local h = entry.h or 70
		-- AnchorPoint (1,1) + Position (1,-R, 1,-(y+h))  means:
		--   right edge is NOTIF_R px from screen right
		--   bottom edge is (y+h) px from screen bottom
		tw(entry.f, {
			Position = UDim2.new(1, -(NOTIF_R + NOTIF_W), 1, -(y + h))
		}, 0.18)
		y = y + h + NOTIF_GAP
	end
end

function UIlib.Notify(title, body, duration)
	duration = duration or 3
	local sg = getSG()

	local n = Instance.new("Frame", sg)
	n.Name             = "TKNotif"
	n.Size             = UDim2.new(0, NOTIF_W, 0, 10)
	-- Start: off-screen to the right, anchored bottom-left of frame
	n.AnchorPoint      = Vector2.new(0, 1)
	n.Position         = UDim2.new(1, NOTIF_R, 1, -NOTIF_BOT)
	n.BackgroundColor3 = THEME.NotifyBG
	n.BorderSizePixel  = 0
	n.AutomaticSize    = Enum.AutomaticSize.Y
	n.ZIndex           = 200
	mkCorner(n, 8)
	mkPad(n, 10, 12, 14, 12)
	mkList(n, 4)

	-- Accent bar (left edge)
	local bar = Instance.new("Frame", n)
	bar.Size = UDim2.new(0, 3, 1, 0); bar.Position = UDim2.new(0, 0, 0, 0)
	bar.BackgroundColor3 = THEME.Accent; bar.BorderSizePixel = 0; bar.ZIndex = 201

	local tl = mkLabel(n, title, 13, THEME.Text, FONT)
	tl.LayoutOrder = 1; tl.ZIndex = 201

	local bl = mkLabel(n, body, 12, THEME.TextDim, FONT_BODY)
	bl.LayoutOrder = 2; bl.ZIndex = 201

	-- Wait one frame for AutomaticSize to resolve
	task.wait()
	local h = n.AbsoluteSize.Y
	if h < 20 then h = 68 end

	local entry = {f = n, h = h}
	table.insert(UIlib.__notifyStack, entry)
	restack()

	-- Auto dismiss
	task.delay(duration, function()
		for i, e in ipairs(UIlib.__notifyStack) do
			if e == entry then table.remove(UIlib.__notifyStack, i); break end
		end
		-- Slide off-screen to the right
		tw(n, {Position = UDim2.new(1, NOTIF_R, n.Position.Y.Scale, n.Position.Y.Offset)}, 0.2)
		task.delay(0.22, function()
			pcall(n.Destroy, n)
			restack()
		end)
	end)
end

-- ─────────────────────────────────────────────────────────────────
-- SIDEBAR
-- ─────────────────────────────────────────────────────────────────
local function buildSidebar(sg)
	local sb = Instance.new("Frame", sg)
	sb.Name             = "TKLibSidebar"
	sb.Size             = UDim2.new(0, 118, 0, 0)
	sb.Position         = UDim2.new(0, 18, 0.5, 0)
	sb.AnchorPoint      = Vector2.new(0, 0.5)
	sb.BackgroundColor3 = THEME.SideBar
	sb.BorderSizePixel  = 0
	sb.AutomaticSize    = Enum.AutomaticSize.Y
	sb.ZIndex           = 5
	mkCorner(sb, 8)
	mkPad(sb, 8, 8, 6, 6)
	mkList(sb, 4)

	local logo = Instance.new("TextLabel", sb)
	logo.Size = UDim2.new(1, 0, 0, 26)
	logo.BackgroundTransparency = 1
	logo.Text        = "TKHub"
	logo.TextColor3  = THEME.Accent
	logo.Font        = FONT
	logo.TextSize    = 15
	logo.TextXAlignment = Enum.TextXAlignment.Center
	logo.LayoutOrder = -10; logo.ZIndex = 6

	local div = Instance.new("Frame", sb)
	div.Size             = UDim2.new(1, 0, 0, 1)
	div.BackgroundColor3 = THEME.Separator
	div.BorderSizePixel  = 0
	div.LayoutOrder      = -9
	return sb
end

local function addSideBtn(sb, name, order, onClick)
	local btn = Instance.new("TextButton", sb)
	btn.Name             = "SideBtn_"..name
	btn.Size             = UDim2.new(1, 0, 0, 28)
	btn.BackgroundColor3 = THEME.SideBarBtn
	btn.BorderSizePixel  = 0
	btn.Text             = name
	btn.TextColor3       = THEME.TextDim
	btn.Font             = FONT_BODY
	btn.TextSize         = 12
	btn.TextTruncate     = Enum.TextTruncate.AtEnd
	btn.LayoutOrder      = order
	btn.ZIndex           = 6
	mkCorner(btn, 5)
	hoverFX(btn, THEME.SideBarBtn, THEME.SideBarBtnActive)

	btn.MouseButton1Click:Connect(function()
		for _, c in ipairs(sb:GetChildren()) do
			if c:IsA("TextButton") then
				c.TextColor3 = THEME.TextDim
				tw(c, {BackgroundColor3 = THEME.SideBarBtn})
			end
		end
		btn.TextColor3 = THEME.Text
		tw(btn, {BackgroundColor3 = THEME.SideBarBtnActive})
		onClick()
	end)
	return btn
end

-- ─────────────────────────────────────────────────────────────────
-- MAINWINDOW
-- ─────────────────────────────────────────────────────────────────
function UIlib.MainWindow(name)
	local sg  = getSG()
	local idx = #UIlib.__windows

	local sb = sg:FindFirstChild("TKLibSidebar") or buildSidebar(sg)
	if not sb.Parent then sb.Parent = sg end

	-- Outer scrolling frame (the actual window panel)
	local cf = Instance.new("ScrollingFrame", sg)
	cf.Name                = "TKWin_"..name
	cf.Size                = UDim2.new(0, 430, 0, 500)
	cf.Position            = UDim2.new(0, 148, 0.5, 0)
	cf.AnchorPoint         = Vector2.new(0, 0.5)
	cf.BackgroundColor3    = THEME.Background
	cf.BorderSizePixel     = 0
	cf.ScrollBarThickness  = 4
	cf.ScrollBarImageColor3 = THEME.Accent
	cf.AutomaticCanvasSize = Enum.AutomaticSize.Y
	cf.CanvasSize          = UDim2.new(0, 0, 0, 0)
	cf.Visible             = (idx == 0)
	cf.ClipsDescendants    = true
	cf.ZIndex              = 10
	mkCorner(cf, 8)

	-- Inner layout frame (content host)
	local inner = Instance.new("Frame", cf)
	inner.Name             = "Inner"
	inner.Size             = UDim2.new(1, -10, 0, 0)
	inner.BackgroundTransparency = 1
	inner.AutomaticSize    = Enum.AutomaticSize.Y
	mkPad(inner, 10, 14, 10, 6)
	mkList(inner, 8)

	-- Title bar (drag handle)
	local tbar = Instance.new("Frame", inner)
	tbar.Size             = UDim2.new(1, 0, 0, 30)
	tbar.BackgroundColor3 = THEME.BackgroundLight
	tbar.BorderSizePixel  = 0
	tbar.LayoutOrder      = -100
	tbar.ZIndex           = 11
	mkCorner(tbar, 6)
	makeDraggable(cf, tbar)

	local tlbl = mkLabel(tbar, name, 14, THEME.Accent, FONT)
	tlbl.Size = UDim2.new(1, -38, 1, 0); tlbl.Position = UDim2.new(0, 8, 0, 0); tlbl.ZIndex = 12

	local xbtn = Instance.new("TextButton", tbar)
	xbtn.Size             = UDim2.new(0, 22, 0, 22)
	xbtn.Position         = UDim2.new(1, -26, 0.5, -11)
	xbtn.BackgroundColor3 = Color3.fromRGB(170, 50, 50)
	xbtn.Text = "×"; xbtn.TextColor3 = THEME.Text
	xbtn.Font = FONT; xbtn.TextSize = 15
	xbtn.BorderSizePixel = 0; xbtn.ZIndex = 12
	mkCorner(xbtn, 4)
	xbtn.MouseButton1Click:Connect(function() cf.Visible = false end)

	-- Sidebar button
	local sideBtn = addSideBtn(sb, name, idx + 1, function()
		for _, w in ipairs(UIlib.__windows) do w.Frame.Visible = false end
		cf.Visible = true
	end)
	if idx == 0 then
		sideBtn.TextColor3 = THEME.Text
		tw(sideBtn, {BackgroundColor3 = THEME.SideBarBtnActive})
	end

	local wObj = {
		Name = name, Frame = cf, Inner = inner,
		Sidebar = sb, Sections = {}, _idx = idx,
	}
	table.insert(UIlib.__windows, wObj)
	return wObj
end

-- ─────────────────────────────────────────────────────────────────
-- SECTION
-- ─────────────────────────────────────────────────────────────────
function UIlib.Section(window, name)
	local p = window.Inner

	local box = Instance.new("Frame", p)
	box.Name             = "Sec_"..name
	box.BackgroundColor3 = THEME.BackgroundLight
	box.BorderSizePixel  = 0
	box.AutomaticSize    = Enum.AutomaticSize.Y
	box.Size             = UDim2.new(1, 0, 0, 0)
	box.LayoutOrder      = 50 + #p:GetChildren()
	box.ZIndex           = 11
	mkCorner(box, 6)
	mkPad(box, 4, 10, 8, 8)
	mkList(box, 5)

	local hdr = Instance.new("Frame", box)
	hdr.Size             = UDim2.new(1, 0, 0, 20)
	hdr.BackgroundColor3 = THEME.SectionHeader
	hdr.BorderSizePixel  = 0; hdr.LayoutOrder = -1; hdr.ZIndex = 12
	mkCorner(hdr, 4)
	local hl = mkLabel(hdr, name, 11, THEME.TextDim, FONT)
	hl.Position = UDim2.new(0, 6, 0, 0); hl.Size = UDim2.new(1,-6,1,0); hl.ZIndex = 13

	local div = Instance.new("Frame", box)
	div.Size             = UDim2.new(1, 0, 0, 1)
	div.BackgroundColor3 = THEME.Separator
	div.BorderSizePixel  = 0; div.LayoutOrder = 0

	window.Sections[name] = box
	return box
end

-- ─────────────────────────────────────────────────────────────────
-- CREATEBUTTON
-- ─────────────────────────────────────────────────────────────────
function UIlib.CreateButton(section, name, callback)
	local btn = Instance.new("TextButton", section)
	btn.Name             = name
	btn.Size             = UDim2.new(1, 0, 0, 32)
	btn.BackgroundColor3 = THEME.ButtonBG
	btn.BorderSizePixel  = 0
	btn.Text             = name
	btn.TextColor3       = THEME.Text
	btn.Font             = FONT_BODY; btn.TextSize = 13
	btn.LayoutOrder      = #section:GetChildren()
	btn.ZIndex           = 12
	mkCorner(btn, 5)
	hoverFX(btn, THEME.ButtonBG, THEME.ButtonHover)
	btn.MouseButton1Down:Connect(function() tw(btn, {BackgroundColor3 = THEME.Accent}, 0.06) end)
	btn.MouseButton1Up:Connect(function()   tw(btn, {BackgroundColor3 = THEME.ButtonBG},  0.14) end)
	if callback then btn.MouseButton1Click:Connect(callback) end
	return btn
end

-- ─────────────────────────────────────────────────────────────────
-- CREATETOGGLE
-- ─────────────────────────────────────────────────────────────────
function UIlib.CreateToggle(section, name, default, callback)
	local state = (default == true)

	local row = Instance.new("Frame", section)
	row.Size = UDim2.new(1, 0, 0, 32)
	row.BackgroundTransparency = 1
	row.LayoutOrder = #section:GetChildren(); row.ZIndex = 12

	local lbl = mkLabel(row, name, 13, THEME.Text, FONT_BODY)
	lbl.Size = UDim2.new(1,-56,1,0); lbl.Position = UDim2.new(0,0,0,0); lbl.ZIndex = 13

	local pill = Instance.new("TextButton", row)
	pill.Size             = UDim2.new(0, 44, 0, 22)
	pill.Position         = UDim2.new(1, -44, 0.5, -11)
	pill.BackgroundColor3 = state and THEME.ToggleOn or THEME.ToggleOff
	pill.BorderSizePixel  = 0; pill.Text = ""; pill.ZIndex = 13
	mkCorner(pill, 11)

	local knob = Instance.new("Frame", pill)
	knob.Size             = UDim2.new(0, 16, 0, 16)
	knob.Position         = state and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8)
	knob.BackgroundColor3 = THEME.Text; knob.BorderSizePixel = 0; knob.ZIndex = 14
	mkCorner(knob, 8)

	local obj = {Value = state}
	local function set(v)
		state = v; obj.Value = v
		tw(pill, {BackgroundColor3 = v and THEME.ToggleOn or THEME.ToggleOff})
		tw(knob, {Position = v and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8)})
		if callback then callback(v) end
	end
	pill.MouseButton1Click:Connect(function() set(not state) end)
	obj.Set = set; obj.Button = pill
	return obj
end

-- ─────────────────────────────────────────────────────────────────
-- CREATESLIDER
-- ─────────────────────────────────────────────────────────────────
function UIlib.CreateSlider(section, name, minV, maxV, default, callback)
	minV = minV or 0; maxV = maxV or 100
	default = math.clamp(default or minV, minV, maxV)

	local ctn = Instance.new("Frame", section)
	ctn.Size = UDim2.new(1, 0, 0, 52)
	ctn.BackgroundTransparency = 1
	ctn.LayoutOrder = #section:GetChildren(); ctn.ZIndex = 12

	local lbl = mkLabel(ctn, name, 12, THEME.TextDim, FONT_BODY)
	lbl.Size = UDim2.new(1,-56,0,18); lbl.Position = UDim2.new(0,0,0,0); lbl.ZIndex = 13

	local vLbl = mkLabel(ctn, tostring(default), 12, THEME.Accent, FONT)
	vLbl.Size = UDim2.new(0,54,0,18); vLbl.Position = UDim2.new(1,-54,0,0)
	vLbl.TextXAlignment = Enum.TextXAlignment.Right; vLbl.ZIndex = 13

	local track = Instance.new("Frame", ctn)
	track.Size = UDim2.new(1,0,0,8); track.Position = UDim2.new(0,0,0,28)
	track.BackgroundColor3 = THEME.SliderBG; track.BorderSizePixel = 0; track.ZIndex = 12
	mkCorner(track, 4)

	local fill = Instance.new("Frame", track)
	fill.Size = UDim2.new((default-minV)/(maxV-minV),0,1,0)
	fill.BackgroundColor3 = THEME.SliderFill; fill.BorderSizePixel = 0; fill.ZIndex = 13
	mkCorner(fill, 4)

	local thumb = Instance.new("Frame", track)
	thumb.Size = UDim2.new(0,14,0,14); thumb.AnchorPoint = Vector2.new(0.5,0.5)
	thumb.Position = UDim2.new((default-minV)/(maxV-minV),0,0.5,0)
	thumb.BackgroundColor3 = THEME.Text; thumb.BorderSizePixel = 0; thumb.ZIndex = 14
	mkCorner(thumb, 7)

	local obj = {Value = default}
	local dragging = false

	local function upd(x)
		local rel = math.clamp((x - track.AbsolutePosition.X)/math.max(track.AbsoluteSize.X,1),0,1)
		local val = math.floor(minV + rel*(maxV-minV) + 0.5)
		obj.Value = val; vLbl.Text = tostring(val)
		fill.Size = UDim2.new(rel,0,1,0); thumb.Position = UDim2.new(rel,0,0.5,0)
		if callback then callback(val) end
	end

	track.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; upd(inp.Position.X) end
	end)
	UIS.InputChanged:Connect(function(inp)
		if dragging and inp.UserInputType == Enum.UserInputType.MouseMovement then upd(inp.Position.X) end
	end)
	UIS.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
	end)

	obj.Set = function(v)
		v = math.clamp(v, minV, maxV); obj.Value = v
		local rel = (v-minV)/(maxV-minV)
		vLbl.Text = tostring(v)
		fill.Size = UDim2.new(rel,0,1,0); thumb.Position = UDim2.new(rel,0,0.5,0)
		if callback then callback(v) end
	end
	return obj
end

-- ─────────────────────────────────────────────────────────────────
-- CREATEDROPDOWN  (list parented to ScreenGui root – never overlaps)
-- ─────────────────────────────────────────────────────────────────
function UIlib.CreateDropdown(section, name, options, callback)
	options  = options or {}
	local selected = options[1] or ""
	local isOpen   = false

	-- Placeholder in section layout
	local wrapper = Instance.new("Frame", section)
	wrapper.Name = "DD_"..name
	wrapper.Size = UDim2.new(1,0,0,32)
	wrapper.BackgroundTransparency = 1
	wrapper.LayoutOrder = #section:GetChildren(); wrapper.ZIndex = 12

	local btn = Instance.new("TextButton", wrapper)
	btn.Size = UDim2.new(1,0,1,0)
	btn.BackgroundColor3 = THEME.ButtonBG; btn.BorderSizePixel = 0
	btn.Text = name..":  "..selected.."  ▾"
	btn.TextColor3 = THEME.Text; btn.Font = FONT_BODY; btn.TextSize = 13; btn.ZIndex = 12
	mkCorner(btn, 5)
	hoverFX(btn, THEME.ButtonBG, THEME.ButtonHover)

	-- List lives at ScreenGui root so it always renders on top
	local sg = getSG()
	local list = Instance.new("ScrollingFrame", sg)
	list.Name = "TKDrop_"..name
	list.Size = UDim2.new(0,100,0,0)
	list.Position = UDim2.new(0,0,0,0)
	list.BackgroundColor3 = THEME.BackgroundLight
	list.BorderSizePixel = 0; list.Visible = false; list.ZIndex = 100
	list.ScrollBarThickness = 3; list.ScrollBarImageColor3 = THEME.Accent
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new(0,0,0,0); list.ClipsDescendants = true
	mkCorner(list, 6); mkPad(list, 4,4,4,4); mkList(list, 2)

	local obj = {Value = selected}

	local function close()
		isOpen = false
		tw(list, {Size = UDim2.new(0, list.AbsoluteSize.X, 0, 0)}, 0.14)
		task.delay(0.15, function() list.Visible = false end)
	end

	local function pick(v)
		selected = v; obj.Value = v
		btn.Text = name..":  "..v.."  ▾"
		close()
		if callback then callback(v) end
	end

	local function buildOpts()
		for _, c in ipairs(list:GetChildren()) do
			if c:IsA("TextButton") then c:Destroy() end
		end
		for _, opt in ipairs(options) do
			local ob = Instance.new("TextButton", list)
			ob.Size = UDim2.new(1,-8,0,26)
			ob.BackgroundColor3 = THEME.SideBarBtn; ob.BorderSizePixel = 0
			ob.Text = opt; ob.TextColor3 = THEME.Text
			ob.Font = FONT_BODY; ob.TextSize = 12; ob.ZIndex = 101
			mkCorner(ob, 4)
			hoverFX(ob, THEME.SideBarBtn, THEME.SideBarBtnActive)
			ob.MouseButton1Click:Connect(function() pick(opt) end)
		end
	end
	buildOpts()

	local function open()
		task.wait()  -- let layout settle so AbsolutePosition is fresh
		local ap  = btn.AbsolutePosition
		local as  = btn.AbsoluteSize
		local maxH = math.min(#options * 30 + 8, 200)
		list.Size     = UDim2.new(0, as.X, 0, 0)
		list.Position = UDim2.new(0, ap.X, 0, ap.Y + as.Y + 3)
		list.Visible  = true; isOpen = true
		tw(list, {Size = UDim2.new(0, as.X, 0, maxH)}, 0.14)
	end

	btn.MouseButton1Click:Connect(function()
		if isOpen then close() else open() end
	end)

	-- Click outside closes dropdown
	UIS.InputBegan:Connect(function(inp, gp)
		if gp or not isOpen then return end
		if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		local pos = inp.Position
		local ap = list.AbsolutePosition; local as = list.AbsoluteSize
		if pos.X < ap.X or pos.X > ap.X+as.X or pos.Y < ap.Y or pos.Y > ap.Y+as.Y then
			close()
		end
	end)

	obj.Set     = pick
	obj.Refresh = function(newOpts) options = newOpts; buildOpts() end
	return obj
end

-- ─────────────────────────────────────────────────────────────────
-- CREATETEXTBOX
-- ─────────────────────────────────────────────────────────────────
function UIlib.CreateTextbox(section, name, placeholder, callback)
	local ctn = Instance.new("Frame", section)
	ctn.Size = UDim2.new(1,0,0,52); ctn.BackgroundTransparency = 1
	ctn.LayoutOrder = #section:GetChildren(); ctn.ZIndex = 12

	local lbl = mkLabel(ctn, name, 12, THEME.TextDim, FONT_BODY)
	lbl.Size = UDim2.new(1,0,0,18); lbl.Position = UDim2.new(0,0,0,0); lbl.ZIndex = 13

	local box = Instance.new("TextBox", ctn)
	box.Size = UDim2.new(1,0,0,30); box.Position = UDim2.new(0,0,0,20)
	box.BackgroundColor3 = THEME.BackgroundLight; box.BorderSizePixel = 0
	box.Text = ""; box.PlaceholderText = placeholder or "Enter text..."
	box.TextColor3 = THEME.Text; box.PlaceholderColor3 = THEME.TextDim
	box.Font = FONT_BODY; box.TextSize = 13; box.ClearTextOnFocus = false; box.ZIndex = 13
	mkCorner(box, 5); mkPad(box, 0,0,8,8)
	if callback then box.FocusLost:Connect(function(enter) callback(box.Text, enter) end) end
	return box
end

-- ─────────────────────────────────────────────────────────────────
-- CREATELABEL / SEPARATOR
-- ─────────────────────────────────────────────────────────────────
function UIlib.CreateLabel(section, text)
	local l = mkLabel(section, text, 13, THEME.TextDim, FONT_BODY)
	l.Size = UDim2.new(1,0,0,0); l.LayoutOrder = #section:GetChildren(); l.ZIndex = 12
	return l
end

function UIlib.CreateSeparator(section)
	local s = Instance.new("Frame", section)
	s.Size = UDim2.new(1,0,0,1); s.BackgroundColor3 = THEME.Separator
	s.BorderSizePixel = 0; s.LayoutOrder = #section:GetChildren()
	return s
end

-- ─────────────────────────────────────────────────────────────────
-- ADDSETTING
-- ─────────────────────────────────────────────────────────────────
function UIlib.AddSetting(win, name, kind, ...)
	local sec = win.Sections["Settings"] or UIlib.Section(win, "Settings")
	local a = {...}
	if     kind == "toggle"   then return UIlib.CreateToggle(sec, name, a[1], a[2])
	elseif kind == "slider"   then return UIlib.CreateSlider(sec, name, a[1], a[2], a[3], a[4])
	elseif kind == "dropdown" then return UIlib.CreateDropdown(sec, name, a[1], a[2])
	elseif kind == "textbox"  then return UIlib.CreateTextbox(sec, name, a[1], a[2])
	elseif kind == "button"   then return UIlib.CreateButton(sec, name, a[1])
	elseif kind == "label"    then return UIlib.CreateLabel(sec, a[1] or name) end
end

-- ─────────────────────────────────────────────────────────────────
-- COLOR EDITOR POPUP  (VSCode-style: SV square + hue strip)
-- ─────────────────────────────────────────────────────────────────
function UIlib.OpenColorEditor(labelText, currentColor, onDone)
	local sg = getSG()
	currentColor = currentColor or Color3.new(1, 1, 1)

	-- Backdrop
	local bg = Instance.new("Frame", sg)
	bg.Size = UDim2.new(1,0,1,0); bg.BackgroundColor3 = Color3.new(0,0,0)
	bg.BackgroundTransparency = 0.5; bg.BorderSizePixel = 0; bg.ZIndex = 150

	-- Panel
	local panel = Instance.new("Frame", bg)
	panel.Size = UDim2.new(0, 290, 0, 340)
	panel.Position = UDim2.new(0.5,-145,0.5,-170)
	panel.BackgroundColor3 = THEME.Background; panel.BorderSizePixel = 0; panel.ZIndex = 151
	mkCorner(panel, 10); mkPad(panel, 12,14,12,12); mkList(panel, 10)
	makeDraggable(panel)

	-- Title row
	local ttl = mkLabel(panel, "Color Editor  –  "..labelText, 14, THEME.Text, FONT)
	ttl.LayoutOrder = 0; ttl.ZIndex = 152

	-- SV square
	local svBox = Instance.new("Frame", panel)
	svBox.Name = "SVBox"; svBox.Size = UDim2.new(1,0,0,155)
	svBox.BorderSizePixel = 0; svBox.LayoutOrder = 1; svBox.ZIndex = 152
	svBox.BackgroundColor3 = Color3.new(1,0,0)
	mkCorner(svBox, 4)

	-- White-to-transparent (left→right = saturation)
	local wO = Instance.new("Frame", svBox)
	wO.Size = UDim2.new(1,0,1,0); wO.BackgroundColor3 = Color3.new(1,1,1)
	wO.BorderSizePixel = 0; wO.ZIndex = 153; mkCorner(wO, 4)
	local wG = Instance.new("UIGradient", wO)
	wG.Transparency = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1)
	}

	-- Transparent-to-black (top→bottom = value)
	local bO = Instance.new("Frame", svBox)
	bO.Size = UDim2.new(1,0,1,0); bO.BackgroundColor3 = Color3.new(0,0,0)
	bO.BorderSizePixel = 0; bO.ZIndex = 154; mkCorner(bO, 4)
	local bG = Instance.new("UIGradient", bO)
	bG.Rotation = 90
	bG.Transparency = NumberSequence.new{
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0)
	}

	-- SV thumb
	local svTh = Instance.new("Frame", svBox)
	svTh.Size = UDim2.new(0,13,0,13); svTh.AnchorPoint = Vector2.new(0.5,0.5)
	svTh.BackgroundColor3 = Color3.new(1,1,1); svTh.BorderSizePixel = 2; svTh.ZIndex = 160
	mkCorner(svTh, 7)

	-- Hue strip
	local hStrip = Instance.new("Frame", panel)
	hStrip.Size = UDim2.new(1,0,0,16); hStrip.BorderSizePixel = 0
	hStrip.LayoutOrder = 2; hStrip.ZIndex = 152; mkCorner(hStrip, 4)
	local hG = Instance.new("UIGradient", hStrip)
	hG.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0,    Color3.fromRGB(255,0,0)),
		ColorSequenceKeypoint.new(1/6,  Color3.fromRGB(255,255,0)),
		ColorSequenceKeypoint.new(2/6,  Color3.fromRGB(0,255,0)),
		ColorSequenceKeypoint.new(3/6,  Color3.fromRGB(0,255,255)),
		ColorSequenceKeypoint.new(4/6,  Color3.fromRGB(0,0,255)),
		ColorSequenceKeypoint.new(5/6,  Color3.fromRGB(255,0,255)),
		ColorSequenceKeypoint.new(1,    Color3.fromRGB(255,0,0)),
	}

	-- Hue thumb (vertical bar)
	local hTh = Instance.new("Frame", hStrip)
	hTh.Size = UDim2.new(0,4,1,6); hTh.AnchorPoint = Vector2.new(0.5,0.5)
	hTh.Position = UDim2.new(0,0,0.5,0)
	hTh.BackgroundColor3 = Color3.new(1,1,1); hTh.BorderSizePixel = 1; hTh.ZIndex = 160
	mkCorner(hTh, 2)

	-- Preview row
	local prevRow = Instance.new("Frame", panel)
	prevRow.Size = UDim2.new(1,0,0,34); prevRow.BackgroundTransparency = 1
	prevRow.LayoutOrder = 3; prevRow.ZIndex = 152

	local swatch = Instance.new("Frame", prevRow)
	swatch.Size = UDim2.new(0,52,1,0); swatch.BackgroundColor3 = currentColor
	swatch.BorderSizePixel = 0; swatch.ZIndex = 153; mkCorner(swatch, 5)

	local hexL = mkLabel(prevRow, "#"..currentColor:ToHex():upper(), 13, THEME.TextDim, FONT_BODY)
	hexL.Position = UDim2.new(0,60,0.15,0); hexL.Size = UDim2.new(1,-62,0.7,0); hexL.ZIndex = 153

	-- Button row
	local btnRow = Instance.new("Frame", panel)
	btnRow.Size = UDim2.new(1,0,0,30); btnRow.BackgroundTransparency = 1
	btnRow.LayoutOrder = 4; btnRow.ZIndex = 152

	local applyBtn = Instance.new("TextButton", btnRow)
	applyBtn.Size = UDim2.new(0.48,0,1,0)
	applyBtn.BackgroundColor3 = Color3.fromRGB(70,150,70); applyBtn.BorderSizePixel = 0
	applyBtn.Text = "Apply"; applyBtn.TextColor3 = THEME.Text
	applyBtn.Font = FONT; applyBtn.TextSize = 13; applyBtn.ZIndex = 153
	mkCorner(applyBtn, 5)

	local cancelBtn = Instance.new("TextButton", btnRow)
	cancelBtn.Size = UDim2.new(0.48,0,1,0); cancelBtn.Position = UDim2.new(0.52,0,0,0)
	cancelBtn.BackgroundColor3 = Color3.fromRGB(150,50,50); cancelBtn.BorderSizePixel = 0
	cancelBtn.Text = "Cancel"; cancelBtn.TextColor3 = THEME.Text
	cancelBtn.Font = FONT_BODY; cancelBtn.TextSize = 13; cancelBtn.ZIndex = 153
	mkCorner(cancelBtn, 5)

	-- State
	local ch, cs, cv = rgbToHsv(currentColor)

	local function refresh()
		svBox.BackgroundColor3 = hsvToRgb(ch, 1, 1)
		svTh.Position = UDim2.new(cs, 0, 1-cv, 0)
		hTh.Position  = UDim2.new(ch, 0, 0.5, 0)
		local col = hsvToRgb(ch, cs, cv)
		swatch.BackgroundColor3 = col
		hexL.Text = "#"..col:ToHex():upper()
	end
	refresh()

	local dragSV, dragH = false, false
	svBox.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragSV = true end
	end)
	hStrip.InputBegan:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragH = true end
	end)
	UIS.InputEnded:Connect(function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 then dragSV = false; dragH = false end
	end)
	UIS.InputChanged:Connect(function(inp)
		if inp.UserInputType ~= Enum.UserInputType.MouseMovement then return end
		if dragSV then
			local ap, as = svBox.AbsolutePosition, svBox.AbsoluteSize
			cs = math.clamp((inp.Position.X-ap.X)/math.max(as.X,1), 0, 1)
			cv = math.clamp(1-(inp.Position.Y-ap.Y)/math.max(as.Y,1), 0, 1)
			refresh()
		elseif dragH then
			local ap, as = hStrip.AbsolutePosition, hStrip.AbsoluteSize
			ch = math.clamp((inp.Position.X-ap.X)/math.max(as.X,1), 0, 0.9999)
			refresh()
		end
	end)

	applyBtn.MouseButton1Click:Connect(function()
		local result = hsvToRgb(ch, cs, cv)
		bg:Destroy()
		if onDone then onDone(result) end
	end)
	cancelBtn.MouseButton1Click:Connect(function() bg:Destroy() end)
end

-- ─────────────────────────────────────────────────────────────────
-- SETTHEME  (update colors; does NOT retroactively repaint GUI)
-- ─────────────────────────────────────────────────────────────────
function UIlib.SetTheme(t)
	for k, v in pairs(t) do THEME[k] = v end
end

-- ─────────────────────────────────────────────────────────────────
-- SETOPACITY  (0 = fully transparent  …  1 = fully opaque)
-- Works by adjusting BackgroundTransparency of every opaque frame.
-- ─────────────────────────────────────────────────────────────────
function UIlib.SetOpacity(alpha)
	alpha = math.clamp(alpha, 0, 1)
	UIlib.__opacity = alpha
	local sg = UIlib.__screenGui
	if not sg then return end

	for _, obj in ipairs(sg:GetDescendants()) do
		if obj:IsA("Frame") or obj:IsA("ScrollingFrame") then
			-- Snapshot original on first call
			if obj:GetAttribute("BaseTrans") == nil then
				obj:SetAttribute("BaseTrans", obj.BackgroundTransparency)
			end
			local base = obj:GetAttribute("BaseTrans")
			if base ~= nil and base < 1 then
				-- alpha=1 → keep base transparency; alpha=0 → fully transparent
				obj.BackgroundTransparency = 1 - alpha * (1 - base)
			end
		end
	end
end

-- ─────────────────────────────────────────────────────────────────
-- ALT + RIGHTSHIFT  → toggle GUI visibility
-- ─────────────────────────────────────────────────────────────────
UIS.InputBegan:Connect(function(inp, gp)
	if gp then return end
	if inp.KeyCode == Enum.KeyCode.RightShift and UIS:IsKeyDown(Enum.KeyCode.LeftAlt) then
		local sg = UIlib.__screenGui
		if sg then sg.Enabled = not sg.Enabled end
	end
end)

-- ─────────────────────────────────────────────────────────────────
-- DESTROY
-- ─────────────────────────────────────────────────────────────────
function UIlib.Destroy()
	if UIlib.__screenGui then
		UIlib.__screenGui:Destroy()
		UIlib.__screenGui = nil
	end
	UIlib.__windows     = {}
	UIlib.__notifyStack = {}
end

return UIlib
