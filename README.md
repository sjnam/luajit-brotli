Name
====
luajit-brotli - Google [Brotli](https://github.com/google/brotli) ffi bounding


Installation
============
To install `luajit-brotli` you need to install
[Brotli](https://github.com/google/brotli#build-instructions)
with shared libraries firtst.
Then you can install `luajit-brotli` by placing `brotli/{encoder,decoder}.lua` to
your lua library path.


Synopsis
========

* Simple usage
```lua
local brotlienc = require "brotli.encoder"
local brotlidec = require "brotli.decoder"

local encoder = brotlienc:new()
local decoder = brotlidec:new()

local txt = string.rep("ABCD", 1000)
print("Uncompressed size:", #txt)
local c, err = encoder:compress(txt)
print("Compressed size:", #c)
local txt2, err = decoder:decompress(c)
assert(txt == txt2)
```

* In nginx with lua-nginx-module

  The document root directory, `html` has only precompressed files with the ".br" filename
  extension instead of reqular files. If a brower does not support "br",
  it decompress on-the-fly.
```nginx
# static contents
location / {
    root html;
    
    rewrite_by_lua_block {
       local brotlidec = require "brotli.decoder"
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
       if not ngx.ctx.brotli_ok then
          ngx.header.content_length = nil
       else
          ngx.header["Content-Encoding"] = "br"
       end
    }
    
    body_filter_by_lua_block {
       if ngx.ctx.brotli_ok then return end
       local decoder = ngx.ctx.decoder
       ngx.arg[1] = decoder:decompressStream(ngx.arg[1])
       if decoder:isFinished() then
          decoder:destroy()
          ngx.arg[2] = true
       end
    }
}
```

* Compressing on-the-fly for dynamic contents
```nginx
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
        local brotlienc = require "brotli.encoder"
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
        if not ngx.ctx.brotli_ok then return end                
        local encoder = ngx.ctx.encoder
        ngx.arg[1] = encoder:compressStream(ngx.arg[1])        
        if encoder:isFinished() then
           encoder:destroy()
           ngx.arg[2] = true
        end
    }
}
```

* Decompressing on-the-fly for the compressed request body
```nginx
location /reqdecom {
    content_by_lua_block {
        local brotlidec = require "brotli.decoder"

        local decoder = brotlidec:new()
        local sock, err = ngx.req.socket()
        if not sock then
           print(err)
           ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
        end

        sock:settimeout(1000)
        while true do
           local line, err, partial = sock:receive(1024)
           line = decoder:decompressStream(line or partial)
           ngx.print(line)
           if err == "closed" then break end
        end
        decoder:destroy()
    }
}
```

Methods
=======

new
---
* `syntax: encoder, err = brotlienc:new(options?)`

* `syntax: decoder, err = brotlidec:new()`

Create brotli encoder or decoder.

The `options` argument of the encoder is a lua table holding the following keys:

* `quality`

    Set Brotli quality (compression) level.
    Acceptable values are in the range from `0` to `11`.
    (Defaults to 11)

* `lgwin`

    Set Brotli window size. Window size is `(1 << lgwin) - 16`.

* `mode`

    The compression mode can be
    
    * `BROTLI_MODE_GENERIC` (0, default)
    
    * `BROTLI_MODE_TEXT` (1, for UTF-8 format text input)

    * `BROTLI_MODE_FONT` (2, for WOFF 2.0)


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
`syntax: buffer = decoder:decompressStream(encoded_stream)`

Decompresses the data in encoded_buffer into buffer stream

Author
======
Soojin Nam jsunam@gmail.com

License
=======
Public Domain
