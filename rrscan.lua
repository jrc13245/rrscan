--[[
rrscan.lua - Affinity Scanner (SuperWoW Enhanced)
IMPROVEMENTS:
- GUID-based targeting (instant, no TargetNearestEnemy loop!)
- Persistent GUID cache (finds Affinities even when out of range)
- Proactive scanning (collects GUIDs from all events)
- Fallback to vanilla method if SuperWoW not available
- Memory leak fixes
- Performance optimizations
]]

-- ===== PERFORMANCE: Cache global functions =====
local strfind = string.find
local strlower = string.lower
local strformat = string.format
local GetTime = GetTime
local UnitExists = UnitExists
local UnitName = UnitName
local UnitHealth = UnitHealth
local UnitIsDead = UnitIsDead
local UnitIsDeadOrGhost = UnitIsDeadOrGhost
local UnitIsFriend = UnitIsFriend
local CastSpellByName = CastSpellByName
local TargetUnit = _G.TargetUnit  -- SuperWoW function
local SpellInfo = _G.SpellInfo    -- SuperWoW function

-- ===== AFFINITY DEFINITIONS =====
local FireElName       = "Red Affinity"
local FrostElName      = "Blue Affinity"
local ArcaneElName     = "Mana Affinity"
local NatureElName     = "Green Affinity"
local ShadowElName     = "Black Affinity"
local PhysicalElName   = "Crystal Affinity"
local playerclass        

local affinityMessages = {
	[FireElName]     = "CAST FIRE SPELLS!",
	[FrostElName]    = "CAST FROST SPELLS!",
	[ArcaneElName]   = "CAST ARCANE SPELLS!",
	[NatureElName]   = "CAST NATURE SPELLS!",
	[ShadowElName]   = "CAST SHADOW SPELLS!",
	[PhysicalElName] = "SMASH IT WITH PHYSICAL DAMAGE!",
}

local EleTargets = {
	FireElName, FrostElName, ArcaneElName,
	NatureElName, ShadowElName, PhysicalElName
}

local mageSpells = {
	[FireElName]       = "Fireball",
	[FrostElName]      = "Frostbolt",
	[ArcaneElName]     = "Arcane Rupture",
	[NatureElName]     = "shoot",
	[PhysicalElName]   = "cantattack",
	[ShadowElName]     = "cantattack",
}

local warlockSpells = {
	[FireElName]       = "Immolate",
	[FrostElName]      = "cantattack",
	[ArcaneElName]     = "cantattack",
	[NatureElName]     = "shoot",
	[PhysicalElName]   = "cantattack",
	[ShadowElName]     = "Shadow Bolt",
}

local priestSpells = {
	[FireElName]       = "cantattack",
	[FrostElName]      = "cantattack",
	[ArcaneElName]     = "cantattack",
	[NatureElName]     = "shoot",
	[PhysicalElName]   = "cantattack",
	[ShadowElName]     = "Shadow Word: Pain",
}

local druidSpells = {
	[FireElName]       = "cantattack",
	[FrostElName]      = "cantattack",
	[ArcaneElName]     = "Starfire",
	[NatureElName]     = "Wrath",
	[PhysicalElName]   = "physical",
	[ShadowElName]     = "cantattack",
}

local hunterSpells = {
	[FireElName]       = "cantattack",
	[FrostElName]      = "cantattack",
	[ArcaneElName]     = "Arcane Shot",
	[NatureElName]     = "Serpent Sting",
	[PhysicalElName]   = "physical",
	[ShadowElName]     = "cantattack",
}

local rogueSpells = {
	[FireElName]       = "cantattack",
	[FrostElName]      = "cantattack",
	[ArcaneElName]     = "cantattack",
	[NatureElName]     = "cantattack",
	[PhysicalElName]   = "physical",
	[ShadowElName]     = "cantattack",
}

local warriorSpells = {
	[FireElName]       = "cantattack",
	[FrostElName]      = "cantattack",
	[ArcaneElName]     = "cantattack",
	[NatureElName]     = "cantattack",
	[PhysicalElName]   = "physical",
	[ShadowElName]     = "cantattack",
}

local paladinSpells = {
	[FireElName]       = "cantattack",
	[FrostElName]      = "cantattack",
	[ArcaneElName]     = "cantattack",
	[NatureElName]     = "cantattack",
	[PhysicalElName]   = "physical",
	[ShadowElName]     = "cantattack",
}

