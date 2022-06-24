local COMMON = require "libs.common"
local ENUMS = require "world.enums.enums"
local BALANCE = require "world.balance.balance"

local TAG = "Entities"


---@class InputInfo
---@field action_id hash
---@field action table

---@class Size
---@field w number
---@field h number

---@class bbox
---@field w number
---@field h number

---@class Tile
---@field tile_id number

---@class LightData
---@field points LightDataPoints[]
---@field points_list number[]

---@class LightDataPoints
---@field position vector3
---@field fraction number


---@class EntityGame
---@field _in_world boolean is entity in world
---@field tag string tag can search entity by tag
---@field position vector3
---@field input_info InputInfo
---@field auto_destroy_delay number
---@field auto_destroy boolean
---@field visible boolean
---@field body Box2dBody
---@field map_object LevelMapObject
---@field tile LevelMapTileData
---@field tile_go TileGo
---@field decor boolean
---@field decor_go DecorGo
---@field player boolean
---@field player_go PlayerGo
---@field direction string
---@field ground_sensor_collisions number
---@field on_ground boolean
---@field light boolean
---@field light_native GameNativeLight
---@field light_debug_go LightDebugGo
---@field light_sensor_collisions number
---@field light_circle bool
---@field light_angle number
---@field light_rays vector3[]
---@field light_camera bool camera light not make scene bright. Draw on top like base spites
---@field light_hit_player bool

---@class ENTITIES
local Entities = COMMON.class("Entities")

---@param world World
function Entities:initialize(world)
	self.world = world
end


--region ecs callbacks
---@param e EntityGame
function Entities:on_entity_removed(e)
	e._in_world = false

	if (e.tile_go) then
		go.delete(e.tile_go.root, true)
		e.tile_go = nil
	end
	if (e.light_native) then
		e.light_native:Destroy()
		e.light_native = nil
	end

	if (e.body) then
		e.body:GetWorld():DestroyBody(e.body)
		e.body = nil
	end
end

---@param e EntityGame
function Entities:on_entity_added(e)
	e._in_world = true
end

---@param e EntityGame
function Entities:on_entity_updated(e)

end
--endregion


--region Entities

---@return EntityGame
function Entities:create_input(action_id, action)
	return { input_info = { action_id = action_id, action = action }, auto_destroy = true }
end

---@param tile LevelMapTile
function Entities:create_tile(tile, position)
	local tile_size = BALANCE.tile_size
	---@type EntityGame
	local e = {}
	e.visible = true
	e.position = vmath.vector3(position.x * tile_size + tile_size / 2, position.y * tile_size + tile_size / 2, position.z)
	e.tile = tile
	e.visible_bbox = { w = tile_size * math.sqrt(2), h = tile_size * math.sqrt(2) } --bbox at rotated diagonal
	return e
end

