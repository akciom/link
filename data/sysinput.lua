-- Copyright 2020 -- Scott Smith --

local keys2 = keys2
local keys = keys2.keys

local vec = require "Vector"

local input = {_VERSION = "SysInput 0.5.0",
	count = 0, sidx = 0, bind = {},
	edit_mode_enabled = false,
	text = "",
	edit = {count = 0},
}
--{{{ setting up hal.input metatable
local hal = hal
local input_key_lookup = {
	mouse = true, gpaxis = true, _VERSION = true, initialize = true,
	edit_mode = true, focus_clickthrough = true, text = true,
	processed = true, edit = true,
}
hal.input = setmetatable({}, {
	__index = function(self, key)
		if input_key_lookup[key] then
		--if  key == "mouse" or
		--	key == "gpaxis" or
		--	key == "_VERSION" or
		--	key == "initialize" or
		--	key == "edit_mode" or
		--	key == "focus_clickthrough" or
		--	key == "text"
		--then
			return input[key]
		end
		for i = 0, input.count-2, 2 do
			local ikey = input[i+1]
			if ikey == key then
				return input[i+2]
			end
		end
	end,
	__newindex = function(self, key, value)
		if key == "text" then
			input[key] = value
			return
		elseif key == "processed" then
			input[key] = value
			return
		end
		error("cannot set input variables", 2)
	end,
})--}}}

local setmetatable, type, rawget
	= setmetatable, type, rawget
local sfmt = string.format

do --{{{ MOUSE FOCUS CLICKTHROUGH
	--Thanks to slime and zorg on the LÖVE discord server
	local ffi = require("ffi")
	local sdl = ffi.os == "Windows" and ffi.load("SDL2") or ffi.C

	if not hal_defined.sdl_sethint then
		hal_defined.sdl_sethint = true
		ffi.cdef[[
		typedef enum SDL_bool {
			   SDL_FALSE = 0,
			   SDL_TRUE  = 1
		} SDL_bool;

		SDL_bool SDL_SetHint(const char *name,
							 const char *value);
		]]
	end

	--sdl.SDL_SetHint("SDL_MOUSE_FOCUS_CLICKTHROUGH", "1")
	function input.focus_clickthrough(enable)
		local value = "0"
		if enable then
			value = "1"
		end
		local ret = sdl.SDL_SetHint("SDL_MOUSE_FOCUS_CLICKTHROUGH", value)
		return (ret == sdl.SDL_TRUE)
	end
end--}}}
--------------------------------------------------------------------------------
--  KEYBINDING
--
--  This should probably be separated into another file at some point
--------------------------------------------------------------------------------
local keybind = {
global = { --{{{
	--DEBUG KEYS
	--["end"] = function()error("HALT_THE_GAME_PLEASE")end,
	--["home"]  = "debug_menu",

	--UNKNOWN KEYS
	["space"]  = "jump",
	["return"] = "pause",
	["lshift"] = "shift",
	["rshift"] = "shift",
	["delete"] = "delete",



--[[{{{ example usage of mouse_click in game:
	if input.mouse_click then
		print("mouse_click is down")
	elseif input.mouse_click == "pressed" then
		print("mouse_click has just been pressed")
	elseif not input.mouse_click then
		print("mouse_click has been or is released")
	end
--}}}]]
	["pressed1"] = {"pressed", "mouse_click"},
	["released1"] = {"released", "mouse_click"},
	["pressed2"] = {"pressed", "mouse_menu"},
	["released2"] = {"released", "mouse_menu"},
	["pressed3"] = {"pressed", "mouse_middle"},
	["released3"] = {"released", "mouse_middle"},
}, --}}}
}

local words_to_symbols = { --{{{
	zero = "0",
	one = "1",
	two = "2",
	three = "3",
	four = "4",
	five = "5",
	six = "6",
	seven = "7",
	eight = "8",
	nine = "9",
	exclamation = "!",
	double_quote = "\"",
	hash = "#",
	dollar = "$",
	ampersand = "&",
	single_quote = "'",
	left_parenthesis = "(",
	right_parenthesis = ")",
	astrisk = "*",
	plus = "+",
	comma = ",",
	minus = "-",
	period = ".",
	slash = "/",
	colon = ":",
	semicolon = ";",
	less_than = "<",
	equal = "=",
	greater_than = ">",
	question = "?",
	at = "@",
	left_square_bracket = "[",
	backslash = "\\",
	right_square_bracket = "]",
	caret = "^",
	underscore = "_",
	grave_accent = "`",

	kp_decimal = "kp.",
	kp_comma = "kp,",
	kp_divide = "kp/",
	kp_multiply = "kp*",
	kp_subtract = "kp-",
	kp_add = "kp+",
	kp_equals = "kp=",
	kp_enter = "kpenter",
} --}}}

