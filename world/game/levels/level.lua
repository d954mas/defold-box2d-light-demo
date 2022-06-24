local COMMON = require "libs.common"
local TILESET = require "world.game.levels.tilesets"
local MAP_HELPER = require "assets.bundle.common.levels.parser.map_helper"

local TAG = "Level"

---@class Level
local Level = COMMON.class("Level")

---@param objects LevelMapObject[]
local function objects_set_meta(objects)
    for _, object in pairs(objects) do
        if (object.tile_id and object.properties) then
            setmetatable(object.properties, { __index = TILESET.by_id[object.tile_id].properties })
        end
    end
end

---@param data LevelData
function Level:initialize(data)
    self.data = assert(data)
    self.cell_max_id = self.data.size.w * self.data.size.h
    objects_set_meta(self.data.lights)
end

--region MAP
function Level:map_get_width() return self.data.size.w end
function Level:map_get_height() return self.data.size.h end

function Level:map_cell_id_is_valid(id)
    return id >= 1 and id <= self.cell_max_id
end

function Level:coords_is_valid(x, y)
    return x >= 0 and y >= 0 and x < self.data.size.w and y < self.data.size.h
end

function Level:coords_to_id(x, y)
    return MAP_HELPER.coords_to_id(self.data, math.floor(x), math.floor(y))
end

function Level:id_to_coords(id)
    local x, y = MAP_HELPER.id_to_coords(self.data, id)
    return x, y
end
--endregion


---@return LevelMapTile
function Level:get_tile(id)
    return assert(TILESET.by_id[id], "no tile with id:" .. id)
end

---@return LevelMapTile
function Level:get_tile_for_tileset(tileset_name, id)
    assert(tileset_name)
    assert(id)
    local tileset = assert(TILESET.tilesets[tileset_name], "no tileset with name:" .. tileset_name)
    local tile_id = tileset.first_gid + id
    assert(tile_id <= tileset.end_gid, "no tile:" .. tile_id .. " in tileset:" .. tileset_name .. " end:" .. tileset.end_gid)
    return self:get_tile(tile_id), tile_id
end

return Level