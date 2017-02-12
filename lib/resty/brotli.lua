local ffi = require "ffi"

local ffi_new = ffi.new
local ffi_load = ffi.load
local ffi_copy = ffi.copy
local ffi_str = ffi.string
local ffi_gc = ffi.gc
local C = ffi.C
local assert = assert
local tab_concat = table.concat
local tab_insert = table.insert

local _M = { _VERSION = '0.01' }


ffi.cdef[[
void free(void *ptr);

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

typedef void* (*brotli_alloc_func)(void* opaque, size_t size);
typedef void (*brotli_free_func)(void* opaque, void* address);

typedef struct BrotliEncoderStateStruct BrotliEncoderState;

BrotliEncoderState* BrotliEncoderCreateInstance(
    brotli_alloc_func alloc_func, brotli_free_func free_func, void* opaque);

int BrotliEncoderSetParameter(
    BrotliEncoderState* state, BrotliEncoderParameter param, uint32_t value);

int BrotliEncoderCompressStream(
    BrotliEncoderState* state, BrotliEncoderOperation op, size_t* available_in,
    const uint8_t** next_in, size_t* available_out, uint8_t** next_out,
    size_t* total_out);

size_t BrotliEncoderMaxCompressedSize(size_t input_size);

int BrotliEncoderCompress(
    int quality, int lgwin, BrotliEncoderMode mode, 
    size_t input_size, const uint8_t input_buffer[],
    size_t* encoded_size, uint8_t encoded_buffer[]);

int BrotliEncoderIsFinished(BrotliEncoderState* state);

void BrotliEncoderDestroyInstance(BrotliEncoderState* state);

/* decoder */
typedef enum {
  BROTLI_DECODER_RESULT_ERROR = 0,
  BROTLI_DECODER_RESULT_SUCCESS = 1,
  BROTLI_DECODER_RESULT_NEEDS_MORE_INPUT = 2,
  BROTLI_DECODER_RESULT_NEEDS_MORE_OUTPUT = 3
} BrotliDecoderResult;

typedef struct BrotliDecoderStateStruct BrotliDecoderState;

BrotliDecoderState* BrotliDecoderCreateInstance(
    brotli_alloc_func alloc_func, brotli_free_func free_func, void* opaque);

void BrotliDecoderDestroyInstance(BrotliDecoderState* state);

BrotliDecoderResult BrotliDecoderDecompressStream(
  BrotliDecoderState* state, 
  size_t* available_in, const uint8_t** next_in,
  size_t* available_out, uint8_t** next_out,
  size_t* total_out);
]]


local encoder = ffi_load("brotlienc")
local decoder = ffi_load("brotlidec")


local BROTLI_TRUE = 1
local BROTLI_FALSE = 0

local BROTLI_DEFAULT_QUALITY = 11
local BROTLI_DEFAULT_WINDOW = 22
local BROTLI_DEFAULT_MODE = C.BROTLI_MODE_GENERIC

local kFileBufferSize = 65536


local function compress (input, options)
   local lgwin = BROTLI_DEFAULT_WINDOW
   local quality = BROTLI_DEFAULT_QUALITY
   local mode = BROTLI_DEFAULT_MODE
   if options then
      lgwin = options.lgwin or lgwin
      quality = options.quality or quality
      mode = options.mode or mode
   end

   local input_size = #input
   local n = encoder.BrotliEncoderMaxCompressedSize(input_size)
   local encoded_size = ffi_new("size_t[1]", n)
   local encoded_buffer = ffi_new("uint8_t[?]", n)
   local ret = encoder.BrotliEncoderCompress(
      quality, lgwin, mode,
      input_size, input, encoded_size, encoded_buffer)

   assert(ret == BROTLI_TRUE)
   
   return ffi_str(encoded_buffer, encoded_size[0])
end
--_M.compress = compress


