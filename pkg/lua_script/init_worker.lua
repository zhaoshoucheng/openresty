ngx.log(ngx.INFO, "init nginx worker ......")


require "upstream.init".on_init_worker()