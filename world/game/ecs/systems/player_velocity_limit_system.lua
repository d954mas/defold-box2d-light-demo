local COMMON = require 'libs.common'
local ECS = require 'libs.ecs'
local ENUMS = require 'world.enums.enums'
local BALANCE = require "world.balance.balance"

---@class PlayerVelocityLimitSystem:ECSSystem
local System = ECS.processingSystem()
System.filter = ECS.requireAll("player")
System.name = "PlayerVelocityLimitSystem"

----@param e EntityGame
function System:process(e, dt)
    local balance = BALANCE

    local vel = e.body:GetLinearVelocity()
    local limit = not e.on_ground and balance.velocity_x_air_limit or balance.velocity_x_limit

    local min_limit = -limit
    local max_limit = limit

    vel.x = COMMON.LUME.clamp(vel.x, min_limit, max_limit)
    e.body:SetLinearVelocity(vel)
end

return System