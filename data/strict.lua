-- Copyright 2020 -- Scott Smith --
-- MIT License
--------------------------------------------------------------------------------
-- strict.lua
-- Prevents all variables in a table from being set without the use of a
-- setter (a special variable of the table). If a variable has not been
-- intialized, it will throw an error when accessed. 
--
-- Will not work with tables that use metatables.
--
-- Usage:
--     require"strict"("export", _G)
--     --newglobal = "this would throw an error"
--     --table = "as will this"
--
--     export. newglobal = "I've just initialized and set a global variable!"
--     export. table = "this works just fine"
--
--     --Lock any table
--     local newtable = {}
--     require"strict"("set", newtable)
--     newtable.error = 1        --this will fail
--     newtable.set.error = 1    --but this will not
--
--     print(newtable.error)     --prints: 1
--------------------------------------------------------------------------------
local getmetatable, setmetatable = getmetatable, setmetatable
local error, debug = error, debug
local next, strfmt, type = next, string.format, type

local _VERSION = "Strict 0.9.0"

local function strict(settername, tbl)
	if type(settername) ~= "string" then
		error("The variable setter (arg1) must be a string.", 2)
	end
	if type(tbl) ~= "table" then
		error("No table (arg2) to lock.", 2)
	end
	if getmetatable(tbl) then
		error("No support for metatables. Cannot lock table.", 2)
	end
	if tbl[settername] ~= nil then
		error(strfmt(
			"Strict setter \"%s\" has previously been set!", settername), 2)
	end

	local index = {}
	local index_si = {} --index's strict index (if it's set, true)
	for k,v in next, tbl do
		index_si[k] = true
		index[k] = v
		tbl[k] = nil
	end

	index_si[settername] = true
	index[settername] = setmetatable({},{
		__call = function(_, cmd, key)
			if cmd == "version" then return _VERSION end
			if cmd == "check" and key then return index_si[key], index[key] end
			if cmd == "clear" and key == "all" then
				local setter = index[settername]
				index_si = {[settername] = true}
				index = {[settername] = setter}
				return true
			end
		end,
		__newindex = function(_, key, value)
			if key == settername then
				error("Cannot change strict setter variable once set", 2)
			end
			if value == nil then
				index_si[key] = nil
			else
				index_si[key] = true
			end
			index[key] = value
		end,
		__index = function(_, key)
			error(strfmt(
				"What are you trying to do? \"%s\" is not getter.",
				settername), 2)
		end,
	})

	local meta = {
	__newindex = function(_, key, value)
		error(debug.traceback(strfmt(
			"Table locked! Must set variable \"%s\" with setter: \"%s\"",
			key, settername) , 2), 2)
	end,
	__index = function (_, k)
		if index_si[k] then
			return index[k]
		end
		error(strfmt("The strict variable \"%s\" was not initialized!", k),  2)
	end
	}
	setmetatable(tbl, meta)

	return index[settername]
end

return setmetatable({}, {
	__call = function(_, sname, tbl, set) return strict(sname, tbl, set) end,
	__index = { _VERSION = _VERSION }
})
