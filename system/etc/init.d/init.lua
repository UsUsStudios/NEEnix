local u = include("unistd")
local fd = u.open("/etc/environment/PATH", u.O_RDONLY)
print(u.readall(fd))
u.close(fd)
