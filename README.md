# Slab

Slab is an immediate mode GUI toolkit for the Love 2D framework. This library is designed to
allow users to easily add this library to their existing Love 2D projects and quickly create
tools to enable them to iterate on their ideas quickly. The user should be able to utilize this
library with minimal integration steps and is completely written in Lua and utilizes
the Love 2D API. No compiled binaries are required and the user will have access to the source
so that they may make adjustments that meet the needs of their own projects and tools. Refer
to main.lua and SlabTest.lua for example usage of this library.

### Usage

Integrating this library into existing projects is very simple.

```lua
local Slab = require 'Slab'

function love.load(args)
	love.graphics.setBackgroundColor(0.4, 0.88, 1.0)
	Slab.Initialize(args)
end

function love.update(dt)
	Slab.Update(dt)
  
	Slab.BeginWindow('MyFirstWindow', {Title = "My First Window"})
	Slab.Text("Hello World")
	Slab.EndWindow()
end

function love.draw()
	Slab.Draw()
end
```
![](https://github.com/coding-jackalope/Slab/wiki/Images/Slab_HelloWorld.png)

For more detailed information on usage of this library, refer to the [Wiki](https://github.com/coding-jackalope/Slab/wiki).

### License

Slab is licensed under the MIT license. Please see the LICENSE file for more information.

### Credits
* [Dear ImGui](https://github.com/ocornut/imgui) project built by Omar Cornut and various contributors. This project was the inspiration for building an Immediate Mode GUI for Love2D specifically. If anyone is building a game or application in C++, I highly recommend using this library and its rich toolset to speed up development.
* [Kenney.nl](https://kenney.nl/) and the [Tango Desktop Project](https://opengameart.org/content/tango-desktop-icons) for providing icons used in this project.
* [lovefs](https://github.com/linux-man/lovefs) provides some FFI code for the filesystem.
* [luapower/fs](https://github.com/luapower/fs) provides cross platform FFI code for the filesystem.
