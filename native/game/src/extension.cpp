// myextension.cpp
// Extension lib defines
#define EXTENSION_NAME Game
#define LIB_NAME "Game"
#define MODULE_NAME "game"
// include the Defold SDK
#include <dmsdk/sdk.h>
#include "light.h"
#include <world.h>
#include <filter.h>

using namespace d954masGame;
using namespace box2dDefoldNE;
namespace d954masGame {
    b2World* gameWorld = NULL;
    b2Filter filterGeometry, filterPlayer;
}

static int lua_create_light(lua_State *L) {
    DM_LUA_STACK_CHECK(L, 1);

	Light *light = new Light();
	light->Push(L);
	return 1;
}


static int lua_set_world(lua_State *L) {
    World* world = World_get_userdata_safe(L, 1);
    d954masGame::gameWorld = world->world;
	return 0;
}

static int lua_set_filter_geometry(lua_State *L) {
	d954masGame::filterGeometry = b2Filter_from_table(L,1);
	return 0;
}

static int lua_set_filter_player(lua_State *L) {
	d954masGame::filterPlayer = b2Filter_from_table(L,1);
	return 0;
}


// Functions exposed to Lua
static const luaL_reg Module_methods[] ={
   {"create_light", lua_create_light},
   {"set_world", lua_set_world},
   {"set_filter_geometry", lua_set_filter_geometry},
   {"set_filter_player", lua_set_filter_player},
	{0, 0}
};

static void LuaInit(lua_State* L){
	int top = lua_gettop(L);
	luaL_register(L, MODULE_NAME, Module_methods);
	lua_pop(L, 1);
	assert(top == lua_gettop(L));
}

static dmExtension::Result AppInitializeMyExtension(dmExtension::AppParams* params){return dmExtension::RESULT_OK;}
static dmExtension::Result InitializeMyExtension(dmExtension::Params* params){
	// Init Lua
	LuaInit(params->m_L);

	LightInitMetaTable(params->m_L);

	printf("Registered %s Extension\n", MODULE_NAME);
	return dmExtension::RESULT_OK;
}

static dmExtension::Result AppFinalizeMyExtension(dmExtension::AppParams* params){return dmExtension::RESULT_OK;}

static dmExtension::Result FinalizeMyExtension(dmExtension::Params* params){	return dmExtension::RESULT_OK;}

DM_DECLARE_EXTENSION(EXTENSION_NAME, LIB_NAME, AppInitializeMyExtension, AppFinalizeMyExtension, InitializeMyExtension, 0, 0, FinalizeMyExtension)