---@meta

---@class Slab
local Slab = {}


---@class Slab.BeginWindowOptions
---@field X? number
---@field Y? number
---@field W? number
---@field H? number
---@field ContentW? number
---@field ContentH? number
---@field BgColor? table
---@field Title? string
---@field TitleH? number
---@field TitleAlignX? "left" | "center" | "right"
---@field TitleAlignY? "top" | "center" | "bottom"
---@field AllowMove? boolean
---@field AllowResize? boolean
---@field AllowFocus? boolean
---@field Border? number
---@field NoOutline? boolean
---@field IsMenuBar? boolean
---@field AutoSizeWindow? boolean
---@field AutoSizeWindowW? boolean
---@field AutoSizeWindowH? boolean
---@field AutoSizeContent? boolean
---@field Layer? string
---@field ResetPosition? boolean
---@field ResetSize? boolean
---@field ResetContent? boolean
---@field ResetLayout? boolean
---@field SizerFilter? table
---@field CanObstruct? boolean
---@field Rounding? number
---@field IsOpen? boolean
---@field NoSaveSettings? boolean
---@field ConstrainPosition? boolean
---@field ShowMinimize? boolean
---@field ShowScrollbarX? boolean
---@field ShowScrollbarY? boolean

---@param id string
---@param options? Slab.BeginWindowOptions
---@return boolean
Slab.BeginWindow = function(id, options)
end

Slab.EndWindow = function()
end

---@return number, number
Slab.GetWindowPosition = function()
end

---@return number, number
Slab.GetWindowContentSize = function()
end

---@return number, number
Slab.GetWindowActiveSize = function()
end

---@return boolean
Slab.IsWindowAppearing = function()
end

---@param id string
Slab.PushID = function(id)
end

Slab.PopID = function()
end


---@return table
Slab.GetStyle = function()
end

---@param font love.graphics.Font
Slab.PushFont = function(font)
end

Slab.PopFont = function()
end

---@param path string
---@param set boolean
---@return table
Slab.LoadStyle = function(path, set)
end

---@param name string
---@return boolean
Slab.SetStyle = function(name)
end

---@return table
Slab.GetStyleNames = function()
end

---@return string
Slab.GetCurrentStyleName = function()
end

---@return boolean
Slab.BeginMainMenuBar = function()
end

Slab.EndMainMenuBar = function()
end

---@param isMainMenuBar boolean
---@return boolean
Slab.BeginMenuBar = function(isMainMenuBar)
end

---@class Slab.BeginMenuOptions
---@field Enabled? boolean

---@param label string
---@param options? Slab.BeginMenuOptions
---@return boolean
Slab.BeginMenu = function(label, options)
end

Slab.EndMenu = function()
end

---@param button number
---@return boolean
Slab.BeginContextMenuItem = function(button)
end

---@param button number
---@return boolean
Slab.BeginContextMenuWindow = function(button)
end

Slab.EndContextMenu = function()
end

---@class Slab.MenuItemOptions
---@field Enabled? boolean

---@param label string
---@param options? Slab.MenuItemOptions
Slab.MenuItem = function(label, options)
end

---@class Slab.MenuItemCheckedOptions
---@field Enabled? boolean

---@param label string
---@param isChecked boolean
---@param options? Slab.MenuItemCheckedOptions
---@return boolean
Slab.MenuItemChecked = function(label, isChecked, options)
end

---@param id string
Slab.OpenDialog = function(id)
end

---@param id string
---@param options Slab.BeginWindowOptions
Slab.BeginDialog = function(id, options)
end

Slab.EndDialog = function()
end

Slab.CloseDialog = function()
end

---@class Slab.MessageBoxOptions
---@field Button? table

---@param title string
---@param message string
---@param options? Slab.MessageBoxOptions
---@return string
Slab.MessageBox = function(title, message, options)
end

---@class Slab.FileDialogOptions
---@field Directry? string
---@field Type? string
---@field Filters? table
---@field IncludeParent? boolean

---@param options Slab.FileDialogOptions
---@return table
Slab.FileDialog = function(options)
end

---@class Slab.ColorPickerOptions
---@field Color? table

