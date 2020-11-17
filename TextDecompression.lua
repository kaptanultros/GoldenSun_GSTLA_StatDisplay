readWord = memory.read_u16_le
readDWord = memory.read_u32_le

function getNextBit(number,bitAddr)
    b = bit.band(number,1)
    number = bit.rshift(number,1)
    bitAddr = bitAddr + 1
    if bit.band(bitAddr,31) == 0 then
        number = readDWord(bit.rshift(bitAddr,3))
    end
    return b,number,bitAddr
end


function decompressText(textIndex)

    local charTablePointer = readDWord(0x08038578) -- 08060C30 pointer to charDataAddr and treeOffsetTableAddr
    local dataPointer = readDWord(0x080385DC) -- 080A9F54 table of addresses related to compressed data
    local txtDataPntrs = dataPointer + bit.lshift(bit.rshift(textIndex,8),3) -- base compressed data address, address of table of text lengths
    local baseAddr = readDWord(txtDataPntrs)
    local txtLenAddr = readDWord(txtDataPntrs + 4)
    textIndex = bit.band(textIndex,0xFF)

    -- Gets address of compressed text data
    local i = 0
    while i < textIndex do
        local txtLen = memory.readbyte(txtLenAddr + i)
        baseAddr = baseAddr + txtLen
        if txtLen ~= 0xFF then i = i + 1 end
    end

    local previousChar = 0
    local charString = ""
    local dataBitAddr = bit.lshift(baseAddr,3)
    local data = bit.rshift(readDWord(bit.band(baseAddr,-4)), bit.lshift(bit.band(baseAddr,3),3))

    repeat

        local charDataPointer = charTablePointer + bit.lshift(bit.rshift(previousChar,8),3) -- addresses of charData and table of offsets
        previousChar = bit.band(previousChar,0xFF)
        local charDataAddr = readDWord(charDataPointer)
        local charOffsetTableAddr = readDWord(charDataPointer + 4)
        local charOffset = readWord(charOffsetTableAddr + 2*previousChar)
        local charTreeAddr = charDataAddr + charOffset
        local treeBitAddr = bit.lshift(charTreeAddr,3)
        local byteOffset = bit.band(charTreeAddr,3)
        charTreeAddr = charTreeAddr - byteOffset
        local charTree = bit.rshift(readDWord(charTreeAddr),8*byteOffset)
        local charAddr = treeBitAddr - 12

        -- Gets the next character by navigating the chartree using the compressed data
        while true do

            treeBit,charTree,treeBitAddr = getNextBit(charTree,treeBitAddr)
            if treeBit == 1 then break end

            dataBit,data,dataBitAddr = getNextBit(data,dataBitAddr)
            if dataBit == 1 then
                local depth = 0
                while depth >=0 do
                    treeBit,charTree,treeBitAddr = getNextBit(charTree,treeBitAddr)
                    while treeBit == 0 do
                        treeBit,charTree,treeBitAddr = getNextBit(charTree,treeBitAddr)
                        depth = depth + 1
                    end
                    depth = depth - 1
                    charAddr = charAddr - 12
                end
            end
        end

        charValue = readWord(bit.rshift(charAddr - bit.band(charAddr,7),3))
        charValue = bit.band(bit.rshift(charValue,bit.band(charAddr,7)),0xFFF)
        local character = bit.band(charValue,0xFF)
        if character < 32 and character > 0 or character > 127 then character = "{"..character.."}"
        else character = string.char(character) end
        charString = charString..character
        previousChar = charValue

    until charValue == 0
    return charString
end
