local ECS = require "libs.ecs"
local COMMON = require "libs.common"
local BALANCE = require "world.balance.balance"

local FACTORY = msg.url("game_scene:/factories#debug_light")

local PARTS = {
	ROOT = COMMON.HASHES.hash("/root"),
	LIGHT = COMMON.HASHES.hash("/root"),
}

local COLOR = vmath.vector4(1, 1, 1, 1)
local COLOR_RAY = vmath.vector4(1, 1, 1, 1)
local COLOR_RAY_DYNAMIC = vmath.vector4(0, 1, 0, 1)
local COLOR_HIT_PLAYER = vmath.vector4(1, 0, 0, 1)

local POS_START = vmath.vector3()
local POS_END = vmath.vector3()

local message = {
	start_point = POS_START,
	end_point = POS_END,
	color = COLOR
}

local MSG_DRAW_LINE = hash("draw_line")

---@class DebugDrawLightsSystem:ECSSystem
local System = ECS.processingSystem()
System.name = "DebugDrawLightsSystem"
System.filter = ECS.filter("light")

function System:init()

end

function System:preProcess(dt)
	local player = self.world.game_world.game.level_creator.player
	self.player_position_b2 = player.body:GetPosition()
	---@type Box2dPolygonShape
	self.player_size_b2 = player.body_player.f_light_size
	self.player_position_light_b2 = self.player_position_b2 + player.body_player.f_light_d_pos

end

function System:__draw_circle(center, radius, angle_begin, angle_end, light_angle)
	local segments = 16
	local base_angle = math.rad(angle_begin) + light_angle
	-- local base_angle = 0

	local a = math.rad(angle_end - angle_begin) / segments
	--local a = math.pi * 2 / segments

	local x1 = center.x + math.cos(base_angle) * radius
	local y1 = center.y + math.sin(base_angle) * radius
	for i = 1, segments do
		local a2 = base_angle + (i) * a
		local x2, y2 = center.x + math.cos(a2) * radius, center.y + math.sin(a2) * radius

		--draw sector lines
		if (i == segments) then
			message.start_point.x, message.start_point.y = center.x, center.y
			message.end_point.x, message.end_point.y = x2, y2
			msg.post("@render:", MSG_DRAW_LINE, message)
		end

		if (i == 1) then
			message.start_point.x, message.start_point.y = center.x, center.y
			message.end_point.x, message.end_point.y = x1, y1
			msg.post("@render:", MSG_DRAW_LINE, message)
		end

		message.start_point.x, message.start_point.y = x1, y1
		message.end_point.x, message.end_point.y = x2, y2
		msg.post("@render:", MSG_DRAW_LINE, message)
		x1, y1 = x2, y2
	end
end

---@param e EntityGame
function System:process(e, dt)
	if (self.world.game_world.debug_state.debug_light) then
		local physics_scale = BALANCE.physics_scale
		if (not e.light_debug_go) then
			local pos = vmath.vector3(e.position)
			pos.z = COMMON.CONSTANTS.Z_ORDER.LIGHT_DEBUG
			local collection = collectionfactory.create(FACTORY, e.position)
			---@class LightDebugGo
			local light_debug_go = {
				root = msg.url(assert(collection[PARTS.LIGHT])),
				light = {
					root = msg.url(collection[PARTS.BODY]),
					sprite = nil,
				},
			}
			light_debug_go.light.sprite = COMMON.LUME.url_component_from_url(light_debug_go.light.root, COMMON.HASHES.SPRITE)
			e.light_debug_go = light_debug_go
		end

		message.color.x = 1
		message.color.y = 1
		message.color.z = 1
		message.color.w = 1

		local visible = e.light_sensor_collisions == 0 and e.light_enabled

		if visible then
			--draw area
			self:__draw_circle(e.position, e.map_object.properties.distance,
					e.map_object.properties.angle_begin, e.map_object.properties.angle_end, e.light_angle)
			local rays = e.light_native:RaysGetPositions()
			message.start_point.x = e.position.x
			message.start_point.y = e.position.y
			go.set_position( e.position/physics_scale,e.light_debug_go.root)
			for _, ray in ipairs(rays) do
				local color = ray.dynamic and COLOR_RAY_DYNAMIC or COLOR_RAY
				message.color.x = color.x
				message.color.y = color.y
				message.color.z = color.z
				message.color.w = color.w
				message.end_point.x, message.end_point.y = ray.x / physics_scale, ray.y / physics_scale
				msg.post("@render:", MSG_DRAW_LINE, message)
			end
			local aabb = e.light_native:AABBGet()

			local ax1, ay1 = aabb.lowerBound.x / physics_scale, aabb.lowerBound.y / physics_scale
			local ax2, ay2 = aabb.upperBound.x / physics_scale, aabb.upperBound.y / physics_scale

			message.color.x = 0
			message.color.y = 1
			message.color.z = 1
			message.color.w = 1

			message.start_point.x, message.start_point.y = ax1, ay1
			message.end_point.x, message.end_point.y = ax1, ay2
			msg.post("@render:", MSG_DRAW_LINE, message)

			message.start_point.x, message.start_point.y = ax1, ay2
			message.end_point.x, message.end_point.y = ax2, ay2
			msg.post("@render:", MSG_DRAW_LINE, message)

			message.start_point.x, message.start_point.y = ax2, ay2
			message.end_point.x, message.end_point.y = ax2, ay1
			msg.post("@render:", MSG_DRAW_LINE, message)

			message.start_point.x, message.start_point.y = ax2, ay1
			message.end_point.x, message.end_point.y = ax1, ay1
			msg.post("@render:", MSG_DRAW_LINE, message)

			if (e.light_hit_player_cast_rays) then
				local rays_player = e.light_native:UpdateHitPlayerGetRays(self.player_position_light_b2.x, self.player_position_light_b2.y,
						self.player_size_b2.x, self.player_size_b2.y)
				message.color.x = COLOR_HIT_PLAYER.x
				message.color.y = COLOR_HIT_PLAYER.y
				message.color.z = COLOR_HIT_PLAYER.z
				message.color.w = COLOR_HIT_PLAYER.w
				message.start_point.x, message.start_point.y = e.position.x, e.position.y
				for _, ray in ipairs(rays_player) do
					--message.end_point.x, message.end_point.y = ray.x / physics_scale, ray.y / physics_scale
					--msg.post("@render:", MSG_DRAW_LINE, message)
				end

			end
		end

	else
		if (e.light_debug_go) then
			go.delete(e.light_debug_go.root, true)
			e.light_debug_go = nil
		end
	end

end

return System