.PHONY: all install clean

all:
	cd /data/openresty/openresty_src/1.15.8.1/build/LuaJIT-2.1-20190507 && $(MAKE) TARGET_STRIP=@: CCDEBUG=-g XCFLAGS='-std=gnu99 -DLUAJIT_ENABLE_LUA52COMPAT -DLUAJIT_ENABLE_GC64' CC=cc PREFIX=/data/pkg/openresty/luajit
	cd /data/openresty/openresty_src/1.15.8.1/build/lua-cjson-2.1.0.7 && $(MAKE) DESTDIR=$(DESTDIR) LUA_INCLUDE_DIR=/data/openresty/openresty_src/1.15.8.1/build/luajit-root/data/pkg/openresty/luajit/include/luajit-2.1 LUA_CMODULE_DIR=/data/pkg/openresty/lualib LUA_MODULE_DIR=/data/pkg/openresty/lualib CJSON_CFLAGS="-g -fpic" CC=cc
	cd /data/openresty/openresty_src/1.15.8.1/build/lua-resty-signal-0.02 && $(MAKE) DESTDIR=$(DESTDIR) LUA_INCLUDE_DIR=/data/openresty/openresty_src/1.15.8.1/build/luajit-root/data/pkg/openresty/luajit/include/luajit-2.1 LUA_LIB_DIR=/data/pkg/openresty/lualib CC=cc
	cd /data/openresty/openresty_src/1.15.8.1/build/lua-redis-parser-0.13 && $(MAKE) DESTDIR=$(DESTDIR) LUA_INCLUDE_DIR=/data/openresty/openresty_src/1.15.8.1/build/luajit-root/data/pkg/openresty/luajit/include/luajit-2.1 LUA_LIB_DIR=/data/pkg/openresty/lualib CC=cc
	cd /data/openresty/openresty_src/1.15.8.1/build/lua-rds-parser-0.06 && $(MAKE) DESTDIR=$(DESTDIR) LUA_INCLUDE_DIR=/data/openresty/openresty_src/1.15.8.1/build/luajit-root/data/pkg/openresty/luajit/include/luajit-2.1 LUA_LIB_DIR=/data/pkg/openresty/lualib CC=cc
	cd /data/openresty/openresty_src/1.15.8.1/build/nginx-1.15.8 && $(MAKE)

