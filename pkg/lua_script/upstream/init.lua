
local module_name = (...):match("(.-)[^%.]+$")
local upstream_conf = require(module_name .. "config")

local function on_init()
    
end


local function on_init_worker()
    local etcd_source =     
    require "resty.source.etcdsource".new(
        {
            etcd_conf = upstream_conf.etcd_options,
            cache_path = upstream_conf.cache_path,
            prefix = upstream_conf.watch_path,
            map_size = upstream_conf.map_size,
        }
    )

    local ok, err = etcd_source:init()
    if not ok then
        ngx.log(ngx.ERR, "failed to init obconf: "..tostring(err))
    end
end

return {
    on_init = on_init,
    on_init_worker = on_init_worker
}