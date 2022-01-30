 --                      Copyright 2021 -- Scott Smith                       --

--{{{ Local Variable Assignment
local export = nil --"clear" export assignment. don't want to use it
local _

local iowrite = io.write
local io = require "utils.io"
--local io = io
local hal, love, table, string, require, include, os, tostring, type
    = hal, love, table, string, require, include, os, tostring, type
local sfmt, tonumber = string.format, tonumber
local unpack = unpack or table.unpack

local lg = love.graphics
local vec = require "Vector"

local abs, floor, ceil = math.abs, math.floor, math.ceil
local truncate = require "utils.math.truncate"
local sin, cos, tan, atan2 = math.sin, math.cos, math.tan, math.atan2
local random = love.math.random
local round = require "utils.math.round"

local PriorityQueue = require "PriorityQueue"
local select, next
	= select, next
local ceil = math.ceil
local floor = math.floor

local utf8 = require "utf8"

local ini = require "ini"

--}}}

local AG = hal_conf.AG
AG.assets = AG.PACK..".agpack/assets/data"

local font --{{{
local fonts = {
	names = {
		"SourceCodePro", "Regular", 16, "fixed";
		"CrimsonPro", "Light", 18, "serif";
	},
	name_full = {},
	type = {},
	format = "ttf",
	type_face_option = false,
	astrisk_width = 0,
}
local font_name, font_size
do
	local typeface_options = {
		[false] = 2,
		serif = 2,
		fixed = 1,
	}
	local tf = type(AG.TYPEFACE) == "string" and AG.TYPEFACE:lower()
	fonts.type_face_option = tf or "serif"
	local font_number = typeface_options[tf]

	--local n = (font_number - 1) * 3 + 1
	local ti = table.insert
	for n = 1, #fonts.names, 4 do
		local f1 = fonts.names[n  ]
		local f2 = fonts.names[n+1]
		local f3 = fonts.names[n+2]
		local f4 = fonts.names[n+3]
		local name = sfmt("%s-%s.%s", f1, f2, fonts.format)
		ti(fonts.name_full, name)
		ti(fonts.type, f4)
		if font_number == #fonts.name_full then
			font_name = name
			font_size = tonumber(f3)
		end
	end

end

local default_font_name = font_name
local default_font_size = font_size
--}}}

--TODO: select_note should handle the possibility of an even thinner letter

local smallest_font_width --{{{
do
	local cache = {}

function smallest_font_width(font)
	if cache[font] then
		return cache[font]
	end
	local characters = ".'j "
	local half_width = math.huge
	for i = 1, #characters do
		local letter = string.sub(characters, i, i)
		local hw = font:getWidth(letter) * 0.5
		if hw < half_width then
			--print("letter", letter)
			half_width = hw
		end
	end
	cache[font] = half_width
	return half_width
end
end--}}}

local Animation = include "Animation"

local canvas = hal.canvas
local screen_text_render = true

--{{{ INITIALIZE SCALE variables
local scale = 1.0
local scale_inv = 1.0/scale

local scale_level = 0

local scale_update
--}}}

local trim = require"utils.string.trim"
local hex_dump = require"utils.string.hex_dump"
local check_utf8 = require"utils.string.check_utf8"

--{{{ status_message and set_status()
local status_message = {
	text = false,
	time = 0.0,
	default_time = 3.0,
}

local function set_status(msg, time)
	status_message.text = msg
	status_message.time = time or status_message.default_time
	screen_text_render = true
end
--}}}

--{{{ THEMES & COLORS
local theme
local color
do
	local uc = require"utils.color"
	local h2c = uc.hex2rgba

	local bullet_style_options = {
		circle = true,
		square = true,
		both = true,
		disable = true,
	}
	local grid_style_options = {
		line = true,
		dot = true,
		disable = true,
	}

	local grid_major_style_options = {
		screen = true,
		half = true,
	}

	local grid_major_weight_style_options = {
		thin = true,
		thick = true,
	}


	if not bullet_style_options[AG.BULLET_STYLE] then
		AG.BULLET_STYLE = "both"
	elseif AG.BULLET_STYLE == "disable" then
		AG.BULLET_STYLE = false
	end

	if not grid_style_options[AG.GRID] then
		AG.GRID = false
	elseif AG.GRID == "disable" then
		AG.GRID = false
	end

	if not grid_major_weight_style_options[AG.GRID_MAJOR_WEIGHT] then
		AG.GRID_MAJOR_WEIGHT = "thick"
	end


	local gmw, gmh
	if AG.GRID_MAJOR then
		if not grid_major_style_options[AG.GRID_MAJOR] then
			if type(AG.GRID_MAJOR) == "string" then
				local s, e, w, h = string.find(AG.GRID_MAJOR, "^%s*(%d+)%s*,%s*(%d+)%s*$")
				if s then
					AG.GRID_MAJOR = "custom"
					w = tonumber(w)
					h = tonumber(h)
					gmw = w > 0 and w or 1
					gmh = h > 0 and h or 1
				end
			else
				AG.GRID_MAJOR = false
			end
		end
	end

	local find_autowrap_px = "^(%d+)%s*px$"
	local s,e,m = string.find(AG.SERIF_AUTOWRAP, find_autowrap_px)
	local autowrap_serif = tonumber(m)
	local s,e,m = string.find(AG.FIXED_AUTOWRAP, find_autowrap_px)
	local autowrap_fixed = tonumber(m)
	local s,e,m = string.find(AG.WRAP_LIMIT_MINIMUM, find_autowrap_px)
	local wrap_limit_minimum = tonumber(m) or 100

	theme = {
		bullet_style = AG.BULLET_STYLE,
		h1_multi = 4,
		grid = AG.GRID,
		grid_major = AG.GRID_MAJOR,
		grid_major_weight = AG.GRID_MAJOR_WEIGHT,
		grid_major_w = gmw,
		grid_major_h = gmh,
		grid_scale_level = -3,
		_grid_table = {
			w = 0,
			h = 0,
			x = {},
			y = {},
		},
		autowrap = autowrap_serif,
		autowrap_serif = autowrap_serif,
		autowrap_fixed = autowrap_fixed,
		wrap_limit_minimum = wrap_limit_minimum,
		find_autowrap_px = find_autowrap_px,

		status_esc_menu = "Hold ESC to open menu.",

		double_click_speed = tonumber(AG.DOUBLE_CLICK_SPEED) or 0.5,
	}

	color = {
		rgba2hex = uc.rgba2hex,
		hex2rgba = uc.hex2rgba,

		FG                 = {h2c(AG.COLOR_FG or "decec6")},
		BG                 = {h2c(AG.COLOR_BG or "4b3a47")},
		GRID_DOT           = {h2c(AG.COLOR_GRID_DOT  or "decec660")},
		GRID_LINE          = {h2c(AG.COLOR_GRID_LINE or "decec618")},
		GRID_LINE_ORIGIN   = {h2c(AG.COLOR_GRID_LINE_ORIGIN or "decec618")},
		BOX                = {h2c(AG.COLOR_BOX or "2b1b27")},
		RECTANGLE_SELECT   = {h2c(AG.COLOR_RECTANGLE_SELECTION or "decec6")},
		TEXT               = {h2c(AG.COLOR_TEXT or "decec6")},
		TEXT_SELECT        = {h2c(AG.COLOR_TEXT_SELECT or "decec62e")},
		TASK               = {h2c(AG.COLOR_TASK or "decec6")},
		TASK_CANCEL        = {h2c(AG.COLOR_TASK_CANCEL or "e09aa4")},
		EDITING            = {h2c(AG.COLOR_EDIT_OUTLINE or "cb5264")},
		CURSOR             = {h2c(AG.COLOR_EDIT_CURSOR or "decec6")},
		WAYPOINT           = {h2c(AG.COLOR_WAYPOINT or "352230")},
		FOCUS_OUTLINE      = {h2c(AG.COLOR_FOCUS_OUTLINE or "decec6")},
		FOCUS_OUTLINE_HL   = {h2c(AG.COLOR_FOCUS_OUTLINE_HOVER or "decec6")},

		STATUS_BG          = {h2c(AG.COLOR_STATUS_BG or "2b1b27")},
		STATUS_FG          = {h2c(AG.COLOR_STATUS_FG or "decec6")},

		DIALOG_BG          = {h2c(AG.COLOR_DIALOG_BG or "2b1b27")},
		DIALOG_BUTTON      = {h2c(AG.COLOR_DIALOG_BUTTON or "decec6")},
		DIALOG_BUTTON_TEXT = {h2c(AG.COLOR_DIALOG_BUTTON_TEXT or "2b1b27")},
		DIALOG_HIGHLIGHT   = {h2c(AG.COLOR_DIALOG_HIGHLIGHT or "CB5264")},
	}
end
--}}} THEMES & COLORS

