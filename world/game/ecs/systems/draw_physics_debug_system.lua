local ECS = require 'libs.ecs'
local COMMON = require "libs.common"

---@class DrawPhysicsDebugSystem:ECSSystem
local System = ECS.system()
System.name = "DrawPhysicsDebugSystem"

---@param e EntityGame
function System:update(dt)
	if (self.enable_physics ~= self.world.game_world.debug_state.draw_physics) then
		self.enable_physics = self.world.game_world.debug_state.draw_physics

		local b2_world = self.world.game_world.game.box2d_world
		if (self.enable_physics) then
			b2_world.world:SetDebugDraw(b2_world.debug_draw)
		else
			b2_world.world:SetDebugDraw(nil)
		end
	end
	if (self.enable_physics) then
		self.world.game_world.game.box2d_world.world:DebugDraw()
	end
end

return System