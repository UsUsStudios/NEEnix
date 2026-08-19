local complex = {}
local math = ... or require("math")

local function znumber(x)
	if type(x) == "number" then
		return complex.z(x, 0)
	end
	return x
end

local complex_metatable = {
	__tostring = function(z)
		return z.r .. " + " .. z.i .. "i"
	end,
	__add = function(a, b)
		a = znumber(a)
		b = znumber(b)
		return complex.z(a.r + b.r, a.i + b.i)
	end,
	__sub = function(a, b)
		a = znumber(a)
		b = znumber(b)
		return complex.z(a.r - b.r, a.i - b.i)
	end,
	__mul = function(a, b)
		a = znumber(a)
		b = znumber(b)
		return complex.z(
			(a.r * b.r - a.i * b.i), --
			(a.r * b.i + a.i * b.r)
		)
	end,
	__div = function(a, b)
		a = znumber(a)
		b = znumber(b)
		return complex.z(
			(a.r * b.r + a.i * b.i) / (b.r ^ 2 + b.i ^ 2), --
			(a.i * b.r - a.r * b.i) / (b.r ^ 2 + b.i ^ 2)
		)
	end,
	__pow = function(z, w)
		z = znumber(z)
		w = znumber(w)
		local a, b = z.r, z.i
		local c, d = w.r, w.i

		if a == 0 and b == 0 then
			if c == 0 and d == 0 then
				return complex.z(1, 0)
			end

			return complex.z(0, 0)
		end

		local r2 = a * a + b * b
		local theta = complex.carg(z)
		local ln_r = 0.5 * math.log(r2)

		local magnitude = math.exp(c * ln_r - d * theta)
		local angle = c * theta + d * ln_r

		return complex.z(
			magnitude * math.cos(angle), --
			magnitude * math.sin(angle)
		)
	end,
	__unm = function(a)
		a = znumber(a)
		return complex.z(-a.r, -a.i)
	end,
	__eq = function(a, b)
		a = znumber(a)
		b = znumber(b)
		return a.r == b.r and a.i == b.i
	end,
	__index = function(z, index)
		if index == "r" then
			return z[1]
		elseif index == "i" then
			return z[2]
		end
		return z[3]
	end,
}

complex.z = function(r, i)
	local z = { r, i }
	setmetatable(z, complex_metatable)
	return z
end

complex.I = complex.z(0, 1)

complex.conj = function(z)
	return complex.z(z.r, -z.i)
end
complex.cabs = function(z)
	return math.sqrt(z.r ^ 2 + z.i ^ 2)
end
complex.creal = function(z)
	return z.r
end
complex.cimag = function(z)
	return z.i
end
complex.carg = function(z)
	return math.atan(z.i, z.r)
end

return complex
