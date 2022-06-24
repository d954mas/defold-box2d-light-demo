local COMMON = require "libs.common"
local LEVELS = require "world.game.levels.levels"
local TILESETS = require "world.game.levels.tilesets"
local BALANCE = require "world.balance.balance"

---@class LevelCreator
local Creator = COMMON.class("LevelCreator")

---@param world World
function Creator:initialize(world)
	self.world = world
	self.level = world.game.level
	self.ecs = world.game.ecs_game
	self.entities = world.game.ecs_game.entities

end

function Creator:create()
	self.player = nil
	self.geometry = {}

	self:__create_tiles()
	self:__create_geometry()
	self:__create_player()
	self:__create_lights()
	self:__create_boxes()

	self.ecs:refresh()

--self:__create_decor()
end

function Creator:__create_player()
	self.player = self.entities:create_player(self.level.data)
	self.ecs:add_entity(self.player)
end

function Creator:__create_geometry()
	local box2d_world = self.world.game.box2d_world
	local physics_scale = BALANCE.physics_scale

	---@type Box2dBodyDef
	local body_def = {
		type = box2d.b2BodyType.b2_staticBody,
		position = vmath.vector3(0)
	}
	---@type Box2dFixtureDef
	local fixture_def = {
		filter = {
			categoryBits = box2d_world.groups.GEOMETRY,
			maskBits = box2d_world.masks.GEOMETRY,
			groupIndex = 0,
		},
		friction = 2,
		density = 2,
		shape = box2d.NewPolygonShape()
	}

	local fixture_def_chain = {
		filter = {
			categoryBits = box2d_world.groups.GEOMETRY,
			maskBits = box2d_world.masks.GEOMETRY,
			groupIndex = 0,
		},
		friction = 2,
		density = 2,
	}

	for _, obj in ipairs(self.level.data.geometry) do
		if (obj.shape == "rectangle") then
			body_def.position = vmath.vector3((obj.x + obj.w / 2) * physics_scale, (obj.y - obj.h / 2) * physics_scale, 0)
			fixture_def.shape = box2d.NewPolygonShape()
			fixture_def.shape:SetAsBox(obj.w / 2 * physics_scale, obj.h / 2 * physics_scale)
			local body = box2d_world.world:CreateBody(body_def)
			local f = body:CreateFixture(fixture_def)
			local e = {
				geometry = true,
				shape_object = obj,
				body = body
			}
			table.insert(self.geometry, e)
		elseif (obj.shape == "ellipse") then
			body_def.position = vmath.vector3(obj.x * physics_scale, obj.y * physics_scale, 0)
			fixture_def.shape = box2d.NewCircleShape()
			fixture_def.shape:SetRadius(obj.radius * physics_scale)
			local body = box2d_world.world:CreateBody(body_def)
			local f = body:CreateFixture(fixture_def)
			local e = {
				geometry = true,
				shape_object = obj,
				body = body
			}
			table.insert(self.geometry, e)
		elseif (obj.shape == "polygon") then
			local vertices = {}
			local ox, oy = obj.x * physics_scale, obj.y * physics_scale
			if (obj.properties.reverse) then
				for i = #obj.vertices, 1, -1 do
					local v = obj.vertices[i]
					table.insert(vertices, vmath.vector3(v[1] * physics_scale, v[2] * physics_scale, 0))
				end
			else
				for _, v in ipairs(obj.vertices) do
					table.insert(vertices, vmath.vector3(v[1] * physics_scale, v[2] * physics_scale, 0))
				end
			end

			body_def.position = vmath.vector3(ox, oy, 0)
			fixture_def_chain.shape = box2d.NewChainShape()
			fixture_def_chain.shape:CreateLoop(vertices)

			local body = box2d_world.world:CreateBody(body_def)
			local f = body:CreateFixture(fixture_def_chain)

			local e = {
				geometry = true,
				shape_object = obj,
				body = body
			}

			table.insert(self.geometry, e)
		end
	end
end

function Creator:__create_tiles_layer(layer, z)
	local idx = 1
	local position = vmath.vector3(0, 0, z)
	for y = 0, self.level.data.size.h - 1 do
		position.y = y
		for x = 0, self.level.data.size.w - 1 do
			position.x = x
			local tile = layer[idx]
			if (tile) then
				local tile_data = TILESETS.by_id[tile.id]
				local e_tile = self.entities:create_tile(tile, position)
				self.ecs:add_entity(e_tile)
				position.z = z
			end
			idx = idx + 1
		end
	end
end

function Creator:__create_tiles()
	self:__create_tiles_layer(self.level.data.front1, COMMON.CONSTANTS.Z_ORDER.TILE_BASE)
end

function Creator:__create_decor()
	--world gui not existed. will be exist on next frame
	timer.delay(0, false, function()
		local ctx = COMMON.CONTEXT:set_context_top_game_world_gui()
		local create_text = function(text, bg)
			local str = text.text
			-- str = COMMON.LOCALIZATION["game_" .. str]()
			local scale = text.pixelsize / 53 * 1.5

			str = "<size=" .. scale .. ">" .. str .. "</size>"
			local lbl = ctx.data:create_label({ text = str,
												center_v = true,
												size = { w = text.w, h = text.h },
												position = vmath.vector3(text.center_x, text.center_y, 0), bg = bg })
			lbl.center_v = true
		end

		local create_object = function(object, bg)
			local e = self.entities:create_decor_object(object, bg)
			return e
		end

		---@param object LevelMapObject
		local can_create = function(object)
			local tile_properties = TILESETS.by_id[object.tile_id]
			if (tile_properties.properties.pc_only) then
				return COMMON.CONSTANTS.PLATFORM_IS_PC or (COMMON.CONSTANTS.PLATFORM_IS_WEB and not COMMON.html5_is_mobile())
			else
				return true
			end
		end

		for _, text in ipairs(self.level.data.decor.texts) do
			create_text(text, false)
		end
		for _, obj in ipairs(self.level.data.decor.objects) do
			if (can_create(obj)) then
				self.ecs:add_entity(create_object(obj, false))
			end
		end

		for _, text in ipairs(self.level.data.decor_bg.texts) do
			create_text(text, true)
		end
		for _, obj in ipairs(self.level.data.decor_bg.objects) do
			if (can_create(obj)) then
				self.ecs:add_entity(create_object(obj, true))
			end
		end
		ctx:remove()
	end)

end

function Creator:__create_lights()
	for _, obj in ipairs(self.level.data.lights) do
		local e = self.entities:create_light(obj, self.level.data)
		self.ecs:add_entity(e)
	end
end

function Creator:__create_boxes()
	for i, obj in ipairs(self.level.data.boxes) do
		local e = self.entities:create_box(self.level.data, obj)
		self.ecs:add_entity(e)
	end
end

return Creator