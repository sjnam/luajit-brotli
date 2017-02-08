local brotli = require "lib.ffi-brotli"

local txt = string.rep("abcd", 1000)

local encoded, err = brotli.compress(txt)
if not encoded then
   print(err)
   return
end

local decoded, err = brotli.decompress(encoded)
if not decoded then
   print(err)
else
   assert(txt == decoded)
   print(decoded)
end

local fname = "input.txt"
local f = io.open(fname, "wb")
f:write(txt)
f:close()


local ret = brotli.compressStream(fname)
print(ret)

