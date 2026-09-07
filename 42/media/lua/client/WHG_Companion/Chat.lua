-- SPDX-License-Identifier: Apache-2.0
-- Reuse PZ's native text dialog and context menu. No API key enters Lua.
if isClient() or isServer() then return end
require "ISUI/ISTextBox"
local Transport = require "WHG_Companion/IPC/Transport"
local Companion = require "WHG_Companion/Companion"
local pending, lastPoll, lastMove = nil, 0, 0
local lastReply = "Celine: Ready. Start the DeepSeek runtime, then summon a companion."
local npcFailed = false

local function notify(player, text)
    lastReply = text
    player:Say(text)
end

local function send(_, button, player)
    if button.internal ~= "OK" or pending then return end
    local message = button.parent.entry:getText()
    if not message or message:match("^%s*$") then return end
    if #message > 2000 then notify(player, "Message is too long (max 2000 UTF-8 bytes).") return end
    if not Companion.nearby(player) then notify(player, "Celine must be nearby to chat.") return end
    local healthy, status = Transport.getRuntimeStatus()
    if not healthy or status.mode ~= "deepseek" then
        notify(player, "DeepSeek runtime is offline. Start it before chatting.") return
    end
    local id, err = Transport.submitConversation(Companion.identity(player), message, {
        mode = Companion.mode, nearby = true, hour = getGameTime():getTimeOfDay(),
    }, 45000)
    if id then
        pending = { id = id, player = player, npc = Companion.npc }
        notify(player, "Celine is thinking...")
    else
        notify(player, "Cannot send message: " .. tostring(err))
    end
end

local function openChat(player)
    if pending then notify(player, "Please wait for the current reply.") return end
    -- Strip rich-text delimiters from model output before using a PZ dialog label.
    local label = lastReply:gsub("[<>]", "") .. " <LINE> Message to Celine (sent to DeepSeek):"
    local dialog = ISTextBox:new(0, 0, 520, 230, label, "", nil, send, player:getPlayerNum(), player)
    dialog:initialise()
    dialog:addToUIManager()
end

local function summon(player)
    local ok, success, err = pcall(Companion.spawn, player)
    npcFailed = not ok
    if ok and success then notify(player, "Celine: Em ở đây rồi.")
    else notify(player, "Experimental NPC unavailable: " .. tostring(ok and err or success)) end
end

local function command(player, intent)
    -- A manual command supersedes any older model action still in flight.
    if pending then pending.ignoreAction = true end
    local ok, applied = pcall(Companion.apply, intent)
    notify(player, ok and applied and ("Celine: " .. intent) or "NPC command unavailable.")
end

Events.OnFillWorldObjectContextMenu.Add(function(playerIndex, menu, _, test)
    if test or playerIndex ~= 0 then return end
    local player = getSpecificPlayer(playerIndex)
    if not player or player:isDead() then return end
    menu:addOption("Celine: Summon (experimental)", player, summon)
    menu:addOption("Celine: Chat / last reply", player, openChat)
    if Companion.nearby(player) then
        menu:addOption("Celine: Follow", player, command, "FOLLOW")
        menu:addOption("Celine: Wait", player, command, "WAIT")
    end
end)

Events.OnTick.Add(function()
    local now = getTimestampMs()
    if now - lastPoll < 500 then return end
    lastPoll = now
    if pending then
        local state, value = Transport.poll(pending.id)
        if state ~= "pending" then
            local request = pending
            pending = nil
            if state == "ok" then
                local applied = false
                if not request.ignoreAction and Companion.npc == request.npc
                    and not request.player:isDead() and Companion.nearby(request.player) then
                    local ok, result = pcall(Companion.apply, value.intent)
                    applied = ok and result
                end
                local suffix = (value.intent ~= "NONE" and not applied) and " [Action not applied]" or ""
                notify(request.player, "Celine: " .. value.speech .. suffix)
            else
                notify(request.player, "No reply: " .. tostring(type(value) == "table" and value.error or value))
            end
        end
    end
    if not npcFailed and now - lastMove >= 2000 then
        lastMove = now
        local player = getSpecificPlayer(0)
        if player then
            local ok = pcall(Companion.tick, player)
            if not ok then
                npcFailed = true
                pcall(Companion.apply, "WAIT")
                notify(player, "Experimental NPC movement failed; chat runtime is still available.")
            end
        end
    end
end)

Events.OnGameStart.Add(function()
    pending, lastPoll, lastMove = nil, 0, 0
    Companion.npc, Companion.mode, npcFailed = nil, "WAIT", false
end)