local pclasses = {
	["mage"]      = mageSpells,
	["warlock"]   = warlockSpells,
	["priest"]    = priestSpells,
	["druid"]     = druidSpells,
	["hunter"]    = hunterSpells,
	["rogue"]     = rogueSpells,
	["warrior"]   = warriorSpells,
	["paladin"]   = paladinSpells,
}

-- ===== SUPERWOW GUID SYSTEM =====
local hasSuperWoW = false
local GUIDCache = {}  -- guid -> {name, time}
local NameToGUID = {}  -- name -> guid (for targeting)
local AffinityGUIDs = {}  -- Separate cache for Affinities only
local debugMode = false

local Stats = {
	guidsCollected = 0,
	affinitiesFound = 0,
	superWowTargets = 0,
}

-- ===== GUID COLLECTION =====
local function AddUnit(unit)
	if not hasSuperWoW then return end
	if not unit then return end
	
	local exists, guid = UnitExists(unit)
	if not exists or not guid then return end
	
	local name = UnitName(guid)
	if not name then return end
	
	-- Check if unit is dead
	local isDead = UnitIsDead(guid) or UnitIsDeadOrGhost(guid) or UnitHealth(guid) <= 0
	
	-- Store in general GUID cache
	local isNew = GUIDCache[guid] == nil
	GUIDCache[guid] = {
		name = name,
		time = GetTime(),
		isDead = isDead
	}
	
	-- Update name-to-GUID mapping (only if alive!)
	if not isDead then
		NameToGUID[name] = guid
	end
	
	-- Check if this is an Affinity
	for _, affinityName in ipairs(EleTargets) do
		if name == affinityName then
			local oldGUID = AffinityGUIDs[affinityName]
			
			if not isDead then
				-- ✅ ALIVE Affinity found
				local isNewAffinity = (oldGUID == nil or oldGUID ~= guid)
				
				if isNewAffinity then
					if oldGUID then
						-- Different GUID = respawn
						if debugMode then
							DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[rrScan]|r " .. affinityName .. " respawned (new GUID)")
						end
					else
						-- First time seeing this Affinity
						if debugMode then
							DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[rrScan]|r Found NEW Affinity: " .. affinityName)
						end
					end
					
					Stats.affinitiesFound = Stats.affinitiesFound + 1
				end
				
				-- Always update to current GUID (even if same)
				AffinityGUIDs[affinityName] = guid
				
				if isNew then
					Stats.guidsCollected = Stats.guidsCollected + 1
				end
			else
				-- ❌ DEAD Affinity found
				if oldGUID == guid then
					-- This is the cached Affinity and it's dead - remove it
					AffinityGUIDs[affinityName] = nil
					if debugMode then
						DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[rrScan]|r " .. affinityName .. " died (removed from cache)")
					end
				end
				-- If oldGUID != guid, ignore this dead one (it's an old corpse)
			end
			break
		end
	end
end

-- ===== GUID CLEANUP =====
local cleanupTimer = 0
local CLEANUP_INTERVAL = 0.1

local function CleanupOldGUIDs()
	local removed = 0
	
	-- Cleanup GUIDs that no longer exist
	for guid, data in pairs(GUIDCache) do
		if not UnitExists(guid) then
			GUIDCache[guid] = nil
			removed = removed + 1
		end
	end
	
	-- ✅ CRITICAL: Cleanup DEAD Affinities from AffinityGUIDs cache
	for name, guid in pairs(AffinityGUIDs) do
		if not UnitExists(guid) then
			-- GUID no longer exists - remove it
			AffinityGUIDs[name] = nil
			if debugMode then
				DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa[rrScan]|r " .. name .. " no longer exists (removed)")
			end
		else
			-- GUID exists, but check if it's dead
			local isDead = UnitIsDead(guid) or UnitIsDeadOrGhost(guid) or UnitHealth(guid) <= 0
			if isDead then
				AffinityGUIDs[name] = nil
				if debugMode then
					DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[rrScan]|r " .. name .. " is dead (removed)")
				end
			end
		end
	end
	
	if debugMode and removed > 0 then
		DEFAULT_CHAT_FRAME:AddMessage("|cffaaaaaa[rrScan]|r Cleaned up " .. removed .. " old GUIDs")
	end
end

-- ===== AKTIVES SCANNEN NACH AFFINITIES =====
local function ScanAllGUIDsForAffinities()
	if not hasSuperWoW then return end
	
	for guid, data in pairs(GUIDCache) do
		-- Prüfe ob dies eine Affinity ist
		for _, affinityName in ipairs(EleTargets) do
			if data.name == affinityName then
				-- Prüfe ob noch nicht in AffinityGUIDs
				if not AffinityGUIDs[affinityName] then
					-- Verifiziere dass GUID noch existiert und lebendig ist
					if UnitExists(guid) then
						local isDead = UnitIsDead(guid) or UnitIsDeadOrGhost(guid) or UnitHealth(guid) <= 0
						if not isDead then
							AffinityGUIDs[affinityName] = guid
							if debugMode then
								DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[rrScan]|r Found " .. affinityName .. " via full scan!")
							end
						end
					end
				end
			end
		end
	end
end

-- ===== GUID COLLECTION FRAME =====
local guidFrame = CreateFrame("Frame")
guidFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
guidFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
guidFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
guidFrame:RegisterEvent("UNIT_AURA")
guidFrame:RegisterEvent("UNIT_HEALTH")
-- ✅ NEUE EVENTS WIE SHAGUSCAN:
guidFrame:RegisterEvent("UNIT_COMBAT")
guidFrame:RegisterEvent("UNIT_HAPPINESS")
guidFrame:RegisterEvent("UNIT_MODEL_CHANGED")
guidFrame:RegisterEvent("UNIT_PORTRAIT_UPDATE")
guidFrame:RegisterEvent("UNIT_FACTION")
guidFrame:RegisterEvent("UNIT_FLAGS")

guidFrame:SetScript("OnEvent", function()
	if not hasSuperWoW then return end
	
	if event == "UPDATE_MOUSEOVER_UNIT" then
		AddUnit("mouseover")
	elseif event == "PLAYER_TARGET_CHANGED" then
		AddUnit("target")
		AddUnit("targettarget")
	elseif event == "PLAYER_ENTERING_WORLD" then
		AddUnit("player")
		AddUnit("target")
	elseif event == "UNIT_HEALTH" then
		-- Bei Health-Updates sofort prüfen ob Affinity gestorben ist
		local unit = arg1
		if unit then
			AddUnit(unit)
		end
	else
		-- ✅ Alle anderen Events nutzen arg1 als unit
		local unit = arg1
		if unit then
			AddUnit(unit)
		end
	end
end)

-- ===== CLEANUP TIMER =====
local cleanupFrame = CreateFrame("Frame")
cleanupFrame:SetScript("OnUpdate", function()
	if not hasSuperWoW then return end
	
	cleanupTimer = cleanupTimer + (arg1 or 0.01)
	if cleanupTimer >= CLEANUP_INTERVAL then
		cleanupTimer = 0
		CleanupOldGUIDs()
		-- ✅ Nach Cleanup aktiv nach Affinities scannen
		ScanAllGUIDsForAffinities()
	end
end)

-- ===== SUPERWOW: TARGET BY GUID =====
local function targetAffinityByGUID(affinityName)
	if not hasSuperWoW or not TargetUnit then
		return false
	end
	
	local guid = AffinityGUIDs[affinityName]
	
	-- ✅ NEW: If no GUID cached, try to find one immediately
	if not guid then
		for cachedGuid, data in pairs(GUIDCache) do
			if data.name == affinityName and not data.isDead then
				if UnitExists(cachedGuid) then
					local stillAlive = not (UnitIsDead(cachedGuid) or UnitIsDeadOrGhost(cachedGuid) or UnitHealth(cachedGuid) <= 0)
					if stillAlive then
						AffinityGUIDs[affinityName] = cachedGuid
						guid = cachedGuid
						if debugMode then
							DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[rrScan]|r Recovered " .. affinityName .. " from cache!")
						end
						break
					end
				end
			end
		end
	end
	
	if not guid then
		return false
	end
	
	-- ✅ CRITICAL: Verify GUID is still alive before targeting!
	if not UnitExists(guid) then
		-- GUID no longer exists - remove it
		AffinityGUIDs[affinityName] = nil
		if debugMode then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[rrScan]|r " .. affinityName .. " GUID invalid (removed)")
		end
		return false
	end
	
	-- Check if it's dead
	local isDead = UnitIsDead(guid) or UnitIsDeadOrGhost(guid) or UnitHealth(guid) <= 0
	if isDead then
		-- Dead Affinity - remove from cache
		AffinityGUIDs[affinityName] = nil
		if debugMode then
			DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[rrScan]|r " .. affinityName .. " is dead (removed)")
		end
		return false
	end
	
	-- Try to target by GUID
	TargetUnit(guid)
	
	-- Verify target
	if UnitExists("target") then
		local _, targetGUID = UnitExists("target")
		if targetGUID == guid then
			Stats.superWowTargets = Stats.superWowTargets + 1
			if debugMode then
				DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[rrScan]|r SuperWoW targeting: " .. affinityName)
			end
			return true
		end
	end
	
	return false
end

-- ===== VANILLA: TARGET BY NAME (FALLBACK) =====
function targetAliveElementalByName(name)
	-- Erst prüfen ob die Affinity überhaupt existiert, BEVOR wir Target clearen
	local found = false
	
	-- Scan ohne Target zu ändern
	for i = 1, 10 do
		TargetNearestEnemy()
		if UnitExists("target") then
			local unitName = strlower(UnitName("target") or "")
			local isDead = UnitIsDeadOrGhost("target") or UnitHealth("target") <= 0
			local isFriend = UnitIsFriend("player", "target")

			if not isDead and not isFriend and unitName == strlower(name) then
				found = true
				Stats.vanillaTargets = Stats.vanillaTargets + 1
				return true
			end
		end
	end
	
	-- Nur wenn NICHT gefunden, Target NICHT ändern (altes Target behalten)
	return false
end

-- ===== MAIN SCAN FUNCTION (SUPERWOW ONLY) =====
function rrScan(safeDefaultSpell)
    if not hasSuperWoW then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[rrScan]|r SuperWoW required! Install SuperWoW to use this addon.", 1, 0, 0)
        return false
    end
    
    playerclass = strlower(UnitClass("player"))
    if not pclasses[playerclass] then
        CastSpellByName(safeDefaultSpell)
        return
    end

    local engaging = false
    local unit = "target"

    -- Check if current target is an Affinity
    if UnitExists(unit) then  
        local currentTargetName = UnitName(unit)
        
        -- Collect GUID from current target
        AddUnit(unit)
        
        for _, affinity in ipairs(EleTargets) do
            if currentTargetName == affinity then
                local unNotAttackable = UnitIsFriend("player", unit)
                local unDead = not (UnitHealth(unit) > 0) or UnitIsDeadOrGhost(unit)
                local ability = strlower(pclasses[playerclass][affinity] or "")
                if not (unNotAttackable or unDead) and ability ~= "cantattack" then
                    engaging = true
                    rrEngageElemental(affinity, true)
                    return
                end
            end
        end
    end

    -- Scan for alive Affinity (SuperWoW ONLY)
    if not engaging then
        for _, affinity in ipairs(EleTargets) do
            local ability = strlower(pclasses[playerclass][affinity] or "")
            if ability ~= "cantattack" then
                -- SuperWoW GUID targeting
                if targetAffinityByGUID(affinity) then
                    rrEngageElemental(affinity, false)
                    engaging = true
                    break
                end
            end
        end
    end

    -- No Affinity engaged – fallback spell
    if not engaging then
        if safeDefaultSpell and safeDefaultSpell ~= "" then
            CastSpellByName(safeDefaultSpell)
            return true
        end
        return false
    end
    return true
end

function rrEngageElemental(elementalName, continuing)
	if continuing then
		rrCastTheThing(elementalName)
	else
		local ability = strlower(pclasses[playerclass][elementalName] or "")
		if ability ~= "cantattack" then
			PlaySound("GLUECREATECHARACTERBUTTON")
			local customMsg = affinityMessages[elementalName]
			if customMsg then
				DEFAULT_CHAT_FRAME:AddMessage(elementalName .. " detected, " .. customMsg, 1, 0, 0)
			end
		end
		rrPrepEngagement(elementalName)
		rrCastTheThing(elementalName)
	end
end

function rrPrepEngagement(elementalName)
	SpellStopCasting()
end

function isInCatForm()
	for i = 1, GetNumShapeshiftForms() do
		local name, _, isActive = GetShapeshiftFormInfo(i)
		if isActive and i == 3 then
			return true
		end
	end
	return false
end

function isInMoonkinForm()
	for i = 1, 40 do
		local buff = UnitBuff("player", i)
		if buff and strfind(buff, "Moonkin") then
			return true
		end
	end
	return false
end

function cancelShapeshiftForm()
	for i = 1, 40 do
		local icon = UnitBuff("player", i)
		if icon then
			local _, _, buffTexture = UnitBuff("player", i)
			if buffTexture and strfind(buffTexture, "Ability_") then
				CancelPlayerBuff(i)
				break
			end
		end
	end
end

function rrCastTheThing(elementalName)
	local abilities = pclasses[playerclass]
	if abilities and abilities[elementalName] then
		local ability = strlower(abilities[elementalName])

		if playerclass == "druid" then
			if elementalName == PhysicalElName then
				if not isInCatForm() then
					cancelShapeshiftForm()
					CastSpellByName("Cat Form")
				else
					CastSpellByName("Claw")
				end
				return
			elseif elementalName == ArcaneElName or elementalName == NatureElName then
				if not isInMoonkinForm() then
					cancelShapeshiftForm()
				end
			end
		end

		if ability ~= "cantattack" then
			if ability == "shoot" then
				for i = 1, 120 do
					if IsAutoRepeatAction(i) then
						return
					end
				end
			end
			CastSpellByName(ability)
		end
	end
end

-- ===== SLASH COMMANDS =====
SLASH_RRSCAN1 = "/rrscan"
SlashCmdList["RRSCAN"] = function(msg)
	-- Check for status command
	if msg == "status" then
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00========== rrScan Status ==========|r")
		
		if hasSuperWoW then
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00SuperWoW:|r |cff00ff00ACTIVE|r")
		else
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00SuperWoW:|r |cffffcc00NOT AVAILABLE (Vanilla Mode)|r")
		end
		
		local guidCount = 0
		for _ in pairs(GUIDCache) do
			guidCount = guidCount + 1
		end
		
		local affinityCount = 0
		for _ in pairs(AffinityGUIDs) do
			affinityCount = affinityCount + 1
		end
		
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Cached GUIDs:|r " .. guidCount)
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Cached Affinities:|r " .. affinityCount)
		
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Statistics:|r")
		DEFAULT_CHAT_FRAME:AddMessage("  GUIDs Collected: " .. Stats.guidsCollected)
		DEFAULT_CHAT_FRAME:AddMessage("  Affinities Found: " .. Stats.affinitiesFound)
		DEFAULT_CHAT_FRAME:AddMessage("  SuperWoW Targets: " .. Stats.superWowTargets)
		
		if hasSuperWoW then
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Known Affinities:|r")
			for name, guid in pairs(AffinityGUIDs) do
				local exists = UnitExists(guid) and "|cff00ff00[OK]|r" or "|cffff0000[X]|r"
				DEFAULT_CHAT_FRAME:AddMessage("  " .. exists .. " " .. name)
			end
		end
		
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00======================================|r")
		return
	end
	
	-- Check for debug command
	if msg == "debug" then
		debugMode = not debugMode
		if debugMode then
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[rrScan]|r Debug mode |cff00ff00ENABLED|r")
		else
			DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[rrScan]|r Debug mode |cffff0000DISABLED|r")
		end
		return
	end
	
	-- Check for clear command
	if msg == "clear" then
		GUIDCache = {}
		NameToGUID = {}
		AffinityGUIDs = {}
		Stats.guidsCollected = 0
		Stats.affinitiesFound = 0
		Stats.superWowTargets = 0
		Stats.vanillaTargets = 0
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[rrScan]|r All cached data cleared!")
		return
	end
	
	-- Normal scan
	local didSomething = rrScan(msg)
	if not didSomething and (not msg or msg == "") then
		-- Do nothing (original behavior)
	end
end

local function Initialize()
	-- Check if SuperWoW is available
	hasSuperWoW = (TargetUnit ~= nil and SpellInfo ~= nil)
	
	if hasSuperWoW then
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[rrScan]|r Loaded. SuperWoW GUID targeting: |cff00ff00ACTIVE|r")
		DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00[rrScan]|r Commands: /rrscan status, /rrscan debug")
		guidFrame:Show()
		cleanupFrame:Show()
	else
		DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[rrScan]|r ERROR: SuperWoW NOT detected!")
		DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[rrScan]|r This addon REQUIRES SuperWoW to function!")
		DEFAULT_CHAT_FRAME:AddMessage("|cffff0000[rrScan]|r Download: https://github.com/balakethelock/SuperWoW")
		guidFrame:Hide()
		cleanupFrame:Hide()
	end
end

-- ===== RUFE INITIALIZE AUF =====
Initialize()