return {
    etcd_options = {
        http_host = {
            "http://127.0.0.1:2379",
        },
        protocol = "v3",
        ssl_verify = false,
        user = "service",
        password = "123456",
    },
    -- signature_key = "aa2c0c73-b409-4609-b069-dbcb5fdcc5c7\n",
    watch_path = "/openresty/demo/",
    cache_path = "/data/ufe/upstream_cache",
    use_events = true,
    events_shm_name = "events",
    ups_shm_name = "ups", -- for ahc data sharing
    losable_shm_name = "losable",

    active_health_check_idle = 3600, -- seconds

    health_check_concurrency = 3,

    max_reties = 2,
}