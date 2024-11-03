-- Optimize table operations
local function addToTable(tbl, value)
    tbl[#tbl + 1] = value -- Instead of table.insert
end

local function setTableValue(tbl, key, value)
    tbl[key] = value -- Instead of table.insert with key
end 