--Copyright 2020 -- Scott Smith --

local setmetatable = setmetatable
local type, select
	= type, select

local m = {}

function m:new() local list = self
	local last = self.last
	local max = self.max

	local next_entity_idx
	for i = last + 1, max do
		if not list[i] or list[i] == 0 then
			next_entity_idx = i
			break
		end
	end
	if not next_entity_idx then
		next_entity_idx = max + 1
		self.max = max + 1
	end
	list[next_entity_idx] = true

	self.last = next_entity_idx

	return next_entity_idx
end

function m:add_existing(...) local list = self
	local arr_max = 0
	local length
	local select = select
	local arr = select(1, ...)
	if type(arr) == "table" then
		length = #arr
		select = function (idx) return arr[idx] end
	elseif type(arr) == "number" then
		length = select("#", ...)
	else
		--This isn't enforced once the array is processed, but I don't care.
		--Entities can be other types, but with undefined behavior.
		return nil, "invalid type, must pass number or table"
	end

	for i = 1, length do
		local eid = select(i, ...)
		if eid > arr_max then
			arr_max = eid
		end
		list[eid] = true
	end

	if arr_max > list.max then
		list.max = arr_max
	end
	return true
end

--convert an existing component's ids to newly generated ids
--great for reusing generic components
function m:convert(component, new)
	local eid = component.eid
	local pid = component.pid
	if not eid or not pid then
		return nil, "invalid component, missing eid or pid"
	end
	if not new or new.type ~= "component" or not new.eid or not new.pid then
		return nil, "invalid new component, unable to generate ids"
	end
	local neid = new.eid
	local npid = new.pid
	for i = 1, #eid do
		npid[i] = 0
	end
	for i = 1, #eid do
		local nid = self:new()
		neid[i] = nid
		for k = 1, #eid do
			if pid[k] == eid[i] then
				npid[k] = nid
			end
		end
	end
	--make sure neid table is same length as eid table
	for i = #eid + 1, #neid do
		neid[i] = nil
	end

	local zero
	for i = 1, #npid do
		if npid[i] == 0 then
			if zero then
				return nil, "only one entity with parent id equal to 0 allowed"
			end
			zero = true
		end
	end
	return new
end

function m:remove()
	error("not implimented")
end

local f = {}
function f.new()
	local entity_list = {}
	entity_list.last = 0
	entity_list.max = 0
	return setmetatable(entity_list, {__index = m})
end

return setmetatable(f, {__call = f.new})