---@param options Slab.ColorPickerOptions
---@return table
Slab.ColorPicker = function(options)
end

---@param list string | table
Slab.EnableDocks = function(list)
end

---@param list string | table
Slab.DisableDocks = function(list)
end

---@class Slab.SetDockOptionsOptiond
---@field NoSaveSettings? boolean

---@param options Slab.SetDockOptionsOptiond
Slab.SetDockOptions = function(options)
end

---@param type string
Slab.WindowToDock = function(type)
end

---@class Slab.ButtonOptions
---@field Tooltip? string
---@field Rounding? number
---@field Invisible? boolean
---@field W? number
---@field H? number
---@field Disable? boolean
---@field Image? table
---@field Color? table
---@field HoverColor? table
---@field PressColor? table
---@field PadX? number
---@field PadY? number
---@field VLines? number

---@param label string
---@param options? Slab.ButtonOptions
---@return boolean
Slab.Button = function(label, options)
end

---@class Slab.RadioButtonOptions
---@field Index? number
---@field SelectedInxex? number
---@field Tooltip? string

---@param label string
---@param options? Slab.RadioButtonOptions
---@return boolean
Slab.RadioButton = function(label, options)
end

---@class Slab.TextOptions
---@field Color? table
---@field Pad? number
---@field IsSelectable? boolean
---@field IsSelectableTextOnly? boolean
---@field IsSelected? boolean
---@field SleectOnHover? boolean
---@field HoverColor? table

---@param label string
---@param options? Slab.TextOptions
---@return boolean
Slab.Text = function(label, options)
end

---@param label string
---@param options Slab.TextOptions
---@return boolean
Slab.TextSelectable = function(label, options)
end

---@class Slab.TextfOptions
---@field Color table
---@field W number
---@field Align "left" | "center" | "right"

---@param label string
---@param options Slab.TextOptions
Slab.Textf = function(label, options)
end

---@param label string
---@return number, number
Slab.GetTextSize = function(label)
end

---@param label string
---@return number
Slab.GetTextWidth = function(label)
end

---@return number
Slab.GetTextHeight = function()
end

---@class Slab.CheckBoxOptions
---@field Tooltip? string
---@field Id? string
---@field Rounding? number
---@field Size? number
---@field Disable? boolean

---@param enabled boolean
---@param label string
---@param options? Slab.CheckBoxOptions
---@return boolean
Slab.CheckBox = function(enabled, label, options)
end

---@class Slab.InputOptions
---@field Tooltip? string
---@field ReturnOnTexy? boolean
---@field Text? string | number
---@field TextColor? table
---@field BgColor? table
---@field SelectColor? table
---@field SelectOnFocus? boolean
---@field NumberOnly? boolean
---@field W? number
---@field H? number
---@field ReadOnly? boolean
---@field Align? "left" | "center" | "right"
---@field Rounding? number
---@field MinNumber? number
---@field MaxNumber? number
---@field MultiLine? boolean
---@field MultiLineW? number
---@field Highlight? table
---@field Step? number
---@field NoDrag? boolean
---@field UseSlider? boolean
---@field IsPassword? boolean
---@field PasswordChar? string

---@param id string
---@param options? Slab.InputOptions
---@return boolean
Slab.Input = function(id, options)
end

---@param id string
---@param value number
---@param min number
---@param max number
---@param step number
---@param options Slab.InputOptions
Slab.InputNumberDrag = function(id, value, min, max, step, options)
end

---@return string
Slab.GetInputText = function()
end

---@return number
Slab.GetInputNumber = function()
end

---@return number, number, number
Slab.GetInputCursorPos = function()
end

---@param id string
---@return boolean
Slab.IsInputFocused = function(id)
end

---@return boolean
Slab.IsAnyInputFocused = function()
end

---@param id string
Slab.SetInputFocus = function(id)
end

---@param pos number
Slab.SetInputCursorPos = function(pos)
end

---@param column number
---@param line number
Slab.SetInputCursorPosLine = function(column, line)
end

---@class Slab.BeginTreeOptions
---@field Label? string
---@field Tooltip? string
---@field IsLeaf? boolean
---@field OpenWithHighlight? boolean
---@field icon? table
---@field IsSelected? boolean
---@field IsOpen? boolean
---@field NoSaveSettings? boolean

