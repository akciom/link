-- Copywrite 2020 -- Scott Smith --

local export = export
export. hal = {conf = hal_conf}
hal.debug = {}
export. keys2 = require "keys2"
--{{{populate hal_conf.AG
do
	local game_config = "game.cfg"
	local data = require"utils.io".open("./"..game_config, "r")
	if data then
		local idat = require"ini".parse(data:read("*a"), game_config)
		data:close()
		hal_conf.AG = idat[""]
	else
		error("missing "..game_config)
	end
end
--}}}populate hal_conf.AG
local UPDATES_PER_SECOND = 60--24 --20.0
do
	local fps = hal_conf.AG.FPS
	if type(fps) == "number" and fps ~= 0 then
		if fps < 10 then
			fps = 10
		elseif fps > 60 then
			fps = 60
		end
		UPDATES_PER_SECOND = fps
	end
end
local UPDATE_DT = 1/UPDATES_PER_SECOND
local TARGET_DT = 60 --target minimum 60fps
local invTARGET_DT = 1/TARGET_DT
local FRAME_LIMIT = UPDATES_PER_SECOND + 0.5
local invFRAME_LIMIT = FRAME_LIMIT == 0 and 0 or 1/FRAME_LIMIT

--The Main Loop functions

--the number is abitrary and only has meaning in the context of this program
--that meaning I am unsure of though
local GC_STEP_SIZE = 1
local GC_UPDATES_PER_SECOND = 20


--{{{ [[ local variable assignment ]]
local keys2 = keys2
local keys = keys2.keys
local midi = keys2.midi

local inputSystem = require "sysinput"

local ffi = require "ffi"
local ini = require "ini"
local string, error, loadfile, math, love
    = string, error, loadfile, math, love
local strfmt, unpack = string.format, unpack

local floor, ceil, min = math.floor, math.ceil, math.min
local atan2, cos, sin = math.atan2, math.cos, math.sin
local abs, sqrt = math.abs, math.sqrt
local average = require"utils.math.stats".average
local stddev = require"utils.math.stats".stddev
local round = require"utils.math.round"

local lg = love.graphics


--The following shouldn't need to change very often.
--all code should be put in functions above.

--Escape key will reload game when pressed. Long press quits game.
--this function should always be able to be called.
local levent, leventpump, leventpoll, love_handlers
    = love.event, love.event.pump, love.event.poll, love.handlers
local ltimer, ltimerstep, ltimergetdelta, ltimersleep
    = love.timer, love.timer.step, love.timer.getDelta, love.timer.sleep
local lwindowisopen, lwindowgetWidth, lw =
	  love.window.isOpen, love.window.getWidth, love.window
local lgprint = lg.print

--}}}

--{{{ DEBUG font
local debug_font
local function debug_font_setup()
	debug_font = lg.newImageFont("assets/akciom-4x9.png",
	" !\"#$%&'()*+,-./0123456789:;<=>?"..
	"@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_"..
	"`abcdefghijklmnopqrstuvwxyz{|}~",
	1)
end
--}}} DEBUG font

local escapekey do --{{{ --[[ Escape Key ]]
	local quit_timer = 0
	local function esc_quit() --{{{
		lg.reset()
		lg.clear() --Good bye
		lgprint("Good bye!", 10, 10)
		lg.present()
		ltimersleep(0.5)
		love.event.quit()
	end--}}}
	local function esc_reload()--{{{
		love.event.push("reload")
	end--}}}
	local function esc_refresh()--{{{
		love.event.push("refresh")
	end--}}}
	local function esc_noop() end

	local on_hold = esc_refresh
	local on_release = esc_noop

	function escapekey(dt)
		if midi(0xb02a) > 0.5 then --stop
			midi.saved._hashalted = true
			error("HALT_THE_GAME_PLEASE")
		end
		if keys.escape then
			quit_timer = quit_timer + dt
			if quit_timer > 0.3228 then
				on_hold()
			end
		end
		local rewind = midi(0xb02b) > 0.5 --pressed or released
		if not midi.saved._hasreset and rewind then
			midi.saved._hasreset = true
			love.event.push("reload")
		elseif not rewind then
			midi.saved._hasreset = false
		end
		local kr = keys2.released
		for i = 1, kr.count do
			if kr[i] == "escape" then
				quit_timer = 0
				on_release()
			end
		end
	end
end --}}}