function hal.input_load_bindings(bind)
	local warning = false
	local loading_str = "Loading Key Bindings..."
	printf(loading_str)
	input.bind = {global = {}}
	local ib = input.bind
	for k,v in next, bind.global do
		local symbol = words_to_symbols[k]
		if symbol then
			bind.global[k] = nil
			bind.global[symbol] = v
		end
	end
	for k,v in next, keybind.global do
		if bind.global and bind.global[k] then
			local default_global = v
			local new_global = bind.global[k]
			if type(default_global) == "table" then
				default_global = sfmt("{%s, %s}", v[1], v[2])
			end
			if type(new_global) == "table" then
				new_global = sfmt("{%s, %s}", new_global[1], new_global[2])
			end
			if default_global ~= new_global then
				printf("\nWARNING: overwriting global keybind '%s' from '%s' to '%s'", k, default_global, new_global)
				warning = true
			end
		else
			ib.global[k] = v
		end
	end
	for ksec,vtab in next, bind do
		local ibk = ib[ksec] or {}
		ib[ksec] = ibk
		for k,v in next, vtab do
			ibk[k] = v
		end
	end
	if warning then
		printf("\n%s", loading_str)
	end
	printf("done\n")
end

--keybindings
local function modifier(mtype)
	--need to be able to bind everything.
	--in windows lctrl is correctly reported (as capslock on my system)
	--in linux lctrl is still reported as the key on the keyboard
	--so in linux I need to use keys.capslock rather than keys.lctrl
	if     mtype == "ctrl" and (keys.lctrl or keys.rctrl) then return true
	elseif mtype == "alt" and (keys.lalt or keys.ralt) then return true
	elseif mtype == "shift" and (keys.lshift or keys.rshift) then return true
	--annoyingly, gui is used for command in apple (normally treated as CTRL)
	--is treated as the Windows key in windows (probably meta key in Linux)
	elseif mtype == "gui" and (keys.lgui or keys.rgui) then return true
	end
end

do --{{{ ( keybind.global; mouse, wheel, and gamepad functions )
	local svec do
		local ffi = require "ffi"
		if not hal_defined.twovector2 then
			hal_defined.twovector2 = true
			ffi.cdef[[
			struct twovector2 {
				struct vector2 absolute;
				struct vector2 relative;
				struct vector2 wheel;
			};]]
		end
		svec = ffi.new(ffi.typeof("struct twovector2"))
	end
	input["mouse"] = svec

	local axisvec do
		local ffi = require "ffi"
		if not hal_defined.axisvec then
			hal_defined.axisvec = true
			ffi.cdef[[
			struct axisvec {
				struct vector2 left_stick;
				struct vector2 right_stick;
				double left_trigger, right_trigger;
			};]]
		end
		axisvec = ffi.new(ffi.typeof("struct axisvec"))
	end
	input["gpaxis"] = axisvec

	function keybind.global.moved(dt, x, y, dx, dy)
		svec.absolute.x = x or 0
		svec.absolute.y = y or 0
		svec.relative.x = dx or 0
		svec.relative.y = dy or 0
	end

	function keybind.global.wheel(dt, x, y)
		svec.wheel.x = svec.wheel.x + x
		svec.wheel.y = svec.wheel.y + y
	end

	--TODO:how can I turn input.gpaxis.left_stick.x to something more pleasing
	--like in keybind.cfg (gp1_leftx = move_x)
	function keybind.global.axis(dt, id, axis, value)
		if axis == "gp1_leftx" then
			axisvec.left_stick.x = value
		elseif axis == "gp1_lefty" then
			axisvec.left_stick.y = value
		elseif axis == "gp1_rightx" then
			axisvec.right_stick.x = value
		elseif axis == "gp1_righty" then
			axisvec.right_stick.y = value
		elseif axis == "gp1_triggerleft" then
			axisvec.left_trigger = value
		elseif axis == "gp1_triggerright" then
			axisvec.right_trigger = value
		end
	end
end
--}}}

function input.edit_mode(enabled)
	local enabled_type = type(enabled)
	if enabled_type == "nil" then
		return input.edit_mode_enabled
	elseif enabled_type == "boolean" then
		love.keyboard.setKeyRepeat(enabled)
		input.edit_mode_enabled = enabled
		return enabled
	else
		error("invalid input.edit_mode argument: ".. enabled_type)
	end
end

local function new_keypress(key)
	local c = input.count
	local si = input.sidx --start index
	local ptr
	if input.edit_mode_enabled then
		for i = 0, c, 2 do
			if input[i+1] == key then
				ptr = i
			end
		end
	end
	if not ptr then
		for i = si, c, 2 do
			if not input[i+1] then
				ptr = i
				si = i + 2
				input.sidx = si
				if i == c then input.count = si end
				break
			end
		end
	end

	input[ptr+1] = key
	input[ptr+2] = "pressed"
end

local function new_keyrelease(key)
	for i = 0, input.count-2, 2 do
		if input[i+1] == key then
			input[i+1] = false
			input[i+2] = false
			if input.sidx > i then input.sidx = i end
			break
		end
	end
end

local function new_keydown()
	local last_idx = -2
	for i = 0, input.count-2, 2 do
		if input[i+2] then
			last_idx = i
			input[i+2] = "down"
		end
	end
	--if input[i+2] is always false, count will be 0
	input.count = last_idx + 2
end

