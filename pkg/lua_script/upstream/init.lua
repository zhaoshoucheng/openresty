
local module_name = (...):match("(.-)[^%.]+$")
local cjson = require "cjson.safe"
local upstream_conf = require(module_name .. "config")

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
    local events = ev.event_list(
        upstream_conf.watch_path, -- available as _M.events._source
        "full_sync",                -- available as _M.events.full_sync
    )
    local my_callback = function(data, event, source, pid)
        if event == events.full_sync then
            -- do sth
        elseif event == events.sync_keys then
            -- do sth
        end
        ngx.log(ngx.INFO,"get data event: "..cjson.encode(event).."data :"..data.."pid :"..tostring(pid).." now pid: "..tostring(ngx.worker.pid()))
    end
    ev.register(my_callback, events._source, events.full_sync)
--    ev.register(my_callback, events._source, events.sync_keys)

    if is_master() then
        local raise_event = function(p, event, data)
            ngx.log(ngx.INFO,"master post event ")
            return ev.post(events._source, event, data)
        end
        --raise_event(nil, events.full_sync, "test_event")
        ngx.timer.at(0, raise_event,events.full_sync, "test_event")
    end 
        
end

return {
    on_init = on_init,
    on_init_worker = on_init_worker
}