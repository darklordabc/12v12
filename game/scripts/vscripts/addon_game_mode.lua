if not IsDedicatedServer() and not IsInToolsMode() then error("") end
-- Rebalance the distribution of gold and XP to make for a better 10v10 game
local GOLD_SCALE_FACTOR_INITIAL = 1
local GOLD_SCALE_FACTOR_FINAL = 2.5
local GOLD_SCALE_FACTOR_FADEIN_SECONDS = (60 * 60) -- 60 minutes
local XP_SCALE_FACTOR_INITIAL = 2
local XP_SCALE_FACTOR_FINAL = 2
local XP_SCALE_FACTOR_FADEIN_SECONDS = (60 * 60) -- 60 minutes

local game_start = true

-- Anti feed system
local TROLL_FEED_DISTANCE_FROM_FOUNTAIN_TRIGGER = 6000 -- Distance from allince Fountain
local TROLL_FEED_BUFF_BASIC_TIME = (60 * 10)   -- 10 minutes
local TROLL_FEED_TOTAL_RESPAWN_TIME_MULTIPLE = 2.5 -- x2.5 respawn time. If you respawn 100sec, after debuff you respawn 250sec
local TROLL_FEED_INCREASE_BUFF_AFTER_DEATH = 60 -- 1 minute
local TROLL_FEED_RATIO_KD_TO_TRIGGER_MIN = -5 -- (Kill-Death)
local TROLL_FEED_NEED_TOKEN_TO_BUFF = 3
local TROLL_FEED_TOKEN_TIME_DIES_WITHIN = (60 * 1.5) -- 1.5 minutes
local TROLL_FEED_TOKEN_DURATION = (60 * 5) -- 5 minutes
local TROLL_FEED_MIN_RESPAWN_TIME = 60 -- 1 minute
local TROLL_FEED_SYSTEM_ASSISTS_TO_KILL_MULTI = 0.5 -- 10 assists = 5 "kills"

--Requirements to Buy Divine Rapier
local NET_WORSE_FOR_RAPIER_MIN = 20000

--Change team system
local ts_entities = LoadKeyValues('scripts/kv/ts_entities.kv')
local COOLDOWN_FOR_CHANGE_TEAM = (60 * 3) -- 3 minutes
local MIN_DIFFERNCE_PLAYERS_IN_TEAM = 2 -- Player can change team if they're playing 10vs12, not 11vs12
local TIME_LIMIT_FOR_CHANGE_TEAM = (60 * 20) -- Players cannot change team after this time
_G.changeTeamProgress = false
_G.changeTeamTimes = {}
_G.isChangeTeamAvailable = false

--Max neutral items for each player (hero/stash/courier)
_G.MAX_NEUTRAL_ITEMS_FOR_PLAYER = 3

require("common/init")
require("util")
require("neutral_items_drop_choice")
require("gpm_lib")
require("game_options/game_options")
require("shuffle_team")

WebApi.customGame = "Dota12v12"

LinkLuaModifier("modifier_dummy_inventory", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_core_courier", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_patreon_courier", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_silencer_new_int_steal", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_troll_feed_token", 'anti_feed_system/modifier_troll_feed_token', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_troll_feed_token_couter", 'anti_feed_system/modifier_troll_feed_token_couter', LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_troll_debuff_stop_feed", 'anti_feed_system/modifier_troll_debuff_stop_feed', LUA_MODIFIER_MOTION_NONE)