local function compressStream (str, options, bufsize)
   local bufsize = bufsize or kFileBufferSize
   local lgwin = BROTLI_DEFAULT_WINDOW
   local quality = BROTLI_DEFAULT_QUALITY
   local mode = BROTLI_DEFAULT_MODE
   if options then
      lgwin = options.lgwin or lgwin
      quality = options.quality or quality
      mode = options.mode or mode
   end

   local s = encoder.BrotliEncoderCreateInstance(nil, nil, nil)
   if not s then
      return nil, "out of memory: cannot create encoder instance"
   end
   
   encoder.BrotliEncoderSetParameter(s, C.BROTLI_PARAM_QUALITY, quality)
   encoder.BrotliEncoderSetParameter(s, C.BROTLI_PARAM_LGWIN, lgwin)

   local buffer = ffi_new("uint8_t[?]", bufsize*2)
   if not buffer then
      return nil, "out of memory"
   end

   local input = buffer
   local output = buffer + bufsize
   local available_in = ffi_new("size_t[1]", 0)
   local available_out = ffi_new("size_t[1]", bufsize)
   local next_in = ffi_new("const uint8_t*[1]")
   local next_out = ffi_new("uint8_t*[1]")
   next_out[0] = output
   local is_ok = true
   local is_eof = false
   
   local res = {}
   local len = #str
   local buff = ffi.new("char[?]", len, str)
   local p = buff

   while true do
      if available_in[0] == 0 and not is_eof then
         local read_size = bufsize
         if len <= bufsize then
            read_size = len
         end
         ffi_copy(input, ffi_str(p, read_size))
         available_in[0] = read_size
         next_in[0] = input
         len = len - read_size
         p = p + read_size
         is_eof = len <= 0
      end
      
      if encoder.BrotliEncoderCompressStream(
         s,
         is_eof and C.BROTLI_OPERATION_FINISH or C.BROTLI_OPERATION_PROCESS,
         available_in, next_in, available_out, next_out, nil) == BROTLI_FALSE
      then
         is_ok = false
         break
      end
      
      if available_out[0] ~= bufsize then
         local out_size = bufsize - available_out[0]

         tab_insert(res, ffi_str(output, out_size))
         available_out[0] = bufsize
         next_out[0] = output
      end
      
      if encoder.BrotliEncoderIsFinished(s) == 1 then
         break
      end
   end

   ffi_gc(buff, free)
   ffi_gc(buffer, free)
   encoder.BrotliEncoderDestroyInstance(s)

   if is_ok then
      return tab_concat(res)
   end
   
   return nil, "fail to compress"
end
_M.compress = compressStream


local function decompress (encoded_buffer, bufsize)
   local bufsize = bufsize or kFileBufferSize
   local s = decoder.BrotliDecoderCreateInstance(nil, nil, nil)
   if not s then
      return nil, "out of memory: cannot create decoder instance"
   end

   local available_in = ffi_new("size_t[1]", #encoded_buffer)
   local next_in = ffi_new("const uint8_t*[1]")
   next_in[0] = encoded_buffer
   local buffer = ffi_new("uint8_t[?]", bufsize)

   local decoded_buffer = {}
   local ret = C.BROTLI_DECODER_RESULT_NEEDS_MORE_OUTPUT
   while ret == C.BROTLI_DECODER_RESULT_NEEDS_MORE_OUTPUT do
      local available_out = ffi_new("size_t[1]", bufsize)
      local next_out = ffi_new("uint8_t*[1]", buffer)
      local total_out = ffi_new("size_t[1]", 0)
      ret = decoder.BrotliDecoderDecompressStream(s,
                                                  available_in, next_in,
                                                  available_out, next_out,
                                                  total_out)
      local used_out = bufsize - available_out[0]
      if used_out ~= 0 then
         decoded_buffer[#decoded_buffer+1] = ffi_str(buffer, used_out)
      end
   end

   assert(ret == C.BROTLI_DECODER_RESULT_SUCCESS)
   decoder.BrotliDecoderDestroyInstance(s)
   
   return tab_concat(decoded_buffer)
end
_M.decompress = decompress


return _M