function love.focus(f)
	lw.setDisplaySleepEnabled(true)
end

local DEBUG_DISPLAY_MIDI_TOGGLE = false


local profile = require "debug.Profile"
--{{{ PROFILE SETUP
do
local p = profile
p(             "main",         "Main Loop")
p.set.main(  p("start",        " Event Loop"))
p.set.main(  p("start_process","  Event Process"))

p.set.main(  p("accumulator",  " Accumulator Loop"))
p.set.main(p  ("garbage",      "  GC"))

p(             "update",       "  Update Game")
p.set.update(p("inputsys",     "   Input System"))

p(             "render",       " Render Loop")
p.set.render(p("render2",      "  Debug Output"))
p.set.render(p("render3",      "  Present!"))
p.set.render(p("render1",      "  Render Game"))
p(             "sleep",        "Sleeping")
end
--}}} PROFILE SETUP

local function main(arg)
	--{{{ --[[ Pre-Initalization ]]--
	if not love.math then error("Need some love.math") end
	if not love.event then error("Need some love.event") end
	if not love.timer then error("Need some love.timer") end

	--reset events
	keys2:reset()
	love.event.clear()

	local hal = hal
	hal.met = 0
	hal.frame = 0

	--Set Seed
	love.math.setRandomSeed(os.time())
	--add some set randomness
	do
		local lmr = love.math.random
		local count = 0
		local randval
		for i = 1, 10 do
			count = count + 1
			randval = lmr(40)
			if randval == count + 15 then
				break
			end
		end
		for i = 1, randval + count do
			lmr()
		end

	end
	--end:Set Seed

	local pause_game = false
	--Counting Frames and Timers
	local frames = ffi.new("uint16_t [?]", UPDATES_PER_SECOND+1)
	local frametime = 0.0 --total time simulation has been running
	local fps_update = 1
	local fps = 0
	local fps_min = math.huge
	local fps_max = 0
	local fps_reset_clock = hal.met + 1 + UPDATE_DT
	local accumulator = 0.0
	local frame_table = {
		count = 0,
		max = UPDATES_PER_SECOND * 5,
		pointer = 0,
	}
	local frame_average = 0.0
	local frame_average_percentage = 0.0
	local frame_std_dev_table = {}
	local frame_std_dev = false
	local frame_spikes = {
		count = 0,
		strings = {max = 10},
		average = 0/0, stddev = 0
	}
	local frame_limit_percentage = 0
	local frame_limit_time = 0
	local frame_limit_percentage_max = 0
	local frame_limit_time_max = 0
	local target_frame_percentage = 0
	local target_frame_percentage_max = 0
	local garbage_time = {
		count = 0,
		pointer = 0,
		count_max = 9999,
		min = math.huge,
		max = 0,
		average = 0,
		stddev = 0,

		run_gc = 0,
		run_gc_default = ceil(UPDATES_PER_SECOND / GC_UPDATES_PER_SECOND),

		steps_between = 0,
		steps_between_complete = -1,
	}
	local allocated_memory = 0
	local allocated_memory_max = 0
	local allocated_memory_frames = {update = 1}
	--end:Counting Frames and Timers
	--}}}
	--TODO:These commands are ripe for abuse when inputs are user defined
