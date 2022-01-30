local sfmt = string.format
local ceil = math.ceil
local min = math.min
--local ti = table.insert
local tcat = table.concat
local select = select
--local iowrite = io.write
local iowrite = function() end

local t = {}
local t_count = 0

local iow = function (...)
	for i = 1, select("#", ...) do
		local s = select(i, ...)
		t_count = t_count + 1
		t[t_count] = s
		--ti(t, s)
	end
	iowrite(...)
end

local function align(n)
	return ceil(n / 16) * 16
end

local function hex_dump(buf, first, last)
	first = first or 1
	last = last or #buf
	t_count = 0
	for i = align(first - 16) + 1, align(min(last, #buf)) do
		if (i-1) % 16 == 0 then iow(sfmt("%08X  ", i-1)) end
		iow( i > #buf and "   " or sfmt("%02X ", buf:byte(i)) )
		if i %  8 == 0 then iow(" ") end
		if i % 16 == 0 then iow(buf:sub(i-16+1, i):gsub("%c","."),"\n") end
	end
	return tcat(t, "", 1, t_count)
end

return hex_dump
