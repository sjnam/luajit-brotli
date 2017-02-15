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

in nginx with lua-nginx-module of Openresty
```` lua
# static contents
location / {
    rewrite_by_lua_block {
       local brotli = require "resty.brotli"
       local brotli_ok = false
       local header = ngx.var.http_accept_encoding
       if header then
          if string.find(header, "br") then
             brotli_ok = true
          end
       end
       if not brotli_ok then
          ngx.ctx.bro_decoder = brotli.get_decoder()
       end
       ngx.ctx.bro_ok = brotli_ok       
       ngx.req.set_uri(ngx.var.uri..".br")    
    }

    header_filter_by_lua_block {
       ngx.header["Vary"] = "Accept-Encoding"                
       if not ngx.ctx.bro_ok then
          ngx.header.content_length = nil
       else
          ngx.header["Content-Encoding"] = "br"
       end
    }
    
    body_filter_by_lua_block {
       if ngx.ctx.bro_ok then
          return
       end
    
       local brotli = require "resty.brotli"
       local decoder = ngx.ctx.bro_decoder
       local ret, stream = brotli.decompressStream(decoder, ngx.arg[1])
       ngx.arg[1] = stream
       if ret == brotli.BROTLI_DECODER_RESULT_SUCCESS then
          brotli.destroyDecoder(decoder)
          ngx.arg[2] = true
       else
          ngx.ctx.bro_decoder = decoder
       end
    }
}

# dynamic contents
location /hello {
    content_by_lua_block {
        local name = ngx.var.arg_name or "world"
        local msg = string.rep("Hello,"..name.." ", 100)
        msg = string.rep(msg.."\n", 10000)
        ngx.header["Content-Length"] = #msg 
        ngx.print(msg)
    }

    header_filter_by_lua_block {
        local brotli = require "resty.brotli"
        local brotli_ok = false
        local header = ngx.var.http_accept_encoding
        if header then
           if string.find(header, "br") then
              brotli_ok = true
           end
        end
        ngx.ctx.bro_ok = brotli_ok
        ngx.header["Vary"] = "Accept-Encoding"
        if brotli_ok then
           ngx.header.content_length = nil
           ngx.header["Content-Encoding"] = "br"
           ngx.ctx.bro_encoder = brotli.createEncoder()
        end
    }

    body_filter_by_lua_block {
        if not ngx.ctx.bro_ok then
           return
        end                
        local brotli = require "resty.brotli"
        local encoder = ngx.ctx.bro_encoder
        ngx.arg[1] = brotli.compressStream(encoder, ngx.arg[1])
        
        if brotli.encoderIsFinished(encoder) then
           brotli.destroyEncoder(encoder)
           ngx.arg[2] = true
        else
           ngx.ctx.bro_encoder = encoder
        end
    }
}
````

Methods
=======

createEncoder
-----------
`syntax: encoder = brotli.createEncoder()`

Creates an instance of BrotliEncoderState and initializes it.

createDecoder
-------------
`syntax: decoder = brotli.createDecoder()`

Creates an instance of BrotliDecoderState and initializes it.

destroyEncoder
--------------
`syntax: brotli.destroyEncoder()`

Deinitializes and frees BrotliEncoderState instance.

destroyDecoder
--------------
`syntax: brotli.destroyDecoder()`

Deinitializes and frees BrotliDecoderState instance.

encoderIsFinished
-----------------
`syntax: isfinished = brotli.encoderIsFinished(encoder)`

Checks if encoder instance reached the final state.

compress
--------
`syntax: encoded_buffer, err = brotli.compress(input_buffer, options?)`

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
`syntax: decoded_buffer, err = brotli.decompress(encoded_buffer)`

Decompresses the data in encoded_buffer into decoded_buffer.

decompressStream
----------------
`syntax: ret, buffer = brotli.decompressStream(decoder, encoded_buffer)`

Decompresses the data in encoded_buffer into buffer stream


