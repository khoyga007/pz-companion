-- SPDX-License-Identifier: Apache-2.0
package.path = "42/media/lua/shared/?.lua;42/media/lua/client/?.lua;" .. package.path
local Protocol = require "WHG_Companion/IPC/Protocol"
local Companion = require "WHG_Companion/Companion"
local calls = {}
local npc = {
    isDead = function() return false end,
    getPathFindBehavior2 = function() return { cancel = function() calls.cancel = true end } end,
    setPath2 = function() end, setMoving = function() end, setVariable = function() end,
    setIgnoreMovement = function(_, value) calls.stopped = value end,
    getModData = function() return {} end,
}
Companion.npc = npc
assert(not Companion.apply("EXEC"))
assert(Companion.apply("FOLLOW") and Companion.mode == "FOLLOW" and not calls.stopped)
assert(Companion.apply("WAIT") and Companion.mode == "WAIT" and calls.stopped and calls.cancel)
local response = {protocolVersion=1, requestId="one", status="ok", speech="Hello", intent="WAIT", confidence=1, parameters={}}
assert(Protocol.validateResponse(response, "one"))
assert(not Protocol.validateResponse(response, "another"))
response.confidence = 0/0
assert(not Protocol.validateResponse(response, "one"))
response.confidence, response.speech = 1, string.rep("x", 4097)
assert(not Protocol.validateResponse(response, "one"))
print("PASS: command allowlist, follow/wait state, correlation, NaN and speech bounds")

-- A finished reply arriving after the deadline must never become an action.
local files, clock = {}, 1000
getTimestampMs = function() return clock end
fileExists = function(path) return files[path] ~= nil end
getFileWriter = function(path)
    files[path] = ""
    return { write=function(_, text) files[path] = files[path] .. text end, close=function() end }
end
getFileReader = function(path)
    if not files[path] then return nil end
    local read = false
    return { readLine=function() if not read then read=true; return files[path] end end, close=function() end }
end
local Transport = require "WHG_Companion/IPC/Transport"
local Json = require "WHG_Companion/IPC/Json"
local id = assert(Transport.submitConversation("test", "Wait", {}, 100))
assert(files["WHG_PZ_Companion/ipc/requests/" .. id .. ".request.ready"])
response.requestId, response.speech = id, "Wait"
files["WHG_PZ_Companion/ipc/responses/" .. id .. ".response.json"] = Json.encode(response)
clock = 1101
assert(Transport.poll(id) == "timeout")
assert(Transport.getPendingCount() == 0)
assert(files["WHG_PZ_Companion/ipc/responses/" .. id .. ".response.ack"])
print("PASS: expired completed response discarded and acknowledged")

-- B42 object storage is a Set (no get), while the Lua view is read-only, and
-- the companion body is an IsoPlayer, so real players share her class.
local actors = {}
local liveSet = {
    contains=function(_, value) return actors[value] == true end,
    add=function(_, value) actors[value] = true end,
}
local cell = {
    getObjectList=function() return liveSet end,
    getObjectListForLua=function()
        local snapshot = {}
        for actor in pairs(actors) do snapshot[#snapshot+1] = actor end
        return {size=function() return #snapshot end, get=function(_, index) return snapshot[index+1] end}
    end,
    getGridSquare=function(_, x,y,z) return {
        isFree=function() return true end, getX=function() return x end,
        getY=function() return y end, getZ=function() return z end,
    } end,
}
local playerData, npcData = {}, {}
local player = {getModData=function() return playerData end,
    getX=function() return 0 end, getY=function() return 0 end, getZ=function() return 0 end}
getCell=function() return cell end
ZombRand=function(bound) return bound - 1 end -- identity() mints the id itself.
-- Both bodies answer to IsoPlayer; only the actor tag may tell them apart.
instanceof=function(actor, class) return class == "IsoPlayer" and (actor == npc or actor == player) end
npc.getModData=function() return npcData end
npc.setCurrent=function(_, square) npcData.square = square end
npc.setMovingSquareNow=function() npcData.onMovingList = true end
npc.setNpc=function(_, value) npcData.npcFlag = value end
npc.dressInRandomNonSillyOutfit=function() end
npc.setSceneCulled=function() end
local creations=0
SurvivorFactory={CreateSurvivor=function() return {
    setForename=function() end, setSurname=function() end, setFemale=function() end,
} end}
IsoPlayer={new=function() creations=creations+1; return npc end}
Companion.npc=nil
actors[player] = true -- The player is already in the cell before any summon.
assert(Companion.spawn(player))
assert(actors[npc] and creations == 1 and npcData.npcFlag == true)
-- Rendering only sees her once she is on the square's moving object list.
assert(npcData.square and npcData.onMovingList)
assert(npcData.CelineCompanionActor == playerData.CelineCompanionId)
print("PASS: B42 IsoPlayer body, NPC flag, Set registration, immutable snapshot")

-- A tagged player must never be adopted as its own companion.
Companion.npc=nil
playerData.CelineCompanionActor = playerData.CelineCompanionId
assert(Companion.spawn(player))
assert(creations == 1 and Companion.npc == npc)
print("PASS: duplicate spawn reuses the actor and never adopts the player")
