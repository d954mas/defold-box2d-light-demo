local COMMON = require "libs.common"
local BOX2D_UTILS = require "box2d.utils"
local BALANCE = require "world.balance.balance"

local Box2dWorld = COMMON.class("Box2dWorld")

---@param game_world World
function Box2dWorld:initialize(config, game_world)
	self.groups = {
		GEOMETRY = bit.tobit(1),
		PLAYER = bit.tobit(2),
		PLAYER_LIGHT = bit.tobit(4),
		LIGHT_RAY = bit.tobit(8),
		ENEMY = bit.tobit(16),
		OBSTACLE = bit.tobit(32),
	}
	self.masks = {
		EMPTY = bit.bor(0),
		GEOMETRY = bit.bor(self.groups.PLAYER, self.groups.LIGHT_RAY, self.groups.ENEMY, self.groups.OBSTACLE),
		PLAYER = bit.bor(self.groups.GEOMETRY, self.groups.OBSTACLE),
		LIGHT_RAY_GEOMETRY = bit.bor(self.groups.GEOMETRY, self.groups.OBSTACLE),
		ENEMY = bit.bor(self.groups.GEOMETRY, self.groups.OBSTACLE),
		OBSTACLE = bit.bor(self.groups.GEOMETRY, self.groups.PLAYER, self.groups.LIGHT_RAY,
				self.groups.OBSTACLE),
	}

	self.game_world = game_world
	self.config = config
	self.config.time_step = self.config.time_step or 1 / 60
	self.config.velocity_iterations = self.config.velocity_iterations or 8
	self.config.position_iterations = self.config.position_iterations or 3
	self.world = box2d.NewWorld(self.config.gravity)
	---@type Box2dDebugDraw
	self.debug_draw = BOX2D_UTILS.create_debug_draw(BALANCE.physics_scale)
	self.debug_draw_flags = bit.bor(box2d.b2Draw.e_shapeBit, box2d.b2Draw.e_jointBit, box2d.b2Draw.e_centerOfMassBit) or 0
	self.debug_draw:SetFlags(self.debug_draw_flags)
	self.physics_scale = 1
	self.game_world = assert(game_world)
end

function Box2dWorld:update(dt)
	self.world:Step(dt or self.config.time_step, self.config.velocity_iterations, self.config.position_iterations)
end

function Box2dWorld:dispose()
	assert(self.world)
	self.world:Destroy()
	self.debug_draw:Destroy()
	self.world = nil
	self.debug_draw = nil
end

return Box2dWorld

