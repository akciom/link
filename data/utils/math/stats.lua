local sqrt = math.sqrt

local function average(list)
	local count = list.count or #list or 0
	local sum = 0
	for i = 1, count do
		sum = sum + list[i]
	end
	return sum / count
end

local function stddev(list, avg)
	avg = avg or average(list)
	local sum = 0
	local count = list.count or #list or 0
	for i = 1, count do
		local diff = list[i] - avg
		sum = sum + diff * diff
	end
	return sqrt(sum / count)
end

return {
	average = average,
	stddev = stddev,
}
