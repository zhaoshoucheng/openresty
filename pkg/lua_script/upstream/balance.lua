local module_name = (...):match("(.-)[^%.]+$")
local upstream_context = require(module_name.."upstream_context")
local conf = require(module_name.."config")
local utils = require(module_name.."utils")
local ngx_balancer = require "ngx.balancer"
local cjson = require "cjson.safe"
local transform_data_simple = utils.transform_data_simple
local down_watcher

local _M = { }

local upstream_contexts = { }


local function get_upstream_context(name)
    -- local ctx = upstream_contexts:get(name)
    local ctx = upstream_contexts[name]
    if not ctx then
        -- local ups = uupstreams:get_upstream(name)
        local ups = etcd_source_module:get_value(name)
        if not ups then
            return nil, "upstream configure not found: "..name
        end
        ups = transform_data_simple(ups)
        if ups then
            ctx = upstream_context.new(name, ups)
            -- upstream_contexts:set(name, ctx)
            upstream_contexts[name] = ctx
        end
    end
    return ctx
end

local function _handle_down_peer_watched(dpc, watch_name, peer)
    local _, _, upname = watch_name:find("(.+)-")
    if upname then
        local uctx = get_upstream_context(upname)
        if uctx then
            uctx:dpc_on_added(watch_name, peer)
        end
    else
        ngx.log(ngx.ERR, "unexpected upstream name: "..tostring(upname))
    end
end

local function _handle_down_peer_becomes_up(dpc, watch_name, peer)
    local _, _, upname = watch_name:find("(.+)-")
    if upname then
        local uctx = get_upstream_context(upname)
        if uctx then
            uctx:dpc_on_up(watch_name, peer)
        end
    else
        ngx.log(ngx.ERR, "unexpected upstream name: "..tostring(upname))
    end
end
local function __watch_name(name, node)
    return name.."-"..node.ip..":"..tostring(node.port)
end

local function debug_down_watcher(p)
    local debug_ctx = down_watcher:debug_ctx()
    down_watcher:add_watch(__watch_name('server_test1', debug_ctx.peer), debug_ctx.ahc, debug_ctx.peer)
end
function _M.init(is_master)
    down_watcher = require(module_name.."down_peer_checker").new()
    down_watcher.on_peer_added:add_delegate2(_handle_down_peer_watched)
    down_watcher.on_peer_up:add_delegate2(_handle_down_peer_becomes_up)
    down_watcher:start(is_master)
    if is_master then
        ngx.timer.at(1, debug_down_watcher)
    end

end

function _M.get_down_watcher()
    return down_watcher
end
local function report_server_failed(self, uctx, peer)
    down_watcher.add_watch(uctx.name, uctx._ups.health_check, peer)
end
function _M.do_balance(ups_name)
    local ctx = ngx.ctx
    local uctx, err = get_upstream_context(ups_name)
    if not uctx then
        ngx.log(ngx.ERR, ups_name..", "..tostring(err))
        ngx.exit(502)
        return
    end

    local b, err = uctx:get_prefered_balancer()
    if not b then
        ngx.log(ngx.ERR, "failed to get balancer: "..tostring(err))
        ngx.exit(502)
        return
    end

    local key, idx
    local sn, sc = ngx_balancer.get_last_failure()
    if not sn then
        -- first call
        local ok, err = ngx_balancer.set_more_tries(3)
        if err and #err > 0 then
            ngx.log(ngx.WARN, err)
        end
        key, idx = b:find(ctx.balance_key)
        if not key then
            ngx.log(ngx.ERR, "failed to get upstream endpoint")
            ngx.exit(502)
            return
        end
    else
        down_watcher:add_watch(__watch_name(ups_name, ctx.latest_peer), uctx._ups.health_check, ctx.latest_peer)
        key, idx = b:next(ctx.latest_idx)
        ngx.log(ngx.WARN, "rebalancing: "..sn..", "..tostring(sc))
    end

    local peer = uctx._all_nodes[key]
    if not peer then
        ngx.log(ngx.ERR, "failed to get upstream endpoint: "..tostring(key))
        ngx.exit(502)
        return
    end
    ctx.latest_peer = peer
    ctx.latest_key = key
    ctx.latest_idx = idx

    local ok, err = ngx_balancer.set_current_peer(peer.ip, peer.port)
    if not ok then
        ngx.log(ngx.ERR, string.format("error while setting current upstream peer %s: %s", peer.ip, err))
        ngx.exit(500)
        return
    end
end
return _M