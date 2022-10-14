local type = type
local str_char = string.char

local zeros = {
    "0", "00", "000", "0000", "00000",
    "000000", "0000000", "00000000", "000000000", "0000000000",
    "00000000000", "000000000000", "0000000000000", "00000000000000", "000000000000000",
    "0000000000000000", "00000000000000000", "000000000000000000", "0000000000000000000", "00000000000000000000",
}
local function big_int_incr(num)
    if type(num) ~= "string" then
        return num
    end
    local len = #num
    local up = len
    while num:byte(up) == 57 do
        up = up - 1
        if up == 0 then
            return "1"..zeros[len]
        end
    end
    if len == up then
        return num:sub(1, up - 1)..str_char(num:byte(up) + 1)
    end
    return num:sub(1, up - 1)..str_char(num:byte(up) + 1)..zeros[len - up]
end

return {
    big_int_incr = big_int_incr,
}