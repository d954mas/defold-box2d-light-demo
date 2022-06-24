game = {}

---@class GameNativeLight
local GameNativeLight = {

}

function GameNativeLight:SetPosition(x,y) end
function GameNativeLight:SetRadius(radius) end
function GameNativeLight:SetRays(rays) end
function GameNativeLight:SetAngle(angle) end
function GameNativeLight:SetBaseAngles(angle_begin, angle_end) end
function GameNativeLight:PlayerIsHit() end
function GameNativeLight:BufferInit() end
function GameNativeLight:GetBuffer() end
function GameNativeLight:SetPhysicsScale(scale) end
function GameNativeLight:SetPlayerIsHit(hit) end
function GameNativeLight:SetColor(r, g, b, a) end
function GameNativeLight:UpdateHitPlayer(px, py, pw, ph) end
function GameNativeLight:SetStartDrawFraction(startDrawFraction) end

function GameNativeLight:UpdateLight() end

function GameNativeLight:Destroy() end

---@return GameNativeLight
function game.create_light() end
function game.set_world() end
function game.set_filter_geometry() end
function game.set_filter_player() end
