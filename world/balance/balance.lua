local COMMON = require "libs.common"

---@class Balance
local Balance = {
    physics_scale = 1 / 32, --tile is 2 meter
    physics_gravity = vmath.vector3(0, -60, 0),
    tile_size = 64,
    velocity_x_limit = 18,
    velocity_x_air_limit = 16,
    player_speed_increase = 400,
    player_speed_decrease_scale = 1.5,
    air_power = 40000,
    jump_power = vmath.vector3(0, -500, 0),
    jump_power_impulse = vmath.vector3(0, 400, 0),
}


return Balance