LinkLuaModifier("modifier_super_tower","game_options/modifiers_lib/modifier_super_tower", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_mega_creep","game_options/modifiers_lib/modifier_mega_creep", LUA_MODIFIER_MOTION_NONE)

_G.newStats = newStats or {}
_G.personalCouriers = {}
_G.mainTeamCouriers = {}

_G.lastDeathTimes = {}
_G.lastHeroKillers = {}
_G.lastHerosPlaceLastDeath = {}
_G.tableRadiantHeroes = {}
_G.tableDireHeroes = {}
_G.newRespawnTimes = {}

_G.itemsIsBuy = {}
_G.lastTimeBuyItemWithCooldown = {}

_G.tPlayersMuted = {}

if CMegaDotaGameMode == nil then
	_G.CMegaDotaGameMode = class({}) -- put CMegaDotaGameMode in the global scope
	--refer to: http://stackoverflow.com/questions/6586145/lua-require-with-global-local
end

function Precache( context )
	PrecacheResource( "soundfile", "soundevents/custom_soundboard_soundevents.vsndevts", context )

	PrecacheResource( "soundfile", "soundevents/game_sounds_heroes/game_sounds_chen.vsndevts", context )
	PrecacheResource( "particle", "particles/alert_ban_hammer.vpcf", context )
	PrecacheResource( "particle", "particles/econ/items/faceless_void/faceless_void_weapon_bfury/faceless_void_weapon_bfury_cleave_c.vpcf", context )
	PrecacheResource( "particle", "particles/custom_cleave.vpcf", context )

	local heroeskv = LoadKeyValues("scripts/heroes.txt")
	for hero, _ in pairs(heroeskv) do
		PrecacheResource( "soundfile", "soundevents/voscripts/game_sounds_vo_"..string.sub(hero,15)..".vsndevts", context )
	end

	Cosmetics:Precache( context )
end

function Activate()
	Cosmetics:Init()
	CMegaDotaGameMode:InitGameMode()
end

_G.ItemKVs = {}

function CMegaDotaGameMode:InitGameMode()
	_G.ItemKVs = LoadKeyValues("scripts/npc/npc_block_items_for_troll.txt")
	print( "10v10 Mode Loaded!" )

	local neutral_items = LoadKeyValues("scripts/npc/neutral_items.txt")

	_G.neutralItems = {}

	for _, data in pairs( neutral_items ) do
		for item, turn in pairs( data.items ) do
			if turn == 1 then
				_G.neutralItems[item] = true
			end
		end
	end

	-- Adjust team limits
	GameRules:SetCustomGameTeamMaxPlayers( DOTA_TEAM_GOODGUYS, 12 )
	GameRules:SetCustomGameTeamMaxPlayers( DOTA_TEAM_BADGUYS, 12 )
	GameRules:SetStrategyTime( 0.0 )
	GameRules:SetShowcaseTime( 0.0 )

	-- Hook up gold & xp filters
    GameRules:GetGameModeEntity():SetItemAddedToInventoryFilter( Dynamic_Wrap( CMegaDotaGameMode, "ItemAddedToInventoryFilter" ), self )
	GameRules:GetGameModeEntity():SetModifyGoldFilter( Dynamic_Wrap( CMegaDotaGameMode, "FilterModifyGold" ), self )
	GameRules:GetGameModeEntity():SetModifyExperienceFilter( Dynamic_Wrap(CMegaDotaGameMode, "FilterModifyExperience" ), self )
	GameRules:GetGameModeEntity():SetBountyRunePickupFilter( Dynamic_Wrap(CMegaDotaGameMode, "FilterBountyRunePickup" ), self )
	GameRules:GetGameModeEntity():SetModifierGainedFilter( Dynamic_Wrap( CMegaDotaGameMode, "ModifierGainedFilter" ), self )
	GameRules:GetGameModeEntity():SetRuneSpawnFilter( Dynamic_Wrap( CMegaDotaGameMode, "RuneSpawnFilter" ), self )
	GameRules:GetGameModeEntity():SetExecuteOrderFilter(Dynamic_Wrap(CMegaDotaGameMode, 'ExecuteOrderFilter'), self)
	GameRules:GetGameModeEntity():SetDamageFilter( Dynamic_Wrap( CMegaDotaGameMode, "DamageFilter" ), self )


	GameRules:GetGameModeEntity():SetTowerBackdoorProtectionEnabled( true )
	GameRules:GetGameModeEntity():SetPauseEnabled(IsInToolsMode())
	GameRules:SetGoldTickTime( 0.3 ) -- default is 0.6
	GameRules:LockCustomGameSetupTeamAssignment(true)

	if GetMapName() == "dota_tournament" then
		GameRules:SetCustomGameSetupAutoLaunchDelay(20)
	else
		GameRules:SetCustomGameSetupAutoLaunchDelay(10)
	end

	GameRules:GetGameModeEntity():SetKillableTombstones( true )
	GameRules:GetGameModeEntity():SetFreeCourierModeEnabled(true)

	if IsInToolsMode() then
		GameRules:GetGameModeEntity():SetDraftingBanningTimeOverride(0)
	end

	ListenToGameEvent('game_rules_state_change', Dynamic_Wrap(CMegaDotaGameMode, 'OnGameRulesStateChange'), self)
	ListenToGameEvent( "npc_spawned", Dynamic_Wrap( CMegaDotaGameMode, "OnNPCSpawned" ), self )
	ListenToGameEvent( "entity_killed", Dynamic_Wrap( CMegaDotaGameMode, 'OnEntityKilled' ), self )
	ListenToGameEvent("dota_player_pick_hero", Dynamic_Wrap(CMegaDotaGameMode, "OnHeroPicked"), self)
	ListenToGameEvent('player_connect_full', Dynamic_Wrap(CMegaDotaGameMode, 'OnConnectFull'), self)
	ListenToGameEvent('player_disconnect', Dynamic_Wrap(CMegaDotaGameMode, 'OnPlayerDisconnect'), self)
	ListenToGameEvent( "player_chat", Dynamic_Wrap( CMegaDotaGameMode, "OnPlayerChat" ), self )

	self.m_CurrentGoldScaleFactor = GOLD_SCALE_FACTOR_INITIAL
	self.m_CurrentXpScaleFactor = XP_SCALE_FACTOR_INITIAL
	self.couriers = {}
	GameRules:GetGameModeEntity():SetThink( "OnThink", self, 5 )

	ListenToGameEvent("dota_player_used_ability", function(event)
		local hero = PlayerResource:GetSelectedHeroEntity(event.PlayerID)
		if not hero then return end
		if event.abilityname == "night_stalker_darkness" then
			local ability = hero:FindAbilityByName(event.abilityname)
			CustomGameEventManager:Send_ServerToAllClients("time_nightstalker_darkness", {
				duration = ability:GetSpecialValueFor("duration")
			})
		end
		if event.abilityname == "item_blink" then
			local oldpos = hero:GetAbsOrigin()
			Timers:CreateTimer( 0.01, function()
				local pos = hero:GetAbsOrigin()

				if IsInBugZone(pos) then
					FindClearSpaceForUnit(hero, oldpos, false)
				end
			end)
		end
	end, nil)

	_G.raxBonuses = {}
	_G.raxBonuses[DOTA_TEAM_GOODGUYS] = 0
	_G.raxBonuses[DOTA_TEAM_BADGUYS] = 0

	Timers:CreateTimer( 0.6, function()
		for i = 0, GameRules:NumDroppedItems() - 1 do
			local container = GameRules:GetDroppedItem( i )

			if container then
				local item = container:GetContainedItem()

				if item:GetAbilityName():find( "item_ward_" ) then
					local owner = item:GetOwner()

					if owner then
						local team = owner:GetTeam()
						local fountain
						local multiplier

						if team == DOTA_TEAM_GOODGUYS then
							multiplier = -350
							fountain = Entities:FindByName( nil, "ent_dota_fountain_good" )
						elseif team == DOTA_TEAM_BADGUYS then
							multiplier = -650
							fountain = Entities:FindByName( nil, "ent_dota_fountain_bad" )
						end

						local fountain_pos = fountain:GetAbsOrigin()

						if ( fountain_pos - container:GetAbsOrigin() ):Length2D() > 1200 then
							local pos_item = fountain_pos:Normalized() * multiplier + RandomVector( RandomFloat( 0, 200 ) ) + fountain_pos
							pos_item.z = fountain_pos.z

							container:SetAbsOrigin( pos_item )
							CustomGameEventManager:Send_ServerToPlayer( PlayerResource:GetPlayer( owner:GetPlayerID() ), "display_custom_error", { message = "#dropped_wards_return_error" } )
						end
					end
				end
			end
		end

		return 0.6
	end )

	GameOptions:Init()
end

function IsInBugZone(pos)
	local sum = pos.x + pos.y
	return sum > 14150 or sum < -14350 or pos.x > 7750 or pos.x < -7750 or pos.y > 7500 or pos.y < -7300
end

function GetActivePlayerCountForTeam(team)
    local number = 0
    for x=0,DOTA_MAX_TEAM do
        local pID = PlayerResource:GetNthPlayerIDOnTeam(team,x)
        if PlayerResource:IsValidPlayerID(pID) and (PlayerResource:GetConnectionState(pID) == 1 or PlayerResource:GetConnectionState(pID) == 2) then
            number = number + 1
        end
    end
    return number
end

function GetActiveHumanPlayerCountForTeam(team)
    local number = 0
    for x=0,DOTA_MAX_TEAM do
        local pID = PlayerResource:GetNthPlayerIDOnTeam(team,x)
        if PlayerResource:IsValidPlayerID(pID) and not self:isPlayerBot(pID) and (PlayerResource:GetConnectionState(pID) == 1 or PlayerResource:GetConnectionState(pID) == 2) then
            number = number + 1
        end
    end
    return number
end

function otherTeam(team)
    if team == DOTA_TEAM_BADGUYS then
        return DOTA_TEAM_GOODGUYS
    elseif team == DOTA_TEAM_GOODGUYS then
        return DOTA_TEAM_BADGUYS
    end
    return -1
end

function UnitInSafeZone(unit , unitPosition)
	local teamNumber = unit:GetTeamNumber()
	local fountains = Entities:FindAllByClassname('ent_dota_fountain')
	local allyFountainPosition
	for i, focusFountain in pairs(fountains) do
		if focusFountain:GetTeamNumber() == teamNumber then
			allyFountainPosition = focusFountain:GetAbsOrigin()
		end
	end
	return ((allyFountainPosition - unitPosition):Length2D()) <= TROLL_FEED_DISTANCE_FROM_FOUNTAIN_TRIGGER
end

function GetHeroKD(unit)
	return (unit:GetKills() + (unit:GetAssists() * TROLL_FEED_SYSTEM_ASSISTS_TO_KILL_MULTI) - unit:GetDeaths())
end

function ItWorstKD(unit) -- use minimun TROLL_FEED_RATIO_KD_TO_TRIGGER_MIN
	local unitTeam = unit:GetTeamNumber()
	local focusTableHeroes

	if unitTeam == DOTA_TEAM_GOODGUYS then
		focusTableHeroes = _G.tableRadiantHeroes
	elseif unitTeam == DOTA_TEAM_BADGUYS then
		focusTableHeroes = _G.tableDireHeroes
	end

	for i, focusHero in pairs(focusTableHeroes) do
		local unitKD = GetHeroKD(unit)
		if unitKD > TROLL_FEED_RATIO_KD_TO_TRIGGER_MIN then
			return false
		elseif GetHeroKD(focusHero) <= unitKD and unit ~= focusHero then
			return false
		end
	end
	return true
end
function CMegaDotaGameMode:SetTeamColors()
	local ggp = 0
	local bgp = 0
	local ggcolor = {
		{70,70,255},
		{0,255,255},
		{255,0,255},
		{255,255,0},
		{255,165,0},
		{0,255,0},
		{255,0,0},
		{75,0,130},
		{109,49,19},
		{255,20,147},
		{128,128,0},
		{255,255,255}
	}
	local bgcolor = {
		{255,135,195},
		{160,180,70},
		{100,220,250},
		{0,128,0},
		{165,105,0},
		{153,50,204},
		{0,128,128},
		{0,0,165},
		{128,0,0},
		{180,255,180},
		{255,127,80},
		{0,0,0}
	}
	for i=0, PlayerResource:GetPlayerCount()-1 do
		if PlayerResource:GetTeam(i) == DOTA_TEAM_GOODGUYS then
			ggp = ggp + 1
			PlayerResource:SetCustomPlayerColor(i,ggcolor[ggp][1],ggcolor[ggp][2],ggcolor[ggp][3])
		end
		if PlayerResource:GetTeam(i) == DOTA_TEAM_BADGUYS then
			bgp = bgp + 1
			PlayerResource:SetCustomPlayerColor(i,bgcolor[bgp][1],bgcolor[bgp][2],bgcolor[bgp][3])
		end
	end
end
function CMegaDotaGameMode:OnHeroPicked(event)
	local hero = EntIndexToHScript(event.heroindex)
	if not hero then return end

	if hero:GetTeamNumber() == DOTA_TEAM_GOODGUYS then
		table.insert(_G.tableRadiantHeroes, hero)
	end

	if hero:GetTeamNumber() == DOTA_TEAM_BADGUYS then
		table.insert(_G.tableDireHeroes, hero)
	end
end
---------------------------------------------------------------------------
-- Filter: DamageFilter
---------------------------------------------------------------------------
function CMegaDotaGameMode:DamageFilter(event)
	local entindex_victim_const = event.entindex_victim_const
	local entindex_attacker_const = event.entindex_attacker_const
	local death_unit
	local killer

	if (entindex_victim_const) then death_unit = EntIndexToHScript(entindex_victim_const) end
	if (entindex_attacker_const) then killer = EntIndexToHScript(entindex_attacker_const) end

	if death_unit and death_unit:HasModifier("modifier_troll_debuff_stop_feed") and (death_unit:GetHealth() <= event.damage) and (killer ~= death_unit) and (killer:GetTeamNumber()~=DOTA_TEAM_NEUTRALS) then
		if ItWorstKD(death_unit) and (not (UnitInSafeZone(death_unit, _G.lastHerosPlaceLastDeath[death_unit]))) then
			local newTime = death_unit:FindModifierByName("modifier_troll_debuff_stop_feed"):GetRemainingTime() + TROLL_FEED_INCREASE_BUFF_AFTER_DEATH
			--death_unit:RemoveModifierByName("modifier_troll_debuff_stop_feed")
			local normalRespawnTime =  death_unit:GetRespawnTime()
			local addRespawnTime = normalRespawnTime * (TROLL_FEED_TOTAL_RESPAWN_TIME_MULTIPLE - 1)

			if addRespawnTime + normalRespawnTime < TROLL_FEED_MIN_RESPAWN_TIME then
				addRespawnTime = TROLL_FEED_MIN_RESPAWN_TIME - normalRespawnTime
			end
			death_unit:AddNewModifier(death_unit, nil, "modifier_troll_debuff_stop_feed", { duration = newTime, addRespawnTime = addRespawnTime })
		end
		death_unit:Kill(nil, death_unit)
	end

	return true
end

---------------------------------------------------------------------------
-- Event: OnEntityKilled
---------------------------------------------------------------------------
function CMegaDotaGameMode:OnEntityKilled( event )
	local entindex_killed = event.entindex_killed
    local entindex_attacker = event.entindex_attacker
	local killedUnit
    local killer
	local name

	if (entindex_killed) then
		killedUnit = EntIndexToHScript(entindex_killed)
		name = killedUnit:GetUnitName()
	end
	if (entindex_attacker) then killer = EntIndexToHScript(entindex_attacker) end

	local raxRespawnTimeWorth = {
		npc_dota_goodguys_range_rax_top = 1,
		npc_dota_goodguys_melee_rax_top = 2,
		npc_dota_goodguys_range_rax_mid = 1,
		npc_dota_goodguys_melee_rax_mid = 2,
		npc_dota_goodguys_range_rax_bot = 1,
		npc_dota_goodguys_melee_rax_bot = 2,
		npc_dota_badguys_range_rax_top = 1,
		npc_dota_badguys_melee_rax_top = 2,
		npc_dota_badguys_range_rax_mid = 1,
		npc_dota_badguys_melee_rax_mid = 2,
		npc_dota_badguys_range_rax_bot = 1,
		npc_dota_badguys_melee_rax_bot = 2,
	}
	if raxRespawnTimeWorth[name] ~= nil then
		local team = killedUnit:GetTeam()
		raxBonuses[team] = raxBonuses[team] + raxRespawnTimeWorth[name]
		SendOverheadEventMessage( nil, OVERHEAD_ALERT_MANA_ADD, killedUnit, raxRespawnTimeWorth[name], nil )
		GameRules:SendCustomMessage("#destroyed_" .. string.sub(name,10,#name - 4),-1,0)
		if raxBonuses[team] == 9 then
			raxBonuses[team] = 11
			if team == DOTA_TEAM_BADGUYS then
				GameRules:SendCustomMessage("#destroyed_badguys_all_rax",-1,0)
			else
				GameRules:SendCustomMessage("#destroyed_goodguys_all_rax",-1,0)
			end
		end
	end
	if killedUnit:IsClone() then killedUnit = killedUnit:GetCloneSource() end
	--print("fired")
    if killer and killedUnit and killedUnit:IsRealHero() and not killedUnit:IsReincarnating() then
		local player_id = -1
		if killer:IsRealHero() and killer.GetPlayerID then
			player_id = killer:GetPlayerID()
		else
			if killer:GetPlayerOwnerID() ~= -1 then
				player_id = killer:GetPlayerOwnerID()
			end
		end
		if player_id ~= -1 then

			newStats[player_id] = newStats[player_id] or {
				npc_dota_sentry_wards = 0,
				npc_dota_observer_wards = 0,
				tower_damage = 0,
				killed_hero = {}
			}

			local kh = newStats[player_id].killed_hero

			kh[name] = kh[name] and kh[name] + 1 or 1
		end


	    local dotaTime = GameRules:GetDOTATime(false, false)
	    --local timeToStartReduction = 0 -- 20 minutes
	    local respawnReduction = 0.65 -- Original Reduction rate

	    -- Reducation Rate slowly increases after a certain time, eventually getting to original levels, this is to prevent games lasting too long
	    --if dotaTime > timeToStartReduction then
	    --	dotaTime = dotaTime - timeToStartReduction
	    --	respawnReduction = respawnReduction + ((dotaTime / 60) / 100) -- 0.75 + Minutes of Game Time / 100 e.g. 25 minutes fo game time = 0.25
	    --end

	    --if respawnReduction > 1 then
	    --	respawnReduction = 1
	    --end

	    local timeLeft = killedUnit:GetRespawnTime()
	 	timeLeft = timeLeft * respawnReduction -- Respawn time reduced by a rate

	    -- Disadvantaged teams get 5 seconds less respawn time for every missing player
	    local herosTeam = GetActivePlayerCountForTeam(killedUnit:GetTeamNumber())
	    local opposingTeam = GetActivePlayerCountForTeam(otherTeam(killedUnit:GetTeamNumber()))
	    local difference = herosTeam - opposingTeam

	    local addedTime = 0
	    if difference < 0 then
	        addedTime = difference * 5
	        local RespawnReductionRate = string.format("%.2f", tostring(respawnReduction))
		    local OriginalRespawnTime = tostring(math.floor(timeLeft))
		    local TimeToReduce = tostring(math.floor(addedTime))
		    local NewRespawnTime = tostring(math.floor(timeLeft + addedTime))
	        --GameRules:SendCustomMessage( "ReductionRate:"  .. " " .. RespawnReductionRate .. " " .. "OriginalTime:" .. " " ..OriginalRespawnTime .. " " .. "TimeToReduce:" .. " " ..TimeToReduce .. " " .. "NewRespawnTime:" .. " " .. NewRespawnTime, 0, 0)
	    end

	    timeLeft = timeLeft + addedTime
	    --print(timeLeft)

		timeLeft = timeLeft + ((raxBonuses[killedUnit:GetTeam()] - raxBonuses[killedUnit:GetOpposingTeamNumber()]) * (1-respawnReduction))

	    if timeLeft < 1 then
	        timeLeft = 1
	    end

		if killedUnit and (not killedUnit:HasModifier("modifier_troll_debuff_stop_feed")) and (not ItWorstKD(killedUnit)) then
			killedUnit:SetTimeUntilRespawn(timeLeft)
		end
    end

	if killedUnit and killedUnit:IsRealHero() and (PlayerResource:GetSelectedHeroEntity(killedUnit:GetPlayerID())) then
		_G.lastHeroKillers[killedUnit] = killer
		_G.lastHerosPlaceLastDeath[killedUnit] = killedUnit:GetOrigin()
		if (killer ~= killedUnit) then
			_G.lastDeathTimes[killedUnit] = GameRules:GetGameTime()
		end
	end

end

LinkLuaModifier("modifier_rax_bonus", LUA_MODIFIER_MOTION_NONE)


function CMegaDotaGameMode:OnNPCSpawned(event)
	local spawnedUnit = EntIndexToHScript(event.entindex)
	local tokenTrollCouter = "modifier_troll_feed_token_couter"

	if spawnedUnit and spawnedUnit.reduceCooldownAfterRespawn and _G.lastHeroKillers[spawnedUnit] then
		local killersTeam = _G.lastHeroKillers[spawnedUnit]:GetTeamNumber()
		if killersTeam ~=spawnedUnit:GetTeamNumber() and killersTeam~= DOTA_TEAM_NEUTRALS then
			for i = 0, 20 do
				local item = spawnedUnit:GetItemInSlot(i)
				if item then
					local cooldown_remaining = item:GetCooldownTimeRemaining()
					if cooldown_remaining > 0 then
						item:EndCooldown()
						item:StartCooldown(cooldown_remaining-(cooldown_remaining/100*spawnedUnit.reduceCooldownAfterRespawn))
					end
				end
			end
			for i = 0, 30 do
				local ability = spawnedUnit:GetAbilityByIndex(i)
				if ability then
					local cooldown_remaining = ability:GetCooldownTimeRemaining()
					if cooldown_remaining > 0 then
						ability:EndCooldown()
						ability:StartCooldown(cooldown_remaining-(cooldown_remaining/100*spawnedUnit.reduceCooldownAfterRespawn))
					end
				end
			end
		end
		spawnedUnit.reduceCooldownAfterRespawn = false
	end
	-- Assignment of tokens during quick death, maximum 3
	if spawnedUnit and (_G.lastDeathTimes[spawnedUnit] ~= nil) and (spawnedUnit:GetDeaths() > 1) and ((GameRules:GetGameTime() - _G.lastDeathTimes[spawnedUnit]) < TROLL_FEED_TOKEN_TIME_DIES_WITHIN) and not spawnedUnit:HasModifier("modifier_troll_debuff_stop_feed") and (_G.lastHeroKillers[spawnedUnit]~=spawnedUnit) and (not (UnitInSafeZone(spawnedUnit, _G.lastHerosPlaceLastDeath[spawnedUnit]))) and (_G.lastHeroKillers[spawnedUnit]:GetTeamNumber()~=DOTA_TEAM_NEUTRALS) then
		local maxToken = TROLL_FEED_NEED_TOKEN_TO_BUFF
		local currentStackTokenCouter = spawnedUnit:GetModifierStackCount(tokenTrollCouter, spawnedUnit)
		local needToken = currentStackTokenCouter + 1
		if needToken > maxToken then
			needToken = maxToken
		end
		spawnedUnit:AddNewModifier(spawnedUnit, nil, tokenTrollCouter, { duration = TROLL_FEED_TOKEN_DURATION })
		spawnedUnit:AddNewModifier(spawnedUnit, nil, "modifier_troll_feed_token", { duration = TROLL_FEED_TOKEN_DURATION })
		spawnedUnit:SetModifierStackCount(tokenTrollCouter, spawnedUnit, needToken)
	end

	-- Issuing a debuff if 3 quick deaths have accumulated and the hero has the worst KD in the team
	if spawnedUnit:GetModifierStackCount(tokenTrollCouter, spawnedUnit) == 3 and ItWorstKD(spawnedUnit) then
		spawnedUnit:RemoveModifierByName(tokenTrollCouter)
		local normalRespawnTime = spawnedUnit:GetRespawnTime()
		local addRespawnTime = normalRespawnTime * (TROLL_FEED_TOTAL_RESPAWN_TIME_MULTIPLE - 1)
		if addRespawnTime + normalRespawnTime < TROLL_FEED_MIN_RESPAWN_TIME then
			addRespawnTime = TROLL_FEED_MIN_RESPAWN_TIME - normalRespawnTime
		end
		GameRules:SendCustomMessage("#anti_feed_system_add_debuff_message", spawnedUnit:GetPlayerID(), 0)
		spawnedUnit:AddNewModifier(spawnedUnit, nil, "modifier_troll_debuff_stop_feed", { duration = TROLL_FEED_BUFF_BASIC_TIME, addRespawnTime = addRespawnTime })
	end

	local owner = spawnedUnit:GetOwner()
	local name = spawnedUnit:GetUnitName()

	if owner and owner.GetPlayerID and ( name == "npc_dota_sentry_wards" or name == "npc_dota_observer_wards" ) then
		local player_id = owner:GetPlayerID()

		newStats[player_id] = newStats[player_id] or {
			npc_dota_sentry_wards = 0,
			npc_dota_observer_wards = 0,
			tower_damage = 0,
			killed_hero = {}
		}

		newStats[player_id][name] = newStats[player_id][name] + 1
		local wardsName = {
			["npc_dota_sentry_wards"] = "item_ward_sentry",
			["npc_dota_observer_wards"] = "item_ward_observer",
		}
		Timers:CreateTimer(0.04, function()
			if HeroHasWards(owner:GetAssignedHero(), wardsName[name]) then
				ReloadTimerHoldingCheckerForPlayer(player_id)
			else
				RemoveTimerHoldingCheckerForPlayer(player_id)
			end
			return nil
		end
		)
	end

	if spawnedUnit:IsRealHero() then
		spawnedUnit:AddNewModifier(spawnedUnit, nil, "modifier_rax_bonus", {})
		-- Silencer Nerf
		local playerId = spawnedUnit:GetPlayerID()
		Timers:CreateTimer(1, function()
			if spawnedUnit:HasModifier("modifier_silencer_int_steal") then
				spawnedUnit:RemoveModifierByName('modifier_silencer_int_steal')
				spawnedUnit:AddNewModifier(spawnedUnit, nil, "modifier_silencer_new_int_steal", {})
			end
		end)

		if self.couriers[spawnedUnit:GetTeamNumber()] then
			self.couriers[spawnedUnit:GetTeamNumber()]:SetControllableByPlayer(spawnedUnit:GetPlayerID(), true)
		end

		if not spawnedUnit.firstTimeSpawned then
			spawnedUnit.firstTimeSpawned = true
			spawnedUnit:SetContextThink("HeroFirstSpawn", function()

				if spawnedUnit == PlayerResource:GetSelectedHeroEntity(playerId) then
					Patreons:GiveOnSpawnBonus(playerId)
				end
			end, 2/30)
		end

		--local psets = Patreons:GetPlayerSettings(playerId)
		if PlayerResource:GetPlayer(playerId) and not PlayerResource:GetPlayer(playerId).dummyInventory then
			CreateDummyInventoryForPlayer(playerId, spawnedUnit)
		end
		--if psets.level > 1 and _G.personalCouriers[playerId] == nil then
		--	local courier_spawn = {
		--		[2] = Entities:FindByClassname(nil, "info_courier_spawn_radiant"),
		--		[3] = Entities:FindByClassname(nil, "info_courier_spawn_dire"),
		--	}
		--	local team = spawnedUnit:GetTeamNumber()
		--	CreatePrivateCourier(playerId, spawnedUnit, courier_spawn[team]:GetAbsOrigin())
		--end
	end
end

function CreateDummyInventoryForPlayer(playerId, unit)
	if PlayerResource:GetPlayer(playerId).dummyInventory then
		PlayerResource:GetPlayer(playerId).dummyInventory:Kill(nil, nil)
	end
	local team = unit:GetTeamNumber()
	local startPointSpawn = {
		[2] = Entities:FindByClassname(nil, "info_courier_spawn_radiant"),
		[3] = Entities:FindByClassname(nil, "info_courier_spawn_dire"),
	}
	startPointSpawn = startPointSpawn[team]:GetAbsOrigin() + (RandomFloat(100, 100))
	local dInventory = CreateUnitByName("npc_dummy_inventory", startPointSpawn, true, unit, unit, team)
	dInventory:SetControllableByPlayer(playerId, true)
	dInventory:AddNewModifier(dInventory, nil, "modifier_dummy_inventory", {duration = -1})
	PlayerResource:GetPlayer(playerId).dummyInventory = dInventory
end

function CMegaDotaGameMode:ModifierGainedFilter(filterTable)

	local disableHelpResult = DisableHelp.ModifierGainedFilter(filterTable)
	if disableHelpResult == false then
		return false
	end

	local parent = filterTable.entindex_parent_const and filterTable.entindex_parent_const ~= 0 and EntIndexToHScript(filterTable.entindex_parent_const)
	local caster = filterTable.entindex_caster_const and filterTable.entindex_caster_const ~= 0 and EntIndexToHScript(filterTable.entindex_caster_const)

	if caster and parent and caster.bonusDebuffTime and (parent:GetTeamNumber() ~= caster:GetTeamNumber()) and filterTable.duration > 0 then
		filterTable.duration = filterTable.duration/100*caster.bonusDebuffTime + filterTable.duration
	end

	return true
end

function CMegaDotaGameMode:RuneSpawnFilter(kv)
	local r = RandomInt( 0, 5 )

	if r == 5 then r = 6 end

	kv.rune_type = r

	return true
end

function CMegaDotaGameMode:OnThink()
	if GameRules:State_Get() == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		-- update the scale factor:
	 	-- * SCALE_FACTOR_INITIAL at the start of the game
		-- * SCALE_FACTOR_FINAL after SCALE_FACTOR_FADEIN_SECONDS have elapsed
		local curTime = GameRules:GetDOTATime( false, false )
		local goldFracTime = math.min( math.max( curTime / GOLD_SCALE_FACTOR_FADEIN_SECONDS, 0 ), 1 )
		local xpFracTime = math.min( math.max( curTime / XP_SCALE_FACTOR_FADEIN_SECONDS, 0 ), 1 )
		self.m_CurrentGoldScaleFactor = GOLD_SCALE_FACTOR_INITIAL + (goldFracTime * ( GOLD_SCALE_FACTOR_FINAL - GOLD_SCALE_FACTOR_INITIAL ) )
		self.m_CurrentXpScaleFactor = XP_SCALE_FACTOR_INITIAL + (xpFracTime * ( XP_SCALE_FACTOR_FINAL - XP_SCALE_FACTOR_INITIAL ) )
--		print( "Gold scale = " .. self.m_CurrentGoldScaleFactor )
--		print( "XP scale = " .. self.m_CurrentXpScaleFactor )

		for i = 0, 23 do
			if PlayerResource:IsValidPlayer( i ) then
				local hero = PlayerResource:GetSelectedHeroEntity( i )
				if hero and hero:IsAlive() then
					local pos = hero:GetAbsOrigin()

					if IsInBugZone(pos) then
						-- hero:ForceKill(false)
						-- Kill this unit immediately.

						local naprv = Vector(pos[1]/math.sqrt(pos[1]*pos[1]+pos[2]*pos[2]+pos[3]*pos[3]),pos[2]/math.sqrt(pos[1]*pos[1]+pos[2]*pos[2]+pos[3]*pos[3]),0)
						pos[3] = 0
						FindClearSpaceForUnit(hero, pos-naprv*1100, false)
					end
				end
			end
		end
	end
	return 5
end


function CMegaDotaGameMode:FilterBountyRunePickup( filterTable )
--	print( "FilterBountyRunePickup" )
--  for k, v in pairs( filterTable ) do
--  	print("MG: " .. k .. " " .. tostring(v) )
--  end
	filterTable["gold_bounty"] = self.m_CurrentGoldScaleFactor * filterTable["gold_bounty"]
	filterTable["xp_bounty"] = self.m_CurrentXpScaleFactor * filterTable["xp_bounty"]
	return true
end

function CMegaDotaGameMode:FilterModifyGold( filterTable )
--	print( "FilterModifyGold" )
--	print( self.m_CurrentGoldScaleFactor )
	filterTable["gold"] = self.m_CurrentGoldScaleFactor * filterTable["gold"]
	if PlayerResource:GetTeam(filterTable.player_id_const) == ShuffleTeam.weakTeam then
		filterTable["gold"] = ShuffleTeam.multGold * filterTable["gold"]
	end
	return true
end

function CMegaDotaGameMode:FilterModifyExperience( filterTable )
--	print( "FilterModifyExperience" )
--	print( self.m_CurrentXpScaleFactor )
	filterTable["experience"] = self.m_CurrentXpScaleFactor * filterTable["experience"]
	return true
end

function CMegaDotaGameMode:OnGameRulesStateChange(keys)
	local newState = GameRules:State_Get()

	if newState ==  DOTA_GAMERULES_STATE_CUSTOM_GAME_SETUP then
		AutoTeam:Init()
		ShuffleTeam:SortInMMR()
	end
	if newState ==  DOTA_GAMERULES_STATE_HERO_SELECTION then
		AutoTeam:EnableFreePatreonForBalance()
	end
	if newState == DOTA_GAMERULES_STATE_POST_GAME then
		local couriers = FindUnitsInRadius( 2, Vector( 0, 0, 0 ), nil, FIND_UNITS_EVERYWHERE, DOTA_UNIT_TARGET_TEAM_BOTH, DOTA_UNIT_TARGET_COURIER, DOTA_UNIT_TARGET_FLAG_NONE, FIND_ANY_ORDER, false )

		for i = 0, 23 do
			if PlayerResource:IsValidPlayer( i ) then
				local networth = 0
				local hero = PlayerResource:GetSelectedHeroEntity( i )

				for _, cour in pairs( couriers ) do
					if cour:GetTeam() == cour:GetTeam() then
						for s = 0, 8 do
							local item = cour:GetItemInSlot( s )

							if item and item:GetOwner() == hero then
								networth = networth + item:GetCost()
							end
						end
					end
				end

				for s = 0, 8 do
					local item = hero:GetItemInSlot( s )

					if item then
						networth = networth + item:GetCost()
					end
				end

				networth = networth + PlayerResource:GetGold( i )

				local stats = {
					networth = networth,
					total_damage = PlayerResource:GetRawPlayerDamage( i ),
					total_healing = PlayerResource:GetHealing( i ),
				}

				if newStats and newStats[i] then
					stats.tower_damage = newStats[i].tower_damage
					stats.sentries_count = newStats[i].npc_dota_sentry_wards
					stats.observers_count = newStats[i].npc_dota_observer_wards
					stats.killed_hero = newStats[i].killed_hero
				end

				CustomNetTables:SetTableValue( "custom_stats", tostring( i ), stats )
			end
		end

		local winner
		local forts = Entities:FindAllByClassname("npc_dota_fort")
		for _, fort in ipairs(forts) do
			if fort:GetHealth() > 0 then
				local team = fort:GetTeam()
				if winner then
					winner = nil
					break
				end

				winner = team
			end
		end

		if winner then
			WebApi:AfterMatch(winner)
		end
	end

	if newState == DOTA_GAMERULES_STATE_STRATEGY_TIME then
		self:SetTeamColors()
		for i=0, DOTA_MAX_TEAM_PLAYERS do
			if PlayerResource:IsValidPlayer(i) then
				if PlayerResource:HasSelectedHero(i) == false then
					local player = PlayerResource:GetPlayer(i)
					player:MakeRandomHeroSelection()
				end
			end
		end
	end

	if newState == DOTA_GAMERULES_STATE_PRE_GAME then
		ShuffleTeam:GiveBonusToWeakTeam()
		if GameOptions:OptionsIsActive("super_towers") then
			local towers = Entities:FindAllByClassname('npc_dota_tower')
			for _, tower in pairs(towers) do
				tower:AddNewModifier(tower, nil, "modifier_super_tower", {duration = -1})
			end
		end

		local parties = {}
		local party_indicies = {}
		local party_members_count = {}
		local party_index = 1
		-- Set up player colors
		for id = 0, 23 do
			if PlayerResource:IsValidPlayer(id) then
				local party_id = tonumber(tostring(PlayerResource:GetPartyID(id)))
				if party_id and party_id > 0 then
					if not party_indicies[party_id] then
						party_indicies[party_id] = party_index
						party_index = party_index + 1
					end
					local party_index = party_indicies[party_id]
					parties[id] = party_index
					if not party_members_count[party_index] then
						party_members_count[party_index] = 0
					end
					party_members_count[party_index] = party_members_count[party_index] + 1
				end
			end
		end
		for id, party in pairs(parties) do
			 -- at least 2 ppl in party!
			if party_members_count[party] and party_members_count[party] < 2 then
				parties[id] = nil
			end
		end
		if parties then
			CustomNetTables:SetTableValue("game_state", "parties", parties)
		end
		Timers:CreateTimer(3, function()
			if not IsDedicatedServer() then
				CustomGameEventManager:Send_ServerToAllClients("is_local_server", {})
			end
			ShuffleTeam:SendNotificationForWeakTeam()
		end)
        local toAdd = {
            luna_moon_glaive_fountain = 4,
            ursa_fury_swipes_fountain = 1,
        }
		Timers:RemoveTimer("game_options_unpause")
		Convars:SetFloat("host_timescale", 1)
		Convars:SetFloat("host_timescale", 0.07)
		Timers:CreateTimer({
			useGameTime = false,
			endTime = 2.1,
			callback = function()
				Convars:SetFloat("host_timescale", 1)
				return nil
			end
		})

        local fountains = Entities:FindAllByClassname('ent_dota_fountain')
		-- Loop over all ents
        for k,fountain in pairs(fountains) do
            for skillName,skillLevel in pairs(toAdd) do
                fountain:AddAbility(skillName)
                local ab = fountain:FindAbilityByName(skillName)
                if ab then
                    ab:SetLevel(skillLevel)
                end
            end

            local item = CreateItem('item_monkey_king_bar_fountain', fountain, fountain)
            if item then
                fountain:AddItem(item)
            end

		end
		if game_start then
			local courier_spawn = {}
			courier_spawn[2] = Entities:FindByClassname(nil, "info_courier_spawn_radiant")
			courier_spawn[3] = Entities:FindByClassname(nil, "info_courier_spawn_dire")

			--for team = 2, 3 do
			--	self.couriers[team] = CreateUnitByName("npc_dota_courier", courier_spawn[team]:GetAbsOrigin(), true, nil, nil, team)
			--	if _G.mainTeamCouriers[team] == nil then
			--		_G.mainTeamCouriers[team] = self.couriers[team]
			--	end
			--	self.couriers[team]:AddNewModifier(self.couriers[team], nil, "modifier_core_courier", {})
			--end
		end
--		Timers:CreateTimer(30, function()
--			for i=0,PlayerResource:GetPlayerCount() do
--				local hero = PlayerResource:GetSelectedHeroEntity(i)
--				if hero ~= nil then
--					if hero:GetTeam() == DOTA_TEAM_GOODGUYS then
--						hero:AddItemByName("item_courier")
--						break
--					end
--				end
--			end
--			for i=0,PlayerResource:GetPlayerCount() do
--				local hero = PlayerResource:GetSelectedHeroEntity(i)
--				if hero ~= nil then
--					if hero:GetTeam() == DOTA_TEAM_BADGUYS then
--						hero:AddItemByName("item_courier")
--						break
--					end
--				end
--			end
--		end)
		StartTrackPerks()
	end

	if newState == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		Convars:SetFloat("host_timescale", 1)
		CheckTeamBalance()
		if game_start then
			game_start = false
			Timers:CreateTimer(0.1, function()
				GPM_Init()
				return nil
			end)
		end
	end
end

function SearchAndCheckRapiers(buyer, unit, plyID, maxSlots, timerKey)
	local fullRapierCost = 6000
	for i = 0, maxSlots do
		local item = unit:GetItemInSlot(i)
		if item and item:GetAbilityName() == "item_rapier" and (item:GetPurchaser() == buyer) and ((item.defend == nil) or (item.defend == false)) then
			local playerNetWorse = PlayerResource:GetNetWorth(plyID)
			if playerNetWorse < NET_WORSE_FOR_RAPIER_MIN then
				CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(plyID), "display_custom_error", { message = "#rapier_small_networth" })
				UTIL_Remove(item)
				buyer:ModifyGold(fullRapierCost, false, 0)
				Timers:CreateTimer(0.03, function()
					Timers:RemoveTimer(timerKey)
				end)
			else
				if GetHeroKD(buyer) > 0 then
					Timers:CreateTimer(0.03, function()
						item.defend = true
						Timers:RemoveTimer(timerKey)
					end)
				elseif (GetHeroKD(buyer) <= 0) then
					CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(plyID), "display_custom_error", { message = "#rapier_littleKD" })
					UTIL_Remove(item)
					buyer:ModifyGold(fullRapierCost, false, 0)
					Timers:CreateTimer(0.03, function()
						Timers:RemoveTimer(timerKey)
					end)
				end
			end
		end
	end
end

function CMegaDotaGameMode:ItemAddedToInventoryFilter( filterTable )
	if filterTable["item_entindex_const"] == nil then
		return true
	end
 	if filterTable["inventory_parent_entindex_const"] == nil then
		return true
	end
	local hInventoryParent = EntIndexToHScript( filterTable["inventory_parent_entindex_const"] )
	local hItem = EntIndexToHScript( filterTable["item_entindex_const"] )
	if hItem ~= nil and hInventoryParent ~= nil then
		local itemName = hItem:GetName()

		if itemName == "item_banhammer" and GameOptions:OptionsIsActive("no_trolls_kick") then
			local playerId = hItem:GetPurchaser():GetPlayerID()
			if playerId then
				CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(playerId), "display_custom_error", { message = "#you_cannot_buy_it" })
			end
			UTIL_Remove(hItem)
			return false
		end

		if hInventoryParent:IsRealHero() then
			local plyID = hInventoryParent:GetPlayerID()
			if not plyID then return true end
			local pitems = {
			--	"item_patreon_1",
			--	"item_patreon_2",
			--	"item_patreon_3",
			--	"item_patreon_4",
			--	"item_patreon_5",
			--	"item_patreon_6",
			--	"item_patreon_7",
			--	"item_patreon_8",
				"item_patreonbundle_1",
				"item_patreonbundle_2"
			}
			if itemName == "item_patreon_courier" then
				BlockToBuyCourier(plyID, hItem)
				return false
			end

			local pitem = false
			for i=1,#pitems do
				if itemName == pitems[i] then
					pitem = true
					break
				end
			end
			if pitem == true then
				local psets = Patreons:GetPlayerSettings(plyID)
				if psets.level < 1 then
					CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(plyID), "display_custom_error", { message = "#nopatreonerror" })
					UTIL_Remove(hItem)
					return false
				end
			end

			if itemName == "item_banhammer" then
				if GameRules:GetDOTATime(false,false) < 300 then
					CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(plyID), "display_custom_error", { message = "#notyettime" })
					UTIL_Remove(hItem)
					return false
				end
			end
		else
			local pitems = {
				"item_patreonbundle_1",
				"item_patreonbundle_2",
			}
			for i=1,#pitems do
				if itemName == pitems[i] then
					local prsh = hItem:GetPurchaser()
					if prsh ~= nil then
						if prsh:IsRealHero() then
							local prshID = prsh:GetPlayerID()

							if itemName == "item_patreon_courier" then
								BlockToBuyCourier(prshID, hItem)
								return false
							end

							if not prshID then
								UTIL_Remove(hItem)
								return false
							end
							local psets = Patreons:GetPlayerSettings(prshID)
							if not psets then
								UTIL_Remove(hItem)
								return false
							end
							if itemName == "item_banhammer" then
								if GameRules:GetDOTATime(false,false) < 300 then
									CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(prshID), "display_custom_error", { message = "#notyettime" })
									UTIL_Remove(hItem)
									return false
								end
							else
								if psets.level < 1 then
									CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(prshID), "display_custom_error", { message = "#nopatreonerror" })
									UTIL_Remove(hItem)
									return false
								end
							end
						else
							UTIL_Remove(hItem)
							return false
						end
					else
						UTIL_Remove(hItem)
						return false
					end
				end
			end
		end

		if  hItem:GetPurchaser() and (itemName == "item_relic")then
			local buyer = hItem:GetPurchaser()
			local plyID = buyer:GetPlayerID()
			local itemEntIndex = hItem:GetEntityIndex()
			local timerKey = "seacrh_rapier_on_player"..itemEntIndex
			Timers:CreateTimer(timerKey, {
				useGameTime = false,
				endTime = 0.4,
				callback = function()
					SearchAndCheckRapiers(buyer, buyer, plyID, 20, timerKey)
					--SearchAndCheckRapiers(buyer, SearchCorrectCourier(plyID, buyer:GetTeamNumber()), plyID, 10,timerKey)
					return 0.45
				end
			})
		end

		local purchaser = hItem:GetPurchaser()
		local itemCost = hItem:GetCost()

		if purchaser then
			local prshID = purchaser:GetPlayerID()
			local psets = Patreons:GetPlayerSettings(prshID)
			local correctInventory = hInventoryParent:IsRealHero() or (hInventoryParent:GetClassname() == "npc_dota_lone_druid_bear") or hInventoryParent:IsCourier()

			if (filterTable["item_parent_entindex_const"] > 0) and correctInventory and (ItemIsFastBuying(hItem:GetName()) or psets.level > 0) then
				if hItem:TransferToBuyer(hInventoryParent) == false then
					return false
				end
				local unique_key_cd = itemName .. "_" .. purchaser:GetEntityIndex()
				if _G.lastTimeBuyItemWithCooldown[unique_key_cd] and (_G.itemsCooldownForPlayer[itemName] and (GameRules:GetGameTime() - _G.lastTimeBuyItemWithCooldown[unique_key_cd]) < _G.itemsCooldownForPlayer[itemName]) then
					local checkMaxCount = CheckMaxItemCount(hItem, unique_key_cd, prshID, false)
					if checkMaxCount then
						MessageToPlayerItemCooldown(itemName, prshID)
					end
					Timers:CreateTimer(0.08, function()
						UTIL_Remove(hItem)
					end)
					return false
				end
			end

			if (filterTable["item_parent_entindex_const"] > 0) and hItem and correctInventory and (not purchaser:CheckPersonalCooldown(hItem)) then
				purchaser:ModifyGold(itemCost, false, 0)
				UTIL_Remove(hItem)
				return false
			end
		end
	end

	if _G.neutralItems[hItem:GetAbilityName()] and hItem.new == nil then
		hItem.new = true
		local inventoryIsCorrect = hInventoryParent:IsRealHero() or (hInventoryParent:GetClassname() == "npc_dota_lone_druid_bear") or hInventoryParent:IsCourier()
		if inventoryIsCorrect then
			local playerId = hInventoryParent:GetPlayerOwnerID() or hInventoryParent:GetPlayerID()
			CustomGameEventManager:Send_ServerToPlayer( PlayerResource:GetPlayer( playerId ), "neutral_item_picked_up", { item = filterTable.item_entindex_const })
			return false
		end
	end

	if hItem and hItem.neutralDropInBase then
		hItem.neutralDropInBase = false
		local inventoryIsCorrect = hInventoryParent:IsRealHero() or (hInventoryParent:GetClassname() == "npc_dota_lone_druid_bear") or hInventoryParent:IsCourier()
		local playerId = inventoryIsCorrect and hInventoryParent:GetPlayerOwnerID()
		if playerId then
			NotificationToAllPlayerOnTeam({
				PlayerID = playerId,
				item = filterTable.item_entindex_const,
			})
		end
	end

	return true
