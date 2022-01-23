--[[

MIT License

Copyright (c) 2019-2021 Love2D Community <love2d.org>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

--]]

local insert = table.insert
local remove = table.remove
local min = math.min
local max = math.max
local floor = math.floor
local gmatch = string.gmatch
local find = string.find
local sub = string.sub
local format = string.format

local Button = require(SLAB_PATH .. ".Internal.UI.Button")
local ComboBox = require(SLAB_PATH .. ".Internal.UI.ComboBox")
local Cursor = require(SLAB_PATH .. ".Internal.Core.Cursor")
local DrawCommands = require(SLAB_PATH .. ".Internal.Core.DrawCommands")
local FileSystem = require(SLAB_PATH .. ".Internal.Core.FileSystem")
local Image = require(SLAB_PATH .. ".Internal.UI.Image")
local Input = require(SLAB_PATH .. ".Internal.UI.Input")
local Keyboard = require(SLAB_PATH .. ".Internal.Input.Keyboard")
local LayoutManager = require(SLAB_PATH .. ".Internal.UI.LayoutManager")
local ListBox = require(SLAB_PATH .. ".Internal.UI.ListBox")
local Mouse = require(SLAB_PATH .. ".Internal.Input.Mouse")
local Region = require(SLAB_PATH .. ".Internal.UI.Region")
local Style = require(SLAB_PATH .. ".Style")
local Text = require(SLAB_PATH .. ".Internal.UI.Text")
local Tree = require(SLAB_PATH .. ".Internal.UI.Tree")
local Utility = require(SLAB_PATH .. ".Internal.Core.Utility")
local Window = require(SLAB_PATH .. ".Internal.UI.Window")

local Dialog = {}

local active_instance
local fd_ask_overwrite = false
local filter_w = 0
local instances, stack, instance_stack = {}, {}, {}
local modes = {
	opendirectory = "opendirectory",
	savefile = "savefile",
}

local function ValidateSaveFile(files, ext)
	if not ext or ext == "" then return end
	if not files or #files ~= 1 then return end
	local i = find(files[1], ".", 1, true)
	if i then
		files[1] = sub(files[1], 1, i - 1)
	end
	files[1] = files[1] .. ext
end

local STR_MULTIPLE = "<Multiple>"
local STR_EMPTY = ""
local STR_OK = "OK"
local STR_CANCEL = "Cancel"

local function UpdateInputText(instance)
	if not instance then return end
	if #instance.Return > 0 then
		instance.Text = #instance.Return > 1 and STR_MULTIPLE or instance.Return[1]
	else
		instance.Text = STR_EMPTY
	end
end

local function PruneResults(items, dir_only)
	local res = {}
	if #items == 0 then return res end
	for _, v in ipairs(items) do
		if FileSystem.IsDirectory(v) and dir_only then
			insert(res, v)
		elseif not dir_only then
				insert(res, v)
		end
	end
	return res
end

local function OpenDirectory(dir)
	if active_instance and active_instance.Directory then
		active_instance.Parsed = false
		local len_dir = #instance.Directories
		if sub(dir, len_dir, len_dir) == FileSystem.Separator() then
			dir = sub(dir, 1, len_dir - 1)
		end
		active_instance.Directory = FileSystem.Sanitize(dir)
	end
end

