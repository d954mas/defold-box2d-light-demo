#include "light.h"
#include "game_utils.h"
#include <math.h>

#include <world.h>
#include <filter.h>
#include <unordered_set>
#include <extra_utils.h>

#define META_NAME "Game::LightClass"
#define USERDATA_TYPE "light"

#define TWO_PI  6.28318530717958648f
#define PI   3.14159265358979323846

// small enough value used to translate ends of the rays to the side when targeting shape points.
// smaller values may produce precision errors
#define OFFSET_SIZE 0.02f
//1 degree
#define OFFSET_PLAYER_ANGLE 0*0.01745329252f

//light a little bigger to fix tile borders
//add 0.1 of meter(1meter is 1 tile)
#define LIGHT_ADD_LEN 0.1f

#define SKIP_DYNAMIC_FRACTION 0.95f


using  namespace box2dDefoldNE;

namespace d954masGame {

extern b2World* gameWorld;
extern b2Filter filterGeometry;
extern b2Filter filterPlayer;

static bool sortRays (RayData *r1,RayData* r2) {
    return (r1->angle<r2->angle);
}

static inline float VectorAngle(float x1, float y1, float x2, float y2){
    //https://stackoverflow.com/questions/14066933/direct-way-of-computing-clockwise-angle-between-2-vectors
    //angle beetween first ray and this ray
    float dot = x1*x2 + y1*y2;      // dot product between [x1, y1] and [x2, y2]
    float det = x1*y2 - y1*x2 ;     // determinant
    //  dmLogInfo("atan");
    // dmLogInfo("dot:%f det:%f",dot,det);
    float angleRay = atan2(det, dot);  // atan2(y, x) or atan2(sin, cos)
    // dmLogInfo("angle1:%f",angleRay);
    //  dmLogInfo("dx:%f dy:%f",x1-x2,y1-y2);
    if(angleRay < 0){ angleRay += TWO_PI;}
    // angleRay = PI - angleRay;
    // dmLogInfo("angle:%f/%f", angleRay,  light->angleEnd-light->angleBegin);
    return angleRay;

}


// Return true if contact calculations should be performed between these two shapes.
// If you implement your own collision filter you may want to build from this implementation.
static inline bool filterCollide(const b2Filter& filterA, const b2Filter& filterB){
     //ignore groups for raycast
	//if (filterA.groupIndex == filterB.groupIndex && filterA.groupIndex != 0)
	//{
	//	return filterA.groupIndex > 0;
	//}
	bool collide = (filterA.maskBits & filterB.categoryBits) != 0 && (filterA.categoryBits & filterB.maskBits) != 0;
	return collide;
}

class LightRayCastCallbackGeometry : public b2RayCastCallback {
    public:
        b2Vec2 result = b2Vec2(0,0);
        float resultFraction = -1;
        LightRayCastCallbackGeometry(){  // This is the constructor
        }

        float ReportFixture(b2Fixture* fixture, const b2Vec2& point,const b2Vec2& normal, float fraction) {
            if (filterCollide(filterGeometry, fixture->GetFilterData())){
                this->result.x = point.x;
                this->result.y = point.y;
                this->resultFraction = fraction;
                return fraction;
            }
            return -1;
        }

        void Reset(){
            result.x = 0;
            result.y = 0;
            resultFraction = -1;
        }
};


class LightRayCastCallbackPlayer : public b2RayCastCallback {
    public:
           bool payerIsHit = false;
           float playerHitFraction = -1;
           b2Vec2 result = b2Vec2(0,0);
           float resultFraction = -1;
           LightRayCastCallbackPlayer(){  // This is the constructor

           }

           float ReportFixture(b2Fixture* fixture, const b2Vec2& point,const b2Vec2& normal, float fraction) {
               bool collidePlayer = filterCollide(filterPlayer, fixture->GetFilterData());
               if (collidePlayer){
                    this->playerHitFraction = fraction;
               }

               if (collidePlayer || filterCollide(filterGeometry, fixture->GetFilterData())){
                   this->result.x = point.x;
                   this->result.y = point.y;
                   this->resultFraction = fraction;
                   return fraction;
               }
               return -1;
           }

           void Reset(){
               payerIsHit = false;
               playerHitFraction = -1;
               result.x = 0;
               result.y = 0;
               resultFraction = -1;
           }
};

class LightQueryCallback : public b2QueryCallback {
    public:
        std::unordered_set<b2Fixture*> fixtures; // NOTE set because chain shape is reported for each segment in aabb, we test entire shape, so we dont care
        LightQueryCallback(){  // This is the constructor

        }

        bool ReportFixture(b2Fixture* fixture) {
            if (filterCollide(filterGeometry, fixture->GetFilterData())){
                fixtures.insert(fixture);
            }
            return true;
        }

