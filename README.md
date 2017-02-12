Name
====
lua-resty-brotli - Lua bindings to Google
[Brotli](https://github.com/google/brotli) for LuaJIT using FFI.


Status
======
This library is still experimental and under early development.


Installation
============
To install `lua-resty-brotli` you need to install
[Brotli](https://github.com/google/brotli#build-instructions)
with shared libraries firtst.
Then you can install `lua-resty-brotli` by placing `lib/resty/brotli.lua` to
your lua library path.


Example
=======
```` lua
local brotli = require "resty.brotli"

local txt = string.rep("ABCD", 1000)
print("Uncompressed size:", #txt)
local c, err = brotli.compress(txt)
print("Compressed size:", #c)
local txt2, err = brotli.decompress(c)
assert(txt == txt2)
````


Methods
=======

compress
--------
`syntax: encoded_buffer, err = brotli.compress(input_buffer, options?, buffer_size?)`

Compresses the data in input_buffer into encoded_buffer.

The `options` argument is a Lua table holding the following keys:

* `quality`

    Set Brotli quality (compression) level.
    Acceptable values are in the range from `0` to `11`.
    (Defaults to 11)

* `lgwin`

    Set Brotli window size. Window size is `(1 << lgwin) - 16`.

* `mode`

    The compression mode can be `BROTLI_MODE_GENERIC` (0, default),
   `BROTLI_MODE_TEXT` (1, for UTF-8 format text input) or
   `BROTLI_MODE_FONT` (2, for WOFF 2.0).

decompress
----------
`syntax: decoded_buffer, err = brotli.decompress(encoded_buffer, buffer_size?)`

Decompresses the data in encoded_buffer into decoded_buffer.

