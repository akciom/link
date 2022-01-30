local type = type

local ffi = require "ffi"
local ffinew = ffi.new

ffi.cdef[[
struct hitbox {
	float offx, offy;
	float hw, hh;
};
]]

local struct_hitbox_ctype = ffi.typeof("struct hitbox")

local hitbox = {
	_datatype = "hitbox",
}

local meta = {}

meta.__index = hitbox

local strfmt = string.format
function meta:__tostring()
	return strfmt("%.2f,%.2f+%.2f,%.2f",
		self.offx, self.offy, self.hw, self.hh)
end

local function istype(v)
	return type(v) == "cdata" and v._datatype == "hitbox"
end

--Can be inialized with (hitbox) or (hw, hh) or (offx, offy, hw, hh)
local function new(arg1, arg2, hw, hh)
	local offx = arg1
	local offy = arg2
	if istype(arg1) then
		local hbox = arg1
		offx = hbox.offx
		offy = hbox.offy
		hw = hbox.hw
		hh = hbox.hh
	elseif hw == nil and hh == nil then
		offx, offy = 0, 0
		hw = arg1
		hh = arg2
	end

	local hitbox = ffinew(struct_hitbox_ctype)
	hitbox.offx = offx
	hitbox.offy = offy
	hitbox.hw = hw
	hitbox.hh = hh
	return hitbox
end

function hitbox:unpack()
	return self.offx, self.offy, self.hw, self.hh
end



ffi.metatype(struct_hitbox_ctype, meta)

return setmetatable({new = new, istype = istype},
{__call = function(_, ...) return new(...) end})