local update, render do --{{{ [ Setup include() and initialize ]

	local entryfile = hal.conf.AG.PACK

	local suffix = ".agpack"
	local entryfile_match_string = "^([%w_%-]+)$"

	do
		local errentryfile = entryfile
		entryfile = string.match(entryfile, entryfile_match_string)
		if not entryfile then
			error("entryfile is invalid, %s", errentryfile)
		end
	end

	export .include = function(incfile)
		local errincfile = incfile
		incfile = string.match(incfile, entryfile_match_string)
		if not incfile then
			error(strfmt("include: invalid file name, %s", errincfile))
		end
		local fullincfile = strfmt("./%s%s/src/%s.lua",
			entryfile, suffix, incfile
		)
		local incfunc = assert(loadfile(fullincfile))

		--like require, include only returns one thing
		return incfunc(incfile), nil
	end
	--same as dofile(filename)() but adding entryfile as first argument
	local loadfilename = strfmt("./%s%s/main.lua", entryfile, suffix)
	local entry = assert(loadfile(loadfilename))
	do --load keybindings
		local kbfn = strfmt("./%s%s/keybind.cfg", entryfile, suffix)
		local f = io.open(kbfn)
		if f then
			hal.input_load_bindings(assert(ini.parse(f:read("*a"))))
			f:close()
		end
	end

	local initialize
	initialize, update, render = entry(entryfile)()
	if      type(initialize) ~= "function"
		and type(update) ~= "function"
		and type(render) ~= "function"
	then
		error("invalid entry file")
	end

	initialize(arg)
end--}}}

	--{{{ Process delay based on window focus
	local process_delay = 0
	local process_delay_default = floor(UPDATES_PER_SECOND / 3)
	local process_delay_mouse = 0
	local process_delay_mouse_default = floor(UPDATES_PER_SECOND / 20)
	local lwHasFocus = love.window.hasFocus
	local lwHasMouseFocus = love.window.hasMouseFocus
	--}}} Process delay based on window focus

	--log.hal"HAL! "
	--printf "        |"
	--for k,v in next, hal do
	--	printf("%s|", k)
	--end
	--printf "\n"

	-- We don't want the first frame's dt to include time taken to initialize.
	ltimerstep()
	local gettime = ltimer.getTime
	while true do
		profile.main[1]:start()
		profile.start:start()
		local this_frame_time = gettime()
		local updated = false

		--{{{ [[ Process events ]]
		local process = false
		if lwHasFocus() then
			process = true
		elseif lwHasMouseFocus() then
			process_delay_mouse = process_delay_mouse - 1
			if process_delay_mouse <= 0 then
				process = true
				process_delay_mouse = process_delay_mouse_default
			end
		else
			process_delay = process_delay - 1
			if process_delay <= 0 then
				process = true
				process_delay = process_delay_default
			end
		end


		if process then
			profile.start_process:start()
			keys2.doevents()
			leventpump()
			--do e,a,b,c,d = love.event.wait()
			for e,a,b,c,d in leventpoll() do
				love_handlers[e](a,b,c,d)
			end
			profile.start_process:lap()
		end
		--}}}end:process events

		-- Update dt, as we'll be passing it to update
		ltimerstep()
		frametime = ltimergetdelta()
		accumulator = accumulator + frametime
		profile.start:lap()
		while accumulator >= UPDATE_DT do
			profile.accumulator:start()
			profile.update[1]:start()
			hal.input.processed = process
			if process then
				 --TODO:escapekey shouldn't be available in release
				profile.inputsys:start()
				escapekey(UPDATE_DT)
				inputSystem(UPDATE_DT)
				profile.inputsys:lap()
			end
			--pause
			local midiplaypause = midi(0xb029) > 0.5
			if not midi.saved._haspaused and midiplaypause then
				pause_game = not pause_game and accumulator
				midi.saved._haspaused = true
			elseif not midiplaypause then
				midi.saved._haspaused = false
			end
			if not pause_game then
				update(UPDATE_DT)

				hal.met = hal.met + UPDATE_DT
				fps_update = fps_update + 1
				if fps_update > UPDATES_PER_SECOND then
					fps_update = 1
				end
				-- frame update reported to use a 0 based
				hal.frame = fps_update - 1
			end

			if hal.input.debug_menu == "pressed" or
				(midi(0xb02e) == 1 and not DEBUG_DISPLAY_MIDI_TOGGLE)
			then
				DEBUG_DISPLAY_MIDI_TOGGLE = true
				hal.debug_display_power = true
				hal.debug_display = not hal.debug_display
			end
			if DEBUG_DISPLAY_MIDI_TOGGLE then
				DEBUG_DISPLAY_MIDI_TOGGLE = midi(0xb02e) == 1
			end


			keys2:reset()

			if accumulator > 5.0 then
				hal.accumulator_reset = accumulator
				accumulator = UPDATE_DT
			end
			accumulator = accumulator - UPDATE_DT

