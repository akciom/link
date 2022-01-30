-- Copyright 2020 -- Scott Smith --

local f = {}
f._VERSION = "Logging 0.3.0-beta.2"

local setmetatable, type, require
	= setmetatable, type, require
local io_write, dgetinfo = io.write, debug.getinfo
local strup = string.upper
local sfmt = string.format
local osdate = os.date
local floor = math.floor

local printf = require "utils.printf"

function f.time (...)
	io_write(osdate("[%m/%d %H:%M:%S] "))
	printf(...)
	io_write("\n")
end

local log_print = function (self, level, logtype, ...)
	local di = dgetinfo(level + 2, "Sl");
	local name = di.short_src
	local line_number = di.currentline
	if self._hal then --{{{ agpack specific modifications
	--TODO: separate agpack specific mods to make logging a generic util
	--something like: string = function(name, line_number, logtype)
		local agpack = name:match("agpack(.*).lua")
		if agpack then
			name = sfmt("AGP%s", agpack)
		end
		local hal = self._hal
		name = sfmt("[%2d'%02d]", floor(hal.met), hal.frame) .. name
	end --}}}
	printf("%s:%-4d %5s: ", name, line_number, logtype)
	printf(...)
	io_write("\n")
end

local log = setmetatable(f, {__index = function(self, logtype)
	logtype = strup(logtype)
	return function(level, ...)
		if type(level) == "number" then
			return log_print(self, level, logtype, ...)
		else
			return log_print(self, 0, logtype, level, ...)
		end
	end
end;
__call = function(self, options)
	self._hal = options.hal
	return self
end})

return log
