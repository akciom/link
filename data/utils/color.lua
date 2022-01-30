--Copyright 2021 Scott Smith
--
--Simply converts hex strings to floating point rgba values and back

local tonumber = tonumber
local floor = math.floor
local sfmt = string.format
local sfind = string.find 

local find_str = "^#?(%x%x)(%x%x)(%x%x)(%x?%x?)$"

local FF_inv = 1.0/0xff


local function hex2rgba(str)
	local s, e, r, g, b, a = sfind(str or "", find_str)
	if not s then return end

	return
		         tonumber(r, 16) * FF_inv,
		         tonumber(g, 16) * FF_inv,
		         tonumber(b, 16) * FF_inv,
		#a>0 and tonumber(a, 16) * FF_inv or nil
end

local function rgba2hex(r,g,b,a)
    return sfmt("#%02X%02X%02X",
        floor(r * 0xff + 0.5),
        floor(g * 0xff + 0.5),
		floor(b * 0xff + 0.5)) ..
		(a and sfmt("%02X", floor(a * 0xff + 0.5)) or "")
end

return {
	hex2rgba = hex2rgba,
	rgba2hex = rgba2hex
}
