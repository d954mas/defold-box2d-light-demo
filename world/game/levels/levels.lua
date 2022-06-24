local COMMON = require "libs.common"
local MAP_HELPER = require "assets.bundle.common.levels.parser.map_helper"
local PARSER = require "assets.bundle.common.levels.parser.parser"
local Level = require "world.game.levels.level"
local JSON = require "libs.json"
local TILESETS = require "world.game.levels.tilesets"
local M = {}
local TAG = "LEVEL"

M.LEVELS = {
	LEVEL_1 = "level_1",
}

M.LEVELS_LIST = {
	M.LEVELS.LEVEL_1

}

M.LEVELS_COUNT = #M.LEVELS_LIST

M.CURRENT_LEVEL_IDX = 1
M.CURRENT_LEVEL_NAME = ""

local function string_key_to_number(data)
	local result = {}
	for k, v in pairs(data) do
		result[tonumber(k)] = v
	end
	return result
end

local function to_tiles_array(array, max_id)
	for i = 0, max_id do
		local str = tostring(i)
		if (array[str]) then
			array[i] = array[str]
			array[str] = nil
		end
		if (array[i] and array[i] ~= 0) then
			array[i] = MAP_HELPER.tile_to_data(array[i])
		end
	end
end

---@param file_path boolean use filepath instead of resources
function M.load_level(name, file_path)
	local time = socket.gettime()
	local data
	if (file_path) then
		local path = file_path .. "\\" .. name .. ".json"
		print("load level file:" .. path)
		local file = io.open(path, "r")
		local contents, read_err = file:read("*a")
		file:close()
		if (read_err) then
			COMMON.w("can't read level:" .. tostring(read_err), "[ERROR]")
		end
		data = contents
	else
		data = assert(sys.load_resource("/assets/bundle/common/levels/editor/result/" .. name .. ".json", "no lvl:" .. name))
	end
	---@type LevelData
	local level_data = JSON.decode(data)
	local max_id = level_data.size.w * level_data.size.h
	to_tiles_array(level_data.front1, max_id)
	local level = Level(level_data)

	local idx = COMMON.LUME.findi(M.LEVELS_LIST, name)
	if (idx ~= nil) then
		M.CURRENT_LEVEL_IDX = idx
	end
	M.CURRENT_LEVEL_NAME = name

	level.name = name
	level.idx = idx or -1

	print(TAG .. " lvl:" .. name .. " loaded. Time:" .. (socket.gettime() - time))
	return level
end

return M