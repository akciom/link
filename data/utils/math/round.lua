local ceil, floor = math.ceil, math.floor

local function round(num)
	if num < 0 then
		return ceil(num - 0.5)
	end
	return floor(num + 0.5)
end

return round
