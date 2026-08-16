-- Copyright 2026 jojotastic777
--
-- Permission is hereby granted, free of charge, to any person
-- obtaining a copy of this software and associated documentation
-- files (the “Software”), to deal in the Software without
-- restriction, including without limitation the rights to use, copy,
-- modify, merge, publish, distribute, sublicense, and/or sell copies
-- of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
-- NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
-- BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
-- ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
-- CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

local package = {}
local shim = {}

package.config = "/\n;\n?"
package.path = table.concat({
	"?.lua",
	"?/init.lua",

	"/lib/?.lua",
	"/lib/?/init.lua",
}, ";")

-- utility function to get the directory separator from `package.config`.
local function getdirsep()
	return string.match(package.config, "^[^\n]+")
end

-- utility function to get the template separator from `package.config`.
local function gettemplatesep()
	local dirsep = getdirsep()
	return string.match(package.config, "^[^\n]+", #dirsep + 2)
end

-- utility function to get the template substitution marker from
-- `package.config`.
local function gettemplatesubst()
	local dirsep = getdirsep()
	local templatesep = gettemplatesep()
	return string.match(package.config, "^[^\n]+", #dirsep + #templatesep + 3)
end

-- utility function to escape every character of a string, for use as
-- "patterns" in functions like `string.match` and `string.gsub`.
local function patescape(str)
	return string.gsub(str, ".", function(char)
		return "%" .. char
	end)
end

function package.searchpath(name, path, sep, rep)
	sep = sep or "."
	rep = rep or getdirsep()
	local templatesep = gettemplatesep()
	path = path .. templatesep -- needed for matching.
	local templatesubst = gettemplatesubst()
	local namepathfrag = string.gsub(name, patescape(sep), rep)

	local tried = {}
	-- this `string.gmatch` is saying "match each thing with a template
	-- separator immediately after it", and is a way of splitting a string
	-- by an arbitrary separator.

	for template in string.gmatch(path, "(.-)(" .. patescape(templatesep) .. ")") do
		local filename = string.gsub(template, patescape(templatesubst), namepathfrag)

		if filename:sub(1, 1) ~= "/" then
			filename = cwd .. filename
		end

		if coroutine.yield({ type = "isfile", path = filename }) then
			return filename
		else
			table.insert(tried, filename)
		end
	end

	return nil, string.format("no module found in the following locations: %s", table.concat(tried, ", "))
end

function shim.loadfile(filename, mode, environment)
	local fd, err = coroutine.yield({ type = "open", path = filename, mode = "r" })
	if err then
		error(err, 2)
	end

	local data = coroutine.yield({ type = "read", fd = fd, count = "a" })
	coroutine.yield({ type = "close", fd = fd })

	return load(data, filename, mode or "bt", environment or _G)
end

package.preload = {}

package.searchers = {
	-- the first searcher looks for a loader in `package.preload`.
	function(name)
		return package.preload[name], ":preload:"
	end,

	-- the second searcher looks for a loader as a lua library, using
	-- `package.searchpath` where the `path` argument is `package.path`.
	function(name)
		local filename, err = package.searchpath(name, package.path)
		if err then
			return err
		end

		local loader, load_err = shim.loadfile(filename)
		if load_err then
			error(load_err)
		end
		return loader, filename
	end,

	-- the third and fourth searchers aren't relevant, since they're for
	-- loading c libraries, and so i've not implemented them here.
}

package.loaded = {}

-- here it is, `require` itself!
-- the function itself is surprisingly simple, actually. i built up all
-- the complicated parts beforehand. this just puts it all together.
function shim.require(modname)
	-- first, check if the module is already loaded.
	if package.loaded[modname] then
		return package.loaded[modname]
	end

	-- then, iterate through `package.searchers`.
	for _, searcher in ipairs(package.searchers) do
		local loader, data = searcher(modname)
		-- if you find a searcher that returns a loader, call the loader
		-- with `modname` and the loader data.
		if type(loader) == "function" then
			return loader(modname, data)
		end
	end

	-- if no searcher retuns a loader, raise an error.
	return error(string.format("could not find module: %q", modname), 2)
end

return package, shim.require, shim.loadfile
