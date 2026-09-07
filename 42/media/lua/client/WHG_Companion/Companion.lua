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
    -- B42 stores actors in a Set; its Lua snapshot supports indexed access.
    local objects = getCell():getObjectListForLua()
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        -- The companion is an IsoPlayer, so every real player passes the class
        -- test; the actor tag and the identity guard are what single her out.
        if object ~= player and instanceof(object, "IsoPlayer")
            and object:getModData().CelineCompanionActor == id then
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
    -- B42 keeps IsoSurvivor only as the character-creation avatar: it never
    -- overrides getVisual() and its constructor builds no BodyDamage, so both
    -- ModelManager.Add and the cell update loop throw on a world instance.
    -- IsoPlayer is the only human body the engine can still draw.
    -- Argument order differs from IsoSurvivor: the cell comes first.
    local npc = IsoPlayer.new(getCell(), descriptor, square:getX(), square:getY(), square:getZ())
    Companion.npc = npc -- Retain the reference even if subsequent setup fails.
    npc:setNpc(true) -- Attaches the engine AIComponent; keeps her off player input.
    npc:getModData().CelineCompanionActor = id
    npc:setCurrent(square)
    -- setCurrent only assigns the field. Rendering walks the square's moving
    -- object list, and setMovingSquareNow() is what puts her on it; without it
    -- she exists, speaks and updates, but is drawn nowhere.
    npc:setMovingSquareNow()
    -- The snapshot is immutable: register in the live Set, not the snapshot.
    local liveObjects = getCell():getObjectList()
    if not liveObjects:contains(npc) then liveObjects:add(npc) end
    -- getSurvivorList() is typed ArrayList<IsoSurvivor>; an IsoPlayer stored
    -- there breaks any consumer that casts, and nothing reads it, so skip it.
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
