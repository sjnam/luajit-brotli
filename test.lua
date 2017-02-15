local brotli = require "lib.resty.brotli"

local txt = string.rep("ABCDEFGH", 131072)

print("input size= "..#txt, "\n\ncompressed")
print("level", "size", "\n------------")

for lvl=0,11 do
   local bro = brotli:new({ quality = lvl })
   local encoded, err = bro:compress(txt)
   local decoded, err = bro:decompress(encoded)
   assert(txt == decoded)
   print(lvl, #encoded)
end
