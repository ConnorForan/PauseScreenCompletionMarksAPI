-- Pause Screen Completion Marks API by Connor, aka Ghostbroster
-- Credit to JSG and Tem for first rendering completion marks on the pause screen in "Completion Marks for Modded Characters".
-- Thanks to DeadInfinity for letting me using Dead Sea Scrolls' font for this.
-- 
-- GitHub page: https://github.com/ConnorForan/PauseScreenCompletionMarksAPI
-- 
-- !! Please see included readme file for a guide and more info!
-- 
-- !! Please do not modify this code! If you want additional features or options, let me know!
-- Discord: Connor#2143
-- Steam: Ghostbroster Connor
-- Email: ghostbroster@gmail.com
-- Twitter: @Ghostbroster

local VERSION = 2

local CACHED_CHARACTER_CALLBACKS
local CACHED_MOD_MARK_CALLBACKS
local CACHED_ALT_SHADER

if PauseScreenCompletionMarksAPI then
	-- PauseScreenCompletionMarksAPI is already initialized, likely via another mod.
	if PauseScreenCompletionMarksAPI.VERSION > VERSION then
		-- The existing version is newer than this one. Keep that one.
		return
	end
	-- The existing version is either older, or the same version, so we should reload.
	-- We have to reload even on the same version, since some stuff breaks if the mod that contains
	-- the latest version of PauseScreenCompletionMarksAPI reloads but we don't reload this.
	-- Before we reload though, cache the current callbacks from other mods so that we don't lose them.
	CACHED_CHARACTER_CALLBACKS = PauseScreenCompletionMarksAPI.CHARACTER_CALLBACKS
	CACHED_MOD_MARK_CALLBACKS = PauseScreenCompletionMarksAPI.MOD_MARKS_CALLBACKS
	CACHED_ALT_SHADER = PauseScreenCompletionMarksAPI.ALT_SHADER
end

PauseScreenCompletionMarksAPI = RegisterMod("Pause Screen Completion Marks", 1)

PauseScreenCompletionMarksAPI.VERSION = VERSION
PauseScreenCompletionMarksAPI.CHARACTER_CALLBACKS = CACHED_CHARACTER_CALLBACKS or {}
PauseScreenCompletionMarksAPI.MOD_MARKS_CALLBACKS = CACHED_MOD_MARK_CALLBACKS or {}
PauseScreenCompletionMarksAPI.ALT_SHADER = CACHED_ALT_SHADER

local kDefaultShader = "PauseScreenCompletionMarks"

local game = Game()
local kZeroVector = Vector(0,0)
local kNormalVector = Vector(1,1)

--Stolen from PROAPI
local function Lerp(first,second,percent)
	return (first + (second - first)*percent)
end

local function LOG(str)
	str = "[PauseScreenCompletionMarksAPI] " .. str
	Isaac.DebugString(str)
end

local function LOG_ERROR(str)
	str = "[PauseScreenCompletionMarksAPI] ERROR: " .. str
	print(str)
	Isaac.DebugString(str)
end

local function LOG_WARNING(str)
	str = "[PauseScreenCompletionMarksAPI] WARNING: " .. str
	Isaac.DebugString(str)
end

--------------------------------------------------
-- VARS
--------------------------------------------------

-- Base offset from the center of the screen where the pause screen post-it is.
local kDefaultPostItsRenderOffset = Vector(-72, -84)
-- Offset from the above where the modded completion mark sheet is rendered.
local kDefaultModMarksRenderOffset = Vector(172, -5)

--------------------------------------------------
-- Allows using an existing shader
--------------------------------------------------

function PauseScreenCompletionMarksAPI:SetShader(shaderName)
	if shaderName and not PauseScreenCompletionMarksAPI.ALT_SHADER then
		PauseScreenCompletionMarksAPI.ALT_SHADER = shaderName
	end
end

--------------------------------------------------
-- Compatability
--------------------------------------------------

local kUnintrusiveHudPostItOffset = Vector(65, 50)
local kUnintrusiveHudModMarkOffset = Vector(50, -50)

local kMiniHudPostItOffset = Vector(92, 89)
local kMiniHudModMarkOffset = Vector(24, -234)

local function GetPostItRenderOffset()
	if UNINTRUSIVEPAUSEMENU then
		return kUnintrusiveHudPostItOffset
	elseif MiniPauseMenu_Mod or MiniPauseMenuPlus_Mod then
		return kMiniHudPostItOffset
	else
		return kDefaultPostItsRenderOffset
	end
end

local function GetModMarksRenderOffset()
	if UNINTRUSIVEPAUSEMENU then
		return kUnintrusiveHudModMarkOffset
	elseif MiniPauseMenu_Mod or MiniPauseMenuPlus_Mod then
		return kMiniHudModMarkOffset
	else
		return kDefaultModMarksRenderOffset
	end
