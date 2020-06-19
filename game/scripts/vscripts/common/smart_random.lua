SmartRandom = SmartRandom or {}
SmartRandom.SmartRandomHeroes = SmartRandom.SmartRandomHeroes or {}
SmartRandom.AutoPickHeroes = SmartRandom.AutoPickHeroes or {}
SmartRandom.PickReasons = SmartRandom.PickReasons or {}
SmartRandom.BannedHeroesEventListeners = SmartRandom.BannedHeroesEventListeners or {}

function SmartRandom:SetPlayerInfo(playerId, heroes, err)
	local table = CustomNetTables:GetTableValue("game_state", "smart_random") or {}
	SmartRandom.SmartRandomHeroes[playerId] = heroes
	table[playerId] = heroes or err
	CustomNetTables:SetTableValue("game_state", "smart_random", table)
end

local npc_heroes = LoadKeyValues("scripts/npc/npc_heroes.txt")
local function getReadableHeroName(name)
	return npc_heroes[name].workshop_guide_name or ""
end

local function getBannedHeroes(callback)
	-- Max safe networkable integer is 2^24
	local eventId = RandomInt(-16777216, 16777216)
	SmartRandom.BannedHeroesEventListeners[eventId] = callback
	for playerId = 0, 23 do
		local player = PlayerResource:GetPlayer(playerId)
		if player then
			CustomGameEventManager:Send_ServerToPlayer(player, "banned_heroes", { eventId = eventId })
		end
	end
end

local function pickRandomHeroFromList(playerId, list, callback)
	local player = PlayerResource:GetPlayer(playerId)
	if not player then return callback(false) end

	getBannedHeroes(function(bannedHeroes)
		for _, heroName in ipairs(table.shuffled(list)) do
			if not PlayerResource:IsHeroSelected(heroName, false) and not bannedHeroes[heroName] then
				UTIL_Remove(CreateHeroForPlayer(heroName, player))
				return callback(true)
			end
		end

		callback(false)
	end)
end

function SmartRandom:PrepareAutoPick()
	local players = {}
	local heroes = {}
	for i = 0, 23 do
		if PlayerResource:IsValidPlayerID(i) then
			if PlayerResource:HasSelectedHero(i) then
				table.insert(heroes, PlayerResource:GetSelectedHeroName(i))
			else
				table.insert(players, tostring(PlayerResource:GetSteamID(i)))
			end
		end
	end

	WebApi:Send("match/auto-pick", { mapName = GetMapName(), players = players, selectedHeroes = heroes }, function(data)
		for _,player in ipairs(data.players) do
			local playerId = GetPlayerIdBySteamId(player.steamId)
			SmartRandom.AutoPickHeroes[playerId] = player.heroes
		end
	end)
end

function SmartRandom:AutoPick()
	for playerId = 0, 23 do
		if PlayerResource:IsValidPlayerID(playerId) and not PlayerResource:HasSelectedHero(playerId) then
			if PlayerResource:GetPlayer(playerId) then
				SmartRandom.PickReasons[playerId] = "auto"
				pickRandomHeroFromList(playerId, SmartRandom.AutoPickHeroes[playerId] or {}, function(success)
					if success then
						GameRules:SendCustomMessage("%s1 has auto-picked " .. getReadableHeroName(PlayerResource:GetSelectedHeroName(playerId)), playerId, -1)
					else
						PlayerResource:GetPlayer(playerId):MakeRandomHeroSelection()
					end
				end)
			end
		end
	end
end

RegisterCustomEventListener("smart_random_hero", function(event)
	local playerId = event.PlayerID
	if GameRules:State_Get() > DOTA_GAMERULES_STATE_HERO_SELECTION then return end
	if PlayerResource:HasSelectedHero(playerId) then return end

	SmartRandom.PickReasons[playerId] = "smart-random"

	EmitGlobalSound("custom.smart_random")
	pickRandomHeroFromList(playerId, SmartRandom.SmartRandomHeroes[playerId] or {}, function(success)
		if success then
			GameRules:SendCustomMessage("%s1 has smart-randomed " .. getReadableHeroName(PlayerResource:GetSelectedHeroName(playerId)), playerId, -1)
		else
			PlayerResource:GetPlayer(playerId):MakeRandomHeroSelection()
		end
	end)
end)

RegisterCustomEventListener("banned_heroes", function(event)
	local eventId = event.eventId
	if SmartRandom.BannedHeroesEventListeners[eventId] then
		SmartRandom.BannedHeroesEventListeners[eventId](event.result)
		SmartRandom.BannedHeroesEventListeners[eventId] = nil
	end
end)
