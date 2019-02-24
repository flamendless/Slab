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
![](https://github.com/coding-jackalope/Slab/wiki/Images/Slab_Hello_World.gif)

For more detailed information on usage of this library, refer to the [Wiki](https://github.com/coding-jackalope/Slab/wiki).

### License

Slab is licensed under the MIT license. Please see the LICENSE file for more information.