end

function CMegaDotaGameMode:OnConnectFull(data)
	_G.tUserIds[data.PlayerID] = data.userid
	if _G.kicks and _G.kicks[data.PlayerID] then
		SendToServerConsole('kickid '.. data.userid);
	end
	CustomGameEventManager:Send_ServerToAllClients( "change_leave_status", {leave = false, playerId = data.PlayerID} )
	CheckTeamBalance()
end

function CMegaDotaGameMode:OnPlayerDisconnect(data)
	CustomGameEventManager:Send_ServerToAllClients( "change_leave_status", {leave = true, playerId = data.PlayerID} )
	Timers:CreateTimer(1, function()
		CheckTeamBalance()
	end)
	Timers:CreateTimer(310, function()
		CheckTeamBalance()
	end)
end

function GetBlockItemByID(id)
	for k,v in pairs(_G.ItemKVs) do
		if tonumber(v["ID"]) == id then
			v["name"] = k
			return v
		end
	end
end

function CMegaDotaGameMode:ExecuteOrderFilter(filterTable)
	local orderType = filterTable.order_type
	local playerId = filterTable.issuer_player_id_const
	local target = filterTable.entindex_target ~= 0 and EntIndexToHScript(filterTable.entindex_target) or nil
	local ability = filterTable.entindex_ability ~= 0 and EntIndexToHScript(filterTable.entindex_ability) or nil
	local orderVector = Vector(filterTable.position_x, filterTable.position_y, 0)
	-- `entindex_ability` is item id in some orders without entity
	if ability and not ability.GetAbilityName then ability = nil end
	local abilityName = ability and ability:GetAbilityName() or nil
	local unit
	-- TODO: Are there orders without a unit?
	if filterTable.units and filterTable.units["0"] then
		unit = EntIndexToHScript(filterTable.units["0"])
	end

	if orderType == DOTA_UNIT_ORDER_CAST_TARGET then
		if target:GetName() == "npc_dota_seasonal_ti9_drums" then
			CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(playerId), "display_custom_error", { message = "#dota_hud_error_cant_cast_on_other" })
			return
		end
	end

	local itemsToBeDestroy = {
		["item_disable_help_custom"] = true,
		["item_mute_custom"] = true,
	}
	if orderType == DOTA_UNIT_ORDER_PURCHASE_ITEM then
		local entIndexAbility = filterTable["entindex_ability"]
		if ItemIsWard(entIndexAbility) then
			if _G.playerIsBlockForWards[playerId] then
				CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(playerId), "display_custom_error", { message = "#you_cannot_buy_it" })
				return false
			elseif not _G.playerHasTimerWards[playerId] then
				StartTimerHoldingCheckerForPlayer(playerId)
			end
		end
	end

	if orderType == DOTA_UNIT_ORDER_DROP_ITEM or orderType == DOTA_UNIT_ORDER_EJECT_ITEM_FROM_STASH then
		if ability:GetAbilityName() == "item_relic" then
			CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(playerId), "display_custom_error", { message = "#cannotpullit" })
			return false
		end
	end

	if  orderType == DOTA_UNIT_ORDER_SELL_ITEM  then
		if ability:GetAbilityName() == "item_relic" then
			Timers:RemoveTimer("seacrh_rapier_on_player"..filterTable.entindex_ability)
		end
	end

	if orderType == DOTA_UNIT_ORDER_GIVE_ITEM then
		if target:GetClassname() == "ent_dota_shop" and ability:GetAbilityName() == "item_relic" then
			Timers:RemoveTimer("seacrh_rapier_on_player"..ability:GetEntityIndex())
		end

		if _G.neutralItems[ability:GetAbilityName()] then
			local targetID = target:GetPlayerOwnerID()
			if targetID and targetID~=playerId then
				if CheckCountOfNeutralItemsForPlayer(targetID) >= _G.MAX_NEUTRAL_ITEMS_FOR_PLAYER then
					DisplayError(playerId, "#unit_still_have_a_lot_of_neutral_items")
					return
				end
			end
		end
	end

	if orderType == DOTA_UNIT_ORDER_PICKUP_ITEM then
		if not target then return true end
		local pickedItem = target:GetContainedItem()
		if not pickedItem then return true end
		local itemName = pickedItem:GetAbilityName()

		if _G.wardsList[itemName] then
			if _G.playerIsBlockForWards[playerId] then
				CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(playerId), "display_custom_error", { message = "#cannotpickupit" })
				return false
			elseif not _G.playerHasTimerWards[playerId] then
				StartTimerHoldingCheckerForPlayer(playerId)
			end
		end
		if _G.neutralItems[itemName] then
			if CheckCountOfNeutralItemsForPlayer(playerId) >= _G.MAX_NEUTRAL_ITEMS_FOR_PLAYER then
				DisplayError(playerId, "#player_still_have_a_lot_of_neutral_items")
				return
			end
		end
	end

	if orderType == 38 then
		if _G.neutralItems[ability:GetAbilityName()] then
			if CheckCountOfNeutralItemsForPlayer(playerId) >= _G.MAX_NEUTRAL_ITEMS_FOR_PLAYER then
				DisplayError(playerId, "#player_still_have_a_lot_of_neutral_items")
				return
			end
		end
	end

	if orderType == DOTA_UNIT_ORDER_DROP_ITEM or orderType == DOTA_UNIT_ORDER_EJECT_ITEM_FROM_STASH then
		if ability and itemsToBeDestroy[ability:GetAbilityName()] then
			ability:Destroy()
		end
	end

	if orderType == 25 then
		if ability and itemsToBeDestroy[ability:GetAbilityName()] then
			ability:Destroy()
		end
	end

	local disableHelpResult = DisableHelp.ExecuteOrderFilter(orderType, ability, target, unit, orderVector)
	if disableHelpResult == false then
		return false
	end

	--if filterTable then
	--	filterTable = EditFilterToCourier(filterTable)
	--end

	if orderType == DOTA_UNIT_ORDER_CAST_POSITION then
		if abilityName == "item_ward_dispenser" or abilityName == "item_ward_sentry" or abilityName == "item_ward_observer" then
			local list = Entities:FindAllByClassname("trigger_multiple")
			local fs = {
				Vector(5000,6912,0),
				Vector(-5300,-6938,0)
			}
			if PlayerResource:GetTeam(playerId) == 2 then
				fs = {fs[2],fs[1]}
			end
			for i=1,#list do
				if list[i]:GetName():find("neutralcamp") ~= nil then
					if IsInTriggerBox(list[i], 12, orderVector) and ( fs[1] - orderVector ):Length2D() < ( fs[2] - orderVector ):Length2D() then
						CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(playerId), "display_custom_error", { message = "#block_spawn_error" })
						return false
					end
				end
			end
		end
	end

	if unit then
		if unit:IsCourier() then
			if (orderType == DOTA_UNIT_ORDER_DROP_ITEM or orderType == DOTA_UNIT_ORDER_GIVE_ITEM) and ability and ability:IsItem() then
				local purchaser = ability:GetPurchaser()
				if purchaser and purchaser:GetPlayerID() ~= playerId then
					if purchaser:GetTeam() == PlayerResource:GetPlayer(playerId):GetTeam() then
						--CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(playerId), "display_custom_error", { message = "#hud_error_courier_cant_order_item" })
						return false
					end
				end
			end
		end
	end

	return true
