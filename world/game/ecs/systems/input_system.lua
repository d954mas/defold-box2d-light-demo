local ECS = require 'libs.ecs'
local COMMON = require "libs.common"
local ENUMS = require "world.enums.enums"
local CAMERAS = require "libs.cameras"

---@class InputSystem:ECSSystemProcessing
local System = ECS.processingSystem()
System.filter = ECS.filter("input_info")
System.name = "InputSystem"

function System:init()
	local cam = CAMERAS.game_camera
	self.input_handler = COMMON.INPUT()
	self.input_handler:add(COMMON.HASHES.INPUT.TOUCH, function(_, _, action)
		local game = self.world.game_world.game
		local input = game.input
		if (action.pressed) then
			if (input.type == ENUMS.GAME_INPUT.NONE) then
				input.type = ENUMS.GAME_INPUT.TOUCHED
				input.start_time = socket.gettime()
				input.move_delta = 0
			end
		end
		local prev = input.touch_pos
		if (not action.released) then
			input.touch_pos = vmath.vector3(action.screen_x, action.screen_y, 0)
			local d_time = socket.gettime() - input.start_time
			if (not input.handle_long_tap and d_time > 0.5 and input.move_delta / COMMON.RENDER.screen_size.h < 0.10) then
				input.handle_long_tap = true
				-- if (game.game_building_selected) then
				--  input.type = ENUMS.GAME_INPUT.DRAG
				--  end
			end
		end
		if (prev) then
			game.input.move_delta = game.input.move_delta + vmath.length(game.input.touch_pos - prev)
		end
		--action pressed get very big dx values
		if (not action.pressed) then
			game.input.touch_pos_dx = action.screen_dx
			game.input.touch_pos_dy = action.screen_dy
		else
			game.input.touch_pos_dx = 0
			game.input.touch_pos_dy = 0
		end

		if (game.input.type == ENUMS.GAME_INPUT.TOUCHED) then
			--move camera
			local move_v = CAMERAS.game_camera:screen_to_world_2d(-game.input.touch_pos_dx, -game.input.touch_pos_dy, true)
			local new_pos = cam.wpos + move_v
			local borders = game.camera_config.borders
			new_pos.x = COMMON.LUME.clamp(new_pos.x, borders.x_min, borders.x_max)
			new_pos.y = COMMON.LUME.clamp(new_pos.y, borders.y_min, borders.y_max)
			cam:set_position(new_pos)
		end
		-- elseif (game.input.type == ENUMS.GAME_INPUT.ZOOMING) then
	end, true, false, true, true)
	self.input_handler:add(COMMON.HASHES.INPUT.SCROLL_UP, function(_, _, action)
		if (not self.world.game_world.debug_state.move_camera) then return end
		if (COMMON.INPUT.PRESSED_KEYS[COMMON.HASHES.INPUT.LEFT_CTRL] or
				COMMON.INPUT.PRESSED_KEYS[COMMON.HASHES.INPUT.LEFT_SHIFT]) then
			if (COMMON.INPUT.TOUCH[1]) then
				self:zoom(0.1, COMMON.INPUT.TOUCH[1].screen_x / COMMON.RENDER.screen_size.w,
						COMMON.INPUT.TOUCH[1].screen_y / COMMON.RENDER.screen_size.h)
			end
		end
	end, false, false, false, true)
	self.input_handler:add(COMMON.HASHES.INPUT.SCROLL_DOWN, function(_, _, action)
		if (not self.world.game_world.debug_state.move_camera) then return end
		if (COMMON.INPUT.PRESSED_KEYS[COMMON.HASHES.INPUT.LEFT_CTRL] or
				COMMON.INPUT.PRESSED_KEYS[COMMON.HASHES.INPUT.LEFT_SHIFT]) then
			if (COMMON.INPUT.TOUCH[1]) then
				self:zoom(-0.1, COMMON.INPUT.TOUCH[1].screen_x / COMMON.RENDER.screen_size.w,
						COMMON.INPUT.TOUCH[1].screen_y / COMMON.RENDER.screen_size.h)
			end
		end
	end, false, false, false, true)
	self.input_handler:add(COMMON.HASHES.INPUT.TOUCH_MULTI, function(_, _, action)
		if (not self.world.game_world.debug_state.move_camera) then return end
		-- print("touch multi:")
		local game = self.world.game_world.game
		local t2 = action.touch[2]
		local t1 = action.touch[1]
		if (t1.pressed) then game.input.t1_pressed = true end
		if (t2 and t2.pressed) then game.input.t2_pressed = true end

		if (t1.released) then game.input.t1_pressed = false end
		if (not t2 or t2.released) then game.input.t2_pressed = false end

		if (game.input.type == ENUMS.GAME_INPUT.NONE) then
			if (game.input.t1_pressed and game.input.t2_pressed) then
				game.input.type = ENUMS.GAME_INPUT.ZOOMING
			elseif (game.input.t1_pressed) then
				game.input.type = ENUMS.GAME_INPUT.TOUCHED
			end
		elseif (game.input.type == ENUMS.GAME_INPUT.TOUCHED) then
			if (game.input.t1_pressed and game.input.t2_pressed) then
				game.input.type = ENUMS.GAME_INPUT.ZOOMING
				-- elseif (not game.input.t1_pressed and not game.input.t2_pressed) then
				--   game.input.type = ENUMS.GAME_INPUT.NONE
			end
		elseif (game.input.type == ENUMS.GAME_INPUT.ZOOMING) then
			if (not game.input.t1_pressed or not game.input.t2_pressed) then
				if (game.input.t1_pressed or game.input.t2_pressed) then
					game.input.type = ENUMS.GAME_INPUT.TOUCHED
					-- else
					-- game.input.type = ENUMS.GAME_INPUT.NONE
				end
			end
		end

		--touched is handled in single touch input
		--  if (game.input.type == ENUMS.GAME_INPUT.TOUCHED) then
		-- if (game.input.t2_pressed and not game.input.t1_pressed) then
		--call single touch on not need it?
		-- print("single touch call")
		--end
		-- else
		if (game.input.type == ENUMS.GAME_INPUT.ZOOMING) then
			local zoom_point = (vmath.vector3(t2.screen_x, t2.screen_y, 0) + vmath.vector3(t1.screen_x, t1.screen_y, 0)) * 0.5
			local zoom_line = (vmath.vector3(t2.screen_x, t2.screen_y, 0) - vmath.vector3(t1.screen_x, t1.screen_y, 0))
			game.input.zoom_point = zoom_point
			if (not game.input.zoom_initial) then
				game.input.zoom_initial = CAMERAS.game_camera.zoom
				game.input.zoom_line_len = vmath.length(zoom_line)
			else
				local scale = vmath.length(zoom_line) / game.input.zoom_line_len
				local dx = zoom_point.x / COMMON.RENDER.screen_size.w
				local dy = zoom_point.y / COMMON.RENDER.screen_size.h
				local zoom_cfg = self.world.game_world.game.camera_config.zoom
				--  print(string.format("zoom:%s scale:%s dx:%s dy:%s", game.input.zoom_initial * scale- zoom_cfg.current, scale, dx, dy))
				self:zoom(game.input.zoom_initial * scale - zoom_cfg.current, dx, dy)
			end
		end

	end, true, false, true, true)
