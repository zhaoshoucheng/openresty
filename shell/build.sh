#!/bin/bash

DIR="/data/openresty"
OPENSSL_VERSION="1.1.0k"

check_status() {
  retval="$?"

  msg="$1"
  if [ "$msg" == "" ]; then
    msg="Build Failed!"
  fi

  errcode="$2"
  if [ "$errcode" == "" ]; then
    errcode=255
  fi

  if [ "$retval" != "0" ]; then
    if [ -f "$LOCK_FILE" ]; then
      rm "$LOCK_FILE"
    fi

    echo "BUILD  FAILED: $msg"
    exit $errcode
  fi
}

#初次使用是，需要patch相关依赖

#cd $DIR/other_nginx_bundles/openssl/$OPENSSL_VERSION/ && ./config
#check_status "config openssl FAILED!"

#cd $DIR/other_nginx_bundles/nginx-sticky-module-ng
#patch -p0 < $DIR/other_nginx_bundles/nginx_upstream_check_module/nginx-sticky-module.patch
#check_status "patch nginx sticky module FAILED!"

#cd $DIR/openresty_src/1.15.8.1/bundle/nginx-1.15.8
#patch -p0 < $DIR/other_nginx_bundles/nginx_upstream_check_module/check_1.11.5+.patch
#check_status "patch nginx upstream_check_module module FAILED!"

openrestydir=$DIR"/openresty_src/1.19.3.1"
otherbundles=$DIR"/other_nginx_bundles"
cd $openrestydir
./configure --prefix=/data/pkg/openresty --user=nginx --group=nginx --with-pcre-jit --with-http_v2_module --with-http_sub_module --with-http_realip_module --with-http_stub_status_module --with-luajit --add-module=$otherbundles/nginx-sticky-module-ng  --add-module=$otherbundles/nginx_upstream_check_module --add-module=$otherbundles/ngx_stream_upstream_check_module --with-openssl=$otherbundles/openssl/$OPENSSL_VERSION --with-pcre=$otherbundles/pcre/pcre-8.40 --with-zlib=$otherbundles/zlib/zlib-1.2.10

make

make install