end

local blockedChatPhraseCode = {
	[796] = true,
}

function CMegaDotaGameMode:OnPlayerChat(keys)
	local text = keys.text
	local playerid = keys.playerid
	if string.sub(text, 0,4) == "-ch " then
		local data = {}
		data.num = tonumber(string.sub(text, 5))
		if not blockedChatPhraseCode[data.num] then
			data.PlayerID = playerid
			SelectVO(data)
		end
	end
end

msgtimer = {}
RegisterCustomEventListener("OnTimerClick", function(keys)
	if msgtimer[keys.PlayerID] and GameRules:GetGameTime() - msgtimer[keys.PlayerID] < 3 then
		return
	end
	msgtimer[keys.PlayerID] = GameRules:GetGameTime()

	local time = math.abs(math.floor(GameRules:GetDOTATime(false, true)))
	local min = math.floor(time / 60)
	local sec = time - min * 60
	if min < 10 then min = "0" .. min end
	if sec < 10 then sec = "0" .. sec end
	Say(PlayerResource:GetPlayer(keys.PlayerID), min .. ":" .. sec, true)
end)

votimer = {}
vousedcol = {}
SelectVO = function(keys)
	local psets = Patreons:GetPlayerSettings(keys.PlayerID)
	print(keys.num)
	local heroes = {
		"abaddon",
		"alchemist",
		"ancient_apparition",
		"antimage",
		"arc_warden",
		"axe",
		"bane",
		"batrider",
		"beastmaster",
		"bloodseeker",
		"bounty_hunter",
		"brewmaster",
		"bristleback",
		"broodmother",
		"centaur",
		"chaos_knight",
		"chen",
		"clinkz",
		"rattletrap",
		"crystal_maiden",
		"dark_seer",
		"dark_willow",
		"dazzle",
		"death_prophet",
		"disruptor",
		"doom_bringer",
		"dragon_knight",
		"drow_ranger",
		"earth_spirit",
		"earthshaker",
		"elder_titan",
		"ember_spirit",
		"enchantress",
		"enigma",
		"faceless_void",
		"grimstroke",
		"gyrocopter",
		"huskar",
		"invoker",
		"wisp",
		"jakiro",
		"juggernaut",
		"keeper_of_the_light",
		"kunkka",
		"legion_commander",
		"leshrac",
		"lich",
		"life_stealer",
		"lina",
		"lion",
		"lone_druid",
		"luna",
		"lycan",
		"magnataur",
		"mars",
		"medusa",
		"meepo",
		"mirana",
		"monkey_king",
		"morphling",
		"naga_siren",
		"furion",
		"necrolyte",
		"night_stalker",
		"nyx_assassin",
		"ogre_magi",
		"omniknight",
		"oracle",
		"obsidian_destroyer",
		"pangolier",
		"phantom_assassin",
		"phantom_lancer",
		"phoenix",
		"puck",
		"pudge",
		"pugna",
		"queenofpain",
		"razor",
		"riki",
		"rubick",
		"sand_king",
		"shadow_demon",
		"nevermore",
		"shadow_shaman",
		"silencer",
		"skywrath_mage",
		"slardar",
		"slark",
		"snapfire",
		"sniper",
		"spectre",
		"spirit_breaker",
		"storm_spirit",
		"sven",
		"techies",
		"templar_assassin",
		"terrorblade",
		"tidehunter",
		"shredder",
		"tinker",
		"tiny",
		"treant",
		"troll_warlord",
		"tusk",
		"abyssal_underlord",
		"undying",
		"ursa",
		"vengefulspirit",
		"venomancer" ,
		"viper",
		"visage",
		"void_spirit",
		"warlock",
		"weaver",
		"windrunner",
		"winter_wyvern",
		"witch_doctor",
		"skeleton_king",
		"zuus"
	}
	local selectedid = 1
	local selectedid2 = nil
	local selectedstr = nil
	local startheronums = 110
	if keys.num >= startheronums then
		local locnum = keys.num - startheronums
		local mesarrs = {
			"_laugh",
			"_thank",
			"_deny",
			"_1",
			"_2",
			"_3",
			"_4",
			"_5"
		}
		selectedstr = heroes[math.floor(locnum/8)+1]..mesarrs[math.fmod(locnum,8)+1]
		print(math.floor(locnum/8))
		print(selectedstr)
		selectedid = math.floor(locnum/8)+2
		selectedid2 = math.fmod(locnum,8)+1
	else
		if keys.num < (startheronums-8) then
			local mesarrs = {
				--dp1
				"Applause",
				"Crash_and_Burn",
				"Crickets",
				"Party_Horn",
				"Rimshot",
				"Charge",
				"Drum_Roll",
				"Frog",
				--dp2
				"Headshake",
				"Kiss",
				"Ow",
				"Snore",
				"Bockbock",
				"Crybaby",
				"Sad_Trombone",
				"Yahoo",
				--misc
				"",
				"Sleighbells",
				"Sparkling_Celebration",
				"Greevil_Laughter",
				"Frostivus_Magic",
				"Ceremonial_Drums",
				"Oink_Oink",
				"Celebratory_Gong",
				--en an
				"patience",
				"wow",
				"all_dead",
				"brutal",
				"disastah",
				"oh_my_lord",
				"youre_a_hero",
				--en an2
				"that_was_questionable",
				"playing_to_win",
				"what_just_happened",
				"looking_spicy",
				"no_chill",
				"ding_ding_ding",
				"absolutely_perfect",
				"lets_play",
				--ch an
				"duiyou_ne",
				"wan_bu_liao_la",
				"po_liang_lu",
				"tian_huo",
				"jia_you",
				"zou_hao_bu_song",
				"liu_liu_liu",
				--ch an2
				"hu_lu_wa",
				"ni_qi_bu_qi",
				"gao_fu_shuai",
				"gan_ma_ne_xiong_di",
				"bai_tuo_shei_qu",
				"piao_liang",
				"lian_dou_xiu_wai_la",
				"zai_jian_le_bao_bei",
				--ru an
				"bozhe_ti_posmotri",
				"zhil_do_konsta",
				"ay_ay_ay",
				"ehto_g_g",
				"eto_prosto_netchto",
				"krasavchik",
				"bozhe_kak_eto_bolno",
				--ru an2
				"oy_oy_bezhat",
				"eto_nenormalno",
				"eto_sochno",
				"kreasa_kreasa",
				"kak_boyge_te_byechenya",
				"eto_ge_popayx_feeda",
				"da_da_da_nyet",
				"wot_eto_bru",
				--bp19
				"kooka_laugh",
				"monkey_biz",
				"orangutan_kiss",
				"skeeter",
				"crowd_groan",
				"head_bonk",
				"record_scratch",
				"ta_da",
				--epic
				"easiest_money",
				"echo_slama_jama",
				"next_level",
				"oy_oy_oy",
				"ta_daaaa",
				"ceeb",
				"goodness_gracious",
				--epic2
				"nakupuuu",
				"whats_cooking",
				"eughahaha",
				"glados_chat_21",
				"glados_chat_01",
				"glados_chat_07",
				"glados_chat_04",
				"",
				--kor cas
				"kor_yes_no",
				"kor_scan",
				"kor_immortality",
				"kor_roshan",
				"kor_yolo",
				"kor_million_dollar_house",
				"",
				"",
			}
			selectedstr = mesarrs[keys.num]
			selectedid2 = keys.num
		else
			local locnum = keys.num - (startheronums-8)
			local nowheroname = string.sub(PlayerResource:GetSelectedHeroEntity(keys.PlayerID):GetName(), 15)
			local mesarrs = {
				"_laugh",
				"_thank",
				"_deny",
				"_1",
				"_2",
				"_3",
				"_4",
				"_5"
			}
			local herolocid = 2
			for i=1, #heroes do
				if nowheroname == heroes[i] then
					break
				end
				herolocid = herolocid + 1
			end
			selectedstr = nowheroname..mesarrs[locnum+1]
			selectedid = herolocid
			print(selectedid)
			selectedid2 = locnum+1
		end
	end
	if selectedstr ~= nil and selectedid2 ~= nil then
		local heroesvo = {
			{
				--dp1
				"soundboard.applause",
				"soundboard.crash",
				"soundboard.cricket",
				"soundboard.party_horn",
				"soundboard.rimshot",
				"soundboard.charge",
				"soundboard.drum_roll",
				"soundboard.frog",
				--dp2
				"soundboard.headshake",
				"soundboard.kiss",
				"soundboard.ow",
				"soundboard.snore",
				"soundboard.bockbock",
				"soundboard.crybaby",
				"soundboard.sad_bone",
				"soundboard.yahoo",
				--misc
				"",
				"soundboard.sleighbells",
				"soundboard.new_year_celebration",
				"soundboard.greevil_laughs",
				"soundboard.frostivus_magic",
				"soundboard.new_year_drums",
				"soundboard.new_year_pig",
				"soundboard.new_year_gong",
				--en an
				"soundboard.patience",
				"soundboard.wow",
				"soundboard.all_dead",
				"soundboard.brutal",
				"soundboard.disastah",
				"soundboard.oh_my_lord",
				"soundboard.youre_a_hero",
				--en an2
				"soundboard.that_was_questionable",
				"soundboard.playing_to_win",
				"soundboard.what_just_happened",
				"soundboard.looking_spicy",
				"soundboard.no_chill",
				"custom_soundboard.ding_ding_ding",
				"soundboard.absolutely_perfect",
				"custom_soundboard.lets_play",
				--ch an
				"soundboard.duiyou_ne",
				"soundboard.wan_bu_liao_la",
				"soundboard.po_liang_lu",
				"soundboard.tian_huo",
				"soundboard.jia_you",
				"soundboard.zou_hao_bu_song",
				"soundboard.liu_liu_liu",
				--ch an2
				"soundboard.hu_lu_wa",
				"soundboard.ni_qi_bu_qi",
				"soundboard.gao_fu_shuai",
				"soundboard.gan_ma_ne_xiong_di",
				"soundboard.bai_tuo_shei_qu",
				"soundboard.piao_liang",
				"soundboard.lian_dou_xiu_wai_la",
				"soundboard.zai_jian_le_bao_bei",
				--ru an
				"soundboard.bozhe_ti_posmotri",
				"soundboard.zhil_do_konsta",
				"soundboard.ay_ay_ay",
				"soundboard.ehto_g_g",
				"soundboard.eto_prosto_netchto",
				"soundboard.krasavchik",
				"soundboard.bozhe_kak_eto_bolno",
				--ru an2
				"soundboard.oy_oy_bezhat",
				"soundboard.eto_nenormalno",
				"soundboard.eto_sochno",
				"soundboard.kreasa_kreasa",
				"soundboard.kak_boyge_te_byechenya",
				"soundboard.eto_ge_popayx_feeda",
				"soundboard.da_da_da_nyet",
				"soundboard.wot_eto_bru",
				--bp19
				"custom_soundboard.ti9_kooka_laugh",
				"custom_soundboard.ti9_monkey_biz",
				"custom_soundboard.ti9_orangutan_kiss",
				"custom_soundboard.ti9_skeeter",
				"custom_soundboard.ti9_crowd_groan",
				"custom_soundboard.ti9_head_bonk",
				"custom_soundboard.ti9_record_scratch",
				"custom_soundboard.ti9_ta_da",
				--epic
				"soundboard.easiest_money",
				"soundboard.echo_slama_jama",
				"soundboard.next_level",
				"soundboard.oy_oy_oy",
				"soundboard.ta_daaaa",
				"soundboard.ceb.start",--need fix
				"soundboard.goodness_gracious",
				--epic2
				"soundboard.nakupuuu",
				"soundboard.whats_cooking",
				"soundboard.eughahaha",
				"custom_soundboard.glados_chat_01",
				"custom_soundboard.glados_chat_21",
				"custom_soundboard.glados_chat_04",
				"custom_soundboard.glados_chat_07",
				"",
				--kor cas
				"custom_soundboard.kor_yes_no",
				"custom_soundboard.kor_scan",
				"custom_soundboard.kor_immortality",
				"custom_soundboard.kor_roshan",
				"custom_soundboard.kor_yolo",
				"custom_soundboard.kor_million_dollar_house",
				"",
				"",
			},
			{
				"abaddon_abad_laugh_03",
				"abaddon_abad_failure_01",
				"abaddon_abad_deny_06",
				"abaddon_abad_lasthit_06",
				"abaddon_abad_death_03",
				"abaddon_abad_kill_05",
				"abaddon_abad_cast_01",
				"abaddon_abad_begin_02",
			},
			{
				"alchemist_alch_laugh_07",
				"alchemist_alch_win_03",
				"alchemist_alch_kill_02",
				"alchemist_alch_ability_rage_25",
				"alchemist_alch_kill_08",
				"alchemist_alch_ability_rage_14",
				"alchemist_alch_ability_failure_02",
				"alchemist_alch_respawn_06",
			},
			{
				"ancient_apparition_appa_laugh_01",
				"ancient_apparition_appa_lasthit_04",
				"ancient_apparition_appa_spawn_03",
				"ancient_apparition_appa_kill_03",
				"ancient_apparition_appa_death_13",
				"ancient_apparition_appa_purch_02",
				"ancient_apparition_appa_battlebegins_01",
				"ancient_apparition_appa_attack_05",
			},
			{
				"antimage_anti_laugh_05",
				"antimage_anti_respawn_09",
				"antimage_anti_deny_12",
				"antimage_anti_magicuser_01",
				"antimage_anti_ability_failure_02",
				"antimage_anti_kill_08",
				"antimage_anti_kill_13",
				"antimage_anti_rare_02",
			},
			{
				"arc_warden_arcwar_laugh_06",
				"arc_warden_arcwar_thanks_02",
				"arc_warden_arcwar_deny_10",
				"arc_warden_arcwar_flux_08",
				"arc_warden_arcwar_death_02",
				"arc_warden_arcwar_tempest_double_killed_04",
				"arc_warden_arcwar_failure_03",
				"arc_warden_arcwar_rival_05",
			},
			{
				"axe_axe_laugh_03",
				"axe_axe_drop_medium_01",
				"axe_axe_deny_08",
				"axe_axe_kill_06",
				"axe_axe_deny_16",
				"axe_axe_ability_failure_01",
				"axe_axe_rival_01",
				"axe_axe_rival_22",
				},
				{
				"bane_bane_battlebegins_01",
				"bane_bane_thanks_02",
				"bane_bane_ability_enfeeble_05",
				"bane_bane_spawn_02",
				"bane_bane_purch_04",
				"bane_bane_lasthit_11",
				"bane_bane_kill_13",
				"bane_bane_level_06",
				},
				{
				"batrider_bat_laugh_02",
				"batrider_bat_kill_10",
				"batrider_bat_cast_01",
				"batrider_bat_win_03",
				"batrider_bat_battlebegins_02",
				"batrider_bat_ability_napalm_06",
				"batrider_bat_kill_04",
				"batrider_bat_ability_failure_03",
				},
				{
				"beastmaster_beas_laugh_09",
				"beastmaster_beas_ability_summonsboar_04",
				"beastmaster_beas_rare_01",
				"beastmaster_beas_kill_07",
				"beastmaster_beas_immort_02",
				"beastmaster_beas_ability_animalsound_02",
				"beastmaster_beas_buysnecro_07",
				"beastmaster_beas_ability_animalsound_01",
				},
				{
				"bloodseeker_blod_laugh_02",
				"bloodseeker_blod_kill_10",
				"bloodseeker_blod_deny_09",
				"bloodseeker_blod_drop_rare_01",
				"bloodseeker_blod_respawn_10",
				"bloodseeker_blod_ability_rupture_02",
				"bloodseeker_blod_ability_rupture_04",
				"bloodseeker_blod_begin_01",
				},
				{
				"bounty_hunter_bount_laugh_07",
				"bounty_hunter_bount_ability_track_kill_02",
				"bounty_hunter_bount_rival_15",
				"bounty_hunter_bount_kill_14",
				"bounty_hunter_bount_bottle_01",
				"bounty_hunter_bount_ability_wind_attack_04",
				"bounty_hunter_bount_ability_track_02",
				"bounty_hunter_bount_level_09",
				},
				{
				"brewmaster_brew_laugh_07",
				"brewmaster_brew_ability_primalsplit_11",
				"brewmaster_brew_ability_failure_03",
				"brewmaster_brew_level_07",
				"brewmaster_brew_level_08",
				"brewmaster_brew_kill_03",
				"brewmaster_brew_respawn_01",
				"brewmaster_brew_spawn_05",
				},
				{
				"bristleback_bristle_laugh_02",
				"bristleback_bristle_levelup_04",
				"bristleback_bristle_rival_31",
				"bristleback_bristle_happy_04",
				"bristleback_bristle_deny_08",
				"bristleback_bristle_attack_22",
				"bristleback_bristle_kill_03",
				"bristleback_bristle_spawn_03",
				},
				{
				"broodmother_broo_laugh_06",
				"broodmother_broo_ability_spawn_05",
				"broodmother_broo_invis_02",
				"broodmother_broo_kill_16",
				"broodmother_broo_kill_01",
				"broodmother_broo_ability_spawn_10",
				"broodmother_broo_ability_spawn_06",
				"broodmother_broo_kill_17",
				},
				{
				"centaur_cent_laugh_04",
				"centaur_cent_thanks_02",
				"centaur_cent_hoof_stomp_03",
				"centaur_cent_happy_02",
				"centaur_cent_failure_03",
				"centaur_cent_rival_21",
				"centaur_cent_doub_edge_05",
				"centaur_cent_levelup_06",
				},
				{
				"chaos_knight_chaknight_laugh_15",
				"chaos_knight_chaknight_levelup_04",
				"chaos_knight_chaknight_rival_10",
				"chaos_knight_chaknight_kill_10",
				"chaos_knight_chaknight_ally_04",
				"chaos_knight_chaknight_ability_phantasm_03",
				"chaos_knight_chaknight_purch_02",
				"chaos_knight_chaknight_battlebegins_01",
				},
				{
				"chen_chen_laugh_09",
				"chen_chen_thanks_02",
				"chen_chen_cast_04",
				"chen_chen_kill_04",
				"chen_chen_death_04",
				"chen_chen_bottle_02",
				"chen_chen_battlebegins_01",
				"chen_chen_respawn_06",
				},
				{
				"clinkz_clinkz_laugh_02",
				"clinkz_clinkz_thanks_04",
				"clinkz_clinkz_deny_07",
				"clinkz_clinkz_kill_06",
				"clinkz_clinkz_rival_01",
				"clinkz_clinkz_rival_07",
				"clinkz_clinkz_win_01",
				"clinkz_clinkz_kill_02",
				},
				{
				"rattletrap_ratt_kill_14",
				"rattletrap_ratt_level_13",
				"rattletrap_ratt_deny_09",
				"rattletrap_ratt_ability_flare_12",
				"rattletrap_ratt_ability_batt_14",
				"rattletrap_ratt_ability_batt_09",
				"rattletrap_ratt_respawn_18",
				"rattletrap_ratt_win_05",
				},
				{
				"crystalmaiden_cm_laugh_06",
				"crystalmaiden_cm_thanks_02",
				"crystalmaiden_cm_deny_02",
				"crystalmaiden_cm_kill_09",
				"crystalmaiden_cm_levelup_04",
				"crystalmaiden_cm_respawn_05",
				"crystalmaiden_cm_respawn_06",
				"crystalmaiden_cm_levelup_03",
				},
				{
				"dark_seer_dkseer_laugh_10",
				"dark_seer_dkseer_move_03",
				"dark_seer_dkseer_deny_06",
				"dark_seer_dkseer_kill_01",
				"dark_seer_dkseer_firstblood_02",
				"dark_seer_dkseer_happy_02",
				"dark_seer_dkseer_ability_wallr_05",
				"dark_seer_dkseer_rare_02",
				},
				{
				"dark_willow_sylph_wheel_laugh_01",
				"dark_willow_sylph_drop_rare_02",
				"dark_willow_sylph_respawn_01",
				"dark_willow_sylph_wheel_deny_02",
				"dark_willow_sylph_kill_06",
				"dark_willow_sylph_wheel_all_05",
				"dark_willow_sylph_wheel_all_02",
				"dark_willow_sylph_wheel_all_10",
				},
				{
				"dazzle_dazz_laugh_02",
				"dazzle_dazz_purch_03",
				"dazzle_dazz_deny_08",
				"dazzle_dazz_kill_05",
				"dazzle_dazz_lasthit_08",
				"dazzle_dazz_ability_shadowave_02",
				"dazzle_dazz_kill_10",
				"dazzle_dazz_respawn_09",
				},
				{
				"death_prophet_dpro_laugh_012",
				"death_prophet_dpro_denyghost_04",
				"death_prophet_dpro_deny_16",
				"death_prophet_dpro_kill_11",
				"death_prophet_dpro_fail_05",
				"death_prophet_dpro_exorcism_15",
				"death_prophet_dpro_kill_18",
				"death_prophet_dpro_levelup_10",
				},
				{
				"disruptor_dis_laugh_03",
				"disruptor_dis_purch_02",
				"disruptor_dis_staticstorm_06",
				"disruptor_dis_respawn_10",
				"disruptor_dis_kill_10",
				"disruptor_dis_underattack_02",
				"disruptor_dis_rare_02",
				"disruptor_dis_illus_02",
				},
				{
				"doom_bringer_doom_laugh_10",
				"doom_bringer_doom_happy_01",
				"doom_bringer_doom_ability_lvldeath_03",
				"doom_bringer_doom_level_05",
				"doom_bringer_doom_respawn_12",
				"doom_bringer_doom_lose_04",
				"doom_bringer_doom_ability_fail_02",
				"doom_bringer_doom_respawn_08",
				},
				{
				"dragon_knight_drag_laugh_07",
				"dragon_knight_drag_level_05",
				"dragon_knight_drag_purch_01",
				"dragon_knight_drag_kill_11",
				"dragon_knight_drag_lasthit_09",
				"dragon_knight_drag_kill_01",
				"dragon_knight_drag_move_05",
				"dragon_knight_drag_ability_eldrag_06",
				},
				{
				"drowranger_dro_laugh_04",
				"drowranger_dro_win_04",
				"drowranger_dro_deny_02",
				"drowranger_drow_kill_13",
				"drowranger_drow_rival_13",
				"drowranger_dro_kill_05",
				"drowranger_dro_win_03",
				"drowranger_drow_kill_17",
				},
				{
				"earth_spirit_earthspi_laugh_06",
				"earth_spirit_earthspi_thanks_04",
				"earth_spirit_earthspi_deny_05",
				"earth_spirit_earthspi_rollingboulder_20",
				"earth_spirit_earthspi_invis_03",
				"earth_spirit_earthspi_lasthit_10",
				"earth_spirit_earthspi_failure_06",
				"earth_spirit_earthspi_illus_02",
				},
				{
				"earthshaker_erth_laugh_03",
				"earthshaker_erth_move_06",
				"earthshaker_erth_death_09",
				"earthshaker_erth_kill_08",
				"earthshaker_erth_respawn_06",
				"earthshaker_erth_ability_echo_06",
				"earthshaker_erth_rival_20",
				"earthshaker_erth_rare_05",
				},
				{
				"elder_titan_elder_laugh_05",
				"elder_titan_elder_purch_03",
				"elder_titan_elder_deny_06",
				"elder_titan_elder_lose_05",
				"elder_titan_elder_failure_01",
				"elder_titan_elder_move_11",
				"elder_titan_elder_failure_02",
				"elder_titan_elder_kill_04",
				},
				{
				"ember_spirit_embr_laugh_12",
				"ember_spirit_embr_levelup_01",
				"ember_spirit_embr_itemrare_01",
				"ember_spirit_embr_attack_06",
				"ember_spirit_embr_kill_12",
				"ember_spirit_embr_move_02",
				"ember_spirit_embr_rival_03",
				"ember_spirit_embr_failure_02",
				},
				{
				"enchantress_ench_laugh_05",
				"enchantress_ench_win_03",
				"enchantress_ench_deny_13",
				"enchantress_ench_death_08",
				"enchantress_ench_deny_14",
				"enchantress_ench_kill_08",
				"enchantress_ench_deny_15",
				"enchantress_ench_rare_01",
				},
				{
				"enigma_enig_laugh_03",
				"enigma_enig_respawn_05",
				"enigma_enig_purch_01",
				"enigma_enig_ability_black_03",
				"enigma_enig_lasthit_01",
				"enigma_enig_rival_20",
				"enigma_enig_drop_medium_01",
				"enigma_enig_ability_black_01",
				},
				{
				"faceless_void_face_laugh_07",
				"faceless_void_face_win_03",
				"faceless_void_face_lose_03",
				"faceless_void_face_kill_01",
				"faceless_void_face_kill_11",
				"faceless_void_face_ability_chronos_failure_08",
				"faceless_void_face_rare_03",
				"faceless_void_face_ability_chronos_failure_07",
				},
				{
				"grimstroke_grimstroke_laugh_11",
				"grimstroke_grimstroke_wheel_thanks_01",
				"grimstroke_grimstroke_kill_11",
				"grimstroke_grimstroke_wheel_deny_03",
				"grimstroke_grimstroke_spawn_14",
				"grimstroke_grimstroke_kill_10",
				"grimstroke_grimstroke_wheel_deny_01",
				"grimstroke_grimstroke_taunt_01",
				},
				{
				"gyrocopter_gyro_laugh_11",
				"gyrocopter_gyro_flak_cannon_09",
				"gyrocopter_gyro_failure_03",
				"gyrocopter_gyro_homing_missile_destroyed_02",
				"gyrocopter_gyro_respawn_12",
				"gyrocopter_gyro_deny_05",
				"gyrocopter_gyro_kill_15",
				"gyrocopter_gyro_kill_02",
				},
				{
				"huskar_husk_laugh_09",
				"huskar_husk_purch_01",
				"huskar_husk_ability_lifebrk_01",
				"huskar_husk_kill_06",
				"huskar_husk_ability_brskrblood_03",
				"huskar_husk_ability_lifebrk_05",
				"huskar_husk_lasthit_07",
				"huskar_husk_kill_04",
				},
				{
				"invoker_invo_laugh_06",
				"invoker_invo_purch_01",
				"invoker_invo_ability_invoke_01",
				"invoker_invo_kill_01",
				"invoker_invo_attack_05",
				"invoker_invo_failure_06",
				"invoker_invo_lasthit_06",
				"invoker_invo_rare_04",
				},
				{
				"wisp_laugh",
				"wisp_thanks",
				"wisp_deny",
				"wisp_ally",
				"wisp_win",
				"wisp_lose",
				"wisp_no_mana_not_yet01",
				"wisp_battlebegins",
				},
				{
				"jakiro_jak_deny_13",
				"jakiro_jak_bottle_01",
				"jakiro_jak_rare_03",
				"jakiro_jak_deny_12",
				"jakiro_jak_level_05",
				"jakiro_jak_bottle_03",
				"jakiro_jak_ability_failure_07",
				"jakiro_jak_brother_02",
				},
				{
				"juggernaut_jug_laugh_05",
				"juggernaut_jugg_set_complete_06",
				"juggernaut_jugg_set_complete_04",
				"juggernaut_jugg_taunt_06",
				"juggernaut_jugg_set_complete_03",
				"juggernaut_jug_ability_stunteleport_03",
				"juggernaut_jug_kill_09",
				"juggernaut_jugg_set_complete_05",
				},
				{
				"keeper_of_the_light_keep_laugh_06",
				"keeper_of_the_light_keep_thanks_04",
				"keeper_of_the_light_keep_nomana_06",
				"keeper_of_the_light_keep_kill_18",
				"keeper_of_the_light_keep_deny_12",
				"keeper_of_the_light_keep_deny_16",
				"keeper_of_the_light_keep_kill_09",
				"keeper_of_the_light_keep_cast_02",
				},
				{
				"kunkka_kunk_laugh_06",
				"kunkka_kunk_thanks_03",
				"kunkka_kunk_kill_04",
				"kunkka_kunk_attack_08",
				"kunkka_kunk_kill_10",
				"kunkka_kunk_ability_tidebrng_02",
				"kunkka_kunk_ally_06",
				"kunkka_kunk_kill_13",
				},
				{
				"legion_commander_legcom_laugh_05",
				"legion_commander_legcom_itemcommon_02",
				"legion_commander_legcom_deny_07",
				"legion_commander_legcom_move_15",
				"legion_commander_legcom_ally_11",
				"legion_commander_legcom_duel_08",
				"legion_commander_legcom_duelfailure_06",
				"legion_commander_legcom_kill_14",
				},
				{
				"leshrac_lesh_deny_14",
				"leshrac_lesh_bottle_01",
				"leshrac_lesh_kill_13",
				"leshrac_lesh_lasthit_08",
				"leshrac_lesh_deny_13",
				"leshrac_lesh_purch_01",
				"leshrac_lesh_cast_01",
				"leshrac_lesh_kill_11",
				},
				{
				"lich_lich_level_09",
				"lich_lich_ability_armor_01",
				"lich_lich_kill_05",
				"lich_lich_immort_02",
				"lich_lich_attack_03",
				"lich_lich_ability_nova_01",
				"lich_lich_kill_09",
				"lich_lich_ability_icefrog_01",
				},
				{
				"life_stealer_lifest_laugh_07",
				"life_stealer_lifest_levelup_11",
				"life_stealer_lifest_ability_infest_burst_08",
				"life_stealer_lifest_ability_infest_burst_05",
				"life_stealer_lifest_ability_rage_06",
				"life_stealer_lifest_attack_02",
				"life_stealer_lifest_kill_13",
				"life_stealer_lifest_ability_infest_burst_06",
				},
				{
				"lina_lina_laugh_09",
				"lina_lina_kill_01",
				"lina_lina_kill_05",
				"lina_lina_kill_02",
				"lina_lina_spawn_08",
				"lina_lina_kill_03",
				"lina_lina_drop_common_01",
				"lina_lina_purch_02",
				},
				{
				"lion_lion_laugh_01",
				"lion_lion_move_12",
				"lion_lion_deny_06",
				"lion_lion_kill_05",
				"lion_lion_cast_03",
				"lion_lion_kill_02",
				"lion_lion_kill_04",
				"lion_lion_respawn_01",
				},
				{
				"lone_druid_lone_druid_laugh_05",
				"lone_druid_lone_druid_level_03",
				"lone_druid_lone_druid_ability_trueform_09",
				"lone_druid_lone_druid_ability_rabid_04",
				"lone_druid_lone_druid_ability_failure_02",
				"lone_druid_lone_druid_purch_02",
				"lone_druid_lone_druid_death_03",
				"lone_druid_lone_druid_bearform_ability_trueform_04",
				},
				{
				"luna_luna_laugh_09",
				"luna_luna_levelup_03",
				"luna_luna_drop_common",
				"luna_luna_kill_06",
				"luna_luna_ability_failure_03",
				"luna_luna_drop_medium",
				"luna_luna_shiwiz_02",
				"luna_luna_ability_eclipse_08",
				},
				{
				"lycan_lycan_laugh_14",
				"lycan_lycan_kill_04",
				"lycan_lycan_immort_02",
				"lycan_lycan_kill_01",
				"lycan_lycan_level_05",
				"lycan_lycan_attack_02",
				"lycan_lycan_attack_05",
				"lycan_lycan_cast_02",
				},
				{
				"magnataur_magn_laugh_06",
				"magnataur_magn_purch_04",
				"magnataur_magn_failure_08",
				"magnataur_magn_kill_01",
				"magnataur_magn_failure_10",
				"magnataur_magn_lasthit_02",
				"magnataur_magn_failure_03",
				"magnataur_magn_rare_05",
				},
				{
				"mars_mars_laugh_08",
				"mars_mars_thanks_03",
				"mars_mars_lose_05",
				"mars_mars_kill_09",
				"mars_mars_kill_10",
				"mars_mars_ability4_09",
				"mars_mars_song_02",
				"mars_mars_wheel_all_11",
				},
				{
				"medusa_medus_laugh_05",
				"medusa_medus_items_15",
				"medusa_medus_deny_01",
				"medusa_medus_kill_09",
				"medusa_medus_failure_01",
				"medusa_medus_deny_12",
				"medusa_medus_begin_03",
				"medusa_medus_illus_02",
				},
				{
				"meepo_meepo_deny_16",
				"meepo_meepo_drop_medium",
				"meepo_meepo_earthbind_05",
				"meepo_meepo_failure_03",
				"meepo_meepo_purch_05",
				"meepo_meepo_lose_05",
				"meepo_meepo_respawn_08",
				"meepo_meepo_lose_04",
				},
				{
				"mirana_mir_laugh_03",
				"mirana_mir_drop_common_01",
				"mirana_mir_illus_03",
				"mirana_mir_kill_09",
				"mirana_mir_kill_02",
				"mirana_mir_attack_08",
				"mirana_mir_rare_04",
				"mirana_mir_kill_04",
				},
				{
				"monkey_king_monkey_laugh_17",
				"monkey_king_monkey_drop_common_01",
				"monkey_king_monkey_regen_02",
				"monkey_king_monkey_win_02",
				"monkey_king_monkey_death_01",
				"monkey_king_monkey_drop_medium_01",
				"monkey_king_monkey_deny_brood_01",
				"monkey_king_monkey_ability5_07",
				},
				{
				"morphling_mrph_laugh_08",
				"morphling_mrph_ability_repfriend_02",
				"morphling_mrph_cast_01",
				"morphling_mrph_attack_09",
				"morphling_mrph_regen_02",
				"morphling_mrph_respawn_02",
				"morphling_mrph_kill_09",
				"morphling_mrph_kill_06",
				},
				{
				"naga_siren_naga_laugh_04",
				"naga_siren_naga_kill_02",
				"naga_siren_naga_kill_12",
				"naga_siren_naga_cast_01",
				"naga_siren_naga_rival_21",
				"naga_siren_naga_deny_08",
				"naga_siren_naga_rival_14",
				"naga_siren_naga_death_07",
				},
				{
				"furion_furi_laugh_01",
				"furion_furi_equipping_04",
				"furion_furi_equipping_05",
				"furion_furi_kill_01",
				"furion_furi_kill_03",
				"furion_furi_equipping_02",
				"furion_furi_deny_07",
				"furion_furi_kill_11",
				},
				{
				"necrolyte_necr_laugh_07",
				"necrolyte_necr_breath_02",
				"necrolyte_necr_purch_04",
				"necrolyte_necr_kill_03",
				"necrolyte_necr_rare_05",
				"necrolyte_necr_lose_03",
				"necrolyte_necr_respawn_12",
				"necrolyte_necr_rare_04",
				},
				{
				"night_stalker_nstalk_laugh_06",
				"night_stalker_nstalk_purch_03",
				"night_stalker_nstalk_respawn_05",
				"night_stalker_nstalk_purch_01",
				"night_stalker_nstalk_cast_01",
				"night_stalker_nstalk_attack_11",
				"night_stalker_nstalk_battlebegins_01",
				"night_stalker_nstalk_spawn_03",
				},
				{
				"nyx_assassin_nyx_laugh_07",
				"nyx_assassin_nyx_items_11",
				"nyx_assassin_nyx_death_03",
				"nyx_assassin_nyx_burn_05",
				"nyx_assassin_nyx_chitter_02",
				"nyx_assassin_nyx_waiting_01",
				"nyx_assassin_nyx_rival_25",
				"nyx_assassin_nyx_levelup_10",
				},
				{
				"ogre_magi_ogmag_laugh_14",
				"ogre_magi_ogmag_rival_04",
				"ogre_magi_ogmag_illus_02",
				"ogre_magi_ogmag_ability_multi_05",
				"ogre_magi_ogmag_kill_11",
				"ogre_magi_ogmag_rival_05",
				"ogre_magi_ogmag_rival_03",
				"ogre_magi_ogmag_kill_03",
				},
				{
				"omniknight_omni_laugh_10",
				"omniknight_omni_death_13",
				"omniknight_omni_level_09",
				"omniknight_omni_kill_09",
				"omniknight_omni_ability_degaura_04",
				"omniknight_omni_kill_02",
				"omniknight_omni_kill_12",
				"omniknight_omni_ability_degaura_05",
				},
				{
				"oracle_orac_laugh_13",
				"oracle_orac_kill_09",
				"oracle_orac_death_11",
				"oracle_orac_lasthit_04",
				"oracle_orac_itemare_02",
				"oracle_orac_respawn_06",
				"oracle_orac_kill_22",
				"oracle_orac_randomprophecies_02",
				},
				{
				"outworld_destroyer_odest_laugh_04",
				"outworld_destroyer_odest_begin_02",
				"outworld_destroyer_odest_win_04",
				"outworld_destroyer_odest_attack_11",
				"outworld_destroyer_odest_death_10",
				"outworld_destroyer_odest_rival_13",
				"outworld_destroyer_odest_death_12",
				"outworld_destroyer_odest_lasthit_03",
				},
				{
				"pangolin_pangolin_laugh_14",
				"pangolin_pangolin_kill_08",
				"pangolin_pangolin_levelup_11",
				"pangolin_pangolin_kill_06",
				"pangolin_pangolin_ability3_04",
				"pangolin_pangolin_ability4_08",
				"pangolin_pangolin_doubledam_03",
				"pangolin_pangolin_ally_09",
				},
				{
				"phantom_assassin_phass_laugh_07",
				"phantom_assassin_phass_happy_09",
				"phantom_assassin_phass_kill_02",
				"phantom_assassin_phass_kill_10",
				"phantom_assassin_phass_kill_01",
				"phantom_assassin_phass_ability_blur_02",
				"phantom_assassin_phass_deny_14",
				"phantom_assassin_phass_level_06",
				},
				{
				"phantom_lancer_plance_laugh_03",
				"phantom_lancer_plance_drop_rare",
				"phantom_lancer_plance_lasthit_06",
				"phantom_lancer_plance_cast_02",
				"phantom_lancer_plance_illus_02",
				"phantom_lancer_plance_respawn_05",
				"phantom_lancer_plance_win_02",
				"phantom_lancer_plance_kill_10",
				},
				{
				"phoenix_phoenix_bird_laugh",
				"phoenix_phoenix_bird_emote_good",
				"phoenix_phoenix_bird_denied",
				"phoenix_phoenix_bird_victory",
				"phoenix_phoenix_bird_death_defeat",
				"phoenix_phoenix_bird_inthebag",
				"phoenix_phoenix_bird_emote_bad",
				"phoenix_phoenix_bird_level_up",
				},
				{
				"puck_puck_laugh_01",
				"puck_puck_spawn_04",
				"puck_puck_kill_09",
				"puck_puck_ability_orb_03",
				"puck_puck_spawn_05",
				"puck_puck_lose_04",
				"puck_puck_ability_dreamcoil_05",
				"puck_puck_win_04",
				},
				{
				"pudge_pud_laugh_05",
				"pudge_pud_thanks_02",
				"pudge_pud_ability_rot_07",
				"pudge_pud_attack_08",
				"pudge_pud_rare_05",
				"pudge_pud_acknow_05",
				"pudge_pud_lasthit_07",
				"pudge_pud_kill_07",
				},
				{
				"pugna_pugna_laugh_01",
				"pugna_pugna_level_06",
				"pugna_pugna_cast_05",
				"pugna_pugna_ability_nblast_05",
				"pugna_pugna_respawn_03",
				"pugna_pugna_battlebegins_01",
				"pugna_pugna_ability_nward_07",
				"pugna_pugna_ability_life_08",
				},
				{
				"queenofpain_pain_laugh_04",
				"queenofpain_pain_spawn_02",
				"queenofpain_pain_kill_08",
				"queenofpain_pain_kill_12",
				"queenofpain_pain_attack_04",
				"queenofpain_pain_cast_01",
				"queenofpain_pain_taunt_01",
				"queenofpain_pain_respawn_04",
				},
				{
				"razor_raz_laugh_05",
				"razor_raz_ability_static_05",
				"razor_raz_cast_01",
				"razor_raz_kill_03",
				"razor_raz_kill_10",
				"razor_raz_lasthit_02",
				"razor_raz_kill_05",
				"razor_raz_kill_09",
				},
				{
				"riki_riki_laugh_03",
				"riki_riki_kill_01",
				"riki_riki_kill_03",
				"riki_riki_cast_01",
				"riki_riki_ability_blink_05",
				"riki_riki_ability_invis_03",
				"riki_riki_respawn_07",
				"riki_riki_kill_14",
				},
				{
				"rubick_rubick_laugh_06",
				"rubick_rubick_move_12",
				"rubick_rubick_lasthit_06",
				"rubick_rubick_levelup_04",
				"rubick_rubick_rival_07",
				"rubick_rubick_itemcommon_02",
				"rubick_rubick_failure_02",
				"rubick_rubick_itemrare_01",
				},
				{
				"sandking_skg_laugh_07",
				"sandking_sand_thanks_03",
				"sandking_skg_ability_caustic_04",
				"sandking_skg_kill_04",
				"sandking_skg_win_04",
				"sandking_skg_ability_epicenter_01",
				"sandking_skg_kill_09",
				"sandking_skg_kill_03",
				},
				{
				"shadow_demon_shadow_demon_laugh_03",
				"shadow_demon_shadow_demon_doubdam_02",
				"shadow_demon_shadow_demon_kill_10",
				"shadow_demon_shadow_demon_attack_13",
				"shadow_demon_shadow_demon_attack_03",
				"shadow_demon_shadow_demon_ability_soul_catcher_01",
				"shadow_demon_shadow_demon_lasthit_07",
				"shadow_demon_shadow_demon_kill_14",
				},
				{
				"nevermore_nev_laugh_02",
				"nevermore_nev_thanks_02",
				"nevermore_nev_deny_03",
				"nevermore_nev_kill_11",
				"nevermore_nev_ability_presence_02",
				"nevermore_nev_lasthit_02",
				"nevermore_nev_attack_07",
				"nevermore_nev_attack_11",
				},
				{
				"shadowshaman_shad_blink_02",
				"shadowshaman_shad_level_03",
				"shadowshaman_shad_ability_voodoo_06",
				"shadowshaman_shad_kill_03",
				"shadowshaman_shad_ability_entrap_03",
				"shadowshaman_shad_refresh_02",
				"shadowshaman_shad_ability_voodoo_08",
				"shadowshaman_shad_attack_07",
				},
				{
				"silencer_silen_laugh_13",
				"silencer_silen_level_06",
				"silencer_silen_deny_11",
				"silencer_silen_ability_silence_05",
				"silencer_silen_ability_failure_04",
				"silencer_silen_ability_curse_02",
				"silencer_silen_death_10",
				"silencer_silen_respawn_02",
				},
				{
				"skywrath_mage_drag_laugh_01",
				"skywrath_mage_drag_lasthit_07",
				"skywrath_mage_drag_deny_04",
				"skywrath_mage_drag_failure_01",
				"skywrath_mage_drag_fastres_01",
				"skywrath_mage_drag_thanks_02",
				"skywrath_mage_drag_inthebag_01",
				"skywrath_mage_drag_cast_02",
				},
				{
				"slardar_slar_laugh_05",
				"slardar_slar_kill_07",
				"slardar_slar_kill_01",
				"slardar_slar_longdistance_02",
				"slardar_slar_cast_02",
				"slardar_slar_deny_05",
				"slardar_slar_kill_03",
				"slardar_slar_win_05",
				},
				{
				"slark_slark_laugh_01",
				"slark_slark_illus_02",
				"slark_slark_cast_03",
				"slark_slark_rival_03",
				"slark_slark_failure_05",
				"slark_slark_kill_08",
				"slark_slark_drop_rare_01",
				"slark_slark_happy_07",
				},
				{
				"snapfire_snapfire_laugh_02_02",
				"snapfire_snapfire_wheel_thanks_02",
				"snapfire_snapfire_spawn_25",
				"snapfire_snapfire_wheel_all_03",
				"snapfire_snapfire_wheel_all_07",
				"snapfire_snapfire_whawiz_01",
				"snapfire_snapfire_rival_67",
				"snapfire_snapfire_spawn_24",
				},
				{
				"sniper_snip_laugh_08",
				"sniper_snip_level_06",
				"sniper_snip_ability_fail_04",
				"sniper_snip_tf2_04",
				"sniper_snip_ability_shrapnel_06",
				"sniper_snip_rare_04",
				"sniper_snip_kill_05",
				"sniper_snip_ability_shrapnel_03",
				},
				{
				"spectre_spec_laugh_13",
				"spectre_spec_ability_haunt_01",
				"spectre_spec_deny_01",
				"spectre_spec_death_07",
				"spectre_spec_lasthit_01",
				"spectre_spec_doubdam_02",
				"spectre_spec_kill_02",
				"spectre_spec_kill_01",
				},
				{
				"spirit_breaker_spir_laugh_06",
				"spirit_breaker_spir_level_07",
				"spirit_breaker_spir_ability_bash_03",
				"spirit_breaker_spir_purch_03",
				"spirit_breaker_spir_cast_01",
				"spirit_breaker_spir_lose_05",
				"spirit_breaker_spir_lasthit_07",
				"spirit_breaker_spir_ability_failure_02",
				},
				{
				"stormspirit_ss_laugh_06",
				"stormspirit_ss_win_03",
				"stormspirit_ss_kill_02",
				"stormspirit_ss_attack_06",
				"stormspirit_ss_ability_lightning_06",
				"stormspirit_ss_kill_03",
				"stormspirit_ss_ability_static_02",
				"stormspirit_ss_lasthit_04",
				},
				{
				"sven_sven_laugh_11",
				"sven_sven_thanks_01",
				"sven_sven_ability_teleport_01",
				"sven_sven_kill_02",
				"sven_sven_kill_05",
				"sven_sven_rare_07",
				"sven_sven_win_04",
				"sven_sven_respawn_02",
				},
				{
				"techies_tech_kill_23",
				"techies_tech_settrap_08",
				"techies_tech_failure_06",
				"techies_tech_suicidesquad_09",
				"techies_tech_detonatekill_02",
				"techies_tech_trapgoesoff_10",
				"techies_tech_ally_03",
				"techies_tech_kill_07",
				},
				{
				"templar_assassin_temp_laugh_02",
				"templar_assassin_temp_lasthit_06",
				"templar_assassin_temp_kill_10",
				"templar_assassin_temp_kill_12",
				"templar_assassin_temp_psionictrap_04",
				"templar_assassin_temp_levelup_01",
				"templar_assassin_temp_psionictrap_06",
				"templar_assassin_temp_refraction_04",
				},
				{
				"terrorblade_terr_laugh_07",
				"terrorblade_terr_conjureimage_03",
				"terrorblade_terr_purch_02",
				"terrorblade_terr_sunder_03",
				"terrorblade_terr_reflection_06",
				"terrorblade_terr_failure_05",
				"terrorblade_terr_kill_14",
				"terrorblade_terr_doubdam_04",
				},
				{
				"tidehunter_tide_laugh_05",
				"tidehunter_tide_battlebegins_02",
				"tidehunter_tide_ability_ravage_02",
				"tidehunter_tide_kill_12",
				"tidehunter_tide_level_18",
				"tidehunter_tide_bottle_01",
				"tidehunter_tide_rival_25",
				"tidehunter_tide_rare_01",
				},
				{
				"shredder_timb_laugh_04",
				"shredder_timb_thanks_03",
				"shredder_timb_kill_10",
				"shredder_timb_happy_05",
				"shredder_timb_drop_rare_02",
				"shredder_timb_whirlingdeath_05",
				"shredder_timb_rival_08",
				"shredder_timb_haste_02",
				},
				{
				"tinker_tink_laugh_10",
				"tinker_tink_thanks_03",
				"tinker_tink_levelup_06",
				"tinker_tink_ability_laser_03",
				"tinker_tink_respawn_01",
				"tinker_tink_kill_03",
				"tinker_tink_respawn_03",
				"tinker_tink_ability_laser_01",
				},
				{
				"tiny_tiny_laugh_05",
				"tiny_tiny_spawn_03",
				"tiny_tiny_ability_toss_11",
				"tiny_tiny_attack_03",
				"tiny_tiny_kill_09",
				"tiny_tiny_ability_toss_07",
				"tiny_tiny_attack_06",
				"tiny_tiny_level_02",
				},
				{
				"treant_treant_laugh_07",
				"treant_treant_freakout",
				"treant_treant_failure_03",
				"treant_treant_attack_07",
				"treant_treant_ability_naturesguise_06",
				"treant_treant_cast_02",
				"treant_treant_kill_05",
				"treant_treant_failure_01",
				},
				{
				"troll_warlord_troll_laugh_05",
				"troll_warlord_troll_battletrance_05",
				"troll_warlord_troll_deny_09",
				"troll_warlord_troll_kill_03",
				"troll_warlord_troll_ally_08",
				"troll_warlord_troll_ally_11",
				"troll_warlord_troll_death_05",
				"troll_warlord_troll_unknown_09",
				},
				{
				"tusk_tusk_laugh_06",
				"tusk_tusk_kill_26",
				"tusk_tusk_snowball_17",
				"tusk_tusk_rival_19",
				"tusk_tusk_snowball_24",
				"tusk_tusk_move_26",
				"tusk_tusk_kill_22",
				"tusk_tusk_snowball_23",
				},
				{
				"abyssal_underlord_abys_laugh_02",
				"abyssal_underlord_abys_thanks_03",
				"abyssal_underlord_abys_failure_01",
				"abyssal_underlord_abys_move_02",
				"abyssal_underlord_abys_kill_13",
				"abyssal_underlord_abys_rival_01",
				"abyssal_underlord_abys_move_12",
				"abyssal_underlord_abys_darkrift_03",
				},
				{
				"undying_undying_levelup_10",
				"undying_undying_thanks_04",
				"undying_undying_kill_09",
				"undying_undying_respawn_03",
				"undying_undying_gummy_vit_01",
				"undying_undying_respawn_05",
				"undying_undying_deny_14",
				"undying_undying_failure_02",
				},
				{
				"ursa_ursa_laugh_20",
				"ursa_ursa_respawn_12",
				"ursa_ursa_kill_10",
				"ursa_ursa_failure_02",
				"ursa_ursa_spawn_05",
				"ursa_ursa_kill_07",
				"ursa_ursa_levelup_07",
				"ursa_ursa_lasthit_08",
				},
				{
				"vengefulspirit_vng_deny_11",
				"vengefulspirit_vng_kill_01",
				"vengefulspirit_vng_respawn_06",
				"vengefulspirit_vng_regen_02",
				"vengefulspirit_vng_rare_09",
				"vengefulspirit_vng_deny_03",
				"vengefulspirit_vng_rare_10",
				"vengefulspirit_vng_rare_05",
				},
				{
				"venomancer_venm_laugh_02",
				"venomancer_venm_ability_ward_02",
				"venomancer_venm_purch_01",
				"venomancer_venm_kill_03",
				"venomancer_venm_ability_fail_07",
				"venomancer_venm_cast_02",
				"venomancer_venm_rosh_04",
				"venomancer_venm_attack_11",
				},
				{
				"viper_vipe_laugh_06",
				"viper_vipe_respawn_07",
				"viper_vipe_deny_06",
				"viper_vipe_kill_03",
				"viper_vipe_move_14",
				"viper_vipe_lasthit_05",
				"viper_vipe_ability_viprstrik_02",
				"viper_vipe_rare_03",
				},
				{
				"visage_visa_laugh_14",
				"visage_visa_happy_07",
				"visage_visa_rival_09",
				"visage_visa_kill_13",
				"visage_visa_failure_01",
				"visage_visa_rival_02",
				"visage_visa_spawn_05",
				"visage_visa_happy_03",
				},
				{
				"void_spirit_voidspir_laugh_05",
				"void_spirit_voidspir_thanks_04",
				"void_spirit_voidspir_spawn_14",
				"void_spirit_voidspir_rival_114",
				"void_spirit_voidspir_rival_113",
				"void_spirit_voidspir_rival_72",
				"void_spirit_voidspir_rival_71",
				"void_spirit_voidspir_wheel_all_10_02",
				},
				{
				"warlock_warl_laugh_06",
				"warlock_warl_ability_reign_07",
				"warlock_warl_defusal_04",
				"warlock_warl_kill_05",
				"warlock_warl_incant_18",
				"warlock_warl_kill_07",
				"warlock_warl_lasthit_02",
				"warlock_warl_doubdemon_06",
				},
				{
				"weaver_weav_laugh_04",
				"weaver_weav_win_03",
				"weaver_weav_ability_timelap_05",
				"weaver_weav_kill_07",
				"weaver_weav_fastres_01",
				"weaver_weav_respawn_02",
				"weaver_weav_kill_03",
				"weaver_weav_lasthit_07",
			},
			{
				"windrunner_wind_laugh_08",
				"windrunner_wind_lasthit_04",
				"windrunner_wind_deny_06",
				"windrunner_wind_kill_11",
				"windrunner_wind_ability_shackleshot_01",
				"windrunner_wind_kill_06",
				"windrunner_wind_lose_06",
				"windrunner_wind_attack_04",
			},
			{
				"winter_wyvern_winwyv_laugh_03",
				"winter_wyvern_winwyv_thanks_01",
				"winter_wyvern_winwyv_deny_08",
				"winter_wyvern_winwyv_death_09",
				"winter_wyvern_winwyv_lasthit_07",
				"winter_wyvern_winwyv_kill_03",
				"winter_wyvern_winwyv_winterscurse_11",
				"winter_wyvern_winwyv_levelup_08",
			},
			{
				"witchdoctor_wdoc_laugh_02",
				"witchdoctor_wdoc_level_08",
				"witchdoctor_wdoc_killspecial_01",
				"witchdoctor_wdoc_killspecial_03",
				"witchdoctor_wdoc_move_06",
				"witchdoctor_wdoc_ability_cask_03",
				"witchdoctor_wdoc_kill_11",
				"witchdoctor_wdoc_laugh_03",
			},
			{
				"skeleton_king_wraith_laugh_04",
				"skeleton_king_wraith_ally_01",
				"skeleton_king_wraith_move_08",
				"skeleton_king_wraith_attack_03",
				"skeleton_king_wraith_purch_03",
				"skeleton_king_wraith_rare_06",
				"skeleton_king_wraith_items_02",
				"skeleton_king_wraith_win_03",
			},
			{
				"zuus_zuus_laugh_01",
				"zuus_zuus_level_03",
				"zuus_zuus_win_05",
				"zuus_zuus_cast_02",
				"zuus_zuus_kill_05",
				"zuus_zuus_death_07",
				"zuus_zuus_ability_thunder_01",
				"zuus_zuus_rival_13",
			}
		}
		if vousedcol[keys.PlayerID] == nil then vousedcol[keys.PlayerID] = 0 end
		if votimer[keys.PlayerID] ~= nil then
			if GameRules:GetGameTime() - votimer[keys.PlayerID] > 5 + vousedcol[keys.PlayerID] and (phraseDoesntHasCooldown == nil or phraseDoesntHasCooldown == true) then
				local chat = LoadKeyValues("scripts/hero_chat_wheel_english.txt")
				--EmitAnnouncerSound(heroesvo[selectedid][selectedid2])
				ChatSound(heroesvo[selectedid][selectedid2], keys.PlayerID)
				--GameRules:SendCustomMessage("<font color='#70EA72'>".."test".."</font>",-1,0)
				Say(PlayerResource:GetPlayer(keys.PlayerID), chat["dota_chatwheel_message_"..selectedstr], false)

				votimer[keys.PlayerID] = GameRules:GetGameTime()
				vousedcol[keys.PlayerID] = vousedcol[keys.PlayerID] + 1
			else
				CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(keys.PlayerID), "display_custom_error", { message = "#wheel_cooldown" })
			end
		else
			local chat = LoadKeyValues("scripts/hero_chat_wheel_english.txt")
			--EmitAnnouncerSound(heroesvo[selectedid][selectedid2])
			ChatSound(heroesvo[selectedid][selectedid2], keys.PlayerID)
			Say(PlayerResource:GetPlayer(keys.PlayerID), chat["dota_chatwheel_message_"..selectedstr], false)
			votimer[keys.PlayerID] = GameRules:GetGameTime()
			vousedcol[keys.PlayerID] = vousedcol[keys.PlayerID] + 1
		end
	end
