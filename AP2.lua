-- Anything can be built on top of AP2, they don't even have to mention they are.

local cellkey = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!$%&+-.=?^{}"

function decodebase74(input)
    -- If negative activate cheat code.
    if string.sub(input, 1, 1) == '-' then
        return decodebase74(string.sub(input, 2)) * -1
    end

    -- Generate decypher table because....... because.
    local decypherTable = {}
    for i=1,string.len(cellkey) do
        decypherTable[string.sub(cellkey, i, i)] = (i-1)
    end

    -- Number
    local num = 0

    -- Decypher time with basic O(n) algorithm
    for i=1,string.len(input) do
        local n = string.len(input) - i
        local c = string.sub(input, i, i)
        local val = decypherTable[c]
        local n2 = (#cellkey)^n * val
        num = num + n2
    end

    return num
end

function encodebase74(input)
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
        local n = input % (#cellkey)
        result = string.sub(cellkey, n + 1, n + 1) .. result
        input = math.floor(input / (#cellkey))
    end
    if neg then
        result = '-' .. result
    end
    return result
end

-- Encode the single cell
function encodeAP2Cell(cell, count)
    local id
    local strcount = encodebase74(count)
    local properties = ""
    if cell.placeable then
      properties = properties .. "+"
    end
    if cell.ctype > initialCellCount then
      -- It is modded, do modded encoding
      id = 'm' .. getCellLabelById(cell.ctype)
    else
      -- It is vanilla, do vanilla encoding
      id = 'v' .. encodebase74(cell.ctype)
    end
    local str = id .. cell.rot .. "|" .. strcount .. "|" .. properties
    return str
end

-- Encode the whole grid
function encodeAP2()
    local str = "AP2;"
    str = str .. encodebase74(width) .. ';'
    str = str .. encodebase74(height) .. ';'
    local cellList = {}
  
    local cellCounts = {}
  
    for y=1,height-2,1 do
      for x=1,width-2,1 do
        local cellToEncode = {
          ctype = cells[y][x].ctype,
          rot = cells[y][x].rot,
          placeable = placeables[y][x]
        }
        if #cellList > 0 then
          local prevcell = CopyTable(cellList[#cellList])
          if encodeAP2Cell(prevcell, 1) == encodeAP2Cell(cellToEncode, 1) then
            cellCounts[#cellCounts] = cellCounts[#cellCounts] + 1
          else
            table.insert(cellList, cellToEncode)
            table.insert(cellCounts, 1)
          end
        else
          table.insert(cellList, cellToEncode)
          table.insert(cellCounts, 1)
        end
      end
    end
  
    for i=1, #cellList, 1 do
      str = str .. encodeAP2Cell(cellList[i], cellCounts[i]) .. ';'
    end
  
    love.system.setClipboardText(str)
end

-- Decode the whole grid
function DecodeAP2(str)
    local code = split(str, ';')
    width = decodebase74(code[2])
    height = decodebase74(code[3])
    code[#code] = nil
  
    local cellList = {}
  
    for k, v in pairs(code) do
      if k > 3 then
        -- Decode the cell
        local thingies = split(v, '|')
        local id
        if thingies[1]:sub(1,1) == "v" then
          id = decodebase74(thingies[1]:sub(2):sub(1,-2))
        elseif thingies[1]:sub(1,1) == "m" then
          id = getCellIDByLabel(thingies[1]:sub(2):sub(1,-2))
        end
        local cell = {
          id = id,
          rot = tonumber(thingies[1]:sub(string.len(thingies[1]))),
          placeable = false
        }
        for i=1,str.len(thingies[3] or '') do
          if str.sub(thingies[3], i, i) == "+" then
            cell.placeable = true
          end
        end
        local count = decodebase74(thingies[2])
        for i=1,count do
          table.insert(cellList, cell)
        end
      end
    end
    local i = 0
    for y=1,height-2 do
          for x=1,width-2 do
              i = i + 1
        cells[y][x].ctype = cellList[i].id
        cells[y][x].rot = cellList[i].rot
        initial[y][x].ctype = cellList[i].id
        initial[y][x].rot = cellList[i].rot
        placeables[y][x] = cellList[i].placeable
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

CreateFormat("AP2", EncodeAP2, DecodeAP2)