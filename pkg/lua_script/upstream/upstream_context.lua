local module_name = (...):match("(.-)[^%.]+$")
-- local lrucache = require "resty.lrucache"
local utils = require(module_name.."utils")
local config = require(module_name.."config")
local balancers = require(module_name.."balancers")
local cjson = require "cjson.safe"

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
local function process_upstream_nodes(nodes)
    local ret = { }
    local def = { }
    for i = 1, #nodes do
        local d = nodes[i]
        local id = d.ip.."\0"..tostring(d.port)
        local ew = ret[id]
        if ew then
            ret[id] = (d.weight or 1) + ew
            def[id].weight = ret[id]
        else
            ret[id] = d.weight or 1
            def[id] = d
        end
    end
    return ret, def
end

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
    local _, _all_nodes = process_upstream_nodes(ups.nodes)
    ret._all_nodes = _all_nodes
    return ret
end

local function get_prefered_balancer(self)
    local b = self._prefered_balancer
    local err = nil
    if not b then
        local nodes, _ = process_upstream_nodes(self._ups.nodes)
        local lb = self._ups.load_balance
        local err
        b, err = balancers.create(lb.type, nodes, lb.args and unpack(lb.args))
        if not b then
            return nil, err
        end
        self._prefered_balancer = b
    end
    return b, err
end

local function get_balancer(self)

end

_M.get_balancer = get_balancer
_M.get_prefered_balancer = get_prefered_balancer
return _M