end

--------------------------------------------------
-- VANILLA COMPLETION MARK HANDLING
--------------------------------------------------

local vanillaMarks
local vanillaMarksSprite

local NormalizedStringToVanillaMarkLayer = {
	DELIRIUM = 0,
	DELERIUM = 0,
	DELI = 0,
	VOID = 0,
	
	MOMSHEART = 1,
	HEART = 1,
	WOMB = 1,
	ITLIVES = 1,
	LIVES = 1,
	
	ISAAC = 2,
	CATHEDRAL = 2,
	
	SATAN = 3,
	STAN = 3,
	SHEOL = 3,
	
	BOSSRUSH = 4,
	BOSS = 4,
	RUSH = 4,
	
	BLUEBABY = 5,
	CHEST = 5,
	["???"] = 5,
	
	LAMB = 6,
	DARKROOM = 6,
	
	MEGASATAN = 7,
	MEGASTAN = 7,
	
	GREED = 8,
	GREEDMODE = 8,
	ULTRAGREED = 8,
	GREEDIER = 8,
	GREEDIERMODE = 8,
	ULTRAGREEDIER = 8,
	
	HUSH = 9,
	BLUEWOMB = 9,
	
	MOTHER = 10,
	WITNESS = 10,
	CORPSE = 10,
	
	BEAST = 11,
	HOME = 11,
	ASCENT = 11,
}
for i=0, 11 do
	NormalizedStringToVanillaMarkLayer[""..i] = i
end

function PauseScreenCompletionMarksAPI:AddModCharacterCallback(playerType, func)
	local callbacks = PauseScreenCompletionMarksAPI.CHARACTER_CALLBACKS
	if callbacks[playerType] then
		LOG("Overwriting CharacterCallback for character: " .. playerType)
	else
		LOG("Adding CharacterCallback for character: " .. playerType)
	end
	callbacks[playerType] = func
end

-- Converts strings to uppercase, removes whitespace, punctuation and any leading "THE".
local function Normalize(str)
	if type(str) ~= "string" then
		return str
	end
	local normalizedString = string.upper(str):gsub("[%c%p%s]", ""):gsub("^THE", "")
	return normalizedString
end

local function NormalizeTableKeys(tab)
	local newTab = {}
	for k,v in pairs(tab) do
		newTab[Normalize(k)] = v
	end
	return newTab
end

local function IsTaintedChar(player)
	return player:GetPlayerType() == Isaac.GetPlayerTypeByName(player:GetName(), true)
end

-- Collect the completion marks to render for player 1.
local function GetCompletionMarks()
	completionMarks = nil
	
	local player = Isaac.GetPlayer(0)
	
	local getMarksFunction = PauseScreenCompletionMarksAPI.CHARACTER_CALLBACKS[player:GetPlayerType()]
	if not getMarksFunction then return end
	
	local data = getMarksFunction()
	if not data then return end
	
	completionMarks = {}
	
	for k, v in pairs(data) do
		local normalizedKey = Normalize(k)
		
		local layer
		if type(k) == "string" then
			layer = NormalizedStringToVanillaMarkLayer[normalizedKey]
		elseif type(k) == "number" then
			layer = k
		end
		
		if not layer then
			LOG_WARNING("Failed to parse completion mark name/layer `" .. k .. "`, for character: " .. player:GetName())
		else
			local frame
			if type(v) == "table" then
				local tab = NormalizeTableKeys(v)
				if tab.HARD or tab.HARDMODE or tab.ONHARD or tab.ONHARDMODE then
					frame = 2
				elseif tab.UNLOCK or tab.UNLOCKED or tab.LOCKED == false then
					if normalizedKey == "GREEDIER" or normalizedKey == "GREEDIERMODE" or normalizedKey == "ULTRAGREEDIER" then
						frame = 2
					else
						frame = 1
					end
				else
					frame = 0
				end
			elseif type(v) == "number" then
				frame = v
			elseif type(v) == "string" then
				frame = tonumber(v)
			elseif type(v) == "boolean" then
				if v then
					frame = 1
				else
					frame = 0
				end
			end
			
			if not frame then
				LOG_ERROR("Failed to parse completion mark [" .. k .. " / " .. layer .. "] status for character: " .. player:GetName() .. " (A `" .. type(v) .. "` was provided)")
				LOG_ERROR(v)
				return
			elseif frame ~= math.floor(frame) or (layer > 0 and frame > 2) or (layer == 0 and frame > 5) then
				LOG_ERROR("Invalid anm2 frame parsed for completion mark [" .. k .. " / " .. layer .. "]: " .. frame)
				return
			elseif layer == 0 and IsTaintedChar(player) and frame < 3 then
				frame = frame + 3
			end
			
			completionMarks[layer] = frame
		end
	end
