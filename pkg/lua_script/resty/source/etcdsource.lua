
local cjson = require "cjson.safe"
local json_decode = cjson.decode

local utils = require "resty.source.utils"

local etcd = require "resty.etcd"
local big_int_cmp        = utils.big_int_cmp
local big_int_incr       = utils.big_int_incr
local lmdb = require "resty.lmdb"
local ev = require "resty.worker.events"

local _M = { _VERSION = 0.1 }

local _MT = { __index = _M }

-- 设置元表
function _M.new(opt)
    return setmetatable({
        etcd_conf  = opt.etcd_conf,
        cache_path = opt.cache_path,
        prefix     = opt.prefix ,   --etcd 数据路径前缀
        key_filter = opt.key_filter, -- returns false when
        checker    = opt.checker, -- returns false when
        map_size   = opt.map_size,
        signature_key  = opt.signature_key,
        watch_path = opt.watch_path,
        _cache     = { },

        _etcd_revision = "0",
    }, _MT)
end

local function _get_etcd_cli(self)
    if self._etcd then
        return self._etcd
    end
    self.etcd_conf.protocol = "v3"
    local _etcd, err = etcd.new({
        protocol = "v3",
        http_host = self.etcd_conf.http_host,
        user = self.etcd_conf.user,
        password = self.etcd_conf.password,
        timeout = self.timeout,
        serializer = "raw",
    })
    if not _etcd then
        ngx.log(ngx.ERR, tostring(err))
        return nil, err
    end
    self._etcd = _etcd
    return self._etcd
end


local function _full_sync(self)
    -- 获取客户端
    local _etcd, err = _get_etcd_cli(self)
    if not _etcd then
        return nil, err
    end
    -- 获取指定前缀的kv,
    local resp, err = _etcd:readdir(self.prefix)
    if not resp then
        return nil, err
    end
    if resp.status ~= 200 then
        return nil, "server response with: "..tostring(resp.status)
    end
    local kvs = resp.body.kvs or { }
    if not resp.body.kvs or #kvs == 0 then
        return nil, "server response empty kvs"
    end
    -- reset
    lmdb.db_drop(true)

    for i = 1, #kvs do
       local kv = kvs[i]
       local obj, err = json_decode(kv.value)
       if obj then
        local ok, err = lmdb.set(kv.key, kv.value)
            if not ok then
                ngx.log(ngx.ERR,'lmdb.set err'..err)
            end
       end
    end

    local _new_revision = resp.body.header.revision
    -- 更新版本，用于增量同步
    self._etcd_revision = _new_revision
    local ok, err = lmdb.set('__etcd_revision__', _new_revision)
    if not ok then
        ngx.log(ngx.ERR,'lmdb.set __etcd_revision__ err'..err)
    end
    ngx.log(ngx.INFO, "etcd decode data revision : ", _new_revision)
    return true
end

local function _watch_sync(self)
    local opts = {
        start_revision = big_int_incr(self._etcd_revision),
        timeout = 60,
        need_cancel  = true,
    }
    local _etcd, err = _get_etcd_cli(self)
    if not _etcd then
        return nil, err
    end    
    local reader, err, http_cli = _etcd:watchdir(self.prefix, opts)
    if not reader then
        return nil, err
    end
    local resp
    repeat
        resp, err = reader()
        if resp then
            if resp.result.canceled then
                ngx.log(ngx.WARN, "cancel_reason: "..tostring(resp.result.cancel_reason))
                break
            end
            if resp.compact_revision and big_int_cmp(resp.compact_revision, self._etcd_revision) > 0 then
                -- revision has been compacted since we last sync
                -- need to restart full sync
                err = "revision has been compacted since we last sync, compact_revision: "..tostring(resp.compact_revision)..", _etcd_revision: "..tostring(self._etcd_revision)
                break
            end
            -- ngx.log(ngx.INFO, "watch: "..tostring(json_encode(resp)))
            local resp_events = resp.result.events
            if resp_events and #resp_events > 0 then
                for i = 1, #resp_events do
                    local evt = resp_events[i]
                    local kv = evt.kv
                    local is_delete = evt.type == "DELETE"
                    if kv then
                        if is_delete then
                            local ok,err = lmdb.set(kv.key, '')
                            if not ok then
                                ngx.log(ngx.ERR,'lmdb.set err'..err)
                            end
                        else 
                            local ok, err = lmdb.set(kv.key, kv.value)
                            if not ok then
                                ngx.log(ngx.ERR,'lmdb.set err'..err)
                            end
                        end 
                    end
                end
            end
            if resp.result.header then
                -- maintaining local revision
                local revision = resp.result.header.revision
                if revision then
                    local v = lmdb.get('__etcd_revision__')
                    if not v or big_int_cmp(v, revision)  < 0 then
                        ngx.log(ngx.INFO, "ectd __etcd_revision__`"..revision.."`")
                        local err, ok = lmdb:set("__etcd_revision__", revision)
                        if not ok then
                            ngx.log(ngx.ERR,'lmdb.set __etcd_revision__ err'..err)
                        end
                    end
                end
            end
        end
    until err
    return true
end


local function init_sync_or_watch(p, self)
    -- 定时器自带参数处理
    if p then
        return
    end
    local ok, err
    -- 全量获取数据
    if self._need_full_sync then
        self._need_full_sync = false
        ok, err = _full_sync(self)
        if not ok then
            if err == "not master" then
                return
            end
            self._need_full_sync = true
            ngx.log(ngx.ERR, "failed to _full_sync: "..tostring(err))
            ngx.timer.at(5, init_sync_or_watch, self) -- retry
            return
        end
        if self.exit then
            return
        end
    end
    -- 增量获取数据
    ok, err = _watch_sync(self) -- blocked
    if err and err ~= "timeout" then
        ngx.log(ngx.ERR, "failed to _watch_sync: "..err)
        self._need_full_sync = not self.exit
    end
    if not self.exit then
        ngx.timer.at(err == "timeout" and 0 or 5, init_sync_or_watch, self) -- retry
    end
end

-- full sync cache from lmdb
local function _on_full_sync(self)
    
end

local function _on_sync_keys(self)
    
end

local function init(self)
    local events = ev.event_list(
        self.watch_path, -- available as _M.events._source
        "full_sync",                -- available as _M.events.full_sync
        "sync_keys"
    )
    ev.register(_on_full_sync, events._source, events.full_sync)
    ev.register(_on_sync_keys, events._source, events.sync_keys)
    return true
end


-- 设置初始化
local function on_master(self)
    self._need_full_sync = true
    local __on_master = function()
        return ngx.timer.at(0, init_sync_or_watch, self)
    end

    return __on_master()
end

_M.init      = init
_M.full_sync = _on_full_sync
_M.on_master = on_master

return _M