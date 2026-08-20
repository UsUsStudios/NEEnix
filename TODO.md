# TODO

- [x] `procfs` kernel data
- [ ] liblua
  - [x] file descriptor I/O, ch. 13
  - [x] file system I/O, ch. 14
  - [x] pipes, ch. 16
  - [x] sighandling, ch. 25
  - [x] processes, ch. 26 and 27
  - [x] system management and config, ch. 32 and 33
  - [ ] date and time, ch. 22
  - [x] math, ch. 19 and 20

- [ ] user input
- [ ] terminal emulator
- [ ] shell
- [ ] `devfs`
  - [ ] device tracker daemon
  - [ ] disk device
  - [x] color display peripheral + screen device
  - [ ] simple display peripheral + headsup device
  - [ ] keyboard input device
  - [ ] computer peripheral
  - [ ] drive bay peripheral
  - [ ] redstone controller peripheral
  - [ ] dynamic light peripheral
- [ ] internet syscalls API
- [ ] neato compatability layer
- [ ] fix error traceback to not include stack frames below the one that got the blame
- [ ] add some languages transpiled/interpreted in lua, examples:
  - [x] js: <https://github.com/PaulBernier/castl> impossible: requires debug.setmetatable
  - [x] C: <https://github.com/ExAcler/XPicoC> functional, not tested
  - [ ] C: <https://github.com/shinh/ELVM> delayed: already functional with XPicoC
  - [ ] scheme: <https://github.com/allea/lal>
  - [ ] lisp: <https://github.com/zick/LuaLisp>
  - [ ] lisp: <https://github.com/bullno1/mLisp/blob/master/mLisp.lua>
  - [ ] forth: <https://github.com/zeroflag/equinox>
  - [ ] forth: <https://github.com/vifino/luaforth>
  - [ ] brainfuck: <https://github.com/ExtReMLapin/fast_brainfuck.lua>
  - [ ] brainfuck: <https://github.com/TangentFoxy/LuaFuck>
  - [ ] chip-8: <https://github.com/brianhang/chip8-lua>
  - [ ] BASIC: <https://gist.github.com/MineRobber9000/7d735c2cd6620760670b9658760b4790>
  - [ ] moonscript: <https://github.com/leafo/moonscript>
  - [ ] typescript: <https://github.com/TypeScriptToLua/TypeScriptToLua>
  - [ ] python: <https://github.com/DreamAndDead/medusa>
  - [ ] python: <https://github.com/ThePiGuy24/Pythish>

## Post-release

- [ ] user system
- [ ] permissions system
- [ ] symlinks
- [ ] compositor?
