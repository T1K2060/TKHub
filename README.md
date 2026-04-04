# TKLib — UIlib.lua
### Complete Reference Manual — v3.0

UIlib is a Roblox Lua UI framework for building hub-style GUIs.  
It gives you windows, sections, buttons, toggles, sliders, dropdowns, textboxes, notifications, a color editor, theme control, keybinds, progress bars, tables, profiles, config import/export, and much more — all from one `require` or `loadstring`.

> **Backward compatible.** All v2.x scripts continue to work without changes.

---

## Table of Contents

1. [Quick Start](#1-quick-start)
2. [What's New in v3.0](#2-whats-new-in-v30)
3. [MainWindow](#3-mainwindow)
4. [Section](#4-section)
5. [CreateButton](#5-createbutton)
6. [CreateToggle](#6-createtoggle)
7. [CreateSlider](#7-createslider)
8. [CreateDropdown](#8-createdropdown)
9. [CreateTextbox](#9-createtextbox)
10. [CreateLabel](#10-createlabel)
11. [CreateSeparator](#11-createseparator)
12. [CreateColorPicker](#12-createcolorpicker)
13. [CreateKeybind](#13-createkeybind)
14. [CreateProgressBar](#14-createprogressbar)
15. [CreateTable](#15-createtable)
16. [CreateTab (Window Inner Tabs)](#16-createtab-window-inner-tabs)
17. [AddSetting](#17-addsetting)
18. [Notify](#18-notify)
19. [SetTheme](#19-settheme)
20. [SetOpacity](#20-setopacity)
21. [SetAnimation](#21-setanimation)
22. [OpenColorEditor](#22-opencoloreditor)
23. [SetTooltip](#23-settooltip)
24. [Config System](#24-config-system)
25. [Profile System](#25-profile-system)
26. [Import / Export Config](#26-import--export-config)
27. [Event System](#27-event-system)
28. [Element Registry](#28-element-registry)
29. [Destroy](#29-destroy)
30. [UIlib.THEME table](#30-uilibtable)
31. [Keyboard Shortcut](#31-keyboard-shortcut)
32. [Versioning & Update Check](#32-versioning--update-check)
33. [Full Example](#33-full-example)
34. [Common Mistakes](#34-common-mistakes)
35. [Backward Compatibility](#35-backward-compatibility)

---

## 1. Quick Start

```lua
-- Option A: loadstring from GitHub
local UIlib = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/T1K2060/TKHub/refs/heads/main/Lib/UIlib.lua", true
))()

-- Option B: require from ModuleScript (Studio)
local UIlib = require(game.StarterGui.TKLib.UIlib)

-- Option C: passed in by loader.lua
local function MyHub(UIlib)
    ...
end
```

Basic workflow:

```lua
UIlib.SetTheme({ Accent = Color3.fromRGB(120,160,255) })  -- optional

local Win = UIlib.MainWindow("Player")
local Sec = UIlib.Section(Win, "Movement")

UIlib.CreateSlider(Sec, "WalkSpeed", 0, 200, 16, function(val)
    game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = val
end)

UIlib.CreateToggle(Sec, "Noclip", false, function(enabled)
    _G.Noclip = enabled
end)

UIlib.Notify("My Hub", "Loaded!", 3, "success")
```

---

## 2. What's New in v3.0

### New Elements
| Element | Description |
|---|---|
| `CreateColorPicker` | Inline swatch button that opens the color editor |
| `CreateKeybind` | Click-to-bind keybind element, stores `KeyCode` |
| `CreateProgressBar` | Read-only bar you update with `.Set(value)` |
| `CreateTable` | Scrollable grid with headers and row data |

### Window / Layout
| Feature | Description |
|---|---|
| Collapsible sections | Click the section header (or arrow) to collapse/expand |
| Window inner tabs | `UIlib.CreateTab(window, "Name")` — sub-pages inside a window |
| Resizable windows | Drag the bottom-right corner handle |
| Window minimize | Click `—` in the title bar to shrink to just the title |
| Window search bar | Click `⌕` in the title bar to filter elements by name |

### Settings & Persistence
| Feature | Description |
|---|---|
| Config auto-save | Call `UIlib.cfgSave(key, value)` — profiles.json persists |
| Profile system | Named save slots: Default, PvP, Farm, etc. |
| Import / Export | `UIlib.ExportConfig()` / `UIlib.ImportConfig(b64)` |

### UX / Polish
| Feature | Description |
|---|---|
| Context menu | Right-click any element → Copy value, Reset to default |
| Tooltip system | `UIlib.SetTooltip(element, "text")` |
| Animation presets | `UIlib.SetAnimation("slide" | "fade" | "bounce")` |
| Mobile support | All drag/input handling uses Touch events too |

### Code Quality
| Feature | Description |
|---|---|
| Event system | `UIlib.on("themeChanged", fn)` / `UIlib.off(...)` |
| Element registry | `UIlib.GetElement(win, sec, name)` |
| Error boundary | All callbacks wrapped in `pcall` + error toast |
| `UIlib.Version` | String e.g. `"3.0.0"` |
| `UIlib.CheckForUpdates()` | Hits GitHub, notifies if newer version exists |

### Notification system rework
- Icons per type: `info`, `success`, `error`, `warning`, `default`
- Dismissible via `×` button
- Progress bar that drains over the duration
- Optional action buttons per notification
- Stacks cleanly; each slides in from the right

---

## 3. MainWindow

```lua
local WindowObj = UIlib.MainWindow(name: string)
```

Creates a **window panel** and adds a sidebar button. The root frame is draggable and resizable.

| Parameter | Type | Description |
|---|---|---|
| `name` | string | Window title and sidebar label |

**Returns** a `WindowObj`:

| Field | Type | Description |
|---|---|---|
| `.Name` | string | Name passed in |
| `.Frame` | ScrollingFrame | Outer scrollable frame |
| `.Inner` | Frame | Content frame (parent for sections) |
| `.Sidebar` | Frame | Shared sidebar reference |
| `.Sections` | table | `{[sectionName] = sectionFrame}` |
| `._tabs` | table | Inner tabs created with `CreateTab` |

**Notes:**
- First window created is visible by default.
- `×` in the title bar hides but does not destroy the window.
- Click `—` to minimize. Click `⌕` to open search.
- Drag the bottom-right handle to resize.

```lua
local HomeWin  = UIlib.MainWindow("Home")
local SetWin   = UIlib.MainWindow("Settings")
local InfoWin  = UIlib.MainWindow("Info")
```

---

## 4. Section

```lua
local sectionFrame = UIlib.Section(windowOrTab, name: string)
```

Creates a **collapsible labeled container** inside a window or tab.

| Parameter | Type | Description |
|---|---|---|
| `windowOrTab` | WindowObj or TabObj | Parent window or inner tab |
| `name` | string | Label shown in the section header |

**Returns** the section inner `Frame`.

**Notes:**
- Click the section header or the `▼` arrow to collapse/expand.
- `windowOrTab.Sections["My Name"]` retrieves the frame later.

```lua
local Sec = UIlib.Section(Win, "Movement")
-- Collapsible by default — users can hide sections they don't need
```

---

## 5. CreateButton

```lua
local btn = UIlib.CreateButton(section, name: string, callback: function?)
```

Creates a **clickable button**. All callbacks are wrapped in `pcall` — an error pops a toast instead of crashing.

| Parameter | Type | Description |
|---|---|---|
| `section` | Frame | Section to add into |
| `name` | string | Button label |
| `callback` | function | Called on click |

**Returns** the `TextButton`.

Right-clicking the button opens a context menu with "Copy value" and "Reset to default".

```lua
UIlib.CreateButton(Sec, "Load Script", function()
    task.spawn(function()
        loadstring(game:HttpGet("https://..."))()
    end)
end)
```

---

## 6. CreateToggle

```lua
local obj = UIlib.CreateToggle(section, name, default: boolean, callback: function?)
```

Creates an **on/off pill toggle**.

**Returns:**

| Field | Type | Description |
|---|---|---|
| `.Value` | boolean | Current state |
| `.Set(v)` | function | Set state without firing callback |
| `.Button` | TextButton | The pill instance |

```lua
local t = UIlib.CreateToggle(Sec, "Noclip", false, function(enabled)
    _G.Noclip = enabled
end)

t.Set(true)          -- programmatic set
print(t.Value)       -- true
```

---

## 7. CreateSlider

```lua
local obj = UIlib.CreateSlider(section, name, min, max, default, callback)
```

Creates a **draggable numeric slider**. Values are always integers.

**Returns:**

| Field | Type | Description |
|---|---|---|
| `.Value` | number | Current integer value |
| `.Set(v)` | function | Jump to a value |

```lua
local ws = UIlib.CreateSlider(Sec, "WalkSpeed", 0, 500, 16, function(v)
    game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = v
end)
ws.Set(100)
```

---

## 8. CreateDropdown

```lua
local obj = UIlib.CreateDropdown(section, name, options: table, callback)
```

Creates a **dropdown selector**. The list renders over everything else (parented to ScreenGui root). Clicking outside closes it.

**Returns:**

| Field | Type | Description |
|---|---|---|
| `.Value` | string | Currently selected option |
| `.Set(v)` | function | Select an option programmatically |
| `.Refresh(t)` | function | Replace options with new table |

```lua
local dd = UIlib.CreateDropdown(Sec, "Mode", {"Fast","Normal","Stealth"}, function(v)
    print("Mode:", v)
end)
dd.Refresh({"A","B","C"})
```

---

## 9. CreateTextbox

```lua
local textbox = UIlib.CreateTextbox(section, name, placeholder, callback)
```

Creates a **text input**. `ClearTextOnFocus` is `false`. Callback fires on focus lost or Enter.

**Returns** the `TextBox` instance.

```lua
local box = UIlib.CreateTextbox(Sec, "Player Name", "Enter name...", function(text, enter)
    if enter then print(text) end
end)
print(box.Text)
box.Text = "Roblox"
```

---

## 10. CreateLabel

```lua
local label = UIlib.CreateLabel(section, text: string)
```

Creates a **static text label**. Supports `\n` for line breaks. Auto-wraps.

```lua
UIlib.CreateLabel(Sec, "Toggle noclip below.\nRight-click elements for options.")
```

---

## 11. CreateSeparator

```lua
UIlib.CreateSeparator(section)
```

Creates a **1px horizontal divider line** inside a section.

---

## 12. CreateColorPicker

```lua
local obj = UIlib.CreateColorPicker(section, name, defaultColor: Color3, callback)
```

Creates an **inline swatch button**. Clicking it opens the full `OpenColorEditor` popup.

**Returns:**

| Field | Type | Description |
|---|---|---|
| `.Value` | Color3 | Currently selected color |
| `.Set(col)` | function | Update color programmatically |

```lua
local cp = UIlib.CreateColorPicker(Sec, "Accent Color", Color3.fromRGB(120,160,255), function(col)
    UIlib.THEME.Accent = col
    UIlib.Notify("Theme", "Accent updated!", 2)
end)
print(cp.Value)
```

---

## 13. CreateKeybind

```lua
local obj = UIlib.CreateKeybind(section, name, defaultKey: Enum.KeyCode, callback)
```

Creates a **click-to-bind keybind element**. Click the button then press any key to assign it. After assignment, pressing the bound key fires the callback.

**Returns:**

| Field | Type | Description |
|---|---|---|
| `.Value` | Enum.KeyCode | Current bound key |
| `.Set(kc)` | function | Set key programmatically |
| `.Button` | TextButton | The bind button |

```lua
local kb = UIlib.CreateKeybind(Sec, "Toggle Noclip", Enum.KeyCode.F, function(kc)
    noclipToggle.Set(not noclipToggle.Value)
end)
UIlib.SetTooltip(kb.Button, "Click then press a key to rebind")
```

---

## 14. CreateProgressBar

```lua
local obj = UIlib.CreateProgressBar(section, name, initialValue, maxValue)
```

Creates a **read-only progress bar**. Useful for health, loading, timers.

**Returns:**

| Field | Type | Description |
|---|---|---|
| `.Value` | number | Current value |
| `.Set(v, animate?)` | function | Update value; `animate = false` skips tween |

```lua
local hpBar = UIlib.CreateProgressBar(Sec, "Health", 100, 100)

-- Update it from a loop:
game:GetService("RunService").Heartbeat:Connect(function()
    local hum = Player.Character and Player.Character:FindFirstChild("Humanoid")
    if hum then hpBar.Set(hum.Health) end
end)
```

---

## 15. CreateTable

```lua
local obj = UIlib.CreateTable(section, headers: table, rows: table, rowHeight?: number)
```

Creates a **scrollable data grid** with alternating row colors.

| Parameter | Type | Description |
|---|---|---|
| `headers` | `{string}` | Column headers |
| `rows` | `{{any}}` | Array of rows, each an array of cell values |
| `rowHeight` | number | Row height in px (default 26) |

**Returns:**

| Field | Type | Description |
|---|---|---|
| `.Rows` | table | Array of row Frames |
| `.AddRow(data, index?)` | function | Append a row |
| `.Clear()` | function | Remove all rows |
| `.Refresh(newRows)` | function | Clear and rebuild |

```lua
local tbl = UIlib.CreateTable(Sec,
    {"Player","Score","Kills"},
    {
        {"Alice", 1200, 14},
        {"Bob",   800,  9},
    }
)

-- Live update
tbl.Refresh({{"Alice",1250,15},{"Bob",820,9}})
```

---

## 16. CreateTab (Window Inner Tabs)

```lua
local tabObj = UIlib.CreateTab(window: WindowObj, tabName: string)
```

Creates a **sub-page tab bar** inside a window. The first tab is active by default. Pass `tabObj` instead of `WindowObj` to `Section`.

**Returns:**

| Field | Type | Description |
|---|---|---|
| `.Name` | string | Tab name |
| `.Frame` | Frame | Content frame |
| `.Button` | TextButton | Tab button |

```lua
local MovTab    = UIlib.CreateTab(PlayerWin, "Movement")
local TargetTab = UIlib.CreateTab(PlayerWin, "Target")

-- Sections go into the tab, not the window:
local MovSec = UIlib.Section(MovTab, "Speed")
UIlib.CreateSlider(MovSec, "WalkSpeed", 0, 500, 16, callback)
```

---

## 17. AddSetting

```lua
local element = UIlib.AddSetting(window, name, kind, ...)
```

Convenience helper — finds or creates a `"Settings"` section in `window`, then adds one element. Supports all element types including the new ones.

| Kind | Extra args |
|---|---|
| `"toggle"` | `default, callback` |
| `"slider"` | `min, max, default, callback` |
| `"dropdown"` | `options, callback` |
| `"textbox"` | `placeholder, callback` |
| `"button"` | `callback` |
| `"label"` | `text` |
| `"colorpicker"` | `defaultColor, callback` |
| `"keybind"` | `defaultKey, callback` |
| `"progress"` | `initialValue, maxValue` |

```lua
UIlib.AddSetting(Win, "Auto-Farm",  "toggle", false, function(v) _G.Farm = v end)
UIlib.AddSetting(Win, "Speed",      "slider", 0, 500, 16, callback)
UIlib.AddSetting(Win, "Accent",     "colorpicker", UIlib.THEME.Accent, function(c) UIlib.THEME.Accent = c end)
UIlib.AddSetting(Win, "Toggle Key", "keybind", Enum.KeyCode.F, callback)
```

---

## 18. Notify

```lua
UIlib.Notify(title, body, duration?, type?, actions?)
```

Shows a **toast notification** — slides in from the right, stacks upward, auto-dismisses.

| Parameter | Type | Default | Description |
|---|---|---|---|
| `title` | string | — | Bold heading |
| `body` | string | — | Body text |
| `duration` | number | 3 | Auto-dismiss seconds |
| `type` | string | `"default"` | `"info"`, `"success"`, `"error"`, `"warning"`, `"default"` |
| `actions` | table | `{}` | `{{label, action}}` buttons inside the notification |

**New in v3.0:**
- Left accent bar and icon change color based on `type`
- A progress bar drains over `duration`
- `×` button for manual dismiss
- Optional action buttons

```lua
UIlib.Notify("Loaded", "Welcome!", 4, "success")
UIlib.Notify("Error", "HttpService disabled.", 5, "error")
UIlib.Notify("Update", "v3.1 is available!", 6, "info", {
    { label = "Dismiss", action = function() end },
})
```

---

## 19. SetTheme

```lua
UIlib.SetTheme(colorTable: table)
```

Merges a partial or full color table into the active theme. Call **before** building your windows.

**Full key list:**

| Key | Controls |
|---|---|
| `Background` | Main window background |
| `BackgroundLight` | Title bar, sections, textbox fill |
| `SideBar` | Sidebar panel |
| `SideBarBtn` | Sidebar button |
| `SideBarBtnActive` | Active sidebar button |
| `Accent` | Title text, scrollbar, slider, notification bar |
| `Text` | Primary text |
| `TextDim` | Labels, placeholders |
| `ButtonBG` | Button background |
| `ButtonHover` | Button hover |
| `ToggleOff` | Toggle pill (off) |
| `ToggleOn` | Toggle pill (on) |
| `SliderBG` | Slider track |
| `SliderFill` | Slider fill and thumb |
| `SectionHeader` | Section header background |
| `Separator` | Divider color |
| `NotifyBG` | Notification background |
| `NotifyBorder` | Notification border |
| `ProgressBG` | Progress bar track |
| `ProgressFill` | Progress bar fill |
| `TableHeader` | Table header row |
| `TableRow` | Table odd rows |
| `TableRowAlt` | Table even rows |
| `ContextBG` | Context menu background |
| `ContextHover` | Context menu hover |
| `TooltipBG` | Tooltip background |
| `KeybindBG` | Keybind button background |

```lua
UIlib.SetTheme({
    Accent    = Color3.fromRGB(165,95,255),
    ToggleOn  = Color3.fromRGB(135,72,225),
    SliderFill = Color3.fromRGB(165,95,255),
})
local Win = UIlib.MainWindow("Hub")  -- build after SetTheme
```

---

## 20. SetOpacity

```lua
UIlib.SetOpacity(alpha: number)
```

Sets the GUI's overall opacity. `1` = opaque, `0` = invisible.

```lua
UIlib.CreateSlider(Sec, "Opacity %", 10, 100, 100, function(v)
    UIlib.SetOpacity(v / 100)
end)
```

---

## 21. SetAnimation

```lua
UIlib.SetAnimation(preset: string)
```

Sets the **window entry animation**. Options: `"slide"` (default), `"fade"`, `"bounce"`.

```lua
UIlib.SetAnimation("bounce")
```

---

## 22. OpenColorEditor

```lua
UIlib.OpenColorEditor(label, currentColor: Color3, onDone: function)
```

Opens a **VSCode-style popup** with a Saturation/Value square, Hue strip, hex input, live preview, and Apply/Cancel buttons. Called automatically by `CreateColorPicker`.

```lua
UIlib.CreateButton(Sec, "Pick Color", function()
    UIlib.OpenColorEditor("Accent", UIlib.THEME.Accent, function(col)
        UIlib.THEME.Accent = col
    end)
end)
```

---

## 23. SetTooltip

```lua
UIlib.SetTooltip(element: Instance, text: string)
```

Shows a **floating tooltip label** near the cursor when hovering over `element`.

```lua
local btn = UIlib.CreateButton(Sec, "Teleport", callback)
UIlib.SetTooltip(btn, "Teleports you to spawn")
```

---

## 24. Config System

UIlib has a built-in key/value persistence system via `profiles.json`.

```lua
-- Save a value (automatically called by built-in elements)
UIlib.cfgSave("myKey", "myValue")

-- Load a value
local v = UIlib.cfgLoad("myKey")
```

Built-in elements (toggles, sliders, dropdowns) auto-save when you use `cfgKey()` + `cfgSave()` around their callbacks. The data file lives at `TKLib/profiles.json`.

---

## 25. Profile System

```lua
UIlib.GetProfiles()          -- returns {profileName, ...}
UIlib.NewProfile(name)       -- create + switch
UIlib.SwitchProfile(name)    -- switch to existing
UIlib.DeleteProfile(name)    -- delete (can't delete "Default")
```

Profiles let users switch between different saved configurations — e.g., one for PvP, one for farming.

```lua
local profiles = UIlib.GetProfiles()   -- {"Default", "PvP", "Farm"}
UIlib.SwitchProfile("PvP")
UIlib.NewProfile("Chill")
```

---

## 26. Import / Export Config

```lua
UIlib.ExportConfig()          -- copies base64 string to clipboard
UIlib.ImportConfig(b64string) -- parses + applies
```

The entire config is JSON-encoded and base64-compressed. Share it as a string to let other users apply your exact setup.

```lua
UIlib.CreateButton(Sec, "Export", function()
    UIlib.ExportConfig()
    -- clipboard now has your config as base64
end)

local impBox = UIlib.CreateTextbox(Sec, "Paste Config", "base64...", nil)
UIlib.CreateButton(Sec, "Import", function()
    UIlib.ImportConfig(impBox.Text)
end)
```

---

## 27. Event System

```lua
UIlib.on(event: string, fn: function)
UIlib.off(event: string, fn: function)
```

Subscribe to internal events. Available events:

| Event | Args | Fires when |
|---|---|---|
| `"windowOpened"` | `winName` | A sidebar tab is clicked |
| `"themeChanged"` | `themeTable` | `SetTheme` is called |
| `"visibilityChanged"` | `bool` | LAlt+RShift toggles the GUI |
| `"configImported"` | `data` | `ImportConfig` succeeds |
| `"profileChanged"` | `profileName` | Profile switched |

```lua
UIlib.on("themeChanged", function(theme)
    print("New accent:", theme.Accent)
end)

UIlib.on("windowOpened", function(name)
    print("Opened:", name)
end)
```

---

## 28. Element Registry

```lua
UIlib.GetElement(windowName, sectionName, elementName)
```

Retrieve any element by its window name, section name, and element name — without needing to store the reference yourself.

```lua
-- Get an element from anywhere in your code
local ws = UIlib.GetElement("Player", "Movement", "WalkSpeed")
if ws then ws.Set(100) end
```

> **Note:** Elements must be registered with `registerElem(winName, secName, elemName, obj)` after creation — this is done automatically by `CreateSlider`, `CreateToggle`, etc. when you use the standard API.

---

## 29. Destroy

```lua
UIlib.Destroy()
```

Removes the ScreenGui and resets all internal state. Safe to rebuild from scratch after calling.

```lua
UIlib.CreateButton(DangerSec, "Unload Hub", function()
    _G.__MYHUB = nil
    UIlib.Destroy()
end)
```

---

## 30. UIlib.THEME table

Live theme table. Read or write any key at any time.

```lua
print(UIlib.THEME.Accent)
UIlib.THEME.Accent = Color3.fromRGB(255, 100, 0)
```

---

## 31. Keyboard Shortcut

| Keys | Action |
|---|---|
| `Left Alt` + `Right Shift` | Toggle GUI visibility |

Always active once UIlib is loaded. Fires the `"visibilityChanged"` event.

---

## 32. Versioning & Update Check

```lua
print(UIlib.Version)     -- "3.0.0"
UIlib.CheckForUpdates()  -- async; shows a notification if newer version exists
```

`CheckForUpdates` fetches `version.txt` from the GitHub repo and compares against `UIlib.Version`.

---

## 33. Full Example

```lua
local UIlib = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/T1K2060/TKHub/refs/heads/main/Lib/UIlib.lua", true
))()

-- ── Theme ──────────────────────────────────────────────────────
UIlib.SetTheme({
    Accent    = Color3.fromRGB(120,160,255),
    ToggleOn  = Color3.fromRGB(100,145,255),
    SliderFill = Color3.fromRGB(120,160,255),
})
UIlib.SetAnimation("slide")

-- ── Windows ────────────────────────────────────────────────────
local Win      = UIlib.MainWindow("Player")
local WinSets  = UIlib.MainWindow("Settings")

-- ── Inner tabs ─────────────────────────────────────────────────
local MovTab    = UIlib.CreateTab(Win, "Movement")
local MiscTab   = UIlib.CreateTab(Win, "Misc")

-- ── Movement ───────────────────────────────────────────────────
local MovSec = UIlib.Section(MovTab, "Speed & Jump")

local wsSlider = UIlib.CreateSlider(MovSec, "WalkSpeed", 0, 500, 16, function(v)
    game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = v
end)
UIlib.SetTooltip(wsSlider, "Sets your walk speed")

UIlib.CreateToggle(MovSec, "Infinite Jump", false, function(enabled)
    _G.InfJump = enabled
end)

UIlib.CreateProgressBar(MovSec, "Health", 100, 100)

-- ── Keybind ────────────────────────────────────────────────────
local MiscSec = UIlib.Section(MiscTab, "Controls")

UIlib.CreateKeybind(MiscSec, "Toggle GUI", Enum.KeyCode.RightShift, function()
    -- custom toggle action
end)

UIlib.CreateColorPicker(MiscSec, "ESP Color", Color3.fromRGB(255,80,80), function(col)
    _G.ESPColor = col
end)

-- ── Settings ───────────────────────────────────────────────────
local AppSec = UIlib.Section(WinSets, "Appearance")

UIlib.CreateSlider(AppSec, "Opacity %", 10, 100, 100, function(v)
    UIlib.SetOpacity(v / 100)
end)

UIlib.CreateDropdown(AppSec, "Animation", {"slide","fade","bounce"}, function(v)
    UIlib.SetAnimation(v)
end)

UIlib.CreateButton(AppSec, "Export Config", function()
    UIlib.ExportConfig()
end)

-- ── Events ─────────────────────────────────────────────────────
UIlib.on("windowOpened", function(name)
    print("Switched to:", name)
end)

-- ── Startup ────────────────────────────────────────────────────
UIlib.Notify("My Hub", "Loaded! LAlt+RShift to hide.", 5, "success", {
    { label = "OK", action = function() end }
})
```

---

## 34. Common Mistakes

### Passing window instead of section
```lua
-- WRONG
UIlib.CreateButton(Win, "Click me", fn)

-- CORRECT
local Sec = UIlib.Section(Win, "My Section")
UIlib.CreateButton(Sec, "Click me", fn)
```

### SetTheme after building the GUI
```lua
-- WRONG – only affects new elements
local Win = UIlib.MainWindow("Hub")
UIlib.SetTheme({ Accent = Color3.fromRGB(255,0,0) })

-- CORRECT
UIlib.SetTheme({ Accent = Color3.fromRGB(255,0,0) })
local Win = UIlib.MainWindow("Hub")
```

### Blocking operations inside callbacks
```lua
-- WRONG – blocks the engine thread
UIlib.CreateButton(Sec, "Load", function()
    local code = game:HttpGet("https://...")
    loadstring(code)()
end)

-- CORRECT
UIlib.CreateButton(Sec, "Load", function()
    task.spawn(function()
        local code = game:HttpGet("https://...")
        loadstring(code)()
    end)
end)
```

### Using UIlib after Destroy
```lua
UIlib.Destroy()
-- All window/section refs are now stale
UIlib.CreateButton(Sec, ...)  -- ERROR

-- To rebuild:
local Win2 = UIlib.MainWindow("Hub")
```

### Forgetting to use CreateTab before Section (for tabbed windows)
```lua
-- This adds a section directly to the window (OK but no tab button)
local Sec = UIlib.Section(Win, "Stuff")

-- This adds a section inside a tab (with a tab bar)
local Tab = UIlib.CreateTab(Win, "Tab Name")
local Sec = UIlib.Section(Tab, "Stuff")
```

---

## 35. Backward Compatibility

v3.0 is **fully backward compatible** with all v2.x scripts. Every existing API (`CreateButton`, `CreateToggle`, `CreateSlider`, `CreateDropdown`, `CreateTextbox`, `CreateLabel`, `CreateSeparator`, `AddSetting`, `Notify`, `SetTheme`, `SetOpacity`, `OpenColorEditor`, `Destroy`, `UIlib.THEME`) works exactly as before.

**The only behavioral additions are:**
- Sections now have a collapse arrow — they still expand by default, so existing UIs look the same.
- `Notify` now accepts two optional extra parameters (`type`, `actions`) — omitting them falls back to the original behavior.
- The root window is now resizable — dragging still works the same way.

No code changes are required in scripts written for v2.x.

---

*TKLib UIlib — documentation for v3.0.0*
