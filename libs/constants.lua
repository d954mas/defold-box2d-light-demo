local lume = require "libs.lume"

local M = {}

M.SYSTEM_INFO = sys.get_sys_info()
M.PLATFORM = M.SYSTEM_INFO.system_name
M.PLATFORM_IS_WEB = M.PLATFORM == "HTML5"
M.PLATFORM_IS_WINDOWS = M.PLATFORM == "Windows"
M.PLATFORM_IS_LINUX = M.PLATFORM == "Linux"
M.PLATFORM_IS_MACOS = M.PLATFORM == "Darwin"
M.PLATFORM_IS_ANDROID = M.PLATFORM == "Android"
M.PLATFORM_IS_IPHONE = M.PLATFORM == "iPhone OS"

M.PLATFORM_IS_PC = M.PLATFORM_IS_WINDOWS or M.PLATFORM_IS_LINUX or M.PLATFORM_IS_MACOS
M.PLATFORM_IS_MOBILE = M.PLATFORM_IS_ANDROID or M.PLATFORM_IS_IPHONE

M.PROJECT_VERSION = sys.get_config("project.version")

M.GAME_VERSION = sys.get_config("game.version")

M.VERSION_IS_DEV = M.GAME_VERSION == "dev"
M.VERSION_IS_RELEASE = M.GAME_VERSION == "release"

M.Z_ORDER = {
	BG = -10,
	DECOR_BG = -9.5,
	TILE_BASE = 1,
	LIGHT = 2,
	PLAYER = 2.5,
	BOX = 2.6,
	LIGHT_DEBUG = 3,
	DECOR = 4,

}

return M
