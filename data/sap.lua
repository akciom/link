--------------------------------------------------------------------------------
-- SAP Library -- String Argument Parser
-- Copyright 2020 - Scott Smith
--------------------------------------------------------------------------------

local _VERSION = "SAP 0.4.0-alpha.1"

--local _

local sfind = string.find
local ssub = string.sub
local sfmt = string.format
local tostring, type, select, error, table, setmetatable
    = tostring, type, select, error, table, setmetatable

local function replace_variable(str, pos, replacement_data) --{{{
	--find short version of string func
	local _, e, match = sfind(str, "^([%w_]+)", pos)
	if not match then
		--try long version of string func
		_, e, match = sfind(str, "^%[([%w_]*)%]", pos)
	end
	if match then
		local replacement = replacement_data and replacement_data[match]
		if not replacement then
			return "", e+1
		else
			return tostring(replacement), e+1
		end
	end

	error("invalid string replacement ".. str:sub(pos, pos + 10))
end --}}}

local find_next_special do --{{{
	local pattern_memo = {}

function find_next_special(str, pos, pat)
	local findpattern = pattern_memo[pat]
	if not findpattern then
		local pre, post = "^([^", "]*)"
		local ti = table.insert
		local pattern = {pre}

		--escapes non-alphanumeric characters
		--alphanumeric are turned into character classes
		--undefined if a character class doesn't exist for alphanumeric
		for i = 1, #pat do
			ti(pattern, "%")
			ti(pattern, pat:sub(i, i))
		end
		ti(pattern, post)

		findpattern = table.concat(pattern)
		pattern_memo[pat] = findpattern
	end
	local s, e, match = sfind(str, findpattern, pos)
	return match, e+1
end end --}}}

local function Stack() --{{{
return setmetatable({poptable = {}, count = 0}, {__index = {
	push = function(self, ...)
		for i = 1, select("#", ...) do
			local item = select(i, ...)
			if item then
				local c = self.count + 1
				self.count = c
				self[c] = item
			end
		end
	end,
	pop = function(self, num)
		if not num or num == 1 then
			local c = self.count - 1
			if c < 0 then
				return
			end
			self.count = c
			return self[c+1]
		elseif type(num) == "number" then
			local c = self.count
			local t = self.poptable --reusing to save allocations
			local popc = 0
			for i = 1, num do
				c = c - 1
				if c < 0 then
					break
				end
				t[i] = self[c+1]
				popc = i
			end
			return unpack(t, 1, popc)
		end
	end,
}})
end --}}}

local function escape_char(specials, str, pos)
	local sc = ssub(str, pos, pos)
	return specials[sc] or "", pos+1
end

local special_base = {
	["n"] = "\n",
	["r"] = "\r",
	["t"] = "    ",
	["\\"] = "\\\\",

	[" "] = " ",
	["$"] = "$",
	["\""] = "\"",
	["'"] = "'",
}

local special_double = {
	["n"] = "\n",
	["r"] = "\r",
	["t"] = "    ",
	["\\"] = "\\\\",

	["\""] = "\"",
	["$"] = "$",
}


local function sap(_, str, replacement_data, pos)
	if type(str) ~= "string" then
		error(sfmt("arg1 must be a string, not a \"%s\"", type(str)), 2)
	end
	local _ _, pos = string.find(str, "^%s*", pos or 1)
	pos = pos + 1
	if pos > #str then return end

	local parsed = Stack()
	while true do
		if pos > #str then
			if parsed.count == 0 then pos = nil end
			break
		end
		local pstr pstr, pos = find_next_special(str, pos, "\\$'\"s")
		parsed:push(pstr) pstr = nil
		--print(table.concat(parsed))

		if     sfind(str, "^\\", pos) then
			pstr, pos = escape_char(special_base, str, pos+1)
		elseif sfind(str, "^%$", pos) then
			pstr, pos = replace_variable(str, pos+1, replacement_data)
		elseif sfind(str, "^'", pos) then
			pstr, pos = find_next_special(str, pos+1, "'")
			pos = pos + 1 --skip ending single quote
		elseif sfind(str, "^\"", pos) then
-- Double Quote ----------------------------------------------------------------
		pos = pos + 1
		while true do
			local pstr pstr, pos = find_next_special(str, pos, "\\$\"")
			parsed:push(pstr) pstr = nil

			if     sfind(str, "^\\", pos) then
				pstr, pos = escape_char(special_double, str, pos+1)
			elseif sfind(str, "^%$", pos) then
				pstr, pos = replace_variable(str, pos+1, replacement_data)
			elseif sfind(str, "^\"", pos) then
				pos = pos + 1
				break
			end
			parsed:push(pstr)
		end
--------------------------------------------------------------------------------
		elseif sfind(str, "^%s", pos) then
			pos = pos + 1
			break
		end
		parsed:push(pstr)
	end
	if parsed.count == 0 then
		return pos
	else
		return pos, table.concat(parsed, "", 1, parsed.count)
	end
end

return setmetatable({}, {
	__call = sap,
	__index = {
		loop = function(str, replacement_data)
			return function(str, pos)
				return sap(nil, str, replacement_data, pos)
			end, str, 1
		end,
	},
})
