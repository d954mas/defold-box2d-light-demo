local ECS = require "libs.ecs"
local COMMON = require "libs.common"
local BALANCE = require "world.balance.balance"

local TEMP_V = vmath.vector3(0)

local BAND = bit.band

---@class UpdateLightAreaSystem:ECSSystemProcessing
local System = ECS.processingSystem()
System.name = "UpdateLightAreaSystem"
System.filter = ECS.filter("light")

function System:init()
end

function System:onAddToWorld()
	local b2w = self.world.game_world.game.box2d_world
	self.filter_geometry = {
		categoryBits = b2w.groups.LIGHT_RAY,
		maskBits = b2w.masks.LIGHT_RAY_GEOMETRY,
		groupIndex = 0
	}
	self.filter_player = {
		categoryBits = b2w.groups.LIGHT_RAY,
		maskBits = bit.bor(b2w.groups.PLAYER_LIGHT),
		groupIndex = 0
	}
	self.physics_scale = BALANCE.physics_scale
	game.set_world(b2w.world)
	game.set_filter_geometry(self.filter_geometry)
	game.set_filter_player(self.filter_player)
end

function System:preProcess(dt)
	local player = self.world.game_world.game.level_creator.player
	self.player_hit = false
	self.player_position_b2 = player.body:GetPosition()
	self.player_position_light_b2 = self.player_position_b2 + player.body_player.f_light_d_pos
	self.player_size_b2 = player.body_player.f_light_size
	self.player_position = vmath.vector3(self.player_position_b2.x / self.physics_scale,
			self.player_position_b2.y / self.physics_scale, 0)
end

---@param e EntityGame
function System:process(e, dt)
	local physics_scale = self.physics_scale
	TEMP_V.x = e.position.x * physics_scale
	TEMP_V.y = e.position.y * physics_scale
	e.body:SetTransform(TEMP_V)
	e.light_native:SetPosition(TEMP_V.x, TEMP_V.y)

	if (e.light_sensor_collisions == 0 and e.light_enabled) then
		if (not e.light_static or e.light_static_dirty) then
			e.light_static_dirty = false
			e.light_native:UpdateLight()
		end
	end

	if (e.light_hit_player and e.light_sensor_collisions == 0) then
		local dx, dy = (self.player_position.x - e.position.x), (self.player_position.y - e.position.y)
		local dist = math.sqrt(dx * dx + dy * dy)
		e.light_hit_player_cast_rays = true
		if (dist <= (e.light_hit_distance or e.map_object.properties.distance)) then
			e.light_native:UpdateHitPlayer(self.player_position_light_b2.x, self.player_position_light_b2.y,
					self.player_size_b2.x, self.player_size_b2.y)
		else
			e.light_hit_player_cast_rays = false
			e.light_native:SetPlayerIsHit(false)
		end
	else
		e.light_native:SetPlayerIsHit(false)
	end


end

return System