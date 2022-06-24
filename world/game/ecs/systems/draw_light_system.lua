local ECS = require "libs.ecs"
local COMMON = require "libs.common"

---@class DrawLightSystem:ECSSystem
local System = ECS.processingSystem()
System.name = "DrawLightSystem"
System.filter = ECS.filter("light")

local LIGHT_COLOR = vmath.vector4(1, 1, 1, 0.5)
local LIGHT_COLOR_HIT = vmath.vector4(1, 0, 0, 0.5)

function System:init()
	self.lights = {}
	self.lights_camera = {}
	for i = 1, 16 do
		self.lights[i] = msg.url("game_scene:/light#mesh_" .. i)
	end
end

---@param e EntityGame
function System:process(e, dt)
	if (not e.light_go) then
		local pos = vmath.vector3(e.position)
		pos.z = COMMON.CONSTANTS.Z_ORDER.LIGHT
		if (e.light_camera) then pos.z = COMMON.CONSTANTS.Z_ORDER.CAMERA_RAYS end
		local factory_url = table.remove(self.lights)
		if (factory_url == nil) then
			COMMON.w("no light mesh", System.name)
			return
		end
		local go_id = factory.create(factory_url, vmath.vector3(0, 0, pos.z))
		---@class LightGo
		local light_go = {
			root = msg.url(go_id),
			mesh = {
				root = msg.url(go_id),
				mesh = nil,
				vertices = nil,
				visible = true,
				buffer_version = -1
			},
			data = {
				color = vmath.vector4(),
				hit_player = false;
			}
		}
		light_go.data.color = COMMON.LUME.color_parse_hex2(e.map_object.properties.color)
		light_go.mesh.mesh = COMMON.LUME.url_component_from_url(light_go.mesh.root, COMMON.HASHES.MESH)
		light_go.mesh.vertices = go.get(light_go.mesh.mesh, COMMON.HASHES.hash("vertices"))
		local color = light_go.data.color
		e.light_native:SetColor(color.x, color.y, color.z, color.w)

		e.light_go = light_go

	end

	--update mesh data
	if (e.light_go) then
		local buffer_version = e.light_native:BufferGetContentVersion()
		-- if (not e.light_native:BufferIsValid()) then
		--   print("buffer invalid")
		--    return
		--end
		if (buffer_version ~= e.light_go.mesh.buffer_version) then
			e.light_go.mesh.buffer_version = buffer_version
			resource.set_buffer(e.light_go.mesh.vertices, e.light_native:GetBuffer())
		end

		local visible = e.light_sensor_collisions == 0 and e.light_enabled
		if (e.light_go.mesh.visible ~= visible) then
			e.light_go.mesh.visible = visible
			msg.post(e.light_go.mesh.root, visible and COMMON.HASHES.MSG.ENABLE or COMMON.HASHES.MSG.DISABLE)
		end
	end
end

return System