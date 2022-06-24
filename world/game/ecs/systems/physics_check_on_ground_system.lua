local ECS = require 'libs.ecs'

---@class PhysicsCheckOnGroundSystem:ECSSystem
local System = ECS.processingSystem()
System.filter = ECS.requireAll("on_ground")
System.name = "PhysicsCheckOnGroundSystem"

---@param e EntityGame
function System:process(e, dt)
    e.on_ground = e.ground_sensor_collisions > 0
end

return System