end

local function PrepareVanillaMarks()
	local player = Isaac.GetPlayer(0)
	
	-- Ignore vanilla characters.
	if player:GetPlayerType() < PlayerType.NUM_PLAYER_TYPES then
		completionMarks = nil
		return
	end
	
	LOG("Preparing vanilla marks for character #" .. player:GetPlayerType() .." (".. player:GetName() .. ")...")
	
	GetCompletionMarks()
	
	if not completionMarks then
		LOG("None found - character is likely not supported.")
		return
	end
	
	LOG("...Marks found...")
	
	if not vanillaMarksSprite then
		vanillaMarksSprite = Sprite()
		vanillaMarksSprite:Load("gfx/ui/completion_widget.anm2", false)
		for i=0, 9 do
			vanillaMarksSprite:ReplaceSpritesheet(i,"gfx/ui/completion_widget_pause.png")
		end
		vanillaMarksSprite:LoadGraphics()
		vanillaMarksSprite:Play("Idle", true)
		vanillaMarksSprite:Stop()
	end
	
	for layer, frame in pairs(completionMarks) do
		vanillaMarksSprite:SetLayerFrame(layer, frame)
	end
	
	LOG("...Done.")
end

--------------------------------------------------
-- TEXT RENDERING
--------------------------------------------------

local kDefaultFontColor = Color(55.0/255, 43.0/255, 45.0/255, 1)
local kWhiteFontColor = Color(1,1,1,1,0,0,0)

local font

-- Taken directly from DeadSeaScrolls.
-- First value is the anm2 frame for that character.
-- Other values are the char widths for the 12, 16, and 24 font sizes respectively.
-- (I only use the size 12 font, though).
local CharData = {}
CharData['a'] = { 0, 4, 7, 11 }
CharData['b'] = { 1, 4, 8, 12 }
CharData['c'] = { 2, 4, 7, 10 }
CharData['d'] = { 3, 4, 8, 12 }
CharData['e'] = { 4, 4, 7, 10 }
CharData['f'] = { 5, 4, 6, 9 }
CharData['g'] = { 6, 5, 8, 12 }
CharData['h'] = { 7, 4, 8, 11 }
CharData['i'] = { 8, 1, 3, 4 }
CharData['j'] = { 9, 4, 7, 11 }
CharData['k'] = { 10, 4, 6, 9 }
CharData['l'] = { 11, 4, 8, 10 }
CharData['m'] = { 12, 5, 8, 13 }
CharData['n'] = { 13, 4, 8, 10 }
CharData['o'] = { 14, 5, 10, 12 }
CharData['p'] = { 15, 4, 7, 10 }
CharData['q'] = { 16, 5, 9, 13 }
CharData['r'] = { 17, 4, 7, 10 }
CharData['s'] = { 18, 4, 6, 10 }
CharData['t'] = { 19, 4, 7, 10 }
CharData['u'] = { 20, 4, 7, 13 }
CharData['v'] = { 21, 5, 8, 13 }
CharData['w'] = { 22, 5, 11, 16 }
CharData['x'] = { 23, 4, 6, 12 }
CharData['y'] = { 24, 4, 7, 10 }
CharData['z'] = { 25, 4, 6, 9 }
CharData['0'] = { 26, 4, 8, 12 }
CharData['1'] = { 27, 4, 8, 10 }
CharData['2'] = { 28, 4, 8, 10 }
CharData['3'] = { 29, 4, 8, 10 }
CharData['4'] = { 30, 4, 7, 10 }
CharData['5'] = { 31, 4, 8, 9 }
CharData['6'] = { 32, 4, 8, 10 }
CharData['7'] = { 33, 4, 8, 10 }
CharData['8'] = { 34, 4, 8, 9 }
CharData['9'] = { 35, 4, 8, 9 }
CharData["'"] = { 36, 1, 2, 3 }
CharData['"'] = { 37, 3, 4, 5 }
CharData[':'] = { 38, 1, 3, 4 }
CharData['/'] = { 39, 3, 6, 8 }
CharData['.'] = { 40, 1, 2, 4 }
CharData[','] = { 41, 2, 3, 4 }
CharData['!'] = { 42, 2, 4, 6 }
CharData['?'] = { 43, 3, 6, 8 }
CharData['['] = { 44, 2, 4, 6 }
CharData[']'] = { 45, 2, 4, 6 }
CharData['('] = { 44, 2, 4, 6 }
CharData[')'] = { 45, 2, 4, 6 }
CharData['$'] = { 46, 4, 6, 8 }
CharData['C'] = { 47, 5, 6, 8 }
CharData['+'] = { 48, 5, 6, 8 }
CharData['-'] = { 49, 4, 6, 10 }
CharData['X'] = { 50, 5, 6, 8 }
CharData['D'] = { 51, 5, 6, 8 }
CharData['%'] = { 52, 4, 6, 8 }
CharData['_'] = { 54, 2, 4, 5 }
CharData[' '] = { 54, 4, 6, 8 }
CharData['='] = { 53, 5, 8, 12 }

