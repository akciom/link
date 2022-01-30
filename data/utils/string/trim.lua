
--http://lua-users.org/wiki/StringTrim
local match = string.match

local function trim(s)
	if not s then return end
	return match(s,'^()%s*$') and '' or match(s,'^%s*(.*%S)')
end

return trim
