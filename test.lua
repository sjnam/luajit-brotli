local brotlienc = require "lib.resty.brotli.encoder"
local brotlidec = require "lib.resty.brotli.decoder"

local txt = string.rep("ABCDEFGH", 131072)

print("input size= "..#txt, "\n\ncompressed")
print("level", "size", "\n------------")

local encoder = brotlienc:new()
local decoder = brotlidec:new()

for lvl=0,11 do
   local encoded, err = encoder:compress(txt, { quality = lvl })
   local decoded, err = decoder:decompress(encoded)
   assert(txt == decoded)
   print(lvl, #encoded)
end
