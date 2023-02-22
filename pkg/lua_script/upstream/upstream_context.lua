local module_name = (...):match("(.-)[^%.]+$")
-- local lrucache = require "resty.lrucache"
local utils = require(module_name.."utils")
local config = require(module_name.."config")
local balancers = require(module_name.."balancers")
local traffoc_policy = require(module_name.."traffic_policy")
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
    -- 增加down标记
    local ret = { }
    local def = { }
    for i = 1, #nodes do
        local d = nodes[i]
        if d.state ~= 'up' then
            goto continue
        end
        local id = d.ip.."\0"..tostring(d.port)
        local ew = ret[id]
        if ew then
            ret[id] = (d.weight or 1) + ew
            def[id].weight = ret[id]
        else
            ret[id] = d.weight or 1
            def[id] = d
        end
        ::continue::
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
local function _update_node_state(self, name ,peer, status)
    for i = 1, #self._ups.nodes do
        local d = self._ups.nodes[i]
        if d.ip == peer.ip or d.port == peer.port then
            self._ups.nodes[i].state = status
            return
        end
    end
    ngx.log(ngx.ERR, "can't find peer when dpc up: "..name)
end
local function dpc_on_added(self, name, peer)
    -- local sctx = _get_server_context(self, peer, true)
    -- sctx.dpc_state = "down"
    _update_node_state(self, name, peer, 'down')
    local _, _all_nodes = process_upstream_nodes(self._ups.nodes)
    self._all_nodes = _all_nodes
end

local function dpc_on_up(self, name, peer)
    _update_node_state(self, name, peer, 'up')
    local _, _all_nodes = process_upstream_nodes(self._ups.nodes)
    self._all_nodes = _all_nodes
    self._prefered_balancer = nil
end


local function get_prefered_balancer(self)
    local b = self._prefered_balancer
    local err = nil
    if not b then
        local ups_nodes = traffoc_policy:do_proxy(self._ups.nodes)
        local nodes, _ = process_upstream_nodes(ups_nodes)
        local lb = self._ups.load_balance
        local err
        --b, err = balancers.create(lb.type, nodes, lb.args and unpack(lb.args))
        b, err = balancers.create(lb.type, nodes)
        if not b then
            return nil, err
        end
        self._prefered_balancer = b
    end
    return b, err
end

_M.get_prefered_balancer = get_prefered_balancer
_M.dpc_on_added = dpc_on_added
_M.dpc_on_up = dpc_on_up
return _M

