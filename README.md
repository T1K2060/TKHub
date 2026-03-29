# TKLib — UIlib.lua
### Complete Reference Manual

UIlib is a Roblox Lua UI framework for building hub-style GUIs.  
It gives you windows, sections, buttons, toggles, sliders, dropdowns, textboxes, notifications, a color editor, and theme control — all with one `require` or `loadstring`.

---

## Table of Contents

1. [Quick Start](#1-quick-start)  
2. [MainWindow](#2-mainwindow)  
3. [Section](#3-section)  
4. [CreateButton](#4-createbutton)  
5. [CreateToggle](#5-createtoggle)  
6. [CreateSlider](#6-createslider)  
7. [CreateDropdown](#7-createdropdown)  
8. [CreateTextbox](#8-createtextbox)  
9. [CreateLabel](#9-createlabel)  
10. [CreateSeparator](#10-createseparator)  
11. [AddSetting](#11-addsetting)  
12. [Notify](#12-notify)  
13. [SetTheme](#13-settheme)  
14. [SetOpacity](#14-setopacity)  
15. [OpenColorEditor](#15-opencoloreditor)  
16. [Destroy](#16-destroy)  
17. [UIlib.THEME table](#17-uilibtable)  
18. [Keyboard Shortcut](#18-keyboard-shortcut)  
19. [Full Example](#19-full-example)  
20. [Common Mistakes](#20-common-mistakes)

---

## 1. Quick Start

```lua
-- Load the library (one of the three ways below)

-- Option A: loadstring from GitHub
local UIlib = loadstring(game:HttpGet("https://raw.githubusercontent.com/YOU/REPO/main/TKLib/Lib/UIlib.lua", true))()

-- Option B: require from ModuleScript (Studio)
local UIlib = require(game.StarterGui.TKLib.UIlib)

-- Option C: already injected by loader.lua — just use the argument
local function MyHub(UIlib)   -- UIlib passed in by loader
    ...
end
```

Once you have `UIlib`, the typical workflow is:

```lua
-- 1. Create a window (tab)
local Win = UIlib.MainWindow("Player")

-- 2. Create a section inside it
local Sec = UIlib.Section(Win, "Movement")

-- 3. Add elements to the section
UIlib.CreateButton(Sec, "Teleport to Spawn", function()
    game.Players.LocalPlayer.Character:MoveTo(Vector3.new(0,5,0))
end)

UIlib.CreateToggle(Sec, "Noclip", false, function(enabled)
    -- your noclip code
end)

UIlib.CreateSlider(Sec, "WalkSpeed", 0, 200, 16, function(val)
    game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = val
end)

-- 4. Done — the GUI appears automatically
```

---

## 2. MainWindow

```lua
local WindowObj = UIlib.MainWindow(name: string)
```

Creates a new **window panel** and adds a corresponding button to the sidebar.

| Parameter | Type   | Description                        |
|-----------|--------|------------------------------------|
| `name`    | string | Window title shown in the title bar and sidebar button |

**Returns** a `WindowObj` table:

| Field      | Type   | Description                                        |
|------------|--------|----------------------------------------------------|
| `.Name`    | string | The name you passed in                             |
| `.Frame`   | ScrollingFrame | The outer window frame                   |
| `.Inner`   | Frame  | The inner content frame (parent for sections)      |
| `.Sidebar` | Frame  | Reference to the shared sidebar                    |
| `.Sections`| table  | `{ [sectionName] = sectionFrame }` lookup          |

**Notes:**
- The **first** window created is visible by default. All others start hidden.
- Clicking a window's sidebar button hides all other windows and shows that one.
- The window is **draggable** by its title bar.
- The **×** button in the title bar hides the window (it is not destroyed).

**Example:**
```lua
local HomeWin     = UIlib.MainWindow("Home")
local SettingsWin = UIlib.MainWindow("Settings")
local InfoWin     = UIlib.MainWindow("Info")
-- Three tabs now appear in the sidebar
```

---

## 3. Section

```lua
local sectionFrame = UIlib.Section(window: WindowObj, name: string)
```

Creates a **grouped box** inside a window. Sections are labeled containers that hold elements like buttons and toggles.

| Parameter | Type      | Description               |
|-----------|-----------|---------------------------|
| `window`  | WindowObj | The window to add this section to |
| `name`    | string    | Label shown at the top of the section |

**Returns** the section `Frame`. Pass this frame as the first argument to `CreateButton`, `CreateToggle`, etc.

**Notes:**
- Sections expand automatically as you add elements.
- You can have as many sections per window as you like.
- `window.Sections["My Section Name"]` gives you back the frame at any time.

**Example:**
```lua
local Win = UIlib.MainWindow("Combat")

local AimSec  = UIlib.Section(Win, "Aimbot")
local ESPSec  = UIlib.Section(Win, "ESP")
local MiscSec = UIlib.Section(Win, "Misc")
```

---

## 4. CreateButton

```lua
local btn = UIlib.CreateButton(section: Frame, name: string, callback: function?)
```

Creates a **clickable button** inside a section.

| Parameter  | Type     | Description                          |
|------------|----------|--------------------------------------|
| `section`  | Frame    | The section frame to add the button to |
| `name`     | string   | Button label text                    |
| `callback` | function | *(optional)* Called when clicked     |

**Returns** the `TextButton` instance.

You can either pass the callback inline, or connect to it yourself afterward:

```lua
-- Inline callback
UIlib.CreateButton(Sec, "Load Vape", function()
    loadstring(game:HttpGet("https://..."))()
end)

-- Manual connection
local MyBtn = UIlib.CreateButton(Sec, "Vape V4")
MyBtn.MouseButton1Click:Connect(function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/VapeVoidware/VWRewrite/master/NewMainScript.lua", true))()
end)
```

**Visual behaviour:**
- Hover → slightly lighter background
- Mouse down → accent color flash
- Mouse up → returns to normal

---

## 5. CreateToggle

```lua
local obj = UIlib.CreateToggle(section: Frame, name: string, default: boolean, callback: function?)
```

Creates an **on/off switch** (pill toggle) inside a section.

| Parameter  | Type     | Description                               |
|------------|----------|-------------------------------------------|
| `section`  | Frame    | Section to add into                       |
| `name`     | string   | Label shown beside the toggle             |
| `default`  | boolean  | Starting state (`true` = on, `false` = off) |
| `callback` | function | *(optional)* Called with `(state: boolean)` when toggled |

**Returns** a toggle object:

| Field    | Type     | Description                              |
|----------|----------|------------------------------------------|
| `.Value` | boolean  | Current state                            |
| `.Set(v)`| function | Programmatically set the state           |
| `.Button`| TextButton | The pill button instance               |

**Example:**
```lua
local noclipToggle = UIlib.CreateToggle(Sec, "Noclip", false, function(enabled)
    -- toggle noclip logic here
    print("Noclip:", enabled)
end)

-- Read state later
print(noclipToggle.Value)   -- true / false

-- Set state programmatically
noclipToggle.Set(true)
```

---

## 6. CreateSlider

```lua
local obj = UIlib.CreateSlider(section, name, min, max, default, callback)
```

Creates a **draggable slider** for numeric values.

| Parameter  | Type     | Description                              |
|------------|----------|------------------------------------------|
| `section`  | Frame    | Section to add into                      |
| `name`     | string   | Label shown above the slider             |
| `min`      | number   | Minimum value                            |
| `max`      | number   | Maximum value                            |
| `default`  | number   | Starting value                           |
| `callback` | function | *(optional)* Called with `(value: number)` on change |

**Returns** a slider object:

| Field    | Type     | Description                          |
|----------|----------|--------------------------------------|
| `.Value` | number   | Current integer value                |
| `.Set(v)`| function | Programmatically set the value       |

**Notes:**
- Values are always **integers** (rounded to nearest whole number).
- The current value is shown on the right side of the slider label.
- Drag anywhere on the track to move the thumb.

**Example:**
```lua
local wsSlider = UIlib.CreateSlider(Sec, "WalkSpeed", 0, 500, 16, function(val)
    local char = game.Players.LocalPlayer.Character
    if char then char.Humanoid.WalkSpeed = val end
end)

-- Jump to a value
wsSlider.Set(100)
print(wsSlider.Value)  -- 100
```

---

## 7. CreateDropdown

```lua
local obj = UIlib.CreateDropdown(section, name, options, callback)
```

Creates a **dropdown selector** with an expanding list of options.

| Parameter  | Type     | Description                                          |
|------------|----------|------------------------------------------------------|
| `section`  | Frame    | Section to add into                                  |
| `name`     | string   | Label prefix shown on the button                     |
| `options`  | table    | Array of strings e.g. `{"Option A", "Option B"}`    |
| `callback` | function | *(optional)* Called with `(selected: string)` on pick |

**Returns** a dropdown object:

| Field         | Type     | Description                               |
|---------------|----------|-------------------------------------------|
| `.Value`      | string   | Currently selected option                 |
| `.Set(v)`     | function | Programmatically select an option         |
| `.Refresh(t)` | function | Replace the options list with a new table |

**Important — overlap prevention:**  
The dropdown list is parented directly to the `ScreenGui` root (not inside the section), so it always renders on top of everything else. Clicking outside the list closes it automatically.

**Example:**
```lua
local teamDD = UIlib.CreateDropdown(Sec, "Team", {"Attackers","Defenders","Spectators"}, function(val)
    print("Selected team:", val)
end)

-- Change options later
teamDD.Refresh({"Red","Blue","Green"})

-- Read or set
print(teamDD.Value)
teamDD.Set("Red")
```

---

## 8. CreateTextbox

```lua
local textbox = UIlib.CreateTextbox(section, name, placeholder, callback)
```

Creates a **text input field** with a label above it.

| Parameter     | Type     | Description                                           |
|---------------|----------|-------------------------------------------------------|
| `section`     | Frame    | Section to add into                                   |
| `name`        | string   | Label shown above the input                           |
| `placeholder` | string   | Gray hint text shown when empty                       |
| `callback`    | function | *(optional)* Called with `(text: string, enterPressed: boolean)` when focus lost |

**Returns** the `TextBox` instance directly (so you can read `.Text` at any time).

**Notes:**
- `ClearTextOnFocus` is `false` — clicking does not erase existing text.
- The callback fires when the player clicks away or presses Enter.

**Example:**
```lua
local nameBox = UIlib.CreateTextbox(Sec, "Player Name", "Enter a player...", function(text, enter)
    if enter then
        print("Searching for:", text)
    end
end)

-- Read text at any time
print(nameBox.Text)

-- Set text programmatically
nameBox.Text = "Roblox"
```

---

## 9. CreateLabel

```lua
local label = UIlib.CreateLabel(section: Frame, text: string)
```

Creates a **static text label** inside a section. Useful for descriptions, credits, instructions, or multi-line info.

| Parameter | Type   | Description                      |
|-----------|--------|----------------------------------|
| `section` | Frame  | Section to add into              |
| `text`    | string | The text to display (wraps automatically) |

**Returns** the `TextLabel` instance.

**Example:**
```lua
UIlib.CreateLabel(Sec, "Toggle noclip with the button below.")
UIlib.CreateLabel(InfoSec,
    "Credits:\n  wyverndayo – WyverionExecutor\n  frstee – Gui To Lua"
)
```

---

## 10. CreateSeparator

```lua
UIlib.CreateSeparator(section: Frame)
```

Creates a **1px horizontal dividing line** inside a section. Use it to visually group related elements.

**Returns** the separator `Frame`.

**Example:**
```lua
UIlib.CreateButton(Sec, "Teleport to Spawn", ...)
UIlib.CreateSeparator(Sec)
UIlib.CreateButton(Sec, "Teleport to Player", ...)
```

---

## 11. AddSetting

```lua
local element = UIlib.AddSetting(window, name, kind, ...)
```

A **convenience helper** that automatically creates or reuses a section called `"Settings"` inside the given window, then adds one element of the specified type.

| Parameter | Type   | Description                    |
|-----------|--------|--------------------------------|
| `window`  | WindowObj | Target window                |
| `name`    | string | Element label                  |
| `kind`    | string | One of: `"toggle"`, `"slider"`, `"dropdown"`, `"textbox"`, `"button"`, `"label"` |
| `...`     | any    | Same extra arguments as the underlying `Create*` function |

**Returns** the same object that the underlying `Create*` function returns.

**Kind → arguments mapping:**

| Kind       | Extra args                          |
|------------|-------------------------------------|
| `"toggle"` | `default: boolean, callback`        |
| `"slider"` | `min, max, default, callback`       |
| `"dropdown"` | `options: table, callback`       |
| `"textbox"` | `placeholder: string, callback`   |
| `"button"` | `callback`                          |
| `"label"`  | `text: string`                      |

**Example:**
```lua
local SettingsWin = UIlib.MainWindow("Settings")

UIlib.AddSetting(SettingsWin, "Auto-Farm", "toggle", false, function(v)
    _G.AutoFarm = v
end)

UIlib.AddSetting(SettingsWin, "Jump Power", "slider", 0, 500, 50, function(v)
    game.Players.LocalPlayer.Character.Humanoid.JumpPower = v
end)

UIlib.AddSetting(SettingsWin, "Mode", "dropdown", {"Normal","Fast","Ghost"}, function(v)
    print("Mode set to:", v)
end)
```

---

## 12. Notify

```lua
UIlib.Notify(title: string, body: string, duration: number?)
```

Shows a **toast notification** that slides in from the bottom-right corner of the screen and auto-dismisses after `duration` seconds. Multiple notifications stack upward.

| Parameter  | Type   | Default | Description                     |
|------------|--------|---------|---------------------------------|
| `title`    | string | —       | Bold heading text               |
| `body`     | string | —       | Smaller description text        |
| `duration` | number | `3`     | Seconds before auto-dismiss     |

**Notes:**
- Notifications appear in the **bottom-right** of the screen (not the top).
- They **stack upward** when multiple are active at once.
- Each slides in from the right and slides back out to the right when dismissed.
- The left accent bar color matches `THEME.Accent`.

**Example:**
```lua
UIlib.Notify("TKHub", "Loaded successfully!", 4)
UIlib.Notify("Error", "Script failed to execute.", 5)
UIlib.Notify("Done", "WalkSpeed set to 100", 2)
```

---

## 13. SetTheme

```lua
UIlib.SetTheme(colorTable: table)
```

**Merges** a partial or full color table into the active theme. You only need to pass the keys you want to change.

**Note:** `SetTheme` updates the theme table for future elements. It does **not** retroactively repaint existing GUI elements. To change existing colors live, use [`OpenColorEditor`](#15-opencoloreditor) or modify `UIlib.THEME` directly and call `SetTheme` before building your GUI.

**Full theme key list:**

| Key              | Controls                                        |
|------------------|-------------------------------------------------|
| `Background`     | Main window background                          |
| `BackgroundLight`| Title bar, section boxes, textbox fill          |
| `SideBar`        | Sidebar panel background                        |
| `SideBarBtn`     | Sidebar button background                       |
| `SideBarBtnActive` | Active sidebar button highlight               |
| `Accent`         | Title text, scrollbar, slider fill, notif bar   |
| `Text`           | Primary text color                              |
| `TextDim`        | Secondary/label text color                      |
| `ButtonBG`       | Button background                               |
| `ButtonHover`    | Button hover background                         |
| `ToggleOff`      | Toggle pill when off                            |
| `ToggleOn`       | Toggle pill when on                             |
| `SliderBG`       | Slider track background                         |
| `SliderFill`     | Slider fill and thumb                           |
| `SectionHeader`  | Section header pill background                  |
| `Separator`      | Divider line color                              |
| `NotifyBG`       | Notification panel background                   |

**Example:**
```lua
-- Apply a blue theme before creating any windows
UIlib.SetTheme({
    Background       = Color3.fromRGB(10, 15, 30),
    BackgroundLight  = Color3.fromRGB(20, 30, 55),
    Accent           = Color3.fromRGB(80, 140, 255),
    SliderFill       = Color3.fromRGB(80, 140, 255),
    ToggleOn         = Color3.fromRGB(60, 120, 220),
})

local Win = UIlib.MainWindow("My Hub")
```

---

## 14. SetOpacity

```lua
UIlib.SetOpacity(alpha: number)
```

Sets the **overall opacity** of the entire GUI. `1` = fully opaque (default), `0` = invisible, `0.5` = 50% transparent.

| Parameter | Type   | Range | Description        |
|-----------|--------|-------|--------------------|
| `alpha`   | number | 0–1   | Opacity multiplier |

**How it works:**
- On first call, the original `BackgroundTransparency` of every frame is snapshot.
- Subsequent calls lerp between that snapshot and fully transparent.
- Only frames with a non-transparent background are affected (text labels etc. are untouched).

**Example:**
```lua
UIlib.SetOpacity(1.0)   -- fully visible (default)
UIlib.SetOpacity(0.75)  -- slightly see-through
UIlib.SetOpacity(0.5)   -- half transparent
UIlib.SetOpacity(0.0)   -- invisible (GUI exists but frames are see-through)

-- Slider controlling opacity:
UIlib.CreateSlider(Sec, "GUI Opacity %", 10, 100, 100, function(val)
    UIlib.SetOpacity(val / 100)
end)
```

---

## 15. OpenColorEditor

```lua
UIlib.OpenColorEditor(label: string, currentColor: Color3, onDone: function)
```

Opens a **VSCode-style color picker popup** with:
- A **Saturation/Value square** (drag to pick color darkness and intensity)
- A **Hue strip** below (drag left/right to change color hue)
- A **live preview swatch** and hex code
- **Apply** and **Cancel** buttons
- The panel is **draggable**

| Parameter      | Type     | Description                                         |
|----------------|----------|-----------------------------------------------------|
| `label`        | string   | Title shown at the top of the popup                 |
| `currentColor` | Color3   | Starting color pre-loaded into the picker           |
| `onDone`       | function | Called with `(newColor: Color3)` when Apply pressed. Not called if Cancel. |

**Example:**
```lua
-- Simple standalone usage
UIlib.CreateButton(Sec, "Pick Accent Color", function()
    UIlib.OpenColorEditor("Accent", UIlib.THEME.Accent, function(newColor)
        UIlib.THEME.Accent = newColor
        UIlib.Notify("Theme", "Accent updated to #"..newColor:ToHex(), 2)
    end)
end)

-- Typical theme editor row pattern
local KEYS = {"Accent", "Background", "ButtonBG", "ToggleOn"}
for _, key in ipairs(KEYS) do
    UIlib.CreateButton(Sec, "Edit "..key, function()
        UIlib.OpenColorEditor(key, UIlib.THEME[key], function(col)
            UIlib.THEME[key] = col
            UIlib.Notify("Theme", key.." = #"..col:ToHex(), 2)
        end)
    end)
end
```

---

## 16. Destroy

```lua
UIlib.Destroy()
```

**Completely removes** the TKLib ScreenGui from `PlayerGui` and resets all internal state. After calling this:
- The GUI is gone from the screen.
- All window/section references are stale (do not use them).
- You can call `UIlib.MainWindow(...)` again to rebuild from scratch.

**Example:**
```lua
UIlib.CreateButton(DangerSec, "Unload Hub", function()
    _G.__TKHUB_RUNNING = nil
    UIlib.Destroy()
end)
```

---

## 17. UIlib.THEME table

`UIlib.THEME` is the **live theme table**. You can read and write it directly at any time.

```lua
-- Read current accent color
print(UIlib.THEME.Accent)

-- Change a color directly (affects new elements and color editor swatches)
UIlib.THEME.Accent = Color3.fromRGB(255, 100, 0)

-- Use in your own code
local accentColor = UIlib.THEME.Accent
```

The full list of keys is in the [SetTheme](#13-settheme) section.

---

## 18. Keyboard Shortcut

| Keys                        | Action                    |
|-----------------------------|---------------------------|
| `Left Alt` + `Right Shift`  | Toggle GUI visibility on/off |

This is always active once UIlib is loaded. Pressing the combo hides or shows the entire ScreenGui.

---

## 19. Full Example

```lua
local UIlib = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/YOUR/REPO/main/TKLib/Lib/UIlib.lua", true
))()

-- ── Theme ──────────────────────────────────────────────────────
UIlib.SetTheme({
    Accent    = Color3.fromRGB(80, 140, 255),
    SliderFill = Color3.fromRGB(80, 140, 255),
    ToggleOn  = Color3.fromRGB(60, 120, 220),
})

-- ── Windows ────────────────────────────────────────────────────
local Win      = UIlib.MainWindow("Player")
local WinMisc  = UIlib.MainWindow("Misc")
local WinSets  = UIlib.MainWindow("Settings")

-- ── Player window ──────────────────────────────────────────────
local MoveSec = UIlib.Section(Win, "Movement")

local wsSlider = UIlib.CreateSlider(MoveSec, "WalkSpeed", 0, 500, 16, function(v)
    game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = v
end)

local jpSlider = UIlib.CreateSlider(MoveSec, "JumpPower", 0, 500, 50, function(v)
    game.Players.LocalPlayer.Character.Humanoid.JumpPower = v
end)

UIlib.CreateSeparator(MoveSec)

UIlib.CreateToggle(MoveSec, "Infinite Jump", false, function(enabled)
    _G.InfJump = enabled
    if enabled then
        game:GetService("UserInputService").JumpRequest:Connect(function()
            if _G.InfJump then
                game.Players.LocalPlayer.Character.Humanoid:ChangeState(
                    Enum.HumanoidStateType.Jumping
                )
            end
        end)
    end
end)

local TargetSec = UIlib.Section(Win, "Target")

UIlib.CreateDropdown(TargetSec, "Target Player",
    (function()
        local names = {}
        for _, p in ipairs(game.Players:GetPlayers()) do
            table.insert(names, p.Name)
        end
        return names
    end)(),
    function(name)
        UIlib.Notify("Target", "Selected: "..name, 2)
    end
)

UIlib.CreateButton(TargetSec, "Teleport to Target", function()
    UIlib.Notify("Teleport", "Feature coming soon!", 2)
end)

-- ── Misc window ────────────────────────────────────────────────
local ScriptSec = UIlib.Section(WinMisc, "Scripts")

UIlib.CreateButton(ScriptSec, "Infinity Yield", function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"))()
end)

UIlib.CreateButton(ScriptSec, "Dex Explorer", function()
    loadstring(game:HttpGet("https://raw.githubusercontent.com/infyiff/backup/main/dex.lua"))()
end)

-- ── Settings window ────────────────────────────────────────────
local AppSec = UIlib.Section(WinSets, "Appearance")

UIlib.CreateSlider(AppSec, "Opacity %", 10, 100, 100, function(v)
    UIlib.SetOpacity(v / 100)
end)

UIlib.CreateButton(AppSec, "Edit Accent Color", function()
    UIlib.OpenColorEditor("Accent", UIlib.THEME.Accent, function(col)
        UIlib.THEME.Accent = col
        UIlib.Notify("Theme", "Accent = #"..col:ToHex(), 2)
    end)
end)

UIlib.AddSetting(WinSets, "Debug Mode", "toggle", false, function(v)
    _G.DebugMode = v
end)

-- ── Notification on load ───────────────────────────────────────
UIlib.Notify("My Hub", "Loaded! Press LAlt+RShift to hide.", 5)
```

---

## 20. Common Mistakes

### ❌ Passing the window instead of the section

```lua
-- WRONG – passing WindowObj to CreateButton
UIlib.CreateButton(Win, "My Button", function() end)

-- CORRECT – pass the Section frame
local Sec = UIlib.Section(Win, "My Section")
UIlib.CreateButton(Sec, "My Button", function() end)
```

### ❌ Reading `.Value` before the user interacts

```lua
local t = UIlib.CreateToggle(Sec, "Thing", false, nil)
-- t.Value is immediately valid (equals the default)
print(t.Value)  -- false  ✓
```

`.Value` is always set to the default on creation — safe to read immediately.

### ❌ SetTheme after building the GUI

`SetTheme` only affects **new** elements created after the call. Call it before `MainWindow` if you want the whole GUI themed:

```lua
UIlib.SetTheme({ Accent = Color3.fromRGB(255,0,0) })   -- FIRST
local Win = UIlib.MainWindow("Hub")                     -- THEN build
```

### ❌ Calling UIlib functions after Destroy

```lua
UIlib.Destroy()
UIlib.CreateButton(Sec, ...)   -- ERROR – Sec no longer exists
```

After `Destroy`, rebuild from `MainWindow` if you need the GUI again.

### ❌ Forgetting `task.spawn` for blocking operations inside callbacks

```lua
-- WRONG – blocks the Roblox engine thread
UIlib.CreateButton(Sec, "Load", function()
    game:HttpGet("https://...")   -- yields; fine in spawn, not directly
    -- other long work
end)

-- CORRECT
UIlib.CreateButton(Sec, "Load", function()
    task.spawn(function()
        local code = game:HttpGet("https://...")
        loadstring(code)()
    end)
end)
```

---

*TKLib UIlib – documentation last updated for v2.1*
