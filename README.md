Name
====
lua-ffi-brotli - Lua bindings to Google
[Brotli](https://github.com/google/brotli) for LuaJIT using FFI.


Status
======
This library is still experimental and under early development.


Example
=======
```` lua
local brotli = require "lib.ffi-brotli"

local txt = string.rep("ABCD", 1000)
print("Uncompressed size:", #txt)
local c, err = brotli.compress(txt)
if not c then
   print(err)
   return
end
print("Compressed size:", #c)
local txt2, err = brotli.decompress(c)
assert(txt == txt2)
````

Methods
=======

compress
--------
`syntax: encoded_buffer, err = brotli.compress(input_buffer, options?)`

Compresses the data in input_buffer into encoded_buffer.

The `options` argument is a Lua table holding the following keys:

* `quality`
    Set Brotli quality (compression) level.
    Acceptable values are in the range from `0` to `11`,
    e.g. `::BROTLI_DEFAULT_QUALITY`
* `lgwin`
    lgwin parameter value, e.g. `::BROTLI_DEFAULT_WINDOW`
* `mode`
    mode parameter value, e.g. `::BROTLI_DEFAULT_MODE`

decompress
----------
`syntax: decoded_buffer, err = brotli.decompress(encoded_buffer)`

Decompresses the data in encoded_buffer into decoded_buffer.


Authors
=======
Soojin Nam <jsunam@gmail.com>, Kakao Corp.