package = "lua-resty-brotli"
version = "0.2-1"
source = {
  url = "git://github.com/sjnam/lua-resty-brotli",
}
description = {
  summary = "Lua bindings to Google Brotli compression library for LuaJIT using FFI",
  homepage = "https://github.com/sjnam/lua-resty-brotli",
  maintainer = "Soojin Nam",
  license = "MIT"
}
dependencies = {
    "lua >= 5.1",
}
build = {
  type = "builtin",
  modules = {
    ["resty.brotli.encoder"] = "lib/resty/brotli/encoder.lua",
    ["resty.brotli.decoder"] = "lib/resty/brotli/decoder.lua"
  }
}
