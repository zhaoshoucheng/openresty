
local module_name = (...):match("(.-)[^%.]+$")
local utils = require(module_name.."utils")
local delegate = require "delegate"
local stream_sock = ngx.socket.tcp
local re_find = ngx.re.find
local worker_exiting = ngx.worker.exiting
local events = require "resty.worker.events"
local cjson = require "cjson.safe"

local _M = { _VERSION = "0.1" }

local _MT = { __index = _M }

function _M.new()
    return setmetatable({
        interval = 1,                       -- 检测间隔时间
        watches = {},                       -- 检测列表 map
        on_peer_up = delegate.new(),        -- 检测节点为up时调用的函数链
        on_peer_added = delegate.new(),     -- 添加检测节点调用函数链
        on_peer_removed = delegate.new(),   -- 移除检测节点调用函数链
    }, _MT)
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
local function _check_peers_and_notify(self, tasks)
    for i = 1, #tasks do
        local ctx = tasks[i]
    --    local server_up, latest_up = _check_peer_and_update(self, ctx)
        local server_up = __check_peer(ctx)
        --TODO 简单策略：遇到一次健康检查成功则设置成up,没有对每次健康检查结果进行保存
        if server_up then
            ctx.down = false
            events.post(self._events._source, self._events.notify, {
                name = ctx.name,
                peer = ctx.peer,
            })
        end
    end
end

local function _do_check(self)
    -- get all peers to check this time
    local todo = { }
    local now = ngx.now()
    local i = 1
    for watch_name, ctx in pairs(self.watches) do
        if ctx.next_check_date and ctx.next_check_date <= now then
            todo[i] = ctx
            local interval = ctx.ahc.interval
            if interval > 1000 then
                interval = interval / 1000
            end
            ctx.next_check_date = now + (interval or 10)
            i = i + 1
        end
    end

    local all_task_count = #todo
    if all_task_count == 0 then
        return
    end
    _check_peers_and_notify(self, todo)
end

local function _tick_proc(p, self)
    local start = ngx.now()
    local ok, err = pcall(_do_check, self)
    local stop = ngx.now()
    local next_tick = self.interval - (stop - start)
    if next_tick <= 0.1 then
        next_tick = 0.1
    end

    if not ok then
        ngx.log(ngx.ERR, "failed to run healthcheck cycle: " .. tostring(err))
    end
    ok, err = ngx.timer.at(next_tick, _tick_proc, self)
    if not ok then
        if err ~= "process exiting" then
            ngx.log(ngx.ERR, "failed to create timer: "..tostring(err))
        end
    end
end
local function _notify_server_up(self, name, peer)
    local ctx = self.watches[name]
    if ctx then
        ctx.removed = true
        self.on_peer_up(self, name, peer)
        self.watches[name] = nil
        self.on_peer_removed(self, name, peer, true) -- removed by up
    end
end
local function _set_watch_context(self, name, ahc, peer)
    local ctx = self.watches[name]
    if not ctx then
        ctx = {
            name = name,
            peer = peer,
            ahc = ahc,
        --    latest_result = slide_window.new(ahc.rise + ahc.fall),
            status_check = __default_check_alive,
            next_check_date = 0,
            down = true,
        }
        self.watches[name] = ctx
    else
        -- treat as update config
        ctx.ahc = ahc
        ctx.status_check = __default_check_alive
    end
end
local function start(self, is_master)
    if self.__started then
        return
    end
    self._stop = false
    self.__started = true

    do
        -- register events
        local handle_notify = function(data, event, source, pid)
            if worker_exiting() then
                return
            end
            ngx.log(ngx.ERR, "handle_notify --> ahc events: "..require "cjson.safe".encode(data))
            _notify_server_up(self, data.name, data.peer)
        end
        local handle_add_watch = function(data, event, source, pid)
            if worker_exiting() then
                return
            end
            _set_watch_context(self, data.name, data.ahc, data.peer)
            ngx.log(ngx.ERR, "handle_add_watch --> added events: "..require "cjson.safe".encode(data))
            self.on_peer_added(self, data.name, data.peer)
        end
        local handle_remove_watch = function(data, event, source, pid)
            if worker_exiting() then
                return
            end
            local name = data.name
            local ctx = self.watches[name]
            if not ctx then
                return
            end
            self.watches[name] = nil
            ngx.log(ngx.ERR, "handle_remove_watch --> added events: "..require "cjson.safe".encode(data))
            self.on_peer_removed(self, name, ctx.peer, false)
        end
        self._events = events.event_list("down_peer_checker", "notify", "add_watch", "remove_watch")
        events.register(handle_notify, self._events._source, self._events.notify)
        events.register(handle_add_watch, self._events._source, self._events.add_watch)
        events.register(handle_remove_watch, self._events._source, self._events.remove_watch)
    end
    if is_master then
        ngx.timer.at(0, _tick_proc,self)
    end
end
local function add_watch(self, watch_name, ahc, peer)
    events.post(self._events._source, self._events.add_watch, {
        name = watch_name,
        peer = {
            ip = peer.ip,
            port = peer.port,
        },
        ahc = ahc
    })
end

local function remove_watch(self, watch_name, prefix)
    events.post(self._events._source, self._events.remove_watch, {
        name = watch_name,
        prefix = prefix,
    })
end

local function debug_ctx()
    local ctx =  {
        peer = {ip = '10.218.22.239', port = '8090'},
        ahc = {
            interval = 3000,
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
_M.set_watch_context = _set_watch_context
_M.start = start
_M.add_watch = add_watch
_M.remove_watch = remove_watch
return _M