end

function ChatSound(phrase, playerId)
	local all_heroes = HeroList:GetAllHeroes()
	for _, hero in pairs(all_heroes) do
		if hero:IsRealHero() and hero:IsControllableByAnyPlayer() and hero:GetPlayerID() and ((not _G.tPlayersMuted[hero:GetPlayerID()]) or (not _G.tPlayersMuted[hero:GetPlayerID()][playerId])) then
			EmitAnnouncerSoundForPlayer(phrase, hero:GetPlayerID())
			if phrase == "soundboard.ceb.start" then
				Timers:CreateTimer(2, function()
					StopGlobalSound("soundboard.ceb.start")
					EmitAnnouncerSoundForPlayer("soundboard.ceb.stop", hero:GetPlayerID())
				end
				)
			end
		end
	end
end

RegisterCustomEventListener("SelectVO", SelectVO)

RegisterCustomEventListener("set_mute_player", function(data)
	local fromId = data.PlayerID
	local toId = data.toPlayerId
	local disable = data.disable
	_G.tPlayersMuted[fromId] = _G.tPlayersMuted[fromId] or {}
	if disable == 0 then
		_G.tPlayersMuted[fromId][toId] = false
	else
		_G.tPlayersMuted[fromId][toId] = true
	end
end)

function GetTopPlayersList(fromTopCount, team, sortFunction)
	local focusTableHeroes

	if team == DOTA_TEAM_GOODGUYS then
		focusTableHeroes = _G.tableRadiantHeroes
	elseif team == DOTA_TEAM_BADGUYS then
		focusTableHeroes = _G.tableDireHeroes
	end
	local playersSortInfo = {}

	for _, focusHero in pairs(focusTableHeroes) do
		playersSortInfo[focusHero:GetPlayerOwnerID()] = sortFunction(focusHero)
	end

	local topPlayers = {}

	local countPlayers = 0
	while(countPlayers < fromTopCount or countPlayerss == 12) do
		local bestPlayerValue = -1
		local bestPlayer
		for playerID, playerInfo in pairs(playersSortInfo) do
			if not topPlayers[playerID] then
				if bestPlayerValue < playerInfo then
					bestPlayerValue = playerInfo
					bestPlayer = playerID
				end
			end
		end
		countPlayers = countPlayers + 1
		if bestPlayer and bestPlayerValue > -1 then
			topPlayers[bestPlayer] = bestPlayerValue
		end
	end
	return topPlayers
