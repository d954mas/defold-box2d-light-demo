local COMMON = require 'libs.common'
local ECS = require 'libs.ecs'
local ENUMS = require 'world.enums.enums'
local BALANCE = require "world.balance.balance"

---@class PlayerMoveSystem:ECSSystem
local System = ECS.processingSystem()
System.filter = ECS.requireAll("player")
System.name = "PlayerMoveSystem"

---@param e EntityGame
function System:process(e, dt)
	local balance = BALANCE
	local velocity = e.body:GetLinearVelocity()
	if (e.moving) then
		e.body_player.f_body:SetFriction(0)
		if (e.on_ground) then
			local same_dir = (velocity.x >= 0 and e.direction == ENUMS.DIRECTION.RIGHT) or
					velocity.x <= 0 and e.direction == ENUMS.DIRECTION.LEFT
			local velocity_sign = e.direction == ENUMS.DIRECTION.RIGHT and 1 or -1
			if (same_dir) then
				local new_vel_x = velocity.x + balance.player_speed_increase * velocity_sign * dt
				if (math.abs(new_vel_x) > balance.velocity_x_limit) then
					new_vel_x = balance.velocity_x_limit * velocity_sign
				end
				velocity.x = new_vel_x
				e.body:SetLinearVelocity(velocity)
			else
				local new_vel_x = velocity.x + (balance.player_speed_increase * velocity_sign * dt) *
						balance.player_speed_decrease_scale
				velocity.x = new_vel_x
				e.body:SetLinearVelocity(velocity)
			end
		end
	else
		e.body_player.f_body:SetFriction(e.body_player.f_body_friction)
		--slow down
		if (e.on_ground) then
			velocity.x = velocity.x * 0.5
			e.body:SetLinearVelocity(velocity)
		end
	end
	if (not e.player_prev_position) then
		e.player_prev_position = e.body:GetPosition()
	end
	e.player_move_delta = e.body:GetPosition() - e.player_prev_position
	e.player_prev_position = e.body:GetPosition()
end

return System