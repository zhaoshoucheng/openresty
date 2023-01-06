local module_name = (...):match("(.-)[^%.]+$")
local chash = require(module_name.."chash")
local setmetatable = setmetatable

local _M = { _VERSION = "0.1" }

local _MT = { __index = _M }

function _M.new(_, nodes)
    return setmetatable({
        _chb = chash:new(nodes)
    }, _MT)
end

function _M:reinit(nodes)
    self._chb:reinit(nodes)
end

function _M:set(...)
    self._chb:set(...)
end

function _M:find()
    return self._chb:find(ngx.var.remote_addr) -- TODO: use xff ?
end

function _M:next(...)
    self._chb:next(...)
end

return _M