end

function CheckTeamBalance()
	if GameOptions:OptionsIsActive("no_switch_team") then
		return
	end

	if GetMapName() == "dota_tourtament" then
		return
	end

	_G.changeTeamProgress = false
	local radiantPlayers = 0
	local direPlayers = 0

	for playerID = 0, 23 do
		local state = PlayerResource:GetConnectionState(playerID)
		if state == DOTA_CONNECTION_STATE_DISCONNECTED or state == DOTA_CONNECTION_STATE_CONNECTED or state == DOTA_CONNECTION_STATE_NOT_YET_CONNECTED then
			local team = PlayerResource:GetTeam(playerID)
			if team == DOTA_TEAM_GOODGUYS then
				radiantPlayers = radiantPlayers + 1
			elseif team == DOTA_TEAM_BADGUYS then
				direPlayers = direPlayers + 1
			end
		end
	end

	if math.abs(radiantPlayers-direPlayers) >= MIN_DIFFERNCE_PLAYERS_IN_TEAM then
		local highTeam = DOTA_TEAM_GOODGUYS
		if radiantPlayers < direPlayers then
			highTeam = DOTA_TEAM_BADGUYS
		end
		Timers:CreateTimer(0.5, function()
			_G.isChangeTeamAvailable = true
			CustomGameEventManager:Send_ServerToTeam(highTeam, "ShowTeamChangePanel", {} )
		end)
	else
		CustomGameEventManager:Send_ServerToAllClients("HideTeamChangePanel", {} )
	end
