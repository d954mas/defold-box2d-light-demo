local M = {}

M.CLASS = require "libs.middleclass"
M.LUME = require "libs.lume"
M.N28S = require "libs.n28s"
M.MSG = require "libs.msg_receiver"
M.CONSTANTS = require "libs.constants"
M.INPUT = require "libs.input_receiver"
M.HASHES = require "libs.hashes"


---@type Render set inside render. Used to get buffers outside from render
M.RENDER = nil

function M.class(name, super)
	return M.CLASS.class(name, super)
end

function M.new_n28s()
	return M.CLASS.class("NewN28S", M.N28S.Script)
end

return M