local kFontHorizontalPadding = 1

-- Calculates the width of this string when rendered.
local function GetStringWidth(str)
	local totalWidth = 0
	str = string.lower(str)
	for c in str:gmatch(".") do
		local charData = CharData[c]
		if charData then
			local frame = charData[1]
			local width = charData[2]
			if totalWidth > 0 then
				totalWidth = totalWidth + kFontHorizontalPadding
			end
			totalWidth = totalWidth + width
		end
	end
	return totalWidth
end

-- Renders a string at the given position.
local function RenderString(str, pos, scale)
	if not font then
		font = Sprite()
		font:Load("gfx/ui/pause screen completion marks/menu_font.anm2", true)
		font:Play("12", true)
		font:Stop()
		if UNINTRUSIVEPAUSEMENU then
			font.Color = kWhiteFontColor
		else
			font.Color = kDefaultFontColor
		end
	end
	
	if scale then
		font.Scale = scale
	else
		font.Scale = kNormalVector
	end
	
	str = string.lower(str)
	for c in str:gmatch(".") do
		local charData = CharData[c]
		if charData then
			local frame = charData[1]
			local width = charData[2]
			font:SetFrame(frame)
			font:Render(pos, kZeroVector, kZeroVector)
			pos = pos + Vector(width + kFontHorizontalPadding, 0)
		end
	end
end

--------------------------------------------------
-- MODDED COMPLETION MARKS HANDLING
--------------------------------------------------

local kMinPageWidth = 3
local kMaxPageWidth = 4
local kMaxPageHeight = 6

local kMaxSpritesPerPage = kMaxPageWidth * (kMaxPageHeight-1)

local modPaperSprite
local modMarkPages
local modMarksPageWidth = kMaxPageWidth

local currentModMarkPage = 1

local kFadedColor = Color(1,1,1, 0.4)
local kModNameOffset = Vector(3, 10)
local kElipses =  "..."

function PauseScreenCompletionMarksAPI:AddModMarksCallback(modKey, func)
	local callbacks = PauseScreenCompletionMarksAPI.MOD_MARKS_CALLBACKS
	modKey = string.lower(modKey)
	if callbacks[modKey] then
		LOG("Overwriting ModMarksCallback for mod: " .. modKey)
	else
		LOG("Adding ModMarksCallback for mod: " .. modKey)
	end
	callbacks[modKey] = func
end

