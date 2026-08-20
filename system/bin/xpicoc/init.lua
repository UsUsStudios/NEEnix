local floor = math.floor
local unistd = require("unistd")

local arg = {...}

local MOD = 2^32
local MODM = MOD-1

local function memoize(f)

  local mt = {}
  local t = setmetatable({}, mt)

  function mt:__index(k)
    local v = f(k)
    t[k] = v
    return v
  end

  return t
end

local function make_bitop_uncached(t, m)
  local function bitop(a, b)
    local res,p = 0,1
    while a ~= 0 and b ~= 0 do
      local am, bm = a%m, b%m
      res = res + t[am][bm]*p
      a = (a - am) / m
      b = (b - bm) / m
      p = p*m
    end
    res = res + (a+b) * p
    return res
  end
  return bitop
end

local function make_bitop(t)
  local op1 = make_bitop_uncached(t, 2^1)
  local op2 = memoize(function(a)
    return memoize(function(b)
      return op1(a, b)
    end)
  end)
  return make_bitop_uncached(op2, 2^(t.n or 1))
end

-- ok? probably not if running on a 32-bit int Lua number type platform
function tobit(x)
  return x % 2^32
end

bxor = make_bitop({[0]={[0]=0,[1]=1},[1]={[0]=1,[1]=0}, n=4})

function bnot(a)
  return MODM - a
end

function band(a,b)
  return ((a+b) - bxor(a,b))/2
end

function bor(a,b)
  return MODM - band(MODM - a, MODM - b)
end

function rshift(a,disp) -- Lua5.2 insipred
  if disp < 0 then return lshift(a,-disp) end
  return floor(a % 2^32 / 2^disp)
end

function lshift(a,disp) -- Lua5.2 inspired
  if disp < 0 then return rshift(a,-disp) end
  return (a * 2^disp) % 2^32
end

function tohex(x, n) -- BitOp style
  n = n or 8
  local up
  if n <= 0 then
    if n == 0 then return '' end
    up = true
    n = - n
  end
  x = band(x, 16^n-1)
  return ('%0'..n..(up and 'X' or 'x')):format(x)
end

function extract(n, field, width) -- Lua5.2 inspired
  width = width or 1
  return band(rshift(n, field), 2^width-1)
end

function replace(n, v, field, width) -- Lua5.2 inspired
  width = width or 1
  local mask1 = 2^width-1
  v = band(v, mask1) -- required by spec?
  local mask = bnot(lshift(mask1, field))
  return band(n, mask) + lshift(v, field)
end

function bswap(x)  -- BitOp style
  local a = band(x, 0xff); x = rshift(x, 8)
  local b = band(x, 0xff); x = rshift(x, 8)
  local c = band(x, 0xff); x = rshift(x, 8)
  local d = band(x, 0xff)
  return lshift(lshift(lshift(a, 8) + b, 8) + c, 8) + d
end

function rrotate(x, disp)  -- Lua5.2 inspired
  disp = disp % 32
  local low = band(x, 2^disp-1)
  return rshift(x, disp) + lshift(low, 32-disp)
end

function lrotate(x, disp)  -- Lua5.2 inspired
  return rrotate(x, -disp)
end

function arshift(x, disp) -- Lua5.2 inspired
  local z = rshift(x, disp)
  if x >= 0x80000000 then z = z + lshift(2^disp-1, 32-disp) end
  return z
end

function btest(x, y) -- Lua5.2 inspired
  return band(x, y) ~= 0
end

--
-- Start Lua 5.2 "bit32" compat section.
--

function bit32_bnot(x)
  return (-1 - x) % MOD
end

function bit32_bxor(a, b, c, ...)
  local z
  if b then
    a = a % MOD
    b = b % MOD
    z = bxor(a, b)
    if c then
      z = bit32_bxor(z, c, ...)
    end
    return z
  elseif a then
    return a % MOD
  else
    return 0
  end
end

function bit32_band(a, b, c, ...)
  local z
  if b then
    a = a % MOD
    b = b % MOD
    z = ((a+b) - bxor(a,b)) / 2
    if c then
      z = bit32_band(z, c, ...)
    end
    return z
  elseif a then
    return a % MOD
  else
    return MODM
  end
end

function bit32_bor(a, b, c, ...)
  local z
  if b then
    a = a % MOD
    b = b % MOD
    z = MODM - band(MODM - a, MODM - b)
    if c then
      z = bit32_bor(z, c, ...)
    end
    return z
  elseif a then
    return a % MOD
  else
    return 0
  end
end

function bit32_btest(...)
  return bit32_band(...) ~= 0
end

function bit32_lrotate(x, disp)
  return lrotate(x % MOD, disp)
end

function bit32_rrotate(x, disp)
  return rrotate(x % MOD, disp)
end

function bit32_lshift(x,disp)
  if disp > 31 or disp < -31 then return 0 end
  return lshift(x % MOD, disp)
end

function bit32_rshift(x,disp)
  if disp > 31 or disp < -31 then return 0 end
  return rshift(x % MOD, disp)
end

function bit32_arshift(x,disp)
  x = x % MOD
  if disp >= 0 then
    if disp > 31 then
      return (x >= 0x80000000) and MODM or 0
    else
      local z = rshift(x, disp)
      if x >= 0x80000000 then z = z + lshift(2^disp-1, 32-disp) end
      return z
    end
  else
    return lshift(x, -disp)
  end
end

function bit32_extract(x, field, ...)
  local width = ... or 1
  if field < 0 or field > 31 or width < 0 or field+width > 32 then error 'out of range' end
  x = x % MOD
  return extract(x, field, ...)
end

function bit32_replace(x, v, field, ...)
  local width = ... or 1
  if field < 0 or field > 31 or width < 0 or field+width > 32 then error 'out of range' end
  x = x % MOD
  v = v % MOD
  return replace(x, v, field, ...)
end


--
-- Start LuaBitOp "bit" compat section.
--

function bit_tobit(x)
  x = x % MOD
  if x >= 0x80000000 then x = x - MOD end
  return x
end

function bit_tohex(x, ...)
  return tohex(x % MOD, ...)
end

function bit_bnot(x)
  return bit_tobit(bnot(x % MOD))
end

function bit_bor(a, b, c, ...)
  if c then
    return bit_bor(bit_bor(a, b), c, ...)
  elseif b then
    return bit_tobit(bor(a % MOD, b % MOD))
  else
    return bit_tobit(a)
  end
end

function bit_band(a, b, c, ...)
  if c then
    return bit_band(bit_band(a, b), c, ...)
  elseif b then
    return bit_tobit(band(a % MOD, b % MOD))
  else
    return bit_tobit(a)
  end
end

function bit_bxor(a, b, c, ...)
  if c then
    return bit_bxor(bit_bxor(a, b), c, ...)
  elseif b then
    return bit_tobit(bxor(a % MOD, b % MOD))
  else
    return bit_tobit(a)
  end
end

function bit_lshift(x, n)
  return bit_tobit(lshift(x % MOD, n % 32))
end

function bit_rshift(x, n)
  return bit_tobit(rshift(x % MOD, n % 32))
end

function bit_arshift(x, n)
  return bit_tobit(arshift(x % MOD, n % 32))
end

function bit_rol(x, n)
  return bit_tobit(lrotate(x % MOD, n % 32))
end

function bit_ror(x, n)
  return bit_tobit(rrotate(x % MOD, n % 32))
end

function bit_bswap(x)
  return bit_tobit(bswap(x % MOD))
end
function LibraryInit(pc)
    pc.VersionString = TableStrRegister(pc, PICOC_VERSION)
    VariableDefinePlatformVar(pc, nil, "PICOC_VERSION", pc.CharPtrType,
        pc.VersionString, false)
end

function LibraryAdd(pc, FuncList)
    local Parser = {}
    local Count = 1
    local Identifier
    local ReturnType
    local NewValue
    local Tokens
    local IntrinsicName = TableStrRegister(pc, "c library")

    while FuncList[Count].Prototype ~= nil do
        Tokens, _ = LexAnalyse(pc, IntrinsicName, FuncList[Count].Prototype,
            string.len(FuncList[Count].Prototype))
        LexInitParser(Parser, pc, FuncList[Count].Prototype, Tokens,
            IntrinsicName, true, false)
        ReturnType, Identifier, _ = TypeParse(Parser)
        NewValue = ParseFunctionDefinition(Parser, ReturnType, Identifier)
        NewValue.Val.FuncDef.Intrinsic = FuncList[Count].Func
        Count = Count + 1
    end
end

function PrintType(Typ, Stream)
    if Typ.Base == BaseType.TypeVoid then
        PrintStr("void", Stream)
    elseif Typ.Base == BaseType.TypeInt then
        PrintStr("int", Stream)
    elseif Typ.Base == BaseType.TypeShort then
        PrintStr("short", Stream)
    elseif Typ.Base == BaseType.TypeChar then
        PrintStr("char", Stream)
    elseif Typ.Base == BaseType.TypeLong then
        PrintStr("long", Stream)
    elseif Typ.Base == BaseType.TypeUnsignedInt then
        PrintStr("unsigned int", Stream)
    elseif Typ.Base == BaseType.TypeUnsignedShort then
        PrintStr("unsigned short", Stream)
    elseif Typ.Base == BaseType.TypeUnsignedLong then
        PrintStr("unsigned long", Stream)
    elseif Typ.Base == BaseType.TypeUnsignedChar then
        PrintStr("unsigned char", Stream)
    elseif Typ.Base == BaseType.TypeFP then
        PrintStr("double", Stream)
    elseif Typ.Base == BaseType.TypeFunction then
        PrintStr("function", Stream)
    elseif Typ.Base == BaseType.TypeMacro then
        PrintStr("macro", Stream)
    elseif Typ.Base == BaseType.TypePointer then
        if Typ.FromType ~= nil then
            PrintType(Typ.FromType, Stream)
        end
        PrintCh('*', Stream)
    elseif Typ.Base == BaseType.TypeArray then
        PrintType(Typ.FromType, Stream)
        PrintCh('[', Stream)
        if Typ.ArraySize ~= 0 then
            PrintSimpleInt(Typ.ArraySize, Stream)
        end
        PrintCh(']', Stream)
    elseif Typ.Base == BaseType.TypeStruct then
        PrintStr("struct ", Stream)
        PrintStr(Typ.Identifier.RawValue.Val, Stream)
    elseif Typ.Base == BaseType.TypeUnion then
        PrintStr("union ", Stream)
        PrintStr(Typ.Identifier.RawValue.Val, Stream)
    elseif Typ.Base == BaseType.TypeEnum then
        PrintStr("enum ", Stream)
        PrintStr(Typ.Identifier.RawValue.Val, Stream)
    elseif Typ.Base == BaseType.TypeGotoLabel then
        PrintStr("goto label ", Stream)
    elseif Typ.Base == BaseType.TypeType then
        PrintStr("type ", Stream)
    end
end

function PrintCh(OutCh, Stream)
    Stream.puts(OutCh)
end

function PrintSimpleInt(Num, Stream)
    Stream.puts(string.format("%d", Num))
end

function PrintStr(Str, Stream)
    Stream.puts(Str)
end

function PrintFP(Num, Stream)
    Stream.puts(string.format("%f", Num))
end
function IncludeInit(pc)
    IncludeRegister(pc, "math.h", nil, MathFunctions, nil)
    IncludeRegister(pc, "stdio.h", StdioSetupFunc, StdioFunctions, StdioDefs)
    IncludeRegister(pc, "stdlib.h", StdlibSetupFunc, StdlibFunctions, nil)
    IncludeRegister(pc, "string.h", StringSetupFunc, StringFunctions, nil)

    IncludeRegister(pc, "console.h", nil, ConsoleFunctions, nil)
end

function IncludeCleanup(pc)
    local ThisInclude = pc.IncludeLibList

    while ThisInclude ~= nil do
        ThisInclude = ThisInclude.NextLib
    end

    pc.IncludeLibList = nil
end

function IncludeRegister(pc, IncludeName, SetupFunction, FuncList, SetupCSource)
    NewLib = {}
    NewLib.IncludeName = TableStrRegister(pc, IncludeName)
    NewLib.SetupFunction = SetupFunction
    NewLib.FuncList = FuncList
    NewLib.SetupCSource = SetupCSource
    NewLib.NextLib = pc.IncludeLibList
    pc.IncludeLibList = NewLib
end

function PicocIncludeAllSystemHeaders(pc)
    local ThisInclude = pc.IncludeLibList

    while ThisInclude ~= nil do
        IncludeFile(pc, ThisInclude.IncludeName)
        ThisInclude = ThisInclude.NextLib
    end
end

function IncludeFile(pc, FileName)
    local LInclude = pc.IncludeLibList

    while LInclude ~= nil do
        if LInclude.IncludeName.RawValue.Val == FileName.RawValue.Val then
            if not VariableDefined(pc, FileName) then
                VariableDefine(pc, nil, FileName, nil, pc.VoidType, false)

                if LInclude.SetupFunction ~= nil then
                    LInclude.SetupFunction(pc)
                end

                if LInclude.SetupCSource ~= nil then
                    PicocParse(pc, FileName.RawValue.Val, LInclude.SetupCSource,
                        string.len(LInclude.SetupCSource), true, false)
                end

                if LInclude.FuncList ~= nil then
                    LibraryAdd(pc, LInclude.FuncList)
                end
            end

            return
        end
        LInclude = LInclude.NextLib
    end

    PicocPlaformScanFile(pc, FileName.RawValue.Val)
end
MAX_FORMAT = 80

function StdioOutPutc(OutCh, Stream)
    if Stream.FilePtr ~= nil then
        Stream.FilePtr.puts(OutCh)
        Stream.CharCount = Stream.CharCount + 1
    else
        -- Output to string to be implemented
    end
end

function StdioOutPuts(Str, Stream)
    if Stream.FilePtr ~= nil then
        Stream.FilePtr.puts(Str)
    else

    end
end

function StdioFprintfValue(Stream, Format, Value)
    if Stream.FilePtr ~= nil then
        local Str = string.format(Format, Value)
        Stream.FilePtr.puts(Str)
        Stream.CharCount = Stream.CharCount + string.len(Str)
    else

    end
end

function GET_FCHAR(Format, FPos)
    return string.sub(Format, FPos, FPos)
end

function StdioBasePrintf(Parser, Stream, StrOut, StrOutLen, Format, Args)
    local ArgCount = 0
    local ArgPos = Args.ParamStartStackId
    local FPos
    local OneFormatBuf = ""
    local OneFormatCount
    local ShowLong = false
    local ShowType
    local SOStream = {}
    local pc = Parser.pc
    local ThisArg = HeapGetStackNode(pc, ArgPos)

    if Format == nil then
        Format = "[null format]\n"
    end

    FPos = 1
    SOStream.FilePtr = Stream
    SOStream.StrOutPtr = StrOut
    SOStream.StrOutLen = StrOutLen
    SOStream.CharCount = 0

    while GET_FCHAR(Format, FPos) ~= '\0' and GET_FCHAR(Format, FPos) ~= '' do
        if GET_FCHAR(Format, FPos) == '%' then
            FPos = FPos + 1
            ShowType = nil
            OneFormatBuf = "%"
            OneFormatCount = 1

            repeat
                if GET_FCHAR(Format, FPos) == 'd' or GET_FCHAR(Format, FPos) == 'i' then
                    if ShowLong then
                        ShowLong = false
                        ShowType = pc.LongType
                    else
                        ShowType = pc.IntType
                    end
                elseif GET_FCHAR(Format, FPos) == 'u' then
                    if ShowLong then
                        ShowLong = 0
                        ShowType = pc.UnsignedLongType
                    end
                elseif GET_FCHAR(Format, FPos) == 'o' or GET_FCHAR(Format, FPos) == 'x' or
                    GET_FCHAR(Format, FPos) == 'X' then
                    ShowType = pc.IntType
                elseif GET_FCHAR(Format, FPos) == 'l' then
                    ShowLong = true
                elseif GET_FCHAR(Format, FPos) == 'e' or GET_FCHAR(Format, FPos) == 'E' then
                    ShowType = pc.FPType
                elseif GET_FCHAR(Format, FPos) == 'f' or GET_FCHAR(Format, FPos) == 'F' then
                    ShowType = pc.FPType
                elseif GET_FCHAR(Format, FPos) == 'g' or GET_FCHAR(Format, FPos) == 'G' then
                    ShowType = pc.FPType
                elseif GET_FCHAR(Format, FPos) == 'a' or GET_FCHAR(Format, FPos) == 'A' then
                    ShowType = pc.IntType
                elseif GET_FCHAR(Format, FPos) == 'c' then
                    ShowType = pc.IntType
                elseif GET_FCHAR(Format, FPos) == 's' then
                    ShowType = pc.CharPtrType
                elseif GET_FCHAR(Format, FPos) == 'p' then
                    ShowType = pc.VoidPtrType
                elseif GET_FCHAR(Format, FPos) == 'n' then
                    ShowType = pc.VoidType
                elseif GET_FCHAR(Format, FPos) == 'm' then
                    ShowType = pc.VoidType
                elseif GET_FCHAR(Format, FPos) == '%' then
                    ShowType = pc.VoidType
                elseif GET_FCHAR(Format, FPos) == '\0' or GET_FCHAR(Format, FPos) == '' then
                    ShowType = pc.VoidType
                end

                if GET_FCHAR(Format, FPos) ~= 'l' then
                    OneFormatBuf = OneFormatBuf .. GET_FCHAR(Format, FPos)
                    OneFormatCount = OneFormatCount + 1
                end

                if ShowType == pc.VoidType then
                    if GET_FCHAR(Format, FPos) == 'm' then
                        -- Not supported, ignored
                    elseif GET_FCHAR(Format, FPos) == '%' then
                        StdioOutPutc(GET_FCHAR(Format, FPos), SOStream)
                    elseif GET_FCHAR(Format, FPos) == '\0' then
                        StdioOutPutc(GET_FCHAR(Format, FPos), SOStream)
                    elseif GET_FCHAR(Format, FPos) == 'n' then
                        ArgPos = ArgPos + 1
                    end
                end

                FPos = FPos + 1
            until ShowType ~= nil or OneFormatCount >= MAX_FORMAT

            if ShowType ~= pc.VoidType then
                if ArgCount >= Args.NumArgs then
                    StdioOutPuts("XXX", SOStream)
                else
                    ArgPos = ArgPos + 1
                    ThisArg = HeapGetStackNode(pc, ArgPos)

                    if ShowType == pc.LongType then
                        if IS_NUMERIC_COERCIBLE(ThisArg) then
                            StdioFprintfValue(SOStream, OneFormatBuf, PointerGetSignedInt(ThisArg.Val))
                        else
                            StdioOutPuts("XXX", SOStream)
                        end
                    elseif ShowType == pc.UnsignedLongType then
                        if IS_NUMERIC_COERCIBLE(ThisArg) then
                            StdioFprintfValue(SOStream, OneFormatBuf, PointerGetUnsignedInt(ThisArg.Val))
                        else
                            StdioOutPuts("XXX", SOStream)
                        end
                    elseif ShowType == pc.IntType then
                        if IS_NUMERIC_COERCIBLE(ThisArg) then
                            StdioFprintfValue(SOStream, OneFormatBuf, ExpressionCoerceInteger(ThisArg))
                        else
                            StdioOutPuts("XXX", SOStream)
                        end
                    elseif ShowType == pc.FPType then
                        if IS_NUMERIC_COERCIBLE(ThisArg) then
                            if IS_NUMERIC_COERCIBLE(ThisArg) then
                                StdioFprintfValue(SOStream, OneFormatBuf, ExpressionCoerceFP(ThisArg))
                            else
                                StdioOutPuts("XXX", SOStream)
                            end
                        end
                    elseif ShowType == pc.CharPtrType then
                        if ThisArg.Typ.Base == BaseType.TypePointer then
                            local NewValue = PointerDereference(ThisArg.Val)
                            if NewValue == nil then
                                ProgramFail(Parser, "string expected")
                            end
                            StdioFprintfValue(SOStream, OneFormatBuf, PointerGetString(NewValue))
                        elseif ThisArg.Typ.Base == BaseType.TypeArray and
                            ThisArg.Typ.FromType.Base == BaseType.TypeChar then
                            StdioFprintfValue(SOStream, OneFormatBuf, PointerGetString(ThisArg.Val))
                        else
                            StdioOutPuts("XXX", SOStream)
                        end
                    elseif ShowType == pc.VoidPtrType then
                        -- No absolute addressing!
                        OneFormatBuf = string.gsub(OneFormatBuf, "%p", "%s")
                        if ThisArg.Typ.Base == BaseType.TypePointer then
                            StdioFprintfValue(SOStream, OneFormatBuf, "0xcccccccc")
                        elseif ThisArg.Typ.Base == BaseType.TypeArray then
                            StdioFprintfValue(SOStream, OneFormatBuf, "0xcccccccc")
                        else
                            StdioOutPuts("XXX", SOStream)
                        end
                    end

                    ArgCount = ArgCount + 1
                end
            end
        else
            StdioOutPutc(GET_FCHAR(Format, FPos), SOStream)
            FPos = FPos + 1
        end
    end

    return SOStream.CharCount
end