---@param id string
---@param options? Slab.BeginTreeOptions
---@return boolean
Slab.BeginTree = function(id, options)
end

Slab.EndTree = function()
end

---@class Slab.BeginComboBoxOptions
---@field Tooltip? string
---@field Selected? string
---@field W? number
---@field Rounding? number

---@param id string
---@param options? Slab.BeginComboBoxOptions
---@return boolean
Slab.BeginComboBox = function(id, options)
end

Slab.EndComboBox = function()
end

---@class Slab.ImageOptions
---@field Image? love.graphics.Image
---@field Path? string
---@field Rotation? number
---@field Scale? number
---@field ScaleY? number
---@field ScaleX? number
---@field Color? table
---@field SubX? number
---@field SubY? number
---@field SubW? number
---@field SubH? number
---@field WrapX? string
---@field WrapY? string
---@field UseOutline? boolean
---@field OutlineColor? table
---@field OutlineWidth? number
---@field W? number
---@field H? number

---@param id string
---@param options? Slab.ImageOptions
Slab.Image = function(id, options)
end

---@class Slab.BeginListBoxOptions
---@field W? number
---@field H? number
---@field Clear? boolean
---@field Rounding? number
---@field StretchW? boolean
---@field StretchH? boolean

---@param id string
---@param options? Slab.BeginListBoxOptions
Slab.BeginListBox = function(id, options)
end

Slab.EndListBox = function()
end

---@class Slab.BeginListBoxItemOptions
---@field Selected? boolean

---@param id string
---@param options? Slab.BeginListBoxItemOptions
Slab.BeginListBoxItem = function(id, options)
end

---@param button number
---@param isDoubleClick boolean
Slab.IsListBoxItemClicked = function(button, isDoubleClick)
end

Slab.EndListBoxItem = function()
end

---@class Slab.RectangleOptions
---@field Mode? string
---@field W? number
---@field H? number
---@field Color? table
---@field Rounding? number | table
---@field Outline? boolean
---@field OutlineColor? table
---@field Segment? number

---@param options? Slab.RectangleOptions
Slab.Rectangle = function(options)
end

---@class Slab.CircleOptions
---@field Mode? string
---@field Radius? number
---@field Color? table
---@field Segment? number

---@param options? Slab.CircleOptions
Slab.Circle = function(options)
end

---@class Slab.TriangleOptions
---@field Mode? string
---@field Radius? number
---@field Rotation? number
---@field Color? table

---@param options? Slab.TriangleOptions
Slab.Triangle = function(options)
end

---@class Slab.LineOptions
---@field Width? number
---@field Color? table

---@param x2 number
---@param y2 number
---@param options? Slab.LineOptions
Slab.Line = function(x2, y2, options)
end

---@class Slab.CurveOptions
---@field Color? table
---@field Depth? number

---@param point table
---@param options? Slab.CurveOptions
Slab.Curve = function(point, options)
end

---@return number
Slab.GetCurveControlPointCount = function()
end

---@return number, number
Slab.GetCurveControlPoint = function()
end

---@class Slab.EvaluateCurveOptions
---@field LocalSpace? boolean

---@param time number
---@param options? Slab.EvaluateCurveOptions
---@return number, number
Slab.EvaluateCurve = function(time, options)
end

---@param options? Slab.EvaluateCurveOptions
---@return number, number
Slab.EvaluateCurveMouse = function(options)
end

---@class Slab.PolygonOptions
---@field Color? table
---@field Mode? string

---@param points table
---@param options? Slab.PolygonOptions
Slab.Polygon = function(points, options)
end

---@param number number
Slab.SetScrollSpeed = function(number)
end

---@return number
Slab.GetScrollSpeed = function()
end

---@class Slab.SeparatorOptions
---@field IncudeBorders? boolean
---@field H? number
---@field Thickness? number

---@param options? Slab.SeparatorOptions
Slab.Separator = function(options)
end

---@param shader love.graphics.Shader
Slab.PushShader = function(shader)
end

Slab.PopShader = function()
end

