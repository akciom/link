-- Directory Parser — Copyright 2021 Scott Smith --

local setmetatable = setmetatable
local sfmt = string.format
local sfind = string.find
local tins = table.insert
local tcat = table.concat

local m = {}

local function tree_to_path(tree, limit)
	local path
	local idx = 1
	if tree.absolute and tree.volume then
		idx = 0
	end
	limit = limit or #tree
	if limit < 0 then
		print("LIMIT!", limit)
		limit = #tree + limit
	end
	return tcat(tree, tree.separator, idx, limit)
end

--system() runs over a files table updating the trees.
function m.update(files)
	--TODO:test on Linux, for now, I can only assume it'll work
	for i = 1, #files, 2 do
		local name = files[i]
		local path = files[i+1]
		files[i] = nil
		files[i+1] = nil
		local tree = setmetatable({}, {__tostring = tree_to_path})
		tree.topath = tree_to_path

		local save_e = 0

		local path_sep
		local find_path_sep
		local s, e, volume
		do
			if sfind(path, "/") then
				path_sep = "/"
			elseif sfind(path, "\\") then
				path_sep = "\\"
			else
				--just a single file (same directory as base file)
				tree.volume = false
				tree.relative = true
				tree[1] = path
				goto nopath
			end
		end
		find_path_sep = "^"..path_sep
		tree.separator = path_sep

		s, e, volume = sfind(path, "^(%a):")
		if volume then
			save_e = e
		elseif path_sep == "\\" and sfind(path, "^\\\\") then
			volume = "\\"
			e = 1
			save_e = e
		else
			volume = false
			e = save_e
		end
		s, e = sfind(path, find_path_sep, e+1)
		if s then
			tree.absolute = true
			if volume then
				local v = volume
				if v ~= "\\" then
					v = v..":"
				end
				tree[0] = v
			end
		else
			tree.relative = true
			e = save_e
			volume = false
		end
		tree.volume = volume
		do
			local find_w_sep = "^([^"..path_sep.."]+)"
			while e and e <= #path do
				local dir
				s, e, dir = sfind(path, find_w_sep, e + 1)
				if dir then
					tins(tree, dir)
					s, e = sfind(path, path_sep, e + 1)
				end
			end
		end
		::nopath::
		--print(sfmt("%20s(%s), %s:> %s", name, tree.absolute and "ABS" or "REL",
		--	tree.volume or " ",
		--	table.concat(tree, " > ")
		--))

		tins(files.names, name)
		files.paths[name] = path
		files.trees[name] = tree

	end
	return files
end

local function get_relative(self, p1n, p2n)
	local p1 = self.trees[p1n] or self:enqueue(p1n)
	local p2 = self.trees[p2n] or self:enqueue(p2n)
	if #self > 0 then
		self:update()
		p1 = self.trees[p1n]
		p2 = self.trees[p2n]
	end

	if not p1.absolute then
		return false, "Path of argument 1 must be absolute"
	end
	local reltree
	if p2.absolute and p1.volume == p2.volume then
		local min = #p1 < #p2 and #p1 or #p2
		local base_i = min
		for i = 1, min do
			if p1[i] ~= p2[i] then
				base_i = i
				break
			end
		end

		local parent_dirs = #p1 - base_i

		--print(sfmt("%2d %17s  %s:> %s", #p1 - base_i, "p1", p1.volume, table.concat(p1, " > ", base_i)))
		--print(sfmt("%2d %17s  %s:> %s", #p2 - base_i, "p2", p2.volume, table.concat(p2, " > ", base_i)))

		reltree = setmetatable({}, {__tostring = tree_to_path})
		reltree.topath = tree_to_path
		--relative directories must be on same volume
		reltree.volume = false
		reltree.relative = true
		reltree.separator = p1.separator
		for i = 1, #p1 - base_i do
			tins(reltree, "..")
		end
		for i = base_i, #p2 do
			tins(reltree, p2[i])
		end
	else
		reltree = p2
	end
	return reltree
end

local function to_absolute(self, p1n, p2n)
	local p1 = self.trees[p1n] or self:enqueue(p1n)
	local p2 = self.trees[p2n] or self:enqueue(p2n)
	if #self > 0 then
		self:update()
		p1 = self.trees[p1n]
		p2 = self.trees[p2n]
	end
	if p2.absolute then
		return p2
	elseif not p1.absolute then
		return false, "Path of argument 1 must be absolute"
	end
	local abstree = setmetatable({}, {__tostring = tree_to_path})
	abstree.topath = tree_to_path
	do
		local volume = p1.volume
		if volume then
			abstree.volume = volume
			abstree[0] = p1[0]
		end
	end
	abstree.absolute = true
	abstree.separator = p1.separator

	local c = 0
	for i = 1, #p1 - 1 do --drop last part of path (assuming it's a file)
		c = c + 1
		abstree[c] = p1[i]
	end

	for i = 1, #p2 do
		if p2[i] == ".." then
			c = c - 1
		else
			c = c + 1
			abstree[c] = p2[i]
		end
	end
	for i = c+1, #abstree do
		abstree[i] = nil
	end
	return abstree
end

--enqueue(name, path)
--enqueue(path)
function m:enqueue(name, path)
	path = path or name

	tins(self, name)
	tins(self, path)
end

function m:add(name, tree)
	self.trees[name] = tree
end

local function new(_)
	local files = {}
	files.names = {}
	files.paths = {}
	files.trees = {}

	files.get_relative = get_relative
	files.to_absolute = to_absolute

	return setmetatable(files, {__index = m})
end

return setmetatable({}, {__call = new})
