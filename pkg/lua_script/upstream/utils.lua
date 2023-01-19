
local _M = { }
local function http_health_check_payload(hhc)
    local payload = (hhc.method or "GET") .. " " .. (hhc.path or "/") .. " " .. (hhc.proto or "HTTP/1.0") .. "\r\n"
    if hhc.host then
        payload = payload .. "Host: "..tostring(hhc.host).."\r\n"
    end
    if hhc.headers then
        for h, v in pairs(hhc.headers) do
        payload = payload .. tostring(h) .. ": "..tostring(v).."\r\n"
        end
    end
    return payload .. "\r\n"
end

local function http_health_check_expect_alive(hhc)
    local ret = { }
    local has_flag = { }
    if hhc.expected_statuses then
        for i, es in ipairs(hhc.expected_statuses) do
            local h = math.floor(es.start / 100) * 100
            local h2 = math.floor(es["end"] / 100) * 100
            for i = h, h2 do
                if not has_flag[i] then
                    table.insert(ret, "http_"..tostring(i).."xx")
                    has_flag[i] = true
                end
            end
        end
    else
        ret[1] = "http_2xx"
    end
    return ret
end
--[[
    {
	"modify_date": 1663743685625,
	"name": "server_test1",
	"type": "static",
	"load_assignment": {
		"modify_date": 0,
		"cluster_name": "",
		"endpoints": [{
			"modify_date": 0,
			"weight": 1,
			"address": "10.218.22.239:8090",
			"state": "up",
			"metadata": {
				"appname": "server_test1",
				"env": "test3",
				"product_type": "POD",
				"provider": "private",
				"traffic_strategy": "gray",
			}
		}, {
			"modify_date": 0,
			"weight": 1,
			"address": "10.218.22.246:8090",
			"state": "up",
			"metadata": {
				"appname": "server_test1",
				"env": "test4",
				"product_type": "POD",
				"provider": "private",
				"traffic_strategy": "default",
			}
		}],
		"cmdb_appname": "server_test1",
		"default_port": 8090
	},
	"connect_timeout": 0,
	"lb_policy": "round_robin",
	"health_checks": [],
	"dns_refresh_rate": 0,
	"respect_dns_ttl": false,
	"dns_resolvers": null,
	"outlier_detection": {
		"consecutive_5xx": 3,
		"interval": 5000,
		"base_ejection_time": 30000
	},
}

]]
-- 没有健康检查相关信息
local function transform_data_simple(bc)
    local nodes = { }
    local edit_date = bc.modify_date
    local endpoints
    if bc.load_assignment and bc.load_assignment.endpoints then
        endpoints = bc.load_assignment.endpoints
    end
    local ii = 1
    for i = 1, #endpoints do
        local _, _, ip, port = endpoints[i].address:find("(.-):(%d+)")
        nodes[ii] = {
            ip = ip,
            port = (tonumber(port)) or 8080,
            state = endpoints[i].state or "up",
            weight = endpoints[i].weight or 1,
            fail_timeout = 3000,
            max_fail = 3,
            metadata = endpoints[i].metadata,
        }
        ii = ii + 1
    end
    return {
        edit_date = edit_date,
        load_balance = {
            type = bc.lb_policy,
        },
        nodes = nodes,
    }
end
local function transform_data(bc, all_uc)
    local health_check = {
        enable_health_check = false,
        type = "tcp",
        interval = 3000,
        check_keepalive_requests = 1,
        timeout = 3000,
        rise = 1,
        fall = 3,
        default_down = false,
    }
    for i, hc in ipairs(bc.health_checks) do
        health_check.interval = hc.interval or 3000
        health_check.timeout = hc.timeout or 3000
        health_check.rise = hc.healthy_threshold or 1
        health_check.fall = hc.unhealthy_threshold or 3
        if hc.http_health_check then
            health_check.enable_health_check = true
            health_check.type = "http"
            health_check.check_http_send = http_health_check_payload(hc.http_health_check)
            health_check.check_http_expect_alive = http_health_check_expect_alive(hc.http_health_check)
            break
        elseif hc.tcp_health_check then
            health_check.enable_health_check = true
            health_check.type = "tcp"
            break
        end
    end

    local nodes = { }
    local edit_date = bc.modify_date
    do
        local endpoints
        if bc.type == "static" then
            if bc.load_assignment and bc.load_assignment.endpoints then
                endpoints = bc.load_assignment.endpoints
            end
        else
            -- dynamic
            -- ngx.log(ngx.INFO, cjson.encode(bc))
            -- ngx.log(ngx.INFO, cjson.encode(all_uc))
            if bc.load_assignment and bc.load_assignment.cluster_name and all_uc then
                endpoints = all_uc[bc.load_assignment.cluster_name]
            end
        end
        if endpoints then
            local fail_timeout = "10s"
            local max_fail = 5
            if bc.outlier_detection then
                fail_timeout = math.floor(bc.outlier_detection.interval / 1000).."s"
                if fail_timeout == "0s" then
                    fail_timeout = "1s"
                end
                max_fail = bc.outlier_detection.consecutive_5xx
            end
            local ii = 1
            for i = 1, #endpoints do
                if endpoints[i].state == "up" then
                    local _, _, ip, port = endpoints[i].address:find("(.-):(%d+)")
                    nodes[ii] = {
                        ip = ip,
                        port = (tonumber(port)) or 8080,
                        state = endpoints[i].state or "up",
                        weight = endpoints[i].weight or 1,
                        fail_timeout = fail_timeout,
                        max_fail = max_fail,
                        metadata = endpoints[i].metadata,
                    }
                    ii = ii + 1

                    if bc.type == "dynamic" then
                        local date = endpoints[i].modify_date
                        if date and edit_date < date then
                            edit_date = date
                        end
                    end
                end
            end
        else
            return nil
        end
    end

    return {
        name = bc.name:gsub("@lfe.cluster$", ""),
        edit_date = edit_date,
        load_balance = {
            type = "roundrobin",
        },
        nodes = nodes,
        health_check = health_check,
    }
end

_M.transform_data = transform_data
_M.transform_data_simple = transform_data_simple

return _M