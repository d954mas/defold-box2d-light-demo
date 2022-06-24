#ifndef light_h
#define light_h

#include <dmsdk/sdk.h>
#include <vector>
#include <world.h>

#include "game_base_userdata.h"

#define MAX_DYNAMIC_RAYS 256
#define MAX_STATIC_RAYS 256


namespace d954masGame {

struct RayData {
  float endX=0, endY=0;
  float dx=0, dy=0;
  float angle = 0;
  bool dynamic = false;
  //skip dynamic ray for mesh
  //if fraction < N(0.95)
  bool skip = false;
  //sqrt len of dynamic ray
  //use to skip some dynamic rays that hit something
  //before target
  float dynamicLen2 = 0;
};

struct RayPosition {
  float x=0, y=0;
  float fraction = 0;
  bool dynamic = true;
};

class Light  : public BaseUserData{
private:

public:
    float x = 0, y = 0, angle = 0, angleBegin = 0, angleEnd = 0, radius = 0;
    float fixedPower = -1;
    b2AABB aabb;
    float physicsScale = 1;
    bool isCircle = false;
    bool dirtyPosition = false, dirtyRays = false, dirtyAngle = false;
    bool playerIsHit = false;
    bool playerHitEnabled = false; //try to find hit player or not
    int raysStatic = 0;
    int raysDynamic = 0;
    int raysTotal = 0;
    int rayDynamicId = 0;
    float startDrawFraction = 0; //begin draw only from that fraction;
    float color_r = 0, color_g = 0, color_b = 0, color_a = 0;
    RayData raysDataStatic[MAX_STATIC_RAYS];
    RayData raysDataDynamic[MAX_DYNAMIC_RAYS];
    int raysDataDynamicSize = 0;
    std::vector<RayData*> raysResult;
    RayPosition* raysPosition = NULL;
    dmBuffer::HBuffer buffer = NULL;
    int vertices = 0;
    float* bufferPositions;
    uint32_t  bufferPositionsStride;
    float* bufferColors;
    uint32_t  bufferColorsStride;
    float* bufferData;
    uint32_t  bufferDataStride;

    Light();
    ~Light();
    virtual void Destroy(lua_State *L);

    void SetPosition(float x, float y);
    void SetRadius(float radius);
    void SetRaysStatic(int rays);
    void SetRaysDynamic(int rays);
    void SetAngle(float angle);
    void SetPhysicsScale(float scale);
    void SetBaseAngles(float angleBegin, float angleEnd);
    void SetStartDrawFraction(float startDrawFraction);
    void SetFixedPower(float fraction);
    void UpdateLight();
    void SetHitPlayer(bool hit);
    void UpdateHitPlayer(float px, float py, float pw, float ph);
    void BufferSetColor(float r, float g, float b, float a);
    bool BufferIsValid();
    std::vector<RayData> UpdateHitPlayerGetRays(float px, float py, float pw, float ph);
    void BufferInit();
};

void LightInitMetaTable(lua_State *L);
Light* Light_get_userdata_safe(lua_State *L, int index);

}
#endif