--{{{ [[   DEBUG Update/FPS   ]]--
if hal.debug_display then
	updated = true --used for debug rendering

	fps = 0
	for i = 1, UPDATES_PER_SECOND do
		fps = fps + frames[i]
	end
	frames[fps_update] = 0

	if fps_reset_clock then
		if hal.met >= fps_reset_clock then
			fps_reset_clock = false
			fps_min = fps
			fps_max = fps
		else
			fps, fps_min, fps_max = 0, 0, 0
		end
	end
	if fps < fps_min then fps_min = fps end
	if fps > fps_max then fps_max = fps end

	--get smooth avg of allocated memory (reported by collectgarbage("count"))
	local amfu = allocated_memory_frames.update + 1
	if amfu > UPDATES_PER_SECOND then
		amfu = 1
	end
	allocated_memory_frames.update = amfu
	allocated_memory_frames[amfu] = collectgarbage("count")
	allocated_memory = 0
	for i = 1, UPDATES_PER_SECOND do
		allocated_memory = allocated_memory + (allocated_memory_frames[i] or 0)
	end
	allocated_memory = allocated_memory * (UPDATE_DT)
end --}}} end:DEBUG Update/FPS

			profile.update[1]:lap()
			garbage_time.run_gc = garbage_time.run_gc - 1
			if garbage_time.run_gc <= 0 then
				garbage_time.run_gc = garbage_time.run_gc_default
				profile.garbage:start()
				--seems like a good place to run a gc step
				local gc_start = gettime()
				garbage_time.steps_between =
					garbage_time.steps_between + 1
				if collectgarbage("step", GC_STEP_SIZE) then
					--print("GC Steps", garbage_time.steps_between_complete)
					garbage_time.steps_between_complete =
						garbage_time.steps_between
					garbage_time.steps_between = 0
				end
				collectgarbage("stop")
				local p = garbage_time.pointer + 1
				local c = garbage_time.count
				if p > garbage_time.count_max then
					p = 1
				end
				if c < p then garbage_time.count = p end
				garbage_time.pointer = p
				local gc_end = gettime() - gc_start
				garbage_time[p] = gc_end
				if gc_end > garbage_time.max then
					garbage_time.max = gc_end
				end
				if gc_end < garbage_time.min then
					garbage_time.min = gc_end
				end
				profile.garbage:lap()
			end

			profile.accumulator:lap()
		end

		profile.render[1]:start()
		if lwindowisopen() then
			profile.render1:start()
			--lg.clear(lg.getBackgroundColor())
			lg.origin()

			local alpha = accumulator * UPDATES_PER_SECOND
			if pause_game then
				alpha = pause_game * UPDATES_PER_SECOND
			end
			local present = render(alpha)
			profile.render1:lap()

