local brotli = require "lib.ffi-brotli"

local assert = assert
local str_rep = string.rep

local txt = str_rep("abcd", 1000)

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

local ret = brotli.compressStream("input.txt")
print(ret)

