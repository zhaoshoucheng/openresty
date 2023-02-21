local _M = { }
local _MT = { __index = _M }
local module_name = (...):match("(.-)[^%.]+$")
local utils = require(module_name.."utils")

-- 设置元表
function _M.new(opt)
    return setmetatable({
        _coloring_policy = {},      -- map[domain]policy
        _etcd_revision = "0",
    }, _MT)
end

local function _update_clolring_policy(self)
    if etcd_source_module:get_etcd_revision() == "0" then
        return
    end
    if self._etcd_revision == etcd_source_module:get_etcd_revision() then
        return
    end
    for k, val in pairs(etcd_source_module:get_all()) do
        if string.find(k, "coloring") then
            for i = 1, #val.available_domain do
                local target_domain = val.available_domain[i]
                self._coloring_policy[target_domain] = val
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
    _update_clolring_policy(self)
    local domain = ngx.var.host
    local policy = self._coloring_policy[domain]
    if not policy then
        return nil
    end
    return policy
end

local function _match_rules(self,rules)
    for i = 1, #rules do
        local rule = rules[i]
        local cond = rule.op
        if not cond then
            return nil, "invalid rule op `"..tostring(rule.op).."`"
        end
        if rule.type and rule.type == "headers" then
            local headers = ngx.req.get_headers()
            if headers[rule.key] and headers[rule.key] == rule.value then
                return rule.actions
            end
        end
        if rule.type and rule.type == "ip" then
            if ngx.var.remote_addr == rule.value then
                return rule.actions, ""
            end
        end
        -- TODO 可以添加其他条件
    end
    return nil, ""
end

local function do_coloring(self)
    if not coloring_policy then
        return 
    end
    local policy = coloring_policy:get_coloring_policy()
    if not policy then
        return
    end
    local actions = _match_rules(self, policy.rules)
    if not actions then
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
return _M
