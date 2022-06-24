local COMMON = require "libs.common"
local ECS = require "libs.ecs"
local SYSTEMS = require "world.game.ecs.game_systems"
local Entities = require "world.game.ecs.entities.entities_game"

---@class GameEcsWorld
local EcsWorld = COMMON.class("EcsWorld")

---@param world World
function EcsWorld:initialize(world)
	self.world = assert(world)

	self.ecs = ECS.world()
	self.ecs.game = self
	self.ecs.game_world = self.world

	self.entities = Entities(world)
	self.ecs.on_entity_added = function(_, ...) self.entities:on_entity_added(...) end
	self.ecs.on_entity_updated = function(_, ...) self.entities:on_entity_updated(...) end
	self.ecs.on_entity_removed = function(_, ...) self.entities:on_entity_removed(...) end
end

function EcsWorld:find_by_id(id)
	return self.entities:find_by_id(assert(id))
end

function EcsWorld:add_systems()
	self.ecs:addSystem(SYSTEMS.DebugMoveLightSystem())

	self.ecs:addSystem(SYSTEMS.PhysicsCheckOnGroundSystem())
	self.ecs:addSystem(SYSTEMS.LightRotateSystem())
	self.ecs:addSystem(SYSTEMS.UpdateLightAreaSystem())

	self.ecs:addSystem(SYSTEMS.InputSystem()) --zoom move camera
	self.ecs:addSystem(SYSTEMS.InputPlayerSystem())

	self.ecs:addSystem(SYSTEMS.PlayerMoveSystem())
	self.ecs:addSystem(SYSTEMS.PlayerAirControlSystem())
	self.ecs:addSystem(SYSTEMS.PlayerVelocityLimitSystem())

	self.ecs:addSystem(SYSTEMS.DrawPlayerSystem())
	self.ecs:addSystem(SYSTEMS.DrawTileSystem())
	self.ecs:addSystem(SYSTEMS.DrawDecorSystem())
	self.ecs:addSystem(SYSTEMS.DrawLightSystem())
	self.ecs:addSystem(SYSTEMS.DrawBoxSystem())

	self.ecs:addSystem(SYSTEMS.DrawPhysicsDebugSystem())
	self.ecs:addSystem(SYSTEMS.DrawDebugLightsSystem())

	self.ecs:addSystem(SYSTEMS.AutoDestroySystem())
end

function EcsWorld:update(dt)
	--if dt will be too big. It can create a lot of objects.
	--big dt can be in htlm when change page and then return
	--or when move game window in Windows.
	local max_dt = 0.1
	if (dt > max_dt) then dt = max_dt end
	self.ecs:update(dt)
end

function EcsWorld:clear()
	self.ecs:clear()
	self.ecs:refresh()
end

function EcsWorld:refresh()
	self.ecs:refresh()
end

function EcsWorld:add(...)
	self.ecs:add(...)
end

function EcsWorld:add_entity(e)
	assert(e)
	self.ecs:addEntity(e)
end

function EcsWorld:remove_entity(e)
	assert(e)
	self.ecs:removeEntity(e)
end

return EcsWorld



