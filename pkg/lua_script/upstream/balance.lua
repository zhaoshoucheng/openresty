local module_name = (...):match("(.-)[^%.]+$")
local upstream_context = require(module_name.."upstream_context")
local conf = require(module_name.."config")
local utils = require(module_name.."utils")
local ngx_balancer = require "ngx.balancer"
local cjson = require "cjson.safe"

local _M = { }

local upstream_contexts = { }

local function get_upstream_context(name)
    -- local ctx = upstream_contexts:get(name)
    local ctx = upstream_contexts[name]
    if not ctx then
        -- local ups = uupstreams:get_upstream(name)
        local ups = obconf:get_value("core/clusters/"..name.."@lfe.cluster")
        if not ups then
            ups = obconf:get_value("core/clusters/"..name)
            if not ups then
                return nil, "upstream configure not found: "..name
            end
        end
        ups = transform_lkfe_business_cluster(ups, all_upstream_cluster)
        if ups then
            local ok, err = __check_upstream_data(ups)
            if not ok then
                return nil, "!!! unexpected upstream config, `"..ups.name.."` new context failed, err: "..tostring(err)
            end
            ctx = upstream_context.new(name, ups, down_watcher, select_prefer_policy(name))
            -- upstream_contexts:set(name, ctx)
            upstream_contexts[name] = ctx

            -- ctx.on_health_check_activity_changed = function(_, is_actived)
            --     if not is_actived then
            --         -- clean related states
            --         if worker_sync.is_master then
            --             if capability_mode then
            --                 losable_shm:delete(key)
            --             elseif losable_shm:ttl(key) == 0 then
            --                 losable_shm:expire(key, 0.99)
            --             end
            --         end
            --     end
            -- end
        end
    end
    return ctx
end

function _M.do_balance(ups_name)
    local ctx = ngx.ctx
    local uctx, err = get_upstream_context(ups_name)
    if not uctx then
        ngx.log(ngx.ERR, ups_name..", "..tostring(err))
        ngx_exit(502)
        return
    end

end