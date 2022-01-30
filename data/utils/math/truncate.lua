local ceil, floor = math.ceil, math.floor

local function truncate(num)
	if num < 0 then
		return ceil(num)
	end
	return floor(num)
end

return truncate
