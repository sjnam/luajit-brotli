local ffi = require "ffi"

local ffi_new = ffi.new
local ffi_load = ffi.load
local ffi_copy = ffi.copy
local ffi_str = ffi.string
local C = ffi.C
local assert = assert
local tab_concat = table.concat


local _M = { _VERSION = '0.01' }


ffi.cdef[[
/* encoder */
typedef enum BrotliEncoderMode {
  BROTLI_MODE_GENERIC = 0,
  BROTLI_MODE_TEXT = 1,
  BROTLI_MODE_FONT = 2
} BrotliEncoderMode;

typedef enum BrotliEncoderOperation {
  BROTLI_OPERATION_PROCESS = 0,
  BROTLI_OPERATION_FLUSH = 1,
  BROTLI_OPERATION_FINISH = 2,
  BROTLI_OPERATION_EMIT_METADATA = 3
} BrotliEncoderOperation;

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

BrotliEncoderState* BrotliEncoderCreateInstance(
    brotli_alloc_func alloc_func, brotli_free_func free_func, void* opaque);

size_t BrotliEncoderMaxCompressedSize(size_t input_size);

int BrotliEncoderCompress(
    int quality, int lgwin, BrotliEncoderMode mode, size_t input_size,
    const uint8_t input_buffer[],
    size_t* encoded_size,
    uint8_t encoded_buffer[]);

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

BrotliDecoderResult BrotliDecoderDecompressStream(
  BrotliDecoderState* state, size_t* available_in, const uint8_t** next_in,
  size_t* available_out, uint8_t** next_out, size_t* total_out);
]]


local brotli_enc = ffi_load("brotlienc")
local brotli_dec = ffi_load("brotlidec")


local BROTLI_DEFAULT_QUALITY = 11
local BROTLI_DEFAULT_WINDOW = 22
local BROTLI_DEFAULT_MODE = C.BROTLI_MODE_GENERIC

local kFileBufferSize = 65536



-- Performs one-shot memory-to-memory compression.
local function compress (input, options)
   local lgwin = BROTLI_DEFAULT_WINDOW
   local quality = BROTLI_DEFAULT_QUALITY
   local mode = BROTLI_DEFAULT_MODE
   if options then
      lgwin = options.lgwin or lgwin
      quality = options.quality or quality
      mode = options.mode or mode
   end
   
   local s = brotli_enc.BrotliEncoderCreateInstance(nil, nil, nil)
   if not s then
      return nil, "out of memory: cannot create encoder instance"
   end
   
   local input_size = #input
   local n = brotli_enc.BrotliEncoderMaxCompressedSize(input_size)
   local encoded_size = ffi_new("size_t[1]", n)
   local encoded_buffer = ffi_new("uint8_t[?]", n)
   local ret = brotli_enc.BrotliEncoderCompress(
      quality, lgwin, mode,
      input_size, input, encoded_size, encoded_buffer)
   
   assert(ret == 1)
   brotli_enc.BrotliEncoderDestroyInstance(s)
   
   return ffi_str(encoded_buffer, encoded_size[0])
end

_M.compress = compress


local function decompress (encoded_buffer)
   local s = brotli_dec.BrotliDecoderCreateInstance(nil, nil, nil)
   if not s then
      return nil, "out of memory: cannot create decoder instance"
   end

   local available_in = ffi_new("size_t[1]", #encoded_buffer)
   local next_in = ffi_new("const uint8_t*[1]")
   next_in[0] = encoded_buffer
   local buffer = ffi_new("uint8_t[?]", kFileBufferSize)

   local decoded_buffer = {}
   local ret = C.BROTLI_DECODER_RESULT_NEEDS_MORE_OUTPUT
   while ret == C.BROTLI_DECODER_RESULT_NEEDS_MORE_OUTPUT do
      local available_out = ffi_new("size_t[1]", kFileBufferSize)
      local next_out = ffi_new("uint8_t*[1]", buffer)
      local total_out = ffi_new("size_t[1]", 0)
      ret = brotli_dec.BrotliDecoderDecompressStream(s,
                                                     available_in, next_in,
                                                     available_out, next_out,
                                                     total_out)
      local used_out = kFileBufferSize - available_out[0]
      if used_out ~= 0 then
         decoded_buffer[#decoded_buffer+1] = ffi_str(buffer, used_out)
      end
   end

   assert(ret == C.BROTLI_DECODER_RESULT_SUCCESS)
   brotli_dec.BrotliDecoderDestroyInstance(s)
   
   return tab_concat(decoded_buffer)
end

_M.decompress = decompress


return _M