function StdioPrintf(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local PrintfArgs = {}

    PrintfArgs.Param = Param
    PrintfArgs.NumArgs = NumArgs - 1
    PrintfArgs.ParamStartStackId = ParamStartStackId

    local NewValue = PointerDereference(Param[1].Val)
    if NewValue == nil then
        ProgramFail(Parser, "parameter 1 of printf() must be a string")
    end

    local Result
    Result = StdioBasePrintf(Parser, Parser.pc.CStdOut, nil, 0,
        PointerGetString(NewValue), PrintfArgs)
    PointerSetSignedOrUnsignedInt(ReturnValue.Val, Result)
end

StdioDefs = "\
typedef struct __va_listStruct va_list; \
typedef struct __FILEStruct FILE; \
"

StdioFunctions = {
    {
        Func = StdioPrintf,
        Prototype = "int printf(char *, ...);"
    },
    {
        Func = nil,
        Prototype = nil
    }
}

function StdioSetupFunc(pc)
    local StructFileType, FilePtrType
    local DummyParser = {}

    DummyParser.pc = pc

    StructFileType = TypeCreateOpaqueStruct(pc, DummyParser,
        TableStrRegister(pc, "__FILEStruct"), 216)

    FilePtrType = TypeGetMatching(pc, DummyParser, StructFileType, BaseType.TypePointer, 0,
        pc.StrEmpty, true)

    TypeCreateOpaqueStruct(pc, DummyParser, TableStrRegister(pc, "__va_listStruct"), 12)

    if not VariableDefined(pc, TableStrRegister(pc, "NULL")) then
        local Stdio_ZeroValue = VariableAllocAnyValue(4)
        VariableDefinePlatformVar(pc, DummyParser, "NULL", pc.IntType,
            Stdio_ZeroValue, false);
    end

    -- To be implemented
end
function StdlibBaseStrToNum(Str)
    local Len = string.len(Str)

    for i = Len, 1, -1 do
        local Span = string.sub(Str, 1, i)
        local Num = tonumber(Span)
        if Num then
            return Num, i
        end
    end

    return 0, 0
end

function StdlibAtof(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local Str = PointerDereference(Param[1].Val)
    if Str == nil then
        ProgramFail(Parser, "argument 1 of atof() must be a string")
    end

    local Val = tonumber(PointerGetString(Str))
    if Val == nil then
        Val = 0
    end

    PointerSetFP(ReturnValue.Val, Val)
end

function StdlibAtoi(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local Str = PointerDereference(Param[1].Val)
    if Str == nil then
        ProgramFail(Parser, "argument 1 of atoi() must be a string")
    end

    local Val = tonumber(PointerGetString(Str))
    if Val == nil then
        Val = 0
    else
        Val = math.floor(Val)
    end

    PointerSetSignedOrUnsignedInt(ReturnValue.Val, Val)
end

function StdlibAtol(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local Str = PointerDereference(Param[1].Val)
    if Str == nil then
        ProgramFail(Parser, "argument 1 of atol() must be a string")
    end

    local Val = tonumber(PointerGetString(Str))
    if Val == nil then
        Val = 0
    else
        Val = math.floor(Val)
    end

    PointerSetSignedOrUnsignedInt(ReturnValue.Val, Val)
end

function StdlibStrtod(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local Str = PointerDereference(Param[1].Val)
    if Str == nil then
        ProgramFail(Parser, "argument 1 of strtod() must be a string")
    end

    local Ptr = PointerDereference(Param[2].Val)

    local Val, Offset = StdlibBaseStrToNum(PointerGetString(Str))
    PointerSetFP(ReturnValue.Val, Val)
    if Ptr then
        PointerCopyPointer(Ptr, Param[1].Val)
        PointerMovePointer(Ptr, Offset)
    end
end

function StdlibStrtol(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local Str = PointerDereference(Param[1].Val)
    if Str == nil then
        ProgramFail(Parser, "argument 1 of strtol() must be a string")
    end

    local Ptr = PointerDereference(Param[2].Val)

    local Val, Offset = StdlibBaseStrToNum(PointerGetString(Str))
    PointerSetSignedOrUnsignedInt(ReturnValue.Val, math.floor(Val))
    if Ptr then
        PointerCopyPointer(Ptr, Param[1].Val)
        PointerMovePointer(Ptr, Offset)
    end
end

function StdlibStrtoul(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    StdlibStrtol(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
end

function StdlibMalloc(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local Length = PointerGetUnsignedInt(Param[1].Val)

    local MemSpace = VariableAllocValueAndData(Parser.pc, Parser, Length, false, nil, true)
    -- Ident > 0x7FFFFFFF for heap value
    MemSpace.Val.Ident = math.random(1, 0x7FFFFFFF) + 0x7FFFFFFF

    PointerReference(ReturnValue.Val, MemSpace.Val)
end

function StdlibCalloc(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local Num = PointerGetUnsignedInt(Param[1].Val)
    local Size = PointerGetUnsignedInt(Param[2].Val)

    local MemSpace = VariableAllocValueAndData(Parser.pc, Parser, Num * Size, false, nil, true)
    MemSpace.Val.Ident = math.random(1, 0x7FFFFFFF) + 0x7FFFFFFF

    PointerReference(ReturnValue.Val, MemSpace.Val)
end

function StdlibRealloc(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local Mem = PointerDereference(Param[1].Val)
    if Mem == nil then
        ProgramFail(Parser, "argument 1 of realloc() must be a valid pointer")
    end

    local Size = PointerGetUnsignedInt(Param[2].Val)

    if Mem.Ident < 0x80000000 then
        ProgramFail(Parser, "invalid pointer: was the memory block created by malloc()?")
    end

    Mem.RawValue.Val = string.rep("\000", Size)
    PointerCopyPointer(ReturnValue.Val, Param[1].Val)
end

function StdlibFree(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local Mem = PointerDereference(Param[1].Val)
    if Mem == nil then
        ProgramFail(Parser, "argument 1 of free() must be a valid pointer")
    end

    if Mem.Ident < 0x80000000 then
        ProgramFail(Parser, "invalid pointer: was the memory block created by malloc()?")
    end

    Mem.RawValue.Val = ""
    PointerCopyPointer(ReturnValue.Val, Param[1].Val)
end

function StdlibRand(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    PointerSetSignedOrUnsignedInt(ReturnValue.Val, math.random(0x7FFFFFFF))
end

function StdlibAbort(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    ProgramFail(Parser, "abort")
end

function StdlibExit(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local RetVal = PointerGetSignedInt(Param[1].Val)

    PlatformExit(Parser.pc, RetVal)
end

function StdlibAbs(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local Value = PointerGetSignedInt(Param[1].Val)

    PointerSetSignedOrUnsignedInt(ReturnValue.Val, math.abs(Value))
end

function StdlibLabs(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    StdlibAbs(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
end

StdlibFunctions = {
    {
        Func = StdlibAtof,
        Prototype = "float atof(char *);"
    },
    {
        Func = StdlibStrtod,
        Prototype = "float strtod(char *,char **);"
    },
    {
        Func = StdlibAtoi,
        Prototype = "int atoi(char *);"
    },
    {
        Func = StdlibAtol,
        Prototype = "int atol(char *);"
    },
    {
        Func = StdlibStrtol,
        Prototype = "int strtol(char *,char **,int);"
    },
    {
        Func = StdlibStrtoul,
        Prototype = "int strtoul(char *,char **,int);"
    },
    {
        Func = StdlibMalloc,
        Prototype = "void *malloc(int);"
    },
    {
        Func = StdlibCalloc,
        Prototype = "void *calloc(int,int);"
    },
    {
        Func = StdlibRealloc,
        Prototype = "void *realloc(void *,int);"
    },
    {
        Func = StdlibFree,
        Prototype = "void free(void *);"
    },
    {
        Func = StdlibRand,
        Prototype = "int rand();"
    },
    --{
    --    Func = StdlibSrand,
    --    Prototype = "void srand(int);"
    --},
    {
        Func = StdlibAbort,
        Prototype = "void abort();"
    },
    {
        Func = StdlibExit,
        Prototype = "void exit(int);"
    },
    {
        Func = StdlibAbs,
        Prototype = "int abs(int);"
    },
    {
        Func = StdlibLabs,
        Prototype = "int labs(int);"
    },
    {
        Func = nil,
        Prototype = nil
    }
}

function StdlibSetupFunc(pc)
    local DummyParser = {}
    DummyParser.pc = pc

    if not VariableDefined(pc, TableStrRegister(pc, "NULL")) then
        local Stdio_ZeroValue = VariableAllocAnyValue(4)
        VariableDefinePlatformVar(pc, DummyParser, "NULL", pc.IntType,
            Stdio_ZeroValue, false);
    end
end
function MathSin(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local Val = math.sin(PointerGetFP(Param[1].Val))
    PointerSetFP(ReturnValue.Val, Val)
end

function MathCos(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local Val = math.cos(PointerGetFP(Param[1].Val))
    PointerSetFP(ReturnValue.Val, Val)
end

function MathTan(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local Val = math.tan(PointerGetFP(Param[1].Val))
    PointerSetFP(ReturnValue.Val, Val)
end

function MathAsin(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local Val = math.asin(PointerGetFP(Param[1].Val))
    PointerSetFP(ReturnValue.Val, Val)
end

function MathAcos(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local Val = math.acos(PointerGetFP(Param[1].Val))
    PointerSetFP(ReturnValue.Val, Val)
end

function MathAtan(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local Val = math.atan(PointerGetFP(Param[1].Val))
    PointerSetFP(ReturnValue.Val, Val)
end

function MathAtan2(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local Val = math.atan(PointerGetFP(Param[1].Val),
        PointerGetFP(Param[2].Val))
    PointerSetFP(ReturnValue.Val, Val)
end

function MathSinh(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local Val = math.sinh(PointerGetFP(Param[1].Val))
    PointerSetFP(ReturnValue.Val, Val)
end

function MathCosh(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local Val = math.cosh(PointerGetFP(Param[1].Val))
    PointerSetFP(ReturnValue.Val, Val)
end

function MathTanh(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local Val = math.tanh(PointerGetFP(Param[1].Val))
    PointerSetFP(ReturnValue.Val, Val)
end

function MathExp(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local Val = math.exp(PointerGetFP(Param[1].Val))
    PointerSetFP(ReturnValue.Val, Val)
end

function MathFabs(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local Val = math.abs(PointerGetFP(Param[1].Val))
    PointerSetFP(ReturnValue.Val, Val)
end

function MathFmod(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local Val = math.fmod(PointerGetFP(Param[1].Val),
        PointerGetFP(Param[2].Val))
    PointerSetFP(ReturnValue.Val, Val)
end

function MathFrexp(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local m, e = math.frexp(PointerGetFP(Param[1].Val))
    local Param1 = PointerDereference(Param[2].Val)
    if Param1 ~= nil then
        PointerSetSignedOrUnsignedInt(Param1, e)
    end
    PointerSetFP(ReturnValue.Val, m)
end

function MathLdexp(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local Val = math.ldexp(PointerGetFP(Param[1].Val),
        PointerGetSignedInt(Param[2].Val))
    PointerSetFP(ReturnValue.Val, Val)
end

function MathLog(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local Val = math.log(PointerGetFP(Param[1].Val))
    PointerSetFP(ReturnValue.Val, Val)
end

function MathLog10(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local Val = math.log10(PointerGetFP(Param[1].Val))
    PointerSetFP(ReturnValue.Val, Val)
end

function MathModf(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local i, f = math.modf(PointerGetFP(Param[1].Val))
    local Param1 = PointerDereference(Param[2].Val)
    if Param1 ~= nil then
        PointerSetFP(Param1, i)
    end
    PointerSetFP(ReturnValue.Val, f)
end

function MathPow(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local Val = math.pow(PointerGetFP(Param[1].Val),
        PointerGetFP(Param[2].Val))
    PointerSetFP(ReturnValue.Val, Val)
end

function MathSqrt(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local Val = math.sqrt(PointerGetFP(Param[1].Val))
    PointerSetFP(ReturnValue.Val, Val)
end

function MathRound(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local Val = math.ceil(PointerGetFP(Param[1].Val) - 0.5)
    PointerSetFP(ReturnValue.Val, Val)
end

function MathCeil(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local Val = math.ceil(PointerGetFP(Param[1].Val))
    PointerSetFP(ReturnValue.Val, Val)
end

function MathFloor(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local Val = math.floor(PointerGetFP(Param[1].Val))
    PointerSetFP(ReturnValue.Val, Val)
end

MathFunctions = {
    {
        Func = MathAcos,
        Prototype = "float acos(float);"
    },
    {
        Func = MathAsin,
        Prototype = "float asin(float);"
    },
    {
        Func = MathAtan,
        Prototype = "float atan(float);"
    },
    {
        Func = MathAtan2,
        Prototype = "float atan2(float, float);"
    },
    {
        Func = MathCeil,
        Prototype = "float ceil(float);"
    },
    {
        Func = MathCos,
        Prototype = "float cos(float);"
    },
    {
        Func = MathCosh,
        Prototype = "float cosh(float);"
    },
    {
        Func = MathExp,
        Prototype = "float exp(float);"
    },
    {
        Func = MathFabs,
        Prototype = "float fabs(float);"
    },
    {
        Func = MathFloor,
        Prototype = "float floor(float);"
    },
    {
        Func = MathFmod,
        Prototype = "float fmod(float, float);"
    },
    {
        Func = MathFrexp,
        Prototype = "float frexp(float, int *);"
    },
    {
        Func = MathLdexp,
        Prototype = "float ldexp(float, int);"
    },
    {
        Func = MathLog,
        Prototype = "float log(float);"
    },
    {
        Func = MathLog10,
        Prototype = "float log10(float);"
    },
    {
        Func = MathModf,
        Prototype = "float modf(float, float *);"
    },
    {
        Func = MathPow,
        Prototype = "float pow(float,float);"
    },
    {
        Func = MathRound,
        Prototype = "float round(float);"
    },
    {
        Func = MathSin,
        Prototype = "float sin(float);"
    },
    {
        Func = MathSinh,
        Prototype = "float sinh(float);"
    },
    {
        Func = MathSqrt,
        Prototype = "float sqrt(float);"
    },
    {
        Func = MathTan,
        Prototype = "float tan(float);"
    },
    {
        Func = MathTanh,
        Prototype = "float tanh(float);"
    },
    {
        Func = nil,
        Prototype = nil
    }
}
function StringBaseMemcpy(DestStr, SourceStr, Length, CheckNullCharacter)
    local SourceOffset = SourceStr.Offset
    local DestOffset = DestStr.Offset

    local SrcPos
    if CheckNullCharacter then
        SrcPos = string.find(SourceStr.RawValue.Val, '\0', SourceOffset + 1)
        if SrcPos == nil then
            SrcPos = SourceOffset + Length
        elseif SrcPos - SourceOffset > Length then
            SrcPos = SourceOffset + Length
        end
    else
        SrcPos = SourceOffset + Length
    end

    local SourceText = string.sub(SourceStr.RawValue.Val, SourceOffset + 1, SrcPos)
    if string.len(SourceText) < Length then
        SourceText = SourceText .. string.rep("\0", Length - string.len(SourceText))
    end

    local DestText = string.sub(DestStr.RawValue.Val, 1, DestOffset) ..
        SourceText .. string.sub(DestStr.RawValue.Val, DestOffset + string.len(SourceText) + 1)
    DestText = string.sub(DestText, 1, string.len(DestStr.RawValue.Val))

    DestStr.RawValue.Val = DestText
end

function StringBaseMemcmp(Str1, Str2, Length, CheckNullCharacter)
    local Offset1 = Str1.Offset
    local Offset2 = Str2.Offset

    for i = 1, Length do
        local c1 = string.sub(Str1.RawValue.Val, Offset1 + i, Offset1 + i)
        local c2 = string.sub(Str2.RawValue.Val, Offset2 + i, Offset2 + i)

        if CheckNullCharacter and (c1 == '\0' or c2 == '\0') then
            break
        elseif c1 == '' or c2 == '' then
            break
        end

        if c1 > c2 then
            return 1
        elseif c1 < c2 then
            return -1
        end
    end

    return 0
end

function StringBaseStrcat(DestStr, SourceStr, Length)
    local SourceOffset = SourceStr.Offset
    local DestOffset = DestStr.Offset

    local ConcatText = string.sub(DestStr.RawValue.Val, DestOffset + 1,
        DestOffset + PointerStringLen(DestStr)) ..
        string.sub(SourceStr.RawValue.Val, SourceOffset + 1,
        SourceOffset + MIN(PointerStringLen(SourceStr), Length)) .. '\0'
    local DestText = string.sub(DestStr.RawValue.Val, 1, DestOffset) .. ConcatText ..
        string.sub(DestStr.RawValue.Val, DestOffset + string.len(ConcatText) + 1)
    DestText = string.sub(DestText, 1, string.len(DestStr.RawValue.Val))

    DestStr.RawValue.Val = DestText
end

function StringBaseStrstr(SourceStr, ValueText, Size, ReverseFind)
    local SourceOffset = SourceStr.Offset

    local FindText = string.sub(SourceStr.RawValue.Val, 1 + SourceOffset, Size + SourceOffset)
    if string.len(FindText) < Size then
        FindText = FindText .. string.rep('\0', Size - string.len(FindText))
    end
    local Pos
    if not ReverseFind then
        Pos = string.find(FindText, ValueText)
    else
        Pos = string.find(string.reverse(FindText), ValueText)
        if Pos then
            Pos = string.len(FindText) - Pos + 1
        end
    end

    return Pos
end

function StringBaseStrspn(Str1, Str2)
    local Text1 = PointerGetString(Str1)
    local Text2 = PointerGetString(Str2)

    local i = 0
    for c1 in string.gmatch(Text1, ".") do
        local Ok = false
        for c2 in string.gmatch(Text2, ".") do
            if c1 == c2 then
                Ok = true
                break
            end
        end
        if not Ok then
            return i
        end
        i = i + 1
    end

    return 0
end

function StringBaseStrcspn(Str1, Str2, NilIfNotFound)
    local Text1 = PointerGetString(Str1)
    local Text2 = PointerGetString(Str2)

    local i = 0
    for c1 in string.gmatch(Text1, ".") do
        for c2 in string.gmatch(Text2, ".") do
            if c1 == c2 then
                return i
            end
        end
        i = i + 1
    end

    if not NilIfNotFound then
        return 0
    else
        return nil
    end
end

-------------------

function StringStrcpy(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local DestStr = PointerDereference(Param[1].Val)
    if DestStr == nil then
        ProgramFail(Parser, "argument 1 of strcpy() must be a string")
    end

    local SourceStr = PointerDereference(Param[2].Val)
    if SourceStr == nil then
        ProgramFail(Parser, "argument 2 of strcpy() must be a string")
    end

    local SourceOffset = SourceStr.Offset
    local DestOffset = DestStr.Offset

    local SrcPos = string.find(SourceStr.RawValue.Val, '\0', SourceOffset + 1)
    local SourceText = string.sub(SourceStr.RawValue.Val, SourceOffset + 1, SrcPos)
    if SrcPos == nil then
        SourceText = SourceText .. "\0"
    end

    local DestText = string.sub(DestStr.RawValue.Val, 1, DestOffset) ..
        SourceText .. string.sub(DestStr.RawValue.Val, DestOffset + string.len(SourceText) + 1)
    DestText = string.sub(DestText, 1, string.len(DestStr.RawValue.Val))

    DestStr.RawValue.Val = DestText
    PointerCopyPointer(ReturnValue.Val, Param[1].Val)
end

function StringStrncpy(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local DestStr = PointerDereference(Param[1].Val)
    if DestStr == nil then
        ProgramFail(Parser, "argument 1 of strncpy() must be a string")
    end

    local SourceStr = PointerDereference(Param[2].Val)
    if SourceStr == nil then
        ProgramFail(Parser, "argument 2 of strncpy() must be a string")
    end

    local Length = PointerGetUnsignedInt(Param[3].Val)

    StringBaseMemcpy(DestStr, SourceStr, Length, true)
    PointerCopyPointer(ReturnValue.Val, Param[1].Val)
end

function StringStrcmp(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local Str1 = PointerDereference(Param[1].Val)
    if Str1 == nil then
        ProgramFail(Parser, "argument 1 of strcmp() must be a string")
    end

    local Str2 = PointerDereference(Param[2].Val)
    if Str2 == nil then
        ProgramFail(Parser, "argument 2 of strcmp() must be a string")
    end

    local Result = StringBaseMemcmp(Str1, Str2, MIN(PointerStringLen(Str1), PointerStringLen(Str2)), true)
    PointerSetSignedOrUnsignedInt(ReturnValue.Val, Result)
end

function StringStrncmp(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local Str1 = PointerDereference(Param[1].Val)
    if Str1 == nil then
        ProgramFail(Parser, "argument 1 of strncmp() must be a string")
    end

    local Str2 = PointerDereference(Param[2].Val)
    if Str2 == nil then
        ProgramFail(Parser, "argument 2 of strncmp() must be a string")
    end

    local Length = PointerGetUnsignedInt(Param[3].Val)

    local Result = StringBaseMemcmp(Str1, Str2, Length, true)
    PointerSetSignedOrUnsignedInt(ReturnValue.Val, Result)
end

function StringStrcat(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local DestStr = PointerDereference(Param[1].Val)
    if DestStr == nil then
        ProgramFail(Parser, "argument 1 of strncat() must be a string")
    end

    local SourceStr = PointerDereference(Param[2].Val)
    if SourceStr == nil then
        ProgramFail(Parser, "argument 2 of strncat() must be a string")
    end

    StringBaseStrcat(DestStr, SourceStr, PointerStringLen(SourceStr))
    PointerCopyPointer(ReturnValue.Val, Param[1].Val)
end

function StringStrncat(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local DestStr = PointerDereference(Param[1].Val)
    if DestStr == nil then
        ProgramFail(Parser, "argument 1 of strncat() must be a string")
    end

    local SourceStr = PointerDereference(Param[2].Val)
    if SourceStr == nil then
        ProgramFail(Parser, "argument 2 of strncat() must be a string")
    end

    local Length = PointerGetUnsignedInt(Param[3].Val)

    StringBaseStrcat(DestStr, SourceStr, Length)
    PointerCopyPointer(ReturnValue.Val, Param[1].Val)
end

function StringStrlen(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local SourceStr = PointerDereference(Param[1].Val)
    if SourceStr == nil then
        ProgramFail(Parser, "argument 1 of strlen() must be a string")
    end

    local Result = PointerStringLen(SourceStr)
    PointerSetSignedOrUnsignedInt(ReturnValue.Val, Result)
end

function StringMemset(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local DestStr = PointerDereference(Param[1].Val)
    if DestStr == nil then
        ProgramFail(Parser, "argument 1 of memset() must be a valid pointer")
    end

    local Value = PointerGetUnsignedChar(Param[2].Val)
    local Size = PointerGetUnsignedInt(Param[3].Val)

    local DestOffset = DestStr.Offset

    local DestText = string.sub(DestStr.RawValue.Val, 1, DestOffset) ..
        string.rep(string.char(Value), Size) ..
        string.sub(DestStr.RawValue.Val, DestOffset + Size + 1)
    DestText = string.sub(DestText, 1, string.len(DestStr.RawValue.Val))

    DestStr.RawValue.Val = DestText
    PointerCopyPointer(ReturnValue.Val, Param[1].Val)
end

function StringMemcpy(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local DestStr = PointerDereference(Param[1].Val)
    if DestStr == nil then
        ProgramFail(Parser, "argument 1 of memcpy() must be a valid pointer")
    end

    local SourceStr = PointerDereference(Param[2].Val)
    if SourceStr == nil then
        ProgramFail(Parser, "argument 2 of memcpy() must be a valid pointer")
    end

    local Length = PointerGetUnsignedInt(Param[3].Val)

    StringBaseMemcpy(DestStr, SourceStr, Length, false)
    PointerCopyPointer(ReturnValue.Val, Param[1].Val)
end

function StringMemcmp(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local Str1 = PointerDereference(Param[1].Val)
    if Str1 == nil then
        ProgramFail(Parser, "argument 1 of memcmp() must be a valid pointer")
    end

    local Str2 = PointerDereference(Param[2].Val)
    if Str2 == nil then
        ProgramFail(Parser, "argument 2 of memcmp() must be a valid pointer")
    end

    local Length = PointerGetUnsignedInt(Param[3].Val)

    local Result = StringBaseMemcmp(Str1, Str2, Length, false)
    PointerSetSignedOrUnsignedInt(ReturnValue.Val, Result)
end

function StringMemmove(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    StringMemcpy(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
end

function StringMemchr(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local SourceStr = PointerDereference(Param[1].Val)
    if SourceStr == nil then
        ProgramFail(Parser, "argument 1 of memchr() must be a valid pointer")
    end

    local Value = PointerGetUnsignedChar(Param[2].Val)
    local Size = PointerGetUnsignedInt(Param[3].Val)

    local Pos = StringBaseStrstr(SourceStr, string.char(Value), Size, false)

    if Pos then
        PointerCopyPointer(ReturnValue.Val, Param[1].Val)
        PointerMovePointer(ReturnValue.Val, Pos - 1)
    else
        PointerSetNull(ReturnValue.Val)
    end
end

function StringStrchr(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local SourceStr = PointerDereference(Param[1].Val)
    if SourceStr == nil then
        ProgramFail(Parser, "argument 1 of strchr() must be a string")
    end

    local Value = PointerGetUnsignedChar(Param[2].Val)

    local Pos = StringBaseStrstr(SourceStr, string.char(Value),
        PointerStringLen(SourceStr) + 1, false)

    if Pos then
        PointerCopyPointer(ReturnValue.Val, Param[1].Val)
        PointerMovePointer(ReturnValue.Val, Pos - 1)
    else
        PointerSetNull(ReturnValue.Val)
    end
end

function StringStrrchr(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local SourceStr = PointerDereference(Param[1].Val)
    if SourceStr == nil then
        ProgramFail(Parser, "argument 1 of strrchr() must be a string")
    end

    local Value = PointerGetUnsignedChar(Param[2].Val)

    local Pos = StringBaseStrstr(SourceStr, string.char(Value),
        PointerStringLen(SourceStr) + 1, true)

    if Pos then
        PointerCopyPointer(ReturnValue.Val, Param[1].Val)
        PointerMovePointer(ReturnValue.Val, Pos - 1)
    else
        PointerSetNull(ReturnValue.Val)
    end
end

function StringStrspn(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local Str1 = PointerDereference(Param[1].Val)
    if Str1 == nil then
        ProgramFail(Parser, "argument 1 of strspn() must be a string")
    end

    local Str2 = PointerDereference(Param[2].Val)
    if Str2 == nil then
        ProgramFail(Parser, "argument 2 of strspn() must be a string")
    end

    local Result = StringBaseStrspn(Str1, Str2)
    PointerSetSignedOrUnsignedInt(ReturnValue.Val, Result)
end

function StringStrcspn(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local Str1 = PointerDereference(Param[1].Val)
    if Str1 == nil then
        ProgramFail(Parser, "argument 1 of strspn() must be a string")
    end

    local Str2 = PointerDereference(Param[2].Val)
    if Str2 == nil then
        ProgramFail(Parser, "argument 2 of strspn() must be a string")
    end

    local Result = StringBaseStrcspn(Str1, Str2, false)
    PointerSetSignedOrUnsignedInt(ReturnValue.Val, Result)
end

function StringStrpbrk(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local Str1 = PointerDereference(Param[1].Val)
    if Str1 == nil then
        ProgramFail(Parser, "argument 1 of strspn() must be a string")
    end

    local Str2 = PointerDereference(Param[2].Val)
    if Str2 == nil then
        ProgramFail(Parser, "argument 2 of strspn() must be a string")
    end

    local Pos = StringBaseStrcspn(Str1, Str2, true)
    if Pos then
        PointerCopyPointer(ReturnValue.Val, Param[1].Val)
        PointerMovePointer(ReturnValue.Val, Pos)
    else
        PointerSetNull(ReturnValue.Val)
    end
end

function StringStrstr(Parser, ReturnValue, Param, NumArgs, ParamStartStackId)
    local SourceStr = PointerDereference(Param[1].Val)
    if SourceStr == nil then
        ProgramFail(Parser, "argument 1 of strstr() must be a string")
    end

    local Value = PointerDereference(Param[2].Val)
    if Value == nil then
        ProgramFail(Parser, "argument 2 of strstr() must be a string")
    end

    local Pos = StringBaseStrstr(SourceStr, PointerGetString(Value),
        PointerStringLen(SourceStr), false)

    if Pos then
        PointerCopyPointer(ReturnValue.Val, Param[1].Val)
        PointerMovePointer(ReturnValue.Val, Pos - 1)
    else
        PointerSetNull(ReturnValue.Val)
    end
end

StringFunctions = {
    {
        Func = StringMemcpy,
        Prototype = "void *memcpy(void *,void *,int);"
    },
    {
        Func = StringMemmove,
        Prototype = "void *memmove(void *,void *,int);"
    },
    {
        Func = StringMemchr,
        Prototype = "void *memchr(char *,int,int);"
    },
    {
        Func = StringMemcmp,
        Prototype = "int memcmp(void *,void *,int);"
    },
    {
        Func = StringMemset,
        Prototype = "void *memset(void *,int,int);"
    },
    {
        Func = StringStrcat,
        Prototype = "char *strcat(char *,char *);"
    },
    {
        Func = StringStrncat,
        Prototype = "char *strncat(char *,char *,int);"
    },
    {
        Func = StringStrchr,
        Prototype = "char *strchr(char *,int);"
    },
    {
        Func = StringStrrchr,
        Prototype = "char *strrchr(char *,int);"
    },
    {
        Func = StringStrcmp,
        Prototype = "int strcmp(char *,char *);"
    },
    {
        Func = StringStrncmp,
        Prototype = "int strncmp(char *,char *,int);"
    },
    {
        Func = StringStrcpy,
        Prototype = "char *strcpy(char *,char *);"
    },
    {
        Func = StringStrncpy,
        Prototype = "char *strncpy(char *,char *,int);"
    },
    {
        Func = StringStrlen, 
        Prototype = "int strlen(char *);"
    },
    {
        Func = StringStrspn,
        Prototype = "int strspn(char *,char *);"
    },
    {
        Func = StringStrcspn,
        Prototype = "int strcspn(char *,char *);"
    },
    {
        Func = StringStrpbrk,
        Prototype = "char *strpbrk(char *,char *);"
    },
    {
        Func = StringStrstr,
        Prototype = "char *strstr(char *,char *);"
    },
    --{
    --    Func = StringStrtok,
    --    Prototype = "char *strtok(char *,char *);"
    --},
    {
        Func = nil,
        Prototype = nil
    }
}

function StringSetupFunc(pc)
    local DummyParser = {}
    DummyParser.pc = pc

    if not VariableDefined(pc, TableStrRegister(pc, "NULL")) then
        local Stdio_ZeroValue = VariableAllocAnyValue(4)
        VariableDefinePlatformVar(pc, DummyParser, "NULL", pc.IntType,
            Stdio_ZeroValue, false);
    end
end
BRACKET_PRECEDENCE = 20
DEEP_PRECEDENCE = BRACKET_PRECEDENCE * 1000

function IS_LEFT_TO_RIGHT(p)
    return (p ~= 2) and (p ~= 14)
end

-- enum OperatorOrder
OperatorOrder = {
    OrderNone = 1,
    OrderPrefix = 2,
    OrderInfix = 3,
    OrderPostfix = 4
}

OperatorPrecedence = {
    -- TokenNone
    {
        PrefixPrecedence = 0,
        PostfixPrecedence = 0,
        InfixPrecedence = 0,
        Name = "none",
    },
    -- TokenComma
    {
        PrefixPrecedence = 0,
        PostfixPrecedence = 0,
        InfixPrecedence = 0,
        Name = ",",
    },
    -- TokenAssign
    {
        PrefixPrecedence = 0,
        PostfixPrecedence = 0,
        InfixPrecedence = 2,
        Name = "=",
    },
    -- TokenAddAssign
    {
        PrefixPrecedence = 0,
        PostfixPrecedence = 0,
        InfixPrecedence = 2,
        Name = "+=",
    },
    -- TokenSubtractAssign
    {
        PrefixPrecedence = 0,
        PostfixPrecedence = 0,
        InfixPrecedence = 2,
        Name = "-=",
    },
    -- TokenMultiplyAssign
    {
        PrefixPrecedence = 0,
        PostfixPrecedence = 0,
        InfixPrecedence = 2,
        Name = "*=",
    },
    -- TokenDivideAssign
    {
        PrefixPrecedence = 0,
        PostfixPrecedence = 0,
        InfixPrecedence = 2,
        Name = "/=",
    },
    -- TokenModulusAssign
    {
        PrefixPrecedence = 0,
        PostfixPrecedence = 0,
        InfixPrecedence = 2,
        Name = "%=",
    },
    -- TokenShiftLeftAssign
    {
        PrefixPrecedence = 0,
        PostfixPrecedence = 0,
        InfixPrecedence = 2,
        Name = "<<=",
    },
    -- TokenShiftRightAssign
    {
        PrefixPrecedence = 0,
        PostfixPrecedence = 0,
        InfixPrecedence = 2,
        Name = ">>=",
    },
    -- TokenArithmeticAndAssign
    {
        PrefixPrecedence = 0,
        PostfixPrecedence = 0,
        InfixPrecedence = 2,
        Name = "&=",
    },
    -- TokenArithmeticOrAssign
    {
        PrefixPrecedence = 0,
        PostfixPrecedence = 0,
        InfixPrecedence = 2,
        Name = "|=",
    },
    -- TokenArithmeticExorAssign
    {
        PrefixPrecedence = 0,
        PostfixPrecedence = 0,
        InfixPrecedence = 2,
        Name = "^=",
    },
    -- TokenQuestionMark
    {
        PrefixPrecedence = 0,
        PostfixPrecedence = 0,
        InfixPrecedence = 3,
        Name = "?",
    },
    -- TokenColon
    {
        PrefixPrecedence = 0,
        PostfixPrecedence = 0,
        InfixPrecedence = 3,
        Name = ":",
    },
    -- TokenLogicalOr
    {
        PrefixPrecedence = 0,
        PostfixPrecedence = 0,
        InfixPrecedence = 4,
        Name = "||",
    },
    -- TokenLogicalAnd
    {
        PrefixPrecedence = 0,
        PostfixPrecedence = 0,
        InfixPrecedence = 5,
        Name = "&&",
    },
    -- TokenArithmeticOr
    {
        PrefixPrecedence = 0,
        PostfixPrecedence = 0,
        InfixPrecedence = 6,
        Name = "=",
    },
    -- TokenArithmeticExor
    {
        PrefixPrecedence = 0,
        PostfixPrecedence = 0,
        InfixPrecedence = 7,
        Name = "^",
    },
    -- TokenAmpersand
    {
        PrefixPrecedence = 14,
        PostfixPrecedence = 0,
        InfixPrecedence = 8,
        Name = "&",
    },
    -- TokenEqual
    {
        PrefixPrecedence = 0,
        PostfixPrecedence = 0,
        InfixPrecedence = 9,
        Name = "==",
    },
    -- TokenNotEqual
    {
        PrefixPrecedence = 0,
        PostfixPrecedence = 0,
        InfixPrecedence = 9,
        Name = "!=",
    },
    -- TokenLessThan
    {
        PrefixPrecedence = 0,
        PostfixPrecedence = 0,
        InfixPrecedence = 10,
        Name = "<",
    },
    -- TokenGreaterThan
    {
        PrefixPrecedence = 0,
        PostfixPrecedence = 0,
        InfixPrecedence = 10,
        Name = ">",
    },
    -- TokenLessEqual
    {
        PrefixPrecedence = 0,
        PostfixPrecedence = 0,
        InfixPrecedence = 10,
        Name = "<=",
    },
    -- TokenGreaterEqual
    {
        PrefixPrecedence = 0,
        PostfixPrecedence = 0,
        InfixPrecedence = 10,
        Name = ">=",
    },
    -- TokenShiftLeft
    {
        PrefixPrecedence = 0,
        PostfixPrecedence = 0,
        InfixPrecedence = 11,
        Name = "<<",
    },
    -- TokenShiftRight
    {
        PrefixPrecedence = 0,
        PostfixPrecedence = 0,
        InfixPrecedence = 11,
        Name = ">>",
    },
    -- TokenPlus
    {
        PrefixPrecedence = 14,
        PostfixPrecedence = 0,
        InfixPrecedence = 12,
        Name = "+",
    },
    -- TokenMinus
    {
        PrefixPrecedence = 14,
        PostfixPrecedence = 0,
        InfixPrecedence = 12,
        Name = "-",
    },
    -- TokenAsterisk
    {
        PrefixPrecedence = 14,
        PostfixPrecedence = 0,
        InfixPrecedence = 13,
        Name = "*",
    },
    -- TokenSlash
    {
        PrefixPrecedence = 0,
        PostfixPrecedence = 0,
        InfixPrecedence = 13,
        Name = "/",
    },
    -- TokenModulus
    {
        PrefixPrecedence = 0,
        PostfixPrecedence = 0,
        InfixPrecedence = 13,
        Name = "%",
    },
    -- TokenIncrement
    {
        PrefixPrecedence = 14,
        PostfixPrecedence = 15,
        InfixPrecedence = 0,
        Name = "++",
    },
    -- TokenDecrement
    {
        PrefixPrecedence = 14,
        PostfixPrecedence = 15,
        InfixPrecedence = 0,
        Name = "--",
    },
    -- TokenUnaryNot
    {
        PrefixPrecedence = 14,
        PostfixPrecedence = 0,
        InfixPrecedence = 0,
        Name = "!",
    },
    -- TokenUnaryExor
    {
        PrefixPrecedence = 14,
        PostfixPrecedence = 0,
        InfixPrecedence = 0,
        Name = "~",
    },
    -- TokenSizeof
    {
        PrefixPrecedence = 14,
        PostfixPrecedence = 0,
        InfixPrecedence = 0,
        Name = "sizeof",
    },
    -- TokenCast
    {
        PrefixPrecedence = 14,
        PostfixPrecedence = 0,
        InfixPrecedence = 0,
        Name = "cast",
    },
    -- TokenLeftSquareBracket
    {
        PrefixPrecedence = 0,
        PostfixPrecedence = 0,
        InfixPrecedence = 15,
        Name = "[",
    },
    -- TokenRightSquareBracket
    {
        PrefixPrecedence = 0,
        PostfixPrecedence = 15,
        InfixPrecedence = 0,
        Name = "]",
    },
    -- TokenDot
    {
        PrefixPrecedence = 0,
        PostfixPrecedence = 0,
        InfixPrecedence = 15,
        Name = ".",
    },
    -- TokenArrow
    {
        PrefixPrecedence = 0,
        PostfixPrecedence = 0,
        InfixPrecedence = 15,
        Name = "->",
    },
    -- TokenOpenBracket
    {
        PrefixPrecedence = 15,
        PostfixPrecedence = 0,
        InfixPrecedence = 0,
        Name = "(",
    },
    -- TokenCloseBracket
    {
        PrefixPrecedence = 0,
        PostfixPrecedence = 15,
        InfixPrecedence = 0,
        Name = ")",
    },
}

function IsTypeToken(Parser, t, LexValue)
    local VarValue

    if t >= LexToken.TokenIntType and t <= LexToken.TokenUnsignedType then
        return true
    end

    if t == LexToken.TokenIdentifier then
        if VariableDefined(Parser.pc, LexValue.Val) then
            VarValue = VariableGet(Parser.pc, Parser, LexValue.Val)
            if VarValue.Typ == Parser.pc.TypeType then
                return true
            end
        end
    end

    return false
end

function ExpressionCoerceInteger(Val)
    if Val.Typ.Base == BaseType.TypeInt then
        return PointerGetSignedInt(Val.Val)
    elseif Val.Typ.Base == BaseType.TypeUnsignedInt then
        return PointerGetUnsignedInt(Val.Val)
    elseif Val.Typ.Base == BaseType.TypeChar then
        return PointerGetSignedChar(Val.Val)
    elseif Val.Typ.Base == BaseType.TypeUnsignedChar then
        return PointerGetUnsignedChar(Val.Val)
    elseif Val.Typ.Base == BaseType.TypeShort then
        return PointerGetSignedShort(Val.Val)
    elseif Val.Typ.Base == BaseType.TypeUnsignedShort then
        return PointerGetUnsignedShort(Val.Val)
    elseif Val.Typ.Base == BaseType.TypeLong then
        return PointerGetSignedInt(Val.Val)
    elseif Val.Typ.Base == BaseType.TypeUnsignedLong then
        return PointerGetUnsignedInt(Val.Val)
    elseif Val.Typ.Base == BaseType.TypePointer then
        -- Getting the absolute address of a pointer is not supported
        -- If pointer is not null, cast a dummy address
        if IsPointerNull(Val.Val) then
            return 0
        else
            return 0xCCCC
        end
    elseif Val.Typ.Base == BaseType.TypeFP then
        return (math.floor(PointerGetFP(Val.Val)) + 0x80000000) % 0x100000000 - 0x80000000
    else
        return 0
    end
end

function ExpressionCoerceUnsignedInteger(Val)
    if Val.Typ.Base == BaseType.TypeInt then
        return PointerGetUnsignedInt(Val.Val)
    elseif Val.Typ.Base == BaseType.TypeUnsignedInt then
        return PointerGetUnsignedInt(Val.Val)
    elseif Val.Typ.Base == BaseType.TypeChar then
        return PointerGetUnsignedChar(Val.Val)
    elseif Val.Typ.Base == BaseType.TypeUnsignedChar then
        return PointerGetUnsignedChar(Val.Val)
    elseif Val.Typ.Base == BaseType.TypeShort then
        return PointerGetUnsignedShort(Val.Val)
    elseif Val.Typ.Base == BaseType.TypeUnsignedShort then
        return PointerGetUnsignedShort(Val.Val)
    elseif Val.Typ.Base == BaseType.TypeLong then
        return PointerGetUnsignedInt(Val.Val)
    elseif Val.Typ.Base == BaseType.TypeUnsignedLong then
        return PointerGetUnsignedInt(Val.Val)
    elseif Val.Typ.Base == BaseType.TypePointer then
        -- Getting the absolute address of a pointer is not supported
        -- If pointer is not null, cast a dummy address
        if IsPointerNull(Val.Val) then
            return 0
        else
            return 0xCCCC
        end
    elseif Val.Typ.Base == BaseType.TypeFP then
        return math.floor(PointerGetFP(Val.Val)) % 0x100000000
    else
        return 0
    end
end

function ExpressionCoerceFP(Val)
    if Val.Typ.Base == BaseType.TypeInt then
        return PointerGetSignedInt(Val.Val)
    elseif Val.Typ.Base == BaseType.TypeUnsignedInt then
        return PointerGetUnsignedInt(Val.Val)
    elseif Val.Typ.Base == BaseType.TypeChar then
        return PointerGetSignedChar(Val.Val)
    elseif Val.Typ.Base == BaseType.TypeUnsignedChar then
        return PointerGetUnsignedChar(Val.Val)
    elseif Val.Typ.Base == BaseType.TypeShort then
        return PointerGetSignedShort(Val.Val)
    elseif Val.Typ.Base == BaseType.TypeUnsignedShort then
        return PointerGetUnsignedShort(Val.Val)
    elseif Val.Typ.Base == BaseType.TypeLong then
        return PointerGetSignedInt(Val.Val)
    elseif Val.Typ.Base == BaseType.TypeUnsignedLong then
        return PointerGetUnsignedInt(Val.Val)
    elseif Val.Typ.Base == BaseType.TypeFP then
        return PointerGetFP(Val.Val)
    else
        return 0
    end
end

function ExpressionAssignInt(Parser, DestValue, FromInt, After)
    local Result

    if not DestValue.IsLValue then
        ProgramFail(Parser, "can't assign to this")
    end

    if After then
        Result = ExpressionCoerceInteger(DestValue)
    else
        Result = FromInt
    end

    if (DestValue.Typ.Base == BaseType.TypeInt or
        DestValue.Typ.Base == BaseType.TypeUnsignedInt) then
        PointerSetSignedOrUnsignedInt(DestValue.Val, FromInt)
    elseif (DestValue.Typ.Base == BaseType.TypeChar or
        DestValue.Typ.Base == BaseType.TypeUnsignedChar) then
        PointerSetSignedOrUnsignedChar(DestValue.Val, FromInt)
    elseif (DestValue.Typ.Base == BaseType.TypeShort or
        DestValue.Typ.Base == BaseType.TypeUnsignedShort) then
        PointerSetSignedOrUnsignedShort(DestValue.Val, FromInt)
    elseif (DestValue.Typ.Base == BaseType.TypeLong or
        DestValue.Typ.Base == BaseType.TypeUnsignedLong) then
        PointerSetSignedOrUnsignedInt(DestValue.Val, FromInt)
    end
    --if VariableDebug then
    --    print("Variable:", FromInt)
    --end

    return Result
end

function ExpressionAssignFP(Parser, DestValue, FromFP)
    if not DestValue.IsLValue then
        ProgramFail(Parser, "can't assign to this")
    end

    PointerSetFP(DestValue.Val, FromFP)
    --if VariableDebug then
    --    print("Variable:", FromFP)
    --end
    return FromFP
end

function ExpressionStackPushValueNode(Parser, StackTop, ValueLoc)
    local StackNode
    StackNode = VariableAlloc(Parser.pc, Parser, false)
    if StackTop == nil then
        StackNode.NextNodeId = 0
    else
        StackNode.NextNodeId = StackTop.StackId
    end
    StackNode.Val = ValueLoc
    StackNode.Op = LexToken.TokenNone
    StackNode.Precedence = 0
    StackNode.Order = OperatorOrder.OrderNone
    StackTop = StackNode

    -- #ifdef FANCY_ERROR_MESSAGES
    --StackNode.Line = Parser.Line
    --StackNode.CharacterPos = Parser.CharacterPos
    -- #endif

    -- #ifdef DEBUG_EXPRESSIONS
    -- ExpressionStackShow(Parser.pc, StackTop)
    -- #endif

    return StackTop
end

function ExpressionStackPushValueByType(Parser, StackTop, PushType)
    local ValueLoc
    ValueLoc = VariableAllocValueFromType(Parser.pc, Parser,
        PushType, false, nil, false)
    StackTop = ExpressionStackPushValueNode(Parser, StackTop, ValueLoc)
    --if Debug then
    --    print("Set", ValueLoc.Typ.Base)
    --end

    return ValueLoc, StackTop
end

function ExpressionStackPushValue(Parser, StackTop, PushValue)
    local ValueLoc = VariableAllocValueAndCopy(Parser.pc, Parser,
        PushValue, false)
    StackTop = ExpressionStackPushValueNode(Parser, StackTop, ValueLoc)

    return StackTop
end

function ExpressionStackPushLValue(Parser, StackTop, PushValue, Offset)
    local ValueLoc = VariableAllocValueShared(Parser, PushValue)
    StackTop = ExpressionStackPushValueNode(Parser, StackTop, ValueLoc)

    return StackTop
end

function ExpressionStackPushDereference(Parser, StackTop, DereferenceValue)
    local DerefIsLValue, DerefVal, ValueLoc, DerefType
    local DerefDataLoc
    DerefDataLoc, DerefVal, DerefType, _, DerefIsLValue =
        VariableDereferencePointer(DereferenceValue)
    --print("Dereference:", DerefType.Base)
    if DerefDataLoc == nil then
        ProgramFail(Parser, "trying to dereference a void pointer - is the pointer NULL or pointing to a deallocated variable?")
    end

    ValueLoc = VariableAllocValueFromExistingData(Parser, DerefType,
        DerefDataLoc, DerefIsLValue, DerefVal)
    StackTop = ExpressionStackPushValueNode(Parser, StackTop, ValueLoc)
    return StackTop
end

function ExpressionPushInt(Parser, StackTop, IntValue)
    local ValueLoc = VariableAllocValueFromType(Parser.pc, Parser,
        Parser.pc.IntType, false, nil, false)
    PointerSetSignedOrUnsignedInt(ValueLoc.Val, IntValue)

    StackTop = ExpressionStackPushValueNode(Parser, StackTop, ValueLoc)
    return StackTop
end

function ExpressionPushFP(Parser, StackTop, FPValue)
    local ValueLoc = VariableAllocValueFromType(Parser.pc, Parser,
        Parser.pc.FPType, false, nil, false)
    PointerSetFP(ValueLoc.Val, FPValue)

    StackTop = ExpressionStackPushValueNode(Parser, StackTop, ValueLoc)
    return StackTop
end

function ExpressionAssignToPointer(Parser, ToValue, FromValue, FuncName, ParamNo, AllowPointerCoercion)
    local PointedToType = ToValue.Typ.FromType

    if (FromValue.Typ == ToValue.Typ or
        FromValue.Typ == Parser.pc.VoidPtrType or
        (ToValue.Typ == Parser.pc.VoidPtrType and
        FromValue.Typ.Base == BaseType.TypePointer)) then
        PointerCopyPointer(ToValue.Val, FromValue.Val)
    elseif (FromValue.Typ.Base == BaseType.TypeArray and
        (PointedToType == FromValue.Typ.FromType or
        ToValue.Typ == Parser.pc.VoidPtrType)) then
        PointerReference(ToValue.Val, FromValue.Val)
        --print("CoercePointer:", PointerGetSignedInt(ToValue.Val))
    elseif (FromValue.Typ.Base == BaseType.TypePointer and
        FromValue.Typ.FromType.Base == BaseType.TypeArray and
        (PointedToType == FromValue.Typ.FromType.FromType or
        ToValue.Typ == Parser.pc.VoidPtrType)) then
        PointerCopyPointer(ToValue.Val, FromValue.Val)
    elseif (IS_NUMERIC_COERCIBLE(FromValue) and
        ExpressionCoerceInteger(FromValue) == 0) then
        PointerSetNull(ToValue.Val)
    elseif AllowPointerCoercion and IS_NUMERIC_COERCIBLE(FromValue) then
        -- Assigning absolute address is not supported:
        -- There is no real address space!
        ProgramFail(Parser, "assigning absolute address to pointer is not supported")
    elseif AllowPointerCoercion and FromValue.Typ.Base == BaseType.TypePointer then
        PointerCopyPointer(ToValue.Val, FromValue.Val)
    else
        AssignFail(Parser, "%t from %t", ToValue.Typ, FromValue.Typ, 0, 0,
            FuncName, ParamNo)
    end
end

function ExpressionAssign(Parser, DestValue, SourceValue, Force, FuncName, ParamNo, AllowPointerCoercion)
    if not DestValue.IsLValue and not Force then
        AssignFail(Parser, "not an lvalue", nil, nil, 0, 0, FuncName, ParamNo)
    end

    if (IS_NUMERIC_COERCIBLE(DestValue) and
        not IS_NUMERIC_COERCIBLE_PLUS_POINTERS(SourceValue, AllowPointerCoercion)) then
        AssignFail(Parser, "%t from %t", DestValue.Typ, SourceValue.Typ, 0, 0,
            FuncName, ParamNo)
    end

    if DestValue.Typ.Base == BaseType.TypeInt then
        --if VariableDebug then
        --    print("Variable:", ExpressionCoerceInteger(SourceValue))
        --end
        PointerSetSignedOrUnsignedInt(DestValue.Val, ExpressionCoerceInteger(SourceValue))
    elseif DestValue.Typ.Base == BaseType.TypeShort then
        --if VariableDebug then
        --    print("Variable:", ExpressionCoerceInteger(SourceValue))
        --end
        PointerSetSignedOrUnsignedShort(DestValue.Val, ExpressionCoerceInteger(SourceValue))
    elseif DestValue.Typ.Base == BaseType.TypeChar then
        --if VariableDebug then
        --    print("Variable:", ExpressionCoerceInteger(SourceValue))
        --end
        PointerSetSignedOrUnsignedChar(DestValue.Val, ExpressionCoerceInteger(SourceValue))
    elseif DestValue.Typ.Base == BaseType.TypeLong then
        --if VariableDebug then
        --    print("Variable:", ExpressionCoerceInteger(SourceValue))
        --end
        PointerSetSignedOrUnsignedInt(DestValue.Val, ExpressionCoerceInteger(SourceValue))
    elseif DestValue.Typ.Base == BaseType.TypeUnsignedInt then
        --if VariableDebug then
        --    print("Variable:", ExpressionCoerceInteger(SourceValue))
        --end
        PointerSetSignedOrUnsignedInt(DestValue.Val, ExpressionCoerceUnsignedInteger(SourceValue))
    elseif DestValue.Typ.Base == BaseType.TypeUnsignedShort then
        --if VariableDebug then
        --    print("Variable:", ExpressionCoerceInteger(SourceValue))
        --end
        PointerSetSignedOrUnsignedShort(DestValue.Val, ExpressionCoerceUnsignedInteger(SourceValue))
    elseif DestValue.Typ.Base == BaseType.TypeUnsignedLong then
        --if VariableDebug then
        --    print("Variable:", ExpressionCoerceInteger(SourceValue))
        --end
        PointerSetSignedOrUnsignedInt(DestValue.Val, ExpressionCoerceUnsignedInteger(SourceValue))
    elseif DestValue.Typ.Base == BaseType.TypeUnsignedChar then
        --if VariableDebug then
        --    print("Variable:", ExpressionCoerceInteger(SourceValue))
        --end
        PointerSetSignedOrUnsignedChar(DestValue.Val, ExpressionCoerceInteger(SourceValue))
    elseif DestValue.Typ.Base == BaseType.TypeFP then
        --if VariableDebug then
        --    print("Variable:", ExpressionCoerceFP(SourceValue))
        --end
        if not IS_NUMERIC_COERCIBLE_PLUS_POINTERS(SourceValue, AllowPointerCoercion) then
            AssignFail(Parser, "%t from %t", DestValue.Typ, SourceValue.Typ, 0, 0,
                FuncName, ParamNo)
        end
        PointerSetFP(DestValue.Val, ExpressionCoerceFP(SourceValue))
    elseif DestValue.Typ.Base == BaseType.TypePointer then
        ExpressionAssignToPointer(Parser, DestValue, SourceValue, FuncName,
            ParamNo, AllowPointerCoercion)
    elseif DestValue.Typ.Base == BaseType.TypeArray then
        local DerefVal, Size

        if (SourceValue.Typ.Base == BaseType.TypeArray and
            DestValue.Typ.ArraySize == 0) then
            DestValue.Typ = SourceValue.Typ
            VariableRealloc(Parser, DestValue, TypeSizeValue(DestValue, false))

            if DestValue.LValueFrom ~= nil then
                DestValue.LValueFrom.Val = DestValue.Val
                DestValue.LValueFrom.AnyValOnHeap = DestValue.AnyValOnHeap
            end
        end

        if (DestValue.Typ.FromType.Base == BaseType.TypeChar and
            SourceValue.Typ.Base == BaseType.TypePointer and
            SourceValue.Typ.FromType.Base == BaseType.TypeChar) then
            DerefVal = PointerDereference(SourceValue.Val)

            if DestValue.Typ.ArraySize == 0 then
                Size = PointerStringLen(DerefVal)

                DestValue.Typ = TypeGetMatching(Parser.pc, Parser,
                    DestValue.Typ.FromType, DestValue.Typ.Base,
                    Size, DestValue.Typ.Identifier, true)
                VariableRealloc(Parser, DestValue, TypeSizeValue(DestValue,
                    false))
            end

            PointerCopyValue(DestValue.Val, DerefVal, DestValue.Typ)
        else
            if DestValue.Typ ~= SourceValue.Typ then
                AssignFail(Parser, "%t from %t", DestValue.Typ, SourceValue.Typ,
                    0, 0, FuncName, ParamNo)
            end

            if DestValue.Typ.ArraySize ~= SourceValue.Typ.ArraySize then
                AssignFail(Parser, "from an array of size %d to one of size %d",
                    nil, nil, DestValue.Typ.ArraySize,
                    SourceValue.Typ.ArraySize, FuncName, ParamNo)
            end

            PointerCopyValue(DestValue.Val, SourceValue.Val, DestValue.Typ)
        end
    elseif (DestValue.Typ.Base == BaseType.TypeStruct or
        DestValue.Typ.Base == BaseType.TypeUnion) then
        if DestValue.Typ ~= SourceValue.Typ then
           AssignFail(Parser, "%t from %t", DestValue.Typ, SourceValue.Typ,
                0, 0, FuncName, ParamNo)
        end
        PointerCopyValue(DestValue.Val, SourceValue.Val, DestValue.Typ)
    else
        AssignFail(Parser, "%t", DestValue.Typ, nil, 0, 0, FuncName, ParamNo)
    end
end

function ExpressionQuestionMarkOperator(Parser, StackTop, BottomValue, TopValue)
    if not IS_NUMERIC_COERCIBLE(TopValue) then
        ProgramFail(Parser, "first argument to '?' should be a number")
    end

    if ExpressionCoerceInteger(TopValue) ~= 0 then
        StackTop = ExpressionStackPushValue(Parser, StackTop, BottomValue)
    else
        _, StackTop = ExpressionStackPushValueByType(Parser, StackTop, Parser.pc.VoidType)
    end

    return StackTop
end

function ExpressionColonOperator(Parser, StackTop, BottomValue, TopValue)
    if TopValue.Typ.Base == BaseType.TypeVoid then
        StackTop = ExpressionStackPushValue(Parser, StackTop, BottomValue)
    else
        StackTop = ExpressionStackPushValue(Parser, StackTop, TopValue)
    end

    return StackTop
end

function ExpressionPrefixOperator(Parser, StackTop, Op, TopValue)
    local Result, Typ
    local ResultFP, ResultInt, TopInt

    if Op == LexToken.TokenAmpersand then
        if not TopValue.IsLValue then
            ProgramFail(Parser, "can't get the address of this")
        end

        Result = VariableAllocValueFromType(Parser.pc, Parser,
            TypeGetMatching(Parser.pc, Parser, TopValue.Typ,
                BaseType.TypePointer, 0, Parser.pc.StrEmpty, true),
            false, nil, false)
        PointerReference(Result.Val, TopValue.Val)

        StackTop = ExpressionStackPushValueNode(Parser, StackTop, Result)
    elseif Op == LexToken.TokenAsterisk then
        if StackTop ~= nil then
            if StackTop.Op == LexToken.TokenSizeof then
                _, StackTop = ExpressionStackPushValueByType(Parser, StackTop, TopValue.Typ)
            else
                StackTop = ExpressionStackPushDereference(Parser, StackTop, TopValue)
            end
        else
            StackTop = ExpressionStackPushDereference(Parser, StackTop, TopValue)
        end
    elseif Op == LexToken.TokenSizeof then
        if TopValue.Typ == Parser.pc.TypeType then
            Typ = TopValue.Val.Typ  -- Val here points to Typ, not AnyValue type
        else
            Typ = TopValue.Typ
        end
        --if Typ.FromType ~= nil then
        --    if Typ.FromType.Base == BaseType.TypeStruct then
        --        Typ = Typ.FromType
        --    end
        --end
        StackTop = ExpressionPushInt(Parser, StackTop, TypeSize(Typ, Typ.ArraySize, true))
    else
        if TopValue.Typ == Parser.pc.FPType then
            ResultFP = 0.0
            if Op == LexToken.TokenPlus then
                ResultFP = PointerGetFP(TopValue.Val)
            elseif Op == LexToken.TokenMinus then
                ResultFP = -PointerGetFP(TopValue.Val)
            elseif Op == LexToken.TokenIncrement then
                ResultFP = ExpressionAssignFP(Parser, TopValue,
                    PointerGetFP(TopValue.Val) + 1)
            elseif Op == LexToken.TokenDecrement then
                ResultFP = ExpressionAssignFP(Parser, TopValue,
                    PointerGetFP(TopValue.Val) - 1)
            elseif Op == LexToken.TokenUnaryNot then
                if PointerGetFP(TopValue.Val) == 0 then
                    ResultFP = 1
                else
                    ResultFP = 0
                end
            else
                ProgramFail(Parser, "invalid operation")
            end
            StackTop = ExpressionPushFP(Parser, StackTop, ResultFP)
        elseif IS_NUMERIC_COERCIBLE(TopValue) then
            ResultInt = 0
            TopInt = 0
            if TopValue.Typ.Base == BaseType.TypeLong then
                TopInt = PointerGetSignedInt(TopValue.Val)
            else
                TopInt = ExpressionCoerceInteger(TopValue)
            end
            if Op == LexToken.TokenPlus then
                ResultInt = TopInt
            elseif Op == LexToken.TokenMinus then
                ResultInt = -TopInt
            elseif Op == LexToken.TokenIncrement then
                ResultInt = ExpressionAssignInt(Parser, TopValue,
                    TopInt + 1, false)
            elseif Op == LexToken.TokenDecrement then
                ResultInt = ExpressionAssignInt(Parser, TopValue,
                    TopInt - 1, false)
            elseif Op == LexToken.TokenUnaryNot then
                if TopInt == 0 then
                    ResultInt = 1
                else
                    ResultInt = 0
                end
            elseif Op == LexToken.TokenUnaryExor then
                ResultInt = bnot(TopInt)
            else
                ProgramFail(Parser, "invalid operation")
            end
            StackTop = ExpressionPushInt(Parser, StackTop, ResultInt)
        elseif TopValue.Typ.Base == BaseType.TypePointer then
            local Size = TypeSize(TopValue.Typ.FromType, 0, true)
            local StackValue

            if Op ~= LexToken.TokenUnaryNot and IsPointerNull(TopValue.Val) then
                ProgramFail(Parser, "a. invalid use of a NULL pointer")
            end
            if not TopValue.IsLValue then
                ProgramFail(Parser, "can't assign to this")
            end
            if Op == LexToken.TokenIncrement then
                PointerMovePointer(TopValue.Val, Size)
            elseif Op == LexToken.TokenDecrement then
                PointerMovePointer(TopValue.Val, -Size)
            elseif Op == LexToken.TokenUnaryNot then
                if IsPointerNull(TopValue.Val) then
                    StackTop = ExpressionPushInt(Parser, StackTop, 1)
                else
                    StackTop = ExpressionPushInt(Parser, StackTop, 0)
                end
                return StackTop
            else
                ProgramFail(Parser, "invalid operation")
            end

            StackValue, StackTop = ExpressionStackPushValueByType(Parser, StackTop,
                TopValue.Typ)
            StackValue.Val = PointerCopyAllValues(TopValue.Val, true)
        else
            ProgramFail(Parser, "invalid operation")
        end
    end

    return StackTop
end

function ExpressionPostfixOperator(Parser, StackTop, Op, TopValue)
    local ResultFP, ResultInt, TopInt

    if TopValue.Typ == Parser.pc.FPType then
        ResultFP = 0.0

        if Op == LexToken.TokenIncrement then
            ResultFP = ExpressionAssignFP(Parser, TopValue, PointerGetFP(TopValue.Val) + 1)
        elseif Op == LexToken.TokenDecrement then
            ResultFP = ExpressionAssignFP(Parser, TopValue, PointerGetFP(TopValue.Val) - 1)
        else
            ProgramFail(Parser, "invalid operation")
        end
        StackTop = ExpressionPushFP(Parser, StackTop, ResultFP)
    elseif IS_NUMERIC_COERCIBLE(TopValue) then
        ResultInt = 0
        TopInt = ExpressionCoerceInteger(TopValue)
        if Op == LexToken.TokenIncrement then
            ResultInt = ExpressionAssignInt(Parser, TopValue, TopInt + 1, true)
        elseif Op == LexToken.TokenDecrement then
            ResultInt = ExpressionAssignInt(Parser, TopValue, TopInt - 1, true)
        elseif Op == LexToken.TokenRightSquareBracket then
            ProgramFail(Parser, "not supported")
        elseif Op == LexToken.TokenCloseBracket then
            ProgramFail(Parser, "not supported")
        else
            ProgramFail(Parser, "invalid operation")
        end
        StackTop = ExpressionPushInt(Parser, StackTop, ResultInt)
    elseif TopValue.Typ.Base == BaseType.TypePointer then
        local Size = TypeSize(TopValue.Typ.FromType, 0, true)
        local StackValue
        local OrigPointerVal = {}

        if IsPointerNull(TopValue.Val) then
            ProgramFail(Parser, "a. invalid use of a NULL or void pointer")
        end

        if not TopValue.IsLValue then
            ProgramFail(Parser, "can't assign to this")
        end

        OrigPointerVal = PointerCopyAllValues(TopValue.Val, true)

        if Op == LexToken.TokenIncrement then
            PointerMovePointer(TopValue.Val, Size)
        elseif Op == LexToken.TokenDecrement then
            PointerMovePointer(TopValue.Val, -Size)
        else
            ProgramFail(Parser, "invalid operation")
        end

        StackValue, StackTop = ExpressionStackPushValueByType(Parser, StackTop,
            TopValue.Typ)
        StackValue.Val = PointerCopyAllValues(OrigPointerVal, true)
    else
        ProgramFail(Parser, "invalid operation")
    end

    return StackTop
end

function ExpressionInfixOperator(Parser, StackTop, Op, BottomValue, TopValue)
    local NewValue
    local ResultInt, StackValue
    local ArrayIndex, Result
    local ResultIsInt, ResultFP, TopFP, BottomFP
    local TopInt, BottomInt
    local ValueLoc

    if BottomValue == nil or TopValue == nil then
        ProgramFail(Parser, "invalid expression")
    end

    --if Debug then
    --    print("ExpressionInfixOperator Enter", Op, "Position:", Parser.Line, Parser.CharacterPos)
    --end

    if Op == LexToken.TokenLeftSquareBracket then
        --if Debug then
        --    print("Infix ArrayOperation")
        --end
        if not IS_NUMERIC_COERCIBLE(TopValue) then
            ProgramFail(Parser, "array index must be an integer")
        end

        ArrayIndex = ExpressionCoerceInteger(TopValue)

        if BottomValue.Typ.Base == BaseType.TypeArray then
            NewValue = {}
            PointerDeriveNewValue(NewValue, BottomValue.Val, true)
            NewValue.Offset = NewValue.Offset + TypeSize(BottomValue.Typ, ArrayIndex, true)
            --print("Coerce1:", PointerGetSignedInt(NewValue))
            Result = VariableAllocValueFromExistingData(Parser,
                BottomValue.Typ.FromType, NewValue,
                BottomValue.IsLValue, BottomValue.LValueFrom)
            --print("Coerce1:", ArrayIndex, NewValue.Offset)
            --print("Coerce1:", string.len(Result.Val.RawValue.Val))
            --print("Coerce1:", PointerGetSignedInt(Result.Val))
        elseif BottomValue.Typ.Base == BaseType.TypePointer then
            NewValue = PointerCopyAllValues(BottomValue.Val, true)
            PointerMovePointer(NewValue, TypeSize(BottomValue.Typ.FromType, 0, true) * ArrayIndex)
            NewValue = PointerDereference(NewValue)
            if NewValue ~= nil then
                Result = VariableAllocValueFromExistingData(Parser,
                    BottomValue.Typ.FromType, NewValue,
                    BottomValue.IsLValue, BottomValue.LValueFrom)
            else
                ProgramFail(Parser, "trying to dereference a void pointer - is the pointer NULL or pointing to a deallocated variable?")
            end
        else
            ProgramFail(Parser, "this %t is not an array", BottomValue.Typ)
        end

        StackTop = ExpressionStackPushValueNode(Parser, StackTop, Result)
    elseif Op == LexToken.TokenQuestionMark then
        StackTop = ExpressionQuestionMarkOperator(Parser, StackTop, TopValue, BottomValue)
    elseif Op == LexToken.TokenColon then
        StackTop = ExpressionColonOperator(Parser, StackTop, TopValue, BottomValue)
    elseif ((TopValue.Typ == Parser.pc.FPType and BottomValue.Typ == Parser.pc.FPType) or
            (TopValue.Typ == Parser.pc.FPType and IS_NUMERIC_COERCIBLE(BottomValue)) or
            (IS_NUMERIC_COERCIBLE(TopValue) and BottomValue.Typ == Parser.pc.FPType)) then
        ResultIsInt = false
        ResultFP = 0.0
        if TopValue.Typ == Parser.pc.FPType then
            TopFP = PointerGetFP(TopValue.Val)
        else
            TopFP = ExpressionCoerceInteger(TopValue)
        end
        if BottomValue.Typ == Parser.pc.FPType then
            BottomFP = PointerGetFP(BottomValue.Val)
        else
            BottomFP = ExpressionCoerceInteger(BottomValue)
        end

        if Op == LexToken.TokenAssign then
            if IS_FP(BottomValue) then
                ResultFP = ExpressionAssignFP(Parser, BottomValue, TopFP)
            else
                ResultInt = ExpressionAssignInt(Parser, BottomValue, TopFP, false)
                ResultIsInt = true
            end
        elseif Op == LexToken.TokenAddAssign then
            if IS_FP(BottomValue) then
                ResultFP = ExpressionAssignFP(Parser, BottomValue, TopFP + BottomFP)
            else
                ResultInt = ExpressionAssignInt(Parser, BottomValue, TopFP + BottomFP, false)
                ResultIsInt = true
            end
        elseif Op == LexToken.TokenSubtractAssign then
            if IS_FP(BottomValue) then
                ResultFP = ExpressionAssignFP(Parser, BottomValue, BottomFP - TopFP)
            else
                ResultInt = ExpressionAssignInt(Parser, BottomValue, BottomFP - TopFP, false)
                ResultIsInt = true
            end
        elseif Op == LexToken.TokenMultiplyAssign then
            if IS_FP(BottomValue) then
                ResultFP = ExpressionAssignFP(Parser, BottomValue, BottomFP * TopFP)
            else
                ResultInt = ExpressionAssignInt(Parser, BottomValue, BottomFP * TopFP, false)
                ResultIsInt = true
            end
        elseif Op == LexToken.TokenDivideAssign then
            if IS_FP(BottomValue) then
                ResultFP = ExpressionAssignFP(Parser, BottomValue, BottomFP / TopFP)
            else
                ResultInt = ExpressionAssignInt(Parser, BottomValue, math.floor(BottomFP / TopFP), false)
                ResultIsInt = true
            end
        elseif Op == LexToken.TokenEqual then
            ResultInt = LUA_BOOLEAN_TO_C(BottomFP == TopFP)
            ResultIsInt = true
        elseif Op == LexToken.TokenNotEqual then
            ResultInt = LUA_BOOLEAN_TO_C(BottomFP ~= TopFP)
            ResultIsInt = true
        elseif Op == LexToken.TokenLessThan then
            ResultInt = LUA_BOOLEAN_TO_C(BottomFP < TopFP)
            ResultIsInt = true
        elseif Op == LexToken.TokenGreaterThan then
            ResultInt = LUA_BOOLEAN_TO_C(BottomFP > TopFP)
            ResultIsInt = true
        elseif Op == LexToken.TokenLessEqual then
            ResultInt = LUA_BOOLEAN_TO_C(BottomFP <= TopFP)
            ResultIsInt = true
        elseif Op == LexToken.TokenGreaterEqual then
            ResultInt = LUA_BOOLEAN_TO_C(BottomFP >= TopFP)
            ResultIsInt = true
        elseif Op == LexToken.TokenPlus then
            ResultFP = BottomFP + TopFP
        elseif Op == LexToken.TokenMinus then
            ResultFP = BottomFP - TopFP
        elseif Op == LexToken.TokenAsterisk then
            ResultFP = BottomFP * TopFP
        elseif Op == LexToken.TokenSlash then
            ResultFP = BottomFP / TopFP
        else
            ProgramFail(Parser, "invalid operation")
        end

        if ResultIsInt then
            StackTop = ExpressionPushInt(Parser, StackTop, ResultInt)
        else
            StackTop = ExpressionPushFP(Parser, StackTop, ResultFP)
        end
    elseif IS_NUMERIC_COERCIBLE(TopValue) and IS_NUMERIC_COERCIBLE(BottomValue) then
        TopInt = ExpressionCoerceInteger(TopValue)
        BottomInt = ExpressionCoerceInteger(BottomValue)
        --if Debug then
        --    print("TopInt:", TopInt)
        --    print("BottomInt:", BottomInt)
        --end

        if Op == LexToken.TokenAssign then
            ResultInt = ExpressionAssignInt(Parser, BottomValue, TopInt, false)
        elseif Op == LexToken.TokenAddAssign then
            ResultInt = ExpressionAssignInt(Parser, BottomValue, BottomInt + TopInt, false)
        elseif Op == LexToken.TokenSubtractAssign then
            ResultInt = ExpressionAssignInt(Parser, BottomValue, BottomInt - TopInt, false)
        elseif Op == LexToken.TokenMultiplyAssign then
            ResultInt = ExpressionAssignInt(Parser, BottomValue, BottomInt * TopInt, false)
        elseif Op == LexToken.TokenDivideAssign then
            ResultInt = ExpressionAssignInt(Parser, BottomValue, math.floor(BottomInt / TopInt), false)
        elseif Op == LexToken.TokenModulusAssign then
            ResultInt = ExpressionAssignInt(Parser, BottomValue, BottomInt % TopInt, false)
        elseif Op == LexToken.TokenShiftLeftAssign then
            ResultInt = ExpressionAssignInt(Parser, BottomValue, lshift(BottomInt, TopInt), false)
        elseif Op == LexToken.TokenShiftRightAssign then
            ResultInt = ExpressionAssignInt(Parser, BottomValue, rshift(BottomInt, TopInt), false)
        elseif Op == LexToken.TokenArithmeticAndAssign then
            ResultInt = ExpressionAssignInt(Parser, BottomValue, band(BottomInt, TopInt), false)
        elseif Op == LexToken.TokenArithmeticOrAssign then
            ResultInt = ExpressionAssignInt(Parser, BottomValue, bor(BottomInt, TopInt), false)
        elseif Op == LexToken.TokenArithmeticExorAssign then
            ResultInt = ExpressionAssignInt(Parser, BottomValue, bxor(BottomInt, TopInt), false)
        elseif Op == LexToken.TokenLogicalOr then
            ResultInt = C_LOGICAL_OR(BottomInt, TopInt)
        elseif Op == LexToken.TokenLogicalAnd then
            ResultInt = C_LOGICAL_AND(BottomInt, TopInt)
        elseif Op == LexToken.TokenArithmeticOr then
            ResultInt = bor(BottomInt, TopInt)
        elseif Op == LexToken.TokenArithmeticExor then
            ResultInt = bxor(BottomInt, TopInt)
        elseif Op == LexToken.TokenAmpersand then
            ResultInt = band(BottomInt, TopInt)
        elseif Op == LexToken.TokenEqual then
            ResultInt = LUA_BOOLEAN_TO_C(BottomInt == TopInt)
        elseif Op == LexToken.TokenNotEqual then
            ResultInt = LUA_BOOLEAN_TO_C(BottomInt ~= TopInt)
        elseif Op == LexToken.TokenLessThan then
            ResultInt = LUA_BOOLEAN_TO_C(BottomInt < TopInt)
        elseif Op == LexToken.TokenGreaterThan then
            ResultInt = LUA_BOOLEAN_TO_C(BottomInt > TopInt)
        elseif Op == LexToken.TokenLessEqual then
            ResultInt = LUA_BOOLEAN_TO_C(BottomInt <= TopInt)
        elseif Op == LexToken.TokenGreaterEqual then
            ResultInt = LUA_BOOLEAN_TO_C(BottomInt >= TopInt)
        elseif Op == LexToken.TokenShiftLeft then
            ResultInt = lshift(BottomInt, TopInt)
        elseif Op == LexToken.TokenShiftRight then
            ResultInt = rshift(BottomInt, TopInt)
        elseif Op == LexToken.TokenPlus then
            ResultInt = BottomInt + TopInt
        elseif Op == LexToken.TokenMinus then
            ResultInt = BottomInt - TopInt
        elseif Op == LexToken.TokenAsterisk then
            ResultInt = BottomInt * TopInt
        elseif Op == LexToken.TokenSlash then
            ResultInt = math.floor(BottomInt / TopInt)
        elseif Op == LexToken.TokenModulus then
            ResultInt = BottomInt % TopInt
        else
            ProgramFail(Parser, "invalid operation")
        end
        StackTop = ExpressionPushInt(Parser, StackTop, ResultInt)
    elseif (BottomValue.Typ.Base == BaseType.TypePointer and
        IS_NUMERIC_COERCIBLE(TopValue)) then
        TopInt = ExpressionCoerceInteger(TopValue)

        if Op == LexToken.TokenEqual or Op == LexToken.TokenNotEqual then
            if TopInt ~= 0 then
                ProgramFail(Parser, "invalid operation")
            end

            if Op == LexToken.TokenEqual then
                StackTop = ExpressionPushInt(Parser, StackTop,
                    LUA_BOOLEAN_TO_C(IsPointerNull(BottomValue.Val)))
            else
                StackTop = ExpressionPushInt(Parser, StackTop,
                    LUA_BOOLEAN_TO_C(not IsPointerNull(BottomValue.Val)))
            end
        elseif Op == LexToken.TokenPlus or Op == LexToken.TokenMinus then
            local Size = TypeSize(BottomValue.Typ.FromType, 0, true)
            local NewOffset = 0

            if IsPointerNull(BottomValue.Val) then
                ProgramFail(Parser, "c. invalid use of a NULL or void pointer")
            end

            if Op == LexToken.TokenPlus then
                NewOffset = TopInt * Size
            else
                NewOffset = -TopInt * Size
            end

            StackValue, StackTop = ExpressionStackPushValueByType(Parser, StackTop,
                BottomValue.Typ)
            StackValue.Val = PointerCopyAllValues(BottomValue.Val, true)
            PointerMovePointer(StackValue.Val, NewOffset)
        elseif Op == LexToken.TokenAssign and TopInt == 0 then
            -- Recover Value on the stack (the operand) as we only push a ExpressionStack
            -- So on the top of the stack it is now ExpressionStack + Value
            HeapUnpopStack(Parser.pc)
            ExpressionAssign(Parser, BottomValue, TopValue, false, nil, 0, false)
            StackTop = ExpressionStackPushValueNode(Parser, StackTop, BottomValue)
        elseif Op == LexToken.TokenAddAssign or Op == LexToken.TokenSubtractAssign then
            local Size = TypeSize(BottomValue.Typ.FromType, 0, true)
            local NewOffset = 0

            if IsPointerNull(BottomValue.Val) then
                ProgramFail(Parser, "c. invalid use of a NULL or void pointer")
            end

            if Op == LexToken.TokenAddAssign then
                NewOffset = TopInt * Size
            else
                NewOffset = -TopInt * Size
            end

            HeapUnpopStack(Parser.pc)
            PointerMovePointer(BottomValue.Val, NewOffset)
            StackTop = ExpressionStackPushValueNode(Parser, StackTop, BottomValue)
        else
            ProgramFail(Parser, "invalid operation")
        end
    elseif (BottomValue.Typ.Base == BaseType.TypePointer and
        TopValue.Typ.Base == BaseType.TypePointer and Op ~= LexToken.TokenAssign) then
        local CompareResult

        if Op == LexToken.TokenEqual then
            CompareResult, _ = PointerComparePointer(TopValue.Val, BottomValue.Val, true)
            StackTop = ExpressionPushInt(Parser, StackTop,
                LUA_BOOLEAN_TO_C(CompareResult))
        elseif Op == LexToken.TokenNotEqual then
            CompareResult, _ = PointerComparePointer(TopValue.Val, BottomValue.Val, true)
            StackTop = ExpressionPushInt(Parser, StackTop,
                LUA_BOOLEAN_TO_C(not CompareResult))
        elseif Op == LexToken.TokenMinus then
            local RefOffsetDifference
            CompareResult, RefOffsetDifference = PointerComparePointer(TopValue.Val, BottomValue.Val, false)
            if (not CompareResult or
                TopValue.Typ.FromType.Base ~= BottomValue.Typ.FromType.Base) then
                -- Difference between pointers referencing different
                -- variables is not supported here
                ProgramFail(Parser, "comparison between pointers with different base addresses is not supported")
            end

            StackTop = ExpressionPushInt(Parser, StackTop,
                math.floor(RefOffsetDifference / TypeSize(BottomValue.Typ.FromType, 0, true)))
        else
            ProgramFail(Parser, "invalid operation")
        end
    elseif Op == LexToken.TokenAssign then
        HeapUnpopStack(Parser.pc)
        ExpressionAssign(Parser, BottomValue, TopValue, false, nil, 0, false)
        StackTop = ExpressionStackPushValueNode(Parser, StackTop, BottomValue)
    elseif Op == LexToken.TokenCast then
        ValueLoc, StackTop = ExpressionStackPushValueByType(Parser, StackTop, BottomValue.Val.Typ)
        ExpressionAssign(Parser, ValueLoc, TopValue, true, nil, 0, true)
        --if Debug then
        --    print("Infix Cast Operation")
        --end
    else
        ProgramFail(Parser, "invalid operation");
    end

    return StackTop
end

function ExpressionStackCollapse(Parser, StackTop, Precedence, IgnorePrecedence)
    local FoundPrecedence = Precedence
    local TopValue, BottomValue, TopStackNode, TopOperatorNode
    TopStackNode = StackTop

    while (TopStackNode ~= nil and HeapGetStackNode(Parser.pc, TopStackNode.NextNodeId) ~= nil and
        FoundPrecedence >= Precedence) do
        if TopStackNode.Order == OperatorOrder.OrderNone then
            -- ExpressionStack + Value
            TopOperatorNode = HeapGetStackNode(Parser.pc, TopStackNode.NextNodeId)
        else
            TopOperatorNode = TopStackNode
        end

        FoundPrecedence = TopOperatorNode.Precedence

        if FoundPrecedence >= Precedence and TopOperatorNode ~= nil then
            if TopOperatorNode.Order == OperatorOrder.OrderPrefix then
                TopValue = TopStackNode.Val
                --if Debug then
                --    print("Top:", PointerGetSignedInt(TopValue.Val))
                --end

                -- OperatorNode, Value, ExpressionStack
                -- (From bottom to top)
                HeapPopStack(Parser.pc, 3)
                --HeapPopStack(Parser.pc, 2)  -- ExpressionStack + Value
                --HeapPopStack(Parser.pc, 1, TopOperatorNode.StackId - 1)  -- OperatorNode
                StackTop = HeapGetStackNode(Parser.pc, TopOperatorNode.NextNodeId)

                if Parser.Mode == RunMode.RunModeRun then
                    StackTop = ExpressionPrefixOperator(Parser, StackTop,
                        TopOperatorNode.Op, TopValue)
                else
                    StackTop = ExpressionPushInt(Parser, StackTop, 0)
                end
            elseif TopOperatorNode.Order == OperatorOrder.OrderPostfix then
                TopValue = HeapGetStackNode(Parser.pc, TopStackNode.NextNodeId).Val

                -- Value, ExpressionStack, OperatorNode
                -- (From bottom to top)
                HeapPopStack(Parser.pc, 3)
                --HeapPopStack(Parser.pc, 1)  -- OperatorNode
                --HeapPopStack(Parser.pc, 2, TopValue.StackId - 1)  -- ExpressionStack + Value
                StackTop = HeapGetStackNode(Parser.pc,
                    HeapGetStackNode(Parser.pc, TopStackNode.NextNodeId).NextNodeId)

                if Parser.Mode == RunMode.RunModeRun then
                    StackTop = ExpressionPostfixOperator(Parser, StackTop,
                        TopOperatorNode.Op, TopValue)
                else
                    StackTop = ExpressionPushInt(Parser, StackTop, 0)
                end
            elseif TopOperatorNode.Order == OperatorOrder.OrderInfix then
                --if Debug then
                --    print("Collapse Infix")
                --end
                TopValue = TopStackNode.Val

                if TopValue ~= nil then
                    BottomValue = HeapGetStackNode(Parser.pc, TopOperatorNode.NextNodeId).Val

                    --if Debug then
                    --    print("Top:", PointerGetSignedInt(TopValue.Val), TopValue.Typ)
                    --    print("Bottom:", PointerGetSignedInt(BottomValue.Val), BottomValue.Typ)
                    --end

                    -- Value, ExpressionStack, OperatorNode, Value, ExpressionStack
                    -- (From bottom to top)
                    HeapPopStack(Parser.pc, 5)
                    --HeapPopStack(Parser.pc, 2)  -- ExpressionStack + Value
                    --HeapPopStack(Parser.pc, 1)  -- OperatorNode
                    --HeapPopStack(Parser.pc, 2, BottomValue.StackId - 1)  -- ExpressionStack + Value
                    StackTop = HeapGetStackNode(Parser.pc,
                        HeapGetStackNode(Parser.pc, TopOperatorNode.NextNodeId).NextNodeId)

                    if Parser.Mode == RunMode.RunModeRun then
                        StackTop = ExpressionInfixOperator(Parser, StackTop,
                            TopOperatorNode.Op, BottomValue, TopValue)
                    else
                        StackTop = ExpressionPushInt(Parser, StackTop, 0)
                    end
                else
                    FoundPrecedence = -1
                end
            else
                -- empty
            end

            if FoundPrecedence <= IgnorePrecedence then
                IgnorePrecedence = DEEP_PRECEDENCE
            end
        end

        TopStackNode = StackTop
    end

    return StackTop, IgnorePrecedence
end

function ExpressionStackPushOperator(Parser, StackTop, Order, Token, Precedence)
    local StackNode
    StackNode = VariableAlloc(Parser.pc, Parser, false)
    if StackTop == nil then
        StackNode.NextNodeId = 0
    else
        StackNode.NextNodeId = StackTop.StackId
    end
    StackNode.Order = Order
    StackNode.Op = Token
    StackNode.Precedence = Precedence
    StackTop = StackNode

    --StackNode.Line = Parser.Line
    --StackNode.CharacterPos = Parser.CharacterPos

    return StackTop
end

function ExpressionGetStructElement(Parser, StackTop, Token)
    local Ident
    local ParamVal, StructVal, StructType, DerefDataLoc, MemberValue, Result
    local TokenG
    local PF1, PF2
    local Success
    local LValueFrom

    TokenG, Ident = LexGetToken(Parser, Ident, true)
    if TokenG ~= LexToken.TokenIdentifier then
        if Token == LexToken.TokenDot then
            ProgramFail(Parser, "need an structure or union member after '.'")
        else
            ProgramFail(Parser, "need an structure or union member after '->'")
        end
    end

    if Parser.Mode == RunMode.RunModeRun then
        ParamVal = StackTop.Val
        StructVal = ParamVal
        StructType = ParamVal.Typ
        DerefDataLoc = {}
        MemberValue = nil

        PointerDeriveNewValue(DerefDataLoc, ParamVal.Val, false)

        if Token == LexToken.TokenArrow then
            DerefDataLoc, StructVal, StructType, _, _ = VariableDereferencePointer(ParamVal)

            if DerefDataLoc == nil then
                ProgramFail(Parser, "trying to dereference a void pointer - is the pointer NULL or pointing to a deallocated variable?")
            end

            -- Change the identity of dereferenced value - members in a struct are *de jure* different objects
            -- but *de facto* the struct itself with different offsets
            DerefDataLoc.Ident = math.random(1, 0x7FFFFFFF)
        end

        if StructType.Base ~= BaseType.TypeStruct and StructType.Base ~= BaseType.TypeUnion then
            if Token == LexToken.TokenDot then PF1 = "."
                else PF1 = "->" end
            if Token == LexToken.TokenArrow then PF2 = "pointer"
                else PF2 = "" end
            ProgramFail(Parser, "can't use '%s' on something that's not a struct or union %s : it's a %t",
                PF1, PF2, ParamVal.Typ)
        end

        -- Ident: Value
        Success, MemberValue, _, _, _ = TableGet(StructType.Members, Ident.Val) -- Changed from Ident.Val.Identifier
        if not Success then
            ProgramFail(Parser, "doesn't have a member called '%s",
                Ident.Val.RawValue.Val)   -- Changed from Ident.Val.Identifier
        end

        HeapPopStack(Parser.pc, 2, ParamVal.StackId - 1)  -- ExpressionStack + Value
        StackTop = HeapGetStackNode(Parser.pc, StackTop.NextNodeId)

        if StructVal ~= nil then
            LValueFrom = StructType.LValueFrom
        else
            LValueFrom = nil
        end

        DerefDataLoc.Offset = DerefDataLoc.Offset +
            PointerGetSignedInt(MemberValue.Val)

        Result = VariableAllocValueFromExistingData(Parser, MemberValue.Typ,
            DerefDataLoc, true, LValueFrom)
        StackTop = ExpressionStackPushValueNode(Parser, StackTop, Result)
    end

    return StackTop
end

function ExpressionParse(Parser)
    local PrefixState = true
    local Done = false
    local BracketPrecedence = 0
    local LocalPrecedence
    local Precedence = 0
    local IgnorePrecedence = DEEP_PRECEDENCE
    local TernaryDepth = 0
    local LexValue
    local StackTop = nil
    local Result

    repeat
        local PreState = {}
        local Token

        ParserCopy(PreState, Parser)
        Token, LexValue = LexGetToken(Parser, LexValue, true)
        --print("Token:", Token)
        if (((Token > LexToken.TokenComma and Token <= LexToken.TokenOpenBracket) or
            (Token == LexToken.TokenCloseBracket and BracketPrecedence ~= 0)) and
            (Token ~= LexToken.TokenColon or TernaryDepth > 0)) then
            if PrefixState then
                --if Debug then
                --    print("Prefix Precedence:", Token, OperatorPrecedence[Token].InfixPrecedence)
                --end
                if OperatorPrecedence[Token].PrefixPrecedence == 0 then
                    ProgramFail(Parser, "operator not expected here")
                end

                LocalPrecedence = OperatorPrecedence[Token].PrefixPrecedence
                Precedence = BracketPrecedence + LocalPrecedence

                if Token == LexToken.TokenOpenBracket then
                    local BracketToken
                    BracketToken, LexValue = LexGetToken(Parser, LexValue, false)

                    local Cond = false
                    if StackTop == nil then
                        Cond = true
                    else
                        if StackTop.Op ~= LexToken.TokenSizeof then
                            Cond = true
                        else
                            Cond = false
                        end
                    end

                    if IsTypeToken(Parser, BracketToken, LexValue) and Cond then
                        local CastType
                        local CastTypeValue
                        local Tok

                        --if Debug then
                        --    print("Type Cast", BracketToken)
                        --end

                        CastType, _, _ = TypeParse(Parser)
                        Tok, LexValue = LexGetToken(Parser, LexValue, true)
                        if Tok ~= LexToken.TokenCloseBracket then
                            ProgramFail(Parser, "brackets not closed")
                        end

                        Precedence = BracketPrecedence +
                            OperatorPrecedence[LexToken.TokenCast].PrefixPrecedence

                        StackTop, IgnorePrecedence = ExpressionStackCollapse(Parser,
                            StackTop, Precedence + 1, IgnorePrecedence)
                        CastTypeValue = VariableAllocValueFromType(Parser.pc,
                            Parser, Parser.pc.TypeType, false, nil, false)
                        CastTypeValue.Val.Typ = CastType    -- Val here points to Typ, not AnyValue type
                        StackTop = ExpressionStackPushValueNode(Parser, StackTop,
                            CastTypeValue)
                        StackTop = ExpressionStackPushOperator(Parser, StackTop,
                            OperatorOrder.OrderInfix, LexToken.TokenCast, Precedence)
                    else
                        BracketPrecedence = BracketPrecedence + BRACKET_PRECEDENCE
                    end
                else
                    local NextToken
                    local TempPrecedenceBoost = 0
                    NextToken, _ = LexGetToken(Parser, nil, false)
                    if NextToken > LexToken.TokenComma and NextToken < LexToken.TokenOpenBracket then
                        local NextPrecedence =
                            OperatorPrecedence[NextToken].PrefixPrecedence

                        if LocalPrecedence == NextPrecedence then
                            TempPrecedenceBoost = -1
                        end
                    end

                    StackTop, IgnorePrecedence = ExpressionStackCollapse(Parser,
                        StackTop, Precedence, IgnorePrecedence)
                    StackTop = ExpressionStackPushOperator(Parser, StackTop, OperatorOrder.OrderPrefix,
                        Token, Precedence + TempPrecedenceBoost)
                    --if Debug then
                    --    print("Prefix")
                    --end
                end
            else
                --if Debug then
                --    print("Precedence:", Token, OperatorPrecedence[Token].InfixPrecedence)
                --end
                if OperatorPrecedence[Token].PostfixPrecedence ~= 0 then
                    if (Token == LexToken.TokenCloseBracket or
                        Token == LexToken.TokenRightSquareBracket) then
                        if BracketPrecedence == 0 then
                            ParserCopy(Parser, PreState)
                            Done = true
                        else
                            StackTop, IgnorePrecedence = ExpressionStackCollapse(Parser,
                                StackTop, BracketPrecedence, IgnorePrecedence)
                            BracketPrecedence = BracketPrecedence - BRACKET_PRECEDENCE
                        end
                    else
                        Precedence = BracketPrecedence +
                            OperatorPrecedence[Token].PostfixPrecedence
                        StackTop, IgnorePrecedence = ExpressionStackCollapse(Parser,
                            StackTop, Precedence, IgnorePrecedence)
                        StackTop = ExpressionStackPushOperator(Parser, StackTop,
                            OperatorOrder.OrderPostfix, Token, Precedence)
                        --if Debug then
                        --    print("Postfix")
                        --end
                    end
                elseif OperatorPrecedence[Token].InfixPrecedence ~= 0 then
                    Precedence = BracketPrecedence +
                        OperatorPrecedence[Token].InfixPrecedence

                    if IS_LEFT_TO_RIGHT(OperatorPrecedence[Token].InfixPrecedence) then
                        StackTop, IgnorePrecedence = ExpressionStackCollapse(Parser,
                            StackTop, Precedence, IgnorePrecedence)
                    else
                        StackTop, IgnorePrecedence = ExpressionStackCollapse(Parser,
                            StackTop, Precedence + 1, IgnorePrecedence)
                    end

                    if Token == LexToken.TokenDot or Token == LexToken.TokenArrow then
                        StackTop = ExpressionGetStructElement(Parser, StackTop, Token)
                    else
                        if ((Token == LexToken.TokenLogicalOr or Token == LexToken.TokenLogicalAnd) and
                            IS_NUMERIC_COERCIBLE(StackTop.Val)) then
                            local LHSInt = ExpressionCoerceInteger(StackTop.Val)
                            if (((Token == LexToken.TokenLogicalOr and LHSInt ~= 0) or
                                (Token == LexToken.TokenLogicalAnd and LHSInt == 0)) and
                                (IgnorePrecedence > Precedence)) then
                                IgnorePrecedence = Precedence
                            end
                        end

                        StackTop = ExpressionStackPushOperator(Parser, StackTop,
                            OperatorOrder.OrderInfix, Token, Precedence)
                        PrefixState = true
                        --if Debug then
                        --    print("Infix")
                        --end

                        if Token == LexToken.TokenQuestionMark then
                            TernaryDepth = TernaryDepth + 1
                        elseif Token == LexToken.TokenColon then
                            TernaryDepth = TernaryDepth - 1
                        end
                    end

                    if Token == LexToken.TokenLeftSquareBracket then
                        BracketPrecedence = BracketPrecedence + BRACKET_PRECEDENCE
                    end
                else
                    ProgramFail(Parser, "operator not expected here")
                end
            end
        elseif Token == LexToken.TokenIdentifier then
            --if Debug then
            --    print("Precedence:", Token)
            --end
            if not PrefixState then
                ProgramFail(Parser, "identifier not expected here")
            end

            local Tok
            Tok, _ = LexGetToken(Parser, nil, false)
            if Tok == LexToken.TokenOpenBracket then
                StackTop = ExpressionParseFunctionCall(Parser, StackTop,
                    LexValue.Val,    -- Changed from LexValue.Val.Identifier
                    Parser.Mode == RunMode.RunModeRun and Precedence < IgnorePrecedence)
            else
                if Parser.Mode == RunMode.RunModeRun then
                    local VariableValue

                    VariableValue = VariableGet(Parser.pc, Parser, LexValue.Val) -- Changed from LexValue.Val.Identifier
                    if VariableValue.Typ.Base == BaseType.TypeMacro then
                        local MacroParser = {}
                        local MacroResult

                        ParserCopy(MacroParser, VariableValue.Val.MacroDef.Body)
                        MacroParser.Mode = Parser.Mode
                        if VariableValue.Val.MacroDef.NumParams ~= 0 then
                            ProgramFail(MacroParser, "macro arguments missing")
                        end

                        local Success
                        Success, MacroResult = ExpressionParse(MacroParser)
                        Tok, _ = LexGetToken(MacroParser, nil, false)
                        if (not Success) or Tok ~= LexToken.TokenEndOfFunction then
                            ProgramFail(MacroParser, "expression expected")
                        end

                        StackTop = ExpressionStackPushValueNode(Parser, StackTop, MacroResult)
                    elseif VariableValue.Typ == Parser.pc.VoidType then
                        ProgramFail(Parser, "a void value isn't much use here")
                    else
                        StackTop = ExpressionStackPushLValue(Parser, StackTop,
                            VariableValue, 0)
                    end
                else
                    StackTop = ExpressionPushInt(Parser, StackTop, 0)
                end
            end

            if Precedence <= IgnorePrecedence then
                IgnorePrecedence = DEEP_PRECEDENCE
            end

            PrefixState = false
        elseif Token > LexToken.TokenCloseBracket and Token <= LexToken.TokenCharacterConstant then
            if not PrefixState then
                ProgramFail(Parser, "value not expected here")
            end

            PrefixState = false
            StackTop = ExpressionStackPushValue(Parser, StackTop, LexValue)
            --if Debug then
            --    print(LexValue.Val.Offset)
            --end
        elseif IsTypeToken(Parser, Token, LexValue) then
            local Typ
            local TypeValue

            if not PrefixState then
                ProgramFail(Parser, "type not expected here")
            end

            PrefixState = false
            ParserCopy(Parser, PreState)
            Typ, _, _ = TypeParse(Parser)
            TypeValue = VariableAllocValueFromType(Parser.pc, Parser,
                Parser.pc.TypeType, false, nil, false)
            TypeValue.Val.Typ = Typ     -- Val here points to Typ, not AnyValue type
            StackTop = ExpressionStackPushValueNode(Parser, StackTop, TypeValue)
        else
            ParserCopy(Parser, PreState)
            Done = true
        end
    until Done

    if BracketPrecedence > 0 then
        ProgramFail(Parser, "brackets not closed")
    end

    StackTop, IgnorePrecedence = ExpressionStackCollapse(Parser, StackTop, 0, IgnorePrecedence)

    if StackTop ~= nil then
        if Parser.Mode == RunMode.RunModeRun then
            if (StackTop.Order ~= OperatorOrder.OrderNone or
                HeapGetStackNode(Parser.pc, StackTop.NextNodeId) ~= nil) then
                ProgramFail(Parser, "invalid expression")
            end

            Result = StackTop.Val
            HeapPopStack(Parser.pc, 1, StackTop.StackId - 1)  -- Pop ExpressionStack, Value is left on stack
        else
            HeapPopStack(Parser.pc, 2, StackTop.Val.StackId - 1)  -- Pop ExpressionStack + Value
        end
    end

    return StackTop ~= nil, Result
end

function ExpressionParseMacroCall(Parser, StackTop, MacroName, MDef)
    local ArgCount
    local Token
    local ReturnValue = nil
    local Param
    local ParamArray = nil

    if Parser.Mode == RunMode.RunModeRun then
        _, StackTop = ExpressionStackPushValueByType(Parser, StackTop, Parser.pc.FPType)
        ReturnValue = StackTop.Val
        HeapPushStackFrame(Parser.pc)
        ParamArray = HeapAllocStack(Parser.pc)
        if ParamArray == nil then
            ProgramFail(Parser, "(ExpressionParseMacroCall) out of memory")
        end
    else
        StackTop = ExpressionPushInt(Parser, StackTop, 0)
    end

    ArgCount = 0
    repeat
        local StackNotNull
        StackNotNull, Param = ExpressionParse(Parser)
        if StackNotNull then
            if Parser.Mode == RunMode.RunModeRun then
                if ArgCount < MDef.NumParams then
                    ParamArray[ArgCount + 1] = Param
                else
                    -- MacroName: AnyValue
                    ProgramFail(Parser, "too many arguments to %s()", MacroName.RawValue.Val)
                end
            end

            ArgCount = ArgCount + 1
            Token, _ = LexGetToken(Parser, nil, true)
            if Token ~= LexToken.TokenComma and Token ~= LexToken.TokenCloseBracket then
                ProgramFail(Parser, "comma expected")
            end
        else
            Token, _ = LexGetToken(Parser, nil, true)
            if Token ~= LexToken.TokenCloseBracket then
                ProgramFail(Parser, "bad argument")
            end
        end
    until Token == LexToken.TokenCloseBracket

    if Parser.Mode == RunMode.RunModeRun then
        local MacroParser = {}
        local EvalValue

        if ArgCount < MDef.NumParams then
            ProgramFail(Parser, "not enough arguments to '%s'", MacroName.RawValue.Val)
        end

        if MDef.Body.ParsingTokens == nil then
            ProgramFail(Parser,
                "ExpressionParseMacroCall MacroName: '%s' is undefined", MacroName.RawValue.Val)
        end

        ParserCopy(MacroParser, MDef.Body)
        MacroParser.Mode = Parser.Mode
        VariableStackFrameAdd(Parser, MacroName, 0)
        local TopStackFrame = HeapGetStackNode(Parser.pc, Parser.pc.TopStackFrameId)
        TopStackFrame.NumParams = ArgCount
        TopStackFrame.ReturnValue = ReturnValue
        for Count = 1, MDef.NumParams do
            VariableDefine(Parser.pc, Parser, MDef.ParamName[Count],
                ParamArray[Count], nil, true)
        end

        _, EvalValue = ExpressionParse(MacroParser)
        ExpressionAssign(Parser, ReturnValue, EvalValue, true, MacroName, 0, false)
        VariableStackFramePop(Parser)
        HeapPopStackFrame(Parser.pc)
    end

    return StackTop
end

function ExpressionParseFunctionCall(Parser, StackTop, FuncName, RunIt)
    local ArgCount
    local Token
    local OldMode = Parser.Mode
    local ReturnValue = nil
    local FuncValue = nil
    local Param = nil
    local ParamArray = nil
    local ParamStartStackId = 0

    Token, _ = LexGetToken(Parser, nil, true)
    if RunIt then
        FuncValue = VariableGet(Parser.pc, Parser, FuncName)

        if FuncValue.Typ.Base == BaseType.TypeMacro then
            StackTop = ExpressionParseMacroCall(Parser, StackTop, FuncName,
                FuncValue.Val.MacroDef)
            return StackTop
        end

        --if Debug then
        --    print("Enter Function")
        --end
        if FuncValue.Typ.Base ~= BaseType.TypeFunction then
            ProgramFail(Parser, "%t is not a function - can't call",
                FuncValue.Typ)
        end

        _, StackTop = ExpressionStackPushValueByType(Parser, StackTop,
            FuncValue.Val.FuncDef.ReturnType)
        ReturnValue = StackTop.Val
        --print("Set StackFrame ReturnValue 1", StackTop.Val.Typ.Base)
        HeapPushStackFrame(Parser.pc)
        ParamArray = HeapAllocStack(Parser.pc)
        if ParamArray == nil then
            ProgramFail(Parser, "(ExpressionParseFunctionCall) out of memory")
        end
    else
        StackTop = ExpressionPushInt(Parser, StackTop, 0)
        Parser.Mode = RunMode.RunModeSkip
    end

    ArgCount = 0
    repeat
        if RunIt and ArgCount < FuncValue.Val.FuncDef.NumParams then
            ParamArray[ArgCount + 1] = VariableAllocValueFromType(Parser.pc, Parser,
                FuncValue.Val.FuncDef.ParamType[ArgCount + 1], false, nil, false)

            if ArgCount == 0 then
                ParamStartStackId = ParamArray[ArgCount + 1].StackId
            end
        end

        local StackNotNull
        StackNotNull, Param = ExpressionParse(Parser)
        if StackNotNull then
            if RunIt then
                if ArgCount < FuncValue.Val.FuncDef.NumParams then
                    ExpressionAssign(Parser, ParamArray[ArgCount + 1], Param, true,
                        FuncName, ArgCount + 1, false)
                    VariableStackPop(Parser, Param)
                else
                    if not FuncValue.Val.FuncDef.VarArgs then
                        -- FuncName: AnyValue
                        ProgramFail(Parser, "too many arguments to %s()", FuncName.RawValue.Val)
                    end
                end
            end

            ArgCount = ArgCount + 1
            Token, _ = LexGetToken(Parser, nil, true)
            if Token ~= LexToken.TokenComma and Token ~= LexToken.TokenCloseBracket then
                ProgramFail(Parser, "comma expected")
            end
        else
            Token, _ = LexGetToken(Parser, nil, true)
            if Token ~= LexToken.TokenCloseBracket then
                ProgramFail(Parser, "bad argument")
            end
        end

    until Token == LexToken.TokenCloseBracket

    if RunIt then
        if ArgCount < FuncValue.Val.FuncDef.NumParams then
            ProgramFail(Parser, "not enough arguments to '%s'", FuncName.RawValue.Val)
        end

        if FuncValue.Val.FuncDef.Intrinsic == nil then
            local OldScopeID = Parser.ScopeID
            local FuncParser = {}

            if FuncValue.Val.FuncDef.Body.ParsingTokens == nil then
                ProgramFail(Parser,
                    "ExpressionParseFunctionCall FuncName: '%s' is undefined",
                    FuncName.RawValue.Val)
            end

            ParserCopy(FuncParser, FuncValue.Val.FuncDef.Body)
            if FuncValue.Val.FuncDef.Intrinsic ~= nil then
                VariableStackFrameAdd(Parser, FuncName, FuncValue.Val.FuncDef.NumParams)
            else
                VariableStackFrameAdd(Parser, FuncName, 0)
            end
            local TopStackFrame = HeapGetStackNode(Parser.pc, Parser.pc.TopStackFrameId)
            TopStackFrame.NumParms = ArgCount
            --print("Set StackFrame ReturnValue", Parser.pc.TopStackFrameId)
            TopStackFrame.ReturnValue = ReturnValue
            --print("Set StackFrame ReturnValue", ReturnValue.Typ.Base)

            Parser.ScopeID = -1

            for Count = 1, FuncValue.Val.FuncDef.NumParams do
                --if Debug then
                --    print("ParamName:", ParamArray[Count].Typ)
                --end
                VariableDefine(Parser.pc, Parser,
                    FuncValue.Val.FuncDef.ParamName[Count], ParamArray[Count],
                    nil, true)
            end

            Parser.ScopeID = OldScopeID

            if ParseStatement(FuncParser, true) ~= ParserResult.ParseResultOk then
                ProgramFail(FuncParser, "function body expected")
            end

            if RunIt then
                if (FuncParser.Mode == RunMode.RunModeRun and
                    FuncValue.Val.FuncDef.ReturnType ~= Parser.pc.VoidType) then
                    ProgramFail(FuncParser,
                        "no value returned from a function returning %t",
                        FuncValue.Val.FuncDef.ReturnType)
                elseif FuncParser.Mode == RunMode.RunModeGoto then
                    ProgramFail(FuncParser, "couldn't find goto label '%s'",
                        FuncParser.SearchGotoLabel)
                end
            end

            VariableStackFramePop(Parser)
        else
            FuncValue.Val.FuncDef.Intrinsic(Parser, ReturnValue, ParamArray,
                ArgCount, ParamStartStackId)
        end

        --if Debug then
        --    print("Pop")
        --end
        HeapPopStackFrame(Parser.pc)
    end

    Parser.Mode = OldMode
    return StackTop
end

function ExpressionParseInt(Parser)
    local Result = 0
    local Val
    local ParseResult

    ParseResult, Val = ExpressionParse(Parser)
    if not ParseResult then
        ProgramFail(Parser, "expression expected")
    end

    if Parser.Mode == RunMode.RunModeRun then
        if not IS_NUMERIC_COERCIBLE_PLUS_POINTERS(Val, true) then
            ProgramFail(Parser, "integer value expected instead of %t", Val.Typ)
        end

        Result = ExpressionCoerceInteger(Val)
        --if Debug then
        --    print("ExpressionParseInt:", Result)
        --end
        VariableStackPop(Parser, Val)
    end

    return Result
end
function HeapInit(pc)
    pc.HeapMemory = {}
    pc.HeapStackTop = 0
    pc.StackFrame = 0
    pc.TopStackFrameId = 0
end

function HeapCleanup(pc)
    pc.HeapMemory = nil
end

function HeapAllocStack(pc)
    local NewTop = pc.HeapStackTop + 1
    local NewMem = {
        StackId = NewTop
    }

    pc.HeapMemory[NewTop] = NewMem
    pc.HeapStackTop = NewTop
    return NewMem
end

function HeapUnpopStack(pc)
    local NewTop = pc.HeapStackTop + 1

    if pc.HeapMemory[NewTop] ~= nil then
        pc.HeapStackTop = NewTop
    end
end

-- Pop stack without actually removing the item
-- Just move the top pointer
function HeapPopStack(pc, n, ExpectedAddress)
    if n > pc.HeapStackTop then
        return false
    end

    --[[
    if ExpectedAddress then
        assert(pc.HeapStackTop - n == ExpectedAddress,
            string.format("HeapPopStack assertion failed: Stack location expected at %d, but got %d",
            ExpectedAddress, pc.HeapStackTop - n))
    end
    --]]

    pc.HeapStackTop = pc.HeapStackTop - n
    return true
end

function HeapPushStackFrame(pc)
    local NewTop = pc.HeapStackTop + 1
    local NewMem = {
        StackId = NewTop,
        PreviousFrameLoc = pc.StackFrame
    }

    pc.HeapMemory[NewTop] = NewMem
    pc.StackFrame = pc.HeapStackTop + 1
    pc.HeapStackTop = NewTop
end

function HeapPopStackFrame(pc)
    local StackFrameItem = pc.HeapMemory[pc.StackFrame]
    if StackFrameItem ~= nil then
        local PreviousFrameLoc = StackFrameItem.PreviousFrameLoc

        if PreviousFrameLoc ~= nil then
            pc.HeapStackTop = pc.StackFrame - 1
            pc.StackFrame = PreviousFrameLoc
            return true
        else
            return false
        end
    else
        return false
    end
end

function HeapGetStackNode(pc, n)
    return pc.HeapMemory[n]
end
function IS_FP(v)
    return v.Typ.Base == BaseType.TypeFP
end

function FP_VAL(v)
    return v.Val.FP
end

function IS_POINTER_COERCIBLE(v, ap)
    if ap then
        return v.Typ.Base == BaseType.TypePointer
    else
        return false
    end
end

function POINTER_COERCE(v)
    return "v.Val.Pointer"
end

function IS_INTEGER_NUMERIC_TYPE(t)
    return (t.Base >= BaseType.TypeInt) and (t.Base <= BaseType.TypeUnsignedLong)
end

function IS_INTEGER_NUMERIC(v)
    return IS_INTEGER_NUMERIC_TYPE(v.Typ)
end

function IS_NUMERIC_COERCIBLE(v)
    return IS_INTEGER_NUMERIC(v) or IS_FP(v)
end

function IS_NUMERIC_COERCIBLE_PLUS_POINTERS(v, ap)
    return IS_NUMERIC_COERCIBLE(v) or IS_POINTER_COERCIBLE(v, ap)
end

function LUA_BOOLEAN_TO_C(cond)
    if cond then
        return 1
    else
        return 0
    end
end

function C_INT_TO_LUA_BOOLEAN(i)
    if i ~= 0 then
        return true
    else
        return false
    end
end

function C_LOGICAL_AND(a, b)
    return LUA_BOOLEAN_TO_C((a ~= 0) and (b ~= 0))
end

function C_LOGICAL_OR(a, b)
    return LUA_BOOLEAN_TO_C((a ~= 0) or (b ~= 0))
end

function MIN(a, b)
    if a < b then
        return a
    else
        return b
    end
end

LexToken = {
    TokenNone = 1,
    TokenComma = 2,
    TokenAssign = 3,
    TokenAddAssign = 4,
    TokenSubtractAssign = 5,
    TokenMultiplyAssign = 6,
    TokenDivideAssign = 7,
    TokenModulusAssign = 8,
    TokenShiftLeftAssign = 9,
    TokenShiftRightAssign = 10,
    TokenArithmeticAndAssign = 11,
    TokenArithmeticOrAssign = 12,
    TokenArithmeticExorAssign = 13,
    TokenQuestionMark = 14,
    TokenColon = 15,
    TokenLogicalOr = 16,
    TokenLogicalAnd = 17,
    TokenArithmeticOr = 18,
    TokenArithmeticExor = 19,
    TokenAmpersand = 20,
    TokenEqual = 21,
    TokenNotEqual = 22,
    TokenLessThan = 23,
    TokenGreaterThan = 24,
    TokenLessEqual = 25,
    TokenGreaterEqual = 26,
    TokenShiftLeft = 27,
    TokenShiftRight = 28,
    TokenPlus = 29,
    TokenMinus = 30,
    TokenAsterisk = 31,
    TokenSlash = 32,
    TokenModulus = 33,
    TokenIncrement = 34,
    TokenDecrement = 35,
    TokenUnaryNot = 36,
    TokenUnaryExor = 37,
    TokenSizeof = 38,
    TokenCast = 39,
    TokenLeftSquareBracket = 40,
    TokenRightSquareBracket = 41,
    TokenDot = 42,
    TokenArrow = 43,
    TokenOpenBracket = 44,
    TokenCloseBracket = 45,
    TokenIdentifier = 46,
    TokenIntegerConstant = 47,
    TokenFPConstant = 48,
    TokenStringConstant = 49,
    TokenCharacterConstant = 50,
    TokenSemicolon = 51,
    TokenEllipsis = 52,
    TokenLeftBrace = 53,
    TokenRightBrace = 54,
    TokenIntType = 55,
    TokenCharType = 56,
    TokenFloatType = 57,
    TokenDoubleType = 58,
    TokenVoidType = 59,
    TokenEnumType = 60,
    TokenLongType = 61,
    TokenSignedType = 62,
    TokenShortType = 63,
    TokenStaticType = 64,
    TokenAutoType = 65,
    TokenRegisterType = 66,
    TokenExternType = 67,
    TokenStructType = 68,
    TokenUnionType = 69,
    TokenUnsignedType = 70,
    TokenTypedef = 71,
    TokenContinue = 72,
    TokenDo = 73,
    TokenElse = 74,
    TokenFor = 75,
    TokenGoto = 76,
    TokenIf = 77,
    TokenWhile = 78,
    TokenBreak = 79,
    TokenSwitch = 80,
    TokenCase = 81,
    TokenDefault = 82,
    TokenReturn = 83,
    TokenHashDefine = 84,
    TokenHashInclude = 85,
    TokenHashIf = 86,
    TokenHashIfdef = 87,
    TokenHashIfndef = 88,
    TokenHashElse = 89,
    TokenHashEndif = 90,
    TokenNew = 91,
    TokenDelete = 92,
    TokenOpenMacroBracket = 93,
    TokenEOF = 94,
    TokenEndOfLine = 95,
    TokenEndOfFunction = 96,
    TokenBackSlash = 97
}

RunMode = {
    RunModeRun = 1,
    RunModeSkip = 2,
    RunModeReturn = 3,
    RunModeCaseSearch = 4,
    RunModeBreak = 5,
    RunModeContinue = 6,
    RunModeGoto = 7
}

BaseType = {
    TypeVoid = 1,
    TypeInt = 2,
    TypeShort = 3,
    TypeChar = 4,
    TypeLong = 5,
    TypeUnsignedInt = 6,
    TypeUnsignedShort = 7,
    TypeUnsignedChar = 8,
    TypeUnsignedLong = 9,
    TypeFP = 10,
    TypeFunction = 11,
    TypeMacro = 12,
    TypePointer = 13,
    TypeArray = 14,
    TypeStruct = 15,
    TypeUnion = 16,
    TypeEnum = 17,
    TypeGotoLabel = 18,
    TypeType = 19
}

LexMode = {
    LexModeNormal = 1,
    LexModeHashInclude = 2,
    LexModeHashDefine = 3,
    LexModeHashDefineSpace = 4,
    LexModeHashDefineSpaceIdent = 5
}

ParserResult = {
    ParseResultEOF = 1,
    ParseResultError = 2,
    ParseResultOk = 3
}

FREELIST_BUCKETS = 8
SPLIT_MEM_THRESHOLD = 17
BREAKPOINT_TABLE_SIZE = 21

Debug = false
VariableDebug = false
function IsAlpha(c)
    return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z')
end

function IsDigit(c)
    return c >= '0' and c <= '9'
end

function IsSpace(c)
    return c == ' ' or c == '\t' or c == '\n' or c == '\v' or c == '\f' or c == '\r'
end

function IsAlNum(c)
    return IsAlpha(c) or IsDigit(c)
end

function IsCidstart(c)
    return IsAlpha(c) or c == '_' or c == '#'
end

function IsCident(c)
    return IsAlNum(c) or c == '_'
end

function IS_HEX_ALPHA_DIGIT(c)
    return (c >= 'a' and c <= 'f') or (c >= 'A' and c <= 'F')
end

function IS_BASE_DIGIT(c, b)
    local digit_end, dec
    if b < 10 then
        digit_end = b - 1
    else
        digit_end = 9
    end
    dec = tostring(digit_end)

    local is_base_digit, is_hex_digit
    is_base_digit = (c >= '0' and c <= dec)

    if b > 10 then
        is_hex_digit = IS_HEX_ALPHA_DIGIT(c)
    else
        is_hex_digit = false
    end

    return is_base_digit or is_hex_digit
end

function GET_BASE_DIGIT(c)
    if c <= '9' then
        return string.byte(c) - string.byte('0')
    else
        if c <= 'F' then
            return string.byte(c) - string.byte('A') + 10
        else
            return string.byte(c) - string.byte('a') + 10
        end
    end
end

function NEXTIS(c, x, y, NextChar, Lexer)
    if NextChar == c then
        LEXER_INC(Lexer)
        return x
    else
        return y
    end
end

function NEXTIS3(c, x, d, y, z, NextChar, Lexer)
    if NextChar == c then
        LEXER_INC(Lexer)
        return x
    else
        return NEXTIS(d, y, z, NextChar, Lexer)
    end
end

function NEXTIS4(c, x, d, y, e, z, a, NextChar, Lexer)
    if NextChar == c then
        LEXER_INC(Lexer)
        return x
    else
        return NEXTIS3(d, y, e, z, a, NextChar, Lexer)
    end
end

function NEXTIS3PLUS(c, x, d, y, e, z, a, NextChar, Lexer)
    if NextChar == c then
        LEXER_INC(Lexer)
        return x
    else
        if NextChar == d then
            if GET_LEXER_CHAR_AT(Lexer, Lexer.Pos + 1) == e then
                LEXER_INCN(Lexer, 2)
                return z
            else
                LEXER_INC(Lexer)
                return y
            end
        else
            return a
        end
    end
end

function NEXTISEXACTLY3(c, d, y, z, NextChar, Lexer)
    if NextChar == c and GET_LEXER_CHAR_AT(Lexer, Lexer.Pos + 1) == d then
        LEXER_INCN(Lexer, 2)
        return y
    else
        return z
    end
end

function LEXER_INC(l)
    l.Pos = l.Pos + 1
    l.CharacterPos = l.CharacterPos + 1
end

function LEXER_INCN(l, n)
    l.Pos = l.Pos + n
    l.CharacterPos = l.CharacterPos + n
end

TOKEN_DATA_OFFSET = 2
MAX_CHAR_VALUE = 255

function GET_LEXER_CHAR(l)
    return string.sub(l.SourceText, l.Pos, l.Pos)
end

function GET_LEXER_CHAR_AT(l, p)
    return string.sub(l.SourceText, p, p)
end

function GET_LEXER_STR_FROM(l, f)
    return string.sub(l.SourceText, f)
end

function CHAR_AT(s, p)
    return string.sub(s, p, p)
end

function GET_PARSING(ps)
    return ps.ParsingTokens[ps.Pos]
end

function GET_PARSING_AT(ps, p)
    return ps.ParsingTokens[p]
end

ReservedWords = {
    {
        Word = "#define",
        Token = LexToken.TokenHashDefine
    },
    {
        Word = "#else",
        Token = LexToken.TokenHashElse
    },
    {
        Word = "#endif",
        Token = LexToken.TokenHashEndif
    },
    {
        Word = "#if",
        Token = LexToken.TokenHashIf
    },
    {
        Word = "#ifdef",
        Token = LexToken.TokenHashIfdef
    },
    {
        Word = "#ifndef",
        Token = LexToken.TokenHashIfndef
    },
    {
        Word = "#include",
        Token = LexToken.TokenHashInclude
    },
    {
        Word = "auto",
        Token = LexToken.TokenAutoType
    },
    {
        Word = "break",
        Token = LexToken.TokenBreak
    },
    {
        Word = "case",
        Token = LexToken.TokenCase
    },
    {
        Word = "char",
        Token = LexToken.TokenCharType
    },
    {
        Word = "continue",
        Token = LexToken.TokenContinue
    },
    {
        Word = "default",
        Token = LexToken.TokenDefault
    },
    {
        Word = "delete",
        Token = LexToken.TokenDelete
    },
    {
        Word = "do",
        Token = LexToken.TokenDo
    },
    {
        Word = "double",
        Token = LexToken.TokenDoubleType
    },
    {
        Word = "else",
        Token = LexToken.TokenElse
    },
    {
        Word = "enum",
        Token = LexToken.TokenEnumType
    },
    {
        Word = "extern",
        Token = LexToken.TokenExternType
    },
    {
        Word = "float",
        Token = LexToken.TokenFloatType
    },
    {
        Word = "for",
        Token = LexToken.TokenFor
    },
    {
        Word = "goto",
        Token = LexToken.TokenGoto
    },
    {
        Word = "if",
        Token = LexToken.TokenIf
    },
    {
        Word = "int",
        Token = LexToken.TokenIntType
    },
    {
        Word = "long",
        Token = LexToken.TokenLongType
    },
    {
        Word = "new",
        Token = LexToken.TokenNew
    },
    {
        Word = "register",
        Token = LexToken.TokenRegisterType
    },
    {
        Word = "return",
        Token = LexToken.TokenReturn
    },
    {
        Word = "short",
        Token = LexToken.TokenShortType
    },
    {
        Word = "signed",
        Token = LexToken.TokenSignedType
    },
    {
        Word = "sizeof",
        Token = LexToken.TokenSizeof
    },
    {
        Word = "static",
        Token = LexToken.TokenStaticType
    },
    {
        Word = "struct",
        Token = LexToken.TokenStructType
    },
    {
        Word = "switch",
        Token = LexToken.TokenSwitch
    },
    {
        Word = "typedef",
        Token = LexToken.TokenTypedef
    },
    {
        Word = "union",
        Token = LexToken.TokenUnionType
    },
    {
        Word = "unsigned",
        Token = LexToken.TokenUnsignedType
    },
    {
        Word = "void",
        Token = LexToken.TokenVoidType
    },
    {
        Word = "while",
        Token = LexToken.TokenWhile
    }
}

function LexInit(pc)
    local Size = #ReservedWords

    TableInitTable(pc.ReservedWordTable, pc.ReservedWordHashTable,
        Size, true)
    for Count = 1, Size do
        TableSet(pc, pc.ReservedWordTable,
            TableStrRegister(pc, ReservedWords[Count].Word),
            ReservedWords[Count], nil, 0, 0)
    end

    LexResetLexValue(pc)
end

function LexResetLexValue(pc)
    pc.LexValue = {}
    pc.LexValue.Typ = nil
    pc.LexValue.Val = {
        RawValue = {
            Val = "\000\000\000\000\000\000\000\000"
        },
        Offset = 0,
        RefOffsets = {},
        Pointer = {},
    }
    --setmetatable(pc.LexValue.Val.Pointer, { __mode = "v" })

    pc.LexValue.LValueFrom = false
    pc.LexValue.ValOnHeap = false
    pc.LexValue.ValOnStack = false
    pc.LexValue.AnyValOnHeap = false
    pc.LexValue.IsLValue = false
end

function LexCleanup(pc)
    LexInteractiveClear(pc, nil)

    local Size = #ReservedWords
    for Count = 1, Size do
        TableDelete(pc, pc.ReservedWordTable,
            TableStrRegister(pc, ReservedWords[Count].Word))
    end
end

function LexCheckReservedWord(pc, Word)
    local val, Success

    Success, val, _, _, _ = TableGet(pc.ReservedWordTable, Word)
    if Success then
        return val.Token
    else
        return LexToken.TokenNone
    end
end

function LexGetNumber(pc, Lexer, Value)
    local Result = 0
    local Base = 10
    local ResultToken, FPResult, FPDiv

    if GET_LEXER_CHAR(Lexer) == '0' then
        LEXER_INC(Lexer)
        if Lexer.Pos ~= Lexer.End then
            if GET_LEXER_CHAR(Lexer) == 'x' or GET_LEXER_CHAR(Lexer) == 'X' then
                Base = 16
                LEXER_INC(Lexer)
            elseif GET_LEXER_CHAR(Lexer) == 'b' or GET_LEXER_CHAR(Lexer) == 'B' then
                Base = 2
                LEXER_INC(Lexer)
            elseif GET_LEXER_CHAR(Lexer) ~= '.' then
                Base = 8
            end
        end
    end

    --print(GET_LEXER_CHAR(Lexer))
    --print(IS_BASE_DIGIT(GET_LEXER_CHAR(Lexer), Base))
    while (Lexer.Pos ~= Lexer.End and
        IS_BASE_DIGIT(GET_LEXER_CHAR(Lexer), Base)) do
        Result = Result * Base + GET_BASE_DIGIT(GET_LEXER_CHAR(Lexer))
        LEXER_INC(Lexer)
    end

    if GET_LEXER_CHAR(Lexer) == 'u' or GET_LEXER_CHAR(Lexer) == 'U' then
        LEXER_INC(Lexer)
    end

    if GET_LEXER_CHAR(Lexer) == 'l' or GET_LEXER_CHAR(Lexer) == 'L' then
        LEXER_INC(Lexer)
    end

    Value.Typ = pc.LongType
    PointerSetSignedOrUnsignedInt(Value.Val, Result)

    ResultToken = LexToken.TokenIntegerConstant

    if Lexer.Pos == Lexer.End then
        return ResultToken
    end

    if (GET_LEXER_CHAR(Lexer) ~= '.' and GET_LEXER_CHAR(Lexer) ~= 'e' and
        GET_LEXER_CHAR(Lexer) ~= 'E') then
        return ResultToken
    end

    Value.Typ = pc.FPType
    FPResult = Result

    if GET_LEXER_CHAR(Lexer) == '.' then
        LEXER_INC(Lexer)
        FPDiv = 1 / Base
        while Lexer.Pos ~= Lexer.End and IS_BASE_DIGIT(GET_LEXER_CHAR(Lexer), Base) do
            FPResult = FPResult + GET_BASE_DIGIT(GET_LEXER_CHAR(Lexer)) * FPDiv
            LEXER_INC(Lexer)
            FPDiv = FPDiv / Base
        end
    end

    if (Lexer.Pos ~= Lexer.End and (GET_LEXER_CHAR(Lexer) == 'e' or
        GET_LEXER_CHAR(Lexer) == 'E')) then
        local ExponentSign = 1

        LEXER_INC(Lexer)
        if Lexer.Pos ~= Lexer.End and GET_LEXER_CHAR(Lexer) == '-' then
            ExponentSign = -1
            LEXER_INC(Lexer)
        end

        Result = 0
        while Lexer.Pos ~= Lexer.End and IS_BASE_DIGIT(GET_LEXER_CHAR(Lexer), Base) do
            Result = Result * Base + GET_BASE_DIGIT(GET_LEXER_CHAR(Lexer))
            LEXER_INC(Lexer)
        end

        FPResult = FPResult * (Base ^ (Result * ExponentSign))
    end

    PointerSetFP(Value.Val, FPResult)

    if GET_LEXER_CHAR(Lexer) == 'f' or GET_LEXER_CHAR(Lexer) == 'F' then
        LEXER_INC(Lexer)
    end

    return LexToken.TokenFPConstant
end

function LexGetWord(pc, Lexer, Value)
    local StartPos = Lexer.Pos
    local Token

    repeat
        LEXER_INC(Lexer)
    until Lexer.Pos == Lexer.End or not IsCident(GET_LEXER_CHAR(Lexer))

    Value.Typ = nil
    Value.Val = TableStrRegister2(pc, GET_LEXER_STR_FROM(Lexer, StartPos),
        Lexer.Pos - StartPos)
    --print("LGW: ", Value.Val.RawValue.Val, Lexer.Pos, StartPos, Value.Val)

    Token = LexCheckReservedWord(pc, Value.Val)
    if Token == LexToken.TokenHashInclude then
        Lexer.Mode = LexMode.LexModeHashInclude
    elseif Token == LexToken.TokenHashDefine then
        Lexer.Mode = LexMode.LexModeHashDefine
    end

    if Token ~= LexToken.TokenNone then
        return Token
    end

    if Lexer.Mode == LexMode.LexModeHashDefineSpace then
        Lexer.Mode = LexMode.LexModeHashDefineSpaceIdent
    end

    return LexToken.TokenIdentifier
end

function LexUnEscapeCharacterConstant(From, FromPos, FirstChar, Base)
    local Total = GET_BASE_DIGIT(FirstChar)
    local CCount = 0

    while IS_BASE_DIGIT(CHAR_AT(From, FromPos), Base) and CCount < 2 do
        Total = Total * Base + GET_BASE_DIGIT(CHAR_AT(From, FromPos))
        CCount = CCount + 1
        FromPos = FromPos + 1
    end

    return string.char(Total), FromPos
end

function LexUnEscapeCharacter(From, FromPos, EndPos)
    local ThisChar
    local Return

    while (FromPos ~= EndPos and CHAR_AT(From, FromPos) == '\\' and
        FromPos + 1 ~= EndPos and CHAR_AT(From, FromPos + 1) == '\n') do
        FromPos = FromPos + 2
    end

    while (FromPos ~= EndPos and CHAR_AT(From, FromPos) == '\\' and
        FromPos + 1 ~= EndPos and CHAR_AT(From, FromPos + 1) == '\r' and
        FromPos + 2 ~= EndPos and CHAR_AT(From, FromPos + 2) == '\n') do
        FromPos = FromPos + 3
    end

    if FromPos == EndPos then
        return '\\', FromPos
    end

    if CHAR_AT(From, FromPos) == '\\' then
        FromPos = FromPos + 1
        if FromPos == EndPos then
            return '\\', FromPos
        end

        ThisChar = CHAR_AT(From, FromPos)
        FromPos = FromPos + 1
        if ThisChar == '\\' then
            return '\\', FromPos
        elseif ThisChar == "'" then
            return "'", FromPos
        elseif ThisChar == '"' then
            return '"', FromPos
        elseif ThisChar == 'a' then
            return '\a', FromPos
        elseif ThisChar == 'b' then
            return '\b', FromPos
        elseif ThisChar == 'f' then
            return '\f', FromPos
        elseif ThisChar == 'n' then
            return '\n', FromPos
        elseif ThisChar == 'r' then
            return '\r', FromPos
        elseif ThisChar == 't' then
            return '\t', FromPos
        elseif ThisChar == 'v' then
            return '\v', FromPos
        elseif ThisChar >= '0' and ThisChar <= '3' then
            return LexUnEscapeCharacterConstant(From, FromPos, ThisChar, 8)
        elseif ThisChar == 'x' then
            return LexUnEscapeCharacterConstant(From, FromPos, '0', 16)
        else
            return ThisChar, FromPos
        end
    else
        Return = CHAR_AT(From, FromPos)
        FromPos = FromPos + 1
        return Return, FromPos
    end
end

function LexGetStringConstant(pc, Lexer, Value, EndChar)
    local Escape = false
    local StartPos = Lexer.Pos
    local EndPos
    local EscBuf, EscBufPos, RegString
    local ArrayValue

    while (Lexer.Pos ~= Lexer.End and
        (GET_LEXER_CHAR(Lexer) ~= EndChar or Escape)) do
        if Escape then
            if GET_LEXER_CHAR(Lexer) == '\r' and Lexer.Pos + 1 ~= Lexer.End then
                Lexer.Pos = Lexer.Pos + 1
            end

            if GET_LEXER_CHAR(Lexer) == '\n' and Lexer.Pos + 1 ~= Lexer.End then
                Lexer.Line = Lexer.Line + 1
                Lexer.Pos = Lexer.Pos + 1
                Lexer.CharacterPos = 0
                Lexer.EmitExtraNewlines = Lexer.EmitExtraNewlines + 1
            end

            Escape = false
        elseif GET_LEXER_CHAR(Lexer) == '\\' then
            Escape = true
        end

        LEXER_INC(Lexer)
    end
    EndPos = Lexer.Pos

    EscBuf = HeapAllocStack(pc)
    if EscBuf == nil then
        LexFail(pc, Lexer, "(LexGetStringConstant) out of memory")
    end
    EscBuf.Str = ""

    EscBufPos = 1
    Lexer.Pos = StartPos
    while Lexer.Pos ~= EndPos do
        local CurChar
        CurChar, Lexer.Pos = LexUnEscapeCharacter(Lexer.SourceText,
            Lexer.Pos, EndPos)
        --print("Byte:", string.byte(CurChar), CurChar)
        EscBuf.Str = EscBuf.Str .. CurChar
        EscBufPos = EscBufPos + 1
    end

    RegString = TableStrRegister2(pc, EscBuf.Str, EscBufPos - 1)
    HeapPopStack(pc, 1, EscBuf.StackId - 1)
    ArrayValue = VariableStringLiteralGet(pc, RegString)
    if ArrayValue == nil then
        ArrayValue = VariableAllocValueAndData(pc, nil, 0, false, nil, true)
        ArrayValue.Typ = pc.CharArrayType
        ArrayValue.Val = RegString
        VariableStringLiteralDefine(pc, RegString, ArrayValue)
    end

    Value.Typ = pc.CharPtrType
    --print(Value.Val.Ident, " ", RegString.RawValue.Val)
    PointerReference(Value.Val, RegString)
    if GET_LEXER_CHAR(Lexer) == EndChar then
        LEXER_INC(Lexer)
    end

    return LexToken.TokenStringConstant
end

function LexGetCharacterConstant(pc, Lexer, Value)
    Value.Typ = pc.CharType
    Value.Val.RawValue.Val, Lexer.Pos = LexUnEscapeCharacter(Lexer.SourceText,
            Lexer.Pos, Lexer.End)
    if Lexer.Pos ~= Lexer.End and GET_LEXER_CHAR(Lexer) ~= "'" then
        LexFail(pc, Lexer, "expected \"'\"")
    end

    LEXER_INC(Lexer)
    return LexToken.TokenCharacterConstant
end

function LexSkipComment(Lexer, NextChar)
    if NextChar == '*' then
        while (Lexer.Pos ~= Lexer.End and
            (GET_LEXER_CHAR_AT(Lexer, Lexer.Pos - 1) ~= '*' or
            GET_LEXER_CHAR(Lexer) ~= '/')) do
            if GET_LEXER_CHAR(Lexer) == '\n' then
                Lexer.EmitExtraNewlines = Lexer.EmitExtraNewlines + 1
            end
            LEXER_INC(Lexer)
        end

        if Lexer.Pos ~= Lexer.End then
            LEXER_INC(Lexer)
        end

        Lexer.Mode = LexMode.LexModeNormal
    else
        while Lexer.Pos ~= Lexer.End and GET_LEXER_CHAR(Lexer) ~= '\n' do
            LEXER_INC(Lexer)
        end
    end
end

function LexSkipLineCont(Lexer, NextChar)
    while Lexer.Pos ~= Lexer.End and GET_LEXER_CHAR(Lexer) ~= '\n' do
        LEXER_INC(Lexer)
    end
end

function LexScanGetToken(pc, Lexer, InitValue)
    local ThisChar, NextChar
    local GotToken = LexToken.TokenNone
    local Value = InitValue

    if Lexer.EmitExtraNewlines > 0 then
        Lexer.EmitExtraNewlines = Lexer.EmitExtraNewlines - 1
        return LexToken.TokenEndOfLine, Value
    end

    repeat
        LexResetLexValue(pc)
        Value = pc.LexValue

        while Lexer.Pos ~= Lexer.End and IsSpace(GET_LEXER_CHAR(Lexer)) do
            if GET_LEXER_CHAR(Lexer) == '\n' then
                Lexer.Line = Lexer.Line + 1
                Lexer.Pos = Lexer.Pos + 1
                Lexer.Mode = LexMode.LexModeNormal
                Lexer.CharacterPos = 0
                return LexToken.TokenEndOfLine, Value
            elseif (Lexer.Mode == LexMode.LexModeHashDefine or
                Lexer.Mode == LexMode.LexModeHashDefineSpace) then
                Lexer.Mode = LexMode.LexModeHashDefineSpace
            elseif Lexer.Mode == LexMode.LexModeHashDefineSpaceIdent then
                Lexer.Mode = LexMode.LexModeNormal
            end

            LEXER_INC(Lexer)
        end

        --print(Lexer.Pos)
        if Lexer.Pos == Lexer.End or GET_LEXER_CHAR(Lexer) == "" then
            return LexToken.TokenEOF, Value
        end

        ThisChar = GET_LEXER_CHAR(Lexer)
        if IsCidstart(ThisChar) then
            local Result = LexGetWord(pc, Lexer, Value)
            return Result, Value
        end

        if IsDigit(ThisChar) then
            local Result = LexGetNumber(pc, Lexer, Value)
            return Result, Value
        end

        if Lexer.Pos + 1 ~= Lexer.End then
            NextChar = GET_LEXER_CHAR_AT(Lexer, Lexer.Pos + 1)
        else
            NextChar = '\0'
        end
        LEXER_INC(Lexer)
        if ThisChar == '"' then
            GotToken = LexGetStringConstant(pc, Lexer, Value, '"')
        elseif ThisChar == "'" then
            GotToken = LexGetCharacterConstant(pc, Lexer, Value)
        elseif ThisChar == '(' then
            if Lexer.Mode == LexMode.LexModeHashDefineSpaceIdent then
                GotToken = LexToken.TokenOpenMacroBracket
            else
                GotToken = LexToken.TokenOpenBracket
            end
            Lexer.Mode = LexMode.LexModeNormal
        elseif ThisChar == ')' then
            GotToken = LexToken.TokenCloseBracket
        elseif ThisChar == '=' then
            GotToken = NEXTIS('=', LexToken.TokenEqual, LexToken.TokenAssign, NextChar, Lexer)
        elseif ThisChar == '+' then
            GotToken = NEXTIS3('=', LexToken.TokenAddAssign, '+',
                LexToken.TokenIncrement, LexToken.TokenPlus, NextChar, Lexer)
        elseif ThisChar == '-' then
            GotToken = NEXTIS4('=', LexToken.TokenSubtractAssign, '>',
                LexToken.TokenArrow, '-', LexToken.TokenDecrement, LexToken.TokenMinus, NextChar, Lexer)
        elseif ThisChar == '*' then
            GotToken = NEXTIS('=', LexToken.TokenMultiplyAssign, LexToken.TokenAsterisk, NextChar, Lexer)
        elseif ThisChar == '/' then
            if NextChar == '/' or NextChar == '*' then
                LEXER_INC(Lexer)
                LexSkipComment(Lexer, NextChar)
            else
                GotToken = NEXTIS('=', LexToken.TokenDivideAssign, LexToken.TokenSlash, NextChar, Lexer)
            end
        elseif ThisChar == '%' then
            GotToken = NEXTIS('=', LexToken.TokenModulusAssign, LexToken.TokenModulus, NextChar, Lexer)
        elseif ThisChar == '<' then
            if Lexer.Mode == LexMode.LexModeHashInclude then
                GotToken = LexGetStringConstant(pc, Lexer, Value, '>')
            else
                GotToken = NEXTIS3PLUS('=', LexToken.TokenLessEqual, '<', LexToken.TokenShiftLeft, '=',
                    LexToken.TokenShiftLeftAssign, LexToken.TokenLessThan, NextChar, Lexer)
            end
        elseif ThisChar == '>' then
            GotToken = NEXTIS3PLUS('=', LexToken.TokenGreaterEqual, '>', LexToken.TokenShiftRight, '=',
                    LexToken.TokenShiftRightAssign, LexToken.TokenGreaterThan, NextChar, Lexer)
        elseif ThisChar == ';' then
            GotToken = LexToken.TokenSemicolon
        elseif ThisChar == '&' then
            GotToken = NEXTIS3('=', LexToken.TokenArithmeticAndAssign, '&', LexToken.TokenLogicalAnd,
                LexToken.TokenAmpersand, NextChar, Lexer)
        elseif ThisChar == '|' then
            GotToken = NEXTIS3('=', LexToken.TokenArithmeticOrAssign, '|', LexToken.TokenLogicalOr,
                LexToken.TokenArithmeticOr, NextChar, Lexer)
        elseif ThisChar == '{' then
            GotToken = LexToken.TokenLeftBrace
        elseif ThisChar == '}' then
            GotToken = LexToken.TokenRightBrace
        elseif ThisChar == '[' then
            GotToken = LexToken.TokenLeftSquareBracket
        elseif ThisChar == ']' then
            GotToken = LexToken.TokenRightSquareBracket
        elseif ThisChar == '!' then
            GotToken = NEXTIS('=', LexToken.TokenNotEqual, LexToken.TokenUnaryNot, NextChar, Lexer)
        elseif ThisChar == '^' then
            GotToken = NEXTIS('=', LexToken.TokenArithmeticExorAssign, LexToken.TokenArithmeticExor,
                NextChar, Lexer)
        elseif ThisChar == '~' then
            GotToken = LexToken.TokenUnaryExor
        elseif ThisChar == ',' then
            GotToken = LexToken.TokenComma
        elseif ThisChar == '.' then
            GotToken = NEXTISEXACTLY3('.', '.', LexToken.TokenEllipsis,
                LexToken.TokenDot, NextChar, Lexer)
        elseif ThisChar == '?' then
            GotToken = LexToken.TokenQuestionMark
        elseif ThisChar == ':' then
            GotToken = LexToken.TokenColon
        elseif ThisChar == '\\' then
            if NextChar == ' ' or NextChar == '\n' then
                LEXER_INC(Lexer)
                LexSkipLineCont(Lexer, NextChar)
            else
                LexFail(pc, Lexer, "illegal character '%c'", ThisChar)
            end
        else
            LexFail(pc, Lexer, "illegal character '%c'", ThisChar)
        end
    until GotToken ~= LexToken.TokenNone

    return GotToken, Value
end

-- Return value of this function is disregarded:
-- just indicates a token has value if it does not return 0
function LexTokenSize(Token)
    if Token == LexToken.TokenIdentifier or Token == LexToken.TokenStringConstant then
        return 4
    elseif Token == LexToken.TokenIntegerConstant then
        return 4
    elseif Token == LexToken.TokenCharacterConstant then
        return 1
    elseif Token == LexToken.TokenFPConstant then
        return 8
    else
        return 0
    end
end

function LexTokenize(pc, Lexer)
    local MemUsed = 0
    local ValueSize
    local LastCharacterPos = 0
    local HeapMem
    --local TokenSpace = HeapAllocStack(pc)
    local TokenSpace = {}
    local Token
    local GotValue
    local TokenPos = 1
    local TokenLen

    if TokenSpace == nil then
        LexFail(pc, Lexer, "(LexTokenize TokenSpace == NULL) out of memory")
    end

    repeat
        Token, GotValue = LexScanGetToken(pc, Lexer, GotValue)
        --if Debug then
        --    io.write("" .. Token .. " ")
        --end

        TokenSpace[TokenPos] = Token
        TokenPos = TokenPos + 1
        MemUsed = MemUsed + 1

        -- Confine to 0xFF
        TokenSpace[TokenPos] = LastCharacterPos % 0x100
        TokenPos = TokenPos + 1
        MemUsed = MemUsed + 1

        ValueSize = LexTokenSize(Token)
        if ValueSize > 0 then
            if Token == LexToken.TokenIdentifier then
                TokenSpace[TokenPos] = GotValue.Val
            else
                TokenSpace[TokenPos] = PointerCopyAllValues(GotValue.Val, true)
                TokenSpace[TokenPos].RawValue.Val =
                    string.sub(TokenSpace[TokenPos].RawValue.Val, 1, ValueSize)
            end
            TokenPos = TokenPos + 1
            MemUsed = MemUsed + 1
        end

        LastCharacterPos = Lexer.CharacterPos
    until Token == LexToken.TokenEOF

    --[[
    HeapMem = {}
    if HeapMem == nil then
        LexFail(pc, Lexer, "(LexTokenize HeapMem == NULL) out of memory")
    end

    for k in pairs(TokenSpace) do
        HeapMem[k] = TokenSpace[k]
    end
    HeapPopStack(pc, 1, TokenSpace.StackId - 1)
    --]]

    TokenLen = MemUsed
    --return HeapMem, TokenLen
    return TokenSpace, TokenLen
end

function LexAnalyse(pc, FileName, Source, SourceLen)
    local Lexer = {}

    Lexer.Pos = 1
    Lexer.End = 1 + SourceLen
    Lexer.Line = 1
    Lexer.FileName = FileName
    Lexer.Mode = LexMode.LexModeNormal
    Lexer.EmitExtraNewlines = 0
    Lexer.CharacterPos = 1
    Lexer.SourceText = Source

    return LexTokenize(pc, Lexer)
end

function LexInitParser(Parser, pc, SourceText, TokenSource, FileName, RunIt, EnableDebugger)
    Parser.pc = pc
    Parser.ParsingTokens = TokenSource
    Parser.Pos = 1
    Parser.Line = 1
    Parser.FileName = FileName
    if RunIt then
        Parser.Mode = RunMode.RunModeRun
    else
        Parser.Mode = RunMode.RunModeSkip
    end
    Parser.SearchLabel = 0
    Parser.HashIfLevel = 0
    Parser.HashIfEvaluateToLevel = 0
    Parser.CharacterPos = 0
    Parser.SourceText = SourceText
    Parser.DebugMode = EnableDebugger
end

function LexGetRawToken(Parser, InitValue, IncPos)
    local ValueSize
    local Prompt
    local Token = LexToken.TokenNone
    local pc = Parser.pc
    local Value = InitValue

    repeat
        if Parser.ParsingTokens == nil and pc.InteractiveHead ~= nil then
            Parser.ParsingTokens = pc.InteractiveHead.Tokens
            Parser.Pos = 1
        end

        if Parser.FileName ~= pc.StrEmpty or pc.InteractiveHead ~= nil then
            Token = GET_PARSING(Parser)
            while Token == LexToken.TokenEndOfLine do
                Parser.Line = Parser.Line + 1
                Parser.Pos = Parser.Pos + TOKEN_DATA_OFFSET
                Token = GET_PARSING(Parser)
            end
        end

        -- If block will not be executed if interactive is off
        if (Parser.FileName == pc.StrEmpty and
            (pc.InteractiveHead == nil or Token == LexToken.TokenEOF)) then
            local LineBuffer
            local LineTokens
            local LineBytes
            local LineNode

            if (pc.InteractiveHead == nil or (
                Parser.ParsingTokens == pc.InteractiveTail.Tokens and
                Parser.Pos == pc.InteractiveTail.NumBytes - TOKEN_DATA_OFFSET + 1)) then
                if pc.LexUseStatementPrompt then
                    Prompt = INTERACTIVE_PROMPT_STATEMENT
                    pc.LexUseStatementPrompt = false
                else
                    Prompt = INTERACTIVE_PROMPT_LINE
                end

                LineBuffer = PlatformGetLine(LINEBUFFER_MAX, Prompt)
                if LineBuffer == nil then
                    return LexToken.TokenEOF, Value
                end

                LineTokens, LineBytes = LexAnalyse(pc, pc.StrEmpty, LineBuffer,
                    string.len(LineBuffer))
                LineNode = VariableAlloc(pc, Parser, true)
                LineNode.Tokens = LineTokens
                LineNode.NumBytes = LineBytes
                if pc.InteractiveHead == nil then
                    pc.InteractiveHead = LineNode
                    Parser.Line = 1
                    Parser.CharacterPos = 0
                else
                    pc.InteractiveTail.Next = LineNode
                end

                pc.InteractiveTail = LineNode
                pc.InteractiveCurrentLine = LineNode
                Parser.ParsingTokens = LineTokens
                Parser.Pos = 1
            else
                if (Parser.ParsingTokens ~= pc.InteractiveCurrentLine.Tokens or
                    Parser.Pos ~= pc.InteractiveCurrentLine.NumBytes - TOKEN_DATA_OFFSET + 1) then
                    pc.InteractiveCurrentLine = pc.InteractiveHead
                    while (Parser.ParsingTokens ~= pc.InteractiveCurrentLine.Tokens or
                        Parser.Pos ~= pc.InteractiveCurrentLine.NumBytes - TOKEN_DATA_OFFSET + 1) do
                        assert(pc.InteractiveCurrentLine.Next ~= nil, "LexGetRawToken: Next of InteractiveCurrentLine is nil")
                        pc.InteractiveCurrentLine = pc.InteractiveCurrentLine.Next
                    end
                end

                assert(pc.InteractiveCurrentLine ~= nil, "LexGetRawToken: InteractiveCurrentLine is nil")
                pc.InteractiveCurrentLine = pc.InteractiveCurrentLine.Next
                assert(pc.InteractiveCurrentLine ~= nil, "LexGetRawToken: InteractiveCurrentLine is nil")
                Parser.ParsingTokens = pc.InteractiveCurrentLine.Tokens
                Parser.Pos = 1
            end

            Token = GET_PARSING(Parser)
        end
    until not ((Parser.FileName == pc.StrEmpty and Token == LexToken.TokenEOF) or
        Token == LexToken.TokenEndOfLine)

    Parser.CharacterPos = GET_PARSING_AT(Parser, Parser.Pos + 1)

    ValueSize = LexTokenSize(Token)
    if ValueSize > 0 then
        --if Value ~= nil then
        if true then
            if Token == LexToken.TokenStringConstant then
                pc.LexValue.Typ = pc.CharPtrType
            elseif Token == LexToken.TokenIdentifier then
                pc.LexValue.Typ = nil
            elseif Token == LexToken.TokenIntegerConstant then
                pc.LexValue.Typ = pc.LongType
            elseif Token == LexToken.TokenCharacterConstant then
                pc.LexValue.Typ = pc.CharType
            elseif Token == LexToken.TokenFPConstant then
                pc.LexValue.Typ = pc.FPType
            end

            local LexValueVal = GET_PARSING_AT(Parser, Parser.Pos + TOKEN_DATA_OFFSET)

            if Token == LexToken.TokenIdentifier then
                pc.LexValue.Val = LexValueVal
            else
                pc.LexValue.Val = PointerCopyAllValues(LexValueVal, true)
            end
            pc.LexValue.ValOnHeap = false
            pc.LexValue.ValOnStack = false
            pc.LexValue.IsLValue = false
            pc.LexValue.LValueFrom = nil
            Value = pc.LexValue
        end

        if IncPos then
            Parser.Pos = Parser.Pos + 1 + TOKEN_DATA_OFFSET
        end
    else
        if IncPos and Token ~= LexToken.TokenEOF then
            Parser.Pos = Parser.Pos + TOKEN_DATA_OFFSET
        end
    end

    assert(Token >= LexToken.TokenNone and Token <= LexToken.TokenEndOfFunction, "LexGetRawToken: Function ends with illegal token")
    return Token, Value
end

function LexHashIncPos(Parser, IncPos)
    if not IncPos then
        LexGetRawToken(Parser, nil, true)
    end
end

function LexHashIfdef(Parser, IfNot)
    local IsDefined
    local IdentValue
    local SavedValue
    local Token
    Token, IdentValue = LexGetRawToken(Parser, IdentValue, true)

    if Token ~= LexToken.TokenIdentifier then
        ProgramFail(Parser, "identifier expected")
    end

    IsDefined, SavedValue, _, _, _ = TableGet(Parser.pc.GlobalTable, IdentValue.Val)    -- Changed from IdentValue.Val.Identifier
    if (Parser.HashIfEvaluateToLevel == Parser.HashIfLevel and
        ((IsDefined and not IfNot) or (not IsDefined and IfNot))) then
        Parser.HashIfEvaluateToLevel = Parser.HashIfEvaluateToLevel + 1
    end

    Parser.HashIfLevel = Parser.HashIfLevel + 1
end

function LexHashIf(Parser)
    local IdentValue
    local SavedValue
    local MacroParser = {}
    local Token
    Token, IdentValue = LexGetRawToken(Parser, IdentValue, true)

    if Token == LexToken.TokenIdentifier then
        local Success
        Success, SavedValue, _, _, _ = TableGet(Parser.pc.GlobalTable, IdentValue.Val)  -- Changed from IdentValue.Val.Identifier
        if not Success then
            ProgramFail(Parser, "'%s' is undefined", IdentValue.Val.RawValue.Val) -- Changed from IdentValue.Val.Identifier
        end

        if SavedValue.Typ.Base ~= BaseType.TypeMacro then
            ProgramFail(Parser, "value expected")
        end

        ParserCopy(MacroParser, SavedValue.Val.MacroDef.Body)
        Token, IdentValue = LexGetRawToken(MacroParser, IdentValue, true)
    end

    if Token ~= LexToken.TokenCharacterConstant and Token ~= LexToken.TokenIntegerConstant then
        ProgramFail(Parser, "value expected")
    end

    local Cond = C_INT_TO_LUA_BOOLEAN(PointerGetSignedChar(IdentValue.Val))
    if Parser.HashIfEvaluateToLevel == Parser.HashIfLevel and Cond then
        Parser.HashIfEvaluateToLevel = Parser.HashIfEvaluateToLevel + 1
    end

    Parser.HashIfLevel = Parser.HashIfLevel + 1
end

function LexHashElse(Parser)
    if Parser.HashIfEvaluateToLevel == Parser.HashIfLevel - 1 then
        Parser.HashIfEvaluateToLevel = Parser.HashIfEvaluateToLevel + 1
    elseif Parser.HashIfEvaluateToLevel == Parser.HashIfLevel then
        if Parser.HashIfLevel == 0 then
            ProgramFail(Parser, "#else without #if")
        end

        Parser.HashIfEvaluateToLevel = Parser.HashIfEvaluateToLevel - 1
    end
end

function LexHashEndif(Parser)
    if Parser.HashIfLevel == 0 then
        ProgramFail(Parser, "#endif without #if")
    end

    Parser.HashIfLevel = Parser.HashIfLevel - 1
    if Parser.HashIfEvaluateToLevel > Parser.HashIfLevel then
        Parser.HashIfEvaluateToLevel = Parser.HashIfLevel
    end
end

function LexGetToken(Parser, InitValue, IncPos)
    local TryNextToken
    local Token
    local Value = InitValue

    repeat
        local WasPreProcToken = true

        Token, Value = LexGetRawToken(Parser, Value, IncPos)
        if Token == LexToken.TokenHashIfdef then
            LexHashIncPos(Parser, IncPos)
            LexHashIfdef(Parser, false)
        elseif Token == LexToken.TokenHashIfndef then
            LexHashIncPos(Parser, IncPos)
            LexHashIfdef(Parser, true)
        elseif Token == LexToken.TokenHashIf then
            LexHashIncPos(Parser, IncPos)
            LexHashIf(Parser)
        elseif Token == LexToken.TokenHashElse then
            LexHashIncPos(Parser, IncPos)
            LexHashElse(Parser)
        elseif Token == LexToken.TokenHashEndif then
            LexHashIncPos(Parser, IncPos)
            LexHashEndif(Parser)
        else
            WasPreProcToken = false
        end

        TryNextToken = ((Parser.HashIfEvaluateToLevel < Parser.HashIfLevel and
            Token ~= LexToken.TokenEOF) or WasPreProcToken)
        if not IncPos and TryNextToken then
            LexGetRawToken(Parser, nil, true)
        end
    until not TryNextToken

    return Token, Value
end

function LexRawPeekToken(Parser)
    return GET_PARSING(Parser)
end

function LexToEndOfMacro(Parser)
    local isContinued = false
    while true do
        local Token = GET_PARSING(Parser)
        if Token == LexToken.TokenEOF then
            return
        elseif Token == LexToken.TokenEndOfLine then
            if not isContinued then
                return
            end
            isContinued = false
        end
        if Token == LexToken.TokenBackSlash then
            isContinued = true
        end
        LexGetRawToken(Parser, nil, true)
    end
end

function LexCopyTokens(StartParser, EndParser)
    local EndPos
    local ParsingTokens = StartParser.ParsingTokens
    local EndParsingTokens = EndParser.ParsingTokens
    local NewTokens
    local ILine
    local pc = StartParser.pc

    if pc.InteractiveHead == nil then
        NewTokens = {}
        for i = StartParser.Pos, EndParser.Pos - 1 do
            table.insert(NewTokens, ParsingTokens[i])
        end
    else
        pc.InteractiveCurrentLine = pc.InteractiveHead
        while (pc.InteractiveCurrentLine ~= nil and
            ParsingTokens ~= pc.InteractiveCurrentLine.Tokens) do
            pc.InteractiveCurrentLine = pc.InteractiveCurrentLine.Next
        end

        if EndParsingTokens == ParsingTokens then
            NewTokens = {}
            for i = StartParser.Pos, EndParser.Pos - 1 do
                table.insert(NewTokens, ParsingTokens[i])
            end
        else
            EndPos = pc.InteractiveCurrentLine.NumBytes - TOKEN_DATA_OFFSET + 1
            NewTokens = {}
            for i = StartParser.Pos, EndPos - 1 do
                table.insert(NewTokens, ParsingTokens[i])
            end
            ILine = pc.InteractiveCurrentLine.Next
            while ILine ~= nil and EndParsingTokens ~= ILine.Tokens do
                for i = 1, ILine.NumBytes - TOKEN_DATA_OFFSET do
                    table.insert(NewTokens, ILine.Tokens[i])
                end
                ILine = ILine.Next
            end
            assert(ILine ~= nil, "LexCopyTokens: ILine is null")
            for i = 1, EndParser.Pos - 1 do
                table.insert(NewTokens, ILine.Tokens[i])
            end
        end
    end

    table.insert(NewTokens, LexToken.TokenEndOfFunction)
    table.insert(NewTokens, 0)

    return NewTokens
end

function LexInteractiveClear(pc, Parser)
    while pc.InteractiveHead ~= nil do
        pc.InteractiveHead = pc.InteractiveHead.Next
    end

    if Parser ~= nil then
        Parser.ParsingTokens = nil
    end

    pc.InteractiveTail = nil
end

function LexInteractiveCompleted(pc, Parser)
    while (pc.InteractiveHead ~= nil and
        Parser.ParsingTokens ~= pc.InteractiveHead.Tokens) do
        pc.InteractiveHead = pc.InteractiveHead.Next

        if pc.InteractiveHead == nil then
            Parser.ParsingTokens = nil
            pc.InteractiveTail = nil
        end
    end

end

function LexInteractiveStatementPrompt(pc)
    pc.LexUseStatementPrompt = true
end
GEnableDebugger = false

function ParseCleanup(pc)
end

function ParseStatementMaybeRun(Parser, Condition, CheckTrailingSemicolon)
    if Parser.Mode ~= RunMode.RunModeSkip and not Condition then
        local OldMode = Parser.Mode
        local Result
        Parser.Mode = RunMode.RunModeSkip
        Result = ParseStatement(Parser, CheckTrailingSemicolon)
        Parser.Mode = OldMode
        return Result
    else
        return ParseStatement(Parser, CheckTrailingSemicolon)
    end
end

function ParseCountParams(Parser)
    local ParamCount = 0

    local Token
    Token, _ = LexGetToken(Parser, nil, true)
    if Token ~= LexToken.TokenCloseBracket and Token ~= LexToken.TokenEOF then
        ParamCount = ParamCount + 1
        Token, _ = LexGetToken(Parser, nil, true)
        while Token ~= LexToken.TokenCloseBracket and Token ~= LexToken.TokenEOF do
            if Token == LexToken.TokenComma then
                ParamCount = ParamCount + 1
            end
            Token, _ = LexGetToken(Parser, nil, true)
        end
    end

    return ParamCount
end

function ParseFunctionDefinition(Parser, ReturnType, Identifier)
    local ParamCount = 0
    local ParamIdentifier
    local Token = LexToken.TokenNone
    local Tok
    local ParamType
    local ParamParser = {}
    local FuncValue
    local OldFuncValue
    local FuncBody = {}
    local pc = Parser.pc

    if pc.TopStackFrameId ~= 0 then
        ProgramFail(Parser, "nested function definitions are not allowed")
    end

    LexGetToken(Parser, nil, true)
    ParserCopy(ParamParser, Parser)
    ParamCount = ParseCountParams(Parser)
    if ParamCount > PARAMETER_MAX then
        ProgramFail(Parser, "too many parameters (%d allowed)", PARAMETER_MAX)
    end

    -- RawValue is not used, so DataSize is of no use
    FuncValue = VariableAllocValueAndData(pc, Parser, 0, false, nil, true)
    FuncValue.Typ = pc.FunctionType
    FuncValue.Val.FuncDef.ReturnType = ReturnType
    FuncValue.Val.FuncDef.NumParams = ParamCount
    FuncValue.Val.FuncDef.VarArgs = false
    FuncValue.Val.FuncDef.ParamType = {}
    FuncValue.Val.FuncDef.ParamName = {}

    ParamCount = 1
    while ParamCount <= FuncValue.Val.FuncDef.NumParams do
        Tok, _ = LexGetToken(ParamParser, nil, false)
        if ParamCount == FuncValue.Val.FuncDef.NumParams and Tok == LexToken.TokenEllipsis then
            FuncValue.Val.FuncDef.NumParams = FuncValue.Val.FuncDef.NumParams - 1
            FuncValue.Val.FuncDef.VarArgs = true
            break
        else
            ParamType, ParamIdentifier, _ = TypeParse(ParamParser)
            if ParamType.Base == BaseType.TypeVoid then
                FuncValue.Val.FuncDef.NumParams = FuncValue.Val.FuncDef.NumParams - 1
            else
                FuncValue.Val.FuncDef.ParamType[ParamCount] = ParamType
                FuncValue.Val.FuncDef.ParamName[ParamCount] = ParamIdentifier
            end
        end

        Token, _ = LexGetToken(ParamParser, nil, true)
        if Token ~= LexToken.TokenComma and ParamCount < FuncValue.Val.FuncDef.NumParams then
            ProgramFail(ParamParser, "comma expected")
        end

        ParamCount = ParamCount + 1
    end

    if (FuncValue.Val.FuncDef.NumParams ~= 0 and Token ~= LexToken.TokenCloseBracket and
        Token ~= LexToken.TokenComma and Token ~= LexToken.TokenEllipsis) then
        ProgramFail(ParamParser, "bad parameter")
    end

    if Identifier.RawValue.Val == "main" then
        if (FuncValue.Val.FuncDef.ReturnType ~= pc.IntType and
            FuncValue.Val.FuncDef.ReturnType ~= pc.VoidType) then
            ProgramFail(Parser, "main() should return an int or void")
        end

        if (FuncValue.Val.FuncDef.NumParams ~= 0 and
            (FuncValue.Val.FuncDef.NumParams ~= 2 or
            FuncValue.Val.FuncDef.ParamType[1] ~= pc.IntType)) then
            ProgramFail(Parser, "bad parameters to main()")
        end
    end

    Token, _ = LexGetToken(Parser, nil, false)
    if Token == LexToken.TokenSemicolon then
        LexGetToken(Parser, nil, true)
    else
        if Token ~= LexToken.TokenLeftBrace then
            ProgramFail(Parser, "bad function definition")
        end

        ParserCopy(FuncBody, Parser)
        if ParseStatementMaybeRun(Parser, false, true) ~= ParserResult.ParseResultOk then
            ProgramFail(Parser, "function definition expected")
        end

        FuncValue.Val.FuncDef.Body = FuncBody
        FuncValue.Val.FuncDef.Body.ParsingTokens = LexCopyTokens(FuncBody, Parser)
        FuncValue.Val.FuncDef.Body.Pos = 1

        local Success
        Success, OldFuncValue, _, _, _ = TableGet(pc.GlobalTable, Identifier)
        if Success then
            if OldFuncValue.Val.FuncDef.Body.ParsingTokens == nil then
                VariableFree(pc, TableDelete(pc, pc.GlobalTable, Identifier))
            else
                ProgramFail(Parser, "'%s' is already defined", Identifier.RawValue.Val)
            end
        end
    end

    if (not TableSet(pc, pc.GlobalTable, Identifier, FuncValue,
        Parser.FileName, Parser.Line, Parser.CharacterPos)) then
            ProgramFail(Parser, "'%s' is already defined", Identifier.RawValue.Val)
    end

    return FuncValue
end

function ParseArrayInitializer(Parser, NewVariable, DoAssignment)
    local ArrayIndex = 0
    local Token
    local CValue

    if DoAssignment and Parser.Mode == RunMode.RunModeRun then
        local CountParser = {}
        local NumElements

        ParserCopy(CountParser, Parser)
        NumElements = ParseArrayInitializer(CountParser, NewVariable, false)

        if NewVariable.Typ.Base ~= BaseType.TypeArray then
            AssignFail(Parser, "%t from array initializer", NewVariable.Typ,
                nil, 0, 0, nil, 0)
        end

        if NewVariable.Typ.ArraySize == 0 then
            NewVariable.Typ = TypeGetMatching(Parser.pc, Parser,
                NewVariable.Typ.FromType, NewVariable.Typ.Base, NumElements,
                NewVariable.Typ.Identifier, true)
            VariableRealloc(Parser, NewVariable, TypeSizeValue(NewVariable, false))
        end
    end

    Token, _ = LexGetToken(Parser, nil, false)
    while Token ~= LexToken.TokenRightBrace do
        local Tok
        Tok, _ = LexGetToken(Parser, nil, false)
        if Tok == LexToken.TokenLeftBrace then
            local SubArraySize = 0
            local SubArray = NewVariable
            if Parser.Mode == RunMode.RunModeRun and DoAssignment then
                SubArraySize = TypeSize(NewVariable.Typ.FromType,
                    NewVariable.Typ.FromType.ArraySize, true)
                local SubArrayVal = {}
                PointerDeriveNewValue(SubArrayVal, NewVariable.Val, true)
                SubArrayVal.Offset = SubArrayVal.Offset + SubArraySize * ArrayIndex
                SubArray = VariableAllocValueFromExistingData(Parser,
                    NewVariable.Typ.FromType, SubArrayVal, true, NewVariable)

                if ArrayIndex >= NewVariable.Typ.ArraySize then
                    ProgramFail(Parser, "too many array elements")
                end
            end
            LexGetToken(Parser, nil, true)
            ParseArrayInitializer(Parser, SubArray, DoAssignment)
        else
            local ArrayElement = nil

            if Parser.Mode == RunMode.RunModeRun and DoAssignment then
                local ElementType = NewVariable.Typ
                local TotalSize = 1
                local ElementSize = 0

                while ElementType.Base == BaseType.TypeArray do
                    TotalSize = TotalSize * ElementType.ArraySize
                    ElementType = ElementType.FromType

                    local Tok1
                    Tok1, _ = LexGetToken(Parser, nil, false)
                    if (Tok1 == LexToken.TokenStringConstant and
                        ElementType.FromType.Base == BaseType.TypeChar) then
                        break
                    end
                end
                ElementSize = TypeSize(ElementType, ElementType.ArraySize, true)

                if ArrayIndex >= TotalSize then
                    ProgramFail(Parser, "too many array elements")
                end
                local ArrayElementVal = {}
                PointerDeriveNewValue(ArrayElementVal, NewVariable.Val, true)
                ArrayElementVal.Offset = ArrayElementVal.Offset + ElementSize * ArrayIndex
                ArrayElement = VariableAllocValueFromExistingData(Parser, ElementType,
                    ArrayElementVal, true, NewVariable)
            end

            local Success
            Success, CValue = ExpressionParse(Parser)
            if not Success then
                ProgramFail(Parser, "expression expected")
            end

            if Parser.Mode == RunMode.RunModeRun and DoAssignment then
                ExpressionAssign(Parser, ArrayElement, CValue, false, nil, 0, false)
                --print(PointerGetString(ArrayElement.Val))
                VariableStackPop(Parser, CValue)
                VariableStackPop(Parser, ArrayElement)
            end
        end

        ArrayIndex = ArrayIndex + 1

        Token, _ = LexGetToken(Parser, nil, false)
        if Token == LexToken.TokenComma then
            LexGetToken(Parser, nil, true)
            Token, _ = LexGetToken(Parser, nil, false)
        elseif Token ~= LexToken.TokenRightBrace then
            ProgramFail(Parser, "comma expected")
        end
    end

    if Token == LexToken.TokenRightBrace then
        LexGetToken(Parser, nil, true)
    else
        ProgramFail(Parser, "'}' expected")
    end

    return ArrayIndex
end

function ParseDeclarationAssignment(Parser, NewVariable, DoAssignment)
    local CValue
    local Tok

    --if Debug then
    --    print("ParseDeclarationAssignment Enter")
    --end

    Tok, _ = LexGetToken(Parser, nil, false)
    if Tok == LexToken.TokenLeftBrace then
        LexGetToken(Parser, nil, true)
        ParseArrayInitializer(Parser, NewVariable, DoAssignment)
    else
        local Success
        Success, CValue = ExpressionParse(Parser)
        if not Success then
            ProgramFail(Parser, "expression expected")
        end

        if Parser.Mode == RunMode.RunModeRun and DoAssignment then
            --print(ExpressionCoerceInteger(CValue))
            --print(NewVariable.Typ.Base)
            ExpressionAssign(Parser, NewVariable, CValue, false, nil, 0, false)
            VariableStackPop(Parser, CValue)
        end
    end
end

function ParseDeclaration(Parser, Token)
    --if Debug then
    --    print("ParseDeclaration Enter")
    --end
    local IsStatic = false
    local FirstVisit = false
    local Identifier
    local BasicType
    local Typ
    local NewVariable = nil
    local pc = Parser.pc

    _, BasicType, IsStatic = TypeParseFront(Parser)

    repeat
        Typ, Identifier = TypeParseIdentPart(Parser, BasicType)
        if (Token ~= LexToken.TokenVoidType and Token ~= LexToken.TokenStructType and
            Token ~= LexToken.TokenUnionType and Token ~= LexToken.TokenEnumType and
            Identifier == pc.StrEmpty) then
            ProgramFail(Parser, "identifier expected")
        end

        if Identifier ~= pc.StrEmpty then
            local Tok
            Tok, _ = LexGetToken(Parser, nil, false)
            if Tok == LexToken.TokenOpenBracket then
                --if Debug then
                --    print("Define", Identifier.RawValue.Val)
                --end
                ParseFunctionDefinition(Parser, Typ, Identifier)
                return false
            else
                if Typ == pc.VoidType and Identifier ~= pc.StrEmpty then
                    ProgramFail(Parser, "can't define a void variable")
                end

                if Parser.Mode == RunMode.RunModeRun or Parser.Mode == RunMode.RunModeGoto then
                    --if Debug then
                    --    print("Define", Identifier.RawValue.Val)
                    --end
                    NewVariable, FirstVisit = VariableDefineButIgnoreIdentical(Parser,
                        Identifier, Typ, IsStatic)
                end

                Tok, _ = LexGetToken(Parser, nil, false)
                if Tok == LexToken.TokenAssign then
                    --if Debug then
                    --    print("Assign")
                    --end
                    LexGetToken(Parser, nil, true)
                    ParseDeclarationAssignment(Parser, NewVariable,
                        (not IsStatic) or FirstVisit)
                end
            end
        end

        Token, _ = LexGetToken(Parser, nil, false)
        if Token == LexToken.TokenComma then
            LexGetToken(Parser, nil, true)
        end
    until Token ~= LexToken.TokenComma

    return true
end

function ParseMacroDefinition(Parser)
    local MacroNameStr
    local MacroName
    local ParamName
    local MacroValue
    local Tok

    Tok, MacroName = LexGetToken(Parser, MacroName, true)
    if Tok ~= LexToken.TokenIdentifier then
        ProgramFail(Parser, "identifier expected")
    end

    MacroNameStr = MacroName.Val

    if LexRawPeekToken(Parser) == LexToken.TokenOpenMacroBracket then
        local Token
        Token, _ = LexGetToken(Parser, nil, true)
        local ParamParser = {}
        local NumParams
        local ParamCount = 1

        ParserCopy(ParamParser, Parser)
        NumParams = ParseCountParams(ParamParser)
        MacroValue = VariableAllocValueAndData(Parser.pc, Parser,
            0, false, nil, true)
        MacroValue.Val.MacroDef.NumParams = NumParams
        MacroValue.Val.MacroDef.ParamName = {}

        Token, ParamName = LexGetToken(Parser, ParamName, true)
        while Token == LexToken.TokenIdentifier do
            MacroValue.Val.MacroDef.ParamName[ParamCount] =
                ParamName.Val
            ParamCount = ParamCount + 1

            Token, _ = LexGetToken(Parser, nil, true)
            if Token == LexToken.TokenComma then
                Token, ParamName = LexGetToken(Parser, ParamName, true)
            elseif Token ~= LexToken.TokenCloseBracket then
                ProgramFail(Parser, "comma expected")
            end
        end

        if Token ~= LexToken.TokenCloseBracket then
            ProgramFail(Parser, "close bracket expected")
        end
    else
        MacroValue = VariableAllocValueAndData(Parser.pc, Parser,
            0, false, nil, true)
        MacroValue.Val.MacroDef.NumParams = 0
    end

    ParserCopy(MacroValue.Val.MacroDef.Body, Parser)
    MacroValue.Typ = Parser.pc.MacroType
    LexToEndOfMacro(Parser)
    MacroValue.Val.MacroDef.Body.ParsingTokens =
        LexCopyTokens(MacroValue.Val.MacroDef.Body, Parser)
    MacroValue.Val.MacroDef.Body.Pos = 1

    if not TableSet(Parser.pc, Parser.pc.GlobalTable, MacroNameStr, MacroValue,
        Parser.FileName, Parser.Line, Parser.CharacterPos) then
        ProgramFail(Parser, "'%s' is already defined", MacroNameStr.RawValue.Val)
    end
end

function ParserCopy(To, From)
    To.pc = From.pc
    To.Pos = From.Pos
    To.ParsingTokens = From.ParsingTokens
    To.FileName = From.FileName
    To.Line = From.Line
    To.CharacterPos = From.CharacterPos
    To.Mode = From.Mode
    To.SearchLabel = From.SearchLabel
    To.SearchGotoLabel = From.SearchGotoLabel
    To.SourceText = From.SourceText
    To.HashIfLevel = From.HashIfLevel
    To.HashIfEvaluateToLevel = From.HashIfEvaluateToLevel
    To.DebugMode = From.DebugMode
    To.ScopeID = From.ScopeID
end

function ParserCopyPos(To, From)
    To.Pos = From.Pos
    To.ParsingTokens = From.ParsingTokens
    To.Line = From.Line
    To.HashIfLevel = From.HashIfLevel
    To.HashIfEvaluateToLevel = From.HashIfEvaluateToLevel
    To.CharacterPos = From.CharacterPos
end

function ParseFor(Parser)
    local Condition
    local PreConditional = {}
    local PreIncrement = {}
    local PreStatement = {}
    local After = {}

    local OldMode = Parser.Mode

    local PrevScopeID = 0
    local ScopeID
    ScopeID, PrevScopeID = VariableScopeBegin(Parser)

    local Token
    Token, _ = LexGetToken(Parser, nil, true)
    if Token ~= LexToken.TokenOpenBracket then
        ProgramFail(Parser, "'(' expected")
    end

    if ParseStatement(Parser, true) ~= ParserResult.ParseResultOk then
        ProgramFail(Parser, "statement expected")
    end

    ParserCopyPos(PreConditional, Parser)
    Token, _ = LexGetToken(Parser, nil, false)
    if Token == LexToken.TokenSemicolon then
        Condition = true
    else
        Condition = C_INT_TO_LUA_BOOLEAN(ExpressionParseInt(Parser))
    end

    Token, _ = LexGetToken(Parser, nil, true)
    if Token ~= LexToken.TokenSemicolon then
        ProgramFail(Parser, "';' expected")
    end

    ParserCopyPos(PreIncrement, Parser)
    ParseStatementMaybeRun(Parser, false, false)

    Token, _ = LexGetToken(Parser, nil, true)
    if Token ~= LexToken.TokenCloseBracket then
        ProgramFail(Parser, "')' expected")
    end

    ParserCopyPos(PreStatement, Parser)
    if ParseStatementMaybeRun(Parser, Condition, true) ~= ParserResult.ParseResultOk then
        ProgramFail(Parser, "statement expected")
    end

    if Parser.Mode == RunMode.RunModeContinue and OldMode == RunMode.RunModeRun then
        Parser.Mode = RunMode.RunModeRun
    end

    ParserCopyPos(After, Parser)

    while Condition and Parser.Mode == RunMode.RunModeRun do
        ParserCopyPos(Parser, PreIncrement)
        ParseStatement(Parser, false)

        ParserCopyPos(Parser, PreConditional)
        Token, _ = LexGetToken(Parser, nil, false)
        if Token == LexToken.TokenSemicolon then
            Condition = true
        else
            Condition = C_INT_TO_LUA_BOOLEAN(ExpressionParseInt(Parser))
        end

        if Condition then
            ParserCopyPos(Parser, PreStatement)
            ParseStatement(Parser, true)

            if Parser.Mode == RunMode.RunModeContinue then
                Parser.Mode = RunMode.RunModeRun
            end
        end
    end

    if Parser.Mode == RunMode.RunModeBreak and OldMode == RunMode.RunModeRun then
        Parser.Mode = RunMode.RunModeRun
    end

    VariableScopeEnd(Parser, ScopeID, PrevScopeID)

    ParserCopyPos(Parser, After)
end

function ParseBlock(Parser, AbsorbOpenBrace, Condition)
    local PrevScopeID = 0
    local ScopeID
    ScopeID, PrevScopeID = VariableScopeBegin(Parser)

    --if Debug then
    --    print("ParseBlock Enter")
    --end

    if AbsorbOpenBrace then
        local Token
        Token, _ = LexGetToken(Parser, nil, true)
        if Token ~= LexToken.TokenLeftBrace then
            ProgramFail(Parser, "'{' expected")
        end
    end

    if Parser.Mode == RunMode.RunModeSkip or not Condition then
        local OldMode = Parser.Mode
        Parser.Mode = RunMode.RunModeSkip
        local ParseResult = ParseStatement(Parser, true)
        while ParseResult == ParserResult.ParseResultOk do
            ParseResult = ParseStatement(Parser, true)
        end
        Parser.Mode = OldMode
    else
        local ParseResult = ParseStatement(Parser, true)
        while ParseResult == ParserResult.ParseResultOk do
            ParseResult = ParseStatement(Parser, true)
        end
    end

    Token, _ = LexGetToken(Parser, nil, true)
    if Token ~= LexToken.TokenRightBrace then
        ProgramFail(Parser, "'}' expected")
    end

    VariableScopeEnd(Parser, ScopeID, PrevScopeID)

    return Parser.Mode
end

function ParseTypedef(Parser)
    local TypeName
    local Typ
    local InitValue

    Typ, TypeName, _ = TypeParse(Parser)
    InitValue = VariableAllocValueAndData(Parser.pc, Parser, 0, false, nil, true)

    --print("Typedef:", Typ.Base, TypeName.RawValue.Val, InitValue.Val.Ident)

    if Parser.Mode == RunMode.RunModeRun then
        InitValue.Typ = Parser.pc.TypeType
        InitValue.Val.Typ = Typ     -- Val here points to Typ, not AnyValue type
        VariableDefine(Parser.pc, Parser, TypeName, InitValue, nil, false)
    end
end

function ParseStatement(Parser, CheckTrailingSemicolon)
    local Condition
    local Token
    local CValue
    local LexerValue
    local VarValue
    local PreState = {}

    ParserCopy(PreState, Parser)
    Token, LexerValue = LexGetToken(Parser, LexerValue, true)
    --if Debug then
    --    print("Token:", Token)
    --end

    if Token == LexToken.TokenEOF then
        return ParserResult.ParseResultEOF
    elseif Token == LexToken.TokenIdentifier then
        --if Debug then
        --    print("Parse Identifier")
        --end
        if VariableDefined(Parser.pc, LexerValue.Val) then
            VarValue = VariableGet(Parser.pc, Parser, LexerValue.Val)
            if VarValue.Typ.Base == BaseType.TypeType then
                ParserCopy(Parser, PreState)
                ParseDeclaration(Parser, Token)
                CheckTrailingSemicolon = false
            else
                -- Fallthrough
                ParserCopy(Parser, PreState)
                _, CValue = ExpressionParse(Parser)
                if Parser.Mode == RunMode.RunModeRun then
                    VariableStackPop(Parser, CValue)
                end
            end
        else
            local NextToken
            NextToken, _ = LexGetToken(Parser, nil, false)
            if NextToken == LexToken.TokenColon then
                LexGetToken(Parser, nil, true)
                if (Parser.Mode == RunMode.RunModeGoto and
                    LexerValue.Val == Parser.SearchGotoLabel) then
                    Parser.Mode = RunMode.RunModeRun
                end
                CheckTrailingSemicolon = false
            else
                -- Fallthrough
                ParserCopy(Parser, PreState)
                _, CValue = ExpressionParse(Parser)
                if Parser.Mode == RunMode.RunModeRun then
                    VariableStackPop(Parser, CValue)
                end
            end
        end
    elseif (Token == LexToken.TokenAsterisk or Token == LexToken.TokenAmpersand or
        Token == LexToken.TokenIncrement or Token == LexToken.TokenDecrement or
        Token == LexToken.TokenOpenBracket) then
        ParserCopy(Parser, PreState)
        _, CValue = ExpressionParse(Parser)
        if Parser.Mode == RunMode.RunModeRun then
            VariableStackPop(Parser, CValue)
        end
    elseif Token == LexToken.TokenLeftBrace then
        ParseBlock(Parser, false, true)
        CheckTrailingSemicolon = false
    elseif Token == LexToken.TokenIf then
        local Tok
        Tok, _ = LexGetToken(Parser, nil, true)
        if Tok ~= LexToken.TokenOpenBracket then
            ProgramFail(Parser, "'(' expected")
        end
        Condition = C_INT_TO_LUA_BOOLEAN(ExpressionParseInt(Parser))
        Tok, _ = LexGetToken(Parser, nil, true)
        if Tok ~= LexToken.TokenCloseBracket then
            ProgramFail(Parser, "')' expected")
        end
        if ParseStatementMaybeRun(Parser, Condition, true) ~= ParserResult.ParseResultOk then
            ProgramFail(Parser, "statement expected")
        end
        Tok, _ = LexGetToken(Parser, nil, false)
        if Tok == LexToken.TokenElse then
            LexGetToken(Parser, nil, true)
            if ParseStatementMaybeRun(Parser, not Condition, true) ~= ParserResult.ParseResultOk then
                ProgramFail(Parser, "statement expected")
            end
        end
        CheckTrailingSemicolon = false
    elseif Token == LexToken.TokenWhile then
        local PreConditional = {}
        local PreMode = Parser.Mode
        local Tok
        Tok, _ = LexGetToken(Parser, nil, true)
        if Tok ~= LexToken.TokenOpenBracket then
            ProgramFail(Parser, "'(' expected")
        end
        ParserCopyPos(PreConditional, Parser)
        repeat
            ParserCopyPos(Parser, PreConditional)
            Condition = C_INT_TO_LUA_BOOLEAN(ExpressionParseInt(Parser))
            Tok, _ = LexGetToken(Parser, nil, true)
            if Tok ~= LexToken.TokenCloseBracket then
                ProgramFail(Parser, "')' expected")
            end
            if ParseStatementMaybeRun(Parser, Condition, true) ~= ParserResult.ParseResultOk then
                ProgramFail(Parser, "statement expected")
            end
            if Parser.Mode == RunMode.RunModeContinue then
                Parser.Mode = PreMode
            end
        until Parser.Mode ~= RunMode.RunModeRun or not Condition
        if Parser.Mode == RunMode.RunModeBreak then
            Parser.Mode = PreMode
        end
        CheckTrailingSemicolon = false
    elseif Token == LexToken.TokenDo then
        local PreStatement = {}
        local PreMode = Parser.Mode
        ParserCopyPos(PreStatement, Parser)
        repeat
            ParserCopyPos(Parser, PreStatement)
            if ParseStatement(Parser, true) ~= ParserResult.ParseResultOk then
                ProgramFail(Parser, "statement expected")
            end
            if Parser.Mode == RunMode.RunModeContinue then
                Parser.Mode = PreMode
            end
            local Tok
            Tok, _ = LexGetToken(Parser, nil, true)
            if Tok ~= LexToken.TokenWhile then
                ProgramFail(Parser, "'while' expected")
            end
            Tok, _ = LexGetToken(Parser, nil, true)
            if Tok ~= LexToken.TokenOpenBracket then
                ProgramFail(Parser, "'(' expected")
            end
            Condition = C_INT_TO_LUA_BOOLEAN(ExpressionParseInt(Parser))
            Tok, _ = LexGetToken(Parser, nil, true)
            if Tok ~= LexToken.TokenCloseBracket then
                ProgramFail(Parser, "')' expected")
            end
        until not Condition or Parser.Mode ~= RunMode.RunModeRun
        if Parser.Mode == RunMode.RunModeBreak then
            Parser.Mode = PreMode
        end
    elseif Token == LexToken.TokenFor then
        ParseFor(Parser)
        CheckTrailingSemicolon = false
    elseif Token == LexToken.TokenSemicolon then
        CheckTrailingSemicolon = false
    elseif (Token == LexToken.TokenIntType or Token == LexToken.TokenShortType or
        Token == LexToken.TokenCharType or Token == LexToken.TokenLongType or
        Token == LexToken.TokenFloatType or Token == LexToken.TokenDoubleType or
        Token == LexToken.TokenVoidType or Token == LexToken.TokenStructType or
        Token == LexToken.TokenUnionType or Token == LexToken.TokenEnumType or
        Token == LexToken.TokenSignedType or Token == LexToken.TokenUnsignedType or
        Token == LexToken.TokenStaticType or Token == LexToken.TokenAutoType or
        Token == LexToken.TokenRegisterType or Token == LexToken.TokenExternType) then
        ParserCopy(Parser, PreState)
        --if Debug then
        --    print("PS:", Parser.Line, Parser.CharacterPos)
        --end
        CheckTrailingSemicolon = ParseDeclaration(Parser, Token)
    elseif Token == LexToken.TokenHashDefine then
        ParseMacroDefinition(Parser)
        CheckTrailingSemicolon = false
    elseif Token == LexToken.TokenHashInclude then
        local Tok
        Tok, LexerValue = LexGetToken(Parser, LexerValue, true)
        if Tok ~= LexToken.TokenStringConstant then
            ProgramFail(Parser, "\"filename.h\" expected")
        end
        local StringConstant = PointerDereference(LexerValue.Val)
        IncludeFile(Parser.pc, StringConstant)
        CheckTrailingSemicolon = false
    elseif Token == LexToken.TokenSwitch then
        Tok, _ = LexGetToken(Parser, nil, true)
        if Tok ~= LexToken.TokenOpenBracket then
            ProgramFail(Parser, "'(' expected")
        end
        Condition = ExpressionParseInt(Parser)
        Tok, _ = LexGetToken(Parser, nil, true)
        if Tok ~= LexToken.TokenCloseBracket then
            ProgramFail(Parser, "')' expected")
        end
        Tok, _ = LexGetToken(Parser, nil, false)
        if Tok ~= LexToken.TokenLeftBrace then
            ProgramFail(Parser, "'{' expected")
        end

        local OldMode = Parser.Mode
        local OldSearchLabel = Parser.SearchLabel
        Parser.Mode = RunMode.RunModeCaseSearch
        Parser.SearchLabel = Condition
        ParseBlock(Parser, true, OldMode ~= RunMode.RunModeSkip and
            OldMode ~= RunMode.RunModeReturn)
        if Parser.Mode ~= RunMode.RunModeReturn then
            Parser.Mode = OldMode
        end
        Parser.SearchLabel = OldSearchLabel
        CheckTrailingSemicolon = false
    elseif Token == LexToken.TokenCase then
        if Parser.Mode == RunMode.RunModeCaseSearch then
            Parser.Mode = RunMode.RunModeRun
            Condition = ExpressionParseInt(Parser)
            Parser.Mode = RunMode.RunModeCaseSearch
        else
            Condition = ExpressionParseInt(Parser)
        end
        local Tok
        Tok, _ = LexGetToken(Parser, nil, true)
        if Tok ~= LexToken.TokenColon then
            ProgramFail(Parser, "':' expected")
        end
        if Parser.Mode == RunMode.RunModeCaseSearch and Condition == Parser.SearchLabel then
            Parser.Mode = RunMode.RunModeRun
        end
        CheckTrailingSemicolon = false
    elseif Token == LexToken.TokenDefault then
        local Tok
        Tok, _ = LexGetToken(Parser, nil, true)
        if Tok ~= LexToken.TokenColon then
            ProgramFail(Parser, "':' expected")
        end
        if Parser.Mode == RunMode.RunModeCaseSearch then
            Parser.Mode = RunMode.RunModeRun
        end
        CheckTrailingSemicolon = false
    elseif Token == LexToken.TokenBreak then
        if Parser.Mode == RunMode.RunModeRun then
            Parser.Mode = RunMode.RunModeBreak
        end
    elseif Token == LexToken.TokenContinue then
        if Parser.Mode == RunMode.RunModeRun then
            Parser.Mode = RunMode.RunModeContinue
        end
    elseif Token == LexToken.TokenReturn then
        if Parser.Mode == RunMode.RunModeRun then
            local GlobalOrNotVoid
            --print("Get StackFrame ReturnValue", Parser.pc.TopStackFrameId)
            if Parser.pc.TopStackFrameId == 0 then
                GlobalOrNotVoid = true
            elseif HeapGetStackNode(Parser.pc, Parser.pc.TopStackFrameId).ReturnValue.Typ.Base ~= BaseType.TypeVoid then
                GlobalOrNotVoid = true
            else
                GlobalOrNotVoid = false
            end

            if GlobalOrNotVoid then
                local Success
                Success, CValue = ExpressionParse(Parser)
                if not Success then
                    ProgramFail(Parser, "value required in return")
                end
                if Parser.pc.TopStackFrameId == 0 then
                    -- Exit the program
                    PlatformExit(Parser.pc, ExpressionCoerceInteger(CValue))
                else
                    local TopStackFrame = HeapGetStackNode(Parser.pc, Parser.pc.TopStackFrameId)
                    ExpressionAssign(Parser,
                        TopStackFrame.ReturnValue, CValue, true,
                        nil, 0, false)
                    VariableStackPop(Parser, CValue)
                end
            else
                local Success
                Success, CValue = ExpressionParse(Parser)
                if Success then
                    ProgramFail(Parser, "value in return from a void function")
                end
            end
            Parser.Mode = RunMode.RunModeReturn
        else
            _, CValue = ExpressionParse(Parser)
        end
    elseif Token == LexToken.TokenTypedef then
        ParseTypedef(Parser)
    elseif Token == LexToken.TokenGoto then
        local Tok
        Tok, LexerValue = LexGetToken(Parser, LexerValue, true)
        if Tok ~= LexToken.TokenIdentifier then
            ProgramFail(Parser, "identifier expected")
        end
        if Parser.Mode == RunMode.RunModeRun then
            Parser.SearchGotoLabel = LexerValue.Val
            Parser.Mode = RunMode.RunModeGoto
        end
    elseif Token == LexToken.TokenDelete then
        local Tok
        Tok, LexerValue = LexGetToken(Parser, LexerValue, true)
        if Tok ~= LexToken.TokenIdentifier then
            ProgramFail(Parser, "identifier expected")
        end
        if Parser.Mode == RunMode.RunModeRun then
            CValue = TableDelete(Parser.pc, Parser.pc.GlobalTable,
                LexerValue.Val)
            if CValue == nil then
                ProgramFail(Parser, "'%s' is not defined",
                    LexerValue.Val.RawValue.Val)
            end

            VariableFree(Parser.pc, CValue)
        end
    else
        ParserCopy(Parser, PreState)
        return ParserResult.ParseResultError
    end

    if CheckTrailingSemicolon then
        local Tok
        Tok, _ = LexGetToken(Parser, nil, true)
        --if Debug then
        --    print(Token, Tok, Parser.Line, Parser.CharacterPos)
        --end
        if Tok ~= LexToken.TokenSemicolon then
            ProgramFail(Parser, "';' expected")
        end
    end

    return ParserResult.ParseResultOk
end

function PicocParse(pc, FileName, Source, SourceLen, RunIt, EnableDebugger)
    local RegFileName = TableStrRegister(pc, FileName)
    local Ok = ParserResult.ParseResultOk
    local Parser = {}

    local Tokens
    Tokens, _ = LexAnalyse(pc, RegFileName, Source, SourceLen)

    LexInitParser(Parser, pc, Source, Tokens, RegFileName, RunIt,
        EnableDebugger)

    repeat
        Ok = ParseStatement(Parser, true)
    until Ok ~= ParserResult.ParseResultOk

    if Ok == ParserResult.ParseResultError then
        ProgramFail(Parser, "parse error")
    end
end

function PicocParseInteractiveNoStartPrompt(pc, EnableDebugger)
    local Status
    local Ok
    local Parser = {}

    LexInitParser(Parser, pc, nil, nil, pc.StrEmpty, true, EnableDebugger)
    LexInteractiveClear(pc, Parser)

    repeat
        LexInteractiveStatementPrompt(pc)

        ParseInteractive = coroutine.create(function()
            return ParseStatement(Parser, true)
        end)

        repeat
            Status, Ok = coroutine.resume(ParseInteractive)
            if coroutine.status(ParseInteractive) == "suspended" then
                coroutine.yield()
            else
                if Status then
                    LexInteractiveCompleted(pc, Parser)
                else
                    if string.find(Ok, "C Parsing Error") ~= nil then
                        LexInteractiveClear(pc, Parser)
                        Ok = ParserResult.ParseResultOk
                    else
                        error(Ok)
                    end
                end
            end
        until coroutine.status(ParseInteractive) ~= "suspended"
    until Ok ~= ParserResult.ParseResultOk

    if Ok == ParserResult.ParseResultError then
        ProgramFail(Parser, "parse error")
    end

    PlatformPrintf(pc.CStdOut, "\n")
end

function PicocParseInteractive(pc)
    PlatformPrintf(pc.CStdOut, INTERACTIVE_HEAD_STATEMENT)
    PicocParseInteractiveNoStartPrompt(pc, GEnableDebugger)
end
PICOC_VERSION = "v2.3.2"

GLOBAL_TABLE_SIZE = 97
STRING_TABLE_SIZE = 97
STRING_LITERAL_TABLE_SIZE = 97
RESERVED_WORD_TABLE_SIZE = 97
PARAMETER_MAX = 256
LINEBUFFER_MAX = 256
LOCAL_TABLE_SIZE = 11
STRUCT_TABLE_SIZE = 11

INTERACTIVE_PROMPT_STATEMENT = "picoc> "
INTERACTIVE_PROMPT_LINE = "     > "

INTERACTIVE_HEAD_STATEMENT = [[
XPicoC v0.1-alpha (Core version 2.3.2) Copyright (c) 2009-2020 Jimmy Lin, Zik Saleeba, Joseph Poirier
]]

function PicocInitialize(pc, NoIOInit)
    pc.GlobalTable = {}
    pc.GlobalHashTable = {}
    pc.LexUseStatementPrompt = false
    pc.ReservedWordTable = {}
    pc.ReservedWordHashTable = {}
    pc.StringLiteralTable = {}
    pc.StringLiteralHashTable = {}
    pc.PicocExitValue = 0
    pc.UberType = {
        Base = 0,
        ArraySize = 0,
        Sizeof = 0,
        AlignBytes = 0,
        OnHeap = false,
        StaticQualifier = false
    }
    pc.IntType = {}
    pc.ShortType = {}
    pc.CharType = {}
    pc.LongType = {}
    pc.UnsignedIntType = {}
    pc.UnsignedShortType = {}
    pc.UnsignedLongType = {}
    pc.UnsignedCharType = {}
    pc.FPType = {}
    pc.VoidType = {}
    pc.TypeType = {}
    pc.FunctionType = {}
    pc.MacroType = {}
    pc.EnumType = {}
    pc.GotoLabelType = {}
    pc.BreakpointTable = {}
    pc.BreakpointHashTable = {}
    pc.BreakpointCount = 0
    pc.DebugManualBreak = false
    pc.BigEndian = false
    pc.LittleEndian = false
    pc.StringTable = {}
    pc.StringHashTable = {}
    pc.StructTempName = "^s0000"
    pc.EnumTempName = "^e0000"
    PlatformInit(pc)
    BasicIOInit(pc, NoIOInit)
    HeapInit(pc)
    TableInit(pc)
    VariableInit(pc)
    LexInit(pc)
    TypeInit(pc)
    IncludeInit(pc)
    LibraryInit(pc)

    --DebugInit(pc)
end

function PicocCleanup(pc)
    --DebugCleanup(pc)

    IncludeCleanup(pc)
    ParseCleanup(pc)
    LexCleanup(pc)
    VariableCleanup(pc)
    TypeCleanup(pc)
    TableStrFree(pc)
    HeapCleanup(pc)
    PlatformCleanup(pc)
end

CALL_MAIN_NO_ARGS_RETURN_VOID = "main();"
CALL_MAIN_WITH_ARGS_RETURN_VOID = "main(__argc,__argv)"
CALL_MAIN_NO_ARGS_RETURN_INT = "__exit_value = main();"
CALL_MAIN_WITH_ARGS_RETURN_INT = "__exit_value = main(__argc,__argv);"

function PicocCallMain(pc, argc, argv)
    local FuncValue

    if not VariableDefined(pc, TableStrRegister(pc, "main")) then
        ProgramFailNoParser(pc, "main() is not defined")
    end

    FuncValue = VariableGet(pc, nil, TableStrRegister(pc, "main"))
    if FuncValue.Typ.Base ~= BaseType.TypeFunction then
        ProgramFailNoParser(pc, "main is not a function - can't call it")
    end

    if FuncValue.Val.FuncDef.NumParams ~= 0 then
        local ArgcValue = VariableAllocAnyValue(4)
        PointerSetSignedOrUnsignedInt(ArgcValue, argc)
        VariableDefinePlatformVar(pc, nil, "__argc", pc.IntType,
            ArgcValue, false)

        local ArgvArrayValue = VariableAllocAnyValue(4 * #argv)
        for _, v in ipairs(argv) do
            local Arg = tostring(v)
            local Len = string.len(Arg)
            local ArgNValue = VariableAllocAnyValue(Len)
            ArgNValue.RawValue.Val = Arg

            PointerReference(ArgvArrayValue, ArgNValue)
            ArgvArrayValue.Offset = ArgvArrayValue.Offset + 4
        end
        ArgvArrayValue.Offset = 0

        VariableDefinePlatformVar(pc, nil, "__argv", pc.CharPtrPtrType,
            ArgvArrayValue, false)
    end

    if FuncValue.Val.FuncDef.ReturnType == pc.VoidType then
        if FuncValue.Val.FuncDef.NumParams == 0 then
            PicocParse(pc, "startup", CALL_MAIN_NO_ARGS_RETURN_VOID,
                string.len(CALL_MAIN_NO_ARGS_RETURN_VOID), true,
                GEnableDebugger)
        else
            PicocParse(pc, "startup", CALL_MAIN_WITH_ARGS_RETURN_VOID,
                string.len(CALL_MAIN_WITH_ARGS_RETURN_VOID), true,
                GEnableDebugger)
        end
    else
        local ExitValue = VariableAllocAnyValue(4)
        PointerSetSignedOrUnsignedInt(ExitValue, pc.PicocExitValue)
        VariableDefinePlatformVar(pc, nil, "__exit_value", pc.IntType,
            ExitValue, true)

        if FuncValue.Val.FuncDef.NumParams == 0 then
            PicocParse(pc, "startup", CALL_MAIN_NO_ARGS_RETURN_INT,
                string.len(CALL_MAIN_NO_ARGS_RETURN_INT), true,
                GEnableDebugger)
        else
            PicocParse(pc, "startup", CALL_MAIN_WITH_ARGS_RETURN_INT,
                string.len(CALL_MAIN_WITH_ARGS_RETURN_INT), true,
                GEnableDebugger)
        end
    end
end

function PrintSourceTextErrorLine(Stream, FileName, SourceText, Line, CharacterPos)
    local LineCount
    local CCount
    local LinePos
    local CPos

    if SourceText ~= nil then
        LinePos = 1
        LineCount = 1
        local GotChar = string.sub(SourceText, LinePos, LinePos)
        while GotChar ~= "" and LineCount < Line do
            if GotChar == '\n' then
                LineCount = LineCount + 1
            end
            LinePos = LinePos + 1
            GotChar = string.sub(SourceText, LinePos, LinePos)
        end

        CPos = LinePos
        GotChar = string.sub(SourceText, CPos, CPos)
        while GotChar ~= "\n" and GotChar ~= "" do
            PrintCh(GotChar, Stream)
            CPos = CPos + 1
            GotChar = string.sub(SourceText, CPos, CPos)
        end
        PrintCh("\n", Stream)

        CPos = LinePos
        GotChar = string.sub(SourceText, CPos, CPos)
        CCount = 0
        while (GotChar ~= '\n' and GotChar ~= "" and
            (CCount < CharacterPos or CPos == ' ')) do
            if GotChar == '\t' then
                PrintCh('\t', Stream)
            else
                PrintCh(' ', Stream)
            end

            CPos = CPos + 1
            CCount = CCount + 1
        end
    else
        for CC = 0, CharacterPos + string.len(INTERACTIVE_PROMPT_STATEMENT) do
            PrintCh(' ', Stream)
        end
    end
    PlatformPrintf(Stream, "^\n%s:%d:%d ", FileName.RawValue.Val, Line, CharacterPos)
end

function ProgramFail(Parser, Message, ...)
    local arg = {...}
    if Parser.SourceText then
        PrintSourceTextErrorLine(Parser.pc.CStdOut, Parser.FileName,
            Parser.SourceText, Parser.Line, Parser.CharacterPos)
    else
        ProgramFailNoParser(Parser.pc, Message, ...)
        return
    end
    PlatformVPrintf(Parser.pc.CStdOut, Message, arg)
    PlatformPrintf(Parser.pc.CStdOut, "\n")
    PlatformExit(Parser.pc, 1)
end

function ProgramFailNoParser(pc, Message, ...)
    local arg = {...}
    PlatformVPrintf(pc.CStdOut, Message, arg)
    PlatformPrintf(pc.CStdOut, "\n")
    PlatformExit(pc, 1)
end

function AssignFail(Parser, Format, Type1, Type2, Num1, Num2, FuncName, ParamNo)
    Stream = Parser.pc.CStdOut

    PrintSourceTextErrorLine(Parser.pc.CStdOut, Parser.FileName,
        Parser.SourceText, Parser.Line, Parser.CharacterPos)
    if FuncName == nil then
        PlatformPrintf(Stream, "can't %s ", "assign")
    else
        PlatformPrintf(Stream, "can't %s ", "set")
    end

    if Type1 ~= nil then
        PlatformPrintf(Stream, Format, Type1, Type2)
    else
        PlatformPrintf(Stream, Format, Num1, Num2)
    end

    if FuncName ~= nil then
        PlatformPrintf(Stream, " in argument %d of call to %s()", ParamNo,
            FuncName.RawValue.Val)
    end

    PlatformPrintf(Stream, "\n")
    PlatformExit(Parser.pc, 1)
end

function LexFail(pc, Lexer, Message, ...)
    local arg = {...}
    PrintSourceTextErrorLine(pc.CStdOut, Lexer.FileName,
        Lexer.SourceText, Lexer.Line, Lexer.CharacterPos)
    PlatformVPrintf(pc.CStdOut, Message, arg)
    PlatformPrintf(pc.CStdOut, "\n")
    PlatformExit(pc, 1)
end

function PlatformPrintf(Stream, Format, ...)
    local arg = {...}
    PlatformVPrintf(Stream, Format, arg)
end

function PlatformVPrintf(Stream, Format, Args)
    local FPos = 1
    local ArgPos = 1
    local GotChar = string.sub(Format, FPos, FPos)
    local Arg

    while GotChar ~= "" do
        if GotChar == '%' then
            FPos = FPos + 1
            GotChar = string.sub(Format, FPos, FPos)
            Arg = Args[ArgPos]
            if Arg ~= nil then
                if GotChar == 's' then
                    PrintStr(Args[ArgPos], Stream)
                    ArgPos = ArgPos + 1
                elseif GotChar == 'd' then
                    PrintSimpleInt(Args[ArgPos], Stream)
                    ArgPos = ArgPos + 1
                elseif GotChar == 'c' then
                    PrintCh(Args[ArgPos], Stream)
                    ArgPos = ArgPos + 1
                elseif GotChar == 't' then
                    PrintType(Args[ArgPos], Stream)
                    ArgPos = ArgPos + 1
                elseif GotChar == 'f' then
                    PrintFP(Args[ArgPos], Stream)
                    ArgPos = ArgPos + 1
                elseif GotChar == '%' then
                    PrintCh(Args[ArgPos], Stream)
                elseif GotChar == '' then
                    FPos = FPos - 1
                end
            end
        else
            PrintCh(GotChar, Stream)
        end

        FPos = FPos + 1
        GotChar = string.sub(Format, FPos, FPos)
    end
end

function PlatformMakeTempName(pc, IsStruct)
    local CPos = 6
    local TempNameBuffer

    if IsStruct then
        TempNameBuffer = pc.StructTempName
    else
        TempNameBuffer = pc.EnumTempName
    end

    while CPos > 2 do
        if string.sub(TempNameBuffer, CPos, CPos) < '9' then
            TempNameBuffer = string.sub(TempNameBuffer, 1, CPos - 1) ..
                string.char(string.byte(string.sub(TempNameBuffer, CPos, CPos)) + 1) ..
                string.sub(TempNameBuffer, CPos + 1)

            if IsStruct then
                pc.StructTempName = TempNameBuffer
            else
                pc.EnumTempName = TempNameBuffer
            end

            return TableStrRegister(pc, TempNameBuffer)
        else
            TempNameBuffer = string.sub(TempNameBuffer, 1, CPos - 1) ..
                "0" .. string.sub(TempNameBuffer, CPos + 1)
            CPos = CPos - 1
        end
    end

    return TableStrRegister(pc, TempNameBuffer)
end
--[[
    pointer.lua - Lua implementation of PicoC AnyValue type
]]

--[[
/* Extensions to definition of AnyValue type in Lua-PicoC */

struct RawValue {
    string Val
}

struct AnyValue {
    // Normal variable excluding pointer array
    struct RawValue *RawValue;      // Value of variable
    unsigned int Offset;            // For dereferencing
    unsigned int Ident;             // Identity of the value of the variable
                                    // We need this to void all pointers to a value
                                    // if the variable it attaches to
                                    // is deleted (gone out of scope)
                                    // to actually free value memory in Lua

    // -- Or --
    // Pointer or array of pointers
    struct RawValue *RawValue;      // Value of the pointer
                                    // Contains (every 4 bytes) the identity
                                    // of the variable that the pointer(s)
                                    // reference
    unsigned int Offset;
    unsigned int Ident;
    unsigned int RefOffsets[];      // Dictionary of pointer offsets of each
                                    // variable member
                                    // The key is the identity of corresponding
                                    // variable member
                                    // Merged if a struct or union contains
                                    // multiple pointers
    struct AnyValue *Pointers[];    // Dictionary of pointers to every
                                    // variable member
}
]]

Multiplier = {0x1, 0x100, 0x10000, 0x1000000}

-- Assign an integer value (-2147483648 to 2147483647 or 0 to 4294967295) to a variable
-- at the current offset, handles overflow cases
-- DestValue: AnyValue
function PointerSetSignedOrUnsignedInt(DestValue, FromInt)
    local Result
    local RawValue = DestValue.RawValue.Val
    local Offset = DestValue.Offset
    local byte1, byte2, byte3, byte4
    local ResultRawValue

    if FromInt < 0 then
        FromInt = 0x100000000 -
            ((-FromInt) - 0x100000000 * math.floor((-FromInt) / 0x100000000))
    else
        FromInt = FromInt - 0x100000000 * math.floor(FromInt / 0x100000000)
    end

    byte4 = math.floor(FromInt / 0x1000000)
    FromInt = FromInt - 0x1000000 * byte4
    byte3 = math.floor(FromInt / 0x10000)
    FromInt = FromInt - 0x10000 * byte3
    byte2 = math.floor(FromInt / 0x100)
    FromInt = FromInt - 0x100 * byte2
    byte1 = FromInt

    Result = string.char(byte1) .. string.char(byte2) ..
        string.char(byte3) .. string.char(byte4)

    RawValue = string.sub(RawValue, Offset + 1, Offset + 4)
    RawValue = string.sub(Result, 1, string.len(RawValue))

    ResultRawValue = string.sub(DestValue.RawValue.Val, 1, Offset) ..
        RawValue ..
        string.sub(DestValue.RawValue.Val, Offset + string.len(RawValue) + 1)

    DestValue.RawValue.Val = ResultRawValue
end

-- Assign a short integer value (-32768 to 32767 or 0 to 65535) to a variable
-- at the current offset, handles overflow cases
-- DestValue: AnyValue
function PointerSetSignedOrUnsignedShort(DestValue, FromInt)
    local Result
    local RawValue = DestValue.RawValue.Val
    local Offset = DestValue.Offset
    local byte1, byte2
    local ResultRawValue

    if FromInt < 0 then
        FromInt = 0x10000 -
            ((-FromInt) - 0x10000 * math.floor((-FromInt) / 0x10000))
    else
        FromInt = FromInt - 0x10000 * math.floor(FromInt / 0x10000)
    end

    byte2 = math.floor(FromInt / 0x100)
    FromInt = FromInt - 0x100 * byte2
    byte1 = FromInt

    Result = string.char(byte1) .. string.char(byte2)

    RawValue = string.sub(RawValue, Offset + 1, Offset + 2)
    RawValue = string.sub(Result, 1, string.len(RawValue))

    ResultRawValue = string.sub(DestValue.RawValue.Val, 1, Offset) ..
        RawValue ..
        string.sub(DestValue.RawValue.Val, Offset + string.len(RawValue) + 1)
    DestValue.RawValue.Val = ResultRawValue
end

-- Assign a one-byte value (-128 to 127 or 0 to 255) to a variable
-- at the current offset, handles overflow cases
-- DestValue: AnyValue
function PointerSetSignedOrUnsignedChar(DestValue, FromInt)
    local Result
    local RawValue = DestValue.RawValue.Val
    local Offset = DestValue.Offset
    local byte1

    if FromInt < 0 then
        FromInt = 0x100 -
            ((-FromInt) - 0x100 * math.floor((-FromInt) / 0x100))
    else
        FromInt = FromInt - 0x100 * math.floor(FromInt / 0x100)
    end
    byte1 = FromInt

    Result = string.char(byte1)

    if string.len(RawValue) > Offset then
        RawValue = Result
        DestValue.RawValue.Val = string.sub(DestValue.RawValue.Val, 1, Offset) ..
            RawValue ..
            string.sub(DestValue.RawValue.Val, Offset + 2)
    end
end

-- Assign a double precision FP value to a variable at the current offset
-- Converts FP into internal floating representation (IEEE 754)
-- DestValue: AnyValue
function PointerSetFP(DestValue, FromFP)
    local RawValue = DestValue.RawValue.Val
    local Offset = DestValue.Offset
    local FromFPAbs, IntegralPart, FractionalPart
    local NShift
    local R, Q
    local TotalBinLen
    local Exponent
    local BiasedExponent
    local ResultBits, NBits, Result, Byte
    local ResultRawValue

    -- Value is 0
    -- This is the minimum number that FP64 can represent
    if FromFP == 0 or math.abs(FromFP) < 2.225073858507e-308 then
        DestValue.RawValue.Val = "\000\000\000\000\000\000\000\000"
        return
    end

    -- Value is infinity
    -- This is the maximum number that FP64 can represent
    if math.abs(FromFP) > 1.797693134862e308 then
        if FromFP >= 0 then
            DestValue.RawValue.Val = "\000\000\000\000\000\000\240\127"
        else
            DestValue.RawValue.Val = "\000\000\000\000\000\000\240\255"
        end
        return
    end

    FromFPAbs = math.abs(FromFP)

    -- The binary exponent
    Exponent = math.floor(math.log(FromFPAbs) / math.log(2))

    -- Set appropriate rounding so that loops won't waste time on preceding or succeeding 0's
    if math.floor(FromFPAbs) > 0 then
        NShift = Exponent - 52
        if NShift < 0 then
            NShift = 0
        end
        FromFPAbs = FromFPAbs / 2 ^ NShift
    else
        NShift = -(Exponent + 1)
        FromFPAbs = FromFPAbs * 2 ^ NShift
    end

    IntegralPart = math.floor(FromFPAbs)
    FractionalPart = FromFPAbs - IntegralPart
    ResultBits = {}

    -- Take the binary number of integral part
    Q = IntegralPart
    while Q > 0 do
        R = Q % 2
        Q = math.floor(Q / 2)
        table.insert(ResultBits, 1, R)
    end

    TotalBinLen = #ResultBits

    Q = FractionalPart
    -- Take the binary number of fractional part
    -- Save iterations by taking the fewest steps possible
    while Q > 0 and TotalBinLen <= 53 do
        R = math.floor(Q * 2)
        Q = Q * 2 - R
        table.insert(ResultBits, R)

        TotalBinLen = TotalBinLen + 1
    end

    -- Remove preceding 1
    if ResultBits[1] == 1 then
        table.remove(ResultBits, 1)
    end

    -- Bit padding
    TotalBinLen = #ResultBits
    if TotalBinLen > 52 then
        while TotalBinLen > 52 do
            table.remove(ResultBits)
            TotalBinLen = TotalBinLen - 1
        end
    else
        while TotalBinLen < 52 do
            table.insert(ResultBits, 0)
            TotalBinLen = TotalBinLen + 1
        end
    end

    BiasedExponent = 1023 + Exponent
    if BiasedExponent > 2047 then
        -- Overflow, infinity
        if FromFP >= 0 then
            DestValue.RawValue.Val = "\000\000\000\000\000\000\240\127"
        else
            DestValue.RawValue.Val = "\000\000\000\000\000\000\240\255"
        end
        return
    elseif BiasedExponent < 0 then
        -- Overflow, 0
        if FromFP >= 0 then
            DestValue.RawValue.Val = "\000\000\000\000\000\000\000\000"
        else
            DestValue.RawValue.Val = "\000\000\000\000\000\000\000\128"
        end
        return
    end

    if FromFP >= 0 then
        table.insert(ResultBits, 1, 0)
    else
        table.insert(ResultBits, 1, 1)
    end

    Q = BiasedExponent
    NBits = 0
    while Q > 0 do
        R = Q % 2
        Q = math.floor(Q / 2)
        table.insert(ResultBits, 2, R)
        NBits = NBits + 1
    end
    for j = 1, 11 - NBits do
        table.insert(ResultBits, 2, 0)
    end

    Result = ""
    for i = 1, 64, 8 do
        Byte = 0
        for j = 0, 7 do
            Byte = Byte + 2 ^ (7 - j) * ResultBits[i + j]
        end
        Result = string.char(Byte) .. Result
    end

    RawValue = string.sub(RawValue, Offset + 1, Offset + 8)
    RawValue = string.sub(Result, 1, string.len(RawValue))

    ResultRawValue = string.sub(DestValue.RawValue.Val, 1, Offset) ..
        RawValue ..
        string.sub(DestValue.RawValue.Val, Offset + string.len(RawValue) + 1)
    DestValue.RawValue.Val = ResultRawValue
end

function PointerGetSignedInt(FromValue)
    local Result = PointerGetUnsignedInt(FromValue)

    if Result > 0x7FFFFFFF then
        --Result = Result - 0xFFFFFFFF
        Result = Result - 0x100000000
    end

    return Result
end

function PointerGetUnsignedInt(FromValue)
    local RawValue = FromValue.RawValue.Val
    local Offset = FromValue.Offset
    local Char, Byte
    local Result = 0
    --print("Enter")

    for i = Offset + 1, Offset + 4 do
        Char = string.sub(RawValue, i, i)
        if Char == "" then
            Byte = 0
        else
            Byte = string.byte(Char)
        end

        Result = Result + Multiplier[i - Offset] * Byte
        --Result = Result + 2 ^ (8 * (i - Offset - 1)) * Byte
    end

    return Result
end

function PointerGetSignedShort(FromValue)
    local Result = PointerGetUnsignedShort(FromValue)

    if Result > 0x7FFF then
        --Result = Result - 0xFFFF
        Result = Result - 0x10000
    end

    return Result
end

function PointerGetUnsignedShort(FromValue)
    local RawValue = FromValue.RawValue.Val
    local Offset = FromValue.Offset
    local Char, Byte
    local Result = 0

    for i = Offset + 1, Offset + 2 do
        Char = string.sub(RawValue, i, i)
        if Char == "" then
            Byte = 0
        else
            Byte = string.byte(Char)
        end

        Result = Result + Multiplier[i - Offset] * Byte
        --Result = Result + 2 ^ (8 * (i - Offset - 1)) * Byte
    end

    return Result
end

function PointerGetSignedChar(FromValue)
    local Result = PointerGetUnsignedChar(FromValue)

    if Result > 0x7F then
        --Result = Result - 0xFF
        Result = Result - 0x100
    end

    return Result
end

function PointerGetUnsignedChar(FromValue)
    local RawValue = FromValue.RawValue.Val
    local Offset = FromValue.Offset
    local Char
    local Result

    Char = string.sub(RawValue, Offset + 1, Offset + 1)
    if Char == "" then
        Result = 0
    else
        Result = string.byte(Char)
    end

    return Result
end

-- Convert IEEE 754 representation to double precision FP
-- FromValue: AnyValue
function PointerGetFP(FromValue)
    local RawValue, Offset
    local ValueBits, Char, Byte
    local Q, R, NBits
    local ValueSign, BiasedExponent, Exponent, FractionalPart
    RawValue = FromValue.RawValue.Val
    Offset = FromValue.Offset
    ValueBits = {}

    RawValue = string.sub(RawValue, Offset + 1, Offset + 8)
    if string.len(RawValue) ~= 8 then
        -- Incomplete FP representation, set result to 0
        -- Debug only
        return 0
    end

    for i = 0, 7 do
        Char = string.sub(RawValue, 8 - i, 8 - i)
        if Char == "" then
            Byte = 0
        else
            Byte = string.byte(Char)
        end

        Q = Byte
        NBits = 0
        while Q > 0 do
            R = Q % 2
            Q = math.floor(Q / 2)
            table.insert(ValueBits, 1 + 8 * i, R)
            NBits = NBits + 1
        end
        for j = 1, 8 - NBits do
            table.insert(ValueBits, 1 + 8 * i, 0)
        end
    end

    if ValueBits[1] == 0 then
        ValueSign = 1
    else
        ValueSign = -1
    end

    BiasedExponent = 0
    for i = 2, 12 do
        BiasedExponent = BiasedExponent + 2 ^ (10 - (i - 2)) * ValueBits[i]
    end
    Exponent = BiasedExponent - 1023

    FractionalPart = 0
    for i = 13, 64 do
        FractionalPart = FractionalPart + 2 ^ (-(i - 12)) * ValueBits[i]
    end

    -- Value is 0
    if BiasedExponent == 0 and FractionalPart == 0 then
        return 0
    end

    -- Value is infinity
    if BiasedExponent == 2047 and FractionalPart == 0 then
        return math.huge
    end

    return ValueSign * 2 ^ Exponent * (1 + FractionalPart)
end

-- Get the C-style length of string in a char array
-- FromValue: AnyValue, must be a char array
function PointerStringLen(FromValue)
    local Offset = FromValue.Offset
    local RawValue = string.sub(FromValue.RawValue.Val, 1 + Offset)

    local i = string.find(RawValue, '\0')
    if i then
        return i - 1
    else
        return string.len(RawValue)
    end
end

function PointerGetString(FromValue)
    local Offset = FromValue.Offset
    local Len = PointerStringLen(FromValue)
    return string.sub(FromValue.RawValue.Val, 1 + Offset, 1 + Offset + Len - 1)
end

-- Copy a value from SourceVal to DestVal
-- DestVal, SourceVal: AnyValue; DestTyp: ValueType
-- DestTyp can only be arrays, structs and unions and have identical definitions
function PointerCopyValue(DestVal, SourceVal, DestTyp)
    local CopyRefs = false
    if DestTyp.Base == BaseType.TypeStruct or DestTyp.Base == BaseType.TypeUnion then
        CopyRefs = true
    end

    if DestTyp.Base == BaseType.TypeArray then
        local FromType = DestTyp.FromType
        while (FromType ~= nil and (FromType.Base == BaseType.TypeArray or
            FromType.Base == BaseType.TypePointer)) do
            if FromType == BaseType.TypePointer then
                CopyRefs = true
                break
            end
            FromType = FromType.FromType
        end
    end

    local Len = TypeSize(DestTyp, DestTyp.ArraySize, false)
    local SourceRawValue = SourceVal.RawValue.Val
    local SourceOffset = SourceVal.Offset
    local DestRawValue = DestVal.RawValue.Val
    local DestOffset = DestVal.Offset
    local DestLen = string.len(DestRawValue)

    if CopyRefs then
        local PointerPosList = {}
        if DestTyp.Base == BaseType.TypeStruct or DestTyp.Base == BaseType.TypeUnion then
            PointerGetPointerPos(DestTyp, 1, PointerPosList)
        else
            table.insert(PointerPosList, {
                From = 1,
                To = Len
            })
        end

        -- Remove old references
        for _, v in ipairs(PointerPosList) do
            local From = DestOffset + v.From
            local To = DestOffset + v.To
            for j = From, To, 4 do
                local IdentTo = string.sub(DestRawValue, j, j + 3)
                DestVal.RefOffsets[IdentTo] = nil
                DestVal.Pointer[IdentTo] = nil
            end
        end

        -- Assign new references
        for _, v in ipairs(PointerPosList) do
            local From = SourceOffset + v.From
            local To = SourceOffset + v.To
            for j = From, To, 4 do
                local IdentTo = string.sub(SourceRawValue, j, j + 3)
                DestVal.RefOffsets[IdentTo] = SourceVal.RefOffsets[IdentTo]
                DestVal.Pointer[IdentTo] = SourceVal.Pointer[IdentTo]
            end
        end
    end

    SourceRawValue = string.sub(SourceRawValue, 
        SourceOffset + 1, SourceOffset + MIN(Len, DestLen - DestOffset))
    local SourceLen = string.len(SourceRawValue)

    DestRawValue = string.sub(DestRawValue, 1, DestOffset) ..
        SourceRawValue .. string.sub(DestRawValue,
            DestOffset + SourceLen + 1)
    DestVal.RawValue.Val = DestRawValue
end

-- Recursively get all positions of pointers in a struct or union
function PointerGetPointerPos(StructTyp, InitPos, PointerPosList)
    for i = 1, StructTyp.Members.Size do
        local Entry = StructTyp.Members.HashTable[i]
        while Entry ~= nil do
            local MemberTyp = Entry.p.v.Val.Typ
            local MemberOffset = PointerGetSignedInt(Entry.p.v.Val.Val)

            if MemberTyp.Base == BaseType.TypePointer then
                table.insert(PointerPosList, {
                    From = InitPos + MemberOffset,
                    To = InitPos + MemberOffset + 4 - 1})
            elseif MemberTyp.Base == BaseType.TypeArray then
                local FromType = MemberTyp.FromType
                local Size = TypeSize(MemberTyp, MemberTyp.ArraySize, false)
                while (FromType ~= nil and (FromType.Base == BaseType.TypeArray or
                    FromType.Base == BaseType.TypePointer)) do
                    if FromType == BaseType.TypePointer then
                        table.insert(PointerPosList, {
                            From = InitPos + MemberOffset,
                            To = InitPos + MemberOffset + Size - 1
                        })
                        break
                    end
                    FromType = FromType.FromType
                end
            elseif MemberTyp.Base == BaseType.TypeStruct or MemberTyp.Base == BaseType.TypeUnion then
                PointerGetPointerPos(MemberTyp, InitPos + MemberOffset, PointerPosList)
            end

            Entry = Entry.Next
        end
    end
end

-- Generate a complete copy of SourceVal
-- SourceVal: AnyValue
function PointerCopyAllValues(SourceVal, Compact)
    local DestVal = {}
    DestVal.RawValue = {}
    DestVal.RawValue.Val = SourceVal.RawValue.Val

    DestVal.Ident = SourceVal.Ident
    DestVal.Offset = SourceVal.Offset

    DestVal.RefOffsets = {}
    for k in pairs(SourceVal.RefOffsets) do
        DestVal.RefOffsets[k] = SourceVal.RefOffsets[k]
    end

    DestVal.Pointer = {}
    for k in pairs(SourceVal.Pointer) do
        DestVal.Pointer[k] = SourceVal.Pointer[k]
    end
    --setmetatable(DestVal.Pointer, { __mode = "v" })

    if not Compact then
        DestVal.Typ = SourceVal.Typ

        if SourceVal.FuncDef ~= nil then
            DestVal.FuncDef = {}
            DestVal.FuncDef.ReturnType = SourceVal.FuncDef.ReturnType
            DestVal.FuncDef.NumParams = SourceVal.FuncDef.NumParams
            DestVal.FuncDef.VarArgs = SourceVal.FuncDef.VarArgs
            DestVal.FuncDef.ParamType = SourceVal.FuncDef.ParamType
            DestVal.FuncDef.ParamName = SourceVal.FuncDef.ParamName
            DestVal.FuncDef.Intrinsic = SourceVal.FuncDef.Intrinsic
            DestVal.FuncDef.Body = {}
            ParserCopy(DestVal.FuncDef.Body, SourceVal.FuncDef.Body)
        end

        if SourceVal.MacroDef ~= nil then
            DestVal.MacroDef = {}
            DestVal.MacroDef.NumParams = SourceVal.MacroDef.NumParams
            DestVal.MacroDef.ParamName = SourceVal.MacroDef.ParamName
            DestVal.MacroDef.Body = {}
            ParserCopy(DestVal.MacroDef.Body, SourceVal.FuncDef.Body)
        end
    end

    return DestVal
end

-- Copy the content of pointer FromValue to DestValue
-- DestValue, FromValue: AnyValue
-- The type of FromValue and DestValue can only be pointers
function PointerCopyPointer(DestValue, FromValue)
    local FromOffset = FromValue.Offset
    local DestOffset = DestValue.Offset

    local FromRawValue = FromValue.RawValue.Val
    local DestRawValue = DestValue.RawValue.Val
    local DestLen = string.len(DestRawValue)
    local FormerDestIdentTo = string.sub(DestRawValue, 1 + DestOffset, 4 + DestOffset)

    FromRawValue = string.sub(FromRawValue,
        FromOffset + 1, FromOffset + MIN(4, DestLen - DestOffset))
    local SourceLen = string.len(FromRawValue)

    -- Trying to copy a pointer identity at an unexpected location
    -- This should never happen
    assert(SourceLen == 4 or SourceLen == 0, "PointerCopyPointer: SourceLen is not 4 or 0")

    if SourceLen == 0 then
        return
    end

    local RefOffset = FromValue.RefOffsets[FromRawValue]
    local Pointer = FromValue.Pointer[FromRawValue]

    if RefOffset == nil or Pointer == nil then
        return
    end
    --assert(RefOffset ~= nil and Pointer ~= nil, "PointerCopyPointer: No reference in pointer")

    DestRawValue = string.sub(DestRawValue, 1, DestOffset) ..
        FromRawValue .. string.sub(DestRawValue,
            DestOffset + SourceLen + 1)

    DestValue.RawValue.Val = DestRawValue

    -- Remove former reference
    DestValue.RefOffsets[FormerDestIdentTo] = nil
    DestValue.Pointer[FormerDestIdentTo] = nil

    -- Assign new reference
    DestValue.RefOffsets[FromRawValue] = RefOffset
    DestValue.Pointer[FromRawValue] = Pointer
end

-- Derive a new value to NewPointerValue, all fields except Offset are linked to FromPointerValue
-- NewPointerValue, FromPointerValue: AnyValue
-- The type of FromPointerValue can only be arrays, structs or unions
function PointerDeriveNewValue(NewPointerValue, FromPointerValue, KeepIdent)
    NewPointerValue.Offset = FromPointerValue.Offset
    NewPointerValue.RawValue = FromPointerValue.RawValue
    if KeepIdent then
        NewPointerValue.Ident = FromPointerValue.Ident
    else
        NewPointerValue.Ident = math.random(1, 0x7FFFFFFF)  -- Generate a new identity
    end

    NewPointerValue.RefOffsets = FromPointerValue.RefOffsets
    NewPointerValue.Pointer = FromPointerValue.Pointer
end

function PointerReference(PointerValue, FromValue)
    local Ident = FromValue.Ident
    local Offset = FromValue.Offset
    local PointerOffset = PointerValue.Offset

    -- No enough space in the pointer to put reference
    if string.len(PointerValue.RawValue.Val) - PointerOffset < 4 then
        return
    end

    -- Remove former reference
    local FormerIdent = string.sub(PointerValue.RawValue.Val, 1 + PointerOffset, 4 + PointerOffset)
    PointerValue.RefOffsets[FormerIdent] = nil
    PointerValue.Pointer[FormerIdent] = nil

    -- Assign new reference
    -- Alter the identity to allow storing references to the same variable
    -- with different offsets
    PointerSetSignedOrUnsignedInt(PointerValue, math.random(1, 0x7FFFFFFF))
    local EncodedIdent = string.sub(PointerValue.RawValue.Val, 1 + PointerOffset, 4 + PointerOffset)
    PointerValue.RefOffsets[EncodedIdent] = Offset
    PointerValue.Pointer[EncodedIdent] = FromValue
end

function PointerDereference(FromValue)
    local Offset = FromValue.Offset
    local IdentTo = string.sub(FromValue.RawValue.Val, 1 + Offset, 4 + Offset)
    local RefOffset = FromValue.RefOffsets[IdentTo]
    local Pointer = FromValue.Pointer[IdentTo]
    local Result

    if RefOffset ~= nil and Pointer ~= nil then
        Result = {}
        Result.RawValue = Pointer.RawValue
        Result.Offset = RefOffset
        Result.Ident = Pointer.Ident
        Result.RefOffsets = Pointer.RefOffsets
        Result.Pointer = Pointer.Pointer
        return Result
    else
        return nil
    end
end

-- A small modification from C standard that void pointers will also be considered null
function IsPointerNull(PointerValue)
    local Offset = PointerValue.Offset
    local IdentTo = string.sub(PointerValue.RawValue.Val, 1 + Offset, 4 + Offset)

    local RefOffset = PointerValue.RefOffsets[IdentTo]
    local Pointer = PointerValue.Pointer[IdentTo]

    --if IdentTo == "\000\000\000\000" and RefOffset == nil and Pointer == nil then
    if RefOffset == nil and Pointer == nil then
        return true
    else
        return false
    end
end

function PointerSetNull(PointerValue)
    local Offset = PointerValue.Offset

    local RawValue = PointerValue.RawValue.Val
    local NullValue
    local Len = string.len(RawValue)
    local FormerIdentTo = string.sub(RawValue, 1 + Offset, 4 + Offset)

    NullValue = string.sub("\000\000\000\000", 1, MIN(4, Len - Offset))
    local NullLen = string.len(NullValue)

    assert(NullLen == 4 or NullLen == 0, "PointerSetNull: Len is not 4 or 0")

    if Len == 0 then
        return
    end

    RawValue = string.sub(RawValue, 1, Offset) ..
        NullValue .. string.sub(RawValue, Offset + NullLen + 1)

    PointerValue.RawValue.Val = RawValue

    -- Remove former reference
    PointerValue.RefOffsets[FormerIdentTo] = nil
    PointerValue.Pointer[FormerIdentTo] = nil
end

function PointerMovePointer(PointerValue, N)
    local Offset = PointerValue.Offset
    local IdentTo = string.sub(PointerValue.RawValue.Val, 1 + Offset, 4 + Offset)
    local RefOffset = PointerValue.RefOffsets[IdentTo]
    local Pointer = PointerValue.Pointer[IdentTo]

    if RefOffset ~= nil and Pointer ~= nil then
        RefOffset = RefOffset + N

        if RefOffset >= 0xFFFFFFFFFF then
            RefOffset = RefOffset - 0xFFFFFFFFFF
        elseif RefOffset < 0 then
            RefOffset = 0xFFFFFFFFFF + RefOffset
        end

        PointerValue.RefOffsets[IdentTo] = RefOffset
    end
end

function PointerComparePointer(PointerValue1, PointerValue2, CompareRefOffset)
    local Offset1 = PointerValue1.Offset
    local Offset2 = PointerValue2.Offset

    local IdentTo1 = string.sub(PointerValue1.RawValue.Val, 1 + Offset1, 4 + Offset1)
    local IdentTo2 = string.sub(PointerValue2.RawValue.Val, 1 + Offset2, 4 + Offset2)

    if IdentTo1 ~= IdentTo2 then
        return false, 0
    end

    local RefOffset1 = PointerValue1.RefOffsets[IdentTo1]
    local Pointer1 = PointerValue1.Pointer[IdentTo1]
    local RefOffset2 = PointerValue2.RefOffsets[IdentTo2]
    local Pointer2 = PointerValue2.Pointer[IdentTo2]

    if (RefOffset1 == nil or Pointer1 == nil or
        RefOffset2 == nil or Pointer2 == nil) then
        return false, 0
    end

    if Pointer1 ~= Pointer2 then
        return false, 0
    end

    if CompareRefOffset then
        if RefOffset1 ~= RefOffset2 then
            return false, RefOffset2 - RefOffset1
        end
    end

    return true, RefOffset2 - RefOffset1
end
function TableInit(pc)
    TableInitTable(pc.StringTable, pc.StringHashTable,
        STRING_TABLE_SIZE, true)
    pc.StrEmpty = TableStrRegister(pc, "")
end

function TableHash(KeyStr, Len)
    local Hash, Offset
    local KeyCharOrd
    Hash = Len

    Offset = 8
    for Count = 1, Len do
        if Offset > 4 * 8 - 7 then
            Offset = Offset - (4 * 8 - 6)
        end

        KeyCharOrd = string.byte(KeyStr, Count)
        Hash = bxor(Hash, lshift(KeyCharOrd, Offset))

        Offset = Offset + 7
    end

    return Hash
end

function TableInitTable(Tbl, HashTable, Size, OnHeap)
    Tbl.Size = Size
    Tbl.OnHeap = OnHeap
    Tbl.HashTable = HashTable
end

-- The original idea is that addresses to keys are unique even if
-- contents of two keys are identical
-- Key: AnyValue
function TableSearch(Tbl, Key)
    local HashValue, Entry, AddAt
    HashValue = (Key.Ident % Tbl.Size) + 1
    Entry = Tbl.HashTable[HashValue]

    while Entry ~= nil do
        if (Entry.p.v.Key == Key and not Entry.p.v.HiddenFromSearch) then
            return Entry, nil
        end
        Entry = Entry.Next
    end

    AddAt = HashValue
    return nil, AddAt
end

function TableSet(pc, Tbl, Key, Val, DeclFileName, DeclLine, DeclColumn)
    local AddAt, FoundEntry, NewEntry
    FoundEntry, AddAt = TableSearch(Tbl, Key)
    if FoundEntry == nil then
        NewEntry = VariableAlloc(pc, nil, Tbl.OnHeap)
        NewEntry.p = {
            v = {}, -- ValueEntry
            b = {}  -- BreakpointEntry
        }
        NewEntry.DeclFileName = DeclFileName
        NewEntry.DeclLine = DeclLine
        NewEntry.DeclColumn = DeclColumn
        NewEntry.p.v.Key = Key
        NewEntry.p.v.Val = Val
        NewEntry.Next = Tbl.HashTable[AddAt]
        Tbl.HashTable[AddAt] = NewEntry
        return true
    end

    return false
end

function TableGet(Tbl, Key)
    local FoundEntry
    local Val, DeclFileName, DeclLine, DeclColumn
    FoundEntry, _ = TableSearch(Tbl, Key)
    if FoundEntry == nil then
        return false, nil, nil, nil, nil
    end

    Val = FoundEntry.p.v.Val

    DeclFileName = FoundEntry.DeclFileName
    DeclLine = FoundEntry.DeclLine
    DeclColumn = FoundEntry.DeclColumn

    return true, Val, DeclFileName, DeclLine, DeclColumn
end

function TableDelete(pc, Tbl, Key)
    local HashValue, EntryPtr, DeleteEntry, Val
    local LastEntryPtr, ListDepth
    HashValue = (Key.Ident % Tbl.Size) + 1
    EntryPtr = Tbl.HashTable[HashValue]
    LastEntryPtr = EntryPtr
    ListDepth = 0

    while EntryPtr ~= nil do
        if EntryPtr.p.v.Key == Key then
            DeleteEntry = EntryPtr
            Val = DeleteEntry.p.v.Val
            if ListDepth == 0 then
                Tbl.HashTable[HashValue] = DeleteEntry.Next
            else
                LastEntryPtr.Next = DeleteEntry.Next
            end

            return Val
        end

        LastEntryPtr = EntryPtr
        EntryPtr = EntryPtr.Next
        ListDepth = ListDepth + 1
    end

    return nil
end

function TableSearchIdentifier(Tbl, KeyStr, Len)
    local HashValue, Entry
    local AddAt
    -- Lua index starts from 1
    HashValue = (TableHash(KeyStr, Len) % Tbl.Size) + 1
    Entry = Tbl.HashTable[HashValue]

    while Entry ~= nil do
        --if string.sub(Entry.p.Key.RawValue.Val, 1, Len) == string.sub(KeyStr, 1, Len) then
        if string.sub(Entry.p.Key.RawValue.Val, 1, Len) == string.sub(KeyStr, 1, Len) and
            Len == string.len(Entry.p.Key.RawValue.Val) then
            return Entry, nil
        end
        Entry = Entry.Next
    end

    AddAt = HashValue
    return nil, AddAt
end

-- Return: AnyValue
function TableSetIdentifier(pc, Tbl, IdentStr, IdentLen)
    local AddAt, FoundEntry, NewEntry
    FoundEntry, AddAt = TableSearchIdentifier(Tbl, IdentStr, IdentLen)

    if FoundEntry ~= nil then
        return FoundEntry.p.Key
    else
        -- Allocating the minimum portion of table needed
        NewEntry = {    -- TableEntry
            p = {
                v = {}, -- ValueEntry
                b = {}  -- BreakpointEntry
            },
        }
        NewEntry.p.Key = {    -- AnyValue
            RawValue = {
                Val = string.sub(IdentStr, 1, IdentLen)
            },
            Offset = 0,
            Ident = math.random(1, 0x7FFFFFFF),
            RefOffsets = {},
            Pointer = {}
        }
        --setmetatable(NewEntry.p.Key.Pointer, { __mode = "v" })

        NewEntry.Next = Tbl.HashTable[AddAt]
        Tbl.HashTable[AddAt] = NewEntry
        return NewEntry.p.Key
    end
end

-- Str: string
-- Return: AnyValue
function TableStrRegister2(pc, Str, Len)
    return TableSetIdentifier(pc, pc.StringTable, Str, Len)
end

-- Str: string
-- Return: AnyValue
function TableStrRegister(pc, Str)
    return TableStrRegister2(pc, Str, string.len(Str))
end

function TableStrFree(pc)
    local Entry, NextEntry

    for Count = 1, pc.StringTable.Size do
        Entry = pc.StringTable.HashTable[Count]
        while Entry ~= nil do
            NextEntry = Entry.Next
            Entry.Next = nil
            Entry = NextEntry
        end

        pc.StringTable.HashTable[Count] = nil
    end
end
function TypeAdd(pc, Parser, ParentType, Base, ArraySize, Identifier, Sizeof, AlignBytes)
    NewType = VariableAlloc(pc, Parser, true)
    NewType.Base = Base
    NewType.ArraySize = ArraySize
    NewType.Sizeof = Sizeof
    NewType.AlignBytes = AlignBytes
    NewType.Identifier = Identifier
    NewType.Members = nil
    NewType.FromType = ParentType
    NewType.DerivedTypeList = nil
    NewType.OnHeap = true
    NewType.StaticQualifier = false
    NewType.Next = ParentType.DerivedTypeList
    ParentType.DerivedTypeList = NewType

    return NewType
end

function TypeGetMatching(pc, Parser, ParentType, Base, ArraySize, Identifier, AllowDuplicates)
    local Sizeof
    local AlignBytes
    local ThisType = ParentType.DerivedTypeList
    while (ThisType ~= nil and (ThisType.Base ~= Base or
        ThisType.ArraySize ~= ArraySize or ThisType.Identifier ~= Identifier)) do
        ThisType = ThisType.Next
    end

    if ThisType ~= nil then
        if AllowDuplicates then
            return ThisType
        else
            ProgramFail(Parser, "data type '%s' is already defined", Identifier.RawValue.Val)
        end
    end

    if Base == BaseType.TypePointer then
        Sizeof = 4
        AlignBytes = PointerAlignBytes
    elseif Base == BaseType.TypeArray then
        Sizeof = ArraySize * ParentType.Sizeof
        AlignBytes = ParentType.AlignBytes
    elseif Base == BaseType.TypeEnum then
        Sizeof = 4
        AlignBytes = IntAlignBytes
    else
        Sizeof = 0
        AlignBytes = 0
    end
    --print(Sizeof)

    return TypeAdd(pc, Parser, ParentType, Base, ArraySize, Identifier, Sizeof,
        AlignBytes)
end

function TypeStackSizeValue(Val)
    if Val ~= nil and Val.ValOnStack then
        return TypeSizeValue(Val, false)
    else
        return 0
    end
end

function TypeSizeValue(Val, Compact)
    if IS_INTEGER_NUMERIC(Val) and not Compact then
        return 4
    elseif Val.Typ.Base ~= BaseType.TypeArray then
        return Val.Typ.Sizeof
    else
        return Val.Typ.FromType.Sizeof * Val.Typ.ArraySize
    end
end

function TypeSize(Typ, ArraySize, Compact)
    if IS_INTEGER_NUMERIC_TYPE(Typ) and not Compact then
        return 4
    elseif Typ.Base ~= BaseType.TypeArray then
        return Typ.Sizeof
    else
        return Typ.FromType.Sizeof * ArraySize
    end
end

function TypeAddBaseType(pc, TypeNode, Base, Sizeof, AlignBytes)
    TypeNode.Base = Base
    TypeNode.ArraySize = 0
    TypeNode.Sizeof = Sizeof
    TypeNode.AlignBytes = AlignBytes
    TypeNode.Identifier = pc.StrEmpty
    TypeNode.Members = nil
    TypeNode.FromType = nil
    TypeNode.DerivedTypeList = nil
    TypeNode.OnHeap = false
    TypeNode.Next = pc.UberType.DerivedTypeList
    TypeNode.StaticQualifier = false
    pc.UberType.DerivedTypeList = TypeNode
end

function TypeInit(pc)
    IntAlignBytes = 1
    PointerAlignBytes = 1

    pc.UberType.DerivedTypeList = nil
    TypeAddBaseType(pc, pc.IntType, BaseType.TypeInt, 4, IntAlignBytes)
    TypeAddBaseType(pc, pc.ShortType, BaseType.TypeShort, 2, 1)
    TypeAddBaseType(pc, pc.CharType, BaseType.TypeChar, 1, 1)
    TypeAddBaseType(pc, pc.LongType, BaseType.TypeLong, 4, 1)
    TypeAddBaseType(pc, pc.UnsignedIntType, BaseType.TypeUnsignedInt, 4, 1)
    TypeAddBaseType(pc, pc.UnsignedShortType, BaseType.TypeUnsignedShort, 2, 1)
    TypeAddBaseType(pc, pc.UnsignedLongType, BaseType.TypeUnsignedLong, 4, 1)
    TypeAddBaseType(pc, pc.UnsignedCharType, BaseType.TypeUnsignedChar, 1, 1)
    TypeAddBaseType(pc, pc.VoidType, BaseType.TypeVoid, 0, 1)
    TypeAddBaseType(pc, pc.FunctionType, BaseType.TypeFunction, 4, IntAlignBytes)
    TypeAddBaseType(pc, pc.MacroType, BaseType.TypeMacro, 4, IntAlignBytes)
    TypeAddBaseType(pc, pc.GotoLabelType, BaseType.TypeGotoLabel, 0, 1)
    TypeAddBaseType(pc, pc.FPType, BaseType.TypeFP, 8, 1)
    TypeAddBaseType(pc, pc.TypeType, BaseType.TypeType, 8, 1)
    pc.CharArrayType = TypeAdd(pc, nil, pc.CharType, BaseType.TypeArray, 0,
        pc.StrEmpty, 1, 1)
    pc.CharPtrType = TypeAdd(pc, nil, pc.CharType, BaseType.TypePointer, 0,
        pc.StrEmpty, 4, PointerAlignBytes)
    pc.CharPtrPtrType = TypeAdd(pc, nil, pc.CharPtrType, BaseType.TypeArray, 0,
        pc.StrEmpty, 4, PointerAlignBytes)
    pc.VoidPtrType = TypeAdd(pc, nil, pc.VoidType, BaseType.TypePointer, 0,
        pc.StrEmpty, 4, PointerAlignBytes)
end

function TypeCleanupNode(pc, Typ)
    local SubType, NextSubType
    local ListDepth = 0
    local LastSubType

    SubType = Typ.DerivedTypeList
    while SubType ~= nil do
        NextSubType = SubType.Next
        TypeCleanupNode(pc, SubType)

        if SubType.OnHeap then
            if SubType.Members ~= nil then
                VariableTableCleanup(pc, SubType.Members)
                SubType.Members = nil
            end

            if ListDepth == 0 then
                Typ.DerivedTypeList = nil
            else
                LastSubType.Next = nil
            end
        end

        LastSubType = SubType
        SubType = NextSubType
        ListDepth = ListDepth + 1
    end

end

function TypeCleanup(pc)
    TypeCleanupNode(pc, pc.UberType)
end

function TypeParseStruct(Parser, InitTyp, IsStruct)
    local MemberIdentifier
    local StructIdentifier
    local Token, Tok
    local MemberValue
    local pc = Parser.pc
    local LexValue
    local MemberType
    local Typ = InitTyp

    Token, LexValue = LexGetToken(Parser, LexValue, false)
    if Token == LexToken.TokenIdentifier then
        _, LexValue = LexGetToken(Parser, LexValue, true)
        StructIdentifier = LexValue.Val  -- Changed from LexValue.Val.Identifier
        Token, _ = LexGetToken(Parser, nil, false)
    else
        StructIdentifier = PlatformMakeTempName(pc, true)
    end

    local Base
    if IsStruct then
        Base = BaseType.TypeStruct
    else
        Base = BaseType.TypeUnion
    end
    Typ = TypeGetMatching(pc, Parser, Parser.pc.UberType,
        Base, 0, StructIdentifier, true)

    Token, _ = LexGetToken(Parser, nil, false)
    if Token ~= LexToken.TokenLeftBrace then
        return Typ
    end

    if pc.TopStackFrameId ~= 0 then
        ProgramFail(Parser, "struct/union definitions can only be globals")
    end

    LexGetToken(Parser, nil, true)
    Typ.Members = VariableAlloc(pc, Parser, true)
    Typ.Members.HashTable = {}
    TableInitTable(Typ.Members, Typ.Members.HashTable, STRUCT_TABLE_SIZE, true)

    repeat
        MemberType, MemberIdentifier, _ = TypeParse(Parser)
        if MemberType == nil or MemberIdentifier == nil then
            ProgramFail(Parser, "invalid type in struct")
        end

        MemberValue = VariableAllocValueAndData(pc, Parser, 4, false,
            nil, true)
        MemberValue.Typ = MemberType
        if IsStruct then
            PointerSetSignedOrUnsignedInt(MemberValue.Val, Typ.Sizeof)
            Typ.Sizeof = Typ.Sizeof + TypeSizeValue(MemberValue, true)
        else
            PointerSetSignedOrUnsignedInt(MemberValue.Val, 0)
            if MemberValue.Typ.Sizeof > Typ.Sizeof then
                Typ.Sizeof = TypeSizeValue(MemberValue, true)
            end
        end

        -- AlignBytes unused
        --[[
        if Typ.AlignBytes < MemberValue.Typ.AlignBytes then
            Typ.AlignBytes = MemberValue.Typ.AlignBytes
        end
        ]]

        if not TableSet(pc, Typ.Members, MemberIdentifier, MemberValue,
            Parser.FileName, Parser.Line, Parser.CharacterPos) then
            ProgramFail(Parser, "member '%s' already defined", MemberIdentifier)
        end

        Tok, _ = LexGetToken(Parser, nil, true)
        if Tok ~= LexToken.TokenSemicolon then
            ProgramFail(Parser, "semicolon expected")
        end

        Tok, _ = LexGetToken(Parser, nil, false)
    until Tok == LexToken.TokenRightBrace

    LexGetToken(Parser, nil, true)
    return Typ
end

-- StructName: AnyValue
function TypeCreateOpaqueStruct(pc, Parser, StructName, Size)
    local Typ = TypeGetMatching(pc, Parser, pc.UberType,
        BaseType.TypeStruct, 0, StructName, false)

    Typ.Members = VariableAlloc(pc, Parser, true)
    Typ.Members.HashTable = {}
    TableInitTable(Typ.Members, Typ.Members.HashTable,
        STRUCT_TABLE_SIZE, true)
    Typ.Sizeof = Size

    return Typ
end

function TypeParseEnum(Parser, InitTyp)
    local EnumValue = 0
    local EnumIdentifier
    local Token, Tok
    local LexValue
    local InitValue
    local pc = Parser.pc
    local Typ = InitTyp

    Token, LexValue = LexGetToken(Parser, LexValue, false)
    if Token == LexToken.TokenIdentifier then
        _, LexValue = LexGetToken(Parser, LexValue, true)
        EnumIdentifier = LexValue.Val   -- Changed from LexValue.Val.Identifier
        Token, _ = LexGetToken(Parser, nil, false)
    else
        EnumIdentifier = PlatformMakeTempName(pc, false)
    end

    TypeGetMatching(pc, Parser, pc.UberType, BaseType.TypeEnum, 0, EnumIdentifier,
        Token ~= LexToken.TokenLeftBrace)
    Typ = pc.IntType
    if Token ~= LexToken.TokenLeftBrace then
        if Typ.Members == nil then
            ProgramFail(Parser, "enum '%s' isn't defined", EnumIdentifier.RawValue.Val)
        end

        return Typ
    end

    if pc.TopStackFrameId ~= 0 then
        ProgramFail(Parser, "enum definitions can only be globals")
    end

    LexGetToken(Parser, nil, true)
    Typ.Members = pc.GlobalTable
    InitValue = VariableAllocValueFromType(pc, nil, pc.IntType, false, nil, true)
    PointerSetSignedOrUnsignedInt(InitValue.Val, EnumValue)
    repeat
        Tok, LexValue = LexGetToken(Parser, LexValue, true)
        if Tok ~= LexToken.TokenIdentifier then
            ProgramFail(Parser, "identifier expected")
        end

        EnumIdentifier = LexValue.Val    -- Changed from LexValue.Val.Identifier
        Tok, _ = LexGetToken(Parser, nil, false)
        if Tok == LexToken.TokenAssign then
            LexGetToken(Parser, nil, true)
            EnumValue = ExpressionParseInt(Parser)
        end

        PointerSetSignedOrUnsignedInt(InitValue.Val, EnumValue)
        VariableDefine(pc, Parser, EnumIdentifier, InitValue, nil, false)

        Token, _ = LexGetToken(Parser, nil, true)
        if Token ~= LexToken.TokenComma and Token ~= LexToken.TokenRightBrace then
            ProgramFail(Parser, "comma expected")
        end

        EnumValue = EnumValue + 1
    until Token ~= LexToken.TokenComma

    return Typ
end

function TypeParseFront(Parser)
    local Unsigned = false
    local StaticQualifier = false
    local Token
    local Before = {}
    local LexerValue
    local VarValue
    local pc = Parser.pc
    local Typ = nil
    local IsStatic

    ParserCopy(Before, Parser)
    Token, LexerValue = LexGetToken(Parser, LexerValue, true)
    while (Token == LexToken.TokenStaticType or Token == LexToken.TokenAutoType or
        Token == LexToken.TokenRegisterType or Token == LexToken.TokenExternType) do
        if Token == LexToken.TokenStaticType then
            StaticQualifier = true
        end

        Token, LexerValue = LexGetToken(Parser, LexerValue, true)
    end

    IsStatic = StaticQualifier

    if Token == LexToken.TokenSignedType or Token == LexToken.TokenUnsignedType then
        local FollowToken
        FollowToken, LexerValue = LexGetToken(Parser, LexerValue, false)
        Unsigned = (Token == LexToken.TokenUnsignedType)

        if (FollowToken ~= LexToken.TokenIntType and FollowToken ~= LexToken.TokenLongType and
            FollowToken ~= LexToken.TokenShortType and FollowToken ~= LexToken.TokenCharType) then
            if Token == LexToken.TokenUnsignedType then
                Typ = pc.UnsignedIntType
            else
                Typ = pc.IntType
            end

            return true, Typ, IsStatic
        end

        Token, LexerValue = LexGetToken(Parser, LexerValue, true)
    end

    if Token == LexToken.TokenIntType then
        if Unsigned then
            Typ = pc.UnsignedIntType
        else
            Typ = pc.IntType
        end
    elseif Token == LexToken.TokenShortType then
        if Unsigned then
            Typ = pc.UnsignedShortType
        else
            Typ = pc.ShortType
        end
    elseif Token == LexToken.TokenCharType then
        if Unsigned then
            Typ = pc.UnsignedCharType
        else
            Typ = pc.CharType
        end
    elseif Token == LexToken.TokenLongType then
        if Unsigned then
            Typ = pc.UnsignedLongType
        else
            Typ = pc.LongType
        end
    elseif Token == LexToken.TokenFloatType or Token == LexToken.TokenDoubleType then
        Typ = pc.FPType
    elseif Token == LexToken.TokenVoidType then
        Typ = pc.VoidType
    elseif Token == LexToken.TokenStructType or Token == LexToken.TokenUnionType then
        if Typ ~= nil then
            ProgramFail(Parser, "bad type declaration")
        end
        Typ = TypeParseStruct(Parser, Typ, Token == LexToken.TokenStructType)
    elseif Token == LexToken.TokenEnumType then
        if Typ ~= nil then
            ProgramFail(Parser, "bad type declaration")
        end
        Typ = TypeParseEnum(Parser, Typ)
    elseif Token == LexToken.TokenIdentifier then
        VarValue = VariableGet(pc, Parser, LexerValue.Val)  -- Changed from LexerValue.Val.Identifier
        --print("TypedefDef:", LexerValue.Val.RawValue.Val, VarValue.Val.Ident)
        Typ = VarValue.Val.Typ  -- Val here points to Typ, not AnyValue type
    else
        ParserCopy(Parser, Before)
        return false, Typ, IsStatic
    end

    return true, Typ, IsStatic
end

function TypeParseBack(Parser, FromType)
    local Token, Tok
    local Before = {}

    ParserCopy(Before, Parser)
    Token, _ = LexGetToken(Parser, nil, true)
    if Token == LexToken.TokenLeftSquareBracket then
        Tok, _ = LexGetToken(Parser, nil, false)
        if Tok == LexToken.TokenRightSquareBracket then
            LexGetToken(Parser, nil, true)
            return TypeGetMatching(Parser.pc, Parser,
                TypeParseBack(Parser, FromType), BaseType.TypeArray, 0,
                Parser.pc.StrEmpty, true)
        else
            local OldMode = Parser.Mode
            local ArraySize
            Parser.Mode = RunMode.RunModeRun
            ArraySize = ExpressionParseInt(Parser)
            Parser.Mode = OldMode

            Tok, _ = LexGetToken(Parser, nil, true)
            if Tok ~= LexToken.TokenRightSquareBracket then
                ProgramFail(Parser, "']' expected")
            end

            return TypeGetMatching(Parser.pc, Parser,
                TypeParseBack(Parser, FromType), BaseType.TypeArray, ArraySize,
                Parser.pc.StrEmpty, true)
        end
    else
        ParserCopy(Parser, Before)
        return FromType
    end
end

function TypeParseIdentPart(Parser, BasicTyp)
    local Done = false
    local Token, Tok
    local LexValue
    local Before = {}
    local Typ = BasicTyp
    local Identifier = Parser.pc.StrEmpty

    while not Done do
        ParserCopy(Before, Parser)
        Token, LexValue = LexGetToken(Parser, LexValue, true)
        if Token == LexToken.TokenOpenBracket then
            if Typ ~= nil then
                ProgramFail(Parser, "bad type declaration")
            end

            Typ, Identifier, _ = TypeParse(Parser)
            Tok, _ = LexGetToken(Parser, nil, true)
            if Tok ~= LexToken.TokenCloseBracket then
                ProgramFail(Parser, "')' expected")
            end
        elseif Token == LexToken.TokenAsterisk then
            if Typ == nil then
                ProgramFail(Parser, "bad type declaration")
            end

            Typ = TypeGetMatching(Parser.pc, Parser, Typ, BaseType.TypePointer, 0,
                Parser.pc.StrEmpty, true)
        elseif Token == LexToken.TokenIdentifier then
            if Typ == nil or Identifier ~= Parser.pc.StrEmpty then
                ProgramFail(Parser, "bad type declaration")
            end

            Identifier = LexValue.Val    -- Changed from LexValue.Val.Identifier
            Done = true
        else
            ParserCopy(Parser, Before)
            Done = true
        end
    end

    if Typ == nil then
        ProgramFail(Parser, "bad type declaration")
    end

    if Identifier ~= Parser.pc.StrEmpty then
        Typ = TypeParseBack(Parser, Typ)
    end

    return Typ, Identifier
end

function TypeParse(Parser)
    local BasicType
    local Typ, Identifier, IsStatic

    _, BasicType, IsStatic = TypeParseFront(Parser)
    Typ, Identifier = TypeParseIdentPart(Parser, BasicType)

    return Typ, Identifier, IsStatic
end

function TypeIsForwardDeclared(Parser, Typ)
    if Typ.Base == BaseType.TypeArray then
        return TypeIsForwardDeclared(Parser, Typ.FromType)
    end

    if ((Typ.Base == BaseType.TypeStruct or Typ.Base == BaseType.TypeUnion) and
        Typ.Members == nil) then
        return true
    end

    return false
end
MAX_TMP_COPY_BUF = 256

function VariableInit(pc)
    TableInitTable(pc.GlobalTable, pc.GlobalHashTable, GLOBAL_TABLE_SIZE, true)
    TableInitTable(pc.StringLiteralTable, pc.StringLiteralHashTable, STRING_LITERAL_TABLE_SIZE, true)
end

function VariableFree(pc, Val)
    -- Scan on the stack and remove all references to Val
    -- This ensures Val can be garbage-collected
    --[[
    local StackId = 1
    local StackNode = pc.HeapMemory[StackId]
    while StackNode ~= nil do
        if StackNode == Val then
            pc.HeapMemory[StackId] = {}
        end

        if StackNode.Val == Val.Val then
            pc.HeapMemory[StackId] = {}
        end

        if StackNode.Val ~= nil and Val.Val.RawValue ~= nil then
            if StackNode.Val.RawValue == Val.Val.RawValue then
                pc.HeapMemory[StackId] = {}
            end
        end

        StackId = StackId + 1
        StackNode = pc.HeapMemory[StackId]
    end
    ]]

    if Val.ValOnHeap or Val.AnyValOnHeap then
        if (Val.Typ == pc.FunctionType and
            Val.Val.FuncDef.Intrinsic == nil and 
            Val.Val.FuncDef.Body.ParsingTokens ~= nil) then
            Val.Val.FuncDef.Body.ParsingTokens = nil
        end

        if Val.Typ == pc.MacroType then
            Val.Val.MacroDef.Body.ParsingTokens = nil
        end

        if Val.AnyValOnHeap then
            Val.Val = nil
        end
    end

    -- If Val is not on the stack, then no other references shall exists for Val
    -- Val will be garbage-collected after exiting this function
    Val = nil
end

function VariableTableCleanup(pc, HashTable)
    local Entry, NextEntry
    local ListDepth, LastEntry
    ListDepth = 0

    for Count = 1, HashTable.Size do
        Entry = HashTable.HashTable[Count]
        while Entry ~= nil do
            NextEntry = Entry.Next

            VariableFree(pc, Entry.p.v.Val)
            if Entry.p.v.Val.ValOnHeap then
                Entry.p.v.Val = nil
            end

            if ListDepth == 0 then
                HashTable.HashTable[Count] = nil
            else
                LastEntry.Next = nil
            end

            LastEntry = Entry
            Entry = NextEntry
            ListDepth = ListDepth + 1
        end
    end

end

function VariableCleanup(pc)
    VariableTableCleanup(pc, pc.GlobalTable)
    VariableTableCleanup(pc, pc.StringLiteralTable)
end

function VariableAlloc(pc, Parser, OnHeap)
    if OnHeap then
        return {}
    else
        return HeapAllocStack(pc)
    end
end

function VariableAllocAnyValue(DataSize)
    local RawValue = string.rep("\000", DataSize)
    local NewValue
    NewValue = {    -- AnyValue
        RawValue = {
            Val = RawValue
        },
        Offset = 0,
        Ident = math.random(1, 0x7FFFFFFF),      -- 0 for temporary value on the stack, should be > 0 for defined variables
        RefOffsets = {},
        Pointer = {},
        FuncDef = {     -- FuncDef
            Body = {}   -- ParseState
        },
        MacroDef = {    -- MacroDef
            Body = {}   -- ParseState
        }
    }
    --setmetatable(NewValue.Val.Pointer, { __mode = "v" })

    return NewValue
end

function VariableAllocValueAndData(pc, Parser, DataSize, IsLValue, LValueFrom, OnHeap)
    local RawValue = string.rep("\000", DataSize)
    local NewValue
    NewValue = VariableAlloc(pc, Parser, OnHeap)
    NewValue.Val = {    -- AnyValue
        RawValue = {
            Val = RawValue
        },
        Offset = 0,
        Ident = math.random(1, 0x7FFFFFFF),      -- 0 for temporary value on the stack, should be > 0 for defined variables
        RefOffsets = {},
        Pointer = {},
        FuncDef = {     -- FuncDef
            Body = {}   -- ParseState
        },
        MacroDef = {    -- MacroDef
            Body = {}   -- ParseState
        }
    }
    --setmetatable(NewValue.Val.Pointer, { __mode = "v" })

    NewValue.ValOnHeap = OnHeap
    NewValue.AnyValOnHeap = false
    NewValue.ValOnStack = not OnHeap
    NewValue.IsLValue = IsLValue
    NewValue.LValueFrom = LValueFrom
    if Parser ~= nil then
        NewValue.ScopeID = Parser.ScopeID
    end

    NewValue.OutOfScope = false

    return NewValue
end

function VariableAllocValueFromType(pc, Parser, Typ, IsLValue, LValueFrom, OnHeap)
    local Size, NewValue
    Size = TypeSize(Typ, Typ.ArraySize, false)
    NewValue = VariableAllocValueAndData(pc, Parser, Size, IsLValue, LValueFrom, OnHeap)
    NewValue.Typ = Typ

    return NewValue
end

function VariableAllocValueAndCopy(pc, Parser, FromValue, OnHeap)
    local DType, NewValue
    DType = FromValue.Typ

    NewValue = VariableAllocValueAndData(pc, Parser, 0,
        FromValue.IsLValue, FromValue.LValueFrom, OnHeap)
    NewValue.Typ = DType
    NewValue.Val = PointerCopyAllValues(FromValue.Val, false)

    return NewValue
end

function VariableAllocValueFromExistingData(Parser, Typ, FromValue, IsLValue, LValueFrom)
    local NewValue
    NewValue = VariableAlloc(Parser.pc, Parser, false)
    NewValue.Typ = Typ
    NewValue.Val = FromValue
    NewValue.ValOnHeap = false
    NewValue.AnyValOnHeap = false
    NewValue.ValOnStack = false
    NewValue.IsLValue = IsLValue
    NewValue.LValueFrom = LValueFrom
    NewValue.ScopeID = 0
    NewValue.OutOfScope = false

    return NewValue
end

function VariableAllocValueShared(Parser, FromValue)
    if FromValue.IsLValue then
        return VariableAllocValueFromExistingData(Parser, FromValue.Typ,
            FromValue.Val, FromValue.IsLValue, FromValue)
    else
        return VariableAllocValueFromExistingData(Parser, FromValue.Typ,
            FromValue.Val, FromValue.IsLValue, nil)
    end
end

function VariableRealloc(Parser, FromValue, NewSize)
    local RawValue = string.rep('\000', NewSize)
    FromValue.Val.RawValue.Val = RawValue
end

function VariableScopeBegin(Parser)
    local Entry, NextEntry, HashTable
    local OldScopeID

    if Parser.ScopeID == -1 then
        return -1, nil
    end

    if Parser.pc.TopStackFrameId == 0 then
        HashTable = Parser.pc.GlobalTable
    else
        local TopStackFrame = HeapGetStackNode(Parser.pc, Parser.pc.TopStackFrameId)
        HashTable = TopStackFrame.LocalTable
    end

    OldScopeID = Parser.ScopeID
    Parser.ScopeID = Parser.Line * 0x10000 + Parser.CharacterPos

    for Count = 1, HashTable.Size do
        Entry = HashTable.HashTable[Count]
        while Entry ~= nil do
            NextEntry = Entry.Next
            if (Entry.p.v.Val.ScopeID == Parser.ScopeID and
                Entry.p.v.Val.OutOfScope == true) then
                Entry.p.v.Val.OutOfScope = false
                -- Here the address is altered back
                -- so we set the flag to false
                Entry.p.v.HiddenFromSearch = false
            end
            Entry = NextEntry
        end
    end

    return Parser.ScopeID, OldScopeID
end

function VariableScopeEnd(Parser, ScopeID, PrevScopeID)
    local Entry, NextEntry, HashTable

    if ScopeID == -1 then
        return
    end

    if Parser.pc.TopStackFrameId == 0 then
        HashTable = Parser.pc.GlobalTable
    else
        local TopStackFrame = HeapGetStackNode(Parser.pc, Parser.pc.TopStackFrameId)
        HashTable = TopStackFrame.LocalTable
    end

    for Count = 1, HashTable.Size do
        Entry = HashTable.HashTable[Count]
        while Entry ~= nil do
            NextEntry = Entry.Next
            if (Entry.p.v.Val.ScopeID == Parser.ScopeID and
                Entry.p.v.Val.OutOfScope == false) then
                Entry.p.v.Val.OutOfScope = true
                -- The purpose of author here is to alter the address of
                -- the key so that it cannot be found by the
                -- table search algorithm
                -- But Lua does not support direct addressing, so
                -- we put a flag here so that the search algorithm
                -- will ignore this key when it sees the flag
                Entry.p.v.HiddenFromSearch = true
            end
            Entry = NextEntry
        end
    end

    Parser.ScopeID = PrevScopeID
end

function VariableDefinedAndOutOfScope(pc, Ident)
    local Entry, HashTable

    if pc.TopStackFrameId == 0 then
        HashTable = pc.GlobalTable
    else
        local TopStackFrame = HeapGetStackNode(pc, pc.TopStackFrameId)
        HashTable = TopStackFrame.LocalTable
    end

    for Count = 1, HashTable.Size do
        Entry = HashTable.HashTable[Count]
        while Entry ~= nil do
            if (Entry.p.v.Val.OutOfScope == true and
                Entry.p.v.Key == Ident) then
                return true
            end
            Entry = Entry.Next
        end
    end

    return false
end

function VariableDefine(pc, Parser, Ident, InitValue, Typ, MakeWritable)
    local ScopeID, AssignValue, currentTable, OnHeap
    local FileName, Line, CharacterPos

    if Parser ~= nil then
        ScopeID = Parser.ScopeID
        FileName = Parser.FileName
        Line = Parser.Line
        CharacterPos = Parser.CharacterPos
    else
        ScopeID = -1
        FileName = nil
        Line = 0
        CharacterPos = 0
    end
    if pc.TopStackFrameId == 0 then
        currentTable = pc.GlobalTable
        OnHeap = true
    else
        local TopStackFrame = HeapGetStackNode(pc, pc.TopStackFrameId)
        currentTable = TopStackFrame.LocalTable
        OnHeap = false
    end

    if InitValue ~= nil then
        AssignValue = VariableAllocValueAndCopy(pc, Parser, InitValue, OnHeap)
    else
        AssignValue = VariableAllocValueFromType(pc, Parser, Typ, MakeWritable, nil, OnHeap)
    end

    AssignValue.IsLValue = MakeWritable
    AssignValue.ScopeID = ScopeID
    AssignValue.OutOfScope = false
    --if Debug then
    --    print(Ident.RawValue.Val)
    --end

    if not TableSet(pc, currentTable, Ident, AssignValue, FileName, Line, CharacterPos) then
        ProgramFail(Parser, "'%s' is already defined", Ident.RawValue.Val)
    end

    return AssignValue
end

function VariableDefineButIgnoreIdentical(Parser, Ident, Typ, IsStatic)
    local FirstVisit
    local DeclLine, DeclColumn, DeclFileName, pc, ExistingValue
    local MangledName, RegisteredMangledName
    local Success
    local HashTable
    FirstVisit = false
    pc = Parser.pc

    if TypeIsForwardDeclared(Parser, Typ) then
        ProgramFail(Parser, "type '%t' isn't defined", Typ)
    end

    if IsStatic then
        -- Parser.FileName: AnyValue
        -- TopStackFrame.FunctionName: AnyValue
        MangledName = "/"
        MangledName = string.sub(MangledName .. Parser.FileName.RawValue.Val, 1, LINEBUFFER_MAX)

        if pc.TopStackFrameId ~= 0 then
            local TopStackFrame = HeapGetStackNode(pc, pc.TopStackFrameId)
            MangledName = MangledName .. "/"
            MangledName = string.sub(MangledName .. TopStackFrame.FuncName.RawValue.Val, 1, LINEBUFFER_MAX)
        end

        -- Ident: AnyValue
        MangledName = MangledName .. "/"
        MangledName = string.sub(MangledName .. Ident.RawValue.Val, 1, LINEBUFFER_MAX)
        RegisteredMangledName = TableStrRegister(pc, MangledName)

        Success, ExistingValue, DeclFileName, DeclLine, DeclColumn = TableGet(pc.GlobalTable, RegisteredMangledName)
        if not Success then
            ExistingValue = VariableAllocValueFromType(Parser.pc, Parser, Typ,
                true, nil, true)
            TableSet(pc, pc.GlobalTable, RegisteredMangledName,
                ExistingValue, Parser.FileName, Parser.Line,
                Parser.CharacterPos)
            FirstVisit = true
        end

        VariableDefinePlatformVar(Parser.pc, Parser, Ident.RawValue.Val, ExistingValue.Typ,
            ExistingValue.Val, true)
        return ExistingValue, FirstVisit
    else
        if pc.TopStackFrameId == 0 then
            HashTable = pc.GlobalTable
        else
            local TopStackFrame = HeapGetStackNode(pc, pc.TopStackFrameId)
            HashTable = TopStackFrame.LocalTable
        end

        Success, ExistingValue, DeclFileName, DeclLine, DeclColumn = TableGet(HashTable, Ident)
        if (Parser.Line ~= 0 and Success and
            DeclFileName == Parser.FileName and DeclLine == Parser.Line and
            DeclColumn == Parser.CharacterPos) then
            return ExistingValue, FirstVisit
        else
            return VariableDefine(Parser.pc, Parser, Ident, nil, Typ, true), FirstVisit
        end
    end
end

function VariableDefined(pc, Ident)
    local Success

    if pc.TopStackFrameId ~= 0 then
        local TopStackFrame = HeapGetStackNode(pc, pc.TopStackFrameId)
        Success, _, _, _, _ = TableGet(TopStackFrame.LocalTable, Ident)
    end

    if pc.TopStackFrameId == 0 or not Success then
        Success, _, _, _, _ = TableGet(pc.GlobalTable, Ident)
        if not Success then
            return false
        end
    end

    return true
end

function VariableGet(pc, Parser, Ident)
    local LVal
    local Success

    if pc.TopStackFrameId ~= 0 then
        local TopStackFrame = HeapGetStackNode(pc, pc.TopStackFrameId)
        Success, LVal, _, _, _ = TableGet(TopStackFrame.LocalTable, Ident)
    end

    if pc.TopStackFrameId == 0 or not Success then
        Success, LVal, _, _, _ = TableGet(pc.GlobalTable, Ident)
        if not Success then
            if VariableDefinedAndOutOfScope(pc, Ident) then
                ProgramFail(Parser, "'%s' is out of scope", Ident.RawValue.Val)
            else
                ProgramFail(Parser, "VariableGet Ident: '%s' is undefined", Ident.RawValue.Val)
            end
        end
    end

    return LVal
end

function VariableDefinePlatformVar(pc, Parser, IdentStr, Typ, FromValue, IsWritable)
    local SomeValue
    local HashTable
    local FileName, Line, CharacterPos
    SomeValue = VariableAllocValueAndData(pc, nil, 0, IsWritable,
        nil, true)
    SomeValue.Typ = Typ
    SomeValue.Val = FromValue

    if Parser ~= nil then
        FileName = Parser.FileName
        Line = Parser.Line
        CharacterPos = Parser.CharacterPos
    else
        FileName = nil
        Line = 0
        CharacterPos = 0
    end
    if pc.TopStackFrameId == 0 then
        HashTable = pc.GlobalTable
    else
        local TopStackFrame = HeapGetStackNode(pc, pc.TopStackFrameId)
        HashTable = TopStackFrame.LocalTable
    end

    if (not TableSet(pc, HashTable, TableStrRegister(pc, IdentStr), SomeValue,
        FileName, Line, CharacterPos)) then
        ProgramFail(Parser, "'%s' is already defined", IdentStr)
    end
end

function VariableStackPop(Parser, Var)
    local Success = HeapPopStack(Parser.pc, 1, Var.StackId - 1)

    if not Success then
        ProgramFail(Parser, "stack underrun")
    end
end

function VariableStackFrameAdd(Parser, FuncName, NumParams)
    local NewFrame

    HeapPushStackFrame(Parser.pc)
    NewFrame = HeapAllocStack(Parser.pc)
    if NewFrame == nil then
        ProgramFail("(VariableStackFrameAdd) out of memory")
    end

    -- Initialize the StackFrame structure
    NewFrame.ReturnParser = {}
    NewFrame.LocalTable = {}
    NewFrame.LocalHashTable = {}

    ParserCopy(NewFrame.ReturnParser, Parser)
    NewFrame.FuncName = FuncName
    if NumParams > 0 then
        NewFrame.Parameter = {}
    else
        NewFrame.Parameter = nil
    end
    TableInitTable(NewFrame.LocalTable, NewFrame.LocalHashTable,
        LOCAL_TABLE_SIZE, false)
    NewFrame.PreviousStackFrameId = Parser.pc.TopStackFrameId
    Parser.pc.TopStackFrameId = NewFrame.StackId
end

function VariableStackFramePop(Parser)
    if Parser.pc.TopStackFrameId == 0 then
        ProgramFail(Parser, "stack is empty - can't go back")
    end

    local TopStackFrame = HeapGetStackNode(Parser.pc, Parser.pc.TopStackFrameId)
    ParserCopy(Parser, TopStackFrame.ReturnParser)
    Parser.pc.TopStackFrameId = TopStackFrame.PreviousStackFrameId
    HeapPopStackFrame(Parser.pc)
end

function VariableStringLiteralGet(pc, Ident)
    local LVal
    local Success

    Success, LVal, _, _, _ = TableGet(pc.StringLiteralTable, Ident)
    if Success then
        return LVal
    else
        return nil
    end
end

function VariableStringLiteralDefine(pc, Ident, Val)
    TableSet(pc, pc.StringLiteralTable, Ident, Val, nil, 0, 0)
end

function VariableDereferencePointer(PointerValue)
    local DerefVal, DerefType, DerefOffset, DerefIsLValue

    DerefType = PointerValue.Typ.FromType
    DerefOffset = 0
    DerefIsLValue = true
    DerefVal = PointerDereference(PointerValue.Val)

    return DerefVal, nil, DerefType, DerefOffset, DerefIsLValue
end
function BasicIOInit(pc)
    pc.CStdOut = {
        puts = function (Str)
            unistd.write(1, Str)
        end
    }
end

function PlatformInit(pc)
    -- Empty function
end

function PlatformCleanup(pc)
    -- Empty function
end

function PlatformGetLine(MaxLen, Prompt)
    if Prompt ~= nil then
         unistd.write(1, Prompt)
    end

    return unistd.read(0)
end

function PlatformReadFile(pc, FileName)
    local InFile

    InFile = unistd.open(FileName, unistd.O_RDONLY)
    if InFile == nil then
        ProgramFailNoParser(pc, "can't read file %s\n", FileName)
    end

    ReadText = unistd.readall(InFile)
    if string.len(ReadText) == 0 then
        ProgramFailNoParser(pc, "can't read file %s\n", FileName)
    end

    unistd.close(InFile)

    if string.sub(ReadText, 1, 1) == '#' and string.sub(ReadText, 2, 2) == '!' then
        local Pos
        Pos, Pos = string.find(ReadText, "\r")
        if Pos == nil then
            Pos = string.len(ReadText)
        end
        ReadText = string.gsub(string.sub(ReadText, 1, Pos - 1), "")
    end

    return ReadText
end

function PicocPlaformScanFile(pc, FileName)
    local SourceStr = PlatformReadFile(pc, FileName)

    if SourceStr ~= nil then
        local Leading = string.sub(SourceStr, 1, 2)
        if Leading == "#!" then
            SourceStr = string.gsub(SourceStr, Leading, "//")
        end
    end

    PicocParse(pc, FileName, SourceStr, string.len(SourceStr), true,
        GEnableDebugger)
end

function PlatformExit(pc, RetVal)
    pc.PicocExitValue = RetVal
    --error("C Parsing Error")
    coroutine.yield({type = "exit" , code = RetVal})
end

function GetSystemCounter()
    return coroutine.yield({type = "time"})
end

local function main()
    -- function main
    a = coroutine.yield({ type = "time" })
    math.randomseed(math.floor(a))
    t = 0

    ParamCount = 1
    DontRunMain = false
    PicoC = {}
    argc = #arg + 1

    if argc < 2 or arg[ParamCount] == "-h" then
        print(PICOC_VERSION .. "  \n" ..
            "Format:\n\n" ..
            "> picoc <file1.c>... [- <arg1>...]     : run a program, calls main() as the entry point\n" ..
            "> picoc -s <file1.c>... [- <arg1>...]  : run a script, runs the program without calling main()\n" ..
            "> picoc -i                             : interactive mode, Ctrl+d to exit\n" ..
            "> picoc -c                             : copyright info\n" ..
            "> picoc -h                             : this help message")
        return 0
    end

    if arg[ParamCount] == "-c" then
        return 0
    end

    PicocInitialize(PicoC)

    if arg[ParamCount] == "-s" then
        DontRunMain = true
        --PicocIncludeAllSystemHeaders(PicoC)
        ParamCount = ParamCount + 1
    end

    if argc > ParamCount and arg[ParamCount] == "-i" then
        PicocIncludeAllSystemHeaders(PicoC)
        PicocParseInteractive(PicoC)
    else
        while ParamCount < argc and arg[ParamCount] ~= "-" do
            PicocPlaformScanFile(PicoC, arg[ParamCount])
            ParamCount = ParamCount + 1
        end

        if not DontRunMain then
            ArgV = {}
            for i = ParamCount, argc do
                table.insert(ArgV, arg[i])
            end
            PicocCallMain(PicoC, #ArgV, ArgV)
        end
    end

    print(coroutine.yield({ type = "time" }) - a)
    print(t)

    PicocCleanup(PicoC)
    return PicoC.PicocExitValue
end

main()
