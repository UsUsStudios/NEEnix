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

_G.package = {}

-- This default `package.config` means the following:
-- Line 1: The directory separator is "/".
-- Line 2: The character that separates templates is ";".
-- Line 3: The string that marks the substitution points in a template
--         is "?".
-- Base Lua's other two lines aren't relevant to NEETComputers, and so
-- aren't included in this implementation.
package.config = "/\n;\n?"

-- Utility function to get the directory separator from `package.config`.
local function getDirSep()
	return string.match(package.config, "^[^\n]+")
end

-- Utility function to get the template separator from `package.config`.
local function getTemplateSep()
	local dirSep = getDirSep()
	return string.match(package.config, "^[^\n]+", #dirSep + 2)
end

-- Utility function to get the template substitution marker from
-- `package.config`.
local function getTemplateSubst()
	local dirSep = getDirSep()
	local templateSep = getTemplateSep()
	return string.match(package.config, "^[^\n]+", #dirSep + #templateSep + 3)
end

if files.__old == nil then
	-- `package.path` is being constructed using `table.concat` becase
	-- it's much easier to read that way.
	package.path = table.concat({ -- This newline is *specifically* because of emacs's desire to
		-- indent *way* to the right for some reason if I don't have
		-- this.

		-- Check the "user" partition first.
		"user:/?.lua",
		"user:/?/init.lua",

		-- Check the "system" partition second.
		"system:/?.lua",
		"system:/?/init.lua",

		-- Check the "bios" partition third.
		"bios:/?.lua",
		"bios:/?/init.lua",
	}, ";")
else
	-- If `files.__old` exists, that probably means that my `files` shim
	-- is installed. In that case, use a `package.path` which is compatible
	-- with that.
	package.path = table.concat({
		-- Check the "user" partition of the 0th disk first.
		"0:user:/?.lua",
		"0:user:/?/init.lua",

		-- Check the "system" partition of the 0th disk second.
		"0:system:/?.lua",
		"0:system:/?/init.lua",

		-- Check the "bios" partition of the 0th disk third.
		"0:bios:/?.lua",
		"0:bios:/?/init.lua",
	}, ";")
end

-- Utility function to escape every character of a string, for use as
-- "patterns" in functions like `string.match` and `string.gsub`.
local function patEscape(str)
	return string.gsub(str, ".", function(char)
		return "%" .. char
	end)
end

function package.searchpath(name, path, sep, rep)
	sep = sep or "."
	rep = rep or getDirSep()
	local templateSep = getTemplateSep()
	path = path .. templateSep -- Needed for matching.
	local templateSubst = getTemplateSubst()
	local namePathFrag = string.gsub(name, patEscape(sep), rep)

	local tried = {}
	-- This `string.gmatch` is saying "match each thing with a template
	-- separator immediately after it", and is a way of splitting a string
	-- by an arbitrary separator.
	for template in string.gmatch(path, "(.-)(" .. patEscape(templateSep) .. ")") do
		local filename = string.gsub(template, patEscape(templateSubst), namePathFrag)
		if files.exists(filename) and files.isFile(filename) then
			return filename
		else
			table.insert(tried, filename)
		end
	end

	return nil, string.format("no module found in the following locations: %s", table.concat(tried, ", "))
end

package.preload = {}

package.searchers = {
	-- The first searcher looks for a loader in `package.preload`.
	function(name)
		return package.preload[name], ":preload:"
	end,

	-- The second searcher looks for a loader as a lua library, using
	-- `package.searchpath` where the `path` argument is `package.path`.
	function(name)
		local filename, err = package.searchpath(name, package.path)
		if err then
			return err
		end

		local handle = files.open(filename)
		local data = handle.read("a")
		handle.close()
		return load(data, filename), filename
	end,

	-- The third and fourth searchers aren't relevant, since they're for
	-- loading C libraries, and so I've not implemented them here.
}

package.loaded = {}

-- Here it is, `require` itself!
-- The function itself is surprisingly simple, actually. I built up all
-- the complicated parts beforehand. This just puts it all together.
function _G.require(modname)
	-- First, check if the module is already loaded.
	if package.loaded[modname] then
		return package.loaded[modname]
	end

	-- Then, iterate through `package.searchers`.
	for _, searcher in ipairs(package.searchers) do
		local loader, data = searcher(modname)
		-- If you find a searcher that returns a loader, call the loader
		-- with `modname` and the loader data.
		if type(loader) == "function" then
			return loader(modname, data)
		end
	end

	-- If no searcher retuns a loader, raise an error.
	return error(string.format("could not find module: %q", modname))
end
