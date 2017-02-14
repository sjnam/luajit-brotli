local brotli = require "lib.resty.brotli"

local compress, decompress = brotli.compress, brotli.decompress

local txt = string.rep("ABCDEFGH", 131072)

print("input size= "..#txt, "\n\ncompressed")
print("level", "size", "\n------------")

for lvl=0,11 do
   local encoded, err = compress(txt, {quality = lvl, mode=1})
   local decoded, err = decompress(encoded)
   assert(txt == decoded)
   print(lvl, #encoded)
end
