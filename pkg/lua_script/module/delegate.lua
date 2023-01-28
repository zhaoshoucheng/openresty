local _M = { }

local _MT = { __index = _M }

local setmetatable = setmetatable
local table_remove = table.remove

function _M.new()
    return setmetatable({ _invoke_list = { }, _count = 0 }, _MT)
end

function _MT:__call(...)
    local _invoke_list = self._invoke_list
    for i = 1, self._count do
        _invoke_list[i](...)
    end
end

local function add_delegate(self, cb, ...)
    if not cb then
        return self
    end
    local _invoke_list = self._invoke_list
    local idx = self._count + 1
    self._invoke_list[idx] = cb
    self._count = idx
    return add_delegate(self, ...)
end

local function add_delegate2(self, cb, ...)
    if not cb then
        return self
    end
    local _invoke_list = self._invoke_list
    for i = 1, self._count do
        if _invoke_list[i] == cb then
            -- already exists, skip
            return add_delegate2(self, ...)
        end
    end
    local _invoke_list = self._invoke_list
    local idx = self._count + 1
    self._invoke_list[idx] = cb
    self._count = idx
    return add_delegate2(self, ...)
end

local function remove_delegate(self, cb, ...)
    if not cb then
        return self
    end
    local _invoke_list = self._invoke_list
    for i = 1, self._count do
        if _invoke_list[i] == cb then
            table_remove(_invoke_list, i)
            self._count = self._count - 1
            break
        end
    end
    return remove_delegate(self, ...)
end

local function is_empty(self)
    return self._count == 0
end

local function merge_from(self, other)
    if #other._invoke_list == 0 then
        return
    end
    local l = #self._invoke_list
    local _invoke_list = self._invoke_list
    local _other_invoke_list = other._invoke_list
    for i = 1, #_other_invoke_list do
        _invoke_list[i + l] = _other_invoke_list[i]
    end
end

_M.__add = add_delegate
_M.__sub = remove_delegate
_M.invoke = _MT.__call
_M.add_delegate = add_delegate
_M.add_delegate2 = add_delegate2
_M.remove_delegate = remove_delegate
_M.is_empty = is_empty

return _M
