print("hi")

return {
	["Config"] = {
		["DefaultEntry"] = 1, -- the option that appears highlighted first when entering the boot menu
		["Autoboot"] = "none", -- or: index number for .Bootlist[i]
	},
	["Bootlist"] = {
		-- {
		-- 	["OS Name"] = "NEEnix",
		-- 	["OS Version"] = "0.0.1",
		-- 	["OS Description"] = "NEATO-compatible UNIX-like system",
		-- 	["OS Boot Path"] = "0:system:",
		-- },
		{
			["OS Name"] = "OS Installer",
			["OS Version"] = "1.0.0", -- semver style (possibly?) enforced
			["OS Description"] = "Install a supported OS from the internet",
			["OS Boot Path"] = "0:neatobios:/installer/installer.lua",
		},
	},
}