local function new_clearkeys()
	input.edit_mode(false)
	for i = 0, input.count-2, 2 do
		input[i+1], input[i+2] = false, false
	end
	input.count = 0
	input.sidx = 0
end
input.initialize = new_clearkeys

--{{{-[[ event handlers (keypress, keyrelease, mouseevent) ]]-------------------
local keydown = {count = 0} --happens as long as the key is pressed down
local mousedown = {count = 0}
local inputdown = {count = 0, startidx = 0}
-- inputdown[c+1] --> keybinding name
-- inputdown[c+2] --> downtime

local keypress = setmetatable({}, {__index = function(self, key)
	new_keypress(key)
end})
local keyrelease = setmetatable({}, {__index = function(self, key)
	new_keyrelease(key)
end})

local mouseevent = setmetatable({}, {__index = function(self, key)
	local ktype = type(key)
	if ktype == "function" then
		return key
	elseif ktype == "table" then
		local ev, ktype = key[1], key[2]
		if ev == "pressed" then
			new_keypress(ktype)
		elseif ev == "released" then
			new_keyrelease(ktype)
		end
		return
	end

	error(sfmt("unsupported mouseevent key type: %s; %s, %s",
		ktype, key[1], key[2]
	))
end})
--}}}

local function keyfunc(kev, ename, key, dt, ...)
	local kb = input.bind[ename][key]
	if not kb then return end
	if type(kb) == "function" then
		return kb(dt, ...)
	end
	local f = kev[kb] --kev are metatables which sets input
	if type(f) == "function" then f(dt, ...) end
end

local function system(dt)
	local edit_mode = input.edit_mode_enabled
	local in_bind = input.bind
	local input = hal.input

	local ename = "global"

	input.mouse.wheel.x, input.mouse.wheel.y = 0, 0
	new_keydown()



	do --{{{ process key/mouse events
		local k2t, kev = keys2.pressed, keypress
		for i = 1, k2t.count do
			keyfunc(kev, ename, k2t[i], dt)
		end

		k2t, kev = keys2.released, keyrelease
		for i = 1, k2t.count do
			keyfunc(kev, ename, k2t[i], dt)
		end

		k2t, kev = keys2.mouseevent, mouseevent
		local i = 0
		while i < k2t.count do
			local size
			local etype,    x,        y,        button_dx, dy
				= k2t[i+1], k2t[i+2], k2t[i+3], k2t[i+4]   --nil
			if etype == "moved" then
				size = k2t.size[etype]
				dy = k2t[i+size]
			elseif etype == "wheel" then
				button_dx = nil
				size = k2t.size[etype]
			else -- etype = pressed or released
				-- etype1  | Left Mouse Button.
				-- etype3  | Middle Mouse Button.
				-- etype2  | Right Mouse Button.
				-- etypen  | etc.
				size = k2t.size.button
				etype = etype..button_dx
			end
			keyfunc(kev, ename, etype, dt, x, y, button_dx, dy)
			i = i + size
		end

		k2t, kev = keys2.gamepad, nil
		local i = 0
		while i < k2t.count do
			local etype,    id,       button_axis, value
				= k2t[i+1], k2t[i+2], k2t[i+3],    k2t[i+4]
			if etype == "pressed" then
				keyfunc(keypress, ename, button_axis, dt)
			elseif etype == "released" then
				keyfunc(keyrelease, ename, button_axis, dt)
			elseif etype == "axis" then
				keyfunc(nil, ename, etype, dt, id, button_axis, value)
			end
			i = i + k2t.size[etype]
		end

		k2t, kev = keys2.touchevent, nil
		local i = 0
		while i < k2t.count do
			local etype,    id,       x,        y,        dx, dy, pressure
				= k2t[i+1], k2t[i+2], k2t[i+3], k2t[i+4]--nil,nil,nil
			if etype == "moved" then
				dx = k2t[i+5]
				dy = k2t[i+6]
				pressure = k2t[i+7]
			else --etype == "pressed" or "released"
				pressure = k2t[i+5]
			end
			--TODO:Handle touchevents in sysinput
			i = i + k2t.size[etype]
		end
	end --}}}

	---[[ not used
	--this is for text input
	if edit_mode then
		input.text = ""
		local k2txt = keys2.text
		if k2txt.count > 0 then
			local textinput = {}
			for i = 1, k2txt.count do
				textinput[i] = k2txt[i]
			end
			input.text = table.concat(textinput)
		end
		local kall = keys2.all
		local ec = 0
		for i = 1, kall.count, 2 do
			local ev = kall[i]
			local key = kall[i+1]
			if ev == "pressed" then
				local kb = in_bind[ename][key]
				if kb then
					input.edit[ec+1] = ev
					input.edit[ec+2] = kb
					ec = ec + 2
				end
			elseif ev == "text" then
				if input.edit[ec-1] == "text" then
					ec = ec - 2
					key = input.edit[ec+2] .. key
				end
				input.edit[ec+1] = ev
				input.edit[ec+2] = key
				ec = ec + 2
			end
		end
		input.edit.count = ec

	end
	--]]
end

return system
