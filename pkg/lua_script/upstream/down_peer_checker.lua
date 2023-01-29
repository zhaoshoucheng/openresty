
local module_name = (...):match("(.-)[^%.]+$")
local utils = require(module_name.."utils")
local delegate = require "delegate"
local stream_sock = ngx.socket.tcp
local re_find = ngx.re.find

local _M = { _VERSION = "0.1" }

local _MT = { __index = _M }

function _M.new()
    return setmetatable({}, _MT)
end

local function __default_check_alive(status)
    return status >= 200 and status <= 299
end


-- functional, check peer by http, returns bool indicate up or down
local function __check_http_peer(ahc, peer, status_check)
    local ok
    local req = ahc.check_http_send

    local sock, err = stream_sock()
    if not sock then
        ngx.log(ngx.ERR, "failed to create stream socket: " .. err)
        return false, err
    end

    sock:settimeout(ahc.timeout * 1000)

    ok, err = sock:connect(peer.ip, peer.port)
    if not ok then
        return false
    end

    local bytes, err = sock:send(req)
    if not bytes then
        return false
    end

    local status_line, err = sock:receive()
    if not status_line then
        if err == "timeout" then
            sock:close()  -- timeout errors do not close the socket.
        end
        return false
    end

    if status_check then
        local from, to, err = re_find(status_line,
                                      [[^HTTP/\d+\.\d+\s+(\d+)]],
                                      "joi", nil, 1)
        if err then
            ngx.log(ngx.ERR, "failed to parse status line: "..err)
        end

        if not from then
            sock:close()
            return false
        end

        local status = tonumber(status_line:sub(from, to))
        if not status_check(status) then
            -- ngx.log(ngx.ERR, status_line)
            sock:close()
            return false
        end
    end

    -- _peer_ok(ahc, peer)
    sock:close()
    return true
end

-- functional, check peer by tcp, returns bool indicate up or down
local function __check_tcp_peer(ahc, peer)
    local ok
    local sock, err = stream_sock()
    if not sock then
        ngx.log(ngx.ERR, "failed to create stream socket: " .. err)
        return false, err
    end

    sock:settimeout(ahc.timeout * 1000)

    ok, err = sock:connect(peer.ip, peer.port)
    if not ok then
        return false
    end
    sock:close()
    return true
end

-- functional, check peer, returns bool indicate up or down
local function __check_peer(ctx)
    local peer = ctx.peer
    local ahc = ctx.ahc
    if ahc.type == "http" then
        return __check_http_peer(ahc, peer, ctx.status_check)
    elseif ahc.type == "tcp" then
        return __check_tcp_peer(ahc, peer)
    else
        ngx.log(ngx.ERR, "unexpected check type: "..tostring(ahc.type).." for peer: "..peer.ip..":"..tostring(peer.port))
        return false, "config error"
    end
end

local function debug_ctx()
    local ctx =  {
        peer = {ip = '10.218.22.239', port = '8090'},
        ahc = {
            type = 'http',
            timeout = 3,
            check_http_send = 'GET /ping HTTP/1.1\r\nHost: service_test.com\r\n\r\n',
        },
        status_check = __default_check_alive
    }
    return ctx
end

_M.check_peer = __check_peer
_M.debug_ctx = debug_ctx

return _M