-- Copyright 2021 Scott Smith
-- Lua uses Window's ANSI api to open files. I want to change that.


local ffi = require("ffi")
if ffi.os ~= "Windows" then return io end

local setmetatable = setmetatable
local type = type
local sfmt = string.format

local m = {}

if not hal_defined.io_function then
hal_defined.io_function = true
ffi.cdef[[
	typedef unsigned int UINT;
	typedef unsigned long DWORD;
	typedef DWORD *LPDWORD;

	typedef long LONG;
	typedef int64_t LONGLONG;
	typedef uint64_t ULONGLONG;

	typedef void *LPVOID;
	typedef const void *LPCVOID;
	typedef void *HANDLE;
	typedef HANDLE *PHANDLE;

	typedef char *LPSTR;
	typedef const char *LPCCH;

	typedef wchar_t WCHAR;
	typedef WCHAR *LPWSTR;
	typedef const WCHAR *LPCWSTR;
	typedef const WCHAR *LPCWCH;
	typedef int BOOL;
	typedef BOOL *LPBOOL;
	typedef union _LARGE_INTEGER {
		struct {
			DWORD LowPart;
			LONG HighPart;
		} DUMMYSTRUCTNAME;
		struct {
			DWORD LowPart;
			LONG HighPart;
		} u;
		LONGLONG QuadPart;
	} LARGE_INTEGER;
	typedef LARGE_INTEGER *PLARGE_INTEGER;

	typedef struct _SECURITY_ATTRIBUTES {
		DWORD nLength;
		LPVOID lpSecurityDescriptor;
		BOOL bInheritHandle;
	} SECURITY_ATTRIBUTES, *PSECURITY_ATTRIBUTES, *LPSECURITY_ATTRIBUTES;

	typedef void *LPOVERLAPPED;

	int MultiByteToWideChar(
		UINT   CodePage,
		DWORD  dwFlags,
		LPCCH  lpMultiByteStr,
		int    cbMultiByte,
		LPWSTR lpWideCharStr,
		int    cchWideChar
	);
	int WideCharToMultiByte(
		UINT   CodePage,
		DWORD  dwFlags,
		LPCWCH lpWideCharStr,
		int    cchWideChar,
		LPSTR  lpMultiByteStr,
		int    cchMultiByte,
		LPCCH  default,
		LPBOOL used
	);


	HANDLE CreateFileW(
		LPCWSTR               lpFileName,
		DWORD                 dwDesiredAccess,
		DWORD                 dwShareMode,
		LPSECURITY_ATTRIBUTES lpSecurityAttributes,
		DWORD                 dwCreationDisposition,
		DWORD                 dwFlagsAndAttributes,
		HANDLE                hTemplateFile
	);

	BOOL GetFileSizeEx(
		HANDLE    hFile,
		PLARGE_INTEGER lpFileSize
	);
	BOOL ReadFile(
		HANDLE       hFile,
		LPVOID       lpBuffer,
		DWORD        nNumberOfBytesToRead,
		LPDWORD      lpNumberOfBytesRead,
		LPOVERLAPPED lpOverlapped
	);
	BOOL WriteFile(
		HANDLE       hFile,
		LPCVOID      lpBuffer,
		DWORD        nNumberOfBytesToWrite,
		LPDWORD      lpNumberOfBytesWritten,
		LPOVERLAPPED lpOverlapped
	);
	BOOL CloseHandle(HANDLE hObject);

	DWORD GetLastError();

	DWORD FormatMessageW(
		DWORD   dwFlags,
		LPCVOID lpSource,
		DWORD   dwMessageId,
		DWORD   dwLanguageId,
		LPWSTR  lpBuffer,
		DWORD   nSize,
		va_list *Arguments
	);

	void *malloc(size_t size);
	void free(void *memblock);

]]
end
local CP_UTF8 = 65001
local WIDE_CHAR_SIZE = 2

local GENERIC_READ        = 0x80000000 --(0x80000000L)
local GENERIC_WRITE       = 0x40000000 --(0x40000000L)

-- to prevent other processes from opening use value of 0
local FILE_SHARE_READ     = 0x00000001
local FILE_SHARE_WRITE    = 0x00000002
local FILE_SHARE_DELETE   = 0x00000004

local CREATE_NEW          = 1
local CREATE_ALWAYS       = 2
local OPEN_EXISTING       = 3
local OPEN_ALWAYS         = 4
local TRUNCATE_EXISTING   = 5

local FILE_ATTRIBUTE_NORMAL = 0x00000080

local INVALID_HANDLE_VALUE = ffi.cast("HANDLE", -1)


local FORMAT_MESSAGE_IGNORE_INSERTS = 0x00000200
local FORMAT_MESSAGE_FROM_SYSTEM    = 0x00001000

local C = ffi.C

