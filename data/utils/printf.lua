local iowrite, sfmt = io.write, string.format

local function printf(...)
	return iowrite(sfmt(...))
end

return printf
