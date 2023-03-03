local _M = { }

local disable_trace = false
local math_floor = math.floor
local shm = ngx.shared.global
local my_ip_hex = ""

local function get_my_ip()
    if my_ip_hex == "" then
        -- try read from var
        my_ip_hex = tostring(ngx.var.server_addr)
    end
    return my_ip_hex
end

local function generate_msg_id()
    local h = math_floor(ngx.time() / 3600)
    local key = "trace_sn_"..h
    local sn, err = shm:incr(key, 1, 0)
    if err then
        ngx.log(ngx.ERR, err)
        return
    end
    if sn == 1 then
        -- shm:expire(key, 3600 + 600) -- 1h10min to expire
        shm:set(key, 1, 3600 + 600)
    end
    return "openresty-"..get_my_ip().."-"..h.."-"..tostring(sn)
end

local function on_access()
    if disable_trace then
        return
    end
    local req = ngx.req
    local headers = req.get_headers()
    local traceid = headers["X-Trace-ID"]
    local parentid = headers["X-PARENT-ID"]
    local msgid = headers["X-CHILD-ID"]
    local newmsgid = generate_msg_id()
    if not newmsgid then
        return
    end
    if traceid and parentid and msgid then
        req.set_header("X-PARENT-ID", msgid)
        req.set_header("X-CHILD-ID", newmsgid)
    else
        -- treat as new transaction
        traceid = newmsgid
        parentid = newmsgid
        msgid = newmsgid
        newmsgid = generate_msg_id()
        req.set_header("X-Trace-ID", traceid)
        req.set_header("X-PARENT-ID", parentid)
        req.set_header("X-X-CHILD-ID", newmsgid)
    end

    local ctx = ngx.ctx
    ctx.trace_id = traceid  
    ctx.parent_id = parentid
    ctx.msg_id = msgid
    ctx.child_id = newmsgid
    ctx.request_time = ngx.now() * 1000
end

local function _send_msg(data)
    ngx.log(ngx.INFO,"traceID msg"..data)

    local producer = require "resty.kafka.producer"
    local config = require "waf.config"
    local bp = producer:new(config['broker_list'], { producer_type = "async" })
    local ok, err = bp:send(config["topic"], nil, data)
    if not ok then
        ngx.log(ngx.ERR, "send msg to kafka err:", err)
        return
    end
end
local function _on_log()
    local ctx = ngx.ctx
    if not ctx.msg_id then
        return -- something goes wrong when accessing, maybe disabled, skip phase
    end

    local upaddr = tostring(ngx.var.upstream_addr)
    local child_id = ctx.child_id
    if not upaddr or upaddr == "nil" or upaddr == "" then
        child_id = nil -- no proxy, clear child id
    end

    local response_time = ngx.var.request_time -- request processing time in seconds with a milliseconds resolution; time elapsed between the first bytes were read from the client and the log write after the last bytes were sent to the client
    local response_time = tonumber(response_time)
    if not response_time then
        response_time = math_floor(ngx.now() * 1000)
    else
        response_time = ctx.request_time + math_floor(response_time * 1000)
    end
    local req = ngx.req
    local host=ngx.var.host
    local args=req.get_uri_args()
    local headers=req.get_headers()
    local ip = ngx.var.remote_addr

    local status=ngx.var.upstream_status
    local status_num = tonumber(status)
    if status_num == nil then
        status_num = 500
    end

    local data, err = require "cjson.safe".encode({
        url = tostring(ngx.var.uri),
        trace_id = ctx.trace_id,
        parent_id = ctx.parent_id,
        msg_id = ctx.msg_id,
        child_id = child_id,
        request_time = ctx.request_time,
        response_time = response_time,
        host = host,
        real_ip = ip,
        proxy_ip = tostring(ngx.var.server_addr),
        parms = args,
        status = status_num,
        headers = headers,
        upstream_addr = upaddr,
    })
    if err then
        ngx.log(ngx.ERR, "trace json encode err:", err)  
        return  
    end

    local ok, err = _send_msg(data)
    if not ok then
        ngx.log(ngx.ERR, "trace kafka send err:", err)  
        return
    end 
end

local function on_log()
    if disable_trace then
        return
    end
    local ret, err = pcall(_on_log)
    if not ret then
        ngx.log(ngx.ERR, err)
    end
end

_M.on_log = on_log
_M.on_access = on_access
return _M