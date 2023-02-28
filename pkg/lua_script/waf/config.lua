local broker_list = {
    { host = "10.218.57.13", port = 9092 },
    { host = "10.218.57.15", port = 9092 },
    { host = "10.218.57.8", port = 9092 }

}
local topic = "trace-log"
return {broker_list=broker_list,topic=topic}
