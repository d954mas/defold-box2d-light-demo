local ECS = require 'libs.ecs'
local COMMON = require "libs.common"
local ENUMS = require "world.enums.enums"
local BALANCE = require "world.balance.balance"

local FACTORY = msg.url("game_scene:/factories#player")

local PARTS = {
	ROOT = COMMON.HASHES.hash("/root"),
	BODY = COMMON.HASHES.hash("/body"),
}

---@class DrawCannonSystem:ECSSystem
local System = ECS.system()
System.filter = ECS.filter("player")
System.name = "DrawPlayerSystem"

local TEMP_V = vmath.vector3(0, 0, COMMON.CONSTANTS.Z_ORDER.PLAYER)

function System:init()

end

---@param e EntityGame
function System:onAdd(e, dt)
	if (not e.player_go) then
		local collection = collectionfactory.create(FACTORY, e.position)
		---@class PlayerGo
		local player_go = {
			root = msg.url(assert(collection[PARTS.ROOT])),
			body = {
				root = msg.url(collection[PARTS.BODY]),
				sprite = nil,
			},
			config = {
				direction = ENUMS.DIRECTION.RIGHT,
				animation = ENUMS.PLAYER_ANIMATIONS.IDLE,
				visible = true,
			}
		}
		player_go.body.sprite = COMMON.LUME.url_component_from_url(player_go.body.root, COMMON.HASHES.SPRITE)
		e.player_go = player_go
	end
end

---@param e EntityGame
function System:get_player_animation(e)
	local state = ENUMS.PLAYER_ANIMATIONS.IDLE
	if (e.moving) then
		state = ENUMS.PLAYER_ANIMATIONS.RUN
	end
	if (not e.on_ground) then
		if (math.abs(e.body:GetLinearVelocity().y) > 0.000001) then
			state = e.body:GetLinearVelocity().y < 0
					and ENUMS.PLAYER_ANIMATIONS.IN_AIR_DOWN or ENUMS.PLAYER_ANIMATIONS.IN_AIR_UP
		else
			--save current state.It air down or air up
			local current_anim = e.player_go.config.animation
			if (current_anim == ENUMS.PLAYER_ANIMATIONS.IN_AIR_DOWN or current_anim == ENUMS.PLAYER_ANIMATIONS.IN_AIR_UP) then
				state = e.player_go.config.animation
			end
		end
	end

	return state
end

---@param player EntityGame
function System:play_animation(player, animation)
	player.player_go.config.animations_data = {
		animation = animation,
	}
	sprite.play_flipbook(player.player_go.body.sprite, animation)
end

function System:update(dt)
	local physics_scale = BALANCE.physics_scale
	for _, player in ipairs(self.entities) do
		local pos = player.body:GetPosition()
		TEMP_V.x = pos.x / physics_scale
		TEMP_V.y = pos.y / physics_scale
		go.set_position(TEMP_V, player.player_go.root)
		local config = player.player_go.config
		if (player.direction ~= config.direction) then
			config.direction = player.direction
			go.set(player.player_go.body.root, "scale.x",
					config.direction == ENUMS.DIRECTION.RIGHT and 1 or -1)
		end

		local animation = self:get_player_animation(player)
		--pprint(tostring(player.player_go.config.animation) .. " Ground:" .. tostring(player.on_ground))
		if (animation ~= player.player_go.config.animation) then
			player.player_go.config.animation = animation
			if (animation == ENUMS.PLAYER_ANIMATIONS.IDLE) then
				self:play_animation(player, "player_idle")
			elseif (animation == ENUMS.PLAYER_ANIMATIONS.RUN) then
				self:play_animation(player, "player_run")
			elseif (animation == ENUMS.PLAYER_ANIMATIONS.IN_AIR_UP) then
				self:play_animation(player, "player_air_up")
			elseif (animation == ENUMS.PLAYER_ANIMATIONS.IN_AIR_DOWN) then
				self:play_animation(player, "player_air_down")
			end

		end
	end
end
return System