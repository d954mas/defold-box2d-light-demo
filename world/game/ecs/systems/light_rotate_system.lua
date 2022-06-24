local ECS = require "libs.ecs"
local COMMON = require "libs.common"

---@class LightRotateSystem:ECSSystem
local System = ECS.processingSystem()
System.name = "LightRotateSystem"
System.filter = ECS.filter("light")

function System:init()

end

---@param e EntityGame
function System:process(e, dt)
    if (e.light_angle_speed ~= 0) then
        e.light_angle = e.light_angle + e.light_angle_speed * dt
        e.light_native:SetAngle(e.light_angle)
    end

end

return System