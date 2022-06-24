---@class TileProperties
---@field type string


---@class LevelMapTile
---@field properties TileProperties
---@field id number
---@field image string
---@field image_hash hash calculate when load tilesets


---@class LevelMapObject
---@field tile_id number
---@field properties TileProperties
---@field x number
---@field y number
---@field center_x number
---@field center_y number
---@field w number
---@field h number
---@field rotation number

---@class LevelTileset
---@field first_gid number
---@field end_gid number
---@field name string

---@class LevelTilesets
---@field by_id LevelMapTile[]
---@field tilesets LevelTileset[]

---@class LevelMapTileData
---@field id number
---@field fv boolean
---@field fh boolean
---@field fd boolean

---@class Point
---@field x
---@field y

--vector3 is not vector3 here. I use it only to autocomplete worked. It will be tables with x,y,z
---@class LevelData
---@field size table {w,h}
---@field properties table
---@field objects LevelMapObject[]
---@field front_1 LevelMapTileData[]
---@field geometry table[]