local function PrepareModMarks()
	LOG("Preparing mod marks...")
	
	if not modPaperSprite then
		modPaperSprite = Sprite()
		modPaperSprite:Load("gfx/ui/pause screen completion marks/custom_marks_sheet.anm2", true)
		modPaperSprite:Stop()
		if UNINTRUSIVEPAUSEMENU then
			modPaperSprite:ReplaceSpritesheet(0, "gfx/ui/pause screen completion marks/custom_marks_sheet_unintrusive.png")
			modPaperSprite:LoadGraphics()
		end
	end
	
	local playerType = Isaac.GetPlayer(0):GetPlayerType()
	
	local mods = {}
	local mostMarks = 0
	
	-- Fetch all the mod marks.
	for modName, func in pairs(PauseScreenCompletionMarksAPI.MOD_MARKS_CALLBACKS) do
		local modData = {}
		modData.Name = modName
		modData.MarkGroups = {}
		
		local marks = {}
		
		local numMarks = 0
		
		local sprites = func(playerType)
		
		if sprites and #sprites > 0 then
			for _, sprite in pairs(sprites) do
				local spriteData = {}
				if type(sprite) == "table" then
					for k, v in pairs(sprite) do
						local normalizedKey = Normalize(k)
						if k == 1 or normalizedKey == "SPRITE" then
							spriteData.Sprite = v
						elseif k == 2 or normalizedKey == "ANIM" or normalizedKey == "ANIMATION" then
							spriteData.Animation = v
						elseif k == 3 or normalizedKey == "FRAME" then
							spriteData.Frame = v
						end
					end
				else
					spriteData = {Sprite = sprite}
				end
				if #marks >= kMaxSpritesPerPage then
					-- Page is full. Split the rest of the marks onto the next page.
					table.insert(modData.MarkGroups, marks)
					marks = {}
				end
				table.insert(marks, spriteData)
				numMarks = numMarks + 1
			end
		end
		
		if numMarks > 0 then
			table.insert(modData.MarkGroups, marks)
			modData.TotalMarks = numMarks
			table.insert(mods, modData)
			mostMarks = math.max(mostMarks, numMarks)
		end
	end
	
	table.sort(mods, function(a,b) return a.Name < b.Name end)
	
	modMarkPages = {}
	modMarksPageWidth = math.min(math.max(kMinPageWidth, mostMarks), kMaxPageWidth)
	
	-- Allocate the marks onto pages.
	for i, mod in pairs(mods) do
		local foundSpot = false
		local firstGroupNumRows = 1 + math.ceil(#mod.MarkGroups[1] / modMarksPageWidth)
		if firstGroupNumRows < kMaxPageHeight-1 then
			-- Try to find an existing page we can fit this into.
			for _, page in pairs(modMarkPages) do
				if not foundSpot and page.Size + firstGroupNumRows <= kMaxPageHeight then
					table.insert(page.Mods, {
						Name = mod.Name,
						Marks = mod.MarkGroups[1],
						Part = 1,
					})
					page.Size = page.Size + firstGroupNumRows
					foundSpot = true
				end
			end
		end
		if not foundSpot then
			-- No existing pages to fit into. Add a new one, or multiple if needed.
			for i, markGroup in pairs(mod.MarkGroups) do
				local numRows = 1 + math.ceil(#markGroup / modMarksPageWidth)
				table.insert(modMarkPages, {
					Mods = {
						{Name = mod.Name, Marks = markGroup, Part = i}
					},
					Size = numRows,
				})
			end
		end
	end
	
	LOG("...Done.")
end

local function RenderModPostItPiece(pos, anim, frame, row, col, mark)
	modPaperSprite:SetFrame(anim, frame)
	local rot = modPaperSprite.Rotation
	local scale = modPaperSprite.Scale
	local offset = Vector(col * 18 * scale.X, row * 18 * scale.Y):Rotated(rot)
	modPaperSprite.Offset = offset
	modPaperSprite:Render(pos, kZeroVector, kZeroVector)
	if mark then
		local sprite = mark.Sprite
		if mark.Animation then
			sprite:Play(mark.Animation, true)
		end
		if mark.Frame then
			sprite:SetFrame(mark.Frame)
		end
		sprite.Rotation = rot
		sprite.Scale = scale
		sprite.Offset = offset + kNormalVector
		sprite:Render(pos, kZeroVector, kZeroVector)
	end
end

local function RenderModMarks(pos, posOffset, scale)
	if not modMarkPages or #modMarkPages == 0 then return end
	
	if MiniPauseMenu_Mod or MiniPauseMenuPlus_Mod then
		posOffset = posOffset * Vector(1, -1)
	end
	
	pos =  pos + posOffset * scale + GetModMarksRenderOffset() * scale
	
	modPaperSprite.Scale = scale
	
	local numRows = kMaxPageHeight
	local numColumns = modMarksPageWidth
	
	currentModMarkPage = math.max(currentModMarkPage, 1)
	currentModMarkPage = math.min(currentModMarkPage, #modMarkPages)
	local page = modMarkPages[currentModMarkPage]
	
	local mods = page.Mods
	
	local currentMod = next(mods)
	local markIterator = next(mods[currentMod].Marks)
	
	local finished = false
	local needToWriteModName = true
	
	for row=0, numRows+1 do
		-- If needed, advance to the next mod.
		while not markIterator and not finished do
			currentMod = next(mods, currentMod)
			if currentMod then
				markIterator = next(mods[currentMod].Marks)
				needToWriteModName = true
			else
				finished = true
			end
		end
		
		-- Render pieces of the mod marks sheet, and the marks themselves.
		for col=0, numColumns+1 do
			local anim
			local frame = 0
			local mark
			if row == 0 then
				if col == 0 then
					anim = "TopLeft"
				elseif col == numColumns+1 then
					anim = "TopRight"
				else
					anim = "Top"
					frame = (col-1) % 3
				end
			elseif row == numRows+1 or finished then
				if col == 0 then
					anim = "BottomLeft"
				elseif col == numColumns+1 then
					anim = "BottomRight"
				else
					anim = "Bottom"
					frame = (col-1) % 3
				end
			elseif col == 0 then
				anim = "Left"
				frame = (row-1) % 3
			elseif col == numColumns+1 then
				anim = "Right"
				frame = (row-1) % 3
			else
				anim = "Middle"
				if not needToWriteModName and markIterator and row > 0 then
					mark = mods[currentMod].Marks[markIterator]
					markIterator = next(mods[currentMod].Marks, markIterator)
				end
			end
			RenderModPostItPiece(pos, anim, frame, row, col, mark)
		end
		
		if currentMod and row > 0 and needToWriteModName then
			-- Print the mod's name on this line.
			local modNamePos = pos + Vector(18 * scale.X, row * 18 * scale.Y) + kModNameOffset
			local str = mods[currentMod].Name
			local maxWidth = 18 * numColumns - kModNameOffset.X * 2
			
			local suffix = ""
			if mods[currentMod].Part > 1 then
				suffix = " (" .. mods[currentMod].Part .. ")"
			end
			
			if GetStringWidth(str .. suffix) > maxWidth then
				while GetStringWidth(str .. kElipses .. suffix) > maxWidth do
					str = str:sub(1, -2)
				end
				str = str .. kElipses .. suffix
			else
				str = str .. suffix
			end
			
			RenderString(str, modNamePos, scale)
			
			needToWriteModName = false
		end
		
		if finished then
			break
		end
		
		row = row + 1
	end
	
	if not (UNINTRUSIVEPAUSEMENU or MiniPauseMenu_Mod or MiniPauseMenuPlus_Mod) then
		-- Pin
		modPaperSprite:SetFrame("Pin", 0)
		modPaperSprite.Offset = Vector(18 * (numColumns+2) * scale.X * 0.5 - 9, 0):Rotated(modPaperSprite.Rotation)
		modPaperSprite:Render(pos, kZeroVector, kZeroVector)
	end
	
	if #modMarkPages > 1 then
		-- Left Arrow
		modPaperSprite:SetFrame("LeftArrow", 0)
		modPaperSprite.Offset = Vector(18 * (1) * scale.X, 8)
		if currentModMarkPage == 1 then
			modPaperSprite.Color = kFadedColor
			modPaperSprite:Render(pos, kZeroVector, kZeroVector)
			modPaperSprite.Color = Color.Default
		else
			modPaperSprite:Render(pos, kZeroVector, kZeroVector)
		end
		
		-- Right Arrow
		modPaperSprite:SetFrame("RightArrow", 0)
		modPaperSprite.Offset = Vector(18 * (numColumns) * scale.X, 8)
		if currentModMarkPage == #modMarkPages then
			modPaperSprite.Color = kFadedColor
			modPaperSprite:Render(pos, kZeroVector, kZeroVector)
			modPaperSprite.Color = Color.Default
		else
			modPaperSprite:Render(pos, kZeroVector, kZeroVector)
		end
		
		-- Page Number
		local pageNumStr = "" .. currentModMarkPage .. " / " .. #modMarkPages
		local pageNumOffset = Vector(18 * (numColumns+2) * scale.X * 0.5 - GetStringWidth(pageNumStr) * 0.5 - 1, 18)
		RenderString(pageNumStr, pos + pageNumOffset, scale)
	end
end

--------------------------------------------------
-- ANIMATION/RENDERING
--------------------------------------------------

local currentAnim = nil
local keyframeIndex = nil
local keyframeCounter = 0
local animFinished = 0

-- Appear/Disappear animations taken from the "CompletionWidget" layer of "pausescreen.anm2".
local Animations = {
	Appear = {
		-- These values are the correct ones for the first frame of this animation.
		-- However, I think my rendering starts one frame late, so I use the next values instead.
		-- All that matters is that things are lined up nicely as-is right now.
		--[[{
			PosOffsetX = -560,
			PosOffsetY = 42,
			ScaleX = 1.5,
			ScaleY = 0.5,
			Duration = 5
		},]]
		{
			PosOffsetX = -445,
			PosOffsetY = 32,
			ScaleX = 1.38,
			ScaleY = 0.62,
			Duration = 4
		},
		{
			PosOffsetX = 12,
			PosOffsetY = -8,
			ScaleX = 0.9,
			ScaleY = 1.1,
			Duration = 2
		},
		{
			PosOffsetX = 0,
			PosOffsetY = 0,
			ScaleX = 1.0,
			ScaleY = 1.0,
			Duration = 1
		},
	},
	Disappear = {
		{
			PosOffsetX = 0,
			PosOffsetY = 0,
			ScaleX = 1.0,
			ScaleY = 1.0,
			Duration = 2 -- Should actually be 3, but the I think the rendering starts 1 frame late as previously mentioned.
		},
		{
			PosOffsetX = 0,
			PosOffsetY = 0,
			ScaleX = 1.0,
			ScaleY = 1.0,
			Duration = 2
		},
		{
			PosOffsetX = 12,
			PosOffsetY = -8,
			ScaleX = 0.9,
			ScaleY = 1.1,
			Duration = 5
		},
		{
			PosOffsetX = 540,
			PosOffsetY = 42,
			ScaleX = 1.5,
			ScaleY = 0.5,
			Duration = 1
		},
	},
	MiniAppear = {
		{
			PosOffsetX = 0,
			PosOffsetY = 63,
			ScaleX = 0.5,
			ScaleY = 1.5,
			Duration = 1
		},
		{
			PosOffsetX = 0,
			PosOffsetY = 0,
			ScaleX = 1.1,
			ScaleY = 0.9,
			Duration = 2
		},
		{
			PosOffsetX = 0,
			PosOffsetY = 0,
			ScaleX = 1.0,
			ScaleY = 1.0,
			Duration = 1
		},
	},
	MiniDisappear = {
		{
			PosOffsetX = 0,
			PosOffsetY = 0,
			ScaleX = 1.0,
			ScaleY = 1.0,
			Duration = 2
		},
		{
			PosOffsetX = 0,
			PosOffsetY = 0,
			ScaleX = 1.1,
			ScaleY = 0.9,
			Duration = 2
		},
		{
			PosOffsetX = 0,
			PosOffsetY = 63,
			ScaleX = 0.5,
			ScaleY = 1.5,
			Duration = 1
		},
	},
}

-- Advances the slide in/out animation by 1 frame.
local function AnimatePauseScreenPostIts(anim)
	if not keyframeIndex then
		keyframeIndex = 1
		keyframeCounter = 0
		if Isaac.GetFrameCount() % 2 == 0 then
			keyframeCounter = -0.5
		end
		animFinished = 0
	end
	local currentKeyframe = Animations[anim][keyframeIndex]
	local nextKeyframe = Animations[anim][keyframeIndex+1]
	
	local posOffset = Vector(currentKeyframe.PosOffsetX, currentKeyframe.PosOffsetY)
	local scale = Vector(currentKeyframe.ScaleX, currentKeyframe.ScaleY)
	if nextKeyframe then
		local lerpValue = math.floor(keyframeCounter) / currentKeyframe.Duration
		posOffset = Lerp(posOffset, Vector(nextKeyframe.PosOffsetX, nextKeyframe.PosOffsetY), lerpValue)
		scale = Lerp(scale, Vector(nextKeyframe.ScaleX, nextKeyframe.ScaleY), lerpValue)
		keyframeCounter = keyframeCounter + 0.5
		if keyframeCounter >= currentKeyframe.Duration then
			keyframeIndex = keyframeIndex + 1
			keyframeCounter = 0
		end
	else
		animFinished = (animFinished or 0) + 1
	end
	
	return posOffset, scale
end

-- Renders the custom sheets according to the current animation state.
local function RenderPostIt(anim, instant)
	if Isaac.GetChallenge() > 0 then return end
	
	if not anim then return end
	
	if anim ~= currentAnim then
		if instant then
			keyframeIndex = #Animations[anim]
		else
			keyframeIndex = nil
		end
		keyframeCounter = 0
		animFinished = 0
		if anim == "Appear" then
			PrepareVanillaMarks()
			PrepareModMarks()
			currentModMarkPage = 1
		elseif anim == "Disappear" and currentAnim ~= "Appear" then
			return
		end
	end
	
	currentAnim = anim
	
	local cid = game:GetPlayer(0).ControllerIndex
	if Input.IsActionTriggered(ButtonAction.ACTION_MENURIGHT, cid) and currentModMarkPage < #modMarkPages then
		currentModMarkPage = currentModMarkPage + 1
	elseif Input.IsActionTriggered(ButtonAction.ACTION_MENULEFT, cid) and currentModMarkPage > 1 then
		currentModMarkPage = currentModMarkPage - 1
	end
	
	local trueAnim = anim
	
	if UNINTRUSIVEPAUSEMENU or MiniPauseMenu_Mod or MiniPauseMenuPlus_Mod then
		trueAnim = "Mini" .. anim
	end
	
	local posOffset, scale = AnimatePauseScreenPostIts(trueAnim)
	local extraOffset = Vector(math.floor((Isaac.GetScreenWidth()/10) - 48), 0)
	local screenCenterPos = Vector(math.floor(Isaac.GetScreenWidth()*0.5), math.floor(Isaac.GetScreenHeight()*0.5))
	local pos = screenCenterPos + GetPostItRenderOffset() + extraOffset
	
	if not (anim == "Disappear" and animFinished > 1) then
		if completionMarks and vanillaMarksSprite then
			vanillaMarksSprite.Scale = scale
			vanillaMarksSprite:Render(pos + posOffset, kZeroVector, kZeroVector)
		end
		RenderModMarks(pos, posOffset, scale)
	end
end

--------------------------------------------------
-- TRACKING THE CURRENT PAUSE MENU STATE
--------------------------------------------------

-- I'm not aware of a good way to track the player LEAVING the console if they open it while paused.
-- Aside from something crazy like tracking every valid keyboard input to the console to detect when
-- enter is pressed AND the console line is empty. So for this, if the player opens the console while
-- in the pause menu, I treat it as if they were unpausing and just hide everything until they unpause.
-- Other than the console, this section seems to do a good job at keeping track of the current pause menu state!
-- Feel free to steal if you want it for something.
local states = {
	UNPAUSED = {
		Hide = true,
		[ButtonAction.ACTION_PAUSE] = "RESUME",
		[ButtonAction.ACTION_MENUBACK] = "RESUME",
		[Keyboard.KEY_GRAVE_ACCENT] = "IN_CONSOLE",
	},
	UNPAUSING = {},
	UNPAUSING_HIDDEN = { Hide = true },
	OPTIONS = {
		[ButtonAction.ACTION_PAUSE] = "UNPAUSING",
		[ButtonAction.ACTION_MENUBACK] = "UNPAUSING",
		[ButtonAction.ACTION_MENUCONFIRM] = "IN_OPTIONS",
		[ButtonAction.ACTION_MENUDOWN] = "RESUME",
		[ButtonAction.ACTION_MENUUP] = "EXIT",
		[Keyboard.KEY_GRAVE_ACCENT] = "UNPAUSING",
	},
	RESUME = {
		[ButtonAction.ACTION_PAUSE] = "UNPAUSING",
		[ButtonAction.ACTION_MENUBACK] = "UNPAUSING",
		[ButtonAction.ACTION_MENUCONFIRM] = "UNPAUSING",
		[ButtonAction.ACTION_MENUDOWN] = "EXIT",
		[ButtonAction.ACTION_MENUUP] = "OPTIONS",
		[Keyboard.KEY_GRAVE_ACCENT] = "UNPAUSING",
	},
	EXIT = {
		[ButtonAction.ACTION_PAUSE] = "UNPAUSING",
		[ButtonAction.ACTION_MENUBACK] = "UNPAUSING",
		[ButtonAction.ACTION_MENUDOWN] = "OPTIONS",
		[ButtonAction.ACTION_MENUUP] = "RESUME",
		[Keyboard.KEY_GRAVE_ACCENT] = "UNPAUSING",
	},
	IN_OPTIONS = {
		Hide = true,
		Ignore = ButtonAction.ACTION_PAUSE,
		[ButtonAction.ACTION_MENUBACK] = "OPTIONS",
		[Keyboard.KEY_GRAVE_ACCENT] = "UNPAUSING_HIDDEN",
	},
	IN_CONSOLE = {
		Hide = true,
		[ButtonAction.ACTION_PAUSE] = "IN_CONSOLE",
		[ButtonAction.ACTION_MENUBACK] = "UNPAUSED",
	},
}

local wasPausedLastFrame = false
local currentState = "UNPAUSED"

local function UpdateState()
	if not game:IsPaused() then
		currentState = "UNPAUSED"
		currentAnim = nil
		return
	elseif currentState == "UNPAUSED" and wasPausedLastFrame then
		return
	end
	
	local cid = game:GetPlayer(0).ControllerIndex
	
	if states[currentState].Ignore and Input.IsActionTriggered(states[currentState].Ignore, cid) then
		return
	end
	
	for buttonAction, state in pairs(states[currentState]) do
		if type(buttonAction) == "number" and (Input.IsActionTriggered(buttonAction, cid) or Input.IsButtonTriggered(buttonAction, cid)) then
			currentState = state
			return
		end
	end
end

--------------------------------------------------
-- MAIN SHADER HOOK
--------------------------------------------------

-- Don't run logic more than once per frame.
-- If multiple mods have this installed, there may be multiple instances of the shader.
local lastUpdate = 0

function PauseScreenCompletionMarksAPI:EntryPoint()
	local currentFrame = Isaac.GetFrameCount()
	
	if lastUpdate == currentFrame then
		return
	end
	
	UpdateState()
	
	if currentState == "UNPAUSING" then
		RenderPostIt("Disappear")
	elseif not states[currentState].Hide then
		RenderPostIt("Appear")
	end
	
	wasPausedLastFrame = game:IsPaused()
	
	lastUpdate = currentFrame
end

function PauseScreenCompletionMarksAPI:Shaderhook(shaderName)
	if shaderName == kDefaultShader or (PauseScreenCompletionMarksAPI.ALT_SHADER and shaderName == PauseScreenCompletionMarksAPI.ALT_SHADER) then
		PauseScreenCompletionMarksAPI:EntryPoint()
	end
end
PauseScreenCompletionMarksAPI:AddCallback(ModCallbacks.MC_GET_SHADER_PARAMS, PauseScreenCompletionMarksAPI.Shaderhook)
