local COMMON = require "libs.common"
local EcsGame = require "world.game.ecs.game_ecs"
local ENUMS = require "world.enums.enums"
local CAMERAS = require "libs.cameras"
local Box2dWorld = require "libs.box2d_world"
local LevelCreator = require "world.game.levels.level_creator"
local BALANCE = require "world.balance.balance"

local TAG = "GAME_WORLD"

---@class GameWorld
local GameWorld = COMMON.class("GameWorld")

---@param world World
function GameWorld:initialize(world)
	self.world = assert(world)
	self.ecs_game = EcsGame(self.world)
	self.input = {
		type = ENUMS.GAME_INPUT.NONE,
		start_time = socket.gettime(),
		move_delta = 0,
		handle_long_tap = false,
		---@type vector3 screen coords
		touch_pos = nil,
		touch_pos_2 = nil,
		touch_pos_dx = nil,
		touch_pos_dy = nil,
		t1_pressed = nil,
		t2_pressed = nil,
		zoom_point = nil,
		zoom_line_len = nil,
		zoom_initial = nil,
		drag = {
			valid = false,
			movable = false
		}
	}
	self.input.drag = nil
	local cx = (46 * 64) / 2
	local cy = (38 * 64) / 2
	self.camera_config = {
		borders = {
			x_min = cx-720, x_max = cx+720,
			y_min = cy-720, y_max = cy+720,
		},
		zoom = {
			current = 0.33,
			max = 2, min = 0.25
		}
	}
	self:reset_state()
	---@type Level
	self.level = nil
	self:on_resize()
end

function GameWorld:reset_state()
	self.state = {
		state = ENUMS.GAME_STATE.RUN,
		completed = false,
		time = 0,
	}
end

---@param level Level
function GameWorld:level_loaded(level)
	self:final()
	self.level = assert(level)
	self.state.timer = level.data.properties.timer or -1

	self.box2d_world = Box2dWorld({ gravity =BALANCE.physics_gravity,
									velocity_iterations = 12, position_iterations = 6,
									time_step = 1 / 60 }, self.world)

	self.box2d_world.world:SetContactListener({
		BeginContact = function(contact) self:physics_begin_contact(contact) end,
		EndContact = function(contact) self:physics_end_contact(contact) end,
		-- PreSolve = function(contact, old_manifold) self:physics_pre_solve(contact, old_manifold) end,
		-- PostSolve = function(contact, impulse) self:physics_post_solve(contact, impulse) end
	})

	self.ecs_game:add_systems()

	self.level_creator = LevelCreator(self.world)
	self.level_creator:create()

	self:reset_camera()

	--update position and create sprites
	self.box2d_world:update(0.016)
	self.ecs_game:update(0.016)
end

function GameWorld:reset_camera()
	local zoom = 0.33
	self.camera_config.zoom.current = zoom
	CAMERAS.game_camera:set_zoom(zoom, 0, 0)
	local cx = (46 * 64) / 2
	local cy = (38 * 64) / 2
	CAMERAS.game_camera:set_position(vmath.vector3(cx, cy, 0))
end

function GameWorld:update(dt)
	if (self.state.state == ENUMS.GAME_STATE.RUN) then
		local box2d_dt = dt
		if (box2d_dt > 0) then
			box2d_dt = self.box2d_world and self.box2d_world.config.time_step or box2d_dt
		end

		if (not self.state.completed) then self.state.time = self.state.time + box2d_dt end

		self.ecs_game:update(box2d_dt)
		if (self.box2d_world and box2d_dt ~= 0) then
			self.box2d_world:update(box2d_dt)
		end
	else
		--or not drawing? wtf
		self.ecs_game:update(0)
	end
end

function GameWorld:final()
	self:reset_state()
	self.ecs_game:clear()

	if (self.box2d_world) then
		self.box2d_world:dispose()
		self.box2d_world = nil
	end
end

function GameWorld:on_resize()
end

function GameWorld:on_input(action_id, action)
	if (self.state.state == ENUMS.GAME_STATE.RUN and not self.state.mg_showing and not self.state.alarm) then
		self.ecs_game:add_entity(self.ecs_game.entities:create_input(action_id, action))
	end
end

function GameWorld:game_pause()
	if (self.state.state == ENUMS.GAME_STATE.RUN) then
		self.state.state = ENUMS.GAME_STATE.PAUSE
	end
end
function GameWorld:game_resume()
	if (self.state.state == ENUMS.GAME_STATE.PAUSE) then
		self.state.state = ENUMS.GAME_STATE.RUN
	end
end

---@param contact Box2dContact
function GameWorld:physics_begin_contact(contact)
	local f1 = contact:GetFixtureA()
	local f2 = contact:GetFixtureB()
	local b1 = f1:GetBody()
	local b2 = f2:GetBody()
	local f1_e = f1:GetUserData()
	local f2_e = f2:GetUserData()
	local b1_e = b1:GetUserData()
	local b2_e = b2:GetUserData()

	if (f1_e and f1_e.ground_sensor) then b1_e.ground_sensor_collisions = b1_e.ground_sensor_collisions + 1 end
	if (f2_e and f2_e.ground_sensor) then b2_e.ground_sensor_collisions = b2_e.ground_sensor_collisions + 1 end

	if (f1_e and f1_e.light_sensor) then b1_e.light_sensor_collisions = b1_e.light_sensor_collisions + 1 end
	if (f2_e and f2_e.light_sensor) then b2_e.light_sensor_collisions = b2_e.light_sensor_collisions + 1 end


end

---@param contact Box2dContact
function GameWorld:physics_end_contact(contact)
	local f1 = contact:GetFixtureA()
	local f2 = contact:GetFixtureB()
	local b1 = f1:GetBody()
	local b2 = f2:GetBody()
	local f1_e = f1:GetUserData()
	local f2_e = f2:GetUserData()
	local b1_e = b1:GetUserData()
	local b2_e = b2:GetUserData()

	if (f1_e and f1_e.ground_sensor) then b1_e.ground_sensor_collisions = b1_e.ground_sensor_collisions - 1 end
	if (f2_e and f2_e.ground_sensor) then b2_e.ground_sensor_collisions = b2_e.ground_sensor_collisions - 1 end

	if (f1_e and f1_e.light_sensor) then b1_e.light_sensor_collisions = b1_e.light_sensor_collisions - 1 end
	if (f2_e and f2_e.light_sensor) then b2_e.light_sensor_collisions = b2_e.light_sensor_collisions - 1 end

end

return GameWorld



