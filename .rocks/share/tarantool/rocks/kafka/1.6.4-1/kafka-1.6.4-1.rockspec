package = "kafka"
version = "1.6.4-1"
source = {
   url = "git+https://github.com/tarantool/kafka.git",
   tag = "1.6.4",
   branch = "master"
}
description = {
   summary = "Kafka library for Tarantool",
   homepage = "https://github.com/tarantool/kafka",
   license = "Apache"
}
dependencies = {
   "lua >= 5.1"
}
external_dependencies = {
   TARANTOOL = {
      header = "tarantool/module.h"
   }
}
build = {
   type = "cmake",
   variables = {
      CMAKE_BUILD_TYPE = "RelWithDebInfo",
      STATIC_BUILD = "$(STATIC_BUILD)",
      TARANTOOL_DIR = "$(TARANTOOL_DIR)",
      TARANTOOL_INSTALL_LIBDIR = "$(LIBDIR)",
      TARANTOOL_INSTALL_LUADIR = "$(LUADIR)",
      WITH_OPENSSL_1_1 = "$(WITH_OPENSSL_1_1)"
   }
}
