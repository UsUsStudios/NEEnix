return {
	["Config"] = {
		["DefaultEntry"] = 1, -- the option that appears highlighted first when entering the boot menu
		["Autoboot"] = 1, -- or: index number for .Bootlist[i]
	},
	["Bootlist"] = {
		{
			["OS Name"] = "NEEnix",
			["OS Version"] = "0.0.1",
			["OS Description"] = "NEATO-compatible UNIX-like system",
			["OS Boot Path"] = "0:system:boot/kernel.lua",
		},
		{
			["OS Name"] = "OS Installer",
			["OS Version"] = "1.0.0", -- semver style (possibly?) enforced
			["OS Description"] = "Install a supported OS from the internet",
			["OS Boot Path"] = "0:neatobios:/installer/installer.lua",
		},
	},
}