---@param level LevelData
function Entities:create_player(level)
	---@type EntityGame
	local e = {}
	e.visible = true
	e.player = true
	e.direction = ENUMS.DIRECTION.RIGHT
	e.ground_sensor_collisions = 0
	e.on_ground = true

	local box2d_world = self.world.game.box2d_world
	local physics_scale = BALANCE.physics_scale

	---@type Box2dBodyDef
	local body_def = {
		type = box2d.b2BodyType.b2_dynamicBody,
		fixedRotation = true,
		position = vmath.vector3(level.player.center_x * physics_scale, level.player.center_y * physics_scale, 0)
	}
	local body = box2d_world.world:CreateBody(body_def)
	body:SetSleepingAllowed(false)


	--region player base
	---@type Box2dFixtureDef
	local fixture_def = {
		filter = {
			categoryBits = box2d_world.groups.PLAYER,
			maskBits = box2d_world.masks.PLAYER,
			groupIndex = 0,
		},
		friction = 1,
		density = 1.5,
		restitution = 0,
		shape = box2d.NewPolygonShape()
	}

	local w = 64
	local h = 96
	local light_w = w - 33
	local light_h = h - 33
	local dx = 1.5
	local dy = 1.5
	--left
	fixture_def.shape = box2d.NewPolygonShape()
	local vertices = {
		--left
		vmath.vector3(-w / 2 + dx, -h / 2, 0) * physics_scale,
		vmath.vector3(-w / 2, -h / 2 + dy, 0) * physics_scale,
		vmath.vector3(-w / 2, h / 2 - dy, 0) * physics_scale,
		vmath.vector3(-w / 2 + dx, h / 2, 0) * physics_scale,

		--right
		vmath.vector3(w / 2 - dx, h / 2, 0) * physics_scale,
		vmath.vector3(w / 2, h / 2 - dy, 0) * physics_scale,
		vmath.vector3(w / 2, -h / 2 + dy, 0) * physics_scale,
		vmath.vector3(w / 2 - dx, -h / 2, 0) * physics_scale,
	}
	fixture_def.shape:Set(vertices)
	local f_body = body:CreateFixture(fixture_def)

	local light_fixture_def = {
		filter = {
			categoryBits = box2d_world.groups.PLAYER_LIGHT,
			maskBits = box2d_world.groups.LIGHT_RAY,
			groupIndex = 0,
		},
		friction = 0,
		density = 0,
		isSensor = true,
		shape = box2d.NewPolygonShape()
	}
	local f_light_size = vmath.vector3(light_w / 2 * physics_scale, light_h / 2 * physics_scale, 0)
	local f_light_d_pos = vmath.vector3(0, 0 * physics_scale, 0)
	light_fixture_def.shape:SetAsBox(f_light_size.x, f_light_size.y, f_light_d_pos, 0)
	local f_light = body:CreateFixture(light_fixture_def)

	--add left/right borders with 0 friction

	--endregion

	--region player jump sensor
	---@type Box2dFixtureDef
	local jump_fixture_def = {
		filter = {
			categoryBits = box2d_world.groups.PLAYER,
			maskBits = box2d_world.masks.PLAYER,
			groupIndex = 0,
		},
		friction = 1,
		density = 1,
		isSensor = true,
		shape = box2d.NewPolygonShape()
	}
	jump_fixture_def.shape:SetAsBox((w - 2.5) / 2 * physics_scale, 5 / 2 * physics_scale,
			vmath.vector3(0, -h / 2 * physics_scale, 0), 0)
	local f_ground_sensor = body:CreateFixture(jump_fixture_def)
	f_ground_sensor:SetUserData({ ground_sensor = true })
	--endregion


	e.body_player = {
		f_ground_sensor_ = f_ground_sensor,
		f_body = f_body,
		f_body_friction = f_body:GetFriction(),
		f_light = f_light,
		f_light_size = f_light_size * 2,
		f_light_d_pos = f_light_d_pos,
		f_light = f_light,
	}

	body:SetUserData(e)
	e.body = body
	return e
end

---@param object LevelMapObject
function Entities:create_decor_object(object, bg)
	---@type EntityGame
	local e = {}
	local z = bg and COMMON.CONSTANTS.Z_ORDER.DECOR_BG or COMMON.CONSTANTS.Z_ORDER.DECOR
	if (object.properties.z) then
		z = z + object.properties.z * 0.01
	end
	e.decor = true
	e.decor_bg = bg
	e.position = vmath.vector3(object.center_x, object.center_y, z)
	e.visible = true
	e.map_object = object
	return e
end

