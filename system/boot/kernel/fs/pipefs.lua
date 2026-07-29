-- The filesystem for /dev/popen, for opening pipes

local function create(next_fd)
	local fs = {}

	function fs.stringrepr()
		return "pipefs"
	end

	function fs.open(pcb, path)
		if path ~= "" then
			error("file does not exist")
		end
		local input = {
			fs = fs,
			buffer = {},
			closed = false,
		}
		local output = {
			fs = fs,
			input = input,
			closed = false,
		}
		input.output = output
		local inputfd = next_fd()
		local outputfd = next_fd()
		pcb.fds[inputfd] = input
		pcb.fds[outputfd] = output
		return { inputfd, outputfd }
	end

	function fs.close(pcb, fd)
		pcb.fds[fd].closed = true
	end

	function fs.read(pcb, fd)
		local outputfd = pcb.fds[fd]
		if outputfd.buffer then -- it's an input fd
			return error("can't read from an input file descriptor")
		elseif outputfd.closed then
			return error("can't read from closed pipe")
		elseif outputfd.input.closed then
			return error("other end of pipe is closed")
		end
		local inputbuf = outputfd.input.buffer
		if #inputbuf > 0 then
			local data = inputbuf[1]
			table.remove(inputbuf, 1)
			return data
		end
		return "\0"
	end

	function fs.lseek(pcb)
		error("invalid operation on " .. fs.stringrepr())
	end

	function fs.write(pcb, fd, buffer)
		local inputfd = pcb.fds[fd]
		if inputfd.input then -- it's an output fd
			return error("can't write to an output file descriptor")
		elseif inputfd.closed then
			return error("can't write to closed pipe")
		elseif inputfd.output.closed then
			return error("other end of pipe is closed")
		end
		table.insert(inputfd.buffer, buffer)
	end

	function fs.fsync(pcb)
		error("invalid operation on " .. fs.stringrepr())
	end

	function fs.mkdir(pcb)
		error("invalid operation on " .. fs.stringrepr())
	end

	function fs.unlink(pcb)
		error("invalid operation on " .. fs.stringrepr())
	end

	function fs.readdir(pcb)
		error("invalid operation on " .. fs.stringrepr())
	end

	return fs
end

return create
