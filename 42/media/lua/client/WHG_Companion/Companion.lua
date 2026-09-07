-- SPDX-License-Identifier: Apache-2.0
-- Experimental single-player NPC; only engine APIs, no third-party NPC code.
local Companion = { npc = nil, mode = "WAIT" }

function Companion.identity(player)
    local data = player:getModData()
    if not data.CelineCompanionId then
        data.CelineCompanionId = "celine-" .. string.format("%.0f", getTimestampMs()) .. "-" .. tostring(ZombRand(1000000))
    end
    return data.CelineCompanionId
end

function Companion.nearby(player)
    local npc = Companion.npc
    if not npc or npc:isDead() or not npc:getSquare() then return false end
    local dx, dy = npc:getX() - player:getX(), npc:getY() - player:getY()
    return npc:getZ() == player:getZ() and dx * dx + dy * dy <= 144
end

function Companion.apply(intent)
    if intent == "NONE" then return true end
    if intent ~= "FOLLOW" and intent ~= "WAIT" then return false end
    if not Companion.npc or Companion.npc:isDead() then return false end
    local npc = Companion.npc
    npc:getPathFindBehavior2():cancel()
    npc:setPath2(nil)
    npc:setMoving(false)
    npc:setVariable("bPathfind", false)
    npc:setIgnoreMovement(intent == "WAIT")
    Companion.mode = intent
    npc:getModData().CelineMode = intent
    return true
end

function Companion.spawn(player)
    local id = Companion.identity(player)
    -- Reuse any loaded actor belonging to this player before creating one.
    local objects = getCell():getObjectList()
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        if instanceof(object, "IsoSurvivor") and object:getModData().CelineCompanionId == id then
            Companion.npc = object
            Companion.apply("WAIT")
            return true
        end
    end
    if Companion.npc then return false, "Companion already exists; return to her location." end
    local square = nil
    for dx = -2, 2 do
        for dy = -2, 2 do
            if not square and (dx ~= 0 or dy ~= 0) then
                local candidate = getCell():getGridSquare(math.floor(player:getX()) + dx,
                    math.floor(player:getY()) + dy, math.floor(player:getZ()))
                if candidate and candidate:isFree(false) then square = candidate end
            end
        end
    end
    if not square then return false, "No free ground nearby." end
    local descriptor = SurvivorFactory.CreateSurvivor()
    descriptor:setForename("Celine")
    descriptor:setSurname("")
    descriptor:setFemale(true)
    local npc = IsoSurvivor.new(descriptor, getCell(), square:getX(), square:getY(), square:getZ())
    Companion.npc = npc -- Retain the reference even if subsequent setup fails.
    npc:getModData().CelineCompanionId = id
    npc:setCurrent(square)
    if not objects:contains(npc) then objects:add(npc) end
    local survivors = getCell():getSurvivorList()
    if not survivors:contains(npc) then survivors:add(npc) end
    npc:dressInRandomNonSillyOutfit()
    npc:setSceneCulled(false)
    Companion.apply("WAIT")
    return true
end

function Companion.tick(player)
    local npc = Companion.npc
    if not npc or npc:isDead() or not npc:getSquare() or player:isDead() then return end
    if Companion.mode == "FOLLOW" then
        local dx, dy = npc:getX() - player:getX(), npc:getY() - player:getY()
        if npc:getZ() ~= player:getZ() or dx * dx + dy * dy > 900 or player:getVehicle() then
            Companion.apply("WAIT") -- No teleporting, vehicles or unloaded-chunk chase.
        elseif dx * dx + dy * dy > 9 then
            npc:pathToCharacter(player)
        else
            npc:getPathFindBehavior2():cancel()
            npc:setPath2(nil)
            npc:setMoving(false)
            npc:setVariable("bPathfind", false)
        end
    end
end

return Companion
