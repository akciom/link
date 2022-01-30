local VERSION = "alpha-0"

local tinsert, tconcat, tremove = table.insert, table.concat, table.remove
local ssub, sfind = string.sub, string.find

local floor = math.floor

local cmd = require "commands"

local lg = love.graphics


-- {{{ LPEG Functions
--local lP, lS, lR,
--      lC, lCt, lCs, lCp,
--	  lmatch, lV
--    = lpeg.P, lpeg.S, lpeg.R,
--	  lpeg.C, lpeg.Ct, lpeg.Cs, lpeg.Cp,
--	  lpeg.match, lpeg.V

--local getescape = setmetatable({
--	t = "\t",
--	v = "\v",
--	r = "\r",
--	n = "\n",
--	e = "\27", --ESC (escape)
--},
--{__call = function (self, esc_char)
--	return self[esc_char] or false
--end})

--local backslash = lP"\\"
--local escseq = backslash * lC(lP(1)) / getescape
--local newline = lP"\r\n" + lS"\r\n"
--local htab = lP"\t"
--local vtab = lP"\v"
--local escape = lP"\27"

--local escbyte = escseq + newline + htab + vtab + escape

--uses lpeg
--local function format(s, linewidth)
--local function getframebuffer(str, height)
--local function getcursoronstring(str)

local function format(s, linewidth)
	local I = lCp()
	local nl = lCs(newline/"")
	local line = lC((1 - nl)^-linewidth) * newline^-1
	local linenl = (nl + line) * I
	assert(s, "all commands must return a string (sysconsole)")
	local slen = #s

	local rt = {}

	local e = 1
	local m
	while e and e <= slen do
		m, e = lmatch(linenl, s, e)
		if m then
			tinsert(rt, m)
		end
	end

	local tlen = #rt
	return tconcat(rt, "\n")
end


--Basically at most height lines of formatted output.
--all output should've already been formatted

local function getframebuffer(str, height)
	local line = (1 - newline)^0 * newline^-1 * lCp()

	local col_count = {1}
	local cclen = 0
	local slen = #str
	local e = 1
	local m
	while e and e <= slen do
		e = lmatch(line, str, e)
		if e then
			cclen = cclen + 1
			col_count[cclen] = e
		end
	end
	local width = col_count[cclen] - col_count[cclen-1] + 1
	if cclen > height then
		local init = cclen - height
		return ssub(str, col_count[init]), height, width
	end
	return str, cclen, width
end

local function getcursoronstring(str)
	local slen = #str
	local e = 1
	local m
	local I = lCp()
	local line = (1 - newline)^0 * newline^-1 * I
	local lastline = lP(1) - (newline^-1 * I * (1 - newline)^0 * -1 )
	--x and y start at one. we always 
	local x, y = 1, 1
	while true do
		e = lmatch(line, str, e)
		if e and e < slen then
			y = y + 1
		else
			break
		end
	end
	local c = lmatch(lastline^0, str)
	x = x + slen - c
	return x, y
end

--}}}

--{{{ Functions; addBufferLine

local function addBufferLine(buffer, str)
	buffer.size = buffer.size + 1
	if buffer.size > buffer.maxsize then
		buffer.size = buffer.maxsize
		tremove(buffer, 1) --slow operation, but it might not matter
	end
	buffer[buffer.size] = str
	if buffer.selected_row then
		buffer.selected_row = buffer.size + 1
	end
end

--}}}

