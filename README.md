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
`syntax: c, err = brotli.compress(s, options?)`

decompress
----------
`syntax: s, err = brotli.decompress(c)`


Todo
====
* compress or decompress stream


Authors
=======
Soojin Nam <jsunam@gmail.com>, Kakao Corp.