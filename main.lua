require "TextDecompression"
local ROM = ""
local offset = 0
local classNameOffset = 0
local enemyBaseAddress = 0
local screen = 0
for i=0,11 do
    ROM = ROM..string.char(memory.readbyte(0x080000A0+i))
end
if ROM == "Golden_Sun_A" then screen = 140  classNameOffset = 1857 enemybaseAddress = 0x02030878 end
if ROM == "GOLDEN_SUN_B" then offset = 0x20 screen = 280 classNameOffset = 2915 enemybaseAddress = 0x020308C8 end

pcRamBase=0x02000500+offset
pcOrderBase=0x02000438+offset

--function space(left,top,right,down)  client.SetGameExtraPadding(left,top,right,down) end
mr1,mr2,rText,c1,c2 = memory.readbyte, memory.read_u16_le, gui.pixelText, 0xFFFFFFFF, 0x00000000

function getFlag(flag)
    local bytepos = bit.rshift(flag, 3)
    local bitpos = bit.band(flag, 7)
    return bit.band(bit.rshift(memory.readbyte(0x02000040 + bytepos), bitpos), 1)
end
function progressbar(x, y, curProgress, maxProgress, posColor, negColor)
    gui.drawBox(x, y, x + 67, y + 6, negColor, negColor)
    if curProgress > maxProgress then curProgress = maxProgress end
	gui.drawBox(x-1, y-1, x + 68 * curProgress / maxProgress, y + 7, 0x00000000, posColor)
end
function progressbar_enemy(x, y, curProgress, maxProgress, posColor, negColor)
    gui.drawBox(x, y, x + 55, y + 6, negColor, negColor)
    if curProgress > maxProgress then curProgress = maxProgress end
	gui.drawBox(x-1, y-1, x + 56 * curProgress / maxProgress, y + 7, 0x00000000, posColor)
end
function progressbar_lowestResist(x, y)
	gui.drawBox(x, y, x + 30, y + 7, 0xFFD8D800, 0xFFD8D800)
end
statID = 1
statTimer = { }
statPrev = { }
function statchange(x, y, stat) --Displays arrows for a short period when stats change.
    if statPrev[statID] == nil then statPrev[statID] = stat end
    if stat > statPrev[statID] then
        statTimer[statID] = 120
    elseif stat < statPrev[statID] then
        statTimer[statID] = -120
    end
    if statTimer[statID] == nil then statTimer[statID] = 0 end
    if statTimer[statID] > 0 then
        gui.drawImage("menu//up.png",x,y)
        statTimer[statID] = statTimer[statID] - 1
    elseif statTimer[statID] < 0 then
        gui.drawImage("menu//down.png",x,y)
        statTimer[statID] = statTimer[statID] + 1
    end
    statPrev[statID] = stat
    statID = statID + 1
end
function drawStats(x, y, addr)
    progressbar(x+32,y, mr2(addr+0x04), mr2(addr+0x00), 0xFF6da73e, "red")
    rText(x+33,y, "HP: " .. mr2(addr+0x04) .. " / " .. mr2(addr+0x00), c1, c2)
    statchange(x+93,y, mr2(addr+0x00))
    progressbar(x+32,y+7, mr2(addr+0x06), mr2(addr+0x02), 0xFF279ddb, 0xFFba1515)
    rText(x+33,y+7, "PP: " .. mr2(addr+0x06) .. " / " .. mr2(addr+0x02), c1, c2)
    statchange(x+93,y+7, mr2(addr+0x02))
    rText(x+100,y+0, "ATK: " .. mr2(addr+0x08), c1, c2)
    statchange(x+93+40,y+0, mr2(addr+0x08))
    rText(x+100,y+7, "DEF: " .. mr2(addr+0x0A), c1, c2)
    statchange(x+93+40,y+7, mr2(addr+0x0A))
    rText(x+100,y+14, "AGI: " .. mr2(addr+0x0C), c1, c2)
    statchange(x+93+40,y+14, mr2(addr+0x0C))
    rText(x+100,y+21, "Luck: " .. mr1(addr+0x0E), c1, c2)  
    statchange(x+93+40,y+21, mr1(addr+0x0E))
end
function drawStatsByID(x, y, char_num) --, name)
    statID = char_num * 100
	local addr = pcRamBase + 0x14C * char_num
	
	--if mr2((addr+0x38)*char_num) ~= 0 then
		gui.drawImage("portraits//" .. char_num .. ".png",x,y)
	--else 
		--gui.drawImage("portraits//dead//" .. name,x,y)
	--end
	
    stat_button = joypad.get()
    if stat_button["Start"] and stat_button["Select"] then
        drawStats(x, y, addr + 0x10)
    else
        drawStats(x, y, addr + 0x34)
    end
    rText(x+33,y+14, "Lvl: " .. mr1(addr+0x0F), c1, c2)
    rText(x+33,y+21, getClassByID(mr1(addr+0x129), char_num+1), c1, c2)
    rText(x+33+6,y+30, mr1(addr+0x118), c1, c2)
    rText(x+33+23,y+30, mr1(addr+0x119), c1, c2)
    rText(x+33+40,y+30, mr1(addr+0x11A), c1, c2)
    rText(x+33+57,y+30, mr1(addr+0x11B), c1, c2)
end

usedClassNames = {}
usedClassIDs = {}
function getClassByID(classID, char_num)
	if usedClassIDs[char_num] ~= classID then
		usedClassIDs[char_num] = classID
		usedClassNames[char_num] = decompressText(classNameOffset+classID)
	end
	return usedClassNames[char_num]