local function utf8_to_wide(str)
	local characters = C.MultiByteToWideChar(CP_UTF8, 0, str, #str, nil, 0)
	--add WIDE_CHAR_SIZE to characters for zero
	local buf = ffi.new("WCHAR[?]",characters + WIDE_CHAR_SIZE)
	C.MultiByteToWideChar(CP_UTF8, 0, str, #str, buf, characters)
	return buf
end

local function wide_to_utf8(wstr)
	local size = C.WideCharToMultiByte(CP_UTF8, 0, wstr, -1, nil,0,nil,nil)
	local buf = ffi.new("char[?]", size + 1) --add one for zero
	C.WideCharToMultiByte(CP_UTF8, 0, wstr, -1, buf, size, nil, nil)
	return ffi.string(buf, size)
end

local bit = require "bit"
local bor = bit.bor

local function get_last_error_msg()
	--TODO:use FormatMessage() for last error message
	local err = C.GetLastError()
	local bufsize = 1024
	local buf = ffi.new("WCHAR[?]", bufsize + WIDE_CHAR_SIZE)
	C.FormatMessageW(
		bor(FORMAT_MESSAGE_FROM_SYSTEM, FORMAT_MESSAGE_IGNORE_INSERTS),
		nil,
		err,
		0,
		buf, bufsize,
		nil
	)
	return wide_to_utf8(buf)
	--return sfmt("error code (%d)", C.GetLastError())
end

function m:size()
	if not self.handle then return nil, "no file open" end
	if not self.length then
		self.length = ffi.new("LARGE_INTEGER[1]")
	end
	local ret = C.GetFileSizeEx(self.handle, self.length) ~= 0
	if not ret then 
		return nil, get_last_error_msg()
	end
	return self.length[0].QuadPart
end

--TODO: support other Lua read arguments: *l, *n
--TODO: check what happens if reading from EOF
--TODO: this will likely all break if it can't all be loaded into memory
function m:read(num)
	if not self.handle then return nil, "no file open" end
	--print("reading HANDLE", self.handle)
	local size = 0
	if type(num) == "number" then
		size = num
	elseif type(num) == "string" then
		if num == "*a" then
			local err
			size, err = self:size()
			if not size then return nil, err end
		elseif num == "*l" then
			error("*l not supported")
		elseif num == "*n" then
			error("*n not supported")
		end
	elseif type(num) == "nil" then
		error("*l (default) not supported")
	end
	local size = self:size()
	local buf = ffi.gc(C.malloc(size), C.free)
	local bytesread = ffi.new("DWORD[1]", 0)
	local ret = C.ReadFile(self.handle, buf, size, bytesread, nil) ~= 0
	if not ret then return nil, get_last_error_msg() end
	return ffi.string(buf, bytesread[0]), bytesread[0]
end

function m:write(str)
	if not self.handle then return nil, "no file open" end
	local byteswritten = ffi.new("DWORD[1]", 0)
	local ret = C.WriteFile(self.handle, str, #str, byteswritten, nil) ~= 0
	if not ret then return nil, get_last_error_msg() end
	return byteswritten[0]
end

function m:close()
	if self.handle then
		local ret = C.CloseHandle(self.handle) ~= 0
		self.handle = false
		if not ret then
			return nil, get_last_error_msg()
		end
	end
	return true
end

local f = {}

--modes:
--  r   Read (beginning of file)
--  r+  Read & Write (beginning of file)
--  w   Write Truncate to zero length or created. (beginning of file)
--  w+  Read & Write. Truncate to zero or created (beginning of file)
--  a   Append. Create if not exist. (end of file)
--  a+  Read (beginning of file) & Append (end of file). Create if not exist.
--      Append only allows writing at end of file
function f.open(filename, mode)
	--print("OPEN", filename, mode)
	local ft = {}
	local read, write, create, append, trunc = false, false, false, false, false

	local desired_access --set by parsing mode
	local share_mode = bor(FILE_SHARE_READ, FILE_SHARE_WRITE)
	local creation_disposition --set by parsing mode
	local flags_and_attributes = FILE_ATTRIBUTE_NORMAL

do --{{{ parse mode
	mode = mode or "r"
	local s, e, rwa, bp1, bp2 = string.find(mode, "([rwa])([%+b]?)([%+b]?)")
	if rwa == "r" then
		desired_access = GENERIC_READ
		creation_disposition = OPEN_EXISTING
		read = true
	elseif rwa == "w" then
		desired_access = GENERIC_WRITE
		creation_disposition = CREATE_ALWAYS
		write = true
		trunc = true
		create = true
	elseif rwa == "a" then
		desired_access = GENERIC_WRITE
		creation_disposition = CREATE_ALWAYS
		write = true
		append = true
		create = true
	end
	if bp1 == "+" or bp2 == "+" then
		desired_access = bor(GENERIC_READ, GENERIC_WRITE)
		read, write = true, true
	end
end--}}} parse mode
	if not desired_access or not creation_disposition then
		return nil, "invalid mode"
	end

	local handle = C.CreateFileW(
		utf8_to_wide(filename),
		desired_access, share_mode,
		nil, --security attributes
		creation_disposition, flags_and_attributes,
		nil -- template file
	)

	--print("HANDLE opened", handle)
	--print("INVALID_HANDLE", INVALID_HANDLE_VALUE)
	if handle == INVALID_HANDLE_VALUE then
		return nil, get_last_error_msg()
	end

	ft.handle = handle

	return setmetatable(ft, {__index = m})

end

return setmetatable({}, {__index = f})
