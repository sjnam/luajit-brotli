local ffi = require "ffi"

local ffi_new = ffi.new
local ffi_load = ffi.load
local ffi_str = ffi.string
local C = ffi.C
local assert = assert
--local setmetatable = setmetatable


local _M = { _VERSION = '0.01' }


local mt = { __index = _M }



ffi.cdef[[
/* encoder */
typedef enum BrotliEncoderMode {
  BROTLI_MODE_GENERIC = 0,
  BROTLI_MODE_TEXT = 1,
  BROTLI_MODE_FONT = 2
} BrotliEncoderMode;

typedef enum BrotliEncoderParameter {
  BROTLI_PARAM_MODE = 0,
  BROTLI_PARAM_QUALITY = 1,
  BROTLI_PARAM_LGWIN = 2,
  BROTLI_PARAM_LGBLOCK = 3,
  BROTLI_PARAM_DISABLE_LITERAL_CONTEXT_MODELING = 4,
  BROTLI_PARAM_SIZE_HINT = 5
} BrotliEncoderParameter;

typedef struct BrotliEncoderStateStruct BrotliEncoderState;

typedef void* (*brotli_alloc_func)(void* opaque, size_t size);

typedef void (*brotli_free_func)(void* opaque, void* address);

int BrotliEncoderSetParameter(
    BrotliEncoderState* state, BrotliEncoderParameter param, uint32_t value);

BrotliEncoderState* BrotliEncoderCreateInstance(
    brotli_alloc_func alloc_func, brotli_free_func free_func, void* opaque);

size_t BrotliEncoderMaxCompressedSize(size_t input_size);

int BrotliEncoderCompress(
    int quality, int lgwin, BrotliEncoderMode mode, size_t input_size,
    const uint8_t input_buffer[],
    size_t* encoded_size,
    uint8_t encoded_buffer[]);

void BrotliEncoderSetCustomDictionary(
    BrotliEncoderState* state, size_t size,
    const uint8_t dict[]);

int BrotliEncoderIsFinished(BrotliEncoderState* state);

void BrotliEncoderDestroyInstance(BrotliEncoderState* state);


/* decoder */
typedef struct BrotliDecoderStateStruct BrotliDecoderState;

typedef enum {
  BROTLI_DECODER_RESULT_ERROR = 0,
  BROTLI_DECODER_RESULT_SUCCESS = 1,
  BROTLI_DECODER_RESULT_NEEDS_MORE_INPUT = 2,
  BROTLI_DECODER_RESULT_NEEDS_MORE_OUTPUT = 3
} BrotliDecoderResult;

BrotliDecoderState* BrotliDecoderCreateInstance(
    brotli_alloc_func alloc_func, brotli_free_func free_func, void* opaque);

void BrotliDecoderDestroyInstance(BrotliDecoderState* state);

BrotliDecoderResult BrotliDecoderDecompress(
    size_t encoded_size,
    const uint8_t encoded_buffer[],
    size_t* decoded_size,
    uint8_t decoded_buffer[]);

]]


local brotli_enc = ffi_load("brotlienc")
local brotli_dec = ffi_load("brotlidec")
local brotli_common = ffi_load("brotlicommon")

local kFileBufferSize = 65536;

-- Performs one-shot memory-to-memory compression.
local function compress (txt, options)
   local lgwin = 0
   local quality = 11
   local mode = C.BROTLI_MODE_GENERIC
   if options then
      lgwin = options.lgwin or lgwin
      quality = options.quality or quality
      mode = options.mode or mode
   end
   
   local s = brotli_enc.BrotliEncoderCreateInstance(nil, nil, nil);
   if not s then
      return nil, "out of memory: cannot create encoder instance"
   end
   
   local input_size = #txt
   local n = brotli_enc.BrotliEncoderMaxCompressedSize(input_size)
   local encoded_size = ffi_new("size_t[1]", n)
   local encoded_buffer = ffi_new("uint8_t[?]", n)
   local ret = brotli_enc.BrotliEncoderCompress(quality, lgwin, mode, input_size,
                                                txt, encoded_size, encoded_buffer)
   
   assert(ret == 1)
   brotli_enc.BrotliEncoderDestroyInstance(s);
   
   return ffi_str(encoded_buffer, encoded_size[0])
end

_M.compress = compress


-- Performs one-shot memory-to-memory decompression.
local function decompress (encoded_buffer)
   local s = brotli_dec.BrotliDecoderCreateInstance(nil, nil, nil);
   if not s then
      return nil, "out of memory: cannot create decoder instance"
   end
   
   local decoded_size = ffi_new("size_t[1]", kFileBufferSize)
   local decoded_buffer = ffi_new("uint8_t[?]", kFileBufferSize)
   local ret = brotli_dec.BrotliDecoderDecompress(#encoded_buffer,
                                                  encoded_buffer,
                                                  decoded_size,
                                                  decoded_buffer)
   
   assert(ret == C.BROTLI_DECODER_RESULT_SUCCESS)
   brotli_dec.BrotliDecoderDestroyInstance(s)
   
   return ffi_str(decoded_buffer)
end

_M.decompress = decompress


return _M

