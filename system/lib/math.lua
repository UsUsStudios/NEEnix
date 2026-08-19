local _math = math
local math = {}
local complex = require("complex", math)

-- CONSTANTS AND MISC
math.M_E = 2.718281828459045090795598298427648842334747314453125
math.M_LOG2E = 1.442695040888963387004650940070860087871551513671875
math.M_LOG10E = 0.43429448190325181666793241674895398318767547607421875
math.M_LN2 = 0.69314718055994528622676398299518041312694549560546875
math.M_LN10 = 2.30258509299404590109361379290930926799774169921875
math.M_PI = 3.141592653589793115997963468544185161590576171875
math.M_PI_2 = 1.5707963267948965579989817342720925807952880859375
math.M_PI_4 = 0.78539816339744827899949086713604629039764404296875
math.M_1_PI = 0.31830988618379069121644420192751567810773849487304688
math.M_2_PI = 0.63661977236758138243288840385503135621547698974609375
math.M_2_SQRTPI = 1.1283791670955125585606992899556644260883331298828125
math.M_SQRT2 = 1.4142135623730951454746218587388284504413604736328125
math.M_SQRT1_2 = 0.70710678118654757273731092936941422522068023681640625
math.M_I = complex.z(0, 1)

math.factorial = function(x)
	local val = 1
	for i = 2, x do
		val = val * i
	end
	return val
end

math.abs = _math.abs
math.ceil = _math.ceil
math.floor = _math.floor
math.round = function(x)
	return _math.floor(x + 0.5)
end
math.fmod = _math.fmod
math.max = _math.max

-- TRIGONOMETRY
math.sin = _math.sin
math.cos = _math.cos
math.tan = _math.tan
math.csin = function(z)
	local iz = math.M_I * z

	return (math.cexp(iz) - math.cexp(-iz)) / (2 * math.M_I)
end
math.ccos = function(z)
	local iz = math.M_I * z

	return (math.cexp(iz) + math.cexp(-iz)) / 2
end
math.ctan = function(z)
	return math.csin(z) / math.ccos(z)
end

-- INVERSE TRIGONOMETRY
math.asin = _math.asin
math.acos = _math.acos
math.atan = _math.atan
math.atan2 = _math.atan
math.casin = function(z)
	return -math.M_I * math.clog(math.M_I * z + math.csqrt(1 - z ^ 2))
end
math.cacos = function(z)
	return -math.M_I * math.clog(z + math.csqrt(z ^ 2 - 1))
end
math.catan = function(z)
	return -math.M_I / 2 * math.clog((math.M_I - z) / (math.M_I + z))
end

-- EXPONENTIATION AND LOGARITHMS
math.exp = _math.exp
math.exp2 = function(x)
	return 2 ^ x
end
math.exp10 = function(x)
	return 10 ^ x
end
math.log = function(x)
	return _math.log(x, math.M_E)
end
math.log2 = function(x)
	return _math.log(x, 2)
end
math.log10 = function(x)
	return _math.log(x, 10)
end
math.logb = function(x)
	return math.floor(math.log2(math.abs(x)))
end

math.pow = function(x, n)
	return x ^ n
end
math.sqrt = _math.sqrt
math.cbrt = function(x)
	if x < 0 then
		return -((-x) ^ (1 / 3))
	end
	return x ^ (1 / 3)
end
math.hypot = function(x, y)
	return math.sqrt(x * x + y * y)
end
math.rootn = function(x, n)
	return x ^ (1 / n)
end

math.cexp = function(z)
	return math.M_E ^ z
end
math.clog = function(z)
	return math.log(complex.cabs(z)) + math.M_I * complex.carg(z)
end
math.clog10 = function(z)
	return math.log10(complex.cabs(z)) + math.M_I * complex.carg(z) / math.M_LN10
end
math.csqrt = function(z)
	return math.cpow(z, 1 / 2)
end
math.cpow = function(x, y)
	return x ^ y
end

-- HYPERBOLIC TRIGONOMETRY
math.sinh = function(x)
	return (math.exp(2 * x) - 1) / (2 * math.exp(x))
end
math.cosh = function(x)
	return (math.exp(2 * x) + 1) / (2 * math.exp(x))
end
math.tanh = function(x)
	return math.sinh(x) / math.cosh(x)
end
math.csinh = function(z)
	return (math.cexp(z) - math.cexp(-z)) / 2
end
math.ccosh = function(z)
	return (math.cexp(z) + math.cexp(-z)) / 2
end
math.ctanh = function(z)
	return math.csinh(z) / math.ccosh(z)
end

math.asinh = function(x)
	return math.log(x + math.sqrt(x ^ 2 + 1))
end
math.acosh = function(x)
	return math.log(x + math.sqrt(x ^ 2 - 1))
end
math.atanh = function(x)
	return 1 / 2 * math.log((1 + x) / (1 - x))
end
math.casinh = function(z)
	return math.clog(z + math.csqrt(z ^ 2 + 1))
end
math.cacosh = function(z)
	return math.clog(z + math.csqrt(z ^ 2 - 1))
end
math.catanh = function(z)
	return 1 / 2 * math.clog((1 + z) / (1 - z))
end

return math
