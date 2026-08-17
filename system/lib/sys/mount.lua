local mount = {}

function mount.mount(mountfile, mountpoint)
	coroutine.yield({ type = "mount", fspath = mountfile, mountpoint = mountpoint })
end

function mount.umount(mountpoint)
	coroutine.yield({ type = "mount", unmount = true, mountpoint = mountpoint })
end

return mount