install: all
	mkdir -p $(DESTDIR)/data/pkg/openresty/
	-cp /data/openresty/openresty_src/1.15.8.1/COPYRIGHT $(DESTDIR)/data/pkg/openresty/
	cd /data/openresty/openresty_src/1.15.8.1/build/LuaJIT-2.1-20190507 && $(MAKE) install TARGET_STRIP=@: CCDEBUG=-g XCFLAGS='-std=gnu99 -DLUAJIT_ENABLE_LUA52COMPAT -DLUAJIT_ENABLE_GC64' CC=cc PREFIX=/data/pkg/openresty/luajit DESTDIR=$(DESTDIR)
	cd /data/openresty/openresty_src/1.15.8.1/build/lua-cjson-2.1.0.7 && $(MAKE) install DESTDIR=$(DESTDIR) LUA_INCLUDE_DIR=/data/openresty/openresty_src/1.15.8.1/build/luajit-root/data/pkg/openresty/luajit/include/luajit-2.1 LUA_CMODULE_DIR=/data/pkg/openresty/lualib LUA_MODULE_DIR=/data/pkg/openresty/lualib CJSON_CFLAGS="-g -fpic" CC=cc
	cd /data/openresty/openresty_src/1.15.8.1/build/lua-resty-signal-0.02 && $(MAKE) install DESTDIR=$(DESTDIR) LUA_INCLUDE_DIR=/data/openresty/openresty_src/1.15.8.1/build/luajit-root/data/pkg/openresty/luajit/include/luajit-2.1 LUA_LIB_DIR=/data/pkg/openresty/lualib CC=cc
	cd /data/openresty/openresty_src/1.15.8.1/build/lua-redis-parser-0.13 && $(MAKE) install DESTDIR=$(DESTDIR) LUA_INCLUDE_DIR=/data/openresty/openresty_src/1.15.8.1/build/luajit-root/data/pkg/openresty/luajit/include/luajit-2.1 LUA_LIB_DIR=/data/pkg/openresty/lualib CC=cc
	cd /data/openresty/openresty_src/1.15.8.1/build/lua-rds-parser-0.06 && $(MAKE) install DESTDIR=$(DESTDIR) LUA_INCLUDE_DIR=/data/openresty/openresty_src/1.15.8.1/build/luajit-root/data/pkg/openresty/luajit/include/luajit-2.1 LUA_LIB_DIR=/data/pkg/openresty/lualib CC=cc
	cd /data/openresty/openresty_src/1.15.8.1/build/lua-resty-dns-0.21 && $(MAKE) install DESTDIR=$(DESTDIR) LUA_LIB_DIR=/data/pkg/openresty/lualib INSTALL=/data/openresty/openresty_src/1.15.8.1/build/install
	cd /data/openresty/openresty_src/1.15.8.1/build/lua-resty-memcached-0.14 && $(MAKE) install DESTDIR=$(DESTDIR) LUA_LIB_DIR=/data/pkg/openresty/lualib INSTALL=/data/openresty/openresty_src/1.15.8.1/build/install
	cd /data/openresty/openresty_src/1.15.8.1/build/lua-resty-redis-0.27 && $(MAKE) install DESTDIR=$(DESTDIR) LUA_LIB_DIR=/data/pkg/openresty/lualib INSTALL=/data/openresty/openresty_src/1.15.8.1/build/install
	cd /data/openresty/openresty_src/1.15.8.1/build/lua-resty-mysql-0.21 && $(MAKE) install DESTDIR=$(DESTDIR) LUA_LIB_DIR=/data/pkg/openresty/lualib INSTALL=/data/openresty/openresty_src/1.15.8.1/build/install
	cd /data/openresty/openresty_src/1.15.8.1/build/lua-resty-string-0.11 && $(MAKE) install DESTDIR=$(DESTDIR) LUA_LIB_DIR=/data/pkg/openresty/lualib INSTALL=/data/openresty/openresty_src/1.15.8.1/build/install
	cd /data/openresty/openresty_src/1.15.8.1/build/lua-resty-upload-0.10 && $(MAKE) install DESTDIR=$(DESTDIR) LUA_LIB_DIR=/data/pkg/openresty/lualib INSTALL=/data/openresty/openresty_src/1.15.8.1/build/install
	cd /data/openresty/openresty_src/1.15.8.1/build/lua-resty-websocket-0.07 && $(MAKE) install DESTDIR=$(DESTDIR) LUA_LIB_DIR=/data/pkg/openresty/lualib INSTALL=/data/openresty/openresty_src/1.15.8.1/build/install
	cd /data/openresty/openresty_src/1.15.8.1/build/lua-resty-lock-0.08 && $(MAKE) install DESTDIR=$(DESTDIR) LUA_LIB_DIR=/data/pkg/openresty/lualib INSTALL=/data/openresty/openresty_src/1.15.8.1/build/install
	cd /data/openresty/openresty_src/1.15.8.1/build/lua-resty-lrucache-0.09 && $(MAKE) install DESTDIR=$(DESTDIR) LUA_LIB_DIR=/data/pkg/openresty/lualib INSTALL=/data/openresty/openresty_src/1.15.8.1/build/install
	cd /data/openresty/openresty_src/1.15.8.1/build/lua-resty-core-0.1.17 && $(MAKE) install DESTDIR=$(DESTDIR) LUA_LIB_DIR=/data/pkg/openresty/lualib INSTALL=/data/openresty/openresty_src/1.15.8.1/build/install
	cd /data/openresty/openresty_src/1.15.8.1/build/lua-resty-upstream-healthcheck-0.06 && $(MAKE) install DESTDIR=$(DESTDIR) LUA_LIB_DIR=/data/pkg/openresty/lualib INSTALL=/data/openresty/openresty_src/1.15.8.1/build/install
	cd /data/openresty/openresty_src/1.15.8.1/build/lua-resty-limit-traffic-0.06 && $(MAKE) install DESTDIR=$(DESTDIR) LUA_LIB_DIR=/data/pkg/openresty/lualib INSTALL=/data/openresty/openresty_src/1.15.8.1/build/install
	cd /data/openresty/openresty_src/1.15.8.1/build/lua-resty-shell-0.02 && $(MAKE) install DESTDIR=$(DESTDIR) LUA_LIB_DIR=/data/pkg/openresty/lualib INSTALL=/data/openresty/openresty_src/1.15.8.1/build/install
	cd /data/openresty/openresty_src/1.15.8.1/build/lua-tablepool-0.01 && $(MAKE) install DESTDIR=$(DESTDIR) LUA_LIB_DIR=/data/pkg/openresty/lualib INSTALL=/data/openresty/openresty_src/1.15.8.1/build/install
	cd /data/openresty/openresty_src/1.15.8.1/build/opm-0.0.5 && /data/openresty/openresty_src/1.15.8.1/build/install bin/* $(DESTDIR)/data/pkg/openresty/bin/
	cd /data/openresty/openresty_src/1.15.8.1/build/resty-cli-0.24 && /data/openresty/openresty_src/1.15.8.1/build/install bin/* $(DESTDIR)/data/pkg/openresty/bin/
	cp /data/openresty/openresty_src/1.15.8.1/build/resty.index $(DESTDIR)/data/pkg/openresty/
	cp -r /data/openresty/openresty_src/1.15.8.1/build/pod $(DESTDIR)/data/pkg/openresty/
	cd /data/openresty/openresty_src/1.15.8.1/build/nginx-1.15.8 && $(MAKE) install DESTDIR=$(DESTDIR)
	mkdir -p $(DESTDIR)/data/pkg/openresty/site/lualib $(DESTDIR)/data/pkg/openresty/site/pod $(DESTDIR)/data/pkg/openresty/site/manifest
	ln -sf /data/pkg/openresty/nginx/sbin/nginx $(DESTDIR)/data/pkg/openresty/bin/openresty

clean:
	rm -rf build