        void Reset(){
            fixtures.clear();
        }
};


static LightRayCastCallbackGeometry cbGeometry;
static LightRayCastCallbackPlayer cbPlayer;
static LightQueryCallback cbQuery;



Light::Light():  BaseUserData(USERDATA_TYPE){
    this->metatable_name = META_NAME;
    this->obj = this;
   // this->raysDataStatic = new RayData[MAX_STATIC_RAYS];
   // this->raysDataDynamic = new RayData[MAX_DYNAMIC_RAYS];
    for(int i=0;i<MAX_DYNAMIC_RAYS;i++){
        this->raysDataDynamic[i].dynamic = true;
    }
}

Light::~Light() {
   // if(this->raysDataStatic != NULL){
     //   delete[] this->raysDataStatic;
    //    this->raysDataStatic = NULL;
   // }
  //  if(this->raysDataDynamic != NULL){
   //     delete[] this->raysDataDynamic;
    //    this->raysDataDynamic = NULL;
  //  }
    if(this->raysPosition != NULL){
        delete[] this->raysPosition;
        this->raysPosition = NULL;
    }
    if(this->buffer != NULL){
        dmBuffer::Destroy(buffer);
        this->buffer = NULL;
    }

}


Light* Light_get_userdata_safe(lua_State *L, int index) {
    Light *lua_light = (Light*) BaseUserData_get_userdata(L, index, USERDATA_TYPE);
    return lua_light;
}

void Light::SetPosition(float x, float y){
    if(this->x != x || this->y != y){
        this->x = x;
        this->y = y;
        this->dirtyPosition = true;
    }
}
void Light::SetAngle(float angle){
    if(this->angle != angle){
        this->angle = angle;
        this->dirtyAngle = true;
    }
}
void Light::SetBaseAngles(float angleBegin, float angleEnd){
    if(this->angleBegin != angleBegin || this->angleEnd != angleEnd){
        this->angleBegin = angleBegin;
        this->angleEnd = angleEnd;
        this->dirtyAngle = true;
        float deltaAngle = angleEnd - angleBegin;
        this->isCircle = deltaAngle<= -6.28318 || deltaAngle >= 6.28318;
    }
}
void Light::SetRaysStatic(int rays){
    if(this->buffer != NULL){
        dmLogError("can't set rays. Buffer already exist");
        return;
    }
    if(rays>MAX_STATIC_RAYS){
        rays = MAX_STATIC_RAYS;
    }
    if(this->raysStatic != rays ){
        this->raysStatic = rays;
       // if(this->raysDataStatic!= NULL){
       //     delete[] this->raysDataStatic;
       // }
      //  this->raysDataStatic = new RayData[rays];
        this->dirtyRays = true;
    }
}

void Light::SetRaysDynamic(int rays){
    if(this->buffer != NULL){
        dmLogError("can't set rays. Buffer already exist");
        return;
    }
    if(rays>MAX_DYNAMIC_RAYS){rays = MAX_DYNAMIC_RAYS;}
    if(this->raysDynamic != rays ){

        this->raysDynamic = rays;
        //if(this->raysDataDynamic != NULL){
        //    delete[] this->raysDataDynamic;
      //  }
        //TODO NO IDEAS WHY THAT NOT WORKER IN WEB
     //   this->raysDataDynamicSize = rays*3;//cast more rays then can draw
        this->raysDataDynamicSize = rays*3;//cast more rays then can draw
        if(this->raysDataDynamicSize>MAX_DYNAMIC_RAYS){this->raysDataDynamicSize = MAX_DYNAMIC_RAYS;}

       // this->raysDataDynamic = new RayData[ this->raysDataDynamicSize];
       // for(int i=0;i<raysDataDynamicSize;i++){
        //    this->raysDataDynamic[i].dynamic = true;
     //  }
        this->dirtyRays = true;
    }
}

void Light::SetRadius(float radius){
    if(this->radius != radius ){
        this->radius = radius;
        this->dirtyRays = true;
    }
}

void Light::SetFixedPower(float fraction){
    this->fixedPower = fraction;
}
void Light::SetPhysicsScale(float physicsScale){
    this->physicsScale = physicsScale;
}

//only updated when buffer is init
void Light::SetStartDrawFraction(float startDrawFraction){
    this->startDrawFraction = startDrawFraction;
}

const dmBuffer::StreamDeclaration streams_decl[] = {
    {dmHashString64("position"), dmBuffer::VALUE_TYPE_FLOAT32, 3},
    {dmHashString64("color0"), dmBuffer::VALUE_TYPE_FLOAT32, 4},
    {dmHashString64("normal"), dmBuffer::VALUE_TYPE_FLOAT32, 3},
    {dmHashString64("data"), dmBuffer::VALUE_TYPE_FLOAT32, 3},
};

void Light::BufferInit(){
    if(this->buffer != NULL){
        dmLogError("can't init buffer. Buffer already exist");
        return;
    }

    int rays = raysStatic + raysDynamic;
    this->raysPosition = new RayPosition[rays];


    if(this->isCircle){
        this->vertices = (rays-1) * 3;
    }else{
        this->vertices = (rays-1) * 3;
    }
    dmBuffer::Result r = dmBuffer::Create((this->vertices), streams_decl, 4, &buffer);
    if (r == dmBuffer::RESULT_OK) {
        dmBuffer::Result r = dmBuffer::GetStream(this->buffer, dmHashString64("position"),
            (void**)&this->bufferPositions, NULL, NULL, &this->bufferPositionsStride);
        if (r != dmBuffer::RESULT_OK) {
            dmLogError("can't get buffer position");
        }

        r = dmBuffer::GetStream(this->buffer, dmHashString64("color0"),
                  (void**)&this->bufferColors, NULL, NULL, &this->bufferColorsStride);
        if (r != dmBuffer::RESULT_OK) {
            dmLogError("can't get buffer colors");
        }

        //set default value to zero. Not sure that need it.
        float* posIter = this->bufferPositions;
        for (int i = 0; i<(this->vertices); ++i) {
            posIter[0] = 0;
            posIter[1] = 0;
            posIter[2] = 0;
            posIter +=this->bufferPositionsStride;
        }

        float* bufferNormal;
        uint32_t bufferNormalStride;
        r = dmBuffer::GetStream(this->buffer, dmHashString64("normal"),
                          (void**)&bufferNormal, NULL, NULL, &bufferNormalStride);
        if (r != dmBuffer::RESULT_OK) {
            dmLogError("can't get buffer normal");
        }else{
            for (int i = 0; i<(this->vertices); ++i) {
                bufferNormal[0] = 0;
                bufferNormal[1] = 0;
                bufferNormal[2] = 1;
                bufferNormal +=bufferNormalStride;
            }
        }

        r = dmBuffer::GetStream(this->buffer, dmHashString64("data"),
                      (void**)&this->bufferData, NULL, NULL, &this->bufferDataStride);
        if (r != dmBuffer::RESULT_OK) {
            dmLogError("can't get buffer data");
        }else{
            float* bufferDataIter = this->bufferData;
            for (int i = 0; i<(this->vertices); i++) {
                    if(i%3 == 0){
                        bufferDataIter[0] = 1;
                    }else{
                        bufferDataIter[0] = 0;
                    }

                bufferDataIter[1] = this->startDrawFraction;
                bufferDataIter[2] = this->fixedPower;
                bufferDataIter +=this->bufferDataStride;
            }
        }

        this->BufferSetColor(color_r,color_g,color_b,color_a);

    } else {
        dmLogError("can't create buffer");
    }
   return;
}

void Light::BufferSetColor(float r, float g, float b, float a){
    if(this->buffer != NULL && (r != color_r || g != color_g || b!= color_b || a != color_a)){
        color_r = r;
        color_g = g;
        color_b = b;
        color_a = a;
        float* colorIter = this->bufferColors;
        for (int i = 0; i<this->vertices; ++i) {
            colorIter[0] = r;
            colorIter[1] = g;
            colorIter[2] = b;
            colorIter[3] = a;
            colorIter +=this->bufferColorsStride;
        }
        dmBuffer::UpdateContentVersion(this->buffer);
    }
}

void Light::SetHitPlayer(bool hit){
    if(this->playerIsHit != hit ){
        this->playerIsHit = hit;
    }
}

std::vector<RayData> Light::UpdateHitPlayerGetRays(float px, float py, float pw, float ph){
    std::vector<RayData> result;
    //TODO add rays that in player area
    //9 light for player
    /*for(int y=-1;y<=1;y++){
        for(int x=-1;x<=1;x++){
            float endX = px+x*(pw/2-0.001);
            float endY = py+y*(ph/2-0.001);


            float x1 = this->raysDataStatic[0].endX-this->x;
            float y1 = this->raysDataStatic[0].endY-this->y;
            float x2 = (endX-this->x);
            float y2 = (endY-this->y);
            float angleRay = VectorAngle(x1,y1,x2,y2);
            if(angleRay > OFFSET_PLAYER_ANGLE
            && angleRay< this->angleEnd-this->angleBegin - OFFSET_PLAYER_ANGLE){
                angleRay += this->raysDataStatic[0].angle;
                RayData data;
                data.endX = endX;
                data.endY = endY;
                data.angle = angleRay;
                data.angle = angleRay;
                data.dynamic = false;
                result.push_back(data);
            }

        }
    }*/
    //all lights
     for (int i = 1; i<this->raysStatic-1; ++i) {
        result.push_back(this->raysDataStatic[i]);
    }


    return result;
}

void Light::UpdateHitPlayer(float px, float py, float pw, float ph){
    bool hitPlayer = false;
    b2Vec2 start(this->x, this->y);

    std::vector<RayData> data = this->UpdateHitPlayerGetRays(px,py,pw,ph);
    for(int i=0; i<data.size(); i++){
        RayData ray = data[i];
        cbPlayer.Reset();
        gameWorld->RayCast(&cbPlayer, start, b2Vec2(ray.endX,ray.endY));
        hitPlayer = cbPlayer.playerHitFraction != -1 && (cbPlayer.resultFraction== -1
                                   || cbPlayer.playerHitFraction<=cbPlayer.resultFraction);
     //  dmLogInfo("hit player %d %f %f",hitPlayer,cbPlayer.playerHitFraction,cbPlayer.resultFraction);

        if(hitPlayer){break;}
    }
    this->SetHitPlayer(hitPlayer);

}

static inline b2Vec2 GetVertexWorld(b2Body* body, const b2Vec2* vertex) {
    return body->GetWorldPoint(*vertex);
}

bool FloatEquals(float a, float b){
    return fabs(a - b) < 0.01f;
}

static inline bool acceptRay(Light* light,b2Vec2& dst){
   bool equalStart = FloatEquals(light->x, dst.x) && FloatEquals(light->y, dst.y);
   return !equalStart;
}

static inline float VectorDistance2(const b2Vec2& v1, const b2Vec2& v2) {
    float dx = v2.x-v1.x;
    float dy = v2.y - v1.y;
    return dx*dx + dy*dy;
}


static void AddRay(Light* light, b2Vec2& src, float len2, float off, int side) {
    if(light->rayDynamicId+1>= light->raysDataDynamicSize){
        dmLogWarning("not enough dynamic rays for light. Dynamic rays:%d",light->raysDataDynamicSize);
        return;
    }

    b2Vec2 candidate = b2Vec2(src.x, src.y);
    candidate.x -= light->x;
    candidate.y -= light->y;
    b2Vec2 perp = b2Vec2(-candidate.y * side, candidate.x * side);
    float perpLen = perp.Length();
    if(perpLen != 0){
        float perpLenScale = off/perpLen;
        perp *= perpLenScale;
    }

    candidate += perp;

    float candidateLen2 = candidate.LengthSquared();
    if(candidateLen2 != 0){
        float candidateLenScale = sqrt(len2/candidateLen2);
        candidate *= candidateLenScale;
    }

    //candidate.x +=light->x;
    //candidate.y +=light->y;
    if(acceptRay(light, candidate)){
        //change input to change sign
        RayData* firstRay = &light->raysDataStatic[0];
        float x1 = firstRay->dx;
        float y1 = firstRay->dy;
        float x2 = candidate.x;
        float y2 = candidate.y;
        float angleRay = VectorAngle(x1,y1,x2,y2);

        if(angleRay< light->angleEnd-light->angleBegin){
            angleRay += firstRay->angle;
            RayData* data = &light->raysDataDynamic[light->rayDynamicId];
            data->endX = candidate.x + light->x;
            data->endY =  candidate.y+ light->y;
            data->dx = candidate.x;
            data->dy = candidate.y;
            data->angle = angleRay;
            data->dynamicLen2 =  candidateLen2;
            light->rayDynamicId++;
        }
    }
}

static inline void AddRay(Light* light,b2Vec2& src, float len2, float off) {
    AddRay(light,src, len2, off, 1);
    AddRay(light,src, len2, off, -1);
}

static inline bool PointInsideAABB(b2Vec2& point, b2AABB& aabb) {
    return point.x >= aabb.lowerBound.x && point.x <= aabb.upperBound.x &&
        point.y >= aabb.lowerBound.y && point.y <= aabb.upperBound.y;
}

static int CircleFindIntersections(const b2Vec2& center, float radius, b2Vec2& start, b2Vec2& end
        , b2Vec2& intA, b2Vec2& intB){
    // find intersection with quadratic formula
    float dx, dy, A, B, C, det, t;

    dx = end.x - start.x;
    dy = end.y - start.y;
    A = dx * dx + dy * dy;
    B = 2 * (dx * (start.x - center.x) + dy * (start.y - center.y));
    C = (start.x - center.x) * (start.x - center.x) + (start.y - center.y)
            * (start.y - center.y) - radius * radius;

    det = B * B - 4 * A * C;
    if ((A <= 0.001f) || (det < 0)) {
        // No real solutions.
       // intA.set(Float.NaN, Float.NaN);
      //  intB.set(Float.NaN, Float.NaN);
        return 0;
    } else if (det == 0) {
        // One solution.
        t = -B / (2 * A);
        intA.Set(start.x /- t * dx, start.y + t * dy);
     //   intB.set(Float.NaN, Float.NaN);
        return 1;
    } else {
        // Two solutions.
        t = (float)((-B + sqrt(det)) / (2 * A));
        intA.Set(start.x + t * dx, start.y + t * dy);
        t = (float)((-B - sqrt(det)) / (2 * A));
        intB.Set(start.x + t * dx, start.y + t * dy);
        return 2;
    }
}

/** Returns a point on the segment nearest to the specified point. */
static void NearestSegmentPoint (b2Vec2& start, b2Vec2& end, b2Vec2& point, b2Vec2& nearest) {
    float length2 = VectorDistance2(start,end);
    if (length2 == 0) return nearest.Set(start.x,start.y);
    float t = ((point.x - start.x) * (end.x - start.x) + (point.y - start.y) * (end.y - start.y)) / length2;
    if (t < 0) return nearest.Set(start.x,start.y);
    if (t > 1) return nearest.Set(end.x,end.y);
    return nearest.Set(start.x + t * (end.x - start.x), start.y + t * (end.y - start.y));
}

static inline bool IsZero (float value) {
    return fabs(value) <0.01f;
}

void Light::UpdateLight(){
    bool meshChanged = false;
    bool dirtyAABB = this->dirtyPosition || this->dirtyAngle || this->dirtyRays;
    if(this->dirtyPosition || this->dirtyAngle || this->dirtyRays){
        float angleStart = this->angle + this->angleBegin;
        float a = (this->angleEnd - this->angleBegin) / (this->raysStatic-1);
        float a2 = angleStart;
        for (int i = 0; i<this->raysStatic; ++i) {
            RayData* ray =  &this->raysDataStatic[i];
            float cosa2 = cos(a2);
            float sina2 = sin(a2);
            ray->dx = cosa2 * this->radius;
            ray->dy = sina2 * this->radius;
            ray->endX = this->x + ray->dx;
            ray->endY = this->y + ray->dy;

            ray->angle = a2;
            a2 += a;
        }
        if(this->dirtyPosition){
            //set 1 vertice position to light start
            float* posIter = this->bufferPositions;
            float x = this->x / this->physicsScale;
            float y = this->y / this->physicsScale;
            //if reset only p0 have problems with circles
            //TODO fix
            for (int i = 0; i<(this->vertices); i++) {
                posIter[0] = x;
                posIter[1] = y;
                //posIter[2] = 0;
                posIter +=this->bufferPositionsStride;
            }
            meshChanged = true;
        }

        this->dirtyPosition  = false;
        this->dirtyAngle  = false;
        this->dirtyRays  = false;
    }

    if(dirtyAABB){
        if(isCircle){
            aabb.lowerBound.x = this->x - this->radius-0.01f;
            aabb.lowerBound.y = this->y - this->radius-0.01f;
            aabb.upperBound.x = this->x + this->radius+0.01f;
            aabb.upperBound.y = this->y + this->radius+0.01f;
        }else{
            aabb.lowerBound.x = this->x -0.01f;
            aabb.lowerBound.y = this->y -0.01f;
            aabb.upperBound.x = this->x +0.01f;
            aabb.upperBound.y = this->y +0.01f;
            for (int i = 0; i<this->raysStatic; ++i) {
                RayData* ray = &this->raysDataStatic[i];
                if(aabb.lowerBound.x>ray->endX) aabb.lowerBound.x = ray->endX-0.01f;
                if(aabb.lowerBound.y>ray->endY) aabb.lowerBound.y = ray->endY-0.01f;
                if(aabb.upperBound.x<ray->endX) aabb.upperBound.x = ray->endX+0.01f;
                if(aabb.upperBound.y<ray->endY) aabb.upperBound.y = ray->endY+0.01f;
           }
       }
    }

    b2Vec2 start(this->x, this->y);




    raysResult.clear();
    for (int i = 0; i<this->raysStatic; ++i) {
        raysResult.push_back(&this->raysDataStatic[i]);
    }

    cbQuery.Reset();
    bool needRaycast = true;
  //  dmLogInfo("rays dynamic:%d", this->raysDynamic);
    if(this->raysDynamic > 0){
        gameWorld->QueryAABB(&cbQuery, aabb);
        needRaycast = cbQuery.fixtures.size()>0;
        //dmLogInfo("fixtures find:%d", cbQuery.fixtures.size());
        rayDynamicId = 0;
        std::unordered_set<b2Fixture* >::iterator it;
        for (it = cbQuery.fixtures.begin(); it != cbQuery.fixtures.end(); ++it) {
            b2Fixture* fixture = *it;
            b2Shape* shape = fixture->GetShape();
            b2Body* body = fixture->GetBody();
            float distSqrt = this->radius * this->radius;
            const b2Vec2 start(this->x,this->y);
            b2Vec2 tmp3;
            b2Vec2 tmp4;
            b2Vec2 tmp5;
            switch (shape->GetType()) {
                case b2Shape::e_circle:{
                    dmLogWarning("circle not supported");
                    break;
                }
                case b2Shape::e_edge:{ // edge is used for ghost vertices we don't care about it
                    break;
                }
                case b2Shape::e_polygon: // fallthrough to Chain
                case b2Shape::e_chain:{
                    int vc = 0;
                    const b2Vec2* vertices = NULL;
                    if(shape->GetType() == b2Shape::e_polygon){
                        vc = ((b2PolygonShape*)shape)->m_count;
                        vertices = (((b2PolygonShape*)shape)->m_vertices);
                    }else if(shape->GetType() == b2Shape::e_chain){
                        vc = ((b2ChainShape*)shape)->m_count;
                        vertices = (((b2ChainShape*)shape)->m_vertices);
                    }
                    b2Vec2 vert1 = GetVertexWorld(body,&vertices[vc-1]);
                    if (PointInsideAABB(vert1, this->aabb) && VectorDistance2(start, vert1) <= distSqrt +0.001f) {
                        // we dont shoot directly at the corner, as sometimes the ray goes straight through it
                        AddRay(this, vert1, distSqrt, OFFSET_SIZE);
                    }
                    for (int i = 0; i < vc; i++) {
                        b2Vec2 vert2 =  GetVertexWorld(body,&vertices[i]);
                        //NO IDEA HOW CircleFindIntersections or NearestSegmentPoint
                        int found = CircleFindIntersections(start, this->radius, vert1, vert2, tmp3, tmp4);
                        if(found >=1){
                            if(PointInsideAABB(tmp3, this->aabb) && VectorDistance2(start, tmp3) <= distSqrt+0.001f){
                                NearestSegmentPoint(vert1,vert2, tmp3,tmp5);
                                if(IsZero(VectorDistance2(tmp3,tmp5))){
                                    AddRay(this, tmp3, distSqrt,0,1);
                                }
                            }
                        }
                        if(found >=1){
                            if(PointInsideAABB(tmp4, this->aabb) && VectorDistance2(start, tmp4) <= distSqrt+0.001f){
                                NearestSegmentPoint(vert1,vert2, tmp4,tmp5);
                                if(IsZero(VectorDistance2(tmp4,tmp5))){
                                    AddRay(this, tmp4, distSqrt,0,1);
                                 }
                            }
                        }
                        // also add corner
                        if (PointInsideAABB(vert2, this->aabb) && VectorDistance2(start, vert2) <= distSqrt+0.001f) {
                            AddRay(this, vert2, distSqrt, OFFSET_SIZE);
                        }
                        vert1 = vert2;
                    }


                    break;
                }
            }
        }

        //printf("rays:%d\n",rayDynamicId);
        for (int i=0; i<rayDynamicId;i++){
            raysResult.push_back(&this->raysDataDynamic[i]);
        }

        std::sort (raysResult.begin(), raysResult.end(), sortRays);
    }

    int raysActive = 0;
    int raysActiveDynamic = 0;

    float* posIter = this->bufferPositions+this->bufferPositionsStride;
    float* posIterPrev = this->bufferPositions+this->bufferPositionsStride;

    float* dataIter = this->bufferData+this->bufferDataStride;
    float* dataIterPrev = this->bufferData+this->bufferDataStride;

    int raysResultSize = raysResult.size();




    for(int i=0; i < raysResultSize; i++){
        RayData* data = raysResult[i];
        float endX = data->endX;
        float endY = data->endY;
        float fraction = 1;
        data->skip = false;
        if(needRaycast){
            cbGeometry.Reset();
            b2Vec2 finish(endX, endY);
            gameWorld->RayCast(&cbGeometry, start, finish);
            float dist = 0;
            float dx = 0;
            float dy = 0;
            if(cbGeometry.resultFraction!= -1){
                fraction = cbGeometry.resultFraction;
                dx = cbGeometry.result.x-start.x;
                dy = cbGeometry.result.y-start.y;
                dist = sqrt(dx*dx + dy*dy);
            }else{
                dx = data->dx;
                dy = data->dy;
                dist = sqrt(dx*dx + dy*dy);
            }
            //add 0.1 of meter(1meter is 1 tile)
            float scale = 1+ LIGHT_ADD_LEN/dist;

            endX = start.x + dx * scale;
            endY = start.y + dy * scale;

            if(data->dynamic){
                //skip ray if it hit something before it target
                float len2 = (dx*dx + dy*dy);
                float skipFraction = (len2/(data->dynamicLen2*SKIP_DYNAMIC_FRACTION));
                data->skip = skipFraction<1;
                // printf("fractionScale:%f\n",skipFraction);
                if(data->skip){
                    continue;
                }
                if(raysActiveDynamic+1 > raysDynamic){
                    dmLogWarning("not enough dynamic rays for draw light. Dynamic rays:%d",this->raysDynamic);
                    continue;
                }
                raysActiveDynamic++;
            }
        }




        RayPosition* rayPos = &this->raysPosition[raysActive];
        rayPos->dynamic = data->dynamic;
        rayPos->fraction = fraction;

        rayPos->x = endX;
        rayPos->y = endY;
        float posX = endX / this->physicsScale;
        float posY = endY / this->physicsScale;
        meshChanged = meshChanged || posIter[0] != posX || posIter[1] != posY ||  dataIter[0] != 1-fraction
            || dataIterPrev[0] != 1-fraction;

        float newFraction = 1-fraction;
        dataIter[0] = newFraction;
        dataIterPrev[0] = newFraction;



        posIter[0] = posX;
        posIterPrev[0] = posX;
        posIter[1] = posY;
        posIterPrev[1] = posY;


        posIter = posIter+3*this->bufferPositionsStride;
        posIterPrev = posIter-2*this->bufferPositionsStride;
        dataIter = dataIter+3*this->bufferDataStride;
        dataIterPrev = dataIter-2*this->bufferDataStride;

        //fixed getting out of bounds of array
        if(raysActive == raysResultSize-2 ){
            posIter = posIterPrev;
            dataIter = dataIterPrev;
        }


        raysActive++;
    }

    //fixed circle cycle first and last vertices to each other
  //  if(this->isCircle){
     //  posIterPrev = this->bufferPositions+(raysActive*3-1-3)*this->bufferPositionsStride;
      // dataIterPrev = this->bufferData+(raysActive*3-1-3)*this->bufferDataStride;
    //   RayPosition* rayPos = &this->raysPosition[0];
      //  float newFraction = 1-rayPos->fraction;
     //   float posX = rayPos->x / this->physicsScale;
     //   float posY = rayPos->y / this->physicsScale;
     //   dataIterPrev[0] = newFraction;
      //  posIterPrev[0] = posX;
      //  posIterPrev[1] = posY;
  // }




    //set not used vertices to cx,cy
    int raysTotalNew = raysActive;
    if(raysTotal != raysTotalNew) {
        raysTotal = raysTotalNew;
        //float endX = 0, endY = 0;
        //set cx,cy for
        float endX = this->x/this->physicsScale, endY = this->y/this->physicsScale;
        posIter = this->bufferPositions+this->bufferPositionsStride*(raysTotal*3-2);

        for(int i =raysTotal; i< raysStatic + raysDynamic;i++ ){
            raysPosition[i].x = endX;
            raysPosition[i].y = endY;
        }

        for(int i=raysTotal*3-2; i < this->vertices; i++){
            posIter[0] = endX;
            posIter[1] = endY;
            posIter +=this->bufferPositionsStride;
        }
        meshChanged = true;

       // posIter = this->bufferPositions;
      //  for(int i=0; i < this->vertices; i++){
       //     posIter +=this->bufferPositionsStride;
       // }
    }




    if(meshChanged){
        dmBuffer::UpdateContentVersion(this->buffer);
    }



}

bool Light::BufferIsValid() {
    dmBuffer::Result r = dmBuffer::ValidateBuffer(buffer);
    if (r == dmBuffer::RESULT_OK) {
        return true;
    } else {
        return false;
    }

   // return dmBuffer::IsBufferValid(this->buffer);
}

void Light::Destroy(lua_State *L) {
    BaseUserData::Destroy(L);
    delete this;
}



static int SetPosition(lua_State *L){
    game_utils::check_arg_count(L, 3);
    Light *light = Light_get_userdata_safe(L, 1);
    light->SetPosition(lua_tonumber(L, 2),lua_tonumber(L, 3));
    return 0;
};

static int SetRadius(lua_State *L){
    game_utils::check_arg_count(L, 2);
    Light *light = Light_get_userdata_safe(L, 1);
    light->SetRadius(lua_tonumber(L, 2));
    return 0;
};

static int SetRaysStatic(lua_State *L){
    game_utils::check_arg_count(L, 2);
    Light *light = Light_get_userdata_safe(L, 1);
    light->SetRaysStatic(lua_tonumber(L, 2));
    return 0;
};

static int SetRaysDynamic(lua_State *L){
    game_utils::check_arg_count(L, 2);
    Light *light = Light_get_userdata_safe(L, 1);
    light->SetRaysDynamic(lua_tonumber(L, 2));
    return 0;
};

static int SetAngle(lua_State *L){
    game_utils::check_arg_count(L, 2);
    Light *light = Light_get_userdata_safe(L, 1);
    light->SetAngle(lua_tonumber(L, 2));
    return 0;
};

static int SetPhysicsScale(lua_State *L){
    game_utils::check_arg_count(L, 2);
    Light *light = Light_get_userdata_safe(L, 1);
    light->SetPhysicsScale(lua_tonumber(L, 2));
    return 0;
};

static int SetStartDrawFraction(lua_State *L){
    game_utils::check_arg_count(L, 2);
    Light *light = Light_get_userdata_safe(L, 1);
    light->SetStartDrawFraction(lua_tonumber(L, 2));
    return 0;
};

static int SetFixedPower(lua_State *L){
    game_utils::check_arg_count(L, 2);
    Light *light = Light_get_userdata_safe(L, 1);
    light->SetFixedPower(lua_tonumber(L, 2));
    return 0;
};

static int SetBaseAngles(lua_State *L){
    game_utils::check_arg_count(L, 3);
    Light *light = Light_get_userdata_safe(L, 1);
    light->SetBaseAngles(lua_tonumber(L, 2),lua_tonumber(L, 3));
    return 0;
};

static int SetColor(lua_State *L){
    game_utils::check_arg_count(L, 5);
    Light *light = Light_get_userdata_safe(L, 1);
    light->BufferSetColor(lua_tonumber(L, 2),lua_tonumber(L, 3),lua_tonumber(L, 4),lua_tonumber(L, 5));
    return 0;
};


static int PlayerIsHit(lua_State *L){
    game_utils::check_arg_count(L, 1);
    Light *light = Light_get_userdata_safe(L, 1);
    lua_pushboolean(L, light->playerIsHit);
    return 1;
};

static int SetPlayerIsHit(lua_State *L){
    game_utils::check_arg_count(L, 2);
    Light *light = Light_get_userdata_safe(L, 1);
    light->SetHitPlayer(lua_toboolean(L,2));
    return 0;
};

static int BufferInit(lua_State *L){
    game_utils::check_arg_count(L, 1);
    Light *light = Light_get_userdata_safe(L, 1);
    light->BufferInit();
    return 0;
};

static int BufferGetContentVersion(lua_State *L){
    game_utils::check_arg_count(L, 1);
    Light *light = Light_get_userdata_safe(L, 1);
    uint32_t version = 0;
    dmBuffer::Result result = dmBuffer::GetContentVersion(light->buffer, &version);
    lua_pushnumber(L, version);
    return 1;
};

static int BufferIsValid(lua_State *L){
    game_utils::check_arg_count(L, 1);
    Light *light = Light_get_userdata_safe(L, 1);
    lua_pushboolean(L, light->BufferIsValid());
    return 1;
};

static int UpdateLight(lua_State *L){
    game_utils::check_arg_count(L, 1);
    Light *light = Light_get_userdata_safe(L, 1);
    light->UpdateLight();
    return 0;
};

static int UpdateHitPlayer(lua_State *L){
    game_utils::check_arg_count(L, 5);
    Light *light = Light_get_userdata_safe(L, 1);
    light->UpdateHitPlayer(lua_tonumber(L, 2),lua_tonumber(L, 3),lua_tonumber(L, 4),lua_tonumber(L, 5));
    return 0;
};

static int UpdateHitPlayerGetRays(lua_State *L){
    game_utils::check_arg_count(L, 5);
    Light *light = Light_get_userdata_safe(L, 1);
    std::vector<RayData> data = light->UpdateHitPlayerGetRays(lua_tonumber(L, 2),lua_tonumber(L, 3),
        lua_tonumber(L, 4),lua_tonumber(L, 5));
    lua_newtable(L);
    for(int i=0; i<data.size(); i++){
        RayData ray = data[i];
        lua_newtable(L);
        lua_pushnumber(L, ray.endX);
        lua_setfield(L, -2, "x");
        lua_pushnumber(L, ray.endY);
        lua_setfield(L, -2, "y");

        lua_rawseti(L,-2,i+1);
    }
    return 1;
};


static int Destroy(lua_State *L) {
    game_utils::check_arg_count(L, 1);
    Light *light = Light_get_userdata_safe(L, 1);
    light->Destroy(L);
    return 0;
}


static int ToString(lua_State *L){
    game_utils::check_arg_count(L, 1);
    Light *lua_light = Light_get_userdata_safe(L, 1);
    lua_pushfstring( L, "light[%p]",(void *) lua_light);
	return 1;
}


static int GetBuffer(lua_State *L){
    game_utils::check_arg_count(L, 1);
    Light *lua_light = Light_get_userdata_safe(L, 1);
    dmScript::LuaHBuffer luabuffer = { lua_light->buffer, dmScript::OWNER_C };
    PushBuffer(L, luabuffer);
	return 1;
}

static int RaysGetTotalCount(lua_State *L){
    game_utils::check_arg_count(L, 1);
    Light *lua_light = Light_get_userdata_safe(L, 1);
    lua_pushnumber(L, lua_light->raysTotal);
	return 1;
}

static int RaysGetPositions(lua_State *L){
    game_utils::check_arg_count(L, 1);
    Light *lua_light = Light_get_userdata_safe(L, 1);
    lua_newtable(L);
    for(int i=0; i<lua_light->raysTotal; i++){
        float x = lua_light->raysPosition[i].x;
        float y = lua_light->raysPosition[i].y;
        bool dynamic = lua_light->raysPosition[i].dynamic;
        lua_newtable(L);
        lua_pushnumber(L, x);
        lua_setfield(L, -2, "x");
        lua_pushnumber(L, y);
        lua_setfield(L, -2, "y");
        lua_pushboolean(L, dynamic);
        lua_setfield(L, -2, "dynamic");

        lua_rawseti(L,-2,i+1);
    }
	return 1;
}

static int AABBGet(lua_State *L){
    game_utils::check_arg_count(L, 1);
    Light *lua_light = Light_get_userdata_safe(L, 1);
    extra_utils::b2AABB_push(L,lua_light->aabb);
	return 1;
}

void LightInitMetaTable(lua_State *L){
    int top = lua_gettop(L);

    luaL_Reg functions[] = {
        {"SetPosition",SetPosition},
        {"SetRadius",SetRadius},
        {"SetRaysStatic",SetRaysStatic},
        {"SetRaysDynamic",SetRaysDynamic},
        {"SetAngle",SetAngle},
        {"SetBaseAngles",SetBaseAngles},
        {"UpdateLight",UpdateLight},
        {"UpdateHitPlayer",UpdateHitPlayer},
        {"UpdateHitPlayerGetRays",UpdateHitPlayerGetRays},
        {"PlayerIsHit",PlayerIsHit},
        {"SetPlayerIsHit",SetPlayerIsHit},
        {"BufferInit",BufferInit},
        {"BufferGetContentVersion",BufferGetContentVersion},
        {"BufferIsValid",BufferIsValid},
        {"SetPhysicsScale",SetPhysicsScale},
        {"GetBuffer",GetBuffer},
        {"SetColor",SetColor},
        {"SetStartDrawFraction",SetStartDrawFraction},
        {"SetFixedPower",SetFixedPower},
        {"RaysGetTotalCount",RaysGetTotalCount},
        {"RaysGetPositions",RaysGetPositions},
        {"AABBGet",AABBGet},
        {"Destroy",Destroy},
        {"__tostring",ToString},
        { 0, 0 }
    };
    luaL_newmetatable(L, META_NAME);
    luaL_register (L, NULL,functions);
    lua_pushvalue(L, -1);
    lua_setfield(L, -1, "__index");
    lua_pop(L, 1);


    assert(top == lua_gettop(L));
}





}


