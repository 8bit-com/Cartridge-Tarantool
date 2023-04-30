package = "luatest"
version = "0.5.6-1"
source = {
   url = "git://github.com/tarantool/luatest.git",
   tag = "0.5.6",
   branch = "master"
}
description = {
   summary = "Tool for testing tarantool applications",
   homepage = "https://github.com/tarantool/luatest",
   license = "MIT"
}
dependencies = {
   "lua >= 5.1",
   "checks >= 3.0.0"
}
external_dependencies = {
   TARANTOOL = {
      header = "tarantool/module.h"
   }
}
build = {
   type = "cmake",
   variables = {
      LUAROCKS = "true",
      TARANTOOL_DIR = "$(TARANTOOL_DIR)",
      TARANTOOL_INSTALL_BINDIR = "$(BINDIR)",
      TARANTOOL_INSTALL_LUADIR = "$(LUADIR)"
   }
}
