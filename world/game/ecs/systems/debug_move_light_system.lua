local ECS = require 'libs.ecs'
local COMMON = require "libs.common"
local CAMERAS = require "libs.cameras"

---@class DebugMoveLightSystem:ECSSystemProcessing
local System = ECS.processingSystem()
System.filter = ECS.filter("input_info")
System.name = "DebugMoveLightSystem"

function System:onAddToWorld()
	self.light = self.world.game_world.game.ecs_game.entities:create_light({
		center_x = 0,
		center_y = 0,
		properties = {
			angle_begin = 0,
			angle_end = 360,
			distance = 600,
			light = true,
			rays = 360,
			rays_dynamic = 360,
			rotation_speed = 0,
			color = "#ff00ff00"
		}
	}, nil)
	self.light.draw_hit_player = false
	self.light.light_hit_distance = 500
	self.light.light_hit_player = true
	self.world:addEntity(self.light)
end

function System:init()
	self.input_handler = COMMON.INPUT()
	self.input_handler:add(COMMON.HASHES.INPUT.TOUCH, function(_, _, action)
		local game = self.world.game_world.game
		local input = game.input
		if (action.pressed) then

		end
		if (not action.released) then
			local x, y = action.screen_x, action.screen_y
			x, y = CAMERAS.game_camera:screen_to_world_2d(x, y, false, nil, true)
			self.light.position.x = x
			self.light.position.y = y
		end
	end, true, false, true, true)
end

---@param e EntityGame
function System:process(e, dt)
	self.input_handler:on_input(self, e.input_info.action_id, e.input_info.action)
end

function System:postProcess(dt)
	if (self.light.draw_hit_player ~= self.light.light_native:PlayerIsHit()) then
		self.light.draw_hit_player = self.light.light_native:PlayerIsHit()
		local color = self.light.draw_hit_player and vmath.vector4(1, 0, 0, 1) or vmath.vector4(0, 1, 0, 1)
		self.light.light_native:SetColor(color.x, color.y, color.z, color.w)
	end
end

return System