end

RegisterCustomEventListener("PlayerChangeTeam", function(data)
	local oldTeam = PlayerResource:GetTeam(data.PlayerID)
	local newTeam
	if oldTeam == DOTA_TEAM_GOODGUYS then
		newTeam = DOTA_TEAM_BADGUYS
	else
		newTeam = DOTA_TEAM_GOODGUYS
	end
	ChangeTeam(data.PlayerID, newTeam)
end)

function PlayerForFeedBack(team)
	for id = 0, 23 do
		local state = PlayerResource:GetConnectionState(id)
		if (PlayerResource:GetTeam(id) == team) and (state == DOTA_CONNECTION_STATE_ABANDONED or state == DOTA_CONNECTION_STATE_NOT_YET_CONNECTED) then
			return id
		end
	end
	return nil
end

function ChangeTeam(playerID, newTeam)
	if GameRules:GetDOTATime(false, true) >= TIME_LIMIT_FOR_CHANGE_TEAM then
		if GetTopPlayersList(3, PlayerResource:GetTeam(playerID), GetHeroKD)[playerID] then
			CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(playerID), "display_custom_error", { message = "#too_huge_kda_for_change_team" })
			return
		end
		if GetTopPlayersList(3, PlayerResource:GetTeam(playerID), function(hero) return PlayerResource:GetNetWorth(hero:GetPlayerOwnerID())end)[playerID] then
			CustomGameEventManager:Send_ServerToPlayer(PlayerResource:GetPlayer(playerID), "display_custom_error", { message = "#too_huge_nw_for_change_team" })
			return
		end
	end

	if _G.changeTeamProgress or (not _G.isChangeTeamAvailable) then return end

	if _G.changeTeamTimes[playerID] and (GameRules:GetGameTime() - _G.changeTeamTimes[playerID]) < COOLDOWN_FOR_CHANGE_TEAM then
		DisplayError(playerID, "Cooldown for change team")
		return
	end
	local feedbackChangeTeamPlayer = PlayerForFeedBack(newTeam)
	if not feedbackChangeTeamPlayer then return end
	_G.changeTeamTimes[playerID] = GameRules:GetGameTime()
	_G.changeTeamProgress = true
	_G.isChangeTeamAvailable = false
	CustomGameEventManager:Send_ServerToAllClients("HideTeamChangePanel", {} )
	CustomGameEventManager:Send_ServerToAllClients("PlayerChangedTeam", {playerId = playerID} )

	local teamForFeedback = DOTA_TEAM_BADGUYS
	if newTeam == DOTA_TEAM_BADGUYS then
		teamForFeedback = DOTA_TEAM_GOODGUYS
	end

	ChangeTeamForPlayer(playerID, newTeam)
	Timers:CreateTimer(4, function()
		ChangeTeamForPlayer(feedbackChangeTeamPlayer, teamForFeedback)
	end)
	Timers:CreateTimer(5, function()
		CheckTeamBalance()
	end)
