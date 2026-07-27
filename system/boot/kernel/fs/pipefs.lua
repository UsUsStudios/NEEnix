-- The filesystem for /dev/popen, for opening pipes

local function create(fd_list, next_fd)
	local fs = {}

	function fs.stringrepr()
		return "pipefs"
	end

	function fs.open(path)
		if path ~= "" then
			error("file does not exist")
		end
		local input = next_fd()
		local output = next_fd()
		fd_list[input] = {
			fs = fs,
			buffer = {},
			output = output,
			closed = false,
		}
		fd_list[output] = {
			fs = fs,
			input = input,
			closed = false,
		}
		return { input, output }
	end

	function fs.close(fd)
		fd_list[fd].closed = true
	end

	function fs.read(fd)
		local outputfd = fd_list[fd]
		if outputfd.buffer then -- it's an input fd
			return error("can't read from an input file descriptor")
		elseif fd_list[outputfd.input].closed then
			return error("other end of pipe is closed")
		end
		local inputbuf = fd_list[outputfd.input].buffer
		if #inputbuf > 0 then
			local data = inputbuf[#inputbuf]
			inputbuf[#inputbuf] = nil -- delete the top of the stack
			return data
		end
		return "\0"
	end

	function fs.lseek()
		error("invalid operation on " .. fs.stringrepr())
	end

	function fs.write(fd, buffer)
		local inputfd = fd_list[fd]
		if inputfd.input then -- it's an output fd
			return error("can't write to an output file descriptor")
		elseif fd_list[inputfd.output].closed then
			return error("other end of pipe is closed")
		end
		table.insert(inputfd.buffer, buffer)
	end

	function fs.fsync()
		error("invalid operation on " .. fs.stringrepr())
	end

	function fs.mkdir()
		error("invalid operation on " .. fs.stringrepr())
	end

	function fs.unlink()
		error("invalid operation on " .. fs.stringrepr())
	end

	function fs.readdir()
		error("invalid operation on " .. fs.stringrepr())
	end

	return fs
end

return create
