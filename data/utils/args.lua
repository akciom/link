--[[

Argument types
short options: -s, -d, -r
long options: --long-arg, --initialize, --render

long options can also be noted by a single dash:
   -long-arg, -initialize, -render

if that's the case, short options cannot be chained: -sdr
    short arguments will always need to be separated by a space

another way to look at it, a dash denotes a switch
    -long-arg, -initialize, -render, -s, -d, -r

arguments without a preceeding hyphen '-' are option dependent arguments:
-render list all ("list" and "all" being arguments to the option "render")

similar for double-hypen options
--render list all ("list" and "all" being arguments to the option "render")

with long arguments using double-hypen "--":
chained short options can have arguments, but only for the last in a chain

to signal the end of option parsing (and use it as an argument for the 
command itself) use double-hyphen "--"

--]]

local type, error = type, error

local function parse_args(args)
	if type(args) ~= "table" then
		error("invalid argument, must pass argument table")
	end
	error("not implimented")
end

return parse_args
