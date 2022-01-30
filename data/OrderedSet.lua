--------------------------------------------------------------------------------
---------------------- ##       #####    #####   ######  -----------------------
---------------------- ##      ##   ##  ##   ##  ##   ## -----------------------
---------------------- ##      ##   ##  ##   ##  ######  -----------------------
---------------------- ##      ##   ##  ##   ##  ##      -----------------------
---------------------- ######   #####    #####   ##      -----------------------
----------------------                                   -----------------------
----------------------- Lua Object-Oriented Programming ------------------------
--------------------------------------------------------------------------------
-- Project: LOOP Class Library                                                --
-- Release: 2.3 beta                                                          --
-- Title  : Ordered Set Optimized for Insertions and Removals                 --
-- Author : Renato Maia <maia@inf.puc-rio.br>                                 --
-- Updated: 0.1.0 by Scott Smith                                              --
--------------------------------------------------------------------------------
-- v0.1.0 - Updated to modern Lua                                             --
--------------------------------------------------------------------------------
-- Notes:                                                                     --
--   Storage of strings equal to the name of one method prevents its usage.   --
--------------------------------------------------------------------------------
local newproxy = newproxy and newproxy or function () return {} end
local next, type = next, type
local setmetatable = setmetatable

--------------------------------------------------------------------------------
-- key constants ---------------------------------------------------------------
--------------------------------------------------------------------------------

local FIRST = newproxy()
local LAST = newproxy()

--------------------------------------------------------------------------------
-- basic functionality ---------------------------------------------------------
--------------------------------------------------------------------------------

local m = {}

local function iterator(self, previous)
	return self[previous], previous
end

function m.sequence(self)
	return iterator, self, FIRST
end

function m.contains(self, element)
	return element ~= nil and (self[element] ~= nil or element == self[LAST])
end
local contains = m.contains

function m.first(self)
	return self[FIRST]
end

function m.last(self)
	return self[LAST]
end

function m.isempty(self)
	return self[FIRST] == nil
end

function m.insert(self, element, previous)
	if element ~= nil and not contains(self, element) then
		if previous == nil then
			previous = self[LAST]
			if previous == nil then
				previous = FIRST
			end
		elseif not contains(self, previous) and previous ~= FIRST then
			return
		end
		if self[previous] == nil
			then self[LAST] = element
			else self[element] = self[previous]
		end
		self[previous] = element
		return element
	end
end

function m.previous(self, element, start)
	if contains(self, element) then
		local previous = (start == nil and FIRST or start)
		repeat
			if self[previous] == element then
				return previous
			end
			previous = self[previous]
		until previous == nil
	end
end

function m.remove(self, element, start)
	local prev = previous(self, element, start)
	if prev ~= nil then
		self[prev] = self[element]
		if self[LAST] == element
			then self[LAST] = prev
			else self[element] = nil
		end
		return element, prev
	end
end

function m.replace(self, old, new, start)
	local prev = previous(self, old, start)
	if prev ~= nil and new ~= nil and not contains(self, new) then
		self[prev] = new
		self[new] = self[old]
		if old == self[LAST]
			then self[LAST] = new
			else self[old] = nil
		end
		return old, prev
	end
end

function m.pushfront(self, element)
	if element ~= nil and not contains(self, element) then
		if self[FIRST] ~= nil
			then self[element] = self[FIRST]
			else self[LAST] = element
		end
		self[FIRST] = element
		return element
	end
end

function m.popfront(self)
	local element = self[FIRST]
	self[FIRST] = self[element]
	if self[FIRST] ~= nil
		then self[element] = nil
		else self[LAST] = nil
	end
	return element
end

function m.pushback(self, element)
	if element ~= nil and not contains(self, element) then
		if self[LAST] ~= nil
			then self[ self[LAST] ] = element
			else self[FIRST] = element
		end
		self[LAST] = element
		return element
	end
end

--------------------------------------------------------------------------------
-- function aliases ------------------------------------------------------------
--------------------------------------------------------------------------------

-- set operations
m.add = m.pushback

-- stack operations
m.push = m.pushfront
m.pop = m.popfront
m.top = m.first

-- queue operations
m.enqueue = m.pushback
m.dequeue = m.popfront
m.head = m.first
m.tail = m.last

--m.firstkey = FIRST

local function new()
	return setmetatable({}, {__index = m})
end

--copy functions over to maintain exising compatability
local f = {}
for k,v in next, m do
	if type(v) == "function" then
		f[k] = v
	end
end
f.new = new

return setmetatable(f, {__call = new})
