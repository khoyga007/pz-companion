-- Opt-in integration driver: real Lua transport, file-backed doubles for PZ I/O.
package.path = "42/media/lua/shared/?.lua;" .. package.path
local root, requestIdFile, message, identity = arg[1], arg[2], arg[3], arg[4]
getTimestampMs = function() return os.time() * 1000 end
fileExists = function(path) local f = io.open(root .. "/" .. path, "r"); if f then f:close(); return true end return false end
getFileWriter = function(path)
    local f = assert(io.open(root .. "/" .. path, "w"))
    return {write=function(_, text) f:write(text) end, close=function() f:close() end}
end
getFileReader = function(path)
    local f = io.open(root .. "/" .. path, "r")
    if not f then return nil end
    return {readLine=function() return f:read("*l") end, close=function() f:close() end}
end
local Transport = require "WHG_Companion/IPC/Transport"
local id, err = Transport.submitConversation(identity, message, {mode="WAIT", nearby=true}, 45000)
assert(id, err)
local f = assert(io.open(requestIdFile, "w")); f:write(id); f:close()
io.read("*l") -- Python driver wakes us when the atomic response exists.
local state, response = Transport.poll(id)
assert(state == "ok", type(response) == "table" and response.error or tostring(response))
local Json = require "WHG_Companion/IPC/Json"
print(Json.encode(response))
