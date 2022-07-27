local Enums = {}

Enums.align_x = {
	left = "left",
	center = "center",
	right = "right",
}
Enums.align_y = {
	top = "top",
	center = "center",
	bottom = "bottom",
}

Enums.context_type = {
	menu = "Menu",
}

Enums.shape = {
	rect = "Rectangle",
	circle = "Circle",
	triangle = "Triangle",
	line = "Line",
	curve = "Curve",
	polygon = "Polygon",
}

Enums.widget = {
	tree = "Tree",
	window = "Window",
}

Enums.button = {
	close = "Close",
	minimize = "Minimize",
}

Enums.sizer_type = {
	None = 0,
	N = 1,
	E = 2,
	S = 3,
	W = 4,
	NE = 5,
	SE = 6,
	SW = 7,
	NW = 8
}

Enums.cursor_size = {
	NWSE = "sizenwse",
	NESW = "sizenwse",
	WE = "sizewe",
	NS = "sizens",
}

Enums.layers = {
	normal = 1,
	dock = 2,
	context_menu = 3,
	main_menu_bar = 4,
	dialog = 5,
	debug = 6,
	mouse = 7
}

Enums.file_type = {
	openfile = "openfile",
	savefile = "savefile",
	opendirectory = "opendirectory",
}

return Enums