local TBL_CENTERY = {CenterY = true}
local function FileDialogItem(id, label, is_dir, index)
	ListBox.BeginItem(id, {Selected = Utility.HasValue(active_instance.Selected, index)})

	if is_dir then
		local fh = Style.Font:getHeight()
		Image.Begin("FileDialog_Folder", {
			Path = SLAB_FILE_PATH .. "/Internal/Resources/Textures/Icons.png",
			SubX = 0, SubY = 0,
			SubW = 50, SubH = 50,
			W = fh, H = fh
		})
		Cursor.SameLine(TBL_CENTERY)
	end
	Text.Begin(label)

	if ListBox.IsItemClicked(1) then
		local set = true
		if active_instance.AllowMultiSelect then
			local len_selected = #active_instance.Selected
			if Keyboard.IsDown("lctrl") or Keyboard.IsDown("rctrl") then
				set = false
				if Utility.HasValue(active_instance.Selected, index) then
					Utility.Remove(active_instance.Selected, index)
					Utility.Remove(active_instance.Return, active_instance.Directory .. "/" .. label)
				else
					insert(active_instance.Selected, index)
					insert(active_instance.Return, active_instance.Directory .. "/" .. label)
				end
			elseif Keyboard.IsDown("lshift") or Keyboard.IsDown("rshift") and len_selected > 0 then
				set = false
				local anchor = active_instance.Selected[len_selected]
				local v_min = min(anchor, index)
				local v_max = max(anchor, index)

				Utility.ClearTable(active_instance.Selected)
				Utility.ClearTable(active_instance.Return)
				for i = v_min, v_max do
					insert(active_instance.Selected, i)
					local len_dir = #active_instance.Directories
					if i > len_dir then
						i = i - len_dir
						insert(active_instance.Return, active_instance.Directory .. "/" .. active_instance.Files[i])
					else
						insert(active_instance.Return, active_instance.Directory .. "/" .. active_instance.Directories[i])
					end
				end
			end
		end

		if set then
			active_instance.Selected = {index}
			active_instance.Return = {active_instance.Directory .. "/" .. label}
		end
		UpdateInputText(active_instance)
	end

	local res = false
	if ListBox.IsItemClicked(1, true) then
		if is_dir then
			OpenDirectory(active_instance.Directory .. "/" .. label)
		else
			res = true
		end
	end
	ListBox.EndItem()
	return res
end

local function AddDirectoryItem(path)
	local sep = FileSystem.Separator()
	local base = FileSystem.GetBaseName(path)
	local item = {
		Path = path,
		Name = base == "" and sep or base,
		Children = nil,
	}
	-- Remove the starting slash for Unix style directories.
	if sub(item.Name, 1, 1) == sep and item.Name ~= sep then
		item.Name = sub(item.Name, 2)
	end
	return item
end