local cell = {x = 0, y = 0}
local mapos = {x = 0, y = 0}
--{{{ edit_line [ TABLE ] & edit_mode... variables
local edit_line = {
	data = "",
	data_2 = "",
	selected = "",
	cursor = 0,
	font = font,
	font_h1 = false,
	process_mouse_down = true,

	show_cursor = false,
	blink_timer = 0,
	blink_default_time = 0.5,
	blink_start_time = 0.8,

	outline_color = {
		r = 0xcb / 255,
		g = 0x52 / 255,
		b = 0x64 / 255,
	},

	diff_match_patch = require"utils.string.diff_match_patch",
	get_diff = function(self, level)
		local dmp = self.diff_match_patch

		local text1 = self.undo.note_raw_saved
		local text2 = self.undo.note_raw
		if text1 and text1 ~= text2 then

			local store_type = "raw"
			local compressed = false
			local data = text2
			if #data > 30 then
				local dmp = self.diff_match_patch
				local diffs = dmp.diff_main(text1, text2)
				dmp.diff_cleanupEfficiency(diffs)
				local patches = dmp.patch_make(text1, diffs)
				local patch_text = dmp.patch_toText(patches)
				if #patch_text < #data then
					store_type = "patch"
					data = patch_text
				end
			end
			if #data > 94 then
				level = level or 9
				local cd = love.data.compress("string", "zlib", data, level)
				if #cd < #data then
					compressed = level
					data = cd
				end
			end
			return store_type, compressed, data
		end
		return nil, "No change"
	end;

	--type = "raw" ;the original data being edited (READONLY)
	undo = { --UNDO STACK
		type = {}, --:string, append or delete or raw
		cursor = {}, --:integer, absolute position from start of text data
		data = {}, --string,
		ptr = 0, --stack pointer
		size = 0,
		timer = 0.0,
		timer_default = 3.0, --seconds
		steps = 0,
		steps_default = 5,
		print_separator = "\n",

		note_raw = "",

		last_selected = 0,

		undo_types = {
			raw = true,
			append = true,
			delete = true,
			backspace = true,
			step = true,
		},
		push = function (self, utype, ag1, ag2)
			if not self.undo_types[utype] then
				set_status("unknown type: ".. utype)
				return false
			end
			local cursor, data = 0, ""
			local p
			if utype == "raw" then
				cursor, data = utf8.len(ag1), ag1
				--log.note_cursor("RAW|data len: %d", #data)
				p = 1
			else
				cursor, data = ag1, ag2
				--log.note_cursor("data %s len: %d", data, #data)
				p = self.ptr + 1
			end
			if type(cursor) ~= "number" then
				set_status("invalid cursor type: ".. type(cursor))
				return false
			end
			if cursor == 0 then return true end
			if type(data) ~= "string" then
				set_status("invalid data type: ".. type(data))
				return false
			end

			do
				--local d = debug.getinfo(2, "l")
				--log.note_info("@%d undo push\t%9s %3d: %s", d.currentline,utype, cursor, data)

				--update self.note_raw

				local ssub = string.sub
				local note_raw = self.note_raw
				local dc = 0
				if utype == "raw" then
					note_raw = data
				elseif utype == "append" then
					local offset = utf8.offset(note_raw, cursor)
					if offset then
						local n1 = ssub(note_raw, 1, offset-1)
						local n2 = ssub(note_raw, offset)
						note_raw = n1 .. data .. n2
						dc = utf8.len(data) - 1
					end
				elseif utype == "backspace" or utype == "delete" then
					local offset = utf8.offset(note_raw, cursor)
					if offset then
						local n1 = ssub(note_raw, 1, offset-1)
						local n2 = ssub(note_raw, offset + #data)
						note_raw = n1 .. n2
						dc = -1
					end
				end
				self.note_raw = note_raw
				self.note_cursor = cursor + dc
				--log.note_cursor("L%d, %2d note_raw: %9s %s",
				--	debug.getinfo(2).currentline, self.note_cursor, utype, note_raw
				--)
			end


			local lasttype = self.type[p-1]
			if self.timer > self.timer_default then
				--print("UNDO STEP - timeout")
				lasttype = false
			end
			self.steps = self.steps + #data
			if self.steps >= self.steps_default then
				if #data == 1 and data:find("%s") then
					--print("UNDO STEP - char count")
					lasttype = false
				end
			end
			if not lasttype then
				--timeout
				self.timer = 0
				self.steps = 0
			elseif lasttype == utype then
				p = p - 1
				local setcur = self.cursor[p]
				local data_len = #self.data[p]
				local errmsg = "Undo stack type %s: expected %s (sc:%d == c:%d %s %d)"
				--printf("updating last stack item: CURSOR diff: %d, DATA len: %s\n",
				--	setcur - cursor, data_len
				--)
				if setcur == cursor then
					if utype ~= "delete" then
						--set_status(sfmt(errmsg, "delete", utype))
						errmsg = debug.getinfo(2).currentline .. " " .. errmsg
						log.info(errmsg, utype, "delete", setcur, cursor, "+", 0)
						return false
					end
					--delete
					data = self.data[p] .. data
				elseif setcur == cursor - utf8.len(self.data[p]) then
					if utype ~= "append" then
						--set_status(sfmt(errmsg, "append", utype))
						errmsg = "@".. debug.getinfo(2).currentline .. " " .. errmsg
						log.info(errmsg, utype, "append",
							setcur, cursor, "-", utf8.len(self.data[p])
						)
						return false
					end
					cursor = setcur
					--append
					data = self.data[p] .. data
				elseif setcur == cursor + utf8.len(data) then
					if utype ~= "backspace" then
						--set_status(sfmt(errmsg, "backspace", utype))
						errmsg = debug.getinfo(2).currentline .. " " .. errmsg
						log.info(errmsg, utype, "backspace",
							setcur, cursor, "+", utf8.len(data)
						)
						return false
					end
					--backspace
					data = data .. self.data[p]
				end
			end

			self.ptr = p
			self.size = p

			self.type[p] = utype
			self.cursor[p] = cursor
			self.data[p] = data

			--if true then
			--	local action_str = sfmt("Undo action #%d %s pushed on stack, cursor %d: %s",
			--		p, utype, cursor, data:gsub("\n", "\\n")
			--	)
			--	--set_status(action_str)
			--	print(action_str)
			--end
			return true
		end;
		--{{{
		peek = function (self, ptr)
			local p = ptr or self.ptr
			local utype, cursor, data = self.type[p], self.cursor[p] or 1, self.data[p]

			--set_status(sfmt("Undo action %s retrieved from stack, cursor %d: %s",
			--	utype, cursor, data and data:gsub("\n", "\\n")
			--));
			return utype, cursor, data
		end;
		pop = function (self)
			local p = self.ptr
			local tp = p - 1
			if tp < 0 then
				return
			end
			self.ptr = tp
			return self:peek(p)
		end;
		redo = function(self)
			local p = self.ptr + 1
			local size = self.size
			if p > size then
				return false
			end
			self.ptr = p
			return self:peek(p)
		end;
		reset = function(self)
			--print("Undo Stack Reset")
			self.ptr = 0
			self.size = 0
		end;
		--}}}
		tostring = function (self)
			local t = {}
			local ti = table.insert
			local sep = self.print_separator
			for i = 1, self.size do
				local ptr = self.ptr == i and "->" or "  "
				ti(t, sfmt(" %s %-6.6s @%3d(%s)",
					ptr, self.type[i], self.cursor[i], self.data[i]
				))
			end
			local msg = table.concat(t, sep)
			return msg
		end;
		print = function(self)
			printf("[%.2fs] EDIT LINE UNDO STACK\n", hal.met)
			print(self:tostring())
		end;
		step = function (self)
			self.timer = self.timer_default + 1
		end;
	},
}
local edit_mode = false
--}}}

---[======[ {{{ LINES! Broken!
local lines
do
lines = {
	x = {},
	y = {},
	id = {},
	ptr = -1,

	width = 6,

	select_end_point = "Select line end point",

	x1 = false,
	y1 = false,
	item1 = false,

	first = function(self, item, x1, y1)
		log.lines("FIRST!")
		self.item1 = item
		item.line = false
		self.x1 = x1
		self.y1 = y1
	end;

	set = function(self, p, x, y)
		if p and x and y then
			self.x[p] = x
			self.y[p] = y
			return true
		end
	end;

	add = function(self, x1, y1, x2, y2)
		local p = self.ptr + 2
		self.ptr = p
		--print("adding", x1, y1, x2, y2)

		self.x[p] = x1
		self.y[p] = y1
		self.x[p+1] = x2
		self.y[p+1] = y2

		return p
	end;
	clear = function(self)
		self.ptr = -1
	end;

	del = function(self, p)
		local x = self.x
		local y = self.y
		local id = self.id
		local pend = self.ptr
		self.ptr = pend - 2

		for i = p, pend, 2 do
			x[p]    =  x[p+2]
			x[p+1]  =  x[p+3]
			y[p]    =  y[p+2]
			y[p+1]  =  y[p+3]
			id[p]   = id[p+2]
			id[p+1] = id[p+3]
		end
	end;


	get = function(self, p)
		local x = self.x
		local y = self.y
		local id = self.id

		return id[p], x[p], y[p], id[p+1], x[p+1], y[p+1]
	end;
}
end
--}}} LINES! ]======]

local camera = { --{{{ [ TABLE ]
	grabbed = false,
	--mouse
	mx = 0,
	my = 0,
	--translate
	dx = 0,
	dy = 0,

	grab_dx = 0,
	grab_dy = 0,
	grab_movement_leeway = 5,

	start_from_x = false,
	start_from_y = false,
	move_to_x = false,
	move_to_y = false,

	scale_level = false,


	step = 0,
	step_interval = 0.1,

	line_line = function(x1,y1,x2,y2,x3,y3,x4,y4)
		local a = ((x4-x3)*(y1-y3)-(y4-y3)*(x1-x3))/((y4-y3)*(x2-x1)-(x4-x3)*(y2-y1))
		local b = ((x2-x1)*(y1-y3)-(y2-y1)*(x1-x3))/((y4-y3)*(x2-x1)-(x4-x3)*(y2-y1))
		if (a >= 0 and a <= 1 and b >= 0 and b <= 1) then
			return true
		end
		return false
	end;
}
function camera.line_rectangle(x1, y1, x2, y2, rx, ry, rw, rh)
	local ll = camera.line_line
	if     ll(x1,y1,x2,y2,   rx,   ry,   rx,ry+rh) then
	elseif ll(x1,y1,x2,y2,rx+rw,   ry,rx+rw,ry+rh) then
	elseif ll(x1,y1,x2,y2,   rx,   ry,rx+rw,   ry) then
	elseif ll(x1,y1,x2,y2,   rx,ry+rh,rx+rw,ry+rh) then
	else
		return false
	end
	return true
end
do
	local pow = math.pow
	function camera.distance(x1,y1,x2,y2)
		local dx = x1 - x2
		local dy = y1 - y2
		local dist = pow((dx * dx) + (dy * dy), 0.5)
		--log.distance("dxy(%.2f, %.2f) (%.2f, %.2f) → (%.2f, %.2f) => %.2f",
		--	dx, dy, x1, y1, x2, y2, dist
		--)
		return dist
	end
end

--}}}
--
--{{{link_file and link_file_data
local link_file
local link_file_data do
	local osd = "L.I.N.K."
link_file_data= {
	load_file = false,
	fullname = "test.link",
	old_fullname = "",
	name = "test",
	default_link = hal_conf.savedir .. "/default.link",
	working = hal_conf.savedir .. "/link_file.dat",
	old_save_dir     = osd,
	old_save_default = osd .. "/default.link",
	old_save_working = osd .. "/link_file.dat",
	modified = false,
	version = "prototype",
	dummy_table = {},
}
end
--}}}

--{{{ Window Settings
local love_window_settings = {
	width = 854,
	height = 480,
	icon_path = AG.assets.."/icon.png",
	icon_data = false,
	flags = {
		--fullscreen = false,
		--fullscreentype = "desktop",
		--vsync = 1,
		--msaa = 0,
		--stencil = true,
		--depth = 0,
		resizable = true,
		--borderless = false,
		centered = true,
		--display = 1,
		--minwidth = 1,
		--minheight = 1,
		--highdpi = false,
		--x = nil,
		--y = nil,
		--usedpiscale = true,
	},

	current_x = false,
	current_y = false,
	current_display = false,

	current_w = false,
	current_h = false,
	current_hw = false,
	current_hh = false,
	update_timer = 0,
}--}}}

--------------------------------------------------------------------------------
--                                                                            --
--                                                                            --
--                                                                            --
--                              THE WALL BEGINS                               --
--                                                                            --
--                                                                            --
--                                                                            --
--------------------------------------------------------------------------------
--{{{ wall  [ TABLE ] and initalizing variables UNDO
local wall
do
local setmetatable = setmetatable
wall = {
	Component = include "Component",
	Entity = include "Entity",

	focused = {},
	deleted = {},
	deleted_interval = {count = 0, max = 100},
	deleted_scheduled = {},
	selected = 0,
	line = 0,
	cursor_x = 0,
	select_text_timer = false,
	select_text_timer_default = .34,
	select_shift = false,
	select_line = 0,
	select_el_cursor = 0,
	select_cursor_x = 0,
	selected_str = "",
	count = 0,
	last = {
		line = false,
		select_line = false,
		cursor_x = false,
		select_cursor_x = false,
	},

	status_str = "",
	status_len = 0,

	mouse_type = "",

	find_last_mouse_x = -1,
	find_last_mouse_y = -1,

	waypoint_button_x = false,
	waypoint_button_y = false,
	waypoint_button_state = false,
	waypoint_button_string = false,
	waypoint_button_display = false,
	waypoint_radius = 20,

	waypoint_display_offset = 0.5,

	--{{{ COMMAND TABLE
	command = {
		wall = false, --will hold the wall table
		convert_to = {
			number  = function(value) return tonumber(value) end,
			string  = function(value) return tostring(value) end,
			clear   = function(value) return end,
			none    = function(value) return end,
			any     = function(value) return value end,
			all     = function(value) return trim(value) end,
			boolean = function(value)
				value = tostring(value):lower()
				if value == "false" or value == "f" then
					return false
				elseif value == "true" or value == "t" then
					return true
				end
			end,
		},
		arg_types = {
			--command = "^:([%a_][%w_]*)"
			number  = "^%s*(%-?%d+)%s*,?",
			string  = "^%s*([%w_%s]+)%s*,?",
			boolean = false,--replace with string
			any     = "^%s*([^,]+),?",
			all     = "^(.*)",
			none    = "^%s*$",
			clear   = "^.*",
		},
		_INTERNAL_arg = { count = 0 }, --only used internally, not meant for public access
		registered = {
			goto   = true,
			line   = true,
			h1     = true,
			image  = true,
		},
		ignore_transaction = {
			goto = false,
			line = false,
			image = true,
			h1 = true,
		},
		goto_arg_definitions = {
			"number", "number", "any",
		},
		_get_args = function(self, string, end_pos, arg_definitions)
			local sfind = string.find
			local ti = table.insert
			local arg_types = self.arg_types
			local goto_arg_def = self.goto_arg_definitions
			local convert_to = self.convert_to

			local args = self._INTERNAL_arg
			local argc = 0
			local s, e, value = 0, end_pos, false
			local c = 0
			--commands only take one line, so that's all we care about
			local _,ns _, _, ns = sfind(string, "^(.*)\n")
			string = ns or string
			while type(value) ~= "nil" and e do
				c = c + 1
				local at
				while true do
					at = arg_definitions[c] or "clear"
					if at == "!<" then
						c = c - 1
					else
						break
					end
				end
				local find_str = arg_types[at]
				s, e, value = sfind(string, find_str, e + 1)
				argc = argc + 1
				value = convert_to[at](value)
				args[argc] = value
			end
			--last value is always nil, so remove it from the count, we don't want it
			argc = argc - 1
			--print("ARGS")
			--for i = 1, argc do
			--	print("", i, args[i], type(args[i]))
			--end

			return args, argc
		end;
		goto = function (self, string, end_pos)
			local args, argc = self:_get_args(
				string, end_pos, self.goto_arg_definitions
			)

			local x, y, scale = unpack(args, 1, argc)
			if scale then scale = tonumber(scale) end

			if type(x) ~= "number" or type(y) ~= "number" then
				local str = "WARNING: Invalid command! x and y must be numbers"
				set_status(str)
				return nil, str
			end

			--print("GOTO ARGS", x, y, scale)
			local cs = self.wall.cell_size

			return function --[[ goto ]] (id)--( x, y, scale )
				--print("GOTO ARGS", x, y, scale)
				camera.dx = -x * cs
				camera.dy = -y * cs
				if scale then
					scale_level = scale
					scale_update(0)
				end
				screen_text_render = true
			end
		end;
		image_arg_definitions = { "all" },
		image_exif = include "exif",
		image = function(self, string, end_pos)
			local args, argc = self:_get_args(
				string, end_pos, self.image_arg_definitions
			)
			local image_fn = unpack(args, 1, argc)
			local item = self.user_data
			if not item.image_data or image_fn ~= item.image_name then
				item.image_name = image_fn
				item._auto_size = false
				local fdata
				local fls = self.wall.files
				local full_name = assert(fls:to_absolute("link", image_fn))
				local f = io.open(tostring(full_name), "r")
				if f then
					fdata = love.filesystem.newFileData(f:read("*a"), image_fn)
					f:close()
					local success, img = pcall(lg.newImage, fdata)
					if not success then
						item.image = false
						item.image_data = false
						set_status(img)
						return false
					end

					item.image_data = img
					local w, h = img:getDimensions()
					local offsetx, offsety
					local item_w, item_h = item.w, item.h
					do
						local p = fdata:getFFIPointer()
						local exif = self.image_exif
						local rot, swap_wh
						--rot will equal nil if no exif data
						rot, swap_wh, offsetx, offsety
							= exif.orientation(p)

						--if not rot then
						--	log.exif_error("%s", swap_wh)
						--end
						item.image_rotate = rot
						if rot and swap_wh then
							w, h = h, w
						end
						--log.image_rotate("%.4f, %s", item.image_rotate, swap_wh)
					end
					if item_w == 0 then
						local lws = love_window_settings
						local w_lim, h_lim =
							lws.current_hw * scale_inv,
							lws.current_hh * scale_inv
						local nw, nh = w, h
						if w > w_lim or h > h_lim then
							local s = self.wall.object_scale_offset(
								w_lim, h_lim, w, h
							)
							nw, nh = w * s, h * s
						end
						local csinv = self.wall.cell_inv
						item_w, item_h = ceil(nw * csinv), ceil(nh * csinv)
					end
					local cs = self.wall.cell_size

					item.image_scale,
					item.image_offx,
					item.image_offy = self.wall.object_scale_offset(
						item_w * cs, item_h * cs, w, h
					)
					do
						local csinv = self.wall.cell_inv
						if offsetx then
							item.image_offx = item.image_offx + item_w * cs
						end
						if offsety then
							item.image_offy = item.image_offy + item_h * cs
						end
					end

					item.w, item.h = item_w, item_h

					item.image = true
					return true
				else
					item.image = false
					item.image_data = false
					set_status("unable to open image")
					return false
				end
			else
				item.image = true
			end
		end;
		line_arg_definitions = { "number", "!<" },
		line_CMD_ID = "SYSTEM_SET_DO_NOT_CHANGE",
		line = function(self, string, end_pos)
			local item = self.user_data
			if not item.discard then
				local args, argc = self:_get_args(
					string, end_pos, self.line_arg_definitions
				)
				local wall = self.wall
				local x, y = unpack(args, 1, 2)
				if x and y then
					wall:update_line(item, tonumber(x), y)
				else
					wall.transaction:queue(sfmt("ADD first line node at %d, %d", item.x, item.y))
					lines:first(item, item.x, item.y)
				end
			end

			local cs = self.wall.cell_size

			return function(id)
				local i2 = item.line
				local x, y = i2.x, i2.y
				local w, h = lg.getDimensions()
				w, h = w * 0.5, h * 0.25
				camera.move_to_x = -x * cs + w
				camera.move_to_y = -y * cs + h
				screen_text_render = true
			end
		end;
		h1_arg_definitions = { "none" },
		h1 = function(self, string, end_pos)
			local args, argc = self:_get_args(
				string, end_pos, self.h1_arg_definitions
			)
			local item = self.user_data
			if #item.note > 1 then
				local heading = 1
				item.heading = heading
				self.wall:resize_note_box(item, heading)
			else
				item.heading = false
			end
			return true
		end;
		autowrap = function(self, string, end_pos)
			return function(id)
				set_status("You're wasting your time.")
				print("Awe, that'll never work.")
			end
		end,
		arg = { count = 0 },
		find = function(self, string)
			local s, e, cmd = string.find(string, "^:([%a_][%w_]*)")
			--printf("Found command: %s\n", cmd)
			local f = self.registered[cmd] and self[cmd]
			return f, e, cmd
		end,

		parse = function(self, string)
			local s, e, cmd = string.find(string, "^:([%a_][%w_]*)")
			local args, argc
			if cmd then
				args, argc = self:_get_args(
					string, e, self[cmd.."_arg_definitions"]
				)
				return cmd, unpack(args, 1, argc)
			else
				return nil, "invalid command"
			end
		end;

		setup = function(self, string, data)
			local func, e, name = self:find(string)

			if func then
				self.user_data = data
				local item_cmd = func(self, string, e)
				self.user_data = false
				if item_cmd then
					return item_cmd, name
				end
			end
			return nil, "invalid command"
		end,
	},
	--}}} COMMAND TABLE
	--{{{ TRANSACTION TABLE
	transaction = {
		front = 0,
		count = 0,
		items_read = 0,
		print_table = {
			count = 0, txns = 0,
			pt2 = {},
			write = function(self)
				local str
				if self.txns > 0 then
					str = table.concat(self, "\n", 1, self.count)
				end
				self.txns = 0
				self.count = 0
				return str
			end;
			dump = function(self)
				local str = self:write()
				if str then
					print(str)
				end
			end;
			printf = function (self, ...)
				local c = self.count + 1
				self.count = c
				self[c] = sfmt(...)
			end;
			print = function (self, ...)
				local p2 = self.pt2
				local c2 = 0
				for i = 1, select("#", ...) do
					c2 = c2 + 1
					p2[c2] = tostring(select(i, ...))
				end
				if c2 > 0 then
					local c = self.count + 1
					self.count = c
					self[c] = table.concat(p2, "\t", 1, c2)
				end
			end;
			txn = function (self, ...)
				self.txns = self.txns + 1
				self:print(...)
			end;
			txnf = function(self, ...)
				self.txns = self.txns + 1
				self:printf(...)
			end;

		},

		--ADD, REMOVE, EDIT
		type = {
			ADD = "add",   --add an existing note (from file)
			NEW = "new",   --completely new note
			CLR = "clear", --reset transaction table
			WALL_CLR = "wall_clear", --clear all wall data (set count to 0)
		},
		types = {
			ADD = "add",
			[1] = "",
		},
		items = {[1] = {}}, --items[?] holds each transaction item
		load_tables = {count = 0},

		get_load_table = function(self)
			local lt = self.load_tables
			local c = lt.count + 1
			lt.count = c
			local t = lt[c]
			if not t then
				t = {}
				lt[c] = t
			end
			t.count = 0
			t.item_id = 0
			t.item_table = false
			t.resize = false
			t.selected = false

			return lt[c]
		end;
		add_note = function(self, item)
			local c = self.count + 1
			self.types[c] = self.types.ADD
			self.items[c] = item

			self.count = c
		end,
		queue_debug_table = {},
		queue = function(self, txn, data)
			if not data then
				data = txn
				txn = "MSG"
			end
			local c = self.count
			self[c+1] = txn
			self[c+2] = data
			self.count = c + 2
			do
				local c = 0
				for i = 5, 2, -1 do
					local cl = debug.getinfo(i).currentline
					if cl > 0 then
						c = c + 1
						self.queue_debug_table[c] = cl
					end
				end
				local cl = table.concat(self.queue_debug_table, "→", 1, c)
				--printf("[%.2f] QUEUE: @%s) %6s|%s\n", hal.met, cl, txn, data)
			end
		end;
		dequeue = function(self)
			local f = self.front
			if f <= self.count then
				self.front = f + 2
				return self[f], self[f+1]
			end
		end;
		reset = function(self)
			self.count = 0
			self.front = 1
			self.load_tables.count = 0
		end;
	},
	--}}} TRANSACTION TABLE

	hover = false,
	resize = false,
	resize_side = false,

	linkdata = false,

	files = include"Directories"(),

	cell_size = false,
	note_border_w = 0,
	wrap_limit = 400, --false,--400,
	resize_anchor_cs = 0.40, --cell size in floating point
	resize_anchor_render = 0.15, --render size when not focused
	[1] = {}, --wall[?] holds each note

	clear_item = function(self, item) --{{{
		if not item then
			return
		end
		local base = item
		item = item._data

		item.x = 0
		item.y = 0
		item.w = false
		item.h = false
		item.r = false
		item.wrap_limit = theme.autowrap
		item.readonly = nil
		item.discard = nil
		--item.date = "2021-05-13"
		--item.time = "00:00:00 AM"
		item.created = "20210513000000"
		item.type = "note"
		item.task = false
		item.heading = false
		item.image = nil
		item.line = nil
		item.command = nil
		item._focused = false
		item._auto_size = false
		if not item.note then item.note = {} end
		if not item.note.newline then item.note.newline = {} end
		for k = 1, #item.note do
			item.note[k] = nil
		end
		for k = 1, #item.note.newline do
			item.note.newline[k] = nil
		end
		item.note_raw = ""
		return base
	end;--}}}
	create_item = function(self, item) --{{{
		item = item or {}
		if not getmetatable(item) then
			item._data = {}
			item._access = {count = 0}
			item._queue = {count = 0}
			setmetatable(item, self.item_metatable)
		end
		return item
	end;--}}}

	set_cell_size = function(self)--{{{
		self.cell_size = ceil(font:getHeight() * 0.5) * 2
		printf("NEW cell_size: %s\n", self.cell_size)
		self.cell_inv = 1.0 / self.cell_size
		self.note_border_w = floor(self.cell_size * .5)
		self.h1_cell_size = ceil(edit_line.font_h1:getHeight() * 0.5) * 2
		self.h1_cell_inv = 1.0 / self.h1_cell_size
		self.h1_note_border_w = floor(self.h1_cell_size * 0.5)
	end, --}}}
	set_select_cursor = function (self) --{{{
		--The idea is, if shift is pressed and an input is registered (with keyboard
		--or with mouse) the existing cursor should be saved to complete the selection.
		--However, if shift is pressed and the old cursor has already been saved, don't
		--change the old cursor, just update the new.

		--printf("set_select_cursor %s@%d\n",
		--	self.select_shift and "SHIFT " or "      ",
		--	debug.getinfo(2).currentline
		--)
		if self.select_shift then
			if self.select_line <= 0 then
				self.select_offset = edit_line.offset
				self.select_el_cursor = edit_line.cursor
				self.select_line = self.line
				self.select_cursor_x = self.cursor_x
			end
			return true
		else
			self.select_line = 0
			self.select_el_cursor = -1
			self.select_offset = -1
			self.select_cursor_x = -1
			return false
		end
	end,--}}}
	clear_focused = function(self, s) --{{{
		s = s or 1
		self.resize = 0
		for i = s, #self.focused do
			local id = self.focused[i]
			self.focused[i] = nil
			local item = self[id]
			item._focused = false
		end
	end,--}}}
	resize_note_box = function(self, id, heading) --{{{
		screen_text_render = true
		local item
		if type(id) == "table" then
			item = id
		else
			item = self[id]
		end
		heading = heading or item.heading
		local note = item.note

		local font = font
		local istart = 1
		if heading then
			font = edit_line.font_h1
			istart = 2
		end
		local item_w = item.w
		local item_h = item.h
		if item._auto_size then
			item_w = 0
			item_h = 0
		end

		local max_w = note.wrap or 0
		if max_w == 0 then
			for i = istart, #note do
				local w = font:getWidth(note[i] or "")
				if w > max_w then
					max_w = w
				end
			end
		end
		local tw = ceil(max_w / self.cell_size)
		local th = #item.note
		if heading then
			local cell_per_head = self.h1_cell_size * self.cell_inv
			item_w = tw + ceil(cell_per_head)
			item_h = (th - 1) * cell_per_head
		else
			if tw >= (item_w or 0) then item_w = tw + 1 end
			if th > (item_h or 0) then item_h = th end
		end

		local nw, nh = item.w ~= item_w, item.h ~= item_h
		if nw or nh then
			local wis = wall.items
			local tidx = wis.tables:map_type("table", item)
			local geos = wis.geometries
			if nw then
				geos.w[tidx] = item_w
				item.w = item_w
			end
			if nh then
				geos.h[tidx] = item_h
				item.h = item_h
			end
		end

		--print("item w, h", item.w, item.h)
	end,--}}}
	add_new_note = function(self, x, y, selected) --{{{
		self.transaction:queue(sfmt("ADD new note at %d,%d", x, y))
		local now = os.time()

		local c = self.count + 1
		self.count = c

		self[c] = self:create_item(self[c])

		self.line = 1

		local item = self[c]
		self.transaction:queue("CLEAR", item)

		local item_created = os.date("!%Y%m%d%H%M%S", now)
		do
			local lt = self.transaction:get_load_table()
			local c
			c = 1; lt[c] = "x";          lt[c+1] = x or 0
			c=c+2; lt[c] = "y";          lt[c+1] = y or 0
			c=c+2; lt[c] = "w";          lt[c+1] = 1
			c=c+2; lt[c] = "h";          lt[c+1] = 1
			c=c+2; lt[c] = "created";    lt[c+1] = item_created
			c=c+2; lt[c] = "type";       lt[c+1] = "note"
			c=c+2; lt[c] = "wrap_limit"; lt[c+1] = theme.autowrap
			c=c+2; lt[c] = "note_raw";   lt[c+1] = ""
			c=c+2; lt[c] = "_auto_size"; lt[c+1] = true
			c=c+2; lt[c] = "_focused";   lt[c+1] = selected
			lt.count = c

			lt.item_id = self.count
			lt.selected = selected
			self.transaction:queue("NEW", lt)
		end

		--TODO: I think clear_focused should be a transaction too...
		self.cursor_x = 0
		if selected then
			self:clear_focused()
			self.focused[1] = c
		end
		link_file_data.modified = true

		edit_line.cursor = 0
		edit_line.undo.note_cursor = 0
		edit_line.undo.note_raw = ""
		edit_line.undo.last_selected = false

		return item, c

	end, --}}}

	load_image_file = function (self, file) --{{{
		local rel_filename
		do
			local abs_filename = file:getFilename()
			local f = self.files
			f:enqueue(abs_filename)
			f:update()
			local tree = assert(f:get_relative("link", abs_filename))
			rel_filename = tostring(tree)
			f:add(rel_filename, tree)
		end

		local item, id = self:add_new_note(cell.x, cell.y, true)
		local txn = self.transaction
		local lt = txn:get_load_table()
		local c = -1
		c=c+2; lt[c] = "w";          lt[c+1] = 0
		c=c+2; lt[c] = "h";          lt[c+1] = 0
		c=c+2; lt[c] = "note_raw";   lt[c+1] = sfmt(":image %s", rel_filename)
		c=c+2; lt[c] = "temp_file";  lt[c+1] = file
		lt.count = c

		lt.item_id = id
		lt.selected = false
		txn:queue("UPDATE", lt)
	end;
-- }}}

	select_note_full = false,
	select_note_x = false,
	select_note_old_cursor_x = false,
	select_note = function(self, id)--{{{
		local wi = self[id]

		local full = wi.note[self.line] or "" --edit_line.data
		local x = self.cursor_x
		self.cursor_x_prev = false

		--printf("select_note called from %d\n", debug.getinfo(2).currentline)

		if self.select_note_full ~= full or self.select_note_x ~= x then
			self.select_note_full = full
			self.select_note_x = x
		else
			self.cursor_x = self.select_note_old_cursor_x
			--printf("NOOP, %d«%s|%s»\n", x, edit_line.data, edit_line.data_2)
			return edit_line.cursor
		end --same position on same string? no work needed

		edit_line.data_2 = ""
		edit_line.data = full--wi.note[self.line] or ""

		local regular_font = font
		local font = font
		if wi.heading then
			font = edit_line.font_h1
		end

		local el_w = font:getWidth(full)
		local el_len = utf8.len(full)
		local el_avg = el_w / el_len
		local half_period = smallest_font_width(font)

		local width = x + half_period * 0.5
		if width < 0 then width = 0 end

		local estimated = floor((width) / el_avg)
		local offset
		local est_count = 0
		local diff = math.huge
		local str1, str2
		estimated = estimated + 1
		--log.cursor("Initial estimation for #%d at x=%d, est=%d (1/2.)=%.1f", id, x, estimated, half_period)
		local last_est = estimated
		while true do
			local est = estimated
			offset = utf8.offset(full, est)
			--log.select_note("x: %d, estimated: %d, offset: %d", x, est, offset or -1)
			if offset then
				est_count = est_count + 1
				local s1 = string.sub(full, 1, offset-1)
				local s1w = font:getWidth(s1)

				local dw = s1w - width
				local tdiff = diff
				if dw == 0 then
					diff  = 1
					tdiff = -1
				elseif dw > 0 then
					tdiff = abs(dw)
					estimated = estimated - 1
				elseif dw < 0 then
					tdiff = abs(dw)
					estimated = estimated + 1
				end
				if tdiff < diff then
					--diff = tdiff
					str1 = s1
					str2 = string.sub(full, offset)
				else
					tdiff = -1
				end
				--log.cursor("Est#%d D:%.1f~%.1f W:%.1f A:%.1f/%.1f=%d(%d) «%s|%s»",
				--	est_count, diff, dw, width, s1w, el_avg, est, offset,
				--	str1, str2
				--)
				if last_est == estimated then break end
				if tdiff < half_period * 0.5 then break end
				diff = tdiff
			else
				--log.cursor("Est#%d No Offset: W:%.1f/%.1f=%d Len:%d «%s|»",
				--	est_count, width, el_avg, estimated, el_len, full)
				if estimated == 0 then
					str1 = ""
					str2 = full
				else
					str1 = full
					str2 = ""
				end
				break
			end
		end

		estimated = utf8.len(str1)
		offset = estimated == 0 and 0 or utf8.offset(str1, estimated)
		edit_line.offset = offset

		edit_line.data   = str1
		edit_line.data_2 = str2
		if wi.heading then
			font = regular_font
		end

		if estimated > 0 and
			not wi.note.newline[self.line] and
			self.line < #wi.note
		then
			local s, e = string.find(full, "^%s$", edit_line.offset-1)
			if s then
				--print("s,e, str", s,e, "«"..string.sub(full, 1, edit_line.offset-2).."»")
				edit_line.data = string.sub(full, 1, edit_line.offset-2)
				estimated = estimated - 1
			end
		end

		self.cursor_x = font:getWidth(edit_line.data)
		self.select_note_old_cursor_x = self.cursor_x
		edit_line.cursor = estimated

		--reset blink timer when this is update.
		edit_line.show_cursor = true
		edit_line.blink_timer = edit_line.blink_start_time
		--print("@"..debug.getinfo(2).currentline.." editline blink timer restarted")

		return estimated  --new cursor position
	end, --}}}
	delete_selected_string = function(self) --{{{
		local ssub = string.sub
		local item = self[self.selected]
		local note = item.note
		local line_start = note[self.min_line] or ""
		local first = ssub(line_start, 1, self.min_o)
		local el_cursor = utf8.len(first)

		do --set undo for text
			local rawstr = item.note_raw
			local cur, del_str = 0, ""
			local ml = self.min_line
			cur = self.get_end_offset(note, self.min_line - 1)
			cur = cur + self.min_o + 1

			local cur_end = self.get_end_offset(note, self.max_line - 1)
			cur_end = cur_end + self.max_o

			--printf("cursor: %d -> %d; #rawstr: %d\n", cur, cur_end, #rawstr)
			del_str = ssub(rawstr, cur, cur_end)
			--log.delete_selected("del_str: %s", del_str)

			local cursor = self.get_end_cursor(note, self.min_line-1)
			cursor = cursor + el_cursor + 1

			edit_line.undo:step()
			edit_line.undo:push("backspace", cursor, del_str)
			edit_line.undo:step()
		end

		edit_line.cursor = el_cursor
		self.line = self.min_line
		self.selected_str = ""
		self.select_shift = false
		self:set_select_cursor()
	end,--}}}
	exit_edit_mode = function(self) --{{{
		edit_mode = hal.input.edit_mode(false)
		--[[
		do
			local d = debug.getinfo(2, "l")
			self.transaction:queue(sfmt("@%d exiting edit mode, but what happened to #%d?", d.currentline, self.selected))
		end--]]
		if self.selected > 0 then
			--self.transaction:queue(sfmt("EXIT edit note #%d", self.selected))
			do
				local stype, compressed, data = edit_line:get_diff()
				if stype then
					local txn = self.transaction
					local lt = txn:get_load_table()
					lt.commit_type = stype
					lt.commit_compressed = compressed
					lt.commit_data = data
					txn:queue("COMMIT", lt)
				end
			end

			local sfind = string.find
			local ssub = string.sub

			local id = self.selected
			local item = self[id]
			local line1 = item.note[1] or ""


			if theme.bullet_style then
				--print("selected:", self.selected)
				local s, e = sfind(line1, "^%*%s+")
				local item_task
				if s then
					item_task = item.task or "incomplete"
				else
					item_task = false
				end
				--TODO: can I clean up the load_table boilerplate
				if item.task ~= item_task then
					local lt = self.transaction:get_load_table()
					local c = 1
					lt[c] = "task"; lt[c+1] = item_task
					lt.count = c
					lt.item_id = self.selected
					self.transaction:queue("MODIFY", lt)
				end
			end
			local cmd, err = item and item.note_raw
			if cmd then
				local str = cmd
				cmd, err = self.command:setup(cmd, item)
				--if cmd and not self.command.ignore_transaction[err] then
				--if cmd then
				--	self.transaction:queue(sfmt("PROCESSED Note %d: %s", self.selected, str))
				--end
			end
			if not cmd then
				--no command
			elseif item.type ~= "waypoint" and type(cmd) == "function" then
				local txn = self.transaction
				local lt = txn:get_load_table()
				local c = -1
				c=c+2; lt[c] = "w";          lt[c+1] = false
				c=c+2; lt[c] = "h";          lt[c+1] = false
				c=c+2; lt[c] = "r";          lt[c+1] = self.waypoint_radius
				c=c+2; lt[c] = "type";       lt[c+1] = "waypoint"
				lt.count = c

				lt.item_id = id
				txn:queue("MODIFY", lt)
				screen_text_render = true
				self.waypoint_button_state = false
				self.waypoint_button_x = false
			else
				--all good
			end
		end

		self.selected = 0
		self.line = 0
		self.cursor_x = 0
		self.select_shift = false
		self.select_line = 0
		self.select_cursor_x = 0
		edit_line.set_autowrap_size = false
		self.mouse_hide_is_typing = false
	end,--}}}
	hit_task_box = function(self, id, mx, my) --{{{
		local item = self[id]
		if item and item.task then
			local cs = self.cell_size
			local width_mod = 0
			if fonts.type_face_option == "fixed" then
				width_mod = cs * 0.25
			end
			local tx, ty, tw, th = item.x*cs, item.y*cs, cs + width_mod, cs
			--printf("mxy (%d, %d) txy (%d, %d) twh (%d, %d)\n",
			--	mx, my, tx, ty, tx+tw, ty+th
			--)
			if mx >= tx and mx <= tx + tw and
				my >= ty and my <= ty + th
			then
				return item
			end
		end
		return false
	end;--}}}
	get_wrap_limit_minimum = function(self, current)
		if current < self.cell_size then current = self.cell_size end
		--log.wrap("current: %dpx < default: %dpx?", current, theme.wrap_limit_minimum)
		if current < theme.wrap_limit_minimum then
			local cells = ceil(theme.wrap_limit_minimum * self.cell_inv)
			if cells < 1 then cells = 1 end
			return cells * self.cell_size
		else
			return current
		end
	end;

	--{{{ get_end_cursor and get_end_offset and get_line_cursor
	get_end_cursor = function(note, line_num)
		local cursor = 0
		for i = 1, line_num or #note do
			local note_len = note[i] and utf8.len(note[i]) or 0
			cursor = cursor + note_len + (note.newline[i] and 1 or 0) --\n
			--print("cursor, note_len", cursor, note_len)
		end
		return cursor
	end;

	get_end_offset = function(note, line_num)
		local offset = 0
		for i = 1, line_num or #note do
			local note_off = note[i] and #note[i] or 0
			offset = offset + note_off + (note.newline[i] and 1 or 0)
		end
		return offset
	end;

	get_line_cursor = function(note, cursor)
		local line = 1
		for i = 1, #note do
			local nl = note.newline[i] and 1 or 0
			local len = utf8.len(note[i]) + nl
			if len < cursor then
				line = line + 1
				--print("cursor, cursor - len", cursor, cursor - len, line)
				cursor = cursor - len
			elseif len == cursor then
				if line < #note then
					line = line + 1
					--print("cursor, cursor - len", cursor, cursor - len, line)
					cursor = cursor - len
				end
				break
			else
				break
			end
		end
		return line, cursor
	end;
	--}}} get_end_cursor and get_end_offset

	object_scale_offset = function (w1, h1, w2, h2) --{{{
		local sw, sh = w1 / w2, h1 / h2
		local scale = sw
		if sh < scale then
			scale = sh
		end
		return scale,
			(w1 - w2 * scale) * 0.5,
			(h1 - h2 * scale) * 0.5
	end;--}}}

}
wall.command.wall = wall
end
function wall.get_raw_cursor(note, row, col)--{{{
	return wall.get_end_cursor(note, row-1) + col
end--}}}
function wall.get_raw_offset(note, row, col) --{{{
	return wall.get_end_offset(note, row) + col
end --}}}
function wall:update_line(item, x, y)

	if item.line then return false end

	local item2, idx2 = self:add_new_note(x, y, false)
	local txn = self.transaction
	local lt = txn:get_load_table()
	local c = -1
	c=c+2; lt[c] = "line"; lt[c+1] = item2
	c=c+2; lt[c] = "note_raw"; lt[c+1] = sfmt(":line %s, %d", x, y)
	lt.count = c
	lt.item_table = item
	txn:queue("MODIFY", lt)

	--update drone item
	lt = txn:get_load_table()
	local c = -1
	c=c+2; lt[c] = "discard"; lt[c+1] = true
	c=c+2; lt[c] = "readonly"; lt[c+1] = true
	c=c+2; lt[c] = "line"; lt[c+1] = item
	c=c+2; lt[c] = "note_raw"; lt[c+1] = sfmt(":line %d, %d", item.x, item.y)
	lt.count = c
	lt.item_id = idx2
	txn:queue("UPDATE", lt)

	edit_line.el_force_update = true

	return true
end

do
	local at = wall.command.arg_types
	at.boolean = at.string
end
do
local STX = string.char(0x2)
local ETX = string.char(0x3)
local find_STX = "^"..STX
local find_ETX = ETX.."$"
local find_space_begin = "^[%s"..STX.."]"
local find_space_end = "[%s"..ETX.."]$"

function wall.load_note_from_string(note_str, item_note) --{{{
	local sfind, sgsub, ssub = string.find, string.gsub, string.sub
	local ti = table.insert
	local s, e = 1, 1
	local str
	local c = 0
	note_str = tostring(note_str)
	do
		local ss, se = 1, #note_str
		local s1 = sfind(note_str, find_STX)
		if s1 then ss = s1 + 1 end
		local s2 = sfind(note_str, find_ETX)
		if s2 then se = s2 - 1 end
		if s1 or s2 then
			--print("stripping control characters")
			note_str = ssub(note_str, ss, se)
		end
	end
	item_note = item_note or {}
	for i = 1, #item_note do item_note[i] = nil end
	do
		local nnl = item_note.newline
		if not nnl then nnl = {} item_note.newline = nnl end
		for i = 1, #nnl do nnl[i] = nil end
	end

	--print("#note_str", #note_str, note_str)
	local trailing_newline = false
	while e and e <= #note_str do
		c = c + 1
		local last_e = e

		str = ""
		--print("NOTE START!", #note_str)
		--print(note_str)
		--print("NOTE END!!!")
		while e and e <= #note_str do
			last_e = e
			local cap, escape, esc_char
			s, e, cap, escape, esc_char = sfind(note_str, "(.-)(\\)(.)", e)
			--printf("(%d->%d[%d])CAP! %30s '%s' '%s'\n", s or -1, e or -1,
			--      last_e or -1, cap, escape, esc_char
			--)
			if cap then
				str = str .. cap
			end
			if escape then
				if esc_char == "n" then
					trailing_newline = e == #note_str
					break
				elseif esc_char == "\\" then
						str = str .. "\\"
				end
					--discard unrecognized esc_chars
			end
			if e then e = e + 1 end
		end

		if not e and last_e <= #note_str then
			   str = str .. ssub(note_str, last_e)
		end
		ti(item_note, str)
		if e then e = e + 1 end
	end
	if trailing_newline then
	   ti(item_note, "")
	end
	return item_note
end --}}}
function wall.save_note_to_string(note_raw) --{{{
	local sgsub, sfind = string.gsub, string.find
	local str = sgsub(note_raw, "\\", "\\\\")
	str = sgsub(str, "\n", "\\n")
	do
		local s = sfind(str, find_space_begin)
		if s then str = STX .. str end
		s = sfind(str, find_space_end)
		if s then str = str .. ETX end
		--if len ~= #str then
		--	print("added control characters")
		--end
	end

	return str
end --}}}
do --{{{ wall.wall.raw_string_to_note [ FUNCTION ]
	local sfind = string.find
	local ssub = string.sub
	local ti = table.insert
	--local table_insert_count
	--[[local ti do --{{{ for debugging
		local tins = table.insert
		function ti(t, str)
			table_insert_count = table_insert_count + 1
			--print("@"..debug.getinfo(2).currentline..": ticount & new line", table_insert_count, str)
			return tins(t, str)
		end
	end--}}}]]
	local space_width = false
	local space_width_inv = false
	local function wrap_line(line, wrap_limit, note)
		if type(note) ~= "table" then
			error("note must be a table")
		end
		if font:getWidth(line) > wrap_limit then
			note.wrap = wrap_limit
		end
		local w, wt = font:getWrap(line, wrap_limit)
		if #wt == 0 then
			wt[1] = line
		end
		for i = 1, #wt do
			local line = wt[i]
			local lw = font:getWidth(line)
			if lw > wrap_limit then
				local s, e = sfind(line, "%s+$")
				if e > s then
					local space_limit = floor(wrap_limit * space_width_inv) + 1
					local es_calc = e - s + 1
					--multiple spaces found
					--I want line1 to have at least one space
					local line1, line2
					if space_limit > s and space_limit <= e then
						note.wrap = wrap_limit
						line1 = ssub(line, 1, space_limit)
						line2 = ssub(line, space_limit+1)
					else
						line1 = ssub(line, 1, s)
						line2 = ssub(line, s+1, e)
					end
					ti(note, line1)
					for k = i + 1, #wt do
						line2 = line2 .. wt[k]
					end
					return wrap_line(line2, wrap_limit, note)
				end
			end
			ti(note, wt[i])
		end

		return note
	end
	function wall.raw_string_to_note(str, nnote, wrap_limit)
		local s, e, line = 1, 1
		local last_e = e
		nnote = nnote or {}
		for i = 1, #nnote do nnote[i] = nil end
		do
			local nnl = nnote.newline
			if not nnl then nnl = {} nnote.newline = nnl end
			for i = 1, #nnl do nnl[i] = nil end
		end
		local newline = false
		nnote.wrap = false
		if wrap_limit then
			local sw = font:getWidth(" ")
			if space_width ~= sw then
				space_width = sw
				space_width_inv = 1.0 / sw
			end
		end
		while e and e <= #str do
			last_e = e
			s, e, line, newline = sfind(str, "(.-)(\n)", e)
			--print(s, e, "line, newline", type(line) , type(newline))
			if line then
				if wrap_limit then
					nnote = wrap_line(line, wrap_limit, nnote)
				else
					ti(nnote, line)
				end
				nnote.newline[#nnote] = true
			end
			if e then e = e + 1 end
		end
		if not e and last_e <= #str then
			local line = ssub(str, last_e)
			--print("e, last_e, #str, str", e, last_e, #str, str)
			if wrap_limit then
				nnote = wrap_line(line, wrap_limit, nnote)
			else
				ti(nnote, line)
			end
		elseif newline then
			ti(nnote, "")
		end
		if #nnote < 1 then
			nnote[1] = ""
		end
		return nnote
	end
end--}}}
end

do
	--convert wall to a metatable
	local wall_table = wall
	local type = type
	local debug_set_keys = {
		grab_x = true,
		grab_y = true,
	}
	local debug_fetch_keys = {
		grab_x = true,
		grab_y = true,
	}
	local setmetatable, getmetatable = setmetatable,getmetatable
	wall = setmetatable({_data = wall_table}, {
	__newindex = function(self, key, value)
		--if type(key) == "number" then
		--	local cl = debug.getinfo(2).currentline
		--	log.wall("@%d, setting %s = %s", cl, key, value)
		--end
		if debug_set_keys[key] then
			local cl = debug.getinfo(2).currentline
			log.wall("@%d, setting %s = %s!", cl, key, value)
		end
		wall_table[key] = value
	end;
	__index = function(self, key)
		local value = wall_table[key]
		--if wall_table.doprint_item_mt and type(key) == "number" and key > 0 then
		--	local cl = debug.getinfo(2).currentline
		--	if not getmetatable(value) then
		--		log.wall("@%d, fetching %s = %s mt missing!", cl, key, value)
		--	end
		--end
		if debug_fetch_keys[key] then
			local cl = debug.getinfo(2).currentline
			log.wall("@%d, fetching %s = %s!", cl, key, value)
		end
		return value
	end;
	})
end

do
	local ignored_items = {
		_focused = true,
	}
	local rawset, rawget = rawset, rawget
	wall.doprint_item_mt = true

	local temp_table = {}
	wall.item_metatable = {
		doprint = true,
		__newindex = function(self, key, value)
			do
				local access = self._access
				local c = access.count + 1
				access.count = c
				access[c] = key
			end
			do
				local queue = self._queue
				local qc = queue.count
				queue[qc + 1] = key
				queue[qc + 2] = value
				queue.count = qc + 2
			end

			if wall.doprint_item_mt and not ignored_items[key] then
				local lines = temp_table
				local c = 0
				for i = 5, 2, -1 do
					local cl = debug.getinfo(i).currentline
					if cl > 0 then
						c = c + 1
						lines[c] = cl
					end
				end
				local cl = table.concat(lines, "→", 1, c)

				printf(" ! [%.2f] ITEM: @%s, setting %s = %s\n", hal.met, cl, key, value)
			end
			self._data[key] = value
		end;
		__index = function(self, key)
			local value = self._data[key]
			local access = self._access
			for i = 1, access.count do
				if access[i] == key then
					local cl = debug.getinfo(2).currentline
					printf(" ! [%.2f] ITEM: @%d, fetching %s → %s\n", hal.met, cl, key, value)
					break
				end
			end
			return value
		end;
	}
end
--}}}
--------------------------------------------------------------------------------
--                                                                            --
--                                                                            --
--                                                                            --
--                               THE WALL ENDS                                --
--                                                                            --
--                                                                            --
--                                                                            --
--------------------------------------------------------------------------------
--{{{ CREATE function scale_level
do
	local scale_interval = 1.0 / font_size * 2
	local scale_min = scale_interval * 2
	local scale_max = 1.00
	local scale_levels = {
		max = -7,
		[ -1] = 0.75,
		[ -2] = 0.60,
		[ -3] = 0.46,
		[ -4] = 0.30,
		[ -5] = 0.18,
		[ -6] = 0.12,
		[ -7] = 0.05,
		[ -8] = 0.01,
		min = -8,
	}

	function scale_update(dl)
		scale_level = scale_level + dl

		if font_size then
			scale_interval = 1.0 / font_size * 2
			scale_min = scale_interval * 2
		end
	if scale_level < scale_levels.min then
		scale_level = scale_levels.min
	end
	local scl = scale_levels[scale_level]
	if scl then
		scale = scl
	else
		scale = 1.0 + scale_level * scale_interval


		local at_max = false
		if scale < scale_min then
			scale = scale_min
			scale_level = (scale_min - 1.0) / scale_interval
		elseif scale > scale_max then
			scale = scale_max
			scale_level = 0
			at_max = true
		end
	end
		scale_inv = 1.0/scale
		if camera.scale_level ~= scale_level then
			camera.scale_level = scale_level
			if scale_level <= 0 then
				local ra = camera.scale_resize_anchor_cs or wall.resize_anchor_cs
				camera.scale_resize_anchor_cs = ra
				--log.resize_scale("%.2f * %.2f = %.2f", ra, scale_inv, ra * scale_inv)
				wall.resize_anchor_cs = scale_level == 0 and ra or ra * scale_inv
			end

		end
	end

end
--}}} CREATE function scale_level

--{{{ INPUT STATE TABLE
local input_state = {
	mouse_msg = "hover",

	action = false,

	active = false,
	active_hold = false,
	active_resize = "",
	active_on_wall = false,
	active_is_focused = false,
	active_editing = false,
	active_waypoint = false,

	--DOUBLE CLICKING
	double = false,
	double_x = 0,
	double_y = 0,

	grab = false,
	grab_x = 0,
	grab_y = 0,
	grab_w = 0,
	grab_h = 0,
	grab_w_total = 0,
	grab_h_total = 0,
	grab_last_x = 0,
	grab_last_y = 0,
	grab_curr_x = 0,
	grab_curr_y = 0,

	rectangle_select = false,
	rectangle_collide = false,

	note_new = false,
	note_edit = false,
	note_update = false,
	note_move = false,
	note_moved = false,
	note_resize = false,
	note_resize_dx = false,
	note_resize_dy = false,
	note_resize_iw = false,
	note_resize_ih = false,
	note_resized = false,
	note_highlight = false,
	note_hi_toggle = false,
	note_hi_clear = false,
	note_task_toggle = false,

	--camera movement is based on *unscaled* mouse position change
	camera_update = false,
	camera_move = false,
	camera_moved = false,

	waypoint_primed = false,
	waypoint_activate = false,

	line_add_second_node = false
}

--}}} INPUT STATE TABLE

--{{{ TIMERS TABLE
local timers = {
	defaults = {},
	count = 0,
	queue = {count = -1},
	set = function (self, name, default)
		default = tonumber(default) or false
		if type(self[name]) == "nil" then
			local c = self.count + 1
			self.count = c
			self[c] = name
			self.defaults[name] = default
		else
			if default then
				self.defaults[name] = default
			else
				default = self.defaults[name]
			end
		end
		if default then
			local c = self.queue.count + 2
			self.queue.count = c
			self.queue[c] = name; self.queue[c+1] = default
		end
		--log.timer("%s QUEUED to %.2f", name, default or 0)
		return true
	end;
	reset = function (self, name)
		self[name] = self.defaults[name]
	end;
	stop = function (self, name)
		self[name] = false
		--log.timer("%s STOPPED", name)
	end;
	update = function (self, dt)
		for i = 1, self.count do
			local name = self[i]
			local time = self[name]
			if time then
				time = time - dt
				if time <= 0 then
					time = false
				end
				self[name] = time
				--if not time then
				--	log.timer("%s EXPIRED", name)
				--end
			end
		end
		local q = self.queue
		for i = 1, q.count, 2 do
			self[q[i]] = q[i+1]
			--log.timer("%s SET to %.2f", q[i], q[i+1] or 0)
		end
		q.count = -1
	end;
}
--}}} TIMERS TABLE

 --{{{ clipboard [ TABLE ] & [ functions ]
local clipboard = {
	count = 0,
	[1] = {},
	notes = {},
	system = "",
	char_width = 0,
	dx = 0,
	dy = 0,
	syscliptext = love.system.getClipboardText,
	gettext = function(self)
		local str = string.gsub(self.syscliptext(), "\r\n", "\n")
		return str
	end,
}

--}}}


 --{{{ dialog [ TABLE ] & [ functions ]
local dialog = {
	item = {},
	font = false,--lg.newFont("assets/" .. font_name, floor(font_size * 2.0)),
	setup_font = function(self)
		self.font = lg.newFont("assets/" .. font_name, floor(font_size * 2.0))
	end,

	count = 0,
	[1] = {
		type = "NONE",
		msg = "",
		rendered = "",
	},
	types = {
		YESNO = true,
		OKAY = true,
		YESNOCANCEL = true,
	},
}


function dialog:reset(msg) --{{{
	local id = 1 --dialog.item[msg]
	local box = dialog[id]
	box.type = "NONE"
	box.render = false
	dialog.click = false
	dialog.pressed = false
	dialog.release = false
	dialog.action = false
	screen_text_render = true
end --}}}
function dialog:msg(msg, new_type) --{{{
	local id = 1 --dialog.item[msg]
	local box = dialog[id]
	if not box or box.type == "NONE" then
		box = box or {}
		if self.types[new_type] then
			box.type = new_type
		end
		local xdiv = 6
		local ydiv = 4
		box.msg = msg
		box.render = true
		box.mouse_x = dialog.mouse_x
		box.mouse_y = dialog.mouse_y
		box.x = (lg.getWidth() / xdiv)
		box.y = (lg.getHeight() / ydiv)
		local xspc = .12 * box.x
		local yspc = .23 * box.y
		box.w = box.x * (xdiv - 2)
		box.h = box.y * (ydiv - 2)
		box.msg_x = box.x + (box.w * 0.5) - (dialog.font:getWidth(msg) * 0.5)
		box.msg_y = box.y + (box.h / ydiv)

		local bt = box.type
		if     bt == "YESNO" then
			box.selected = "YES"
			local btn = box.yes or {}
			if not box.yes then
				box.yes = btn
			end
			btn.title = "Yes"
			btn.w = box.w / xdiv
			btn.h = box.h / ydiv
			btn.x = (box.x + box.w) - 2 * (btn.w + xspc)
			btn.y = (box.y + box.h) - (btn.h + yspc)
			btn.xo = (btn.w * 0.5) - (dialog.font:getWidth(btn.title) * 0.5)
			btn.yo = (btn.h * 0.5) - (dialog.font:getHeight(btn.title) * 0.5)

			btn = box.no or {}
			if not box.no then
				box.no = btn
			end
			btn.title = "No"
			btn.w = box.w / xdiv
			btn.h = box.h / ydiv
			btn.x = box.x + (btn.w + xspc)
			btn.y = (box.y + box.h) - (btn.h + yspc)
			btn.xo = (btn.w * 0.5) - (dialog.font:getWidth(btn.title) * 0.5)
			btn.yo = (btn.h * 0.5) - (dialog.font:getHeight(btn.title) * 0.5)
		elseif bt == "OKAY" then
		elseif bt == "YESNOCANCEL" then
		end
	end
	local answer = false
	if  not dialog.click and
		dialog.mouse_x == box.mouse_x and
		dialog.mouse_y == box.mouse_y
	then
		--mouse hasn't moved since dialog opened, ignore
		return
	else
		box.mouse_x = false
		box.mouse_y = false
	end
	local bt = box.type
	if     bt == "YESNO" then
		local x = dialog.mouse_x
		local y = dialog.mouse_y
		local btn, ans = box.yes, "YES"
		for i = 1, 2 do
			if i == 2 then btn, ans = box.no, "NO" end
			if  btn.x <= x and btn.x + btn.w > x and
				btn.y <= y and btn.y + btn.h > y
			then
				box.selected = ans
				answer = ans
				break
			end
		end
	elseif bt == "OKAY" then
	elseif bt == "YESNOCANCEL" then
	end
	if dialog.click then dialog.action = answer end
	if dialog.released then
		if dialog.action == answer then
			return answer
		else
			dialog.action = false
		end
	end
end--}}}
--}}}

--{{{ love.handlers [ filedropped | refresh | quit | resize ]
function love.handlers.filedropped(file)
	local fname = file:getFilename()
	local s, e, ext = string.find(fname, "%.(%w+)$")
	ext = ext and string.lower(ext)
	if ext == "gif" then
		print("GIF!")
	elseif ext == "png" then
		print("PNG!")
		wall:load_image_file(file)
	elseif ext == "jpg" or ext == "jpeg" then
		print("JPEG!")
		wall:load_image_file(file)
	elseif ext == "link" then
		link_file = file
		link_file_data.load_file = true
		link_file_data.old_fullname = link_file_data.fullname
		link_file_data.fullname = nil
	else
		print("UNKNOWN!", fname, ext)
	end
end

local REFRESH_THE_GAME_PLEASE = false
function love.handlers.refresh()
	REFRESH_THE_GAME_PLEASE = true
end

local QUIT_THE_GAME_PLEASE = false
function love.handlers.quit()
	if love.audio then
		love.audio.stop()
	end

	print("Quiting " .. hal_conf.version)
	QUIT_THE_GAME_PLEASE = true
end

function love.handlers.resize(w,h)
	--print("resizing", w, h)
	canvas = lg.newCanvas()
	screen_text_render = true
	local lws = love_window_settings
	lws.current_w = w
	lws.current_h = h
	lws.current_hw = w * 0.5
	lws.current_hh = h * 0.5
end
function love.handlers.move(x, y, di)
	--print("moving  ", x, y, di)
	local lws = love_window_settings
	lws.current_x = x
	lws.current_y = y
	lws.current_display = di
	screen_text_render = true
end
--}}} love.handlers

 --{{{ render_wall table
local render_wall = {
	count = 0,
	x = {},
	y = {},
	w = {},
	h = {},
	note = {},
	task = {},
	heading = {},
	image = {},
	image_scale = {},
	image_rotate = {},
	image_offx = {},
	image_offy = {},
	default_note = {""},
	cam_lx = 0,
	cam_ly = 0,
	scale_last = scale_level,
	waypoint = {
		x = {},
		y = {},
		r = {},
		next = {},
		last = {},
	},
}
--}}}

---- PROFILE ----- {{{
local profile = require "debug.Profile"
do
	local p = profile
	p.set.update(p("inside_update",     "   Int. Update"))
	p.set.update(p("update_0",          "   update setup"))
	p.set.update(p("ls_link",           "     load/save"))
	p.set.update(p("update_state1",     "     state 1"))
	p.set.update(p("update_mouse",      "     mapos update"))
	p.set.update(p("wall_find",         "   wall find"))
	p.set.update(p("update_1",          "   update 1"))
	p.set.update(p("update_2",          "   update 2"))
	p.set.update(p("setup_render_wall", "   update rndr_wall"))
	p.set.update(p("find_1",            "      #1"))
	p.set.update(p("find_2",            "      #2"))
	p.set.update(p("find_3",            "      #3"))
	p.set.update(p("draw_grid",         "     draw grid"))
	p.set.render(p("render_canvas",     "   render canvas"))
	p.set.render(p("render_edit_mode",  "   render editmode"))
	p.set.render(p("render_status",     "   render status"))
end
--}}}


-------------------------------------------------------------------
--                                                               --
--                                                               --
--                  Initialize                                   --
--                                                               --
--                                                               --
-------------------------------------------------------------------
local function initialize(arg) --{{{
	print("Initializing ".. hal_conf.version)
	if not(love.window and love.graphics) then
		error("Program cannot run without graphics!")
	end

	local link_loaded = false

do
	local err = ""
	love.filesystem.createDirectory(hal_conf.savedir)
	do
		local lfs = love.filesystem
		local info = link_file_data.dummy_table
		info = lfs.getInfo(link_file_data.working, info)
		if not info then
			--working file doesn't exist, check to see if we're migrating
			info = lfs.getInfo(link_file_data.old_save_dir, info)
			local data, size
			local good, msg
			if info then
				-- migrate from old link dir to new one
				print("MIGRATING!")
				data, size = lfs.read(link_file_data.old_save_working)
				good, msg = lfs.write(link_file_data.working, data, size)
				if not good then
					print("ERROR writing to new save directory:", msg)
				end
				data, size = lfs.read(link_file_data.old_save_default)
				good, msg = lfs.write(link_file_data.default_link, data, size)
				if not good then
					print("ERROR writing to new save directory:", msg)
				end
			end
		end
	end
	local load_file = trim(love.filesystem.read(link_file_data.working))
	if load_file then
		--TODO: handle asserts/errors more gracefully
		link_file, err = io.open(load_file, "r")
		if not link_file then
			--TODO: w/assert() above, this block is never used
			local msg = sfmt("Unable to open \"%s\": %s", load_file, err)
			print(msg)
			--TODO: instead of set_status, impliment a dialog box
			--basically, as it stands, the next if block will load the default
			--project file if this one isn't found and this message will never
			--make it to the user
			set_status(msg)
		end
		link_file_data.fullname = load_file
	end
	if not link_file then
		link_file_data.fullname = table.concat({
			love.filesystem.getSaveDirectory(),
			hal_conf.savedir, "default.link"}, "/"
		)

		local saved_default = hal_conf.savedir .. "/default.link"
		print("loading from asset directory")
		local lf
		lf, err = love.filesystem.newFile(AG.assets.."/default.link", "r")
		if not lf then
			print("load default error", err)
		else
			print("saving default to save directory")
			love.filesystem.write(saved_default, lf:read())
			lf:close()
		end
		printf("opening %s\n", link_file_data.fullname)
		link_file, err = assert(io.open(link_file_data.fullname, "r"))
	end
	if not link_file then
		print("unable to load link file", err)
	else
		link_file_data.load_file = true
	end
end


	hal.input.initialize()

	hal.input.focus_clickthrough(true)

	edit_mode = hal.input.edit_mode()

	edit_line.data = "0xdeadbeef"
	edit_line.cursor = utf8.len(edit_line.data)

	wall.transaction:reset()

	camera.grabbed = false

	lg.setBackgroundColor(color.BG)
	lg.setColor(color.FG)

end--}}}

-------------------------------------------------------------------
--                                                               --
--                                                               --
--                       Update                                  --
--                                                               --
--                                                               --
-------------------------------------------------------------------


local function update(dt) --{{{
	profile.inside_update:start()
	local input = hal.input

	timers:update(dt)

	profile.update_0:start()
	profile.ls_link:start()
	--------------------------------------------------------------
	--                                                          --
	--                                                          --
do  --{{{          LOAD LINK and INITIALIZE                     --
	--                                                          --
	--                                                          --
	--------------------------------------------------------------

	local window_width, window_height
	local mode_change = not love.window.isOpen()
	local new_font_name, new_font_size = font_name, font_size
	local new_title

	if link_file_data.load_file then
		--{{{ LOAD FILE
		link_file_data.load_file = false

		local load_link_find_file_name = "[\\/]([^\\/]+)%.link$"
		local gamename = hal_conf.savedir or ""
		local loadname = gamename .. " loader"
		local lua_file = false
		local filepath
		local s, e, filename
		local ini_raw, ini_bytes
		local linkdata

		--{{{ INITIALIZE, VERIFY and LOAD linkdata

		if link_file_data.modified then
			set_status("Unsaved changes, cannot load file")
			goto load_error
		end
		if not link_file then
			printf("%s: No link file to load\n", loadname)
			goto load_error
		end
		if link_file_data.fullname then
			filepath = link_file_data.fullname
			lua_file = true
		else
			filepath = link_file:getFilename()
		end
		printf("%s: loading: %s\n", loadname, filepath)
		s, e, filename = filepath:find(load_link_find_file_name)
		if not filename then
			set_status("invalid file type, ignoring")
			printf("%s: invalid file type\n", loadname)
			goto load_error
		end
		if lua_file then
			ini_raw = link_file:read("*a")
			ini_bytes = #ini_raw
		else
			ini_raw, ini_bytes = link_file:read()
		end
		s, e = string.find(ini_raw, "%s*")
		print("ini_bytes, e", ini_bytes, e)
		if ini_bytes > e then
			--load data and parse
			linkdata = ini.parse(ini_raw, filename)
		else
			linkdata = { meta = {version = "new"}}
		end

		if not linkdata.meta then
			print("invalid file, ignoring")
			set_status("invalid file, ignoring")
			goto load_error
		end
		--TODO: make sure link file is compatable with current version of app
		--  for link_file_data.version == prototype, no further checks are done
		do
			local meta_ver = linkdata.meta.version
			if  meta_ver ~= "new" and
				meta_ver ~= link_file_data.version
			then
				printf("%s: invalid link file\n", loadname)
				goto load_error
			end
		end
		--}}} INITIALIZE, VERIFY and LOAD linkdata

		link_file_data.name = filename
		link_file_data.fullname = filepath

		if linkdata.meta.version == "new" then
			--{{{ EMPTY (NEW) FILE
			print("empty file, clearing data")
			camera.dx = 0
			camera.dy = 0
			scale_level = 0
			new_font_name = default_font_name
			new_font_size = default_font_size

			--}}}END: EMPTY (NEW) FILE
			goto load_success
		end


		------------------------------------------------------------------
		--      LOAD .link DATA                                         --
		------------------------------------------------------------------
		printf("%s: %s loaded. So far, so good!\n", loadname, filename)

		wall.linkdata = linkdata

		goto load_success

		--
		--   ERROR or SUCCESS?
		--

::load_error::
		link_file_data.fullname = link_file_data.old_fullname

		goto load_exit

::load_success::
		--scale_update after setting font_size
		scale_update(0)

		love.filesystem.write(link_file_data.working, link_file_data.fullname)
		set_status("Loaded: " .. link_file_data.fullname)
		printf("%s: Complete! Loaded, %s\n", loadname, filename)
		wall.files:enqueue("link", link_file_data.fullname)
		wall.files:update()

		new_title = link_file_data.name .. "  — " .. hal_conf.version
		if canvas then
			love.window.setTitle(new_title)
		end

		wall.transaction:queue(sfmt("CLEAR %d items", wall.count))
		for i = 1, wall.count do
			local item = wall[i]
			wall.transaction:queue("CLEAR", item)
		end
		wall:clear_focused()
		wall.count = 0
		--}}} End: clear wall

		goto load_exit

::load_exit::
		screen_text_render = true --force canvas to be updated

		--}}} LOAD FILE
	end

	if wall.linkdata then
		--{{{ LOAD LINK META DATA (camera, window size, scale, font)
		local linkdata = wall.linkdata

		local ld = linkdata
		local w, h, flags
		local ow_w, ow_h
		if not love.window.isOpen() then
			w = love_window_settings.width
			h = love_window_settings.height
		else
			ow_w, ow_h = love.window.getMode()
		end
		if ld.camera.w and ld.camera.h then
			if ld.camera.w ~= w or ld.camera.h ~= h then
				w = ld.camera.w
				h = ld.camera.h
			end
		end
		window_width = w
		window_height = h
		if not ow_w or ow_w ~= w or ow_h ~= h then
			canvas = false
			mode_change = true
		end

		camera.dx = ld.camera.dx
		camera.dy = ld.camera.dy
		scale_level = ld.camera.scale
		local info = love.filesystem.getInfo(
			"assets/".. ld.font.name,
			link_file_data.dummy_table
		)
		if info then
			new_font_name = ld.font.name
			new_font_size = ld.font.size
		else
			print("File not found, not changing font")
		end
		--}}} LOAD LINK META DATA (camera, window size, scale, font)
	end
	--
	-- {{{ Initialize canvas and font if necessary
	--
	if not canvas then
		if not window_width then
			window_width = love_window_settings.width
			window_height = love_window_settings.height
		end
		if mode_change then
			love.window.setMode(window_width, window_height, love_window_settings.flags)
		end
		new_title = new_title or hal_conf.version
		love.window.setTitle(new_title)
		if not love_window_settings.icon_data then
			local data = love.image.newImageData(love_window_settings.icon_path)
			if data then
				love_window_settings.icon_data = data
				love.window.setIcon(data)
			end
		end

		love.handlers.resize(window_width, window_height)
		love.handlers.move(love.window.getPosition())
		canvas = lg.newCanvas()
		hal.canvas = canvas
	end

	if new_font_name ~= font_name or new_font_size ~= font_size then
		font_name = new_font_name
		font_size = new_font_size
		font = false --reset font
	end
	if not font then
		font = lg.setNewFont("assets/" .. font_name, font_size)
		edit_line.font_h1 = lg.newFont("assets/"..font_name, font_size * theme.h1_multi)

		for i = 1, #fonts.name_full do
			if fonts.name_full[i] == font_name then
				local tfo = fonts.type[i]
				fonts.type_face_option = tfo
				if tfo == "serif" then
					theme.autowrap = theme.autowrap_serif
				elseif tfo == "fixed" then
					theme.autowrap = theme.autowrap_fixed
				end
				break
			end
		end
		fonts.astrisk_width = font:getWidth("*")

		scale_update(0)
		wall:set_cell_size()
		dialog:setup_font()

		wall.screen_text = lg.newText(font)
		edit_line.h1_text = lg.newText(edit_line.font_h1)

	end
	--
	-- }}} Initialize canvas and font if necessary
	--
	if wall.linkdata then

		--{{{ CREATE ENTITY and COMPONENT TABLES
		local Component = wall.Component
		wall.items = {}
		wall.items.entity = wall.Entity()
		wall.items.scene = Component("pid")
		wall.items.positions = Component("x", "y")
		wall.items.geometries = Component("w", "h")
		wall.items.tables = Component("table", "type")
		--}}} CREATE ENTITY and COMPONENT TABLES

		--{{{ LOAD LINKDATA into PROGRAM
		local linkdata = wall.linkdata

		if linkdata.waypoint then
			--{{{ LOAD WAYPOINT DATA
			wall.transaction:queue(sfmt("LOAD %d waypoints", #linkdata.waypoint))
			for i = 1, #linkdata.waypoint do
				local n = linkdata.waypoint[i]
				local item_note_raw
				do
					local item_note = wall.load_note_from_string(n.note)
					item_note_raw = assert(table.concat(item_note, "\n"))
				end
				do
					local lt = wall.transaction:get_load_table()
					local c
					c = 1; lt[c] = "x";          lt[c+1] = n.x
					c=c+2; lt[c] = "y";          lt[c+1] = n.y
					c=c+2; lt[c] = "r";          lt[c+1] = wall.waypoint_radius
					c=c+2; lt[c] = "created";    lt[c+1] = n.created
					c=c+2; lt[c] = "type";       lt[c+1] = "waypoint"
					c=c+2; lt[c] = "task";       lt[c+1] = false
					c=c+2; lt[c] = "note_raw";   lt[c+1] = item_note_raw
					lt.count = c
					wall.transaction:queue("LOAD", lt)
				end
			end
			--}}} LOAD WAYPOINT DATA
		end
		if linkdata.note then
			--{{{ LOAD NOTE DATA
			wall.transaction:queue(sfmt("LOAD %d notes", #linkdata.note))
			for i = 1, #linkdata.note do
				local n = linkdata.note[i]

				local item_wrap_limit
				if n.wrap then
					local s,e, num = string.find(n.wrap, theme.find_autowrap_px)
					item_wrap_limit = wall:get_wrap_limit_minimum(tonumber(num))
				elseif n.w then
					--remove 1 from width for border
					item_wrap_limit = (n.w - 1) * wall.cell_size
				else
					item_wrap_limit = false
				end
				local item_note_raw
				local item_note
				do
					item_note = wall.load_note_from_string(n.note)
					item_note_raw = assert(table.concat(item_note, "\n"))
				end
				do
					local lt = wall.transaction:get_load_table()
					local c
					c = 1; lt[c] = "x";          lt[c+1] = n.x
					c=c+2; lt[c] = "y";          lt[c+1] = n.y
					c=c+2; lt[c] = "w";          lt[c+1] = n.w
					c=c+2; lt[c] = "h";          lt[c+1] = n.h
					c=c+2; lt[c] = "_auto_size"; lt[c+1] = not n.h
					c=c+2; lt[c] = "created";    lt[c+1] = n.created
					c=c+2; lt[c] = "type";       lt[c+1] = "note"
					c=c+2; lt[c] = "task";       lt[c+1] = n.task or false
					c=c+2; lt[c] = "wrap_limit"; lt[c+1] = item_wrap_limit
					c=c+2; lt[c] = "note_raw";   lt[c+1] = item_note_raw
					lt.count = c
					wall.transaction:queue("LOAD", lt)
				end
			end
			--}}} LOAD NOTE DATA
		end
		wall.linkdata = false
		wall.transaction:queue("LOADED", true)
		 --}}} LOAD LINKDATA into PROGRAM
	end

end --}}} END: LOAD LINK
	--                                                          --
	--                                                          --
	--------------------------------------------------------------

	--------------------------------------------------------
	--                                                    --
	--                                                    --
	--{{{                 SAVE LINK                       --
	--                                                    --
	--                                                    --
	--------------------------------------------------------
	if input.ctrl and input.save == "pressed" then
		wall:exit_edit_mode()
		wall:clear_focused()
		wall.transaction:queue(sfmt("SAVE %d items", wall.count))
		local version = hal_conf.version
		local wall = wall
		local camera = camera
		local font_name = font_name
		local font_size = font_size
		local scale = scale_level

		if not link_file_data.fullname then
			set_status("Cannot save: no file to save.")
		else
			local save = {}
			local ti = table.insert
			local sf = sfmt
			ti(save, sf("; Generated by %s", version))
			ti(save, "[meta]")
			ti(save, sf("version = %s", link_file_data.version))
			ti(save, "[camera]")
			ti(save, sf("w = %d", lg.getWidth()))
			ti(save, sf("h = %d", lg.getHeight()))
			ti(save, sf("dx = %d", camera.dx))
			ti(save, sf("dy = %d", camera.dy))
			ti(save, sf("scale = %d", scale_level))
			ti(save, "[font]")
			ti(save, sf("name = %s", font_name))
			ti(save, sf("size = %d", font_size))

			local notes = {}
			local waypoints = {}
			for i = 1, wall.count do
				local item = wall[i]
				--item.discard is mainly for internal use/programmically created notes
				if not item.discard then
					if item and item.type == "waypoint" then
						ti(waypoints, item)
					elseif item then
						ti(notes, item)
					end
				end
			end

			local c

			c = 0
			for i = 1, #notes do
				--{{{ SAVE NOTES
				local item = notes[i]
				c = c + 1
				ti(save, sf("[note.%d]", c))
				--if readonly was explicitly set (ie. not nil) save it
				if type(item.readonly) == "boolean" then
					ti(save, sf("readonly = %s", item.readonly))
				end
				ti(save, sf("x = %d", item.x))
				ti(save, sf("y = %d", item.y))
				if item.wrap_limit or item.image then
					local w = item.w
					if item._auto_size then
						local min = wall:get_wrap_limit_minimum(item.wrap_limit)
						--add one to width for border
						w = ceil(min * wall.cell_inv) + 1
						log.save("#%d item.w: %d, wrap w: %d", i, item.w, w)
					end
					ti(save, sf("w = %d", w))
				end
				if not item._auto_size or item.image then
					ti(save, sf("h = %d", item.h))
				end
				if item.created then
					ti(save, sf("created = %s", item.created))
				else
					ti(save, sf("date = %s", item.date))
					ti(save, sf("time = %s", item.time))
				end
				ti(save, sf("note = %s", wall.save_note_to_string(item.note_raw)))
				if item.task then
					ti(save, sf("task = %s", item.task))
				end
				::continue::
				--}}} SAVE NOTES
			end

			c = 0
			for i = 1, #waypoints do
				--{{{ SAVE WAYPOINTS
				local item = waypoints[i]
				c = c + 1
				ti(save, sf("[waypoint.%d]", c))
				if type(item.readonly) == "boolean" then
					ti(save, sf("readonly = %s", item.readonly))
				end
				ti(save, sf("x = %d", item.x))
				ti(save, sf("y = %d", item.y))
				if item.created then
					ti(save, sf("created = %s", item.created))
				end
				local note = item.note_raw
				if item.line then
					note = sfmt(":line %d, %d", item.line.x, item.line.y)
				end
				ti(save, sf("note = %s", wall.save_note_to_string(note)))
				--}}} SAVE WAYPOINTS
			end


			print("    -> Saving " .. version)
			local save_data = table.concat(save, "\n") .. "\n"
			local f, msg = io.open(link_file_data.fullname, "w")
			local error_lock = "The requested operation cannot be performed on a file with a user-mapped section open."

			if msg then
				local s, e, m = msg:find"^([^\r\n]*)"
				msg = m or "YOU SHOULDN'T SEE THIS!"
			end
			if msg == error_lock then
				msg = "Cannot save already open file."
			end
			if f then
				--print(save_data)
				assert(f:write(save_data))
				f:close()
				link_file_data.modified = false
				set_status("Saved: ".. link_file_data.fullname)
			else
				set_status(msg)
				print("ERROR: "..msg)
			end
		end
	end
	--------------------------------------------------------
	--                                                    --
	--                                                    --
	--}}}                 SAVE LINK                       --
	--                                                    --
	--                                                    --
	--------------------------------------------------------
	profile.ls_link:lap()

	--------------------------------------------------------
	--                                                    --
	--                                                    --
	if REFRESH_THE_GAME_PLEASE then --{{{
		if status_message.text == theme.status_esc_menu then
			status_message.text = false
		end
		local msg = "Reload?"
		if link_file_data.modified then
			msg = "Discard all unsaved work?"
		end
		--dialog.mouse_x, dialog.mouse_y = mapos.x, mapos.y
		do
			local ima = input.mouse.absolute
			dialog.mouse_x, dialog.mouse_y = ima.x, ima.y
		end
		dialog.released = false
		dialog.click = input.mouse_click == "pressed"
		if input.mouse_click then
			dialog.pressed = true
		else
			if dialog.pressed then
				dialog.released = true
			end
			dialog.pressed = false
		end
		local ans = dialog:msg(msg, "YESNO")
		if not ans then
			local box = dialog[1]
			if input.esc == "pressed" then
				ans = "NO"
			end
			if input.enter == "pressed" then
				ans = box.selected
			end
			if input.left == "pressed" and box.selected == "YES" then
				box.selected = "NO"
			end
			if input.right == "pressed" and box.selected == "NO" then
				box.selected = "YES"
			end
		end
		if     ans == "YES" then
			love.event.push("reload")
		elseif ans == "NO" then
			REFRESH_THE_GAME_PLEASE = false
			dialog:reset(msg)
		else --  WAITING
			return
		end
	end --}}}
	if QUIT_THE_GAME_PLEASE then --{{{
		local msg = "Quit?"
		if not link_file_data.modified then
			error("QUIT_THE_GAME_PLEASE")
		else
			msg = "Discard all unsaved work?"
		end
		--dialog.mouse_x, dialog.mouse_y = mapos.x, mapos.y
		do
			local ima = input.mouse.absolute
			dialog.mouse_x, dialog.mouse_y = ima.x, ima.y
		end
		dialog.released = false
		dialog.click = input.mouse_click == "pressed"
		if input.mouse_click then
			dialog.pressed = true
		else
			if dialog.pressed then
				dialog.released = true
			end
			dialog.pressed = false
		end
		local ans = dialog:msg(msg, "YESNO")
		if not ans then
			local box = dialog[1]
			if input.esc == "pressed" then
				ans = "NO"
			end
			if input.enter == "pressed" then
				ans = box.selected
			end
			if input.left == "pressed" and box.selected == "YES" then
				box.selected = "NO"
			end
			if input.right == "pressed" and box.selected == "NO" then
				box.selected = "YES"
			end
		end

		if ans == "YES" then
			if not love.quit or love.quit() then
				error("QUIT_THE_GAME_PLEASE")
			end
		elseif ans == "NO" then
			QUIT_THE_GAME_PLEASE = false
			dialog:reset(msg)
		else
			return
		end
	end --}}}
	--                                                    --
	--                                                    --
	--------------------------------------------------------

	-------------------------------------------------------------
	--                                                         --
	--                                                         --
	--              NEW UPDATE STATE                           --
	--                                                         --
	--                                                         --
	--{{{update window position
	do
		local lws = love_window_settings
		lws.update_timer = lws.update_timer - dt
		if lws.update_timer <= 0 then
			lws.update_timer = random() * 0.5 + 0.50
			local x,y,di = love.window.getPosition()
			if lws.current_x ~= x or lws.current_y ~= y or lws.current_display ~= di then
				love.handlers.move(x, y, di)
			end
		end
	end
	--}}}update window position

	profile.update_state1:start()
	--{{{ MOVE CAMERA
	if camera.move_to_x then
		local x1, y1
		if not camera.start_from_x then
			camera.start_from_x = camera.dx
			camera.start_from_y = camera.dy
			camera.step = 0
			--local cs = wall.cell_size
			--print("start", camera.start_from_x, camera.start_from_y,
			--	camera.start_from_x/cs, camera.start_from_y/cs)
			--print("move", camera.move_to_x, camera.move_to_y,
			--	camera.move_to_x/cs, camera.move_to_y/cs)
		end
		local x1 = camera.start_from_x
		local y1 = camera.start_from_y
		local x2 = camera.move_to_x
		local y2 = camera.move_to_y

		local step = camera.step + camera.step_interval
		if step >= 1 then
			step = 1
			camera.move_to_x = false
			camera.start_from_x = false
		end
		camera.step = step
		--printf("move_to %d,%d %d,%d, slope: %.4f, step: %.2f\n", x1, y1, x2, y2, m, step)

		--print("xstep", (x1 * (1 - step)), (x2 * step))
		--print("ystep", (y1 * (1 - step)), (y2 * step))
		camera.dx = (x1 * (1 - step)) + (x2 * step)
		camera.dy = y1 * (1 - step) + y2 * step
		--print("camera change",
		--	camera.dx, camera.dy,
		--	camera.dx / cs, camera.dy / cs
		--)
	end
	--}}} MOVE CAMERA
	profile.update_state1:lap()
	--
	--SETUP: MAPOS (World Position) and CELL--{{{
	if input.processed then
		profile.update_mouse:start()
		--mapos would probably better be described as world position
		mapos = input.mouse.absolute * scale_inv
		do
			local hw = love_window_settings.current_hw
			local hh = love_window_settings.current_hh
			--local w,h = lg.getDimensions()
			mapos.x = floor(mapos.x) -
				(hw * (scale_inv - 1.0)) - camera.dx
			mapos.y = floor(mapos.y) -
				(hh * (scale_inv - 1.0)) - camera.dy
			cell.xf = mapos.x * wall.cell_inv
			cell.yf = mapos.y * wall.cell_inv
			cell.x = floor(cell.xf)
			cell.y = floor(cell.yf)
		end

		profile.update_mouse:lap()
	end
	--}}}

	if status_message.time then --{{{ update
		status_message.time = status_message.time - dt
		if status_message.time < 0 then
			screen_text_render = true
			status_message.text = false
			status_message.time = false
		end
	end --}}}

if input.processed then

	--{{{ ESCAPE KEY pressed (or "Ctrl+[")
	if  input.esc == "pressed" or
		(input.ctrl and input.left_bracket == "pressed")
	then
		screen_text_render = true
		if edit_mode then
			wall.transaction:queue("EXIT", wall.selected)
		else
			if #wall.focused > 0 then
				wall:clear_focused()
			else
				camera.dx = 0
				camera.dy = 0
			end
		end
		set_status(theme.status_esc_menu, 1.8)
	end
	 --}}}
	--{{{ DEBUG_MENU KEY pressed
	if input.debug_menu == "pressed" then
		screen_text_render = true
	end
	--}}} DEBUG_MENU key pressed
	profile.update_0:lap()
	--                                                         --
	--                                                         --
	-------------------------------------------------------------

	--------------------------------------------------------
	--                                                    --
	--                                                    --
	--{{{      FIND WALL COLLISIONS — set wall.hover      --
	--                                                    --
	--                                                    --
	--------------------------------------------------------

	--check to see if the currently selected note has changed size/position
	--this can happen without the mouse moving
	if edit_mode and wall.selected then
		--TODO: COPY/PASTED above
		local wi = wall[wall.selected]
		local itype = wi.type
		if itype == "note" then
			local x, y = cell.x, cell.y
			if  wi.x <= x and wi.x + wi.w > x and
				wi.y <= y and wi.y + wi.h > y
			then
				wall.hover = wall.selected
			end
		end
	end

	--only update wall.hover if mouse position has changed
	if
		wall.find_last_mouse_x ~= mapos.x or
		wall.find_last_mouse_y ~= mapos.y
	then
	if  abs(wall.find_last_mouse_x - mapos.x) > 1 or
		abs(wall.find_last_mouse_y - mapos.y) > 1
	then
		wall.mouse_hide_is_typing = false
	end
	profile.wall_find:start()
	wall.find_last_mouse_x = mapos.x
	wall.find_last_mouse_y = mapos.y

	wall.hover = 0
	local old_resize = wall.resize
	wall.resize = 0
	if edit_mode and wall.waypoint_button_x then
		wall.waypoint_button_state = false
		--COPY/PASTED in wall.hover == 0
		local cs = wall.cell_size
		local wx, wy = wall.waypoint_button_x, wall.waypoint_button_y
		local dist = camera.distance(mapos.x, mapos.y, wx * cs, wy * cs)
		if dist <= cs then
			wall.hover = wall.selected
			wall.waypoint_button_state = "hover"
			--set_status("WAYPOINT RELEASED!!!!", 1)
		end
	end
	if wall.hover == 0 then
		local wis = wall.items
		local wi_x = wis.positions.x
		local wi_y = wis.positions.y
		local wi_w = wis.geometries.w
		local wi_h = wis.geometries.h
		local wi_item = wis.tables.table
		local wi_type = wis.tables.type

		local wall_ptr = 0
		for i = 1, #wi_type do
			local item_id = i

			local wi = wi_item[i]
			local itype = wi_type[i]

			--TODO: COPY/PASTED above
			if itype == "note" then
				local wx,wy,ww,wh = wi_x[i], wi_y[i], wi_w[i], wi_h[i]
				local focused = wi._focused
				if focused then
					local ra = wall.resize_anchor_cs
					wx = wx - ra
					wy = wy - ra
					ww = ww + ra * 2
					wh = wh + ra * 2
				end
				local x, y = cell.xf, cell.yf
				if  wx <= x and wx + ww > x and
					wy <= y and wy + wh > y
				then
					for k = 1, wall.count do
						if wall[k] == wi then
							wall_ptr = k
							break
						end
					end
					if focused then
						local rx = x - wx
						local ry = y - wy
						local rw = ww - rx
						local rh = wh - ry
						local hz = wall.resize_anchor_cs --hotzone

						local hz_mul = hz * 2.5 * 2
						--print("wi.h, hz_mul", wi.h, hz_mul)
						local extrax = wi_w[i] <= hz_mul and wi_w[i] * 0.4 or hz
						local extray = wi_h[i] <= hz_mul and wi_h[i] * 0.1 or hz
						local extrax_2 = hz + extrax * 0.25
						local extray_2 = hz + extray * 0.25
						extrax = hz + extrax
						extray = hz + extray

						local resize = false
						--log.info("rx:%.2f hze:%.2f hze2:%.2f; ry:%.2f hze:%.2f hze2:%.2f",
						--	rx, extrax, extrax_2,
						--	ry, extray, extray_2
						--)
						if    (rx < extrax   and ry < extray_2) or
							  (rx < extrax_2 and ry < extray)
						then
							resize = "nw"
						elseif(rx < extrax   and rh < extray_2) or
							  (rx < extrax_2 and rh < extray)
						then
							resize = "sw"
						elseif(rw < extrax   and ry < extray_2) or
							  (rw < extrax_2 and ry < extray)
						then
							resize = "ne"
						elseif(rw < extrax   and rh < extray_2) or
							  (rw < extrax_2 and rh < extray)
						then
							resize = "se"
						elseif rx < hz then
							resize = "w"
						elseif rw < hz then
							resize = "e"
						elseif ry < hz then
							resize = "n"
						elseif rh < hz then
							resize = "s"
						else
							resize = false
						end

						if resize then
							wall.resize = wall_ptr
							wall.resize_side = resize
							--log.resize("#%d side %s", i, resize)
						end
					end
					wall.hover = wall_ptr

					--log.info("found #%d\tcount: %d", i, wall.count)
					break
				end
			elseif itype == "waypoint" then
				--COPY/PASTED in wall.hover == 0
				local offs = wall.waypoint_display_offset
				local cs = wi_w[i]
				local wx, wy = wi_x[i] + offs, wi_y[i] + offs
				local dist = camera.distance(mapos.x, mapos.y, wx * cs, wy * cs)
				if dist <= cs then
					local wall_ptr = 0
					for k = 1, wall.count do
						if wall[k] == wi then
							wall_ptr = k
							break
						end
					end
					wall.hover = wall_ptr
					break
				end
			end
		end
		--printf("%s (%d)    DONE!\n", current, current_c)
	end
	if old_resize ~= wall.resize then
		screen_text_render = true
	end
	profile.wall_find:lap()
end
	--}}}      END :      FIND WALL COLLISIONS            --
	--                                                    --
	--                                                    --
	--------------------------------------------------------

	profile.update_1:start()
	do
		--{{{ Update Mouse CURSOR ICON
		local mouse_type = "arrow"
		if wall.mouse_hide_is_typing then
			mouse_type = "hidden"
		elseif wall.hover > 0 then
			local item = wall[wall.hover]
			if item.type == "waypoint" then
				mouse_type = "hand"
			elseif wall.waypoint_button_state then
				mouse_type = "hand"
			elseif edit_mode and wall.selected == wall.hover then
				mouse_type = "ibeam"
			end
		end
		if wall.resize > 0 then
			local rs = wall.resize_side
			if rs == "n" or rs == "s" then
				mouse_type = "sizens"
			elseif rs == "e" or rs == "w" then
				mouse_type = "sizewe"
			elseif rs == "nw" or rs == "se" then
				mouse_type = "sizenwse"
			elseif rs == "ne" or rs == "sw" then
				mouse_type = "sizenesw"
			end
		end
		if wall.mouse_type ~= mouse_type then
			wall.mouse_type = mouse_type
			local visible = true
			if mouse_type == "hidden" then
				visible = false
			else
				love.mouse.setCursor(love.mouse.getSystemCursor(mouse_type))
			end
			if wall.mouse_visible ~= visible then
				--printf("MOUSE IS%s SEEN\n", visible and "" or " >NOT<")
				wall.mouse_visible = visible
				love.mouse.setVisible(visible)
			end
		end
		--}}} Update Mouse CURSOR ICON
	end


	--------------------------------------------------------
	--                                                    --
	--                                                    --
	--            INPUT STATE                             --
	--                                                    --
	--                                                    --
	--------------------------------------------------------

--{{{ INPUT STATE: SETUP | MOUSE
do
	-- INITIALIZE
	local mouse_object = wall.hover
	local mouse_msg = "hover"
	local imc = input.mouse_click
	if imc then
		mouse_msg = imc == "pressed" and "press" or "down"
	end
	local last = input_state.mouse_msg
	local active_hold = input_state.active_hold
	local active_resize = input_state.active_resize
	local active = active_hold == mouse_object and active_hold
	local double_click = timers.double_click and input_state.double

	local double_click_time_remain

	-- UPDATE
	if double_click then
		local ima = input.mouse.absolute
		local mp_x = ima.x - camera.dx
		local mp_y = ima.y - camera.dy
		local isdx, isdy = input_state.double_x, input_state.double_y
		if mp_x ~= isdx or mp_y ~= isdy then
			local dist = camera.distance(
				input_state.double_x, input_state.double_y,
				mp_x, mp_y
			)
			if dist > wall.cell_size then
				timers:stop("double_click")
				double_click = false
			end
		end
	end
	if mouse_msg == "press" then
		screen_text_render = true
		active = mouse_object
		active_hold = mouse_object
		active_resize = wall.resize > 0 and wall.resize_side

		if timers.double_click then
			if double_click == mouse_object then
				mouse_msg = "double"
				double_click_time_remain = timers.double_click
			end

			timers:stop("double_click")
			double_click = false
		else
			local ima = input.mouse.absolute
			local mp_x = ima.x - camera.dx
			local mp_y = ima.y - camera.dy
			double_click = mouse_object
			input_state.double_x = mp_x
			input_state.double_y = mp_y
			timers:set("double_click", theme.double_click_speed)
		end
	elseif mouse_msg == "down" then
	elseif
		mouse_msg == "hover" and
		(last == "down" or last == "press" or last == "double")
	then
		screen_text_render = true
		mouse_msg = active and "activate" or "release"
	elseif mouse_msg == "hover" then
		active = false
		active_hold = false
		active_resize = false
	end

	-- FINALIZE
	input_state.mouse_msg = mouse_msg
	input_state.active = active
	input_state.active_hold = active_hold
	input_state.active_resize = active_resize
	input_state.active_on_wall = active_hold == 0
	local ach_id = active_hold and active_hold > 0
	input_state.active_not_focused = ach_id and not wall[active_hold]._focused
	input_state.active_is_focused = ach_id and wall[active_hold]._focused
	input_state.active_editing = ach_id and edit_mode and wall.selected == active_hold
	input_state.active_waypoint = ach_id and wall[active_hold].type == "waypoint"
	input_state.double = double_click

	-- DEBUG PRINTING
	--if mouse_msg ~= "hover" or active then
	--	if mouse_msg == "double" then
	--		mouse_msg = sfmt("dbL%dms",
	--			(theme.double_click_speed - double_click_time_remain) * 1000
	--		)
	--	end
	--	log.mouse("%2d,%2s)%9s, %4sactive!, hold: %s",
	--		mouse_object, active_resize or "",
	--		mouse_msg, active and "" or "not ", active_hold
	--	)
	--end
end
--}}} INPUT STATE: SETUP | MOUSE
--{{{ INPUT STATE: GRAB
do
	local itype = "grab"
	local ins = input_state
	ins[itype] = ins.mouse_msg
	local istate = input_state[itype]
	if istate then
		local mouse = input.mouse.absolute
		local update_rectangle
		local update_note
		local update_resize
		local update_camera
		local update_finalize
		------ ![    HOVER     ]! --

		if istate == "press" or istate == "double" then
			if wall:hit_task_box(ins.active_hold, mapos.x, mapos.y) then
				ins.note_task_toggle = ins.active_hold
			end
			ins.rectangle_select = false
			ins.rectangle_collide = false
			ins.note_new = false
			ins.note_move = false
			ins.note_moved = false
			ins.camera_move = false
			ins.camera_moved = false
		end
		if     istate == "press" then
			-- ![    PRESS     ]! --
			local mx, my
			local action_str
			if ins.note_task_toggle then
				--noop
			elseif input.shift and not ins.active_editing then
				action_str = "AABB"
				ins.rectangle_select = true
				ins.rectangle_collide = false
				mx = cell.xf
				my = cell.yf
			elseif ins.active_is_focused then
				action_str = "NOTE "
				if ins.active_resize then
					ins.note_resize = ins.active_resize
					ins.note_resize_dx = false
					ins.note_resized = false
					action_str = sfmt("RESIZE|%s|",
						ins.active_resize and ins.active_resize or ""
					)
					mx = cell.xf
					my = cell.yf
				elseif not (edit_mode and wall.selected == ins.active_hold) then
					ins.note_move = true
					mx = cell.x
					my = cell.y
				end
			elseif ins.active_waypoint then
				action_str = sfmt("WAYPOINT #%d pressed", ins.active_hold)
				ins.waypoint_primed = true
				ins.waypoint_activate = false
				mx = cell.xf
				my = cell.yf
			elseif wall.waypoint_button_state then
				action_str = sfmt("WAYPOINT EXIT BUTTON #%d pressed", ins.active_hold)
				mx = cell.xf
				my = cell.yf
			elseif ins.active_on_wall or ins.active_not_focused then
				action_str = "CAMERA"
				ins.camera_move = true
				ins.camera_moved = false
				ins.line_add_second_node = false
				mx = mouse.x
				my = mouse.y
			end
			if mx then
				ins.grab_x = mx
				ins.grab_y = my
				ins.grab_last_x = mx
				ins.grab_last_y = my
				ins.grab_curr_x = mx
				ins.grab_curr_y = my
				ins.grab_w = 0
				ins.grab_h = 0
				log.grab("%s at %.2f, %.2f", action_str, mx, my)
			else
				log.grab("NOTHING HAPPENS")
			end

		elseif istate == "double" then
			-- ![ DOUBLE CLICK ]! --
			ins.grab_x = cell.x
			ins.grab_y = cell.y
			local nx, ny, ntype = 0, 0
			if ins.active == 0 then
				ins.note_new = true
				ntype = "NEW"
				nx = ins.grab_x
				ny = ins.grab_y
			elseif not ins.note_task_toggle then
				ins.note_edit = ins.active
				ntype = sfmt("EDIT#%d", ins.active)
				local item = wall[ins.active]
				nx = item.x
				ny = item.y
			end
			local cs = wall.cell_size
			log.grab("%6s at %d, %d →(*cs) %d, %d", ntype, nx, ny, nx * cs, ny * cs)

		elseif istate == "down" then
			-- ![     DOWN     ]! --
			update_rectangle = ins.rectangle_select
			update_note = ins.note_move
			update_resize = ins.note_resize
			update_camera = ins.camera_move
			update_finalize = update_rectangle or update_note or update_resize or update_camera

		elseif istate == "activate" then
			-- ![   ACTIVATE   ]! --
			if wall:hit_task_box(ins.active_hold, mapos.x, mapos.y)
				or ins.note_resize or ins.active_editing
			then
				--noop
			elseif ins.active_hold > 0 then
				if input.shift then
					ins.note_hi_toggle = ins.active_hold
				else
					if ins.active_waypoint and ins.waypoint_primed then
						log.grab("WAYPOINT #%d activated", ins.active_hold)
						ins.waypoint_activate = ins.active_hold
						ins.waypoint_primed = false
					elseif wall.waypoint_button_state then
						log.grab("WAYPOINT EXIT BUTTON activated for #%d", wall.selected)
						wall.transaction:queue("EXIT", wall.selected)
					elseif wall.selected ~= ins.active_hold then
						ins.note_highlight = ins.active_hold
					end
				end
			else
				if lines.x1 then
					ins.line_add_second_node = true
				else
					ins.note_hi_clear = wall.selected
				end
			end

		--[[]] istate = "release" end
		if istate == "release" then
			-- ![   RELEASE    ]! --
			update_rectangle = ins.rectangle_select
			update_note = ins.note_move
			update_resize = ins.note_resize
			update_camera = ins.camera_move
			update_finalize = update_rectangle or update_note or update_resize or update_camera

			ins.grab = false
		end


		if update_finalize then
			local dx, dy, dupdate
			local mx, my
			if update_rectangle then
				mx, my = cell.xf, cell.yf
			elseif update_camera then
				mx, my = mouse.x, mouse.y
			elseif update_note then
				mx, my = cell.x, cell.y
			elseif update_resize then
				mx, my = cell.xf, cell.yf
			end

			if not mx then
				dx, dy = 0, 0
			else
				ins.grab_curr_x = mx
				ins.grab_curr_y = my
				dx = mx - ins.grab_last_x
				dy = my - ins.grab_last_y
			end
			dupdate = dx ~= 0 or dy ~= 0

			if istate == "release" then
				local mvx, mvy, mupdate
				if not update_rectangle then
					if not mx then
						mvx = 0
						mvy = 0
					else
						mvx = mx - ins.grab_x
						mvy = my - ins.grab_y
					end
					mupdate = mvx ~= 0 or mvy ~= 0
				end

				ins.rectangle_collide = dupdate and update_rectangle
				ins.rectangle_select = ins.rectangle_collide
				if mupdate then
					ins.grab_w_total = mvx
					ins.grab_h_total = mvy
				else
					update_note = false
					update_resize = false
					update_camera = false
				end
				ins.note_moved = update_note
				ins.note_resized = update_resize
				ins.camera_moved = update_camera
			end

			local grab_action
			if ins.rectangle_collide then
				ins.note_hi_toggle = false
				ins.note_hi_clear = false
				if dx < 0 then
					dx = -dx
					ins.grab_x = ins.grab_x - dx
				end
				if dy < 0 then
					dy = -dy
					ins.grab_y = ins.grab_y - dy
				end
			end

			ins.grab_w = dx
			ins.grab_h = dy
			if dupdate then
				ins.camera_update = update_camera
				ins.note_update = update_note
				if not update_rectangle then
					ins.grab_last_x = mx
					ins.grab_last_y = my
				end
				if ins.rectangle_collide then
					log.grab("COLLIDE %d, %d + %d, %d",
						ins.grab_x, ins.grab_y,
						ins.grab_w, ins.grab_h
					)
				end
			end
			if ins.note_moved or ins.note_resized or ins.camera_moved then
				ins.note_highlight = false
				ins.note_hi_clear = false
				local str = (ins.note_moved and "note")
					or (ins.note_resized and sfmt("resize|%s", ins.note_resize))
					or (ins.camera_moved and "camera")
				local csinv = wall.cell_inv
				log.grab("MOVED %s: %3d, %3d: cells: %.2f, %.2f",
					str, ins.grab_w_total, ins.grab_h_total,
					ins.grab_w_total * csinv, ins.grab_h_total * csinv
				)
			end
			do
				local action
				if ins.note_highlight then
					action = "HIGHLIGHT"
				elseif ins.note_hi_toggle then
					action = "HI TOGGLE"
				elseif ins.note_hi_clear then
					action = "HI  CLEAR"
				end
				if action then
					log.grab("%s note #%d", action, ins.active_hold)
				end
			end
		end
	end
end
--}}} INPUT STATE: GRAB
--{{{ INPUT STATE: TEMPLATE
--[=====[ REMOVE THIS LINE
do
	local itype = "template"
	local istate = input_state[itype] and ins.mouse_msg
	if istate then
		--------------------------------------------- ![    HOVER     ]! -------

		if     istate == "press" then
			----------------------------------------- ![    PRESS     ]! -------

		elseif istate == "double" then
			----------------------------------------- ![ DOUBLE CLICK ]! -------

		elseif istate == "down" then
			----------------------------------------- ![     DOWN     ]! -------

		elseif istate == "activate" then
			----------------------------------------- ![   ACTIVATE   ]! -------

		--[[]] istate = "release" end
		if istate == "release" then
			----------------------------------------- ![   RELEASE    ]! -------

		end
	end
end
--}}} INPUT STATE: TEMPLATE ]=====]

	--{{{ UPDATE: NOTE POSITION
	if input_state.note_update then
		input_state.note_update = false
		for i = 1, #wall.focused do
			local id = wall.focused[i]
			local item = wall[id]
			if item then
				local lt = wall.transaction:get_load_table()
				local c
				c = 1; lt[c] = "x"; lt[c+1] = item.x + input_state.grab_w
				c=c+2; lt[c] = "y"; lt[c+1] = item.y + input_state.grab_h
				lt.count = c
				lt.item_id = id
				wall.transaction:queue("MODIFY", lt)
			end
		end
	end
	--}}} UPDATE: NOTE POSITION
	-- {{{ UPDATE: NOTE RESIZE
	if input_state.note_resize then
	if not input_state.active_hold then
		input_state.note_resize = false
	else
		screen_text_render = true
		local ins = input_state
		local resize = ins.note_resize
		local item = wall[ins.active_hold]

		local minwidth = 1
		local minheight = 1
		if #item.note_raw > 0 then
			minwidth = 2
			minheight = #item.note

		end
		local cs = wall.cell_size
		local width_changed = false
		local height_changed = false

		local item_x = item.x
		local item_y = item.y
		local item_w = item.w
		local item_h = item.h
		local item_wrap_limit = item.wrap_limit
		local item__auto_size = item._auto_size
		local trigger_resize = false
		local item_image_scale, item_image_offx, item_image_offy

		local xdiff, ydiff, initialw, initialh =
			ins.note_resize_dx, ins.note_resize_dy,
			ins.note_resize_iw, ins.note_resize_ih
		if not ins.note_resize_dx then
			xdiff = item_x - ins.grab_curr_x
			ydiff = item_y - ins.grab_curr_y
			initialw = item_w
			initialh = item_h
			ins.note_resize_dx = xdiff
			ins.note_resize_dy = ydiff
			ins.note_resize_iw = initialw
			ins.note_resize_ih = initialh
		end
		local newx, newy = ins.grab_curr_x + xdiff, ins.grab_curr_y + ydiff
		--log.resize("xdiff(%.2f == %.2f + %.2f) ydiff(%.2f == %.2f + %.2f",
		--	item_x, ins.grab_curr_x, xdiff,
		--	item_y, ins.grab_curr_y, ydiff
		--)
		if resize then for i = 1, 2 do
			local rs = resize:sub(i,i)
			if not rs then break end
			if     rs == "n" then
				local h = item_h + item_y - newy
				local diff = h - minheight
				if diff <= 0 then
					newy = newy + diff
					h = minheight
				end
				item_y = newy
				item_h = h
				height_changed = diff
			elseif rs == "w" then
				local w = item_w - item_x - newx
				local diff = w - minwidth
				if diff <= 0 then
					newx = newx + diff
					w = minwidth
				end
				item_x = newx
				item_w = w
				width_changed = round(item_x) ~= round(newx)
			elseif rs == "s" then
				local h = initialh + newy - item_y
				local diff = h - minheight
				if diff < 0 then
					h = minheight
				end
				item_h = h
				height_changed = diff
			elseif rs == "e" then
				local w = initialw + newx - item_x
				if w < minwidth then
					w = minwidth
				end
				item_w = w
				width_changed = round(item_x) ~= round(newx)
			end
		end end
		local status_msg
		if width_changed then
			local new_limit = wall:get_wrap_limit_minimum(round(item_w - 1) * cs)
			if new_limit ~= item.wrap_limit then
				item_wrap_limit = new_limit
				if edit_mode then
					edit_line.el_force_update = true
				else
					local nh = #item.note
					if nh > item_h then
						item_h = nh
					end
				end
				status_msg = sfmt("Wrap limit set to %dpx", new_limit)
			end
		end
		if height_changed then
			--log.auto_size("diff: %.2f", height_changed)
			if height_changed < -1.7 then
				item__auto_size = true
				trigger_resize = ins.active_hold
				local msg = sfmt("Note will auto resize")
				if status_msg then
					status_msg = status_msg .. ", " .. msg
				else
					status_msg = msg
				end
			elseif height_changed > 0 then
				item__auto_size = nil
			end
		else
			trigger_resize = ins.active_hold
			--log.autosize("%s", item._auto_size)
		end

		if ins.note_resized then
			item_x = round(item_x)
			item_y = round(item_y)
			item_w = round(item_w)
			item_h = round(item_h)
		end

		local img = item.image_data
		if img then
			local cs = wall.cell_size
			local w, h = item_w * cs, item_h * cs
			local iw, ih = img:getDimensions()

			item_image_scale,
			item_image_offx,
			item_image_offy = wall.object_scale_offset(w, h, iw, ih)
			status_msg = sfmt("Image scale: %d%%",item.image_scale*100)
		end
		if status_msg then set_status(status_msg) end

		local lt = wall.transaction:get_load_table()
		local c = -1
		if item.x ~= item_x then c=c+2; lt[c]="x"; lt[c+1]=item_x end
		if item.y ~= item_y then c=c+2; lt[c]="y"; lt[c+1]=item_y end
		if item.w ~= item_w then c=c+2; lt[c]="w"; lt[c+1]=item_w end
		if item.h ~= item_h then c=c+2; lt[c]="h"; lt[c+1]=item_h end
		if item.wrap_limit ~= item_wrap_limit then
			c=c+2; lt[c]="wrap_limit"; lt[c+1]=item_wrap_limit
		end
		if item._auto_size ~= item__auto_size then
			c=c+2; lt[c]="_auto_size"; lt[c+1]=item__auto_size
		end
		if item_image_scale then
			c=c+2; lt[c]="image_scale"; lt[c+1]=item_image_scale
			c=c+2; lt[c]="image_offx"; lt[c+1]=item_image_offx
			c=c+2; lt[c]="image_offy"; lt[c+1]=item_image_offy
		end
		if c > 0 then
			lt.count = c
			lt.resize = trigger_resize
			lt.item_id = ins.active_hold
			wall.transaction:queue("MODIFY", lt)
		end
	end
	end
	-- }}} UPDATE: NOTE RESIZE
	-- {{{ UPDATE: CAMERA POSITION
	if input_state.camera_update then
		--log.camera("MOVE %d, %d", input_state.grab_w, input_state.grab_h)
		camera.dx = camera.dx + input_state.grab_w * scale_inv
		camera.dy = camera.dy + input_state.grab_h * scale_inv
		input_state.camera_update = false
	end
	-- }}} UPDATE: CAMERA POSITON
	-- {{{ UPDATE: HIGHLIGHT, TOGGLE HIGHLIGHT & CLEAR HIGHLIGHT
	if input_state.note_highlight then
		local idx = input_state.note_highlight
		input_state.note_highlight = false

		wall:clear_focused()
		if wall.selected > 0 then
			wall:exit_edit_mode()
		end
		wall.focused[1] = idx
		wall[idx]._focused = true
	elseif input_state.note_hi_toggle then
		local idx = input_state.note_hi_toggle
		input_state.note_hi_toggle = false
		local wf = wall.focused
		local pos
		for i = 1, #wf do
			if wf[i] == idx then
				pos = i
				break
			end
		end
		if pos then
			table.remove(wf, pos)
			wall[idx]._focused = false
		else
			table.insert(wf, idx)
			wall[idx]._focused = true
		end
	elseif input_state.note_hi_clear then
		if edit_mode then
			wall.transaction:queue("EXIT", input_state.note_hi_clear)
		end
		wall:clear_focused()
		input_state.note_hi_clear = false
	end


	-- }}} UPDATE: HIGHLIGHT & TOGGLE HIGHLIGH
	-- {{{ UPDATE: NEW NOTE
	if input_state.note_new then
		input_state.note_new = false
		local ins = input_state
		wall.transaction:queue("EXIT", wall.selected)
		wall:add_new_note(ins.grab_x, ins.grab_y, true)
	end
	-- }}} UPDATE: NEW NOTE
	-- {{{ UPDATE: EDIT NOTE
	if input_state.note_edit then
		wall.selected = input_state.note_edit

		if wall.selected > 0 then
			--{{{ change to new mode
			local item = wall[wall.selected]
			if item.readonly then
				--do nothing
			elseif item.type == "note" then
				edit_mode = input.edit_mode(true)
				edit_line.show_cursor = true
				edit_line.blink_timer = edit_line.blink_start_time

				edit_line.cursor_force_update = true

				local item = wall[wall.selected]
				if edit_line.undo.last_selected ~= wall.selected then
					edit_line.undo.last_selected = wall.selected
					edit_line.undo:reset()
					--log.note_cursor("%s «%s»", edit_line.undo.note_cursor, item.note_raw)
					edit_line.undo:push("raw", item.note_raw)
				end
				if not item.note.newline then
					item.note.newline = {}
				end
				--wall.transaction:queue(sfmt("ENTER edit note #%d", wall.selected))
				edit_line.undo.note_raw = item.note_raw
				edit_line.undo.note_raw_saved = edit_line.undo.note_raw
				--log.edit_mode("note: %s", edit_line.undo.note_raw)

				input_state.note_edit = false
			elseif item.type == "waypoint" then
				wall.line = 1
				wall.cursor_x = 0
				local id = wall.selected
				wall:select_note(id)

				local txn = wall.transaction
				local lt = txn:get_load_table()
				local c = -1
				c=c+2; lt[c] = "w";          lt[c+1] = 1
				c=c+2; lt[c] = "h";          lt[c+1] = 1
				c=c+2; lt[c] = "type";       lt[c+1] = "note"
				lt.count = c

				lt.item_id = id
				lt.resize = true
				txn:queue("MODIFY", lt)

				edit_line.process_mouse_down = false
			end
			--}}}
		end

	end
	-- }}} UPDATE: EDIT NOTE
	-- {{{ UPDATE: NOTE TASK
	if input_state.note_task_toggle then
		local idx = input_state.note_task_toggle
		input_state.note_task_toggle = false
		local item = wall[idx]
		local item_task = item.task
		if item_task == "incomplete" then
			item_task = "complete"
		elseif item_task == "complete" then
			item_task = "cancel"
		elseif item_task == "cancel" then
			item_task = "incomplete"
		end
		local lt = wall.transaction:get_load_table()
		local c = 1
		lt[c] = "task"; lt[c+1] = item_task
		lt.count = 1
		lt.item_id = idx
		wall.transaction:queue("MODIFY", lt)
	end
	-- }}} UPDATE: NOTE TASK
	-- {{{ UPDATE: RECTANGLE SELECTION & COLLIDE
	if input_state.rectangle_select then
		screen_text_render = true
		if input_state.rectangle_collide then
			local ins = input_state
			local cs = wall.cell_size
			local rx, ry, rw, rh =
				ins.grab_x, ins.grab_y,
				ins.grab_w, ins.grab_h

			if abs(rw) * cs > 1 or abs(rh) * cs > 1 then
				local st = {}
				local sx = {}
				local sy = {}
				local ti = table.insert
				local min_x = math.huge
				local min_y = math.huge
				for i = 1, wall.count do
					local w = wall[i]
					if not w then break end
					if w.type == "note" then
						if  w.x + w.w > rx and
							w.x < rx + rw and
							w.y + w.h > ry and
							w.y < ry + rh
						then
							ti(st, i)
							ti(sx, w.x)
							ti(sy, w.y)
						end
					elseif w.type == "waypoint" then
						--COPY/PASTED in wall.hover == 0
						local offs = wall.waypoint_display_offset
						local wx, wy = w.x, w.y
						wx, wy = wx + offs, wy + offs
						local testx, testy = wx, wy
						if     wx < rx      then testx = rx
						elseif wx > rx + rw then testx = rx + rw end
						if     wy < ry      then testy = ry
						elseif wy > ry + rh then testy = ry + rh end

						local dist = camera.distance(wx, wy, testx, testy)
						local cs = w.r * wall.cell_inv
						if dist <= cs then
							ti(st, i)
							ti(sx, wx)
							ti(sy, wy)
							break
						end
						if w.line then
							wx, wy = w.x2, w.y2
						end
					end
				end
				--probably a dumb way to organize the ids, but it'll work (maybe)
				local tr = table.remove
				--remove already focused items (don't double add)
				for i = #st, 1, -1 do
					for k = 1, #wall.focused do
						if st[i] == wall.focused[k] then
							tr(st, i)
							tr(sx, i)
							tr(sy, i)
							break
						end
					end
				end
				--print("IDs selected", table.concat(st, ", "))
				local match = {}
				while #st > 0 do
					local match_count = 0
					local min_y = sy[1]
					for i = 2, #sy do
						if sy[i] < min_y then
							min_y = sy[i]
						end
					end
					--repopulate match table each time its removed otherwise removing
					--picks causes matches to point to invalid table position
					for i = 1, #st do
						if sy[i] == min_y then
							match_count = match_count + 1
							match[match_count] = i
						end
					end
					local pick = match[1]
					for i = 2, match_count do
						local m = match[i]
						if sx[m] < sx[pick] then
							pick = m
						end
					end
					local idx = st[pick]
					ti(wall.focused, idx)
					wall[idx]._focused = true
					tr(st, pick)
					tr(sx, pick)
					tr(sy, pick)
				end
			end
			input_state.rectangle_select = false
			input_state.rectangle_collide = false
		end
		log.select("%s notes selected", #wall.focused)
	end
	-- }}} UPDATE: RECTANGLE SELECTION & COLLIDE
	-- {{{ UPDATE: ACTIVATE WAYPOINT
	if input_state.waypoint_activate then
		local idx = input_state.waypoint_activate
		input_state.waypoint_activate = false

		local item = wall[idx]
		local cmd, err = item.note_raw
		if type(cmd) == "string" then
			cmd, err = wall.command:setup(cmd, item)
		end
		if type(cmd) ~= "function" then
			set_status("Invalid command: ".. tostring(err))
			print("Invalid command: ".. tostring(err))
		else
			screen_text_render = true
			wall.transaction:queue(sfmt("EXECUTE #%d's command", idx))
			cmd(idx)
			item._focused = false
			for i = 1, #wall.focused do
				if wall.focused[i] == idx then
					table.remove(wall.focused, i)
					break
				end
			end
		end
	end
	-- }}} UPDATE: ACTIVATE WAYPOINT
	-- {{{ UPDATE: LINE ADD SECOND NODE
	if input_state.line_add_second_node and not input_state.camera_moved then
		input_state.line_add_second_node = false
		local x1, y1 = lines.x1, lines.y1
		local x2, y2 = cell.x, cell.y
		local item = lines.item1

		wall.transaction:queue(sfmt("ADD second line node to item %s",item))

		wall:update_line(item, x2, y2)
		lines.x1 = false
	end
	-- }}} UPDATE: LINE ADD SECOND NODE


	--{{{ ZOOM IN/OUT w/ MOUSE WHEEL
	if input.mouse.wheel.y ~= 0 then
		--print("mouse wheel", input.mouse.wheel.x, input.mouse.wheel.y)
		scale_update(input.mouse.wheel.y)

		local newma = input.mouse.absolute * scale_inv
		newma.x = floor(newma.x) -
			(lg.getWidth() * 0.5 * (scale_inv - 1.0)) - camera.dx
		newma.y = floor(newma.y) -
			(lg.getHeight() * 0.5 * (scale_inv - 1.0)) - camera.dy
		camera.dx = camera.dx + (newma.x - mapos.x)
		camera.dy = camera.dy + (newma.y - mapos.y)
	end
	--}}} ZOOM IN/OUT
	profile.update_1:lap()

	profile.update_2:start()
	wall.waypoint_button_display = false
	if edit_mode then
		-----------------------------------------------------------
		--                                                       --
		--                                                       --
		--{{{  UPDATE EDIT MODE                                  --
		--                                                       --
		--                                                       --
		-----------------------------------------------------------

		--{{{ update edit_line.blink_timer
		edit_line.blink_timer = edit_line.blink_timer - dt
		if edit_line.blink_timer < 0 then
			edit_line.show_cursor = not edit_line.show_cursor
			edit_line.blink_timer = edit_line.blink_default_time
		end
		--}}} update blink timer

		local el_updated = false
		local cursor_updated = false
		local moved_up_down = false

		if edit_line.el_force_update then
			edit_line.el_force_update = false
			el_updated = true
		end
		if edit_line.cursor_force_update then
			edit_line.cursor_force_update = false
			cursor_updated = true
		end



		wall.select_shift = false
		if input.shift then
			wall.select_shift = true
			--while shift is pressed, any cursor movement
			--operates on a second cursor
			-- backspace and delete will remove all selected text
		end
		local has_selected_text = #wall.selected_str > 0
		local delete_selected_str = false

		--UPDATE UNDO TIMER
		edit_line.undo.timer = edit_line.undo.timer + dt


		do
			local pmd = edit_line.process_mouse_down
			local mouse_click = input.mouse_click
			--print("mouse_click", mouse_click, "pmd", pmd)
			if not pmd then
				pmd = not mouse_click
				edit_line.process_mouse_down = not mouse_click
				mouse_click = pmd and mouse_click
			end
		if mouse_click and wall.hover == wall.selected then --{{{
			cursor_updated = true
			--log.info("input.mouse")
			local input_down = input.mouse_click == "down"

			wall.select_shift = (input_down or wall.select_shift) and not wall.select_text_timer
			wall:set_select_cursor()

			--{{{ CLICK NOTE
			local id = wall.selected
			local item = wall[id]
			--print("heading", item.heading)

			do
				local line = cell.y - item.y
				local max = #item.note - 1
				if line > max then
					line = max < 0 and 0 or max
				end
				if line < 0 then line = 0 end
				wall.line = line
			end

			local text_start
			if item.heading then
				wall.line = ceil(wall.line * wall.cell_size * wall.h1_cell_inv)
				if wall.line < 1 then
					wall.line = 1
				end
				wall.line = wall.line + 1
				text_start = item.x * wall.cell_size + wall.h1_cell_size * 0.5
				wall.cursor_x = mapos.x - text_start
			else
				wall.line = wall.line + 1
				text_start = item.x * wall.cell_size + wall.note_border_w -1
			end
			wall.cursor_x = mapos.x - text_start

			if edit_line.undo.ptr == 0 then
				edit_line.undo:push("raw", item.note_raw)
			end

			--log.cursor_x("%d", wall.cursor_x)
			wall:select_note(id)
			--log.cursor_x("%d", wall.cursor_x)
			if item.heading  and input.mouse_click == "pressed" then
				local txn = wall.transaction
				local lt = txn:get_load_table()
				local c = -1
				c=c+2; lt[c] = "heading"; lt[c+1] = false
				lt.count = c
				lt.item_id = id
				lt.resize = true
				txn:queue("MODIFY", lt)
				edit_line.process_mouse_down = false
			end
			if item.image and input.mouse_click == "pressed" then
				local txn = wall.transaction
				local lt = txn:get_load_table()
				local c = -1
				c=c+2; lt[c] = "image"; lt[c+1] = false
				lt.count = c
				lt.item_id = id
				txn:queue("MODIFY", lt)
			end

			--}}}

			if input_down then
				if  wall.select_line == wall.line and
					wall.select_cursor_x == wall.cursor_x
				then
					wall.select_shift = false
					wall:set_select_cursor()
				end
			end
			edit_line.undo.note_cursor = wall.get_raw_cursor(
				item.note, wall.line, edit_line.cursor
			)
			--log.note_cursor("%s «%s»", edit_line.undo.note_cursor, edit_line.undo.note_raw)
		end --}}}
		end
		if input.ctrl and input.undo == "pressed" then --{{{
			--EDIT MODE UNDO
			local utype, cursor, data
			local item = wall[wall.selected]
			local note_raw = item.note_raw

			local offset
			local ssub = string.sub
			local tmp_before, tmp_mid, tmp_after
			local action = utype
			--local undoredo = "undo"
			if input.shift then
				--undoredo = "redo"
				--redo
				utype, cursor, data = edit_line.undo:redo()
				if not utype then goto exit end
				if utype == "append" then
					action = "backspace"
				elseif utype == "delete" or utype == "backspace" then
					action = "append"
				end
			else
				--undo
				utype, cursor, data = edit_line.undo:pop()
				action = utype
			end
			--printf("%s\t\t%9s %3d: %s\n", string.upper(undoredo), action, cursor or -1, data)
			--print("type, type(note_raw), cursor:", utype, type(note_raw), cursor)

			if utype == "raw" then
				edit_line.undo:redo()
				goto exit
			end
			local line_cursor = 0
			cursor = cursor or 1
			offset = utf8.offset(note_raw, cursor)
			--print("offset", offset)
			if not offset then
				printf("unable to find offset at cursor pos %d\n", cursor)
				printf("note_raw length: %d\n", #note_raw)
				print(hex_dump(note_raw))
				goto exit_error
			end

			--print("utype, action", utype, action)
			if    action == "append" then
				tmp_before = ssub(note_raw,              1, offset-1)
				tmp_mid    = ssub(note_raw,         offset,offset+#data-1)
				tmp_after  = ssub(note_raw, offset + #data,       -1)

				--printf("TMP before(%s), middle(%s=?%s#%d)and after(%s)\n",
				--	tmp_before, tmp_mid or "", data, #data, tmp_after
				--)

				if tmp_mid ~= data then goto exit_error end

				cursor = cursor - 1

			elseif action == "delete" or action == "backspace" then
				tmp_before = ssub(note_raw,      1, offset-1)
				tmp_after  = ssub(note_raw, offset,       -1)
				--printf("TMP before(%s), middle(%s)and after(%s)\n",
				--	tmp_before, data, tmp_after
				--)
				tmp_before = tmp_before .. data

				if action == "backspace" then
					cursor = cursor + utf8.len(data) - 1
				else
					cursor = cursor - 1
				end
			else
				--print("invalid action: ".. tostring(action))
				goto exit_error
			end
			do
				local raw = tmp_before .. tmp_after
				edit_line.undo.note_raw = raw
				edit_line.undo.note_cursor = cursor
				--log.note_cursor("%s", cursor)
				local note = item.note
				wall.line, edit_line.cursor = wall.get_line_cursor(note, cursor or 0)
			end
			el_updated = true

			goto exit

			::exit_error::
			--set_status("Undo failed")
			--print("Undo failed")
			::exit::
		end --}}}

		local edit_ptr = 1

		if edit_line.set_autowrap_size then
			edit_line.set_autowrap_size = edit_line.set_autowrap_size - dt
			if edit_line.set_autowrap_size < 0 then
				edit_line.set_autowrap_size = false
			end
		end
while true do
		local next_task = false
		local task_key = false
		do
			for i = edit_ptr, input.edit.count, 2 do
				local ev = input.edit[i]
				local key = input.edit[i+1]
				if ev == "pressed" then
					if key == "backspace" or key == "delete" or key == "enter" then
						next_task = key
					elseif
						key == "up" or
						key == "down" or
						key == "left" or
						key == "right" or
						key == "end" or
						key == "home"
					then
						next_task = "move_cursor"
						task_key = key
					end
				elseif ev == "text" then
					next_task = "text_input"
					task_key = key
				end
				if next_task then
					edit_ptr = i + 2
					break
				end
			end
			if not next_task then break end
			--log.CURSOR("next: %s | %s (%d)→row:%d col:%d\n", next_task, task_key,
			--	edit_line.undo.note_cursor, wall.line, edit_line.cursor
			--)
		end


		local up = task_key == "up"
		local down = task_key == "down"
		local left = task_key == "left"
		local right = task_key == "right"
	if next_task == "move_cursor" then
		if input.ctrl then
			--{{{ctrl + move
			local item = wall[wall.selected]
			local x, y = 0, 0
			if        up then y = -1
			elseif  down then y =  1
			elseif  left then x = -1
			elseif right then x =  1 end
			if x ~= 0 or y ~= 0 then screen_text_render = true end
			item.x = item.x + x
			item.y = item.y + y
			--}}}
			up, down, left, right = false, false, false, false
		end
		if up then
			--{{{
			cursor_updated = true
			--log.info("input.up")
			--log.note_cursor("%s", edit_line.undo.note_cursor)
			wall.line, edit_line.cursor = wall.get_line_cursor(wall[wall.selected].note, edit_line.undo.note_cursor)
			wall:set_select_cursor()
			wall.line = wall.line - 1
			if wall.line < 1 then
				wall.line = 1
			end
			moved_up_down = true
			--}}}
		elseif down then
			--{{{
			cursor_updated = true
			--log.info("input.down")
			wall.line, edit_line.cursor = wall.get_line_cursor(wall[wall.selected].note, edit_line.undo.note_cursor)
			wall:set_select_cursor()
			wall.line = wall.line + 1
			local item = wall[wall.selected]
			if wall.line > item.h then
				wall.line = item.h
			end
			moved_up_down = true
			--}}}
		end
		if moved_up_down then
			local set = wall.cursor_x_prev
			if not set then
				set = wall.cursor_x
			else
				wall.cursor_x = set
			end
			wall:select_note(wall.selected)
			--select_note unsets cursor_x_prev
			wall.cursor_x_prev = set
			edit_line.undo.note_cursor = wall.get_raw_cursor(wall[wall.selected].note,
				wall.line, edit_line.cursor
			)
			--log.note_cursor("%s", edit_line.undo.note_cursor)
		end
		--TODO: "home" and "end" are broken.
		--they both rely on having wall.line and edit_line.cursor being in sync with
		--edit_line.undo.note_cursor but that isn't currently possible.
		--it's a small problem I'll ignore for now, but it's not pretty
		if task_key == "home" then
			--{{{
			cursor_updated = true
			--log.info("input.home")
			local note = wall[wall.selected].note
			edit_line.cursor = 0
			edit_line.undo.note_cursor = wall.get_raw_cursor(note, wall.line, edit_line.cursor)
			el_updated = true
			--}}}
		elseif task_key == "end" then
			--{{{
			cursor_updated = true
			--log.info("input.end")
			wall:set_select_cursor()
			local note = wall[wall.selected].note
			wall.line = wall.get_line_cursor(note, edit_line.undo.note_cursor)
			local cursor = wall.get_end_cursor(note, wall.line)

			if note.newline[wall.line] then
				cursor = cursor - 1
			elseif wall.line < #note then
				local nline = note[wall.line]
				local offset = utf8.offset(nline, -1)
				if offset then
					local s, e = string.find(nline, "^%s$", offset)
					--print("s,e, str", s,e, "«"..string.sub(nline, offset).."»")
					if s then cursor = cursor - 1 end
				end
			end

			edit_line.undo.note_cursor = cursor
			el_updated = true
			--}}}
		elseif left then
			--{{{
			cursor_updated = true
			--log.info("input.left")
			if wall.select_line > 0 and not wall.select_shift then
				local use_select_cursor = false
				if wall.select_line < wall.line then
					use_select_cursor = true
				elseif wall.select_line == wall.line and
					wall.select_el_cursor < edit_line.cursor
				then
					use_select_cursor = true
				end
				if use_select_cursor then
					edit_line.cursor = wall.select_el_cursor
					wall.line = wall.select_line
					wall.cursor_x = wall.select_cursor_x
				end
				wall:set_select_cursor()
			else
				wall:set_select_cursor()
				local item = wall[wall.selected]
				local cursor = edit_line.undo.note_cursor - 1
			--log.note_cursor("%s", edit_line.undo.note_cursor)
				if cursor < 0 then cursor = 0 end
				--printf("cursor %d -> %d (LEN:%d) row:%d, col:%d\n",
				--	edit_line.undo.note_cursor, cursor, #item.note_raw,
				--	wall.get_line_cursor(item.note, cursor)
				--)
				edit_line.undo.note_cursor = cursor
			--log.note_cursor("%s", edit_line.undo.note_cursor)
				el_updated = true
			end
			--}}}
		elseif right then
			--{{{
			cursor_updated = true
			--log.info("input.right")
			if wall.select_line > 0 and not wall.select_shift then
				local use_select_cursor = false
				if wall.select_line > wall.line then
					use_select_cursor = true
				elseif wall.select_line == wall.line and
					wall.select_el_cursor > edit_line.cursor
				then
					use_select_cursor = true
				end
				if use_select_cursor then
					edit_line.cursor = wall.select_el_cursor
					wall.line = wall.select_line
					wall.cursor_x = wall.select_cursor_x
				end
				wall:set_select_cursor()
			else
				wall:set_select_cursor()
				local item = wall[wall.selected]
				local cursor = edit_line.undo.note_cursor + 1
				--local cursor = wall.get_end_cursor(item.note, wall.line - 1)
				--cursor = cursor + edit_line.cursor + 1
				local raw_len = utf8.len(edit_line.undo.note_raw)
				--printf("cursor %d -> %d (LEN:%d) row:%d, col:%d\n",
				--	edit_line.undo.note_cursor, cursor, raw_len,
				--	wall.get_line_cursor(item.note, cursor)
				--)
				if cursor > raw_len then cursor = raw_len end
				edit_line.undo.note_cursor = cursor
				el_updated = true
			end
			--}}}
		end
	end

		if cursor_updated then
			render_wall.updated = 2
			edit_line.undo:step()
		end


		if next_task == "backspace" then
			--{{{
			if has_selected_text then
				wall:delete_selected_string()
			else
				local cursor, str = 0
				do
					local item = wall[wall.selected]
					local data = edit_line.undo.note_raw
					cursor = edit_line.undo.note_cursor
					local offset = utf8.offset(data, cursor)
					local offset2 = utf8.offset(data, cursor+1)
					if offset and offset2 then
						str = string.sub(data, offset, offset2-1)
					end
				end
				if str then
					edit_line.undo:push("backspace", cursor, str)
				end
			end
			el_updated = true
			--}}}
		elseif next_task == "delete" then
			--{{{
			if has_selected_text then
				wall:delete_selected_string()
			else
				local cursor, str = 0
				do
					local item = wall[wall.selected]
					local data = edit_line.undo.note_raw
					cursor = edit_line.undo.note_cursor + 1
					local offset = utf8.offset(data, cursor)
					local offset2 = utf8.offset(data, cursor+1)
					if offset and offset2 then
						str = string.sub(data, offset, offset2-1)
					end
				end
				if str then
					edit_line.undo:push("delete", cursor, str)
				end
			end
			--log.info("input.delete")
			el_updated = true
			--}}}
		elseif next_task == "enter" then
		--{{{
		if input.ctrl then
			--TODO: doesn't work well for headings
			local id = wall.selected
			local item = wall[id]
			log.note_cursor("%s  ... Note added", edit_line.undo.note_cursor)
			input_state.note_new = true
			input_state.grab_x = item.x
			local height = #item.note
			if height < 1 then height = 1 end
			input_state.grab_y = item.y + height
		else
			if has_selected_text then
				wall:delete_selected_string()
			end

			local cur = edit_line.undo.note_cursor + 1
			edit_line.undo:push("append", cur, "\n")

			el_updated = true
			--log.info("input.enter")
		end
		--}}}
		end

		if next_task == "text_input" then --{{{
			local intext = task_key
			if has_selected_text then
				wall:delete_selected_string()
			end
			wall.mouse_hide_is_typing = true
			local cursor = edit_line.undo.note_cursor + 1
			--log.info("input.text: \"%s\" (%d)", intext, utf8.len(intext))
			edit_line.undo:push("append", cursor, intext)
			el_updated = true
		end --}}}
end
	if input.tab == "pressed" then
		local dir = input.shift and -1 or 1
		local item = wall[wall.selected]
		item.x = item.x + dir
		screen_text_render = true
	end

		if input.ctrl and input.select_all == "pressed" then --{{{
			wall.select_shift = false
			wall:set_select_cursor()
			wall.line = 1
			wall.cursor_x = 0
			wall:select_note(wall.selected)
			wall.select_shift = true
			wall:set_select_cursor()
			local note = wall[wall.selected].note
			wall.line = #note
			wall.cursor_x = font:getWidth(note[#note])
			wall:select_note(wall.selected)
			screen_text_render = true
		end --}}}

		if input.ctrl and input.paste == "pressed" then --{{{
			if has_selected_text then
				wall:delete_selected_string()
			end
			--print("edit mode paste")
			local note = wall[wall.selected].note
			local rawstr = clipboard:gettext()
			local line = wall.line


			local paste_cur = wall.get_end_cursor(note, line - 1)
			paste_cur = paste_cur + edit_line.cursor + 1

			--print("append", paste_cur, rawstr)
			edit_line.undo:step()
			edit_line.undo:push("append", paste_cur, rawstr)
			edit_line.undo:step()

			el_updated = true
			link_file_data.modified = true
		end --}}}

	--{{{ update wall.select_text_timer
	if wall.select_text_timer then
		wall.select_text_timer = wall.select_text_timer - dt
		if wall.select_text_timer < 0 then
			wall.select_text_timer = false
			if wall.select_line > 0 then
				edit_line.offset = wall.select_offset
				edit_line.cursor = wall.select_el_cursor
				wall.line = wall.select_line
				wall.cursor_x= wall.select_cursor_x
			end
		end
	end
	--}}}
		--TODO: is there a better way?
	if not wall.select_text_timer then
	if  wall.select_line     ~= wall.last.select_line or
		wall.line            ~= wall.last.line or
		wall.cursor_x        ~= wall.last.cursor_x or
		wall.select_cursor_x ~= wall.last.select_cursor_x
	then
		--{{{ [ Selecting Text ]
		local s_sel_line = wall.select_line
		local s_sel_curx = wall.select_cursor_x
		local s_line = wall.line
		local s_curx = wall.cursor_x
		wall.last.select_line     = s_sel_line
		wall.last.line            = s_line
		wall.last.cursor_x        = s_curx
		wall.last.select_cursor_x = s_sel_curx

		local note = wall[wall.selected].note

		local prev_x = wall.cursor_x_prev
		wall.line = s_sel_line
		wall.cursor_x = s_sel_curx
		wall:select_note(wall.selected)
		local rawoff1 = wall.get_end_offset(note, wall.line-1) + edit_line.offset
		local minmax1 = edit_line.offset

		wall.line = s_line
		wall.cursor_x = s_curx
		wall:select_note(wall.selected)
		local rawoff2 = wall.get_end_offset(note, wall.line-1) + edit_line.offset
		local minmax2 = edit_line.offset
		if moved_up_down then
			wall.cursor_x_prev = prev_x
		end

		local min_line, max_line, min_x, max_x, min_o, max_o
		local selecting_text = true
		if  wall.select_line == wall.line and
			wall.select_cursor_x == wall.cursor_x or
			wall.select_line == 0
		then
			selecting_text = false
		elseif wall.select_line < wall.line then
			min_line = s_sel_line
			max_line = s_line
			min_x = s_sel_curx
			max_x = s_curx
		elseif wall.select_line > wall.line then
			min_line = s_line
			max_line = s_sel_line
			min_x = s_curx
			max_x = s_sel_curx
		else
			min_line = s_line
			max_line = s_sel_line
			if edit_line.cursor < wall.select_el_cursor then
				min_x = s_curx
				max_x = s_sel_curx
			else
				min_x = s_sel_curx
				max_x = s_curx
			end
		end
		wall.min_line, wall.max_line, wall.min_x, wall.max_x =
		     min_line,      max_line,      min_x,      max_x

		--With the min and max line/pos figured out, lets select some text
		wall.selected_str = ""
		if selecting_text then
			local o1, o2 = rawoff1, rawoff2
			wall.min_o, wall.max_o = minmax1, minmax2
			if o1 > o2 then
				o1, o2 = rawoff2, rawoff1
				wall.min_o, wall.max_o = minmax2, minmax1
			end
			o1 = o1 + 1
			wall.selected_str = string.sub(wall[wall.selected].note_raw, o1, o2)
			local status = string.gsub(wall.selected_str, "\n", "\\n")
			--log.select_text("Selected: %d->%d \"%s\"", o1, o2, status)
			screen_text_render = true
		end
		--}}}  [ End Selecting Text ]
	end
	end
		if input.ctrl and input.copy == "pressed" or input.cut == "pressed" then --{{{
			if #wall.selected_str > 0 then
				--print("edit mode copy")
				love.system.setClipboardText(wall.selected_str)
				clipboard.system = "" --clear it
			end
		end --}}}
		if input.ctrl and input.cut == "pressed" then --{{{
			if #wall.selected_str > 0 then
				wall:delete_selected_string()
				el_updated = true
			end
		end--}}}

		--disable autowrap resize if there's any other keypresses
		if edit_line.set_autowrap_size then
			if el_updated or cursor_updated then
				edit_line.set_autowrap_size = false
				edit_line.set_autowrap_status = false
				set_status("", 0)
			end
			if edit_line.set_autowrap_updated then
				edit_line.set_autowrap_updated = false
				el_updated = true
			end
		end
		if el_updated then --{{{
			local id = wall.selected
			local item = wall[id]
			do
				local lt = wall.transaction:get_load_table()
				local c = -1
				if item._data.note_raw ~= edit_line.undo.note_raw then
					c=c+2; lt[c] = "note_raw"; lt[c+1] = edit_line.undo.note_raw
				end
				lt.count = c

				lt.item_id = id
				lt.selected = true
				wall.transaction:queue("EDIT", lt)
			end
			link_file_data.modified = true
			--log.info("%d→%d,%d «%s|%s»", edit_line.undo.note_cursor,
			--	wall.line, edit_line.cursor, edit_line.data, edit_line.data_2
			--)
		end --}}}

		--log.camera_update("el_u:%s; cur_u:%s; cam g&m:%s, mip:%s, mto:%s",
		--	el_updated, cursor_updated, camera.grabbed and camera.moved,
		--	camera.move_in_progress, not camera.move_to_x
		--)
		--UPDATE CAMERA IF CURSOR IS OFF SCREEN
		if (el_updated or cursor_updated or (camera.grabbed and camera.moved)
			or camera.move_in_progress) and not camera.move_to_x
		then
			local item = wall[wall.selected]
			local lws = love_window_settings
			local cs = wall.cell_size
			local ix, iy =
				item.x * cs,
				item.y * cs
			local cx, cy, cw, ch =
				-camera.dx,
				-camera.dy,
				-camera.dx + lws.current_w,
				-camera.dy + lws.current_h

			local cdx, cdy = camera.dx, camera.dy
			local dcx, dcy = 0, 0
			do
				local ratio = 0.2
				local iwcs = item.w * cs
				local curx, curx2, curx3
				local extra = cs
				local iwr = iwcs * ratio
				if iwr < 3 * cs then iwr = 3 * cs end
				if iwcs - wall.cursor_x < iwr then
					curx = ix + iwcs
					curx2 = ix + wall.note_border_w + wall.cursor_x - iwr
				elseif wall.cursor_x < iwr then
					curx = ix
					curx3 = ix + iwr
				else
					curx = ix + wall.note_border_w + wall.cursor_x
					extra = iwr
				end
				local dcuxx, dcuxw =
					(curx2 or curx) - cx - extra,
					cw - (curx3 or curx) - extra

				dcx = dcx - (dcuxx < 0 and dcuxx or 0)
				dcx = round(dcx + (dcuxw < 0 and dcuxw or 0))

				cdx = cdx + dcx
			end
			do
				local cury = iy + (wall.line * cs)
				local extra = cs
				local ihcs = item.h * cs
				if ihcs - wall.line * cs < 8 * cs then
					cury = iy + ihcs
				elseif wall.line * cs < 8 * cs then
					cury = iy
				else
					extra = 8 * cs
				end
				local dcuxy, dcuxh =
					cury - cy - (extra + cs), --remember the status bar
					ch - cury -  extra

				dcy = dcy - (dcuxy < 0 and dcuxy or 0)
				dcy = round(dcy + (dcuxh < 0 and dcuxh or 0))
				cdy = cdy + dcy
			end

			local diff = 3
			if dcx == 0 and dcy == 0 then
				camera.move_in_progress = false
			end
			if (camera.grabbed and camera.moved) or
				(abs(dcx) < diff and dcx ~= 0) or
				(abs(dcy) < diff and dcy ~= 0)
			then
				camera.dx = cdx
				camera.dy = cdy
				wall.select_text_timer = wall.select_text_timer_default
			elseif dcx ~= 0 or dcy ~= 0 then
				camera.move_to_x = camera.move_to_x and
					camera.move_to_x * 0.2 + cdx * 0.8 or cdx
				camera.move_to_y = camera.move_to_y and
					camera.move_to_y * 0.2 + cdy * 0.8 or cdy
				camera.move_in_progress = true
				wall.select_text_timer = wall.select_text_timer_default
			end
		end

		do
			--{{{ check if we can convert note to waypoint
			local item = wall[wall.selected]
			local note = item.note

			wall.waypoint_button_x = false
			wall.waypoint_button_y = false

			local display = false
			if #item.note_raw > 0 then
				local found = wall.command:find(item.note_raw)
				if found then
					display = true
				end
			end

			if wall.waypoint_button_display ~= display then
				wall.waypoint_button_display = display
				screen_text_render = true
			end

			wall.waypoint_button_string = " >"
			--}}} check if we can convert note to waypoint
		end

		--}}}
		--                                                       --
		--                                                       --
		-----------------------------------------------------------
	else-- DEFAULT
		-----------------------------------------------------------
		--                                                       --
		--                                                       --
		--{{{  UPDATE (NOT EDIT | DEFAULT | NORMAL | VIEW) MODE  --
		--                                                       --
		--                                                       --
		-----------------------------------------------------------

		wall.waypoint_button_x = false
		wall.waypoint_button_y = false

		local copy_notes = false
		local delete_notes = false
		local txn = wall.transaction --FOR SEARCHING... transaction:queue()
		if input.ctrl and input.undo == "pressed" then --{{{
			txn:queue("UNDO note DELETE stack")
			local wdic = wall.deleted_interval.count

			for i = 1, #wall.deleted_interval do
				local di = wall.deleted_interval[i]
				if di == wdic then
					wall.deleted_interval[i] = false
				end
			end
			for i = #wall.deleted_interval, 1, -1 do
				if not wall.deleted_interval[i] then
					table.remove(wall.deleted_interval, i)
					local item = table.remove(wall.deleted, i)
					wall.count = wall.count + 1
					wall[wall.count] = item
					wall.selected = wall.count
					wall:exit_edit_mode()
					link_file_data.modified = true
					screen_text_render = true
				end
			end
			wdic = wdic - 1
			if wdic < 1 then wdic = wall.deleted_interval.max end
			wall.deleted_interval.count = wdic
			print("Undo stack count:", #wall.deleted)
		end --}}}]]
		if input.ctrl and input.cut == "pressed" then --{{{
			copy_notes = true
			delete_notes = true
		end --}}}
		if input.ctrl and input.copy == "pressed" then --{{{ [COPY NOTES]
			copy_notes = true
		end
		if copy_notes then
			txn:queue(sfmt("COPY %d notes", #wall.focused))
			clipboard.count = 0
			for i = 1, #wall.focused do
				--add_wall_item_to_clipboard {{{
				local c, clip, max
				local item = wall[wall.focused[i]]


				c = clipboard.count + 1
				clipboard.count = c
				clip = clipboard[c]
				if not clip then
					clip = {}
					clipboard[c] = clip
				end
				if c == 1 then
					clipboard.dx = -item.x
					clipboard.dy = -item.y
					clipboard.char_width = 0
				end
				clip.x = item.x + clipboard.dx
				clip.y = item.y + clipboard.dy
				clip.w = item.w
				clip.h = item.h
				clip.r = item.r
				clip.date = item.date
				clip.time = item.time
				clip.type = item.type
				clip.created = item.created
				clip.wrap_limit = item.wrap_limit
				clip.task = item.task
				clip.heading = item.heading

				if item.line then
					clip.line = item.line
					clip.x2 = item.x2
					clip.y2 = item.y2
				end

				local task_note1 = item.note[1]
				clip.note = wall.save_note_to_string(item.note_raw)
				local max = clipboard.char_width
				for i = 1, #item.note do
					local c = #item.note[i]
					if c > max then max = c end
				end
				clipboard.char_width = max
				clipboard.notes[c] = table.concat(item.note, "\n")
				--}}}
			end
			local div = "\n"..string.rep("-", clipboard.char_width).."\n"
			local clip = table.concat(clipboard.notes, div, 1, clipboard.count)
			if clip then
				love.system.setClipboardText(clip)
				clipboard.system = clip
				--print("          ! DATA IN CLIPBOARD !")
				--hex_dump(clip)
			end
		end --}}}
		if input.ctrl and input.paste == "pressed" then --{{{
			--convert line endings for consistency and matching purposes!
			local clip = clipboard:gettext()
			--print("            ! DATA PASTED FROM SYSTEM !")
			--hex_dump(clip)
			--print("SYSTEM and INTERNAL clipboard match?", clip == clipboard.system)
			if clip == clipboard.system then
				txn:queue("PASTE complex? note")
				--nothing has changed in the system clipboard
				local wc = wall.count
				local only_waypoints = true
				for i = 1, clipboard.count do
					if clipboard[i].type == "note" then
						only_waypoints = false
					end
				end
				for i = 1, clipboard.count do
					local clip = clipboard[i]
					do
						local note_raw = table.concat(
							wall.load_note_from_string(clip.note), "\n"
						)
						local txn = wall.transaction
						local lt = txn:get_load_table()
						local c
						c = 1; lt[c] = "x";          lt[c+1] = cell.x + clip.x
						c=c+2; lt[c] = "y";          lt[c+1] = cell.y + clip.y
						c=c+2; lt[c] = "w";          lt[c+1] = clip.w
						c=c+2; lt[c] = "h";          lt[c+1] = clip.h
						c=c+2; lt[c] = "r";          lt[c+1] = clip.r
						c=c+2; lt[c] = "created";    lt[c+1] = clip.created
						c=c+2; lt[c] = "type";       lt[c+1] = clip.type
						c=c+2; lt[c] = "task";       lt[c+1] = clip.task
						c=c+2; lt[c] = "heading";    lt[c+1] = clip.heading
						c=c+2; lt[c] = "wrap_limit"; lt[c+1] = clip.wrap_limit
						c=c+2; lt[c] = "note_raw";   lt[c+1] = note_raw
						c=c+2; lt[c] = "_auto_size"; lt[c+1] = true
						c=c+2; lt[c] = "_focused";   lt[c+1] = true
						lt.count = c

						--lt.item_id = self.count
						--lt.selected = id
						txn:queue("NEW", lt)
					end
				end
				screen_text_render = true
				--print("screen_text_render", debug.getinfo(1).currentline)
			else
				txn:queue("PASTE simple note")
				--TODO:COPY/PASTED CODE
				local item, id = wall:add_new_note(cell.x, cell.y, false)
				item.note_raw = clip
				item.note = wall.raw_string_to_note(clip, {}, theme.autowrap)
				wall:resize_note_box(id)
				wall.selected = id
				wall:exit_edit_mode()
			end
		end --}}}
		if input.delete == "pressed" then --{{{ [DELETE NOTES]
			delete_notes = true
		end
		if delete_notes then
			txn:queue("DELETE note")
			screen_text_render = true
			--print("screen_text_render", debug.getinfo(1).currentline)
			--print("delete focused", #wall.focused)
			--print("Wall count before", wall.count)
			---[[{{{ UNDO
			local wdic = wall.deleted_interval.count + 1
			if wdic > wall.deleted_interval.max then wdic = 1 end
			wall.deleted_interval.count = wdic
			local di_len = #wall.deleted_interval
			for i = 1, di_len do
				local di = wall.deleted_interval[i]
				if di == wdic then
					wall.deleted_interval[i] = false
					wall.deleted[i] = false
				end
			end
			local ptr = 1
			for i = di_len, 1, -1 do
				if not wall.deleted[i] then
					table.remove(wall.deleted, i)
					table.remove(wall.deleted_interval, i)
				end
			end
			--}}}]]
			for i = #wall.focused, 1, -1 do
				local wfi = wall.focused[i]
				wall.focused[i] = nil
				local item = wall[wfi]
				wall[wfi] = false
				table.insert(wall.deleted, item)
				table.insert(wall.deleted_interval, wdic)

				item.image_data = nil

			end

			for i = wall.count, 1, -1 do
				if not wall[i] then
					link_file_data.modified = true
					table.remove(wall._data, i)
					if i == wall.hover then
						wall.hover = 0
					end
					wall.count = wall.count - 1
					--print("removed", i, "count", wall.count)
				end
			end
			wall.selected = 0
			wall.line = 0
			wall.cursor_x = 0
		end --}}}
--}}}
		--                                                       --
		--                                                       --
		-----------------------------------------------------------
	end

	if wall.selected and wall.waypoint_button_display then
		--{{{ set waypoint_button_[xy] (for hitbox and rendering)
		local item = wall[wall.selected]
		local wpb_x, wpb_y = false, false

		local lgw, lgh = lg.getWidth(), lg.getHeight()
		local cdx, cdy =
			floor(-(lgw * 0.5 * (scale_inv - 1.0) + camera.dx) * wall.cell_inv),
			floor(-(lgh * 0.5 * (scale_inv - 1.0) + camera.dy) * wall.cell_inv)
		cdx = cdx < 0 and floor(cdx) or ceil(cdx)
		cdy = cdy < 0 and floor(cdy) or ceil(cdy)
		local cw, ch =
			ceil(lgw * wall.cell_inv * scale_inv),
			ceil(lgh * wall.cell_inv * scale_inv)
		--END


		local hcs = 0.5 --half a cell
		wpb_x = item.x - 2
		--adjust waypoint button if note is close to left edge of screen
		wpb_y = item.y + hcs
		if wpb_x - 1 <= cdx then
			wpb_x = item.x + hcs
			wpb_y = item.y - 2
			if wpb_y - 2 <= cdy then
				wpb_y = item.y + 3
			end
		end
		wall.waypoint_button_x = wpb_x
		wall.waypoint_button_y = wpb_y
		--}}} set wayopint_button_[xy] (for hitbox and rendering)
	end
	profile.update_2:lap()

end --finished input.processed

	-----------------------------------------------------------
	--                                                       --
	--                                                       --
do --{{{          PROCESS TRANSACTIONS
	--                                                       --
	--                                                       --
	-----------------------------------------------------------

	if wall.transaction.count > 0 then
		local wtxn = wall.transaction
		local pt = wtxn.print_table
		local file_loaded = false
		pt:printf("DEQUEUING transactions at %.2fs BEGIN!", hal.met)
		pt:printf(" (f:%d->%d)", wtxn.front, wtxn.count)
		while true do
			local txn, data, data2 = wall.transaction:dequeue()
			if not data then break end
			if     txn == "MSG" then
				pt:txn("", txn, data)
			elseif txn == "CLEAR" then
				wall.doprint_item_mt = false
				pt:txn("", txn, sfmt("(%s)", data))
				wall:clear_item(data)
				wall.doprint_item_mt = true
			elseif txn == "LOAD" or txn == "NEW" or txn == "UPDATE" or
				txn == "EDIT" or txn == "MODIFY"
			then
				wall.doprint_item_mt = false

				screen_text_render = true
				if txn ~= "LOAD" then
					link_file_data.modified = true
				end

				local len
				if data.item_id > 0 then
					len = data.item_id
				elseif data.item_table then
					--TODO: oof. But at least it works...
					local it = data.item_table
					for i = 1, wall.count do
						if wall[i] == it then
							len = i
							break
						end
					end
				else
					len = wall.count + 1
					wall.count = len
				end
				local comp_eid
				local idx_positions
				local idx_geometries
				local idx_tables

				local item = wall:create_item(wall[len])
				do
					local is = wall.items
					idx_tables = is.tables:map_type("table", item)
					if not idx_tables then
						local len = #is.tables.eid + 1
						is.tables.eid[len] = is.entity:new()
						is.tables.table[len] = item
						idx_tables = len
					end
					comp_eid = wall.items.tables.eid[idx_tables]
				end
				pt:txn("", txn, sfmt("data in item #%d (%s)", len, data))
				wall[len] = item
				local n = data
				local imd = item._data
				local old_note_raw = imd.note_raw
				local old_wrap_limit = imd.wrap_limit

				local scene = wall.items.scene
				for i = 1, n.count, 2 do
					local key = n[i]
					local val = n[i+1]

					imd[key] = val

					if AG.DEBUG_QUEUE_DETAIL then
						pt:txn("", "", key, val)
					end
					--print(type(comp_eid), comp_eid)
					if comp_eid then
						local tbl
						--print("key", key, "val", val)
						if key == "x" or  key == "y" then
							tbl = wall.items.positions
						elseif key == "w" or key == "h" then
							tbl = wall.items.geometries
						elseif key == "r" then
							tbl = wall.items.geometries
							--print("key", key)
							local nxt = tbl:map(comp_eid) or #tbl.w + 1
							tbl.eid[nxt] = comp_eid
							tbl.w[nxt] = val
							tbl.h[nxt] = val
							tbl = nil
						elseif key == "type" then
							tbl = wall.items.tables
						end
						if tbl then
							local nxt = tbl:map(comp_eid) or #tbl[key] + 1
							tbl.eid[nxt] = comp_eid
							tbl[key][nxt] = val or false
							scene.eid[nxt] = comp_eid
							scene.pid[nxt] = 0
						end
					end

				end
				--wall.items.positions:print{"eid", "x", "y"}
				--wall.items.geometries:print{"eid", "w", "h"}
				--wall.items.tables:print{"eid", "type"}
				--only need to resize if note_raw changed
				local note_change = old_note_raw ~= imd.note_raw or old_wrap_limit ~= imd.wrap_limit
				if note_change then
					imd.note = wall.raw_string_to_note(imd.note_raw, imd.note, imd.wrap_limit)
				end

				do --fill in missing height values
					local is = wall.items
					local geos = is.geometries
					local h = geos.h
					local items = wall.items.tables.table
					for i = 1, #h do
						if not h[i] then
							local id = geos.eid[i]
							local p = is.tables:map(id)
							h[i] = #is.tables.table[i].note
						end
					end
				end
				if txn == "EDIT" then
				--{{{ convert from rawstring to edit_line
					local id = data.item_id
					local note = wall[id].note
					--edit_line.undo:print()
					local cursor
					--log.note_cursor("%s", edit_line.undo.note_cursor)
					wall.line, cursor = wall.get_line_cursor(note, edit_line.undo.note_cursor or 0)
					local line = note[wall.line] or ""
					local offset = utf8.offset(line, cursor + 1)
					local flag = " "
					if offset then
						local ssub = string.sub
						edit_line.data_2 = ssub(line, offset)
						if cursor > 0 then
							edit_line.data = ssub(line, 1, offset-1)
							--print("cursor, offset, data", cursor, offset, edit_line.data)
						else
							edit_line.data = ""
						end
					else
						flag = "*"
						wall.line = wall.line - 1
						line = note[wall.line] or ""
						cursor = utf8.len(line)

						edit_line.data = line
						edit_line.data_2 = ""
					end
					--print("data 1, 2", edit_line.data, "|"..flag, edit_line.data_2)
					edit_line.cursor = cursor
					--print("line, cursor", wall.line, cursor)
					wall.cursor_x = font:getWidth(edit_line.data)
				--}}}
				end

				if txn == "LOAD" or txn == "NEW" or txn == "UPDATE" then
					wall.selected = len
					wall:exit_edit_mode()
					if data.selected then
						wall.selected = len
						input_state.note_edit = len
						wall.line = 1
						wall.select_text_timer = wall.select_text_timer_default
					end
				end
				if n.resize or note_change and imd.type == "note" then
					item._access.count = 0
					wall:resize_note_box(len)
					item._access.count = 0
				end
				item._queue.count = 0
				wall.doprint_item_mt = true
			elseif txn == "RESIZE" then
				wall.doprint_item_mt = false
				pt:txn("", txn, sfmt("id #%s", data))
				wall:resize_note_box(data)
				wall[data]._queue.count = 0
				wall.doprint_item_mt = true
			elseif txn == "EXIT" and data > 0 then
				wall.doprint_item_mt = false
				pt:txn("", txn, sfmt("id #%s", data))
				wall.selected = data
				wall:exit_edit_mode()
				wall[data]._queue.count = 0
				wall.doprint_item_mt = true
			elseif txn == "COMMIT" then
				--TODO: save this data somewhere
				local stype, compressed, cdata =
					data.commit_type,
					data.commit_compressed,
					data.commit_data
				pt:txnf("\t%s\tnote: %s(%s) «%d:snip»",
					txn, stype, compressed or " ", cdata and #cdata or 0
				)
			elseif txn == "LOADED" then
				file_loaded = true
			end
		end
		if file_loaded then
			--this might be set during loading, so this resets it
			link_file_data.modified = false
			pt:txn("", "LOADED", "LINK file load complete")
		end
		pt:printf("DEQUEUING transactions at %.2fs FINISHED", hal.met)
		--pt:dump()
		wall.transaction:reset()
	end
	for i = 1, wall.count do
		--log.item("wall[%d]._access.count = %d", i, wall[i]._access.count)
		local item = wall[i]
		item._access.count = 0
		--local q = item._queue
		--for k = 1, q.count, 2 do
		--	log.item("NOT DEQUEUED! #%02d) SET %s = %s", i, q[k], q[k+1])
		--end

		item._queue.count = 0
	end



end --}}} PROCESS TRANSACTIONS
	--                                                       --
	--                                                       --
	-----------------------------------------------------------

	-----------------------------------------------------------
	--                                                       --
	--                                                       --
do  --{{{          SETUP — RENDER_WALL                       --
	--                                                       --
	--                                                       --
	-----------------------------------------------------------
	local rw = render_wall
	if  screen_text_render or
		rw.cam_lx ~= camera.dx or
		rw.cam_ly ~= camera.dy or
		rw.scale_last ~= scale_level
	then
		profile.find_1:start()
		profile.setup_render_wall:start()
		wall.status_str = sfmt(" %d%% (%3d,%3d) ",
			 scale * 100,
			 -camera.dx * wall.cell_inv, -camera.dy * wall.cell_inv
		)
		wall.status_len = font:getWidth(wall.status_str)
		--print("cam_lx", rw.cam_lx, "cam.dx", camera.dx)
		--print("cam_ly", rw.cam_ly, "cam.dy", camera.dy)
		--print("scale_last", rw.scale_last, "scale_level", scale_level)
		--print("screen_text_render", screen_text_render)
		camera.dx = floor(camera.dx)
		camera.dy = floor(camera.dy)
		rw.cam_lx = camera.dx
		rw.cam_ly = camera.dy
		rw.scale_last = scale_level
		screen_text_render = false
		rw.updated = 2

		rw.image.count = 0

		local screen_text = wall.screen_text
		screen_text:clear()
		edit_line.h1_text:clear()

		--TODO: scaled camera dimensions COPY/PASTE
		local lgw, lgh = lg.getWidth(), lg.getHeight()
		local cdx, cdy =
			floor(-(lgw * 0.5 * (scale_inv - 1.0) + camera.dx) * wall.cell_inv),
			floor(-(lgh * 0.5 * (scale_inv - 1.0) + camera.dy) * wall.cell_inv)
		cdx = cdx < 0 and floor(cdx) or ceil(cdx)
		cdy = cdy < 0 and floor(cdy) or ceil(cdy)
		local cw, ch =
			ceil(lgw * wall.cell_inv * scale_inv),
			ceil(lgh * wall.cell_inv * scale_inv)

		local wx, wy, ww, wh, wr = 0, 0, 0, 0, 0
		local visible = false
		local rcnt = 0
		local rcnt_waypnt = 0
		--print("wall.count = ", wall.count)
		local rendered_waypoint = 0
		lines:clear()
		local wis = wall.items
		local wi_x = wis.positions.x
		local wi_y = wis.positions.y
		local wi_w = wis.geometries.w
		local wi_h = wis.geometries.h
		local wi_item = wis.tables.table
		local wi_type = wis.tables.type
		profile.find_1:lap()
		for i = 1, #wi_x do
			profile.find_2:start()
			--local item = wall[i]

			--log.item("%d(%s) x %s, y %s, w %s, h %s, r %s",
			--	i, item.type,
			--	item.x,
			--	item.y,
			--	item.w,
			--	item.h,
			--	item.r
			--)

			local collides = false

			wx, wy = wi_x[i], wi_y[i]
			ww, wh = wi_w[i], wi_h[i]
			if wi_type[i] == "waypoint" then
				local offs = wall.waypoint_display_offset
				wx = wx + offs
				wy = wy + offs
				wr = wall.waypoint_radius
				ww = wr
				wh = wr
			end
			if  wx + ww > cdx and
				wx <= cdx + cw and
				wy + wh > cdy and
				wy <= cdy + ch
			then
				collides = true
			end
			if collides then
				local cs = wall.cell_size
				local x = wx * cs
				local y = wy * cs

				if wi_type[i] == "note" then
					local item = wi_item[i]
					local note = item.note or rw.default_note
					local w = ww * cs
					local h = wh * cs
					rcnt = rcnt + 1
					rw.x[rcnt] = x
					rw.y[rcnt] = y
					rw.w[rcnt] = w
					rw.h[rcnt] = h
					local istask = (wall.selected ~= i) and item.task
					rw.task[rcnt] = istask
					rw.heading[rcnt] = item.heading
					rw.image[rcnt] = item.image and item.image_data
					rw.image_scale[rcnt] = item.image_scale
					rw.image_rotate[rcnt] = item.image_rotate or 0
					rw.image_offx[rcnt] = item.image_offx or 0
					rw.image_offy[rcnt] = item.image_offy or 0

					rw.note[rcnt] = note
					if item.heading then
						lg.setFont(edit_line.font_h1)
						lg.setColor(color.TEXT)
						local cs = wall.h1_cell_size
						for k = 2, #note do
							--lg.print(note[k] or "", cs * .5 + x, (k-1) * cs + y)
							edit_line.h1_text:add(note[k] or "",
								floor(cs * .5 + x),
								floor((k-2) * cs + y)
							)
						end
						lg.setFont(font)
					elseif item.image then
					elseif scale_level > -7 then
						--TODO: remove magic number
						--We only need to render text at higher scale levels.
						--At too low values, the text is hardly visible but
						--still takes a lot of CPU to render that text.
						local kstart = 1
						local x = cs * .5 + x
						if istask then
							local nx = x
							local ns = ""
							--TODO: this only known to work for CrimsonPro-Light 16pt
							nx = nx + fonts.astrisk_width
							ns = string.sub(note[1], 2)

							screen_text:add(ns, nx, y)
							kstart = 2
						end
						for k = kstart, #note do
							screen_text:add(note[k] or "",
								x, floor((k-1) * cs + y)
							)
						end
					end
				elseif wi_type[i] == "waypoint" and not wi_item[i].discard then
					local item = wi_item[i]
					local r = wr

					if item.line then
						local offs = wall.waypoint_display_offset
						r = wr * 0.75
						local x2, y2 = item.line.x, item.line.y
						lines:add(item.x, item.y, x2, y2)
						rcnt_waypnt = rcnt_waypnt + 1
						rw.waypoint.x[rcnt_waypnt] = (x2 + offs) * cs
						rw.waypoint.y[rcnt_waypnt] = (y2 + offs) * cs
						rw.waypoint.r[rcnt_waypnt] = r
						--log.waypoint("LINE2:%02d: x: %.2f, y: %.2f, rad: %d, w: %d, h: %d\n",
						--	i, item.x2 * cs, item.y2 * cs, r, ww, wh
						--)
					end
					--printf("waypoint%02d: x: %d, y: %d, rad: %d, w: %d, h: %d\n", i, x, y, r, ww, wh)
					rcnt_waypnt = rcnt_waypnt + 1
					rw.waypoint.x[rcnt_waypnt] = x
					rw.waypoint.y[rcnt_waypnt] = y
					rw.waypoint.r[rcnt_waypnt] = r
					--rendered_waypoint = rendered_waypoint + 1
					end

			end
			profile.find_2:lap()
		end
		--if rendered_waypoint > 0 then
		--	printf("%d waypoints added to render wall\n", rendered_waypoint)
		--end
		rw.count = rcnt
		rw.waypoint.count = rcnt_waypnt
		--set_status(sfmt("render count : %d", rcnt), 0)

		--set_status(sfmt(
		--	"cell: (%d,%d) camera: orig(%d,%d) (%d,%d+%d,%d) render: %d/%d %d%%| scale: %.2f, inv: %.2f",
		--	cell.x, cell.y,
		--	camera.dx * wall.cell_inv,
		--	camera.dy * wall.cell_inv,
		--	cdx, cdy, cdx + cw, cdy + ch,
		--	rcnt, wall.count, rcnt / wall.count * 100,
		--	scale, scale_inv
		--), 0)

	    ---[[ DRAW to CANVAS {{{
if canvas then lg.setCanvas(canvas)
		local waypoints_rendered = 0
		--print("RENDERING CANVAS", canvas)
	do lg.push()
		local r,g,b,a = lg.getColor()
		local hw = lg.getWidth() * 0.5
		local hh = lg.getHeight() * 0.5
		lg.clear()
		lg.translate(hw, hh)
		lg.scale(scale)
		lg.translate(camera.dx - hw,camera.dy - hh)
		lg.setBlendMode("alpha")

		if theme.grid then --{{{
			profile.draw_grid:start()
			local dx, dy = -camera.dx - (hw * (scale_inv - 1)), -camera.dy - (hh * (scale_inv - 1))
			local cs = wall.cell_size
			local csinv = wall.cell_inv
		if scale_level >= theme.grid_scale_level then
			--print("scale, scale_inv", scale, scale_inv)
			--local dx, dy = -camera.dx , -camera.dy
			local cx, cy =
				floor(dx * csinv) * cs + 1,
				floor(dy * csinv) * cs + 1
			--print("Camera", dx, dy, cx, cy)
			local w, h = lg.getDimensions()
			w, h = w + cs, h + cs
			w, h = w + w * scale_inv, h + h * scale_inv
			lg.setLineWidth(1)
			lg.setLineStyle("rough")
			if theme.grid == "line" then
				lg.setColor(color.GRID_LINE)
				for i = 0, ceil(w * csinv) do
					lg.line(cx + cs * i, cy, cx + cs * i, cy + h)
				end
				for i = 0, ceil(h * csinv) do
					lg.line(cx, cy + cs * i, cx + w, cy + cs * i)
				end
			elseif theme.grid == "dot" then
				lg.setColor(color.GRID_DOT)
				local gt = theme._grid_table
				if gt.w ~= w or gt.h ~= h then
					gt.w, gt.h = w, h
					local c = 0
					for x = 0, ceil(w * csinv) do
						for y = 0, ceil(h * csinv) do
							gt[c+1] = cs * x
							gt[c+2] = cs * y
							c = c + 2
						end
					end
					for i = c + 1, #gt do
						gt[i] = nil
					end
				end
				lg.push()
				lg.translate(cx, cy)
				lg.points(gt)
				lg.pop()
			end
		end --if scale_level...

			if theme.grid_major then
				local gmw = 0
				local gmh = 0
				local tgm = theme.grid_major
				local w, h = lg.getDimensions()
				if tgm == "screen" then
					gmw = ceil(w * csinv)
					gmh = ceil(h * csinv)
				elseif tgm == "half" then
					gmw = ceil(w * 0.5 * csinv)
					gmh = ceil(h * 0.5 * csinv)
				elseif tgm == "custom" then
					gmw = theme.grid_major_w
					gmh = theme.grid_major_h
				end
				--print("grid_major", tgm, gmw, gmh)
				do
					local grid_weight = 1
					if scale_level >= theme.grid_scale_level and
						theme.grid_major_weight == "thick"
					then
						grid_weight = 3
					end
					lg.setLineWidth(floor(grid_weight * scale_inv))
				end
				local cs20w = cs * gmw
				local cs20winv = 1.0 / (cs20w)
				local cs20h = cs * gmh
				local cs20hinv = 1.0 / (cs20h)
				w, h = w + cs20w, h + cs20h
				w, h = w + w * scale_inv, h + h * scale_inv
				local cx, cy =
					floor(dx * cs20winv) * cs20w + 1.5,
					floor(dy * cs20hinv) * cs20h + 0.5
				local csw, csh = w * cs20winv, h * cs20hinv
				lg.setColor(color.GRID_LINE_ORIGIN)
				lg.setColor(color.GRID_LINE)
				for i = 0, ceil(w * cs20winv) + 2 do
					local lx = cx + cs20w * i
					local origin = abs(lx) < cs
					if origin then lg.setColor(color.GRID_LINE_ORIGIN) end
					lg.line(cx + cs20w * i, cy, cx + cs20w * i, cy + h + h)
					if origin then lg.setColor(color.GRID_LINE) end
				end
				for i = 0, ceil(h * cs20hinv) + 2 do
					local ly = cy + cs20h * i
					local origin = abs(ly) < cs
					if origin then lg.setColor(color.GRID_LINE_ORIGIN) end
					lg.line(cx, cy + cs20h * i, cx + w + w, cy + cs20h * i)
					if origin then lg.setColor(color.GRID_LINE) end
				end
			end

			lg.setColor(r,g,b,a)
			lg.setLineStyle("smooth")
			profile.draw_grid:lap()
		end --}}}

		--render_wall
		do
			local rw = render_wall
			local x = rw.x
			local y = rw.y
			local w = rw.w
			local h = rw.h
			lg.setColor(color.BOX)
			for i = 1, rw.count do
				lg.rectangle("fill", x[i]+1, y[i]+1, w[i]-1, h[i]-1)
			end
		end
		---[[ Broken lines code {{{
		do
			local lw = lg.getLineWidth()
			lg.setLineWidth(lines.width)

			if lines.x1 then
				set_status(lines.select_end_point)
				local cs = wall.cell_size
				local x1 = (lines.x1 + 0.5) * cs
				local y1 = (lines.y1 + 0.5) * cs
				local x2 = (cell.x + 0.5) * cs
				local y2 = (cell.y + 0.5) * cs

				lg.line(x1, y1, x2, y2)
			end

			local x = lines.x
			local y = lines.y
			local cs = wall.cell_size
			for i = 1, lines.ptr, 2 do
				--print("print line", cs,
				--	  x[i] * cs,   y[i] * cs,
				--	x[i+1] * cs, y[i+1] * cs
				--)
				local x1, y1, x2, y2 =
					(  x[i] + 0.5) * cs, (  y[i] + 0.5) * cs,
					(x[i+1] + 0.5) * cs, (y[i+1] + 0.5) * cs
				lg.line(x1, y1, x2, y2)
			end
			lg.setLineWidth(lw)
		end
		--}}}Broken lines code]]
		do
			--{{{DRAW WAYPOINTS
			local rw = render_wall.waypoint
			local x = rw.x
			local y = rw.y
			local rad = rw.r
			lg.setColor(color.BOX)
			for i = 1, rw.count do
				--waypoints_rendered = waypoints_rendered + 1
				--printf("waypoint%02d: x: %d, y: %d, rad: %d\n", i, x[i], y[i], rad[i])
				lg.circle("fill", x[i], y[i], rad[i])
			end
			lg.setColor(color.TEXT)
			for i = 1, rw.count do
				local x, y, r = x[i], y[i], rad[i] * 0.25
				local r2 = r - r * 0.5
				lg.polygon("fill", x - r2, y - r, x+r+r2, y, x-r2, y+r)
			end
			--}}}DRAW WAYPOINTS
		end

		if wall.waypoint_button_x then
			local cs = wall.cell_size
			local x = wall.waypoint_button_x * cs
			local y = wall.waypoint_button_y * cs
			lg.setColor(color.WAYPOINT)
			lg.circle("fill", x, y, cs)
			screen_text:add(wall.waypoint_button_string,
				floor(x - cs * 0.5),
				floor(y - cs * 0.5)
			)
		end

		lg.setColor(color.TEXT)
		local cs = wall.cell_size
		lg.draw(screen_text)
		lg.draw(edit_line.h1_text)
		do
			local rw = render_wall
			local x = rw.x
			local y = rw.y
			local w = rw.w
			local h = rw.h
			local task = rw.task
			local head = rw.heading
			local img = rw.image
			local img_scale = rw.image_scale
			local img_rotate = rw.image_rotate
			local imgxo = rw.image_offx
			local imgyo = rw.image_offy
			local cs = wall.cell_size
			lg.setLineWidth(2)
			lg.setColor(color.TASK)
			local cs4 = 0
			local cs2 = 0
			local y_off = 0
			local y_off_line = 0
			if fonts.type_face_option == "serif" then
				cs4 = floor(cs * 0.2)
				cs2 = cs4 + cs4
				y_off = floor(cs4 * 0.9)
				y_off_line = cs4
			else
				cs4 = floor(cs * 0.25)
				cs2 = cs4 + cs4
			end
			for i = 1, rw.count do
				if task[i] then
					local tx = x[i]+cs4
					local ty = y[i]+cs2 + y_off_line
					local style = "line"
					if task[i] == "complete" then
						style = "fill"
					end
					lg.rectangle(style, tx + cs4, y[i]+cs4+y_off, cs2, cs2)
					lg.circle(style, tx + cs2, y[i]+cs2+y_off, cs4 + 1)

					if task[i] == "cancel" then
						lg.setColor(color.TASK_CANCEL)
						for k = 1, #rw.note[i] do
							local tycsi = cs * (k - 1) + ty
							lg.line(tx, tycsi, tx + w[i] - cs2, tycsi)
						end
						lg.setColor(color.TASK)
					end
				elseif img[i] then
					lg.setColor(1,1,1,1)
					lg.draw(img[i], x[i] + imgxo[i], y[i] + imgyo[i], img_rotate[i], img_scale[i])
					lg.setColor(color.TASK)
				end
			end
			lg.setLineWidth(1)
			lg.setColor(r,g,b,a)
		end
	lg.pop() end

	--printf("%d waypoints rendered\n", waypoints_rendered)
lg.setCanvas() end
		profile.setup_render_wall:lap()
--]] }}}
	end
	--}}} END setup render_wall
	--                                                       --
	--                                                       --
	-----------------------------------------------------------
end


	--- PROFILE Print ---
	if hal.debug_display then
		profile:dump_all(dt)
	end

	profile.inside_update:lap()
end --}}} END update()

-------------------------------------------------------------------
--                                                               --
--                                                               --
--                       Render                                  --
--                                                               --
--                                                               --
-------------------------------------------------------------------
--{{{ y_pos function
local y_pos_inc
local y_pos_val =  0
local y_pos = function(reset)
	if not y_pos_inc then
		if not font then return 0 end
		y_pos_inc = font:getHeight()
	end
	if reset then
		local value = 0
		if type(reset) == "number" then
			value = reset
		end
		y_pos_val = value - y_pos_inc
		return 0
	end
	y_pos_val = y_pos_val + y_pos_inc
	return y_pos_val
end
--}}}
local function render(alpha) --{{{
	-- Render Text

	-- Render Graphics
	if not canvas or not font then
		printftime("Canvas: %s, Font: %s",
			canvas and "Yes" or "No",
			font and "Yes" or "No"
		)
		return false
	end
	local present = false
	local r,g,b,a = lg.getColor()
	if edit_line.show_cursor_last ~= edit_line.show_cursor then
		edit_line.show_cursor_last = edit_line.show_cursor
		render_wall.updated = 2
	end

	--{{{ canvas and render_wall.updated
	if canvas and render_wall.updated then
		--print("canvas and render_wall.updated", render_wall.updated)
		present = true
		profile.render_canvas:start()
		lg.clear(lg.getBackgroundColor())
		lg.setColor(1,1,1,1)
		lg.setBlendMode("alpha", "premultiplied")
		lg.draw(canvas)
		lg.setColor(r,g,b,a)
		profile.render_canvas:lap()

	do lg.push()
		local hw = lg.getWidth() * 0.5
		local hh = lg.getHeight() * 0.5
		lg.translate(hw, hh)
		lg.scale(scale)
		lg.translate(camera.dx - hw,camera.dy - hh)
		lg.setBlendMode("alpha")

		lg.setColor(color.FOCUS_OUTLINE)
		local anchor_render = round(wall.cell_size * wall.resize_anchor_render)
		local anchor_hover = round(wall.cell_size * wall.resize_anchor_cs)
		lg.setLineWidth(anchor_render)
		for i = 1, #wall.focused do
			local id = wall.focused[i]
			local item = wall[wall.focused[i]]
			local cs = wall.cell_size
			local wt = item and item.type
			if wt == "note" then
				local ins = input_state
				if ins.active_resize and ins.active_hold == id then
					--TODO: x,y,w,h COPY/PASTED (This is a mess, fix the whole thing!)
					local ra = wall.resize_anchor_cs * 0.5
					local x = (item.x - ra    ) * cs + 0.5
					local y = (item.y - ra    ) * cs + 1.5
					local w = (item.w + ra * 2) * cs
					local h = (item.h + ra * 2) * cs - 1
					lg.setColor(color.FOCUS_OUTLINE_HL)
					lg.setLineWidth(anchor_hover)
					lg.rectangle("line",x,y,w,h)
					lg.setLineWidth(anchor_render)
					if item._auto_size and ins.active_hold > 0 then
						local side = ins.active_resize
						if side == "e" or side == "w" then
							local w = (1 + ra + ra) * cs + item.wrap_limit
							lg.rectangle("line", x, y, w, h)
							--log.auto_size_render("x: %d", x)
						end
					end
					lg.setColor(color.FOCUS_OUTLINE)
				else
					local ra = wall.resize_anchor_render * 0.5
					local x = (item.x - ra    ) * cs
					local y = (item.y - ra    ) * cs + 1
					local w = (item.w + ra * 2) * cs
					local h = (item.h + ra * 2) * cs - 1
					lg.rectangle("line",x,y,w,h)
				end
			elseif wt == "waypoint" then
				local w = item
				local cs = w.r
				local offs = wall.waypoint_display_offset
				lg.circle("line", (w.x + offs) * cs, (w.y + offs) * cs, cs)
			end
		end

		y_pos(true)
		--lg.print("Edit Mode: ".. tostring(hal.input.edit_mode()), 0, y_pos())
		--lg.print("Key Repeat: ".. tostring(love.keyboard.hasKeyRepeat()),
		--	0, y_pos()
		--)
		--local edit_line_y_position = y_pos()
		--lg.print(sfmt("> %s%s", edit_line.data, edit_line.data_2),
		--	0, edit_line_y_position
		--)
		if edit_mode then
			profile.render_edit_mode:start()
			local item = wall[wall.selected]
			local cs = wall.cell_size

			if wall.min_x then
				local x = item.x * cs + wall.note_border_w + wall.select_cursor_x
				local y = (item.y + (wall.select_line - 1)) * cs

				lg.rectangle("fill", x, y, 2, cs)

				lg.setColor(color.TEXT_SELECT)
				--lg.setColor(r,g,b, .18)
				--print(" - SELECTION OUTLINE?", color.rgba2hex(r,g,b, .18))

				if wall.min_line == wall.max_line then
					local x = item.x * cs + wall.note_border_w + wall.min_x
					local y = (item.y + (wall.min_line - 1)) * cs
					local w = wall.max_x - wall.min_x
					lg.rectangle("fill", x, y, w, cs)
				else
					local x = item.x * cs + wall.note_border_w + wall.min_x
					local y = (item.y + (wall.min_line - 1)) * cs
					local w = item.w * cs - wall.min_x - (wall.note_border_w * 2)
					lg.rectangle("fill", x, y, w, cs)
					x = item.x * cs + wall.note_border_w
					w = item.w * cs - (wall.note_border_w * 2)
					--TODO: highlight line up to end of text, not full box width
					for i = wall.min_line + 1, wall.max_line - 1 do
						y = (item.y + (i - 1)) * cs
						lg.rectangle("fill", x, y, w, cs)
					end
					x = item.x * cs + wall.note_border_w
					y = (item.y + (wall.max_line - 1)) * cs
					w = wall.max_x
					lg.rectangle("fill", x, y, w, cs)
				end
			end
			local line_w = lg.getLineWidth()
			local new_w = 5
			local dxy = floor(new_w * 0.5) - 1
			local dwh = new_w - 2
			lg.setLineWidth(new_w)
			lg.setColor(color.EDITING)
			lg.rectangle("line",
				item.x * cs - dxy,
				item.y * cs - dxy,
				item.w * cs + dwh,
				item.h * cs + dwh
			)
			lg.setLineWidth(line_w)

			if edit_line.show_cursor then
				local cc = color.CURSOR
				local x = item.x * cs + wall.note_border_w + wall.cursor_x
				local y = (item.y + (wall.line - 1)) * cs
				if x >= (item.x + item.w) * wall.cell_size then
					cc = color.BOX
				end
				--print("item.x + item.w, x", (item.x + item.w) * wall.cell_size, x)
				lg.setColor(cc)
				lg.rectangle("fill", x, y, 2, cs)
			end

			profile.render_edit_mode:lap()
		end

		lg.setLineWidth(1)
		if input_state.rectangle_select then
			lg.setColor(color.RECTANGLE_SELECT)
			local ins = input_state
			local cs = wall.cell_size
			local x, y, w, h =
				ins.grab_x * cs + 0.5,
				ins.grab_y * cs + 0.5,
				ins.grab_w * cs,
				ins.grab_h * cs
			if abs(w) < 1 then w = 1 end
			if abs(h) < 1 then h = 1 end
			lg.rectangle("line", x, y, w, h)
		end

	lg.pop() end
	end
	--}}} canvas and render_wall.updated
	if dialog[1].render then --{{{
		--print("dialog[1].render")
		present = true
		lg.setFont(dialog.font)
		local box = dialog[1]
		local btn_left, btn_middle, btn_right
		local btn_select
		if box.type == "YESNO" then
			btn_left = box.no
			btn_right = box.yes
			btn_select = box.yes
			if box.selected == "NO" then
				btn_select = box.no
			end
			if box.last ~= box.selected then
				--print("box.selected changed", box.last, box.selected)
				box.last = box.selected
				render_wall.updated = 2
			end
		else
			box.render = false
		end
		if box.render then
			local box = dialog[1]
			lg.setColor(color.DIALOG_BG)
			lg.rectangle("fill", box.x, box.y, box.w, box.h)
			lg.setColor(color.DIALOG_BUTTON)
			lg.rectangle("fill", btn_left.x, btn_left.y, btn_left.w, btn_left.h)
			lg.rectangle("fill", btn_right.x, btn_right.y, btn_right.w, btn_right.h)
			lg.print(box.msg, box.msg_x, box.msg_y)
			lg.setColor(color.DIALOG_BUTTON_TEXT)
			lg.print(btn_left.title,
				btn_left.x + btn_left.xo,
				btn_left.y + btn_left.yo
			)
			lg.print(btn_right.title,
				btn_right.x + btn_right.xo,
				btn_right.y + btn_right.yo
			)

			local line_w = lg.getLineWidth()
			local new_w = 5
			local dxy = floor(new_w * 0.5) - 1
			local dwh = new_w - 2
			lg.setLineWidth(new_w)
			lg.setColor(color.EDITING)
			lg.rectangle("line",
				btn_select.x - dxy,
				btn_select.y - dxy,
				btn_select.w + dwh,
				btn_select.h + dwh
			)
			lg.setLineWidth(line_w)
		end
		lg.setFont(font)
	end --}}}
	if render_wall.updated then --{{{ render status bar
		--print("render_wall.updated")
		present = true
		profile.render_status:start()
		lg.setColor(color.STATUS_BG)
		lg.rectangle("fill", 0, 0, lg.getWidth(), wall.cell_size)
		lg.setColor(color.STATUS_FG)
		local ma = hal.input.mouse.absolute
		if status_message.text then
			lg.print(status_message.text, wall.cell_size * 0.5, 0)
		else
			lg.print(sfmt("%s %s", link_file_data.name or "(error)",
				link_file_data.modified and "*" or ""
			), wall.cell_size * 0.5, 0)
			if wall.status_len > 0 then
				lg.print(wall.status_str, lg.getWidth() - wall.status_len, 0)
			end
		end
		profile.render_status:lap()
	else
		lg.setColor(r,g,b,a)
	end --}}}]]
do
	local rwu = render_wall.updated
	if rwu then
		rwu = rwu - 1
		if rwu <= 0 then
			rwu = false
		end
		render_wall.updated = rwu
	end
end
	return present
end --}}}

return function()
	return initialize, update, render
end
