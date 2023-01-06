local module_name = (...):match("(.-)[^%.]+$")
-- local lrucache = require "resty.lrucache"
local utils = require(module_name.."utils")
local config = require(module_name.."config")
local balancers = require(module_name.."balancers")

local _M = { }
local _MT = { __index = _M }

--
local empty_ups = {
    load_balance = { type = "" },
    nodes = { },
    health_check = {
        enable_health_check = false,
        type = "tcp",
        interval = 3,
        check_keepalive_requests = 1,
        timeout = 3,
        rise = 1,
        fall = 3,
        check_http_send = "GET / HTTP/1.0\r\n\r\n",
        default_down = false,
        check_http_expect_alive = { "http_2xx" },
        port = 81
    },
    edit_date = 0,
}

-- name 上游服务名
-- ups 所有节点
function _M.new(name, ups)
    local ret = setmetatable({
        name = name,
        _ups = empty_ups, -- init as empty, and call update later
        _all_nodes = { },
        servers = {}, --lrucache.new(64),
        _latest_update_time = 0,
     --   _down_watcher = _down_watcher,
        version = 1, -- auto increment while reinit

     --   prefer_policy = prefer_policy,

        proxy_policy_cache = { },
    }, _MT)

    ret._ups = ups
    return ret
end

return _M

