local ECS = require 'libs.ecs'
local COMMON = require "libs.common"
local CAMERAS = require "libs.cameras"

local FACTORY = msg.url("game_scene:/factories#decor")
local FACTORY_BG = msg.url("game_scene:/factories#decor_bg")

---@class DrawDecorSystem:ECSSystem
local System = ECS.system()
System.filter = ECS.filter("decor")
System.name = "DrawDecorSystem"


-- luacheck: push ignore DecorGo
---@class DecorGo
---@field root url
local DecorGo = {
    sprite = msg.url()
}
-- luacheck: pop

function System:init()
    self.viewport = vmath.vector3(CAMERAS.game_camera.view_area)
    self.camera_pos = vmath.vector3(CAMERAS.game_camera.wpos)
    ---@type EntityGame[]
    self.entities = {}
end

---@param e EntityGame
function System:onAdd(e, dt)
    if (not e.visible and e.decor_go) then
        go.delete(assert(e.decor_go.root), true)
        e.decor_go = nil
    elseif (e.visible and not e.decor_go) then
        local rotation = vmath.quat_rotation_z(math.rad(-e.map_object.rotation))
        local tile_data = self.world.game_world.game.level:get_tile(e.map_object.tile_id)
        e.decor_go = {
            root = assert(msg.url(factory.create(e.decor_bg and FACTORY_BG or FACTORY, e.position, rotation, nil,
            (e.map_object.properties.scale or tile_data.properties.scale or 1)* 0.8) )),
            sprite = nil
        }
        e.decor_go.sprite = msg.url(e.decor_go.root.socket, e.decor_go.root.path, COMMON.HASHES.SPRITE)
        sprite.play_flipbook(e.decor_go.sprite, tile_data.image_hash)
        if (tile_data.properties.alpha) then
            go.set(e.decor_go.sprite, "tint.w", tile_data.properties.alpha)
        end
    end
end

function System:update(dt)
    if (CAMERAS.game_camera.dirty) then
        CAMERAS.game_camera:recalculate_view_proj()
    end
    if ((math.abs(CAMERAS.game_camera.view_area.x - self.viewport.x) > 0.0001
            or math.abs(CAMERAS.game_camera.view_area.y - self.viewport.y) > 0.0001
            or math.abs(CAMERAS.game_camera.wpos.x - self.camera_pos.x) > 0.0001
            or math.abs(CAMERAS.game_camera.wpos.y - self.camera_pos.y) > 0.0001))
    then
        self.viewport.x = CAMERAS.game_camera.view_area.x
        self.viewport.y = CAMERAS.game_camera.view_area.y
        self.camera_pos.x = CAMERAS.game_camera.wpos.x
        self.camera_pos.y = CAMERAS.game_camera.wpos.y
        self:recalculate()
    end


end

function System:recalculate()
    local border = CAMERAS.game_camera.orthographic_border
    local DELTA = 10
    for _, e in ipairs(self.entities) do
        local pos = e.position
        local new_visible = not (pos.x - e.visible_bbox.w / 2 - DELTA > border.right_bottom.x
                or pos.x + e.visible_bbox.w / 2 + DELTA < border.left_top.x
                or pos.y - e.visible_bbox.h / 2 - DELTA > border.left_top.y
                or pos.y + e.visible_bbox.h / 2 + DELTA < border.right_bottom.y)
        if (e.visible ~= new_visible) then
            e.visible = new_visible
            self:onAdd(e)
        end
    end
end

return System