---@param table table
---@param options table
---@param fallback table
Slab.Properties = function(table, options, fallback)
end

---@param n? number
Slab.NewLine = function(n)
end

---@class Slab.SameLineOptions
---@field Pad? number
---@field CenterY? boolean

---@param options? Slab.SameLineOptions
Slab.SameLine = function(options)
end

---@class Slab.SetCursorPosOptions
---@field Absolute? boolean

---@param x number
---@param y number
---@param options Slab.SetCursorPosOptions
Slab.SetCursorPos = function(x, y, options)
end

---@param width number
Slab.Indent = function(width)
end

---@param width number
Slab.UnIndent = function(width)
end

---@param button number | 1 | 2 | 3
---@return boolean
Slab.IsMouseDown = function(button)
end

---@param button number | 1 | 2 | 3
---@return boolean
Slab.IsMouseClicked = function(button)
end

---@param button number | 1 | 2 | 3
---@return boolean
Slab.IsMouseReleased = function(button)
end

---@param button number | 1 | 2 | 3
---@return boolean
Slab.IsMouseDoubleClicked = function(button)
end

---@param button number | 1 | 2 | 3
---@return boolean
Slab.IsMouseDragging = function(button)
end

---@return number, number
Slab.GetMousePosition = function()
end

---@return number, number
Slab.GetMousePositionWindow = function()
end

---@return number, number
Slab.GetMouseDelta = function()
end

---@alias CursorCustomType
---| "arrow"
---| "sizewe"
---| "sizens"
---| "sizenesw"
---| "ibeam"
---| "hand"

---@param type CursorCustomType
---@param image love.graphics.Image
---@param quad love.graphics.Quad
Slab.SetCustomMouseCursor = function(type, image, quad)
end

---@param type CursorCustomType
Slab.ClearCustomMouseCursor = function(type)
end

---@return boolean
Slab.IsControlHovered = function()
end

---@param button number | 1 | 2 | 3
---@return boolean
Slab.IsControlClicked = function(button)
end

---@return number, number
Slab.GetControlSize = function()
end

---@return boolean
Slab.IsVoidHovered = function()
end

---@param button number | 1 | 2 | 3
---@return boolean
Slab.IsVoidClicked = function(button)
end

---@param key string
---@return boolean
Slab.IsKeyDown = function(key)
end

---@param key string
---@return boolean
Slab.IsKeyPressed = function(key)
end

---@param key string
---@return boolean
Slab.IsKeyReleased = function(key)
end

---@class Slab.BeginLayoutOptions
---@field AlignX? "left" | "center" | "right"
---@field AlignY? "top" | "center" | "botton"
---@field AlignRowY? "top" | "center" | "botton"
---@field Ignore? boolean
---@field ExpandW? boolean
---@field ExpandH? boolean
---@field AnchorX? boolean
---@field AnchorT? boolean
---@field Columns? number

---@param id string
---@param options? Slab.BeginLayoutOptions
Slab.BeginLayout = function(id, options)
end

Slab.EndLayout = function()
end

---@param index number
Slab.SetLayoutColumn = function(index)
end

---@return number, number
Slab.GetLayoutSize = function()
end

---@return number
Slab.GetCurrentColumnIndex = function()
end

---@param args table
Slab.Initialize = function(args)
end

---@return string
Slab.GetVersion = function()
end

---@return string
Slab.GetLoveVersion = function()
end

---@param dt number
Slab.Update = function(dt)
end

Slab.Draw = function()
end

---@param isVerbose boolean
Slab.SetVerbose = function(isVerbose)
end

---@param name string
---@param category string
---@return number
Slab.BeginStat = function(name, category)
end

---@param number number
Slab.EndStat = function(number)
end

---@param enable boolean
Slab.EnableStats = function(enable)
end

---@return boolean
Slab.IsStatsEnabled = function()
end

---@return table
Slab.GetStats = function()
end

---@param loveStats table
---@return table
Slab.CalculateStats = function(loveStats)
end

---@param path string
Slab.SetINIStatePath = function(path)
end

---@return string
Slab.GetINIStatePath = function()
end

---@return table
Slab.GetMassages = function()
end