end

function checkLowestResist(venus, mercury, mars, jupiter)
	local lowest = venus
	local elementsChecked = 1
	if mercury < lowest then
		lowest = mercury
		elementsChecked = 2
	end
	if mars < lowest then
		lowest = mars
		elementsChecked = 3
	end
	if jupiter < lowest then
		lowest = jupiter
		elementsChecked = 4
	end
	return elementsChecked
end
function drawEnemyData()
    gui.drawImage("menu//enemyBack.png",0,160)
	--only keep going if we have battlers in list at 0x020300B2
	if mr1(0x020300B2) == 0 then
		return
	end
	--top left should be 0, 160
	--020308C8 = Enemy data, second at 02030A14 (+14C per subsequent)
	local x = 0
	local y = 160
	local enemyCount = 0
	for enemyLoop=0,5 do
		local enemyAddr = enemybaseAddress + 0x14C*enemyLoop
		local name = ""
		for nameLimit=0x0,0xD do
			if mr1(enemyAddr+nameLimit) == 0 then
				break
			end
			name = name .. string.char(mr1(enemyAddr+nameLimit))
		end
		-- Only keep going if this enemy is alive
		if mr2(enemyAddr+0x38) > 0 then
			enemyCount = enemyCount + 1
			-- GS1 doesn't go wide enough for more than 4 enemies
			if enemyCount == 5 then
				if ROM == "Golden_Sun_A" then
					rText(x,y,  " Only", c1, c2)
					rText(x,y+7,  " first", c1, c2)
					rText(x,y+14, " four", c1, c2)
					rText(x,y+21, " enemies", c1, c2)
					rText(x,y+28, " shown", c1, c2)
					break
				end
			end
			enemyAddr = enemyAddr + 0x34
			rText(x,y, name, c1, c2)
			progressbar_enemy(x,y+7, mr2(enemyAddr+0x04), mr2(enemyAddr+0x00), 0xFF6da73e, "red")
			rText(x,y+7, "HP:" .. mr2(enemyAddr+0x04), c1, c2)
			progressbar_enemy(x,y+14, mr2(enemyAddr+0x06), mr2(enemyAddr+0x02), 0xFF279ddb, 0xFFba1515)
			rText(x,y+14, "PP:" .. mr2(enemyAddr+0x06), c1, c2)
			rText(x,y+21, "AT:" .. mr2(enemyAddr+0x08) .. " DF:" .. mr2(enemyAddr+0x0A), c1, c2)
			rText(x,y+28, "AG:" .. mr2(enemyAddr+0x0C) .. " LU:" .. mr1(enemyAddr+0x0E), c1, c2)
			rText(x+56,y, "Pow/Res", c1, c2)
			-- Check which elemental resist is lowest, put a gold bar behind it, to highlight djinn-kill element
			if enemyCount == 2 then
			progressbar_lowestResist(x+55, y+7*checkLowestResist(mr2(enemyAddr+0x16), mr2(enemyAddr+0x1A), mr2(enemyAddr+0x1E), mr2(enemyAddr+0x22)))
			elseif enemyCount == 4 then
			progressbar_lowestResist(x+55, y+7*checkLowestResist(mr2(enemyAddr+0x16), mr2(enemyAddr+0x1A), mr2(enemyAddr+0x1E), mr2(enemyAddr+0x22)))
			else
			progressbar_lowestResist(x+56, y+7*checkLowestResist(mr2(enemyAddr+0x16), mr2(enemyAddr+0x1A), mr2(enemyAddr+0x1E), mr2(enemyAddr+0x22)))
			end
			rText(x+56,y+7, mr2(enemyAddr+0x14) .. "/" .. mr2(enemyAddr+0x16), 0xFFF87000, c2)
			rText(x+56,y+14, mr2(enemyAddr+0x18) .. "/" .. mr2(enemyAddr+0x1A), 0xFF00F8F8, c2)
			rText(x+56,y+21, mr2(enemyAddr+0x1C) .. "/" .. mr2(enemyAddr+0x1E), 0xFFFF0000, c2)
			rText(x+56,y+28, mr2(enemyAddr+0x20) .. "/" .. mr2(enemyAddr+0x22), 0xFFE070B0, c2)
			
			-- Move to next x-position
			-- Total width is 520, not evenly divisible by 6, best is alternating 87 and 86 for each enemy
			x = x + 86 +  (enemyCount % 2)
		end
		
		
		
	end
	

end

local gs_timer = 0
while true do
    gs_timer = gs_timer + 1
    if gs_timer > 59 then gs_timer = 2 end
    --ss_t=280
    --space(0,0,ss_r,0)
    client.SetGameExtraPadding(0,0,screen,35)
    --statID=1
	
	gui.drawImage("menu//neutral.png",0,0)
	
    x, y = 240, 0
    pcslot = 0
    for pcflag=0,7 do
        if getFlag(pcflag)==1 then
            if y >= 160 then
                x = x + 140
                y = 0
            end
            drawStatsByID(x, y, mr1(pcOrderBase + pcslot))
            y = y + 40
            pcslot = pcslot + 1
        end
    end

	-- Get enemy data
	drawEnemyData()

	if gs_timer > 1 and gs_timer <= 30 then
        gui.drawImage("menu//background.png",0,0)
    elseif gs_timer >= 30 and gs_timer < 60 then 
        gui.drawImage("menu//background2.png",0,0)
    end
    emu.frameadvance()
end
