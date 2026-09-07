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
