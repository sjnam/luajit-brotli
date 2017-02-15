local brotli = require "lib.resty.brotli"

local txt = string.rep("ABCDEFGH", 131072)

print("input size= "..#txt, "\n\ncompressed")
print("level", "size", "\n------------")

local bro = brotli:new()
for lvl=0,11 do
   local encoded, err = bro:compress(txt, { quality = lvl })
   local decoded, err = bro:decompress(encoded)
   assert(txt == decoded)
   print(lvl, #encoded)
end