end

function ChangeTeamForPlayer(playerID, newTeam)
	PlayerResource:SetCustomTeamAssignment(playerID, newTeam)
	local hero = PlayerResource:GetSelectedHeroEntity(playerID)
	if IsValidEntity(hero) then

		if _G.PlayersPatreonsPerk[playerID] then
			local perkName = _G.PlayersPatreonsPerk[playerID]
			local perkStacks = hero:GetModifierStackCount(perkName, hero)
			hero:RemoveModifierByName(perkName)
			Timers:CreateTimer(4, function()
				hero:AddNewModifier(hero, nil, perkName, {duration = -1})
				if perkStacks > 0 then
					hero:SetModifierStackCount(perkName, nil, perkStacks)
				end
			end)
		end

		hero:SetTeam(newTeam)
		hero:Kill(nil, hero)

		if IsValidEntity(hero) then

			hero:SetTimeUntilRespawn(1)
			CreateDummyInventoryForPlayer(hero:GetPlayerOwnerID(), hero)
			if hero:HasAbility('arc_warden_tempest_double') then
				local clones = Entities:FindAllByName(hero:GetClassname())
				for _,tempestDouble in pairs(clones) do
					if tempestDouble:IsTempestDouble() and playerID == tempestDouble:GetPlayerID() then
						tempestDouble:Kill(nil, nil)
					end
				end
			end

			if hero:HasAbility('meepo_divided_we_stand') then
				local clones = Entities:FindAllByName(hero:GetClassname())

				for _,meepoClone in pairs(clones) do
					if meepoClone:IsClone() and playerID == meepoClone:GetPlayerID() then
						meepoClone:SetTimeUntilRespawn(1)
					end
				end
			end

			for spell, name in pairs(ts_entities.Switch) do
				if hero:HasAbility(spell) then
					local units = Entities:FindAllByName(name)
					if #units == 0 then
						units = Entities:FindAllByModel(name)
					end

					for _, unit in pairs(units) do
						print("found units")
						if unit:GetPlayerOwnerID() == playerID then
							unit:SetTeam(newTeam)
						end
					end
				end
			end

			for spell, name in pairs(ts_entities.Kill) do
				if hero:HasAbility(spell) then
					local units = Entities:FindAllByName(name)
					if #units == 0 then
						units = Entities:FindAllByModel(name)
					end

					for _, unit in pairs(units) do
						if unit:GetPlayerOwnerID() == playerID then
							unit:Kill(nil, nil)
						end
					end
				end
			end

			local couriers = Entities:FindAllByName("npc_dota_courier")
			for _, courier in pairs(couriers) do
				if courier:GetPlayerOwnerID() == playerID then
					local fountain
					local vMoveFromFountain
					if newTeam == DOTA_TEAM_GOODGUYS then
						fountain = Entities:FindByName( nil, "ent_dota_fountain_good" )
						vMoveFromFountain = Vector(500,500,0)
					elseif newTeam == DOTA_TEAM_BADGUYS then
						fountain = Entities:FindByName( nil, "ent_dota_fountain_bad" )
						vMoveFromFountain = Vector(-500,-500,0)
					end
					local vFountainPoint = fountain:GetAbsOrigin()
					local vNewCourierPount = vFountainPoint + vMoveFromFountain + RandomVector(150)
					courier:SetTeam(newTeam)
					FindClearSpaceForUnit(courier, vNewCourierPount, false)
				end
			end
		end
	end
end
