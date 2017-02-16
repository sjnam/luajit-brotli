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

Simple usage
```` lua
local brotlienc = require "resty.brotli.encoder"
local brotlidec = require "resty.brotli.decoder"

local encoder = brotlienc:new()
local decoder = brotlidec:new()

local txt = string.rep("ABCD", 1000)
print("Uncompressed size:", #txt)
local c, err = encoder:compress(txt)
print("Compressed size:", #c)
local txt2, err = decoder:decompress(c)
assert(txt == txt2)
````

In nginx with lua-nginx-module

The following sample nginx.conf, the document root directory, `html/brotli`
has only precompressed files with the ".br" filename extension instead of
reqular files.
```` lua
# static contents
location /brotli {
    root html;
    
    rewrite_by_lua_block {
       local brotlidec = require "resty.brotli.decoder"
       local brotli_ok = false
       local header = ngx.var.http_accept_encoding
       if header then
          if string.find(header, "br") then
             brotli_ok = true
          end
       end
       if not brotli_ok then
          ngx.ctx.decoder = brotlidec:new()
       end
       ngx.ctx.brotli_ok = brotli_ok
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
       if ngx.ctx.brotli_ok then
          return
       end

       local decoder = ngx.ctx.decoder
       local stream = decoder:decompressStream(ngx.arg[1])
       ngx.arg[1] = stream
       if decoder:resultSuccess() then
          decoder:destroy()
          ngx.arg[2] = true
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
        local brotlienc = require "resty.brotli.encoder"
        local brotli_ok = false
        local header = ngx.var.http_accept_encoding
        if header then
           if string.find(header, "br") then
              brotli_ok = true
           end
        end
        ngx.ctx.brotli_ok = brotli_ok
        ngx.header["Vary"] = "Accept-Encoding"
        if brotli_ok then
           ngx.header.content_length = nil
           ngx.header["Content-Encoding"] = "br"
           ngx.ctx.encoder = brotlienc:new()
        end
    }

    body_filter_by_lua_block {
        if not ngx.ctx.brotli_ok then
           return
        end                
        local encoder = ngx.ctx.encoder
        ngx.arg[1] = encoder:compressStream(ngx.arg[1])        
        if encoder:isFinished() then
           encoder:destroy()
           ngx.arg[2] = true
        end
    }
}
````

Methods
=======

new
---
`syntax: encoder, err = brotlienc:new(options?)`

`syntax: decoder, err = brotlidec:new()`

Create brotli encoder and decoder.

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


destroy
-------
* `syntax: encoder:destroy()`

    Deinitializes and frees BrotliEncoderState instance.

* `syntax: decoder:destroy()`

    Deinitializes and frees BrotliDecoderState instance.


compress
--------
`syntax: encoded_buffer, err = encoder:compress(input_buffer)`

Compresses the data in input_buffer into encoded_buffer.


compressStream
--------------
`syntax: buffer = encoder:compressStream(stream)`

Compresses input stream to output buffer.


decompress
----------
`syntax: decoded_buffer, err = decoder:decompress(encoded_buffer)`

Decompresses the data in encoded_buffer into decoded_buffer.


decompressStream
----------------
`syntax: buffer = decoder:decompressStream(encoded_buffer)`

Decompresses the data in encoded_buffer into buffer stream

