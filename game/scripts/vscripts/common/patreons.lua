Patreons = Patreons or {}
Patreons.playerSettings = Patreons.playerSettings or {}
Patreons.openPaymentWindows = Patreons.openPaymentWindows or {}

local colorNames = {
	White = Vector(255, 255, 255),
	Red = Vector(200, 0, 0),
	Green = Vector(0, 200, 0),
	Blue = Vector(0, 0, 200),
	Cyan = Vector(0, 200, 200),
	Yellow = Vector(200, 200, 0),
	Pink = Vector(200, 170, 185),
	Maroon = Vector(128, 0, 0),
	Brown = Vector(154, 99, 36),
	Olive = Vector(0, 128, 128),
	Teal = Vector(70, 153, 144),
	Navy = Vector(0, 0, 117),
	Black = Vector(0, 0, 0),
	Orange = Vector(245, 130, 49),
	Lime = Vector(191, 239, 69),
	Purple = Vector(145, 30, 180),
	Magenta = Vector(240, 50, 230),
	Grey = Vector(169, 169, 169),
	Apricot = Vector(255, 216, 177),
	Beige = Vector(255, 250, 200),
	Mint = Vector(170, 255, 195),
	Lavender = Vector(230, 190, 255),
}

function Patreons:GetPlayerSettings(playerId)
	-- TODO: Handle defaults more consistently
	return Patreons.playerSettings[playerId] or { level = 0 }
end

function Patreons:GetPlayerEmblemColor(playerId)
	return colorNames[Patreons:GetPlayerSettings(playerId).emblemColor]
end

function Patreons:SetPlayerSettings(playerId, settings)
	Patreons.playerSettings[playerId] = settings
	CustomNetTables:SetTableValue("game_state", "patreon_bonuses", Patreons.playerSettings)
end

function Patreons:GiveOnSpawnBonus(playerId)
	local hero = PlayerResource:GetSelectedHeroEntity(playerId)
	local patreonSettings = Patreons:GetPlayerSettings(playerId)

	hero:AddItemByName("item_patreon_mango")
end

RegisterCustomEventListener("patreon_toggle_boots", function(data)
	local playerId = data.PlayerID
	local hero = PlayerResource:GetSelectedHeroEntity(playerId)
	if not hero then return end

	local enabled = data.enabled == 1
	local playerBonuses = Patreons:GetPlayerSettings(playerId)
	if playerBonuses.bootsEnabled == enabled then return end

	playerBonuses.bootsEnabled = enabled
	Patreons:SetPlayerSettings(playerId, playerBonuses)
end)

RegisterCustomEventListener("patreon_update_emblem", function(args)
	local playerId = args.PlayerID
	if not colorNames[args.color] then return end

	local playerBonuses = Patreons:GetPlayerSettings(playerId)
	playerBonuses.emblemColor = args.color
	Patreons:SetPlayerSettings(playerId, playerBonuses)
end)

-- TODO: It's not really related to patreon, it'd be better to extract player options to a different module
RegisterCustomEventListener("patreon_update_chat_wheel_favorites", function(args)
	local playerId = args.PlayerID
	local favorites = {}
	for key, value in pairs(args.favorites) do
		if type(key) ~= "string" then error("favorites contains a non-string key") end
		if type(value) ~= "number" then error("favorites contains a non-number value") end

		local index = tonumber(key) + 1
		if type(index) ~= "number" then error("favorites contains a non-number index") end
		if index ~= index or index < 1 or index > 8 then error("favorites contains an index out of range") end

		favorites[index] = value
	end

	local playerBonuses = Patreons:GetPlayerSettings(playerId)
	playerBonuses.chatWheelFavorites = favorites
	Patreons:SetPlayerSettings(playerId, playerBonuses)
end)

local function onPaymentWindowOpenStatusChange(args)
	local playerId = args.PlayerID
	if args.visible == 1 then
		Patreons.openPaymentWindows[playerId] = true
		MatchEvents.RequestDelay = 5
	else
		Patreons.openPaymentWindows[playerId] = nil
		if not next(Patreons.openPaymentWindows) then
			MatchEvents.RequestDelay = MatchEvents.DEFAULT_REQUEST_DELAY
		end
	end
end

RegisterCustomEventListener("patreon:payments:window", onPaymentWindowOpenStatusChange)
RegisterGameEventListener("player_disconnect", function(args)
	args.visible = 0
	onPaymentWindowOpenStatusChange(args)
end)

RegisterCustomEventListener("patreon:payments:create", function(args)
	local targetId = args.paymentTargetID
	local payerId = args.PlayerID
	local steamId = tostring(PlayerResource:GetSteamID(targetId))
	local payerSteamId = tostring(PlayerResource:GetSteamID(payerId))
	local matchId = tonumber(tostring(GameRules:GetMatchID()))

	WebApi:Send(
		"payment/create",
		{ steamId = steamId, payerSteamId = payerSteamId, matchId = matchId, paymentKind = args.paymentKind, provider = args.provider },
		function(response)
			local player = PlayerResource:GetPlayer(payerId)
			if not player then return end

			CustomGameEventManager:Send_ServerToPlayer(player, "patreon:payments:create", {
				id = args.id,
				url = response.url,
			})
		end,
		function(error)
			local player = PlayerResource:GetPlayer(payerId)
			if not player then return end

			CustomGameEventManager:Send_ServerToPlayer(player, "patreon:payments:create", {
				id = args.id,
				error = error,
			})
		end
	)
end)

MatchEvents.ResponseHandlers.paymentUpdate = function(response)
	local payerSteamId = response.payerSteamId
	local playerId = GetPlayerIdBySteamId(payerSteamId)

	if playerId == -1 then return end

	local player = PlayerResource:GetPlayer(playerId)
	if player then
		CustomGameEventManager:Send_ServerToPlayer(player, "patreon:payments:update", response)
	end

	if not response.error then
		local targetId = GetPlayerIdBySteamId(response.steamId)

		local patreonSettings = table.clone(Patreons:GetPlayerSettings(targetId))
		local isUpgrade = patreonSettings.level > 0 and response.level > patreonSettings.level

		patreonSettings.level = response.level
		patreonSettings.endDate = response.endDate
		Patreons:SetPlayerSettings(targetId, patreonSettings)

		if not isUpgrade then
			Patreons:GiveOnSpawnBonus(targetId)
		end

		if payerSteamId ~= response.steamId then
			CustomGameEventManager:Send_ServerToAllClients("patreon:gift:notification", {playerId = targetId, level = response.level})
		end
	end
end