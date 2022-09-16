
default:	build

clean:
	rm -rf Makefile objs

build:
	$(MAKE) -f objs/Makefile

install:
	$(MAKE) -f objs/Makefile install

modules:
	$(MAKE) -f objs/Makefile modules

upgrade:
	/data/pkg/openresty/nginx/sbin/nginx -t

	kill -USR2 `cat /data/pkg/openresty/nginx/logs/nginx.pid`
	sleep 1
	test -f /data/pkg/openresty/nginx/logs/nginx.pid.oldbin

	kill -QUIT `cat /data/pkg/openresty/nginx/logs/nginx.pid.oldbin`
