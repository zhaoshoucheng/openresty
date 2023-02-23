local _M = { }
local _MT = { __index = _M }
local module_name = (...):match("(.-)[^%.]+$")
local utils = require(module_name.."utils")

-- 设置元表
function _M.new(opt)
    return setmetatable({
        _coloring_policy = {},      -- map[domain]coloring policy
        _proxy_policy = {},         -- map[domain]proxy policy
        _etcd_revision = "0",
    }, _MT)
end

local function _update_policy_config(self)
    if etcd_source_module:get_etcd_revision() == "0" then
        return
    end
    if self._etcd_revision == etcd_source_module:get_etcd_revision() then
        return
    end
    for k, val in pairs(etcd_source_module:get_all()) do
        -- 更新流量标记规则
        if string.find(k, "coloring") then
            for i = 1, #val.available_domain do
                local target_domain = val.available_domain[i]
                self._coloring_policy[target_domain] = val
            end
        end
        -- 更显流量转发策略
        if string.find(k, "proxy") then
            for i = 1, #val.apply_on do
                local target_domain = val.apply_on[i]
                if not self._proxy_policy[target_domain] then
                    self._proxy_policy[target_domain] = {}
                end
                table.insert(self._proxy_policy[target_domain], val)
            end
        end
    end
    self._etcd_revision = etcd_source_module:get_etcd_revision()
    return
end

local function _get_coloring_policy(self)
    if not etcd_source_module then
        return nil
    end
    _update_policy_config(self)
    local domain = ngx.var.host
    local policy = self._coloring_policy[domain]
    if not policy then
        return nil
    end
    return policy
end

local function _get_proxy_policy(self)
    if not etcd_source_module then
        return nil
    end
    _update_policy_config(self)
    local domain = ngx.var.host
    local policy = self._proxy_policy[domain]
    if not policy then
        return nil
    end
    return policy
end

local function get_header_metadata(metastr)
    if not metastr then
        return 
    end
    local str = metastr
    local map = {}
    while true do
        if str == "" then
            break
        end
        local s = string.find(str, ';')
        if not s then
            s = #str + 1
        end
        local item = string.sub(str,0,s-1)
        local i = string.find(item, '=')
        local key = string.sub(item,0,i-1)
        local value = string.sub(item,i+1,#item)
        map[key] = value
        str = string.sub(str,s+1,#str)
    end
    return map
end
local function _match_metadata(policies, nodes)
    local headers = ngx.req.get_headers()
    local header_traffic_group = headers["x-traffic-group"]
    local header_traffic_tags = get_header_metadata(headers["x-traffic-metadata"])
    local endpoint_match = {}

    for i = 1, #policies do
        local policy = policies[i]
        local enabled_when = policy["enabled_when"]
        if not enabled_when then
            break
        end
        if enabled_when["match_group"] ~= "" and header_traffic_group and enabled_when["match_group"] == header_traffic_group then
            -- group 检测命中
            endpoint_match = policy["endpoint_metadata_match"]
            break
        end
        if not header_traffic_tags then
            goto continue
        end
        if enabled_when["match_tags"] and enabled_when["match_tags"] ~= {} then
            for key, value in pairs(enabled_when["match_tags"]) do
                if header_traffic_tags[key] ~= value then
                    goto continue
                end
            end
            -- tag 检测命中
            endpoint_match = policy["endpoint_metadata_match"]
            break
        end
        ::continue::
    end
    local match_nodes = {}
    for i = 1, #nodes do
        local metadata = nodes[i]["metadata"]
        for key, value in pairs(endpoint_match) do
            if metadata[key] ~= value then
                goto nextnode
            end
        end
        table.insert(match_nodes, nodes[i])
        ::nextnode::
    end
    return match_nodes
end
local function do_proxy(self, nodes)
    if not coloring_policy then
        return 
    end
    local policies = coloring_policy:get_proxy_policy()
    if not policies then
        return nodes
    end
    return _match_metadata(policies, nodes)
    
end
local function do_coloring(self)
    if not coloring_policy then
        return 
    end
    local policy = coloring_policy:get_coloring_policy()
    if not policy then
        return
    end
    local parts = { }
    local rules = policy.rules
    for i = 1, #rules do
        local rule = rules[i]
        local cond = rule.op
        if not cond then
            return "invalid rule op `"..tostring(rule.op).."`"
        end
        local _match = false
        if rule.type and rule.type == "headers" then
            local headers = ngx.req.get_headers()
            if headers[rule.key] and headers[rule.key] == rule.value then
                _match = true
            end
        end
        if rule.type and rule.type == "ip" then
            if ngx.var.remote_addr == rule.value then
                _match = true
            end
        end
        -- TODO 可以添加其他条件
        local actions = rule.actions
        if _match then
            if actions.action == "set_group" then
                ngx.req.set_header("X-Traffic-Group", actions.value)
            end
            if actions.action == "set_tag" then
                table.insert(parts, actions.key.."="..actions.value)
            end
        end
    end
    if #parts ~= 0 then
        ngx.req.set_header("X-Traffic-Metadata", table.concat(parts, "; "))
    end
end

_M.do_coloring = do_coloring
_M.get_coloring_policy = _get_coloring_policy
_M.get_proxy_policy = _get_proxy_policy
_M.do_proxy = do_proxy
return _M
