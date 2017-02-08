local ffi = require "ffi"
local bit = require "bit"

local ffi_new = ffi.new
local ffi_load = ffi.load
local ffi_copy = ffi.copy
local ffi_cast = ffi.cast
local ffi_str = ffi.string
local ffi_gc = ffi.gc
local ffi_sizeof = ffi.sizeof
local C = ffi.C
local bit_lshift = bit.lshift
local assert = assert


local _M = { _VERSION = '0.01' }


-- local mt = { __index = _M }


ffi.cdef[[
typedef void *FILE;
int    fclose(FILE *stream);
FILE  *fopen(const char *fname, const char *mode);
size_t fread(void *ptr, size_t size, size_t nitems, FILE *stream);
size_t fwrite(const void *ptr, size_t size, size_t nitems, FILE *stream);
int    feof(FILE *stream);
int    ferror(FILE *stream);
int    fseek(FILE *stream, long offset, int whence);
long   ftell(FILE *stream);

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

int BrotliEncoderSetParameter(
    BrotliEncoderState* state, BrotliEncoderParameter param, uint32_t value);

BrotliEncoderState* BrotliEncoderCreateInstance(
    brotli_alloc_func alloc_func, brotli_free_func free_func, void* opaque);

size_t BrotliEncoderMaxCompressedSize(size_t input_size);

int BrotliEncoderCompressStream(
    BrotliEncoderState* state, BrotliEncoderOperation op, size_t* available_in,
    const uint8_t** next_in, size_t* available_out, uint8_t** next_out,
    size_t* total_out);

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


local kFileBufferSize = 65536


local function FileSize(path)
   local f = C.fopen(path, "rb")
   if not f then return -1 end
   if C.fseek(f, 0, 2) ~= 0 then -- SEEK_END = 2
      C.fclose(f)
      return -1
   end
   
   local retval = C.ftell(f)
   if C.fclose(f) ~= 0 then
      return -1
   end
  
   return retval
end


local function ReadDictionary(path, dictionary_size)
  local kMaxDictionarySize = bit_lshift(1, 24) - 16
  local f = C.fopen(path, "rb")
  if not f then
     return nil, "file open error"
  end

  local file_size_64 = FileSize(path)
  if file_size_64 == -1 then
    return nil, "could not get size of dictionary file"
  end

  if file_size_64 > kMaxDictionarySize then
     return nil, "dictionary is larger than maximum allowed: "..kMaxDictionarySize
  end

  dictionary_size[0] = file_size_64

  local buffer = ffi_new("uint8_t[?]", dictionary_size[0])
  if not buffer then
    return nil, "could not read dictionary: out of memory"
  end
  
  local bytes_read = C.fread(buffer, ffi_sizeof("uint8_t"), dictionary_size[0], f)
  if bytes_read ~= dictionary_size[0] then
    return nil, "could not read dictionary"
  end
  
  C.fclose(f)

  return buffer
end


-- Compresses input stream to output stream.
local function compressStream (path, options)
   local lgwin = 0
   local quality = 11
   local mode = C.BROTLI_MODE_GENERIC
   local dictionary_path = nil
   if options then
      lgwin = options.lgwin or lgwin
      quality = options.quality or quality
      mode = options.mode or mode
      dictionary_path = options.dictionary_path or dictionary_path
   end
   
   local s = brotli_enc.BrotliEncoderCreateInstance(nil, nil, nil)
   if not s then
      return nil, "out of memory: cannot create encoder instance"
   end
   
   brotli_enc.BrotliEncoderSetParameter(s, C.BROTLI_PARAM_QUALITY, quality)
   brotli_enc.BrotliEncoderSetParameter(s, C.BROTLI_PARAM_LGWIN, lgwin)
   if dictionary_path then 
      local dictionary_size = ffi_new("size_t[1]", 0)
      local dictionary = ReadDictionary(dictionary_path, dictionary_size)
      if not dictionary then
         return nil, "cannot open dictionary file"
      end
      brotli_enc.BrotliEncoderSetCustomDictionary(s, dictionary_size, dictionary)
      ffi_gc(dictionary, free)
   end
   
   local fin = C.fopen(path, "rb")
   if not fin then
      return nil, "file open error"
   end

   local fout = C.fopen(path..".br", "wb")
   if not fout then
      return nil, "file open error"
   end

   local buffer = ffi_new("uint8_t[?]", bit_lshift(kFileBufferSize, 1))
   
   if not s or not buffer then
      return nil, "out of memory: cannot create encoder instance"
   end

   local input = buffer
   local output = buffer + kFileBufferSize
   local available_in = ffi_new("size_t[1]", 0)
   local available_out = ffi_new("size_t[1]", kFileBufferSize)
   local next_in = ffi_new("const uint8_t*[1]")
   local next_out = ffi_new("uint8_t*[1]")
   next_out[0] = output
   local is_eof = 0
   local is_ok = 1
   
   while true do
      if available_in[0] == 0 and is_eof == 0 then
         available_in[0] = C.fread(input, 1, kFileBufferSize, fin)
         next_in[0] = input
         if C.ferror(fin) ~= 0 then break end
         is_eof = C.feof(fin)
      end
      
      if brotli_enc.BrotliEncoderCompressStream(
         s, is_eof ~= 0 and C.BROTLI_OPERATION_FINISH or C.BROTLI_OPERATION_PROCESS,
         available_in, next_in, available_out, next_out, nil) == 0 then
         is_ok = 0
         break
      end
      
      if available_out[0] ~= kFileBufferSize then
         local out_size = kFileBufferSize - available_out[0]
         C.fwrite(output, 1, out_size, fout)
         if C.ferror(fout) ~= 0 then break end
         available_out[0] = kFileBufferSize
         next_out[0] = output
      end
      
      if brotli_enc.BrotliEncoderIsFinished(s) == 1 then
         break
      end
   end

   ffi_gc(buffer, free)
   
   brotli_enc.BrotliEncoderDestroyInstance(s)

   C.fclose(fin)
   C.fclose(fout)
   
   return true
end

_M.compressStream = compressStream


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
   
   local s = brotli_enc.BrotliEncoderCreateInstance(nil, nil, nil)
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
   brotli_enc.BrotliEncoderDestroyInstance(s)
   
   return ffi_str(encoded_buffer, encoded_size[0])
end

_M.compress = compress


-- Performs one-shot memory-to-memory decompression.
local function decompress (encoded_buffer)
   local s = brotli_dec.BrotliDecoderCreateInstance(nil, nil, nil)
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

