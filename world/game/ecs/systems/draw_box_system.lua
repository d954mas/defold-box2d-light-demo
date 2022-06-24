local ECS = require 'libs.ecs'
local COMMON = require "libs.common"
local TILESETS = require "world.game.levels.tilesets"

local FACTORY = msg.url("game_scene:/factories#box")

local PARTS = {
    ROOT = COMMON.HASHES.hash("/root")
}

---@class DrawBoxSystem:ECSSystem
local System = ECS.processingSystem()
System.filter = ECS.filter("box")
System.name = "DrawBoxSystem"

function System:onAdd(e)
    e.visible = true
    if (not e.visible and e.box_go) then
        go.delete(assert(e.box_go.root), true)
        e.box_go = nil
    elseif (e.visible and not e.box_go) then
        local collection = collectionfactory.create(FACTORY, e.body.position, nil, nil, 40 / 50)
        ---@class BoxGo
        local box_go = {
            root = msg.url(assert(collection[PARTS.ROOT])),
            sprite = nil
        }
        e.box_go = box_go
        e.box_go.sprite = msg.url(e.box_go.root.socket, e.box_go.root.path, COMMON.HASHES.SPRITE)
        sprite.play_flipbook(e.box_go.sprite, TILESETS.by_id[e.map_object.tile_id].image_hash)
    end

end

---@param e EntityGame
function System:process(e, dt)

    if (e.box_go) then
        local scale = self.world.game_world.balance.config.physics_scale
        local pos = e.body:GetPosition()
        pos.x = pos.x / scale
        pos.y = pos.y / scale
        pos.z = COMMON.CONSTANTS.Z_ORDER.BOX

        go.set_position(pos, e.box_go.root)
        go.set_rotation(vmath.quat_rotation_z(e.body:GetAngle()), e.box_go.root)
    end
end

return System