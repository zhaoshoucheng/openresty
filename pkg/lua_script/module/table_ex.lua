
local deep_clone_for_json_encode
do
    local type = type
    local pairs = pairs
    function table.deep_clone_for_json_encode(obj)
        local ret = { }
        for k, v in pairs(obj) do
            local t = type(v)
            if t ~= "function" and t ~= "userdata" then
                if t == "table" then
                    ret[k] = deep_clone_for_json_encode(v)
                else
                    ret[k] = v
                end
            end
        end
        return ret
    end
    deep_clone_for_json_encode = table.deep_clone_for_json_encode
end

do
    local json_encode = require "cjson.safe".encode
    function table.json_encode(tbl)
        local ret, err = json_encode(tbl)
        if not ret then
            return json_encode(deep_clone_for_json_encode(tbl))
        end
        return ret
    end
end

do
    local type = type
    local pairs = pairs
    local function shallow_clone(obj)
        local ret = { }
        for k, v in pairs(obj) do
            ret[k] = v
        end
        return ret
    end

    local function deep_clone(obj)
        local ret = { }
        for k, v in pairs(obj) do
            local t = type(v)
            if t == "table" then
                ret[k] = deep_clone(v)
            else
                ret[k] = v
            end
        end
        return ret
    end

    function table.clone2(obj, deep)
        if not obj then
            return nil
        end
        if deep then
            return deep_clone(obj)
        else
            return shallow_clone(obj)
        end
    end
end

do
    local pairs = pairs
    local setmetatable = setmetatable
    function table.inherit(tbl, from, hard_way)
        if not from then
            -- only metatable way supported
            if hard_way then
                return nil, "not allowed"
            else
                return setmetatable(tbl, nil)
            end
        end
        if hard_way then
            -- just copy
            for k, v in pairs(from) do
                if not tbl[k] then
                    tbl[k] = v
                end
            end
            return tbl
        else
            -- metatable way
            return setmetatable(tbl, { __index = from })
        end
    end
end

do
    local tb_nkeys
    local _, perr = pcall(function()
        tb_nkeys = require "table.nkeys"
    end)
    local table_exist_keys
    if tb_nkeys and not perr then
        table_exist_keys = function(t)
            return tb_nkeys(t) > 0
        end
    else
        table_exist_keys = function(t)
            return next(t)
        end
    end
    table.exist_keys = table_exist_keys

    local next = next
    local getmetatable = getmetatable
    local type = type
    local tbl_any
    function table.any(tbl)
        if not tbl then
            return false
        end
        if table_exist_keys(tbl) then
            return 0 -- root level
        end
        local mt = getmetatable(tbl)
        if not mt then
            return false
        end
        local h = mt.__index
        local t = type(h)
        if t == "table" then
            local ret = tbl_any(h)
            if ret then
                return ret + 1 -- serarch level +1
            end
        elseif t == "function" then
            return 1
        else
            return false
        end
    end
    tbl_any = table.any
end

local ok, clear_tab = pcall(require, "table.clear")
if not ok then
    clear_tab = function (tab)
                    for k, _ in pairs(tab) do
                        tab[k] = nil
                    end
                end
    table.clear = clear_tab
end

function table.debug_print(tbl, level, msg, include_mt)
    level = level or ngx.INFO
    msg = msg or ""
    if type(tbl) ~= "table" then
        ngx.log(level, msg.."[[ ".. tostring(tbl) .. " ]]")
        return
    end
    local visit
    visit = function (t, pre, out)
        out = out or ""
        pre = pre or ""
        for k, v in pairs(t) do
            if type(v) == "table" then
                out = out .. "\n" .. pre .. "." .. k .. ": {" .. visit(v, pre .. "." .. k) .."}"
            else
                out = out .. "\n" .. pre .. "." .. k .. ": " .. tostring(v)
            end
        end
        return out
    end
    ngx.log(level, msg.."[[ {"..visit(tbl).."} ]]")
end

return table