---@param object LevelMapObject
function Entities:create_light(object, level)
	local physics_scale = BALANCE.physics_scale
	local box2d_world = self.world.game.box2d_world

	local d_angle = object.properties.angle_end - object.properties.angle_begin

	---@type EntityGame
	local e = {}
	e.position = vmath.vector3(object.center_x, object.center_y, 0)
	e.visible = true
	e.map_object = object
	e.light = true
	e.light_native = game.create_light()
	e.light_angle = 0
	e.light_circle = not (d_angle < 360 and d_angle > -360)
	e.light_angle_speed = math.rad(object.properties.rotation_speed)
	e.light_sensor_collisions = 0
	e.light_static = object.properties.static
	e.light_static_dirty = e.light_static and true
	e.light_enabled = true

	e.light_native:SetPhysicsScale(physics_scale)
	e.light_native:SetRadius(object.properties.distance * physics_scale) --gamma correction
	e.light_native:SetPosition(object.center_x * physics_scale, object.center_y * physics_scale)
	e.light_native:SetAngle(0)
	e.light_native:SetBaseAngles(math.rad(object.properties.angle_begin), math.rad(object.properties.angle_end))
	e.light_native:SetRaysStatic(object.properties.rays)
	e.light_native:SetRaysDynamic(object.properties.rays_dynamic)
	e.light_native:SetStartDrawFraction(object.properties.start_draw_fraction or 0)
	if (object.properties.fixed_power) then
		e.light_native:SetFixedPower(object.properties.fixed_power)
	end

	e.light_native:BufferInit()

	if(object.properties.color)then
		local color = COMMON.LUME.color_parse_hex(object.properties.color)
		e.light_native:SetColor(color.x,color.y,color.z,color.w)
	end

	---@type Box2dBodyDef
	local body_def = {
		type = box2d.b2BodyType.b2_dynamicBody,
		fixedRotation = true,
		position = vmath.vector3(object.center_x * physics_scale, object.center_y * physics_scale, 0),
		gravityScale = 0,
		allowSleep = false
	}

	---@type Box2dFixtureDef
	local fixture_def = {
		filter = {
			categoryBits = box2d_world.groups.LIGHT_RAY,
			maskBits = box2d_world.masks.LIGHT_RAY_GEOMETRY,
			groupIndex = 0,
		},
		friction = 1,
		restitution = 0,
		density = 1,
		isSensor = true,
		shape = box2d.NewPolygonShape()
	}
	fixture_def.shape:SetAsBox(2 * physics_scale, 2 * physics_scale)

	local body = box2d_world.world:CreateBody(body_def)
	local fixture = body:CreateFixture(fixture_def)

	body:SetUserData(e)
	fixture:SetUserData({ light_sensor = true, e = e })

	e.body = body
	return e
end

---@param level LevelData
---@param obj LevelMapObject
function Entities:create_box(level, obj)
	assert(obj.properties.box)
	---@type EntityGame
	local e = {}
	e.map_object = obj
	e.visible = true
	e.box = true

	local box2d_world = self.world.game.box2d_world
	local physics_scale = BALANCE.physics_scale

	---@type Box2dBodyDef
	local body_def = {
		type = box2d.b2BodyType.b2_dynamicBody,
		position = vmath.vector3(obj.center_x * physics_scale, obj.center_y * physics_scale, 0)
	}
	body_def.gravityScale = obj.properties.box2d_gravityScale or 1
	body_def.fixedRotation = obj.properties.box2d_fixedRotation
	local body = box2d_world.world:CreateBody(body_def)
	e.body = body

	---@type Box2dFixtureDef
	local fixture_def = {
		filter = {
			categoryBits = box2d_world.groups.OBSTACLE,
			maskBits = box2d_world.masks.OBSTACLE,
			groupIndex = 0,
		},
		friction = obj.properties.box2d_friction,
		density = obj.properties.box2d_density
	}

	obj.w = obj.w - 0.25
	obj.h = obj.h - 0.25
	local dx = 1.5
	local dy = 1.5
	--left
	fixture_def.shape = box2d.NewPolygonShape()
	local vertices = {
		--left
		vmath.vector3(-obj.w / 2 + dx, -obj.h / 2, 0) * physics_scale,
		vmath.vector3(-obj.w / 2, -obj.h / 2 + dy, 0) * physics_scale,
		vmath.vector3(-obj.w / 2, obj.h / 2 - dy, 0) * physics_scale,
		vmath.vector3(-obj.w / 2 + dx, obj.h / 2, 0) * physics_scale,

		--right
		vmath.vector3(obj.w / 2 - dx, obj.h / 2, 0) * physics_scale,
		vmath.vector3(obj.w / 2, obj.h / 2 - dy, 0) * physics_scale,
		vmath.vector3(obj.w / 2, -obj.h / 2 + dy, 0) * physics_scale,
		vmath.vector3(obj.w / 2 - dx, -obj.h / 2, 0) * physics_scale,


	}
	fixture_def.shape:Set(vertices)
	body:CreateFixture(fixture_def)

	body:SetTransform(body:GetPosition(), math.rad(-obj.rotation))

	body:SetUserData(e)

	return e
end

return Entities




