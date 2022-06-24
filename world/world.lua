local COMMON = require "libs.common"
local GameWorld = require "world.game.game_world"
local TAG = "WORLD"
---@class World
local M = COMMON.class("World")

function M:initialize()
    self.game = GameWorld(self)
    self.debug_state = {
        blur = true,
        move_camera = false,
        draw_physics = false,
        debug_light = false,
        draw_light_map = false,
    }
end

return M()