local roundrobin = require("resty.balancer.roundrobin")
local chash = require("resty.balancer.chash")
local iphash = require("resty.balancer.iphash")
local urlhash = require("resty.balancer.urlhash")

local _M = { }

local function create(typ, ...)
    if typ == "roundrobin" or typ == "round_robin" then
        return roundrobin:new(...)
    elseif typ == "chash" then
        return chash:new(...)
    elseif typ == "iphash" or typ == "ip_hash" then
        return iphash:new(...)
    elseif typ == "urlhash" or typ == "url_hash" then
        return urlhash:new(...)
    else
        return nil, "unsupported balancer type: "..tostring(typ)
    end
end

_M.create = create

return _M