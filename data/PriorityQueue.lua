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
-- Title  : Priority Queue Optimized for Insertions and Removals              --
-- Author : Renato Maia <maia@inf.puc-rio.br>                                 --
-- Updated: 0.1.0 by Scott Smith                                              --
--------------------------------------------------------------------------------
-- v0.1.0 - Updated to modern Lua                                             --
--------------------------------------------------------------------------------
-- Notes:                                                                     --
--   Storage of strings equal to the name of one method prevents its usage.   --
--------------------------------------------------------------------------------
local setmetatable = setmetatable

local OrderedSet = require "OrderedSet"

--------------------------------------------------------------------------------
-- internal constants ----------------------------------------------------------
--------------------------------------------------------------------------------

local PRIORITY = {}

--------------------------------------------------------------------------------
-- basic functionality ---------------------------------------------------------
--------------------------------------------------------------------------------

local m = {}

-- internal functions
local function getpriorities(self)
	if not self[PRIORITY] then
		self[PRIORITY] = {}
	end
	return self[PRIORITY]
end
local function removepriority(self, element)
	if element then
		local priorities = getpriorities(self)
		local priority = priorities[element]
		priorities[element] = nil
		return element, priority
	end
end

-- borrowed functions
for k,v in next, OrderedSet do
	m[k] = v
end
local sequence = OrderedSet.sequence
local contains = OrderedSet.contains
local isempty = OrderedSet.isempty
local head = OrderedSet.head
local tail = OrderedSet.tail

-- specific functions
function m.priority(self, element)
	return getpriorities(self)[element]
end

function m.enqueue(self, element, priority)
	if not contains(self, element) then
		local previous
		if priority then
			local priorities = getpriorities(self)
			for elem, prev in sequence(self) do
				local prio = priorities[elem]
				if prio and prio > priority then
					previous = prev
					break
				end
			end
			priorities[element] = priority
		end
		return OrderedSet.insert(self, element, previous)
	end
end

function m.dequeue(self)
	return removepriority(self, OrderedSet.dequeue(self))
end

function m.remove(self, element, previous)
	return removepriority(self, OrderedSet.remove(self, element, previous))
end

local function new()
	return setmetatable({}, {__index = m})
end

return setmetatable({new = new}, {__call = new})
