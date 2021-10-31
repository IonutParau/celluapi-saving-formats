-- M1 can be built on by any saving format, as long as they say it was built on top of it.

local str = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!$%&+-.=?^{}"
local json = require("libs.json")

local function advancedSplit(s, delimiter)
  local inString = false
  local result = {''}
  for i=1,string.len(s) do
    if string.sub(s, i, i) == '"' then
      inString = not inString
      result[#result] = result[#result] .. '"'
    elseif string.sub(s, i, i) == delimiter and not inString then
      table.insert(result, '')
    else
      result[#result] = result[#result] .. string.sub(s, i, i)
    end
  end
  return result
end

local cellDefault = {
  id = 0,
  dir = 0,
  props = "",
}

local function encodeNumM1(input)
  if input == 0 then
    return '0'
  end
  local neg = false
  if input < 0 then
      neg = true
      input = input * -1
  end
  local result = ""
  while input > 0 do
      local n = input % (#str)
      result = string.sub(str, n + 1, n + 1) .. result
      input = math.floor(input / (#str))
  end
  if neg then
      result = '-' .. result
  end
  return result
end

local function decodeNumM1(input)
  -- If negative activate cheat code.
  if string.sub(input, 1, 1) == '-' then
    return decodeNumM1(string.sub(input, 2)) * -1
  end

  -- Generate decypher table because....... because.
  local decypherTable = {}
  for i=1,string.len(str) do
    decypherTable[string.sub(str, i, i)] = (i-1)
  end

  -- Number
  local num = 0

  -- Decypher time with basic O(n) algorithm
  for i=1,string.len(input) do
    local n = string.len(input) - i
    local c = string.sub(input, i, i)
    local val = decypherTable[c]
    local n2 = (#str)^n * val
    num = num + n2
  end

  return num
end

local function join(t, j)
  local s = ""

  for _, v in pairs(t) do
    s = s .. v .. j
  end

  s = s:sub(1, #s-1)

  return s
end

local function equals(a, b)
  if type(a) ~= type(b) then return false end

  local t = type(a)

  if t == "table" then
    if #a ~= #b then return false end

    for k, v in pairs(a) do
      if not equals(b[k], v) then
        return false
      end
    end

    for k, v in pairs(b) do
      if not equals(a[k], v) then
        return false
      end
    end

    return true
  else
    return (a == b)
  end

  return false
end

local function tableHasValue(table, value)
  for _, val in pairs(table) do
    if equals(val, value) then
      return true
    end
  end
  return false
end

local function encodeM1Cell(cell, isPlaceable)
  local prefix = "v"
  local isModded = false
  local suffix = ""
  if cell.ctype > initialCellCount then
    prefix = "m"
    isModded = true
  end
  if isPlaceable then suffix = suffix .. "+" end
  if isModded then
    return prefix .. getCellLabelById(cell.ctype) .. "|" .. suffix
  else
    return prefix .. encodeNumM1(cell.ctype) .. cell.rot .. "|" .. suffix
  end
end

local function encodeLineM1(cell, count)
  return encodeM1Cell(cell, cell.placeable) .. "|" .. encodeNumM1(count)
end

---@param rows table
---@param counts table
---@return table, table
local function CompressM1(rows, counts)
  local compressed = {}
  local compressedCount = {}

  for i, row in ipairs(rows) do
    local count = counts[i]
    local latest = compressed[#compressed]
    local latestCount = compressedCount[#compressedCount]

    if #compressed == 0 then
      table.insert(compressed, row)
      table.insert(compressedCount, count)
    elseif latest == row then
      compressedCount[#compressedCount] = latestCount + count
    elseif (latestCount == count) and (not string.find(latest, row, 1, true)) then
      compressed[#compressed] = latest .. ';' .. row
    elseif row:sub(1, #latest) == latest then
      local rest = row:sub(#latest, #row)
      rest:sub(2, #rest)
      compressed[#compressed] = row
      compressedCount[#compressedCount] = latestCount + count
      table.insert(compressed, rest)
      table.insert(compressedCount, count)
    elseif latest:sub(-(#row)) == row then
      local rest = latest:sub(1, #latest-#row)
      rest = rest:sub(1, #rest-1)
      compressed[#compressed] = rest
      table.insert(compressed, row)
      table.insert(compressedCount, latestCount + count)
    else
      table.insert(compressed, row)
      table.insert(compressedCount, count)
    end
  end

  return {
    compressed,
    compressedCount
  }
end

function EncodeM1()
  local rows = {}
  local rowCounts = {}

  local code = "M1;"
  code = code .. encodeNumM1(width) .. ';'
  code = code .. encodeNumM1(height) .. ';'

  -- Do compression, please help
  local compressionCache
  local compressionCount = 0
  for y=1,height-2 do
    for x=1,width-2 do
      local rawcell = cells[y][x]
      local cell = {
        ctype = rawcell.ctype,
        rot = rawcell.rot,
        placeable = placeables[y][x],
      }
      if compressionCache ~= nil then
        if equals(compressionCache, cell) then
          compressionCount = compressionCount + 1
          if x == width-2 and y == height-2 and cell.ctype ~= 0 then
            local row = encodeLineM1(cell, compressionCount)
            table.insert(rows, row)
            table.insert(rowCounts, 1)
          end
        else
          local row = encodeLineM1(compressionCache, compressionCount)
          compressionCache = cell
          compressionCount = 1
          table.insert(rows, row)
          table.insert(rowCounts, 1)
        end
      else
        compressionCache = cell
        compressionCount = 1
      end
    end
  end

  local prevs = {}

  while true do
    local result = CompressM1(rows, rowCounts)
    if equals(prevs, result) then
      break
    end
    --print(json.encode(result))
    rows = result[1]
    rowCounts = result[2]
    prevs = result
  end

  for index, row in ipairs(rows) do
    code = code .. '"' .. row .. '"|' .. encodeNumM1(rowCounts[index]) .. ';'
  end

  love.system.setClipboardText(code)
end

local function joinTables(t1, t2)
  local joined = {}

  for _, v in pairs(t1) do
    table.insert(joined, v)
  end

  for _, v in pairs(t2) do
    table.insert(joined, v)
  end

  return joined
end

local function decodeM1Cell(cellCode)
  local prefix = cellCode[1]:sub(1, 1)
  local id = cellCode[1]:sub(2, cellCode[1]:len() - 1)
  local rotation = tonumber(cellCode[1]:sub(cellCode[1]:len(), cellCode[1]:len()))

  local ctype

  if prefix == "v" then ctype = decodeNumM1(id) end
  if prefix == "m" then ctype = getCellLabelById(id) end

  local properties = cellCode[2]

  return {
    id = ctype,
    dir = rotation,
    props = properties,
  }
end

local function decodeM1Line(line)
  local code = advancedSplit(line, ';')
  
  local cells = {}

  for _, rawsubcode in ipairs(code) do
    local subcode = advancedSplit(rawsubcode, '|')

    --error(json.encode(subcode))

    local count = decodeNumM1(subcode[3])
    subcode[3] = nil
    local cell = decodeM1Cell(subcode)
    for i=1,count do
      table.insert(cells, cell)
    end
  end

  return cells
end

function DecodeM1(fmt)
  local code = advancedSplit(fmt, ';')
  width = decodeNumM1(code[2])
  height = decodeNumM1(code[3])

  local cellList = {}

  for i=4,#code-1 do
    local subcode = advancedSplit(code[i], '|')
    local line = subcode[1]:sub(2, #(subcode[1])-1)
    local count = decodeNumM1(subcode[2])

    for j=1,count do
      cellList = joinTables(cellList, decodeM1Line(line))
    end
  end

  local i = 0
  for y=1,height-2 do
    for x=1,width-2 do
      i = i + 1

      local cell = cellList[i] or cellDefault

      cells[y][x] = {
        ctype = cell.id,
        rot = cell.dir,
        lastvars = {
          x, y, cell.dir,
        }
      }

      initial[y][x] = {
        ctype = cell.id,
        rot = cell.dir,
      }

      if cell.props:find("+", nil, true) then
        placeables[y][x] = true
      end
    end
  end
  bgsprites = love.graphics.newSpriteBatch(tex[0])
  for y=0,height-1 do
		for x=0,width-1 do
			if y == 0 or x == 0 or y == height-1 or x == width-1 then
				initial[y][x].ctype = walls[border]
			end
			cells[y][x].ctype = initial[y][x].ctype
			cells[y][x].rot = initial[y][x].rot
			cells[y][x].lastvars = {x,y,cells[y][x].rot}
			cells[y][x].testvar = ""
			bgsprites:add((x-1)*20,(y-1)*20)
		end
	end
  RefreshChunks()
end

CreateFormat("M1", EncodeM1, DecodeM1)