--Copyright 2020 -- Scott Smith --

local print, setmetatable, select 
	= print, setmetatable, select
local sfmt = string.format

local f = {}

local m = {type = "component"}
function m:trunc(len)
	local eid = self.eid
	for i = len+1, #eid do
		eid[i] = nil
	end
end

--I could use a hash map, but the map will need to be updated to keep in
--sync with the eid array so that's an optimization for later.

--on the bright side, searching through arrays is fast and if it becomes
--slow, the optimization should be quite easy!
function m:map(entity)
	local eid = self.eid
	for i = 1, #eid do
		if eid[i] == entity then
			return i
		end
	end
	return false
end

function m:map_type(type, value)
	local t = self[type]
	if not t then return nil, "invalid type" end
	for i = 1, #t do
		if t[i] == value then
			return i
		end
	end
	return false
end

function m:print(list) local component = self
	list = list or {"eid"}
	local tstr = {sfmt("%5s:", "i")}
	for i = 1, #component[list[1]] do
		table.insert(tstr, sfmt("%3d", i))
	end
	print(table.concat(tstr, ", "))
	for i = 1, #tstr do tstr[i] = nil end
	for li = 1, #list do
		table.insert(tstr, sfmt("%5s:", list[li]))
		for i = 1, #component[list[li]] do
			local str
			local val = component[list[li]][i]
			if type(val) == "number" then
				str = sfmt("%3d", val)
			else
				str = tostring(val)
			end

			table.insert(tstr, str)
		end
		print(table.concat(tstr, ", "))
		for i = 1, #tstr do tstr[i] = nil end
	end
end --}}}
	
function f:new(...)
	local t = {eid = {count = -1}}
	for i = 1, select("#", ...) do
		local li = select(i, ...)
		t[li] = {}
	end
	return setmetatable(t, {__index = m})
end
return setmetatable(f, {__call = f.new})
