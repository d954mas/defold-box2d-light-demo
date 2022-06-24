# Box2Light Demo
Example of box2d raycasting and meshes for 2d light for Defold game engine.

Raycasting rays from light source. Then update mesh based on raycasting
result.Then draw light meshes.

Check this light in game [Mouse Rob]() (TODO ADD LINK)


Based on fork of [libgdx-box2dlights](https://github.com/piotr-j/box2dlights)
Fork added dynamic rays to light source to make light smooth.
https://www.youtube.com/watch?v=24XHJPjpxy4



This is **demo** project **not library** because i think it is not ready
to be library, but you can copy code and use it in you projects.

In this example i load level from tiled. More info [here](https://github.com/d954mas/defold-tiled-example)


[![](https://c5.patreon.com/external/logo/become_a_patron_button.png)](https://www.patreon.com/d954mas)

[PLAY](https://d954mas.github.io/defold-box2d-light-demo/)

# Light

1. Point light(360 degree)
2. Cone light(1-359 degree)

Can't change number of rays in runtime. Because mesh created once.
Use bigger value for dynamic rays.


Light have:
- Position
- Angle
- Color
- Radius
- Rays(static) 
- Rays(dynamic) 
- ...
```lua
game = {}

---@class GameNativeLight
local GameNativeLight = {

}

function GameNativeLight:SetPosition(x,y) end
function GameNativeLight:SetAngle(angle) end
function GameNativeLight:SetColor(r, g, b, a) end
function GameNativeLight:SetRadius(radius) end
function GameNativeLight:SetRaysStatic(rays) end
function GameNativeLight:SetRaysDynamic(rays) end

function GameNativeLight:SetBaseAngles(angle_begin, angle_end) end
function GameNativeLight:PlayerIsHit() end
function GameNativeLight:BufferInit() end
function GameNativeLight:GetBuffer() end
function GameNativeLight:SetPhysicsScale(scale) end
function GameNativeLight:SetPlayerIsHit(hit) end

function GameNativeLight:UpdateHitPlayer(px, py, pw, ph) end
function GameNativeLight:SetStartDrawFraction(startDrawFraction) end

function GameNativeLight:UpdateLight() end

function GameNativeLight:Destroy() end

---@return GameNativeLight
function game.create_light() end
function game.set_world(world) end
function game.set_filter_geometry(filter) end
function game.set_filter_player(filter) end

```

# Render
1. Draw bg. Before light
2. Draw light to light map render target
3. If need it. Blur light map  render target in blur  render target
4. Draw light map to screen. With custom blend and custom material.In material mix light color with ambient color.Ambient color is a color which we see if no light.
```lua
render.enable_texture(0, self.targets.light_map.target, render.BUFFER_COLOR_BIT)
render.set_blend_func(render.BLEND_ONE, render.BLEND_ONE_MINUS_SRC_ALPHA)
render.enable_material("shadow")
render.draw(self.predicates.model_light_map, self.constants_buffers.shadows)
render.disable_material()
```
5. Draw sprites that on top of light. Tiles