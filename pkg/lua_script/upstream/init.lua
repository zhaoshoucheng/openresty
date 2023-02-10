
local module_name = (...):match("(.-)[^%.]+$")
local cjson = require "cjson.safe"
local upstream_conf = require(module_name .. "config")
local lmdb = require "resty.lmdb"
local delegate = require "delegate"
local down_peer_checker = require(module_name .. "down_peer_checker")

local upstream_shm = ngx.shared[upstream_conf.events_shm_name]
local function on_init()
    -- 删除master 
    upstream_shm:delete("upstream_master")
end

local function is_master()
    local master = upstream_shm:get("upstream_master")
    if master then
        return false
    end
    upstream_shm:set("upstream_master","true")
    return true
end
local function delegate_test1(data)
    ngx.log(ngx.INFO,"delegate_test1 "..data)
end
local function delegate_test2(data)
    ngx.log(ngx.INFO,"delegate_test2 ".. data)
end

local function on_init_worker()
    local etcd_source =     
    require "resty.source.etcdsource".new(
        {
            etcd_conf = upstream_conf.etcd_options,
            cache_path = upstream_conf.cache_path,
            prefix = upstream_conf.watch_path,
            map_size = upstream_conf.map_size,
            watch_path = upstream_conf.watch_path
        }
    )

    -- worker init 
    local ev = require "resty.worker.events"
    local events_ok, err =
    ev.configure(
    {
        shm = upstream_conf.events_shm_name,
        timeout = 2, -- life time of unique event data in shm
        interval = 0.1, -- poll interval (seconds)
        wait_interval = 0.010, -- wait before retry fetching event data
        wait_max = 0.5, -- max wait time before discarding event
        shm_retries = 100 -- number of retries when the shm returns "no memory" on posting an event
    })
    if not events_ok then
        ngx.log(ngx.ERR, "failed to init events, err: "..tostring(err))
    end

    local ok, err = etcd_source:init()
    if not ok then
        ngx.log(ngx.ERR, "failed to init obconf: "..tostring(err))
    end
    local master = false
    if is_master() then

        local ok, err = etcd_source:on_master()
        if not ok then
            ngx.log(ngx.ERR, "failed to init obconf: "..tostring(err))
        end
        master = true
    end 
    etcd_source_module = etcd_source
    require (module_name.."balance").init(master)
    --[[
    --test 
    ngx.timer.at(2, function (p, self)
        local obj = etcd_source_module:get_value("server_test1")
        ngx.log(ngx.ERR, "/openresty/dome/server_test1 "..cjson.encode(obj))
    end)
    -- test
    local delegater  = delegate.new()
    delegater:add_delegate2(delegate_test1)
    delegater:add_delegate2(delegate_test2)
    delegater("test")

    -- test
    ngx.timer.at(0, function (p, self)
        local ctx = down_peer_checker.debug_ctx()
        ngx.log(ngx.INFO,"down_peer_checker  check_peer "..tostring(down_peer_checker.check_peer(ctx)))
    end)
    ]]
end

return {
    on_init = on_init,
    on_init_worker = on_init_worker
}