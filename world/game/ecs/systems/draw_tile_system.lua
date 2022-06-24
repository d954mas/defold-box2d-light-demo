local ECS = require 'libs.ecs'
local COMMON = require "libs.common"
local MAP_HELPER = require "assets.bundle.common.levels.parser.map_helper"
local CAMERAS = require "libs.cameras"

local FACTORY = msg.url("game_scene:/factories#tile")

---@class DrawTileSystem:ECSSystem
local System = ECS.system()
System.filter = ECS.filter("tile&!map_object")
System.name = "DrawTileSystem"

function System:init()
    self.viewport = vmath.vector3(0)
    self.camera_pos = vmath.vector3(0)
    ---@type EntityGame[]
    self.entities = {}
end

---@param e EntityGame
function System:onAdd(e, dt)
    if (not e.visible and e.tile_go) then
        go.delete(assert(e.tile_go.root), true)
        e.tile_go = nil
    elseif (e.visible and not e.tile_go) then
        local scale, rotation = MAP_HELPER.tile_flip_to_scale_and_angle(e.tile.fh, e.tile.fv, e.tile.fd)
        rotation = vmath.quat_rotation_z(math.rad(rotation))
        ---@class TileGo
        local tile_go = {
            root = assert(msg.url(factory.create(FACTORY, e.position, rotation, nil, scale))),
            sprite = nil
        }
        e.tile_go = tile_go

        local tile_data = self.world.game_world.game.level:get_tile(e.tile.id)
        e.tile_go.sprite = COMMON.LUME.url_component_from_url(e.tile_go.root, COMMON.HASHES.SPRITE)
        sprite.play_flipbook(e.tile_go.sprite, tile_data.image_hash)
    end
end

function System:update(dt)
    --camera can change
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
--    print("Draw Tile recalculate")
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