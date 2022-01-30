-- Copyright 2020 -- Scott Smith --
---[ Keys2 ]--------------------------------------------------------------------
-- Midi Numbers
-- 0xWXYZ
-- * W: always 1, represents "Control Change"
-- * X: channel number (0-
-- * 
--------------------------------------------------------------------------------
local tonumber = tonumber
local floor = math.floor

local _VERSION = "Keys2 0.5.0"

local keys2 = {keys = {}, pressed = {}, released = {}, text = {}, all = {}}
do local x, y = love.mouse.getPosition()
	keys2.mouseevent = {"moved", x, y, 0, 0}
end

--{{{--[[ Midi Handling ]]------------------------------------------------------
local inv127 = 1/127
local _, midi_saved = export("check", "halmidi_saved")
midi_saved = midi_saved or {}
keys2.midi = setmetatable({
	count = 0, size = 2, saved = midi_saved, inv127 = inv127
},{
	__call = function(self, key, multiplier, add)
		multiplier, add = multiplier or 1, add or 0
		return (self.saved[key] or 63.5) * inv127 * (multiplier) + (add)
	end
})

if export("check","DEBUG") and DEBUG then
	hal.debug.midi_retval = {}
	local midimt = getmetatable(keys2.midi)
	local call = midimt.__call
	function midimt.__call(self, key, ...)
		local retval = call(self, key, ...)
		hal.debug.midi_retval[key] = retval
		return retval
	end
end
--}}}--[[ End Midi Handling ]]--------------------------------------------------

--[[ Gamepad Table ]]-- {{{
keys2.gamepad = {count = 0, button = {}, pressed = {}, released = {}}
keys2.gamepad.size = {
	axis     = 4,
	button   = 3,
	pressed  = 3,
	released = 3,
}
--[[END: Gamepad Table ]]-- }}}

keys2.pressed.count = 0
keys2.released.count = 0
keys2.text.count = 0
keys2.all.count = 0

--the mouse event moved always has the initial position in the stack
--on update, the values are modified inplace on the stack
keys2.mouseevent.count = 5
keys2.mouseevent.size = {
	wheel = 3,
	moved = 5,

	button = 4,
	pressed = 4,
	released = 4,
}

keys2.touchevent = {
	count = 0,
	touch_count = 0,
	moved_i = {},

	last_idx = 0,
	id = {},
	last_x = {},
	last_y = {},
	size = {
		moved = 7,
		pressed = 5,
		released = 5,
	}
}

function keys2:reset()
	self.midi.count = 0
	self.pressed.count = 0
	self.released.count = 0
	self.text.count = 0
	self.all.count = 0
	self.mouseevent.count = 5
	--reset dx and dy only for moved event
	self.mouseevent[4] = 0
	self.mouseevent[5] = 0

	self.gamepad.count = 0

	self.touchevent.count = 0
	for i = 1, self.touchevent.touch_count do
		self.touchevent.moved_i[i] = -1
	end
	self.touchevent.touch_count = 0
end

--{{{ --[[ Input Handling ]]--
local keys = keys2.keys

local function love_keypress(tt, key, scancode)
	local k2t = keys2[tt]
	k2t.count = k2t.count + 1
	k2t[k2t.count] = key

	local all = keys2.all
	local c = all.count
	all.count = c + 2
	all[c+1] = tt
	all[c+2] = key
end

local function love_mouseevent(k2t, etype, x, y, button)
	local i = k2t.count
	if etype ~= "pressed" and etype ~= "released" and etype ~= "wheel" then
		error("unrecognized mouse event type, "..etype)
	end
	k2t.count = i + k2t.size[etype]

	k2t[i+1] = etype --see; /keys2.mouseevent.size
	k2t[i+2] = x
	k2t[i+3] = y
	k2t[i+4] = button --doesn't matter if size < 4
end

local function love_touchevent(k2t, etype, id, x, y, dx_pressure, dy, pressure)
	local i = k2t.count
	if etype ~= "moved" and etype ~= "pressed" and etype ~= "released" then
		error("unrecognized touch event type, "..etype)
	end
	local prev_dx, prev_dy = 0, 0
	local etype_size = k2t.size[etype]
	if etype == "moved" then
		if (k2t.moved_i[id] or -1) >= 0 then
			--restore previous moved event and deltas
			i = k2t.moved_i[id]
			prev_dx = k2t[i+5]
			prev_dy = k2t[i+6]
			--event table won't grow, using previous event
			etype_size = 0
		else
			--store moved event location
			k2t.moved_i[id] = i
			if k2t.touch_count < id then
				k2t.touch_count = id
			end
		end
	end
	k2t.count = i + etype_size

	k2t[i+1] = etype
	k2t[i+2] = id
	k2t[i+3] = x
	k2t[i+4] = y
	k2t[i+5] = prev_dx + dx_pressure
	--like mouseevent, if size < 6, these values will be ignored/overwritten
	k2t[i+6] = prev_dy + dy
	k2t[i+7] = pressure
end

local function love_gamepadevent(k2t, etype, id, button_axis, value)
	local i = k2t.count
	if etype ~= "pressed" and etype ~= "released" and etype ~= "axis" then
		error("unrecognized gamepad event type, "..etype)
	end
	k2t.count = i + k2t.size[etype]

	k2t[i+1] = etype --see; keys2.gamepad.size
	k2t[i+2] = id
	k2t[i+3] = sfmt("gp%d_%s", id, button_axis)
	k2t[i+4] = value --doesn't matter if size < 4
end

function keys2.getHandlers()
	local handlers = {}
	function handlers.filedropped(file)
		printf("File dropped: \"%s\"\n", file:getFilename())
	end
	function handlers.directorydropped(name)
		printf("Directory dropped: \"%s\"\n", name)
	end
	function handlers.keypressed(key)
		keys[key] = true
		love_keypress("pressed", key)
	end

	function handlers.keyreleased(key)
		keys[key] = false
		love_keypress("released", key)
	end

	function handlers.textinput(text)
		love_keypress("text", text)
	end

	function handlers.mousemoved(x, y, dx, dy)
		local me = keys2.mouseevent
		if me[1] == "moved" then
			me[2] = x
			me[3] = y
			me[4] = me[4] + dx
			me[5] = me[5] + dy
		else
			error("keys2.mouseevent[1] must always be \"moved\"")
		end
	end

	function handlers.mousepressed(x, y, button)
		love_mouseevent(keys2.mouseevent, "pressed", x, y, button)
	end

	function handlers.mousereleased(x, y, button)
		love_mouseevent(keys2.mouseevent, "released", x, y, button)
	end

	--TODO: handler focus won't register properly. have to register in akpack
	function handlers.focus(f)
		print("Focused:", f)
	end

	function handlers.wheelmoved(x,y)
		love_mouseevent(keys2.mouseevent, "wheel", x, y)
	end

	local touchevents = keys2.touchevent
	function handlers.touchpressed(id, x, y, dx, dy, pressure)
		x = floor(x + 0.5)
		y = floor(y + 0.5)
		local index = touchevents.last_idx + 1
		for i = 1, index - 1 do
			if not touchevents.id[i] then
				index = i
				break
			end
		end
		if index > touchevents.last_idx then
			touchevents.last_idx = index
		end
		touchevents.id[index] = id
		touchevents.last_x[index] = x
		touchevents.last_y[index] = y

		pressure = pressure or 1.0

		love_touchevent(touchevents, "pressed", index, x, y, pressure, 0, 0)
	end

	function handlers.touchreleased(id, x, y, dx, dy, pressure)
		x = floor(x + 0.5)
		y = floor(y + 0.5)
		local index = touchevents.last_idx
		for i = 1, index do
			if touchevents.id[i] == id then
				touchevents.id[i] = false
				if i == index then
					touchevents.last_idx = index - 1
				end
				index = i
				break
			end
		end
		pressure = pressure or 0.0

		love_touchevent(touchevents, "released", index, x, y, pressure, 0, 0)
	end

	function handlers.touchmoved(id, x, y, dx, dy, pressure)
		x = floor(x + 0.5)
		y = floor(y + 0.5)
		local index = touchevents.last_idx
		for i = 1, index do
			if touchevents.id[i] == id then
				index = i
				break
			end
		end
		--dy is nul for some reason so I have to figure it out myself 
		--also figure I might as well do it for dx while I'm at it
		dx = x - touchevents.last_x[index]
		dy = y - touchevents.last_y[index]
		touchevents.last_x[index] = x
		touchevents.last_y[index] = y

		pressure = pressure or 1.0

		love_touchevent(touchevents, "moved", index, x, y, dx, dy, pressure)
	end

	function handlers.gamepadpressed(gp, button)
		love_gamepadevent(keys2.gamepad, "pressed", gp:getID(), button)
	end

	function handlers.gamepadreleased(gp, button)
		love_gamepadevent(keys2.gamepad, "released", gp:getID(), button)
	end

	function handlers.gamepadaxis(gp, axis, value)
		love_gamepadevent(keys2.gamepad, "axis", gp:getID(), axis, value)
	end

	return handlers
end

do --initialize love callback handlers
	local handlers = keys2.getHandlers()
	for k,v in next, handlers do
		love[k] = v
	end
end

local function love_midievent(k2t, etype, channel, midikey, value, a3)
	local key = 0
	a3 = a3 or 0
	local alsa = require"midialsa"
	if etype == "control change" then
		local controller = midikey
		a3 = 0
		key = 0xB000
	elseif etype == "note on" then
		local pitch, velocity, duration = midikey, value, a3
		if midikey == 0 then
			alsa.output(alsa.controllerevent(0, 9, 27))
		end
		key = 0x8000
	elseif etype == "note off" then
		local pitch, velocity, duration = midikey, value, a3
		if midikey == 0 then
			alsa.output(alsa.controllerevent(0xa, 1, midi_saved[0xba01] or 0))
		end
		key = 0x9000
	elseif etype == "program change" then
		midikey = 0
		key = 0xC000
	end
	if key == 0 then
		error("unrecognized midi event type!")
	end

	local i = k2t.count
	k2t.count = i + k2t.size --size should be 2

	--0x1234 (key == 1, channel == 2, controller == 34)
	--key = key + (channel * 0x100) + controller
	key = key + (channel * 0x100) + midikey
	printf("0x%04x %3d : %02x %02x %02x %s",
		key, value, midikey, value, a3, etype
	)
	k2t[i+1] = key
	k2t[i+2] = value
	k2t.saved[key] = value
end

local midi_receive
if hal_conf.midi and love.system.getOS() == "Linux" then
	local alsa = require "midialsa"
	local inv127 = 1/127
midi_receive = function()
	if not alsa.inputpending() then return end
	while alsa.inputpending() > 0 do
		local amidi_in = alsa.input()
		local evtype = amidi_in[1]
		if evtype == alsa.SND_SEQ_EVENT_PORT_UNSUBSCRIBED then break end

		local dat = amidi_in[8]
		if evtype == alsa.SND_SEQ_EVENT_CONTROLLER then
			love_midievent(keys2.midi, "control change", dat[1],dat[5],dat[6])
		elseif evtype == alsa.SND_SEQ_EVENT_NOTEON then
			love_midievent(keys2.midi, "note on", dat[1],dat[2],dat[3],dat[5])
		elseif evtype == alsa.SND_SEQ_EVENT_NOTEOFF then
			love_midievent(keys2.midi, "note off", dat[1],dat[2],dat[3],dat[5])
		elseif evtype == alsa.SND_SEQ_EVENT_PGMCHANGE then
			love_midievent(keys2.midi, "program change", dat[1], 0, dat[6])
		else
			for k, v in next, alsa do
				if evtype == v then
					print("evtype", #dat, k)
					for i = 1, #dat do
						print("", i, dat[i])
					end
					break
				end
			end
		end
	end
end
else
	midi_receive = function() end
	print("MIDI system not supported.")
end

--}}}
function keys2.doevents()
	midi_receive()
end

return keys2
