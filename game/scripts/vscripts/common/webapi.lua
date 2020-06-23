WebApi = WebApi or {}

local isTesting = IsInToolsMode() and false
local serverHost = IsInToolsMode() and "http://127.0.0.1:5000" or "http://163.172.174.77:8000"
local dedicatedServerKey = GetDedicatedServerKeyV2("1")

function WebApi:Send(path, data, onSuccess, onError)
	local request = CreateHTTPRequestScriptVM("POST", serverHost .. "/api/" .. path)
	if isTesting then
		print("Request to " .. path)
		DeepPrintTable(data)
	end

	request:SetHTTPRequestHeaderValue("Dedicated-Server-Key", dedicatedServerKey)
	if data ~= nil then
		request:SetHTTPRequestRawPostBody("application/json", json.encode(data))
	end

	request:Send(function(response)
		if response.StatusCode == 200 then
			local data = json.decode(response.Body)
			if isTesting then
				print("Response from " .. path .. ":")
				DeepPrintTable(data)
			end
			if onSuccess then
				onSuccess(data, response.StatusCode)
			end
		else
			if isTesting then
				print("Error from " .. path .. ": " .. response.StatusCode)
				if response.Body then
					local status, result = pcall(json.decode, response.Body)
					if status then
						DeepPrintTable(result)
					else
						print(response.Body)
					end
				end
			end
			if onError then
				-- TODO: Is response.Body nullable?
				onError(response.Body or "Unknown error (" .. response.StatusCode .. ")", response.StatusCode)
			end
		end
	end)
end

function WebApi:BeforeMatch()
	local players = {}
	for i = 0, 23 do
		if PlayerResource:IsValidPlayerID(i) then
			table.insert(players, tostring(PlayerResource:GetSteamID(i)))
		end
	end

	local requestBody = {
		customGame = WebApi.customGame,
		mapName = GetMapName(),
		players = players,
	}

	WebApi:Send("match/before", requestBody, function(data)
		local publicStats = {}
		for _,player in ipairs(data.players) do
			local playerId = GetPlayerIdBySteamId(player.steamId)
			if player.patreon["emblemColor"] == nil then
				local colorNames = {
					"White",
					"Red",
					"Green",
					"Blue",
					"Cyan",
					"Yellow",
					"Pink",
					"Maroon",
					"Brown",
					"Olive",
					"Teal",
					"Navy",
					"Black",
					"Orange",
					"Lime",
					"Purple",
					"Magenta",
					"Grey",
					"Apricot",
					"Beige",
					"Mint",
					"Lavender",
				}
				player.patreon["emblemColor"] = colorNames[RandomInt(1, #colorNames)]
			end
			Patreons:SetPlayerSettings(playerId, player.patreon)
			SmartRandom:SetPlayerInfo(playerId, player.smartRandomHeroes, player.smartRandomHeroesError)

			publicStats[playerId] = {
				streak = player.streak,
				bestStreak = player.bestStreak,
				averageKills = player.averageKills,
				averageDeaths = player.averageDeaths,
				averageAssists = player.averageAssists,
				wins = player.wins,
				loses = player.loses,
				rating = player.rating,
			}
		end

		CustomNetTables:SetTableValue("game_state", "player_stats", publicStats)
		CustomNetTables:SetTableValue("game_state", "leaderboard", data.leaderboard)
		CustomNetTables:SetTableValue("game_state", "player_ratings", data.mapPlayersRating)
	end)
end

function WebApi:AfterMatch(winnerTeam)
	if not isTesting then
		if GameRules:IsCheatMode() then return end
		if GameRules:GetDOTATime(false, true) < 60 then return end
	end

	if winnerTeam < DOTA_TEAM_FIRST or winnerTeam > DOTA_TEAM_CUSTOM_MAX then return end
	if winnerTeam == DOTA_TEAM_NEUTRALS or winnerTeam == DOTA_TEAM_NOTEAM then return end

	local requestBody = {
		customGame = WebApi.customGame,
		matchId = isTesting and RandomInt(1, 10000000) or tonumber(tostring(GameRules:GetMatchID())),
		duration = math.floor(GameRules:GetDOTATime(false, true)),
		mapName = GetMapName(),
		winner = winnerTeam,

		players = {}
	}

	for playerId = 0, 23 do
		if PlayerResource:IsValidTeamPlayerID(playerId) and not PlayerResource:IsFakeClient(playerId) then
			local playerData = {
				playerId = playerId,
				steamId = tostring(PlayerResource:GetSteamID(playerId)),
				team = PlayerResource:GetTeam(playerId),

				hero = PlayerResource:GetSelectedHeroName(playerId),
				pickReason = SmartRandom.PickReasons[playerId] or (PlayerResource:HasRandomed(playerId) and "random" or "pick"),
				kills = PlayerResource:GetKills(playerId),
				deaths = PlayerResource:GetDeaths(playerId),
				assists = PlayerResource:GetAssists(playerId),
				level = 0,
				items = {},
			}

			local patreonSettings = Patreons:GetPlayerSettings(playerId)
			-- Always add an update, because chat wheel favorites is a public feature
			playerData.patreonUpdate = patreonSettings

			local hero = PlayerResource:GetSelectedHeroEntity(playerId)
			if IsValidEntity(hero) then
				playerData.level = hero:GetLevel()
				for slot = DOTA_ITEM_SLOT_1, DOTA_STASH_SLOT_6 do
					local item = hero:GetItemInSlot(slot)
					if item then
						table.insert(playerData.items, {
							slot = slot,
							name = item:GetAbilityName(),
							charges = item:GetCurrentCharges()
						})
					end
				end
			end

			table.insert(requestBody.players, playerData)
		end
	end

	if isTesting or #requestBody.players >= 5 then
		WebApi:Send("match/after", requestBody)
	end
end

RegisterGameEventListener("player_connect_full", function()
	if WebApi.firstPlayerLoaded then return end
	WebApi.firstPlayerLoaded = true
	WebApi:BeforeMatch()
end)
