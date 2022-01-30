--[[ Akciom's Flavor of INI Parser 
--TODO: Should store all warnings for main application to play back
--TODO: Store every line for writing back.
--      Compiler should only change values, keeping comments intacked.
--      Documentation comments that can be updated could handle user changes.
--]]
local f = {}

local tonumber, next, type, io, table, string
	= tonumber, next, type, io, table, string
local print = print
local error = nil
local sfmt = string.format
local tabcat = table.concat

f._VERSION = "INI 0.6.3"

local function lines(str)
	return string.gmatch(str, "[^\r\n]*")
end

function f.parse(inistr, name)
	name = name or "line"
	--stores all the sections key-value pairs
	local t = {}
	local section = "" -- default section
	local subsection = false
	--When slurp-key is set 
	local slurp_key = false
	local slurp_text = {count = 0}
	local slurp_comment = false
	local linenum = 0
	t[section] = {}
	for line in lines(inistr) do
		linenum = linenum + 1

		local tss = t[section]
		if subsection then
			tss = tss[subsection]
		end

		--grab each line and store it in the table t
		if slurp_key then
			--looks for ending pattern of multi-line text
			local pattern_found = false
			if line:find("^%s*%]%]%s*$") then
				printf(
					"%s:%d WARN: %s.%s: use of ]] is deprecated. Use ]]].",
					name, linenum, section, slurp_key
				)
				pattern_found = true
			end
			if line:find("^%s*%]%]%]%s*$") or pattern_found then
				--found end pattern, text collection is done
				if not slurp_comment and slurp_text.count >= 1 then
					local j = slurp_text.count
					local text = tabcat(slurp_text, "\n", 1, j)
					--trim whitespace <http://lua-users.org/wiki/StringTrim> (trim6)
					text = text:match("^()%s*$") and "" or text:match("^%s*(.*%S)")
					tss[slurp_key] = text
				end
				slurp_text.count = 0
				slurp_comment = false
				slurp_key = false
			elseif not slurp_comment then
				--newline
				if line:find("^%s*$") then
					line = "\n"
				end
				slurp_text.count = slurp_text.count + 1
				slurp_text[slurp_text.count] = line
			end
		elseif #line > 0 then
			local new_section, new_subsec = line:match(
				"^%[%s*([%w_]+)%.?([%w_]*)%s*%]%s*$"
			)
			if new_subsec and #new_subsec == 0 then new_subsec = false end

			local comment, k, v
			if not new_section then
				comment, k, v = line:match("^%s*(;?)%s*([%w_]+)%s*=%s*(.-)%s*$")
				comment = comment == ";"
			end

			if new_section then
				if section ~= new_section or not new_subsec then
					--t[new_section] will never == false, but for consitency sake
					--test for nil here as well as t[new_section][new_subsec]
					if type(t[new_section]) ~= "nil" then
						return nil, sfmt(
							"%s:%d Duplicate section header: %s",
							name, linenum, new_section
						)
					end
					section = new_section
					t[section] = {}
				end
				if new_subsec then
					--t[section][subsec] could have matching key == false
					--ie. t[section][k] = false
					if type(t[new_section][new_subsec]) ~= "nil" then
						return nil, sfmt(
							"%s:%d Duplicate section header: %s.%s",
							name, linenum, section, new_subsec
						)
					end
					subsection = tonumber(new_subsec) or new_subsec
					t[section][subsection] = {}
				end
			elseif k and v then
				local num = tonumber(v)
				if num then
					v = num
				elseif v:find("^%[%[$") then
					printf(
						"%s:%d  WARN: %s.%s: use of [[ is deprecated. Use [[[.",
						name, linenum, section, k
					)
					--deprecation so it doesn't confuse with behavior of
					--Lua's string type.
					slurp_key = k
				elseif v:find("^%[%[%[") then
					--multi-line text found
					--Currenly only support the opening braces. Anything else
					--on the line should be considered invalid
					local s, e, option = v:find("^%[%[%[%s*(.+)%s*$")
					if not comment and option then
						printf(
				"%s:%d ERROR: in %s.%s: block text options are not supported",
							name, linenum, section, k, option
						)
						comment = true
					end
					slurp_key = k
					slurp_comment = comment
				else
					local vtl = string.lower(v)
					if vtl == "true" then
						v = true
					elseif vtl == "false" then
						v = false
					end
				end

				if not slurp_key and not comment then
					tss[k] = v
				end
			elseif not line:find("%s*;") then
				--garbage data. Should at least warn
				printf("%s:%d  WARN: Invalid:\n> \"%s\"", name, linenum, line)
			end
		end
	end
	return t
end

function f.write(dest, ini)
	error("this write function is garbage and should never be used.")
	if type(dest) ~= "string" then return false end
	if type(ini) ~= "table" then return false end
	local f = io.open(dest, "w")
	local section_written = false
	local base = ini[""]
	ini[""] = nil

	if type(base) == "table" then
		for k,v in next, base do
			local prefix, postfix = "", ""
			section_written = true
			if type(v) == "string" and v:find("[\r\n]+") then
				--TODO:should also make sure v doesn't contain the postfix
				prefix, postfix = "[[[\n", "\n]]]"
			end
			f:write(sfmt("%s = %s%s%s\n", k, prefix, v, postfix))
		end
	end
	for k,v in next, ini do
		if k ~= "" then
			local prefix, postfix = "", ""
			if section_written then f:write("\n") end
			f:write(sfmt("[%s]\n", k))
			for k2, v2 in next, v do
				section_written = true
				if type(v2) == "string" and v2:find("[\r\n]+") then
					prefix, postfix = "[[[\n", "\n]]]"
				end
				f:write(sfmt("%s = %s%s%s\n", k2, prefix, v2, postfix))
			end
		end
	end
	f:close()

	return true
end

return f
