local hex_dump = require "utils.string.hex_dump"
local utf8 = require "utf8"
local sfmt = string.format
local print = print
local error = error

--TODO: don't think this should throw an error, rather do return nil, message

local function check_utf8(utf8str)
	local len, errpos = utf8.len(utf8str)
	if not len then
		print("ERROR:", utf8str)
		local hex = hex_dump(utf8str)
		error(sfmt("invalid utf8 at position %s\n%s", errpos, hex))
	end
end

return check_utf8
