local Const = {
	SLAB_PATH = (...):match("(.-)[^%.]+$"),
	SLAB_FILE_PATH = debug.getinfo(1, "S").source:match("^@(.+)/"),
}

Const.SLAB_FILE_PATH = Const.SLAB_FILE_PATH == nil and "" or Const.SLAB_FILE_PATH

return Const
