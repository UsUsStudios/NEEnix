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

-- A global for path-related utility functions.
_G.path = {}

-- A utility function to get all the parts of an improved path.
-- Returns the disk, then the partition, then the filename.
function path.split(improvedPath)
	local diskStr = string.match(improvedPath, "^%d+")
	local disk = tonumber(diskStr)
	local partition = string.match(improvedPath, "^[^:]+", #diskStr + 2)
	local filename = string.sub(improvedPath, #diskStr + #partition + 3)
	return disk, partition, filename
end

-- A utility function to get only the "disk" part of an improved path.
function path.getDisk(improvedPath)
	local disk, _, _ = path.split(improvedPath)
	return disk
end

-- A utility function to get only the "partition" part of an improved path.
function path.getPartition(improvedPath)
	local _, partition, _ = path.split(improvedPath)
	return partition
end

-- A utility function to get only the "filename" part of an improved path.
function path.getFilename(improvedPath)
	local _, _, filename = path.split(improvedPath)
	return filename
end

-- A utility function to strip off the "disk" part of an improved path,
-- for use with the unmodified version of `files`.
function path.stripDisk(improvedPath)
	local diskStr = string.match(improvedPath, "^%d+")
	return string.sub(improvedPath, #diskStr + 2)
end

-- A utility function to check if a string is an improved path.
function path.isImprovedPath(str)
	local match = string.match(str, "^%d+:[^:]+:.+$")
	return match ~= nil
end

-- A utility function to check if a string is an improved path.
function path.isVanillaPath(str)
	local match = string.match(str, "^[^:]:.+$")
	return not path.isImprovedPath(str) and match ~= nil
end

-- Save the original version of `files` for later.
local oldFiles = files

-- Replace the global `files` with this shim.
_G.files = {
	__old = oldFiles, -- Just in case someone needs the non-shimmed versions.
	getPartitions = oldFiles.getPartitions,
	getPartition = oldFiles.getPartition,
	createPartition = oldFiles.createPartition,
	deletePartition = oldFiles.deletePartition,
	setPartitionHidden = oldFiles.setPartitionHidden,
	getNumberOfDisks = oldFiles.getNumberOfDisks,
	getDisks = oldFiles.getDisks,
	getDiskID = oldFiles.getDiskID,
	removeDisk = oldFiles.removeDisk,
	setBoot = oldFiles.setBoot,

	-- It should be noted that the "path" associated with these two functions
	-- isn't being modified, because each disk has its *own*  entrypoint.
	-- That means that the "path" for these functions isn't ambiguous,
	-- which means that I don't need to change it.
	getBootPath = oldFiles.getBoothPath,
	setBoot = oldFiles.setBoot,
}

-- Now, I write shims for the *rest* of the `files` methods.
-- These simply get the disk from the full path, then it strips
-- the "disk" portion of the full path to get a vanilla NEETComputers
-- path, and then it passes those into the relevant method.
function files.open(improvedPath, mode)
	mode = mode or "r"
	local disk = path.getDisk(improvedPath)
	local strippedPath = path.stripDisk(improvedPath)
	return oldFiles.open(strippedPath, mode, disk)
end

function files.getChildrten(improvedPath)
	local disk = path.getDisk(improvedPath)
	local strippedPath = path.stripDisk(improvedPath)
	return oldFiles.getChildren(strippedPath, disk)
end

function files.makeDir(improvedPath)
	local disk = path.getDisk(improvedPath)
	local strippedPath = path.stripDisk(improvedPath)
	return oldFiles.makeDir(strippedPath, disk)
end

function files.exists(improvedPath)
	local disk = path.getDisk(improvedPath)
	local strippedPath = path.stripDisk(improvedPath)
	return oldFiles.exists(strippedPath, disk)
end

function files.isFile(improvedPath)
	local disk = path.getDisk(improvedPath)
	local strippedPath = path.stripDisk(improvedPath)
	return oldFiles.isFile(strippedPath, disk)
end

function files.isDir(improvedPath)
	local disk = path.getDisk(improvedPath)
	local strippedPath = path.stripDisk(improvedPath)
	return oldFiles.isDir(strippedPath, disk)
end

function files.delete(improvedPath)
	local disk = path.getDisk(improvedPath)
	local strippedPath = path.stripDisk(improvedPath)
	return oldFiles.delete(strippedPath, disk)
end

-- I'm also including a shim for `loadfile`, since that function also
-- works with file paths.
function _G.loadfile(filename, mode, env)
	local handle -- Gracefully handle "vanilla" paths.
	if path.isImprovedPath(filename) then
		handle = files.open(filename)
	else
		handle = oldFiles.open(filename) -- Assumes that disk=0.
	end

	local data = handle.read("a")
	handle.close()

	-- I /think/ using `_G` as the default value is the right thing to
	-- do here? I'm not completely sure about that, though.
	return load(data, filename, mode or "bt", env or _G)
end