end

---@param center_x number screen [0,1]
---@param center_y number screen [0,1]
function System:zoom(value, center_x, center_y)
	--    checks("?", "number", "number", "number")
	--	assert(center_x >= 0 and center_x <= 1)
	--	assert(center_y >= 0 and center_y <= 1)
	if not ((center_x >= 0 and center_x <= 1) and (center_x >= 0 and center_x <= 1)) then return end
	local zoom_cfg = self.world.game_world.game.camera_config.zoom
	local zoom = zoom_cfg.current
	local zoom_new = COMMON.LUME.clamp(zoom + value, zoom_cfg.min, zoom_cfg.max)
	local d_zoom = zoom_new - zoom
	if (d_zoom ~= 0) then
		zoom_cfg.current = zoom_new
		CAMERAS.game_camera:set_zoom(zoom_new, center_x, center_y)
	end

end

function System:preProcess(dt)
	local input = self.world.game_world.game.input
	local enabled = self.world.game_world.debug_state.move_camera

	if ((not enabled or not COMMON.INPUT.PRESSED_KEYS[COMMON.HASHES.INPUT.TOUCH]) and
			(input.type ~= ENUMS.GAME_INPUT.NONE or input.touch_pos ~= nil)) then
		local prev_type = input.type
		local d_time = socket.gettime() - input.start_time
		local d_move = input.move_delta
		local is_zoom = input.zoom_line_len

		local x, y = input.touch_pos.x, input.touch_pos.y

		input.type = ENUMS.GAME_INPUT.NONE
		input.touch_pos = nil
		input.touch_pos_2 = nil
		input.touch_pos_dx = nil
		input.touch_pos_dy = nil
		input.t1_pressed = nil
		input.t2_pressed = nil
		input.zoom_point = nil
		input.zoom_line_len = nil
		input.zoom_initial = nil
		input.move_delta = 0
		input.handle_long_tap = false
		input.start_time = socket.gettime()

		--print("*****")
		--print(d_time)
		--print(d_move)


		if (prev_type == ENUMS.GAME_INPUT.TOUCHED and not is_zoom) then
			--tap cell without movement
			--reset selected building
			--or select new
			if (d_time < 0.5 and d_move / COMMON.RENDER.screen_size.h < 0.10) then
				self:tap(x, y)
			end
		end
	end
end

function System:tap(x, y)

end

---@param e EntityGame
function System:process(e, dt)
	self.input_handler:on_input(self, e.input_info.action_id, e.input_info.action)
end

System:init()

return System
