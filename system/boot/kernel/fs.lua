local fs = {}
local fd_list = ...

function fs.open(path, mode) end
function fs.close(fd) end
function fs.read(fd, buffer, count) end
function fs.lseek(fd, offset, whence) end
function fs.write(fd, buffer) end
function fs.mkdir(path) end
function fs.unlink(path) end
function fs.rename(oldpath, newpath) end
function fs.readdir(path) end

return fs