local TBL_FILES = {Files = false}
local function FileDialogExplorer(instance, root)
	if not instance or not root then return end
	local should_open = Window.IsAppearing() and
		find(instance.Directory, root.Path, 1, true)
	local opt = {
		label = root.Name,
		OpenWithHighlight = false,
		IsSelected = active_instance.Directory == root.Path,
		IsOpen = should_open
	}
	local is_open = Tree.Begin(root.Path, opt)
	if Mouse.IsClicked(1) and Window.IsItemHot() then
		OpenDirectory(root.Path)
	end
	if not is_open then return end

	if root.Children then
		Utility.ClearTable(root.Children)
		local sep = FileSystem.Separator()
		local dirs = FileSystem.GetDirectoryItems(root.Path .. sep, TBL_FILES)
		for _, v in ipairs(dirs) do
			local path = root.Path
			if sub(path, #path) ~= sep and path ~= sep then
				path = path .. sep
			end
			if sub(v, 1, 1) == sep then
				v = sub(v, 2)
			end
			local item = AddDirectoryItem(path .. FileSystem.GetBaseName(v))
			insert(root.Children, item)
		end

		for _, v in ipairs(root.Children) do
			FileDialogExplorer(instance, v)
		end
		Tree.End()
	end
end

local STR_FILTER = "*.*"
local function GetFilter(instance, index)
	local filter = STR_FILTER
	local desc = "All Files"
	if not (instance and #instance.Filters > 0) then return filter, desc end

	if not index then
		index = instance.SelectedFilter
	end
	local item = instance.Filters[index]
	if not item then return filter, desc end
	if type(item) == "table" then
		local len_item = #item
		if len_item == 1 then
			filter = item[1]
			desc = STR_EMPTY
		elseif len_item == 2 then
			filter = item[1]
			desc = item[2]
		end
	else
		filter = tostring(item)
		desc = STR_EMPTY
	end
	return filter, desc
end

local function GetExtension(instance)
	local filter = GetFilter(instance)
	local res = STR_EMPTY
	if filter == STR_FILTER then return res end
	local index = find(filter, ".", 1, true)
	if index then
		res = sub(filter, index)
	end
	return res
end

local function IsInstanceOpen(id)
	local instance = instances[id]
	return instance and instance.IsOpen or false
end

local function GetInstance(id)
	if not instances[id] then
		local instance = {
			Id = id,
			IsOpen = false,
			Opening = false,
			W = 0,
			H = 0,
		}
		instances[id] = instance
	end
	return instances[id]
end

local TBL_EMPTY = {}
function Dialog.Begin(id, opt)
	local instance = GetInstance(id)
	if not instance.IsOpen then return false end

	opt = opt or TBL_EMPTY
	opt.x = floor(love.graphics.getWidth() * 0.5 - instance.W * 0.)
	opt.y = floor(love.graphics.getHeight() * 0.5 - instance.H * 0.)
	opt.layer = DrawCommands.layers.dialog
	opt.allow_focus, opt.allow_move = false, false
	opt.auto_size_window = opt.AutoSizeWindow ~= false
	opt.no_saved_settings = true
	Window.Begin(instance.Id, opt)

	if instance.Opening then
		Input.SetFocused()
		instance.Opening = false
	end
	active_instance = instance
	insert(instance_stack, 1, active_instance)
	return true
end

function Dialog.End()
	active_instance.W, active_instance.H = Window.GetSize()
	Window.End()
	active_instance = remove(instance_stack, 1)
end

function Dialog.Open(id)
	local instance = GetInstance(id)
	if instance.IsOpen then return end
	instance.Opening = true
	instance.IsOpen = true
	insert(stack, 1, instance)
	Window.SetStackLock(instance.Id)
	Window.PushToTop(instance.Id)
end

function Dialog.Close()
	if not active_instance or not active_instance.IsOpen then return end
	active_instance.IsOpen = false
	local instance = remove(stack, 1)
	Window.SetStackLock(instance and instance.Id)
	Window.PushToTop(instance and instance.Id)
end

function Dialog.IsOpen()
	return #stack > 0
end

local STR_MESSAGEBOX = "MessageBox"
local TBL_MB = {Title = nil, Border = 12}
local TBL_OK = {"OK"}
local TBL_ALIGN = {AlignX = "center", AlignY = "center"}
local TBL_ALIGN_B = {AlignX = "right", AlignY = "bottom"}
function Dialog.MessageBox(title, message, opt)
	local res = STR_EMPTY
	Dialog.Open(STR_MESSAGEBOX)
	TBL_MB.Title = title
	if Dialog.Begin(STR_MESSAGEBOX, TBL_MB) then
		opt = opt or TBL_EMPTY
		opt.Buttons = opt.Buttons or TBL_OK
		LayoutManager.Begin("MessageBox_Message_Layout", TBL_ALIGN)
		LayoutManager.NewLine()
		local tw = min(Text.GetWidth(message), love.graphics.getWidth() * 0.8)
		Text.BeginFormatted(message, {Align = "center", W = tw})
		LayoutManager.End()
		Cursor.NewLine(2)
		LayoutManager.Begin("MessageBox_Buttons_Layout", TBL_ALIGN_B)
		for _, v in ipairs(opt.Buttons) do
			if Button.Begin(v) then
				res = v
			end
			Cursor.SameLine()
			LayoutManager.SameLine()
		end
		LayoutManager.End()

		if res ~= STR_EMPTY then
			Dialog.Close()
		end

		Dialog.End()
	end
	return res
end

local TBL_FILTERS = {{"*.*", "All Files"}}
local TBL_RES = {Button = "", Files = {}}
local TBL_FD = {AutoSizeWindow = false, AutoSizeContent = false, AllowResize = false}
local TBL_UP = {
	Path = SLAB_FILE_PATH .. "/Internal/Resources/Textures/Icons.png",
	SubX = 50, SubY = 0,
	SubW = 50, SubH = 50
}
local COLOR_BLACK = {0, 0, 0, 0}
local TBL_TOKEN = {IsSelectableTextOnly = true}
local TBL_IS_SEL = {IsSelectable = true}
local TBL_FD_LB = {AnchorX = true, ExpandW = true}
local TBL_BUTTONS = {Buttons = {"Cancel", "No", "Yes"}}
local STR_ASK = "Are you sure you would like to overwrite file "

function Dialog.FileDialog(opt)
	opt = opt or TBL_EMPTY
	local allow_multi_select = opt.All or true
	local dir = opt.Directory
	local fdt = opt.Type or "openfile"
	local title = opt.Title
	local filters = opt.Filters or TBL_FILTERS
	local include_p = opt.IncludeParent or true

	if not fdt then
		if fdt == modes.savefile then
			allow_multi_select = false
			title = "Save File"
		elseif fdt == modes.opendirectory then
			title = "Open Directory"
		else
			title = "Open File"
		end
	end

	local res = TBL_RES
	local was_open = IsInstanceOpen("FileDialog")
	Dialog.Open("FileDialog")
	local w = love.graphics.getWidth() * 0.65
	local h = love.graphics.getHeight() * 0.65

	TBL_FD.Title = title
	TBL_FD.W, TBL_FD.H = w, h

	if Dialog.Begin("FileDialog", TBL_FD) then
		active_instance.AllowMultiSelect = allow_multi_select
		if not was_open then
			active_instance.Text = STR_EMPTY
			if not active_instance.Directory then
				active_instance.Directory = love.filesystem.getSourceBaseDirectory()
			end
			if dir and FileSystem.IsDirectory(dir) then
				active_instance.Directory = dir
			end
			active_instance.Filters = filters
			active_instance.SelectedFilter = 1
		end

		local clear = false
		if not active_instance.Parsed then
			local filter = GetFilter(active_instance)
			active_instance.Root = AddDirectoryItem(FileSystem.GetRootDirectory(active_instance.Directory))
			active_instance.Selected = {}
			local a_dir = active_instance.Directory .. "/"
			active_instance.Directories = FileSystem.GetDirectoryItems(a_dir, TBL_FILES)
			active_instance.Files = FileSystem.GetDirectoryItems(a_dir,
				{Directories = false, Filter = filter})
			active_instance.Return = {a_dir}
			active_instance.Text = STR_EMPTY
			active_instance.Parsed = true
			UpdateInputText(active_instance)

			for i, v in ipairs(active_instance.Directories) do
				active_instance.Directories[i] = FileSystem.GetBaseName(v)
			end
			for i, v in ipairs(active_instance.Files) do
				active_instance.Files[i] = FileSystem.GetBaseName(v)
			end
			clear = true
		end

		local _, wh = Window.GetSize()
		local _, bh = Button.GetSize(STR_OK)
		local explorer_w = 150
		local list_h = wh - Text.GetHeight() - bh * 3 - Cursor.PadY() * 2
		local prev_ax = Cursor.GetAnchorX()

		-- Parent directory button for quick access
		local fh = Style.Font:getHeight()

		if Button.Begin(STR_EMPTY, {
			Image = TBL_UP,
			Color = COLOR_BLACK,
			PadX = 2, PadY = 2, W = fh, H = fh
		}) then
			local str_dest = format("%s%s..", active_instance.Directory, FileSystem.Separator())
			local dest = FileSystem.Sanitize(str_dest)

			-- Only attempt to move to parent directory if not the root drive.
			if not FileSystem.IsDrive(dest) then
				OpenDirectory(dest)
			end
		end

		Cursor.SameLine()
		local cx, cy = Cursor.GetPosition()
		local rw = Window.GetRemainingSize()
		local mx, my = Window.GetMousePosition()
		Region.Begin("FileDialog_BreadCrumbs", {
			X = cx,
			Y = cy,
			W = rw,
			H = fh,
			AutoSizeContent = true,
			NoBackground = true,
			Intersect = true,
			MouseX = mx,
			MouseY = my,
			IsObstructed = Window.IsObstructedAtMouse(),
			Rounding = Style.Rounding,
			IgnoreScroll = true
		})

		-- Add some padding from left border. The cursor internally adds it"s own padding.
		Cursor.AdvanceX(0)

		-- Gather each directory name and render as bread crumbs on top of each view.
		local sep = FileSystem.Separator()
		local tokens = {}
		local str = format("([^%s]+)", sep)
		for token in gmatch(active_instance.Directory, str) do
			insert(tokens, token)
		end

		for i, token in ipairs(tokens) do
			local id = token .. "_Crumb"
			Window.PushID(id)
			local clicked = Text.Begin(token, TBL_TOKEN)
			if i < #tokens then
				Cursor.SameLine()
				Image.Begin(id, {
					Path = TBL_UP.Path,
					SubX = 100, SubY = 0,
					SubW = 50, SubH = 50,
					W = fh, H = fh
				})
				Cursor.SameLine()
			end

			if clicked then
				local dest
				for j = 1, i do
					dest = dest and (dest .. sep .. tokens[j]) or tokens[j]
				end
				if dest then
					OpenDirectory(dest)
				end
			end
			Window.PopID()
		end

		-- Move the region"s scrollable area to always have the current directory in view.
		local content_w = Region.GetContentSize()
		Region.ResetTransform()
		Region.Translate(nil, min(rw - content_w - 4, 0), 0)
		Region.End()
		Region.ApplyScissor()
		cx, cy = Cursor.GetPosition()
		mx, my = Window.GetMousePosition()
		Region.Begin("FileDialog_DirectoryExplorer", {
			X = cx, Y = cy, W = explorer_w, H = list_h,
			AutoSizeContent = true, NoBackground = true,
			Intersect = true, MouseX = mx, MouseY = my,
			IsObstructed = Window.IsObstructedAtMouse(),
			Rounding = Style.WindowRounding
		})
		Cursor.AdvanceX(0)
		Cursor.SetAnchorX(Cursor.GetX())
		FileDialogExplorer(active_instance, active_instance.Root)
		Region.End()
		Region.ApplyScissor()
		Cursor.AdvanceX(explorer_w + 4)
		Cursor.SetY(cy)

		LayoutManager.Begin("FileDialog_ListBox_Expand", TBL_FD_LB)
		ListBox.Begin("FileDialog_ListBox", {H = list_h, Clear = clear})

		local index, item_selected = 1, false
		if include_p then
			item_selected = FileDialogItem("Item_Parent", "..", true, index) or item_selected
			index = index + 1
		end

		for _, v in ipairs(active_instance.Directories) do
			FileDialogItem("Item_" .. index, v, true, index)
			index = index + 1
		end

		if fdt ~= modes.opendirectory then
			for _, v in ipairs(active_instance.Files) do
				if FileDialogItem("Item_" .. index, v, false, index) then
					item_selected = true
				end
				index = index + 1
			end
		end
		ListBox.End()
		LayoutManager.End()

		local lbx, _, lbw, _ = Cursor.GetItemBounds()
		local iw = lbx + lbw - prev_ax - filter_w - Cursor.PadX()
		Cursor.SetAnchorX(prev_ax)
		Cursor.SetX(prev_ax)

		local read_only = fdt ~= modes.savefile
		if Input.Begin("FileDialog_Input", {
				W = iw, ReadOnly = read_only,
				Text = active_instance.Text,
				Align = "left"
			}) then
			active_instance.Text = Input.GetText()
			active_instance.Return[1] = active_instance.Text
		end
		Cursor.SameLine()

		local filter, desc = GetFilter(active_instance)
		local str_sel = format("%s %s", filter, desc)
		if ComboBox.Begin("FileDialog_Filter", {
				Selected = str_sel
			}) then
			for i in ipairs(active_instance.Filters) do
				filter, desc = GetFilter(active_instance, i)
				local str_sel = format("%s %s", filter, desc)
				if Text.Begin(str_sel, TBL_IS_SEL) then
					active_instance.SelectedFilter = i
					active_instance.Parsed = false
				end
			end
			ComboBox.End()
		end

		local _, _, f_cbw, _ = Cursor.GetItemBounds()
		filter_w = f_cbw
		LayoutManager.Begin("FileDialog_Buttons_Layout", TBL_ALIGN_B)

		if Button.Begin(STR_OK) or item_selected then
			local opening_dir = false

			if #active_instance.Return == 1 and fdt ~= modes.opendirectory then
				local path = active_instance.Return[1]
				if FileSystem.IsDirectory(path) then
					opening_dir = true
					OpenDirectory(path)
				elseif fdt == modes.savefile then
					if FileSystem.Exists(path) then
						fd_ask_overwrite = true
						opening_dir = true
					end
				end
			end

			if not opening_dir then
				res.Button = STR_OK
				res.Files = PruneResults(active_instance.Return, fdt == modes.opendirectory)
				if fdt == modes.savefile then
					ValidateSaveFile(res.Files, GetExtension(active_instance))
				end
			end
		end

		Cursor.SameLine()
		LayoutManager.SameLine()

		if Button.Begin("Cancel") then
			res.Button = "Cancel"
		end
		LayoutManager.End()

		if fd_ask_overwrite then
			local filename = #active_instance.Return > 0 and active_instance.Return[1] or STR_EMPTY
			local ask_overwrite = Dialog.MessageBox("Overwriting", STR_ASK .. filename, TBL_BUTTONS)

			if ask_overwrite ~= STR_EMPTY then
				if ask_overwrite == "No" then
					res.Button = STR_CANCEL
					Utility.ClearTable(res.Files)
				elseif ask_overwrite == "Yes" then
					res.Button = STR_OK
					res.Files = PruneResults(active_instance.Return, fdt == modes.opendirectory)
				end
				fd_ask_overwrite = false
			end
		end

		if res.Button ~= STR_EMPTY then
			active_instance.Parsed = false
			Dialog.Close()
		end
		Dialog.End()
	end

	return res
end

return Dialog
