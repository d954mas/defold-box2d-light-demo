local COMMON = require 'libs.common'
local ECS = require 'libs.ecs'
local ENUMS = require 'world.enums.enums'
local TWEEN = require 'libs.tween'
local BALANCE = require "world.balance.balance"

---@class PlayerAirControlSystem:ECSSystem
local System = ECS.processingSystem()
System.filter = ECS.requireAll("player")
System.name = "PlayerAirControlSystem"

----@param e EntityGame
function System:process(e, dt)
	local balance = BALANCE

	if (not e.on_ground and e.moving) then
		--in air
		local power = vmath.vector3(0, 0, 0)
		local vel = e.body:GetLinearVelocity()
		local right = e.direction == ENUMS.DIRECTION.RIGHT
		local left = e.direction == ENUMS.DIRECTION.LEFT

		local vel_a = vel.x / balance.velocity_x_air_limit
		vel_a = COMMON.LUME.clamp(vel_a, -1, 1)

		local power_a = 1
		if ((vel_a > 0 and right) or (vel_a < 0) and left) then
			--change power depend on vel
			-- t = time == how much time has to pass for the tweening to complete
			-- b = begin == starting property value
			-- c = change == ending - beginning
			-- d = duration == running time. How much time has passed *right now*
			local tween_t = math.abs(vel_a)
			local tween_b = 0
			local tween_c = 1
			local tween_d = 1
			power_a = 1 - TWEEN.easing.inQuad(tween_t, tween_b, tween_c, tween_d)
			power_a = math.max(0.1, power_a)
		end

		if (right) then power.x = balance.air_power
		elseif (left) then power.x = -balance.air_power
		end

		if (power.x ~= 0) then
			power.x = power.x * dt * power_a
			e.body:ApplyForceToCenter(power, true)
		end
	end
end

return System