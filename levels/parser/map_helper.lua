local M = {}

M.FLIPPED_HORIZONTALLY_FLAG = 0x80000000;
M.FLIPPED_VERTICALLY_FLAG = 0x40000000;
M.FLIPPED_DIAGONALLY_FLAG = 0x20000000;

---@param map LevelData
function M.coords_to_id(map, x, y)
    return y * map.size.w + x + 1
end

---@param map LevelData
function M.id_to_coords(map, id)
    local y = math.ceil(id / map.size.w)
    local x = id - (y - 1) * map.size.w
    return x, y
end

--diagonal flip https://discourse.mapeditor.org/t/can-i-rotate-tiles/703/5
function M.tile_flip_to_scale_and_angle(fh, fv, fad)
    local scale = vmath.vector3(1)
    local rotation = 0
    if fad then
        if (fv and not fh) then
            rotation = 90
        elseif (fh and not fv) then
            rotation = 270
        elseif (fh and fv) then
            rotation = 270
            scale.x = -scale.x
        else
            rotation = -270
            scale.x = -scale.x
        end
    else
        scale.x = fh and -scale.x or scale.x
        scale.y = fv and -scale.y or scale.y
    end
    return scale, rotation
end

---@return LevelMapTileData
function M.tile_to_data(tile_id)
    local flipped_horizontally = bit.band(bit.tobit(tile_id), M.FLIPPED_HORIZONTALLY_FLAG) ~= 0;
    local flipped_vertically = bit.band(bit.tobit(tile_id), M.FLIPPED_VERTICALLY_FLAG) ~= 0;
    local flipped_diagonally = bit.band(bit.tobit(tile_id), M.FLIPPED_DIAGONALLY_FLAG) ~= 0;

    if (not flipped_horizontally) then flipped_horizontally = nil end
    if (not flipped_vertically) then flipped_vertically = nil end
    if (not flipped_diagonally) then flipped_diagonally = nil end

    tile_id = bit.band(tile_id, bit.bnot(bit.bor(M.FLIPPED_HORIZONTALLY_FLAG, M.FLIPPED_VERTICALLY_FLAG, M.FLIPPED_DIAGONALLY_FLAG)));
    return { id = tile_id, fh = flipped_horizontally, fv = flipped_vertically, fd = flipped_diagonally }
end

return M