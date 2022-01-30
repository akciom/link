DEBUG = true
local loveversion = "11.3"
local sfmt = string.format

local version, gamename, savedir do
	gamename = "LINK!"
	savedir  = "LINK"
	local tagline = "Larry's Ingenious Note Keeper"
	local engine = "Emk2.3" --version.gamenum
	local preextra = "- INDEV - "
	local gamever  = "0.8"
	local extra    = " Alpha (Open Source Edition)"

do--{{{, Print fullname to console
	local fullname = sfmt(
		"%s\n%s\n(%s_%s %sversion %s)%s\n",
		gamename, tagline, engine, loveversion, preextra, gamever, extra
	)
	local line = 1
	local s, e, match = 0, 0
	local fullnamelen = #fullname
	repeat
		s, e, match = fullname:find("[^\n]+\n", e+1)
		if not e then break end
		local matchlen = e-s-1 --remove trailing newline

		local termwidth = 78
		local len = math.floor(tonumber((termwidth - matchlen) *.5))
		if len < 0 then len = 0 end
		local pre, post, sep = "", "", "  "
		if line == 1 then
			pre, post, sep = "==[[",   "]]==", "_"
		elseif line == 2 then
			pre, post, sep = "  \\__", "__/  ", "" 
		elseif line == 3 then
			pre, post, sep = "     ", "    ", " "
		end
		if #sep < 1 then sep = " "
		elseif #sep > 1 then sep = sep:sub(1, 1) end

		local termwidth = termwidth-#pre-#post
		local lwdiff = termwidth-matchlen
		if lwdiff > 0 then
			lwdiff = 0
		end
		match = fullname:sub(s, e-1+lwdiff)
		if sep ~= " " then
			match = match:gsub(" ", sep)
		end
		io.write(sfmt(" %s%s%s%s%s\n",
			pre, sep:rep(len-#pre), match, sep:rep(len-#post-1), post))
		line = line + 1
	until #fullname == e + 1
	io.write("\n")
end--}}}

	version = sfmt("%s  %s%s%s", gamename, preextra, gamever, extra)
end

hal_conf = {
	midi = false,
	websocket_enabled = false,
	version = version,
	savedir = savedir,
	reload_main2_on_restart = true,
	AG = {},
}

function love.conf(t)
	t.identity = "Akciom"
	--t.appendidentity = false  --search files in source dir before save dir
    t.version = loveversion
    --t.console = false
	--t.accelerometerjoystick = true
	--t.externalstorage = false
	--t.gammacorrect = false
	
	--t.audio.mic = false
	--t.audio.mixwithsystem = true

	t.window = false --[[
    t.window.title = version
    --t.window.icon = nil
    t.window.width = 854
    t.window.height = 480
    --t.window.borderless = false
    t.window.resizable = true
    --t.window.minwidth = 1
    --t.window.minheight = 1
    --t.window.fullscreen = false
    --t.window.fullscreentype = "desktop" --"desktop" or "exclusive"
    t.window.vsync = 0
    --t.window.msaa = 0
	--t.window.depth = nil
	--t.window.stencil = nil
    t.window.display = 2
	--t.window.highdpi = false
	--t.window.usedpiscale = true
	--t.window.x = nil
	--t.window.y = nil
	--]]

    --t.modules.audio = true
	--t.modules.data = true
    --t.modules.event = true
	--t.modules.font = true
    --t.modules.graphics = true
    --t.modules.image = true
    --t.modules.joystick = true
    --t.modules.keyboard = true
    --t.modules.math = true
    --t.modules.mouse = true
    t.modules.physics = false
    --t.modules.sound = true
    --t.modules.system = true
	--t.modules.thread = true
    --t.modules.timer = true
	--t.modules.touch = true
	--t.modules.video = true
    --t.modules.window = true
end
