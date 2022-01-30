local setmetatable = setmetatable
local sfmt = string.format
local floor = math.floor
local table = table

local f = {}

local m = {}

local getTime = love.timer.getTime

local Hertz
local delta_time

function m:start()
	--self.count = 0
	self[0] = getTime()
	return true
end

function m:reset()
	self.count = -1
	return true
end

function m:time()
	return getTime() - self[0]
end

function m:lap()
	local c = self.count + 1
	self.count = c
	self[c] = getTime() - self[0]
	return self[c]
end

function m:print(file)
	file = file or io.output()
	local start = self[0]
	local sum = 0
	local t = {}
	local ti = table.insert
	local c = self.count
	ti(t, sfmt("Lap Data for \"%s\" (%d laps)", self.name, c))
	for i = 1, c do
		local lap = self[i]
		--ti(t, sfmt("    Lap %d : %7.4fs", i, lap))
		sum = sum + lap
	end
	local microsec = floor(sum * 1000000)
	local microX = floor((delta_time) * 1000000)
	--ti(t, sfmt("  Total    : %5d    µs", microsec))
	--ti(t, sfmt("  Laps     : %5d    laps", c))
	local average = microsec / (c < 1 and 1 or c)
	self.average = average
	self.avgXHz = average / microX * 100
	--ti(t, sfmt("  Average  : %8.2f µs/lap", average))
	--ti(t, sfmt("           : %.4f%% lap/60Hz", self.avg60Hz))

	--local data = table.concat(t, "\n")
	local data = sfmt("Lap Data %-20s|%7.2f%% of %dHz %8.2f µs/lap %7d laps ",
		self.name, self.avgXHz, Hertz, average, c < 0 and 0 or c
	)

	file:write(data.."\n")
	return data
end

function m:dump(file)
	self:print(file)
	self:reset()
end

function f:new(name)
	local t = {
		name = name,
		count = -1,
		[0] = getTime(),
		type = "Profile",
	}

	return setmetatable(t, {__index = m})
end

local Profile = setmetatable(f, {__call = f.new})

local testing = Profile("testing")
--print("testing:start", testing)
--testing:start()
--testing:lap()
--testing:dump()


-- UP NEXT : PROFILE MANAGER

local pmm = {}
local pmf = {}

local reserved = {
	"main",
	"update",
	"render",
	"sleep",
}
for i = 1, #reserved do
	reserved[reserved[i]] = true
end


--{{{ [[ PROFILE TABLE ]] (m table)
function pmm.new (self, name, desc)
	if not self[name] then
		--printf("Adding %s\n", name)
		local p = Profile(desc)

		local adding = p
		if reserved[name] then
			local group = { p, count = 1}
			adding = group
		end

		self[name] = adding
		return adding
	end
	return nil, "name already exists"
end

local function set_func (self, name, desc)
	local p
	local tname = type(name)

	if tname == "table" then
		p = name
	elseif tname == "string" then
		local parent = self._parent or self
		p = parent[name]
		if not p then
			p = assert(self:new(name, desc))
		end
		if not(type(p) == "table" and p.type == "Profile") then
			error("invalid Profile: ".. name)
		end
	end
	--printf("added %s: %s — %s\n", p.type, name, desc)
	self.assembled = false

	local c = self.count + 1
	self.count = c

	self[c] = p
end

local function set_index(self, k)
	local parent = rawget(self, "_parent")
	local g = parent[k]
	if g then
		g._parent = parent
		return function (name, desc)
			set_func(g, name, desc)
		end
	end
end

local function set_newindex(self, k, v)
	if k ~= "_parent" then
		error("Cannot set table")
	elseif rawget(self, k) then
		error("Cannot set parent, already set")
	end
	rawset(self, k, v)
end

function pmm.remove (self, name)
	local p
	local tn = type(name)
	if tn == "string" then
		p = self[name]
	elseif tn == "table" then
		p = name
	end
	local c = self.count
	if p then
		local rm_i
		for i = 1, c do
			if self[i] == p then
				rm_i = i
				break
			end
		end
		if rm_i then
			for i = rm_i, c-1 do
				self[i] = self[i+1]
			end
			self.count = c - 1
		end
	end
end

function pmm.dump_all (self, dt)
	self.timer = self.timer - dt
	if self.timer <= 0 then
		self.timer = self.timer_default
	else
		return
	end

	if not self.assembed then
		local c = 0
		for i = 1, #reserved do
			local gname = reserved[i]
			local grp = self[gname]
			if grp then
				local len = #grp
				--print("Group", gname, "len", len)
				for k = 1, len do
					--print("  gk", grp[k], "type", grp[k].type)
					self[c + k] = grp[k]
				end
				c = c + len
			end
		end
		self.count = c
		self.assembed = true
	end

	Hertz = self.Hertz[dt]
	if not Hertz then
		Hertz = floor(1.0 / dt + 0.5)
		self.Hertz[dt] = Hertz
	end
	delta_time = dt

	printf("      PROFILE LAP DATA @ %.1f s MET\n", hal.met)
	for i = 1, self.count do
		self[i]:dump()
	end
end
--}}}

function pmf.new(self)
	local t = {
		timer = 0,
		timer = 0,
		timer_default = 5,

		count = 0,
		assembled = false,

		Hertz = {},
	}
	t.set = setmetatable({_parent = t}, {
		__call = set_func,
		__index = set_index,
		__newindex = set_newindex,
	})

	return setmetatable(t, {__call = pmm.new, __index = pmm })
end

return pmf.new()
