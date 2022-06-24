local M = {}

--ecs systems created in require.
--so do not cache then

-- luacheck: push ignore require

local require_old = require
local require_no_cache
local require_no_cache_name
require_no_cache = function(k)
	require = require_old
	local m = require_old(k)
	if (k == require_no_cache_name) then
		--        print("load require no_cache_name:" .. k)
		package.loaded[k] = nil
	end
	require_no_cache_name = nil
	require = require_no_cache
	return m
end

local creator = function(name)
	return function(...)
		require_no_cache_name = name
		local system = require_no_cache(name)
		if (system.init) then system.init(system, ...) end
		return system
	end
end

require = creator

M.AutoDestroySystem = require "world.game.ecs.systems.auto_destroy_system"
M.InputSystem = require "world.game.ecs.systems.input_system"
M.InputPlayerSystem = require "world.game.ecs.systems.input_player_system"

M.PlayerMoveSystem = require "world.game.ecs.systems.player_move_system"
M.PlayerVelocityLimitSystem = require "world.game.ecs.systems.player_velocity_limit_system"
M.PlayerAirControlSystem = require "world.game.ecs.systems.player_air_control_system"

M.UpdateLightAreaSystem = require "world.game.ecs.systems.update_light_area_system"
M.LightRotateSystem = require "world.game.ecs.systems.light_rotate_system"

M.DrawTileSystem = require "world.game.ecs.systems.draw_tile_system"
M.DrawPlayerSystem = require "world.game.ecs.systems.draw_player_system"
M.DrawDecorSystem = require "world.game.ecs.systems.draw_decor_system"
M.DrawLightSystem = require "world.game.ecs.systems.draw_light_system"

M.DrawBoxSystem = require "world.game.ecs.systems.draw_box_system"

M.DrawPhysicsDebugSystem = require "world.game.ecs.systems.draw_physics_debug_system"
M.DrawDebugLightsSystem = require "world.game.ecs.systems.draw_debug_lights_system"
M.DebugMoveLightSystem = require "world.game.ecs.systems.debug_move_light_system"

M.PhysicsCheckOnGroundSystem = require "world.game.ecs.systems.physics_check_on_ground_system"

require = require_old

-- luacheck: pop

return M