local function sysconsole(entity, dt)
	local ecomp = entity.component
	local console = ecomp.console
	if not console then return end

	--{{{ Initialize console if not done already
	if not console.version then
		--initialize(console)
		local ec = console
		do --load font
			local font = ec.font or lg.getFont()
			local cellheight = font:getHeight()
			local cellwidth
			if font:getWidth(".") == font:getWidth("W") then
				cellwidth = font:getWidth(".")
			else
				print("WARNING: Non-monospace fonts are not supported.")
				local lm, lw = font:getWidth("M"), font:getWidth("W")
				cellwidth = lm > lw and lm or lw
			end
			ec.font, ec.cellwidth, ec.cellheight =
			   font,    cellwidth,    cellheight
		end

		--magic number .5 is to reduce the 2x scale. this will break!
		--However, currently the console is always rendered at 2x scale
		do --resize terminal
			local w, h = lg.getDimensions()
			ec.termwidth =  floor(w * 0.5 / ec.cellwidth)
			ec.termheight = floor(h * 0.5 / ec.cellheight)
		end

		ec.buffer = {"Connected...", maxsize = 1000}
		--buffer maxsize must be at least termheight tall
		if ec.buffer.maxsize < ec.termheight then
			ec.buffer.maxsize = ec.termheight
		end
		ec.buffer.size = #ec.buffer

		ec.ibuffer = {selected_row = 1, size = 0, maxsize = 1000}
		ec.rawinput = {} --gets data from input system
		ec.version = VERSION
		ec.output = ""
		ec.input = ""
		ec.input_cursor = 1
		ec.cursor_x = 1
		ec.cursor_y = 1
		ec.prompt = "[ Prompt 9000 ] "
	end --}}}

	console.output = ""
	if ecomp._turnon then
		ecomp._turnon = nil --clear the variable (message)
		console.on = not console.on
	end
	if not console.on then return end

	--[ Console is on ]--

	--prerender output
	--draw on last line
	local output = {}
	local bufferstart = console.buffer.size - console.termheight
	if bufferstart < 1 then bufferstart = 1 end 
	for i = bufferstart, console.buffer.size do
		tinsert(output, format(console.buffer[i], console.termwidth))
		tinsert(output, "\n")
	end

	tinsert(output, console.prompt)
	--finds the cursor. Seems easy to break.
	console.cursor_x, console.cursor_y = getcursoronstring(tconcat(output))


	local input = console.input
	local icursor = console.input_cursor

	for i = 1, #console.rawinput do local cin = console.rawinput[i]
	if type(cin) == "string" then
		if #cin == 1 then
			local tail = ssub(input, icursor)
			input = tconcat{ssub(input, 1, icursor-1), cin, tail}
			icursor = icursor + 1
		elseif cin == "up" then
			local ib = console.ibuffer
			local selrow = ib.selected_row - 1
			if selrow < 1 then
				selrow = 1
			end
			input = ib[selrow] or ""
			ib.selected_row = selrow
			icursor = #input + 1
		elseif cin == "down" then
			local ib = console.ibuffer
			local selrow = ib.selected_row + 1
			if selrow > ib.size then
				selrow = ib.size + 1
				input = ""
			else
				input = ib[selrow]
			end
			ib.selected_row = selrow
			icursor = #input + 1
		elseif cin == "left" then
			icursor = icursor - 1
		elseif cin == "right" then
			icursor = icursor + 1
		elseif cin == "home" then
			icursor = 1
		elseif cin == "end" then
			icursor = #input + 1
		end
	elseif type(cin) == "number" then
		local char
		if cin == 0x08 then --backspace
			icursor = icursor - 1
			if input then
				local tail = ssub(input, icursor+1)
				input = ssub(input, 1, icursor-1)..tail
			end
		elseif cin == 0x0a then --newline
			--need to process commands here
			--The buffer size should be updated when the buffer is,
			--with a function
			addBufferLine(console.buffer, console.prompt..input)
			addBufferLine(console.ibuffer, input)
			addBufferLine(console.buffer, cmd.execute(input))
			input = ""
			icursor = 1
		elseif cin == 0x7f then --delete
			--cursor stays in the same position
			if input then
				local tail = ssub(input, icursor+1)
				input = ssub(input, 1, icursor-1)..tail
			end
		end
		if char then
		end
	end end

	if icursor < 1 then icursor = 1 end
	local maxlen = #input + 1
	if icursor > maxlen then icursor = maxlen end
	console.input_cursor = icursor

	console.rawinput = {}
	local inputlen = #input
	console.input = input

	tinsert(output, format(input, console.termwidth - console.cursor_x))
	do -- getframebuffer
		--local function getframebuffer(str, height)
		--console.output, console.cursor_y, console.cursor_x =
		--	getframebuffer(tconcat(output), console.termheight)
		--USES LPEG
		local str = tconcat(output)
		local height = console.termheight

		local line = (1 - newline)^0 * newline^-1 * lCp()

		local col_count = {1}
		local cclen = 0
		local slen = #str
		local e = 1
		local m
		while e and e <= slen do
			e = lmatch(line, str, e)
			if e then
				cclen = cclen + 1
				col_count[cclen] = e
			end
		end
		local width = col_count[cclen] - col_count[cclen-1] + 1
		if cclen > height then
			local init = cclen - height
			return ssub(str, col_count[init]), height, width
		end

		console.output, console.cursor_y, console.cursor_x =
		           str,            cclen,            width
	end

	local curdiff = icursor-1 - inputlen
	local cx = console.cursor_x + curdiff
	--This doesn't work for more than two lines
	if cx < 1 then
		console.cursor_y = console.cursor_y - 1
		cx = cx + console.termwidth - 1
	end
	console.cursor_x = cx
end

return sysconsole
