-- The filesystem for the main computer screen and coloured screen peripheral devices

local function create(get_fd, id)
	local fs = {}
	if id then
		fs.api = _G.io.wrapPeripheral(id)
	else
		fs.api = _G.screen
	end

	fs.api.fs = fs -- so it can be closed directly

	fs.owner = 0
	fs.apicopy = {}

	function fs.api.close()
		for k, _ in pairs(fs.apicopy) do
			fs.apicopy[k] = nil
		end
		fs.owner = nil
	end

	function fs.stringrepr()
		if id then
			return "screenfs - id " .. id
		end
		return "screenfd - default screen"
	end

	function fs.open(pcb, path)
		if path ~= "" then
			error("invalid path")
		end
		if fs.owner ~= 0 then
			error("screen already being controlled")
		end

		fs.apicopy = {}
		for k, v in pairs(fs.api) do
			fs.apicopy[k] = v
		end

		fs.owner = pcb.pid
		return fs.apicopy
	end

	function fs.close()
		error("invalid operation on " .. fs.stringrepr())
	end

	function fs.read()
		error("invalid operation on " .. fs.stringrepr())
	end

	function fs.lseek()
		error("invalid operation on " .. fs.stringrepr())
	end

	function fs.write()
		error("invalid operation on " .. fs.stringrepr())
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

	function fs.isFile()
		return true
	end

	return fs
end

return create
