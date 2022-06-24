local ECS = require 'libs.ecs'
local COMMON = require "libs.common"
local ENUMS = require "world.enums.enums"
local CAMERAS = require "libs.cameras"
local BALANCE = require "world.balance.balance"

---@class InputPlayerSystem:ECSSystemProcessing
local System = ECS.processingSystem()
System.filter = ECS.filter("input_info")
System.name = "InputPlayerSystem"

function System:init()
	self.input_handler = COMMON.INPUT()
	self.keys_priority = {
		[COMMON.HASHES.INPUT.A] = 0,
		[COMMON.HASHES.INPUT.D] = 0,
		[COMMON.HASHES.INPUT.ARROW_LEFT] = 0,
		[COMMON.HASHES.INPUT.ARROW_RIGHT] = 0,
	}
	self.last_jump = 0
	local move_f = function(_, action_id, action)
		self.keys_priority[action_id] = self.world.game_world.game.state.time
		--  self:move_player(0, 1)
	end
	self.input_handler:add(COMMON.HASHES.INPUT.A, move_f, true, false, false, false)
	self.input_handler:add(COMMON.HASHES.INPUT.D, move_f, true, false, false, false)
	self.input_handler:add(COMMON.HASHES.INPUT.ARROW_LEFT, move_f, true, false, false, false)
	self.input_handler:add(COMMON.HASHES.INPUT.ARROW_RIGHT, move_f, true, false, false, false)

	self.input_handler:add(COMMON.HASHES.INPUT.ARROW_UP, System.jump, true, false, false, false)
	self.input_handler:add(COMMON.HASHES.INPUT.SPACE, System.jump, true, false, false, false)
	self.input_handler:add(COMMON.HASHES.INPUT.W, System.jump, true, false, false, false)

	self.input_handler:add(COMMON.HASHES.INPUT.S, System.interact, true, false, false, false)
	self.input_handler:add(COMMON.HASHES.INPUT.E, System.interact, true, false, false, false)
	self.input_handler:add(COMMON.HASHES.INPUT.ARROW_DOWN, System.interact, true, false, false, false)
end

function System:interact()
	local game = self.world.game_world.game
	local player = game.level_creator.player
	if (player.on_ground) then
		local object = game.state.interactive_object
		if (object) then
			if (object.lock) then
				if (not object.map_object.properties.code) then
					COMMON.i("interact lock object", System.name)
					self.world.game_world.game:mg_show(ENUMS.MINI_GAMES.LOCK, { object = object })
				else
					COMMON.i("interact lock code object", System.name)
					self.world.game_world.game:mg_show(ENUMS.MINI_GAMES.ENTER_CODE, { object = object })
				end
			elseif (object.door) then
				COMMON.i("interact door", System.name)
				local doors_set = game.level_creator.doors[object.map_object.properties.door_id]
				local door_pair = doors_set[1] == object and doors_set[2] or doors_set[1]
				if (not door_pair.lock) then
					game:enter_door(object)
				end
			elseif (object.map_object.properties.code_id and object.map_object.properties.code_id ~= "") then
				if (object.code_source) then
					COMMON.i("interact code show", System.name)
					self.world.game_world.game:mg_show(ENUMS.MINI_GAMES.SHOW_CODE, { object = object })
				else
					COMMON.i("interact code enter", System.name)
					self.world.game_world.game:mg_show(ENUMS.MINI_GAMES.ENTER_CODE, { object = object })
				end
			elseif (object.wires) then
				COMMON.i("interact wires show", System.name)
				self.world.game_world.game:mg_show(ENUMS.MINI_GAMES.WIRES, { object = object })
			elseif (object.exit) then
				COMMON.i("interact wires exit", System.name)
				player.door_enter_event = true
				player.door_enter_door = object
			elseif (object.cheese_safe) then
				COMMON.i("interact cheese_safe", System.name)
				if (not object.cheese_safe_data.taken) then
					object.cheese_safe_data.taking = true
				end
			elseif (object.star_object) then
				COMMON.i("interact star_object", System.name)
				self.world.game_world.game:star_take(object)
				self.world.game_world.sounds:play_sound(self.world.game_world.sounds.sounds.search_generic)
			end
		end
	end
end

function System:jump()
	local can_jump = true
	local player = self.world.game_world.game.level_creator.player
	local balance = BALANCE
	can_jump = can_jump and player.on_ground
	if (can_jump) then
		if (self.world.game_world.game.state.time - self.last_jump > 0.33) then
			self.last_jump = self.world.game_world.game.state.time
			player.animation_jump = true
			-- self.world.game_world.sounds:play_sound(self.world.game_world.sounds.sounds.loader_jump)
			--timer.delay(0.05,false,function()
			player.body:ApplyLinearImpulse(balance.jump_power_impulse, vmath.vector3(0, 0, 0), true)
			player.body:ApplyForceToCenter(balance.jump_power, true)
			--end)

		end
	end
end

---@param e EntityGame
function System:process(e, dt)
	local game = self.world.game_world.game
	if (game.state.state == ENUMS.GAME_STATE.RUN) then
		self.input_handler:on_input(self, e.input_info.action_id, e.input_info.action)
	end
end

function System:postProcess(dt)
	local gw = self.world.game_world.game
	local executor = gw.command_executor
	---@type EntityGame
	local player = gw.level_creator.player
	local dir = nil
	local priority = -1
	for action, action_priority in pairs(self.keys_priority) do
		if (COMMON.INPUT.PRESSED_KEYS[action] and action_priority > priority) then
			dir = action
			priority = action_priority
		end
	end


	if (dir) then
		if (dir == COMMON.HASHES.INPUT.A or dir == COMMON.HASHES.INPUT.ARROW_LEFT or dir == ENUMS.DIRECTION.LEFT) then
			dir = ENUMS.DIRECTION.LEFT
		elseif (dir == COMMON.HASHES.INPUT.D or dir == COMMON.HASHES.INPUT.ARROW_RIGHT or dir == ENUMS.DIRECTION.RIGHT) then
			dir = ENUMS.DIRECTION.RIGHT
		end
	end

	if (gw.state.state == ENUMS.GAME_STATE.RUN and not gw.state.mg_showing and not gw.state.alarm) then
		if (dir) then
			player.direction = dir
		end
		player.moving = COMMON.LUME.iftern(dir, true, false)
	else
		player.moving = false
	end
end

System:init()

return System