--{{{ [[  DEBUG Rendering  ]]--
if hal.debug_display then
	profile.render2:start()
	present = true
	local poweredon = hal.debug_display_power
	local met = hal.met
	local wmod = 140

	--reset fps counters, data is probably old/useless and needs to be reset
	if poweredon then
		fps_reset_clock = met + 1 + UPDATE_DT
		frame_limit_time_max = 0
		frame_limit_percentage_max = 0
		frame_table.count = 0
		frame_table.pointer = 0
		frame_spikes.count = 0
		for i = 1, #frame_spikes.strings do
			frame_spikes.strings[i] = nil
		end
		if not debug_font then debug_font_setup() end
	end
	local old_font = lg.getFont()
	lg.setFont(debug_font)

	if updated then
		if allocated_memory > allocated_memory_max then
			allocated_memory_max = allocated_memory
		end
		local flt = gettime() - this_frame_time
		do
			local p = frame_table.pointer + 1
			local c = frame_table.count
			local calc_std_dev = false
			if not frame_std_dev and p > UPDATES_PER_SECOND then
				calc_std_dev = true
			end
			if p > frame_table.max then
				calc_std_dev = true
				frame_table.count = frame_table.max
				p = 1
			end
			if c < p then c, frame_table.count = p, p end
			frame_table.pointer = p
			frame_table[p] = flt
			local avg = average(frame_table)
			frame_average = avg * 1000
			frame_average_percentage = avg * TARGET_DT * 100
			local std_dev_multi = 5
			garbage_time.average = average(garbage_time)
			if calc_std_dev then
				garbage_time.stddev = stddev(garbage_time, garbage_time.average)
				local std_dev = stddev(frame_table, avg)
				local avg_dev_high = avg + std_dev * std_dev_multi
				if not frame_std_dev then
					frame_std_dev = std_dev * 1000
				end
				frame_std_dev = (std_dev * 1000 * 0.8) + (frame_std_dev * 0.2)
				frame_spikes.average = average(frame_spikes)
				frame_spikes.stddev = stddev(frame_spikes, frame_spikes.average)
			elseif frame_std_dev then
				local flt1000 = flt * 1000
				local high = frame_average + frame_std_dev * std_dev_multi
				if flt1000 > high then
					local si = frame_spikes.count + 1
					frame_spikes[si] = flt1000
					frame_spikes.count = si
					local spike_format_str = "%7.2fs|%03d:%5.2fms,%5.2fms"
					table.insert(frame_spikes.strings, strfmt(spike_format_str,
						hal.met, si, flt1000,
						garbage_time[garbage_time.count] * 1000
					))
				end
				frame_spikes.average = average(frame_spikes)
			end
			for i = frame_spikes.strings.max+1, #frame_spikes.strings do
				table.remove(frame_spikes.strings, 1)
			end
		end
		if flt > frame_limit_time_max then
			frame_limit_time_max = flt
			frame_limit_percentage_max = flt * FRAME_LIMIT * 100
			target_frame_percentage_max = flt * TARGET_DT * 100
		end
		frame_limit_time = (frame_limit_time * 0.2) + (flt * 0.8)
		frame_limit_percentage = frame_limit_percentage *0.2 +
			(flt * FRAME_LIMIT * 100) *0.8
		target_frame_percentage = target_frame_percentage * 0.2 +
			(flt * TARGET_DT * 100) * 0.8
	end
	local y_position = 0
	local function y_pos(multi)
		local y = y_position
		y_position = y + round((multi or 1) * 9)
		return y
	end
	local w, h = lg.getDimensions()
	local save_r,save_b,save_g,save_a = lg.getColor()
	lg.setColor(0.0627, 0.0392, 0.0627, 0.77)
	lg.rectangle("fill", w-wmod-4, 0,wmod+4,  h)
	lg.setColor(0.9882,0.8706,0.9882)
	lgprint(strfmt("%4s (%3s,%3s) %7.2fs",
		fps, floor(fps_min), floor(fps_max), met), w-wmod, y_pos())
	do --{{{ print average and std dev
		local avg_std_dev_str = "%5.2fms avg,%4.2fms std dev"
		local count_or_std_dev
		if frame_std_dev then
			count_or_std_dev = frame_std_dev
		else
			avg_std_dev_str = "%5.2fms avg,%3d frames remain"
			count_or_std_dev = UPDATES_PER_SECOND - frame_table.count
		end
		lgprint(strfmt(avg_std_dev_str, frame_average, count_or_std_dev),
			w-wmod, y_pos())
		lgprint(strfmt("      %5.1f%%of%4.1fms Avg",
			frame_average_percentage, invTARGET_DT*1000),
			w-wmod, y_pos())
		y_pos(0.2)
	end--}}}
	lgprint(strfmt("%3d GC Steps till complete",
		garbage_time.steps_between_complete),
		w-wmod, y_pos())
	lgprint(strfmt("%5.2fms avg,%4.2fms SD GC%4d",
		garbage_time.average * 1000,
		garbage_time.stddev * 1000, garbage_time.count),
		w-wmod, y_pos())
	lgprint(strfmt("%5.2fms MAX,%4.2fms MIN GC",
		garbage_time.max * 1000, garbage_time.min * 1000),
		w-wmod, y_pos())
	y_pos(.2)
	lgprint(strfmt("%5.2fms on,%5.2fms off",
		frame_limit_time * 1000,
		(invFRAME_LIMIT - (gettime() - this_frame_time)) * 1000),
		w-wmod, y_pos())
	lgprint(strfmt("%5.2fms on,%5.2fms off MAX",
		frame_limit_time_max * 1000,
		(invFRAME_LIMIT - (frame_limit_time_max)) * 1000),
		w-wmod, y_pos())
	lgprint(strfmt("      %5.1f%%of%4.1fms",
		target_frame_percentage, invTARGET_DT*1000),
		w-wmod, y_pos())
	lgprint(strfmt("      %5.1f%%of%4.1fms MAX",
		target_frame_percentage_max, invTARGET_DT*1000),
		w-wmod, y_pos())
	if FRAME_LIMIT ~= TARGET_DT then
		lgprint(strfmt("      %5.1f%%of%4.1fms",
			frame_limit_percentage, invFRAME_LIMIT*1000),
			w-wmod, y_pos())
		lgprint(strfmt("      %5.1f%%of%4.1fms MAX",
			frame_limit_percentage_max, invFRAME_LIMIT*1000),
			w-wmod, y_pos())
	end
	lgprint(strfmt("Mem:%10.2fKB%10.2fKB",
		allocated_memory, allocated_memory_max),
		w-wmod, y_pos())
	y_pos(.5)

	if frame_spikes.count > 0 then
		lgprint("____________________________", w-wmod, y_position+2)
		lgprint(strfmt("Spikes:  %3d  Frame     GC", frame_spikes.count),
			w-wmod, y_pos(1.1))
		for i = 1, #frame_spikes.strings do
			lgprint(frame_spikes.strings[i],
				w-wmod, y_pos())
		end
		y_pos(0.2)
		lgprint("____________________________", w-wmod, y_position+2)
		lgprint(strfmt(" %5.2fms avg,%5.2fms stddev",
			frame_spikes.average, frame_spikes.stddev),
			w-wmod, y_pos()
		)
	end

	if hal_conf.midi and love.system.getOS() == "Linux" then
		if poweredon then
			--midi isn't tracked when debug display is off
			--this basically resets it
			hal.debug.midi_key = 0
			hal.debug.midi_val = 0
		end
		local m = keys2.midi
		local i = m.count - 1
		if i >= 1 then
			hal.debug.midi_key = m[i]
			hal.debug.midi_val = m[i+1]
		end
		local key = hal.debug.midi_key or 0
		local val = (hal.debug.midi_val or 0) * midi.inv127
		local rtv = hal.debug.midi_retval[key] or 0

		local str
		if key == 0 then
			str = "Midi   --no recent input--"
		else
			str = strfmt("Midi 0x%04x %5.3f; %9.2f", key, val, rtv)
		end
		y_pos()
		lgprint(str, w-wmod, y_pos())
		lgprint(pause_game and "  -- Paused --" or "", w-wmod, y_pos())
	end
	hal.debug_display_power = false --done powering on
	lg.setColor(save_r,save_g,save_b,save_a)
	lg.setFont(old_font)
	profile.render2:lap()
end
--}}}end:DEBUG Rendering

			if present then
				profile.render3:start()
				lg.present()
				profile.render3:lap()
			end
			frames[fps_update] = frames[fps_update] + 1
		end
		profile.render[1]:lap()

		profile.main[1]:lap()

		profile.sleep[1]:start()
		ltimersleep(invFRAME_LIMIT - (gettime() - this_frame_time))
		profile.sleep[1]:lap()
	end
end

return main
