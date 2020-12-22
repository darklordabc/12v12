ShuffleTeam = class({})
DEFAULT_MMR = 1500
BASE_BONUS = 10
MIN_DIFF = 500
BONUS_MMR_STEP = 100
BONUS_FOR_STEP = 3
MAX_BONUS = 100
MAX_PLAYERS_IN_TEAM = 12
LinkLuaModifier("modifier_bonus_for_weak_team_in_mmr", "modifier_bonus_for_weak_team_in_mmr", LUA_MODIFIER_MOTION_NONE)

function ShuffleTeam:SortInMMR()
	if GameOptions:OptionsIsActive("no_mmr_sort") then
		return
	end
	self.multGold = 1
	self.weakTeam = 0
	self.mmrDiff = 0
	local players = {}
	local playersStats = CustomNetTables:GetTableValue("game_state", "player_stats");
	if not playersStats then return end
	GameRules:SetCustomGameTeamMaxPlayers( DOTA_TEAM_GOODGUYS, 12 )
	GameRules:SetCustomGameTeamMaxPlayers( DOTA_TEAM_BADGUYS, 12)

	local phantomPartyID = 456332
	for playerId = 0, 23 do
		if not playersStats[tostring(playerId)] then
			playersStats[tostring(playerId)] = {
				rating = DEFAULT_MMR
			}
		end
		local playerRating = playersStats[tostring(playerId)].rating and playersStats[tostring(playerId)].rating or 0
		local partyID =  tonumber(tostring(PlayerResource:GetPartyID(playerId)))
		if PlayerResource:GetConnectionState(playerId) == DOTA_CONNECTION_STATE_NOT_YET_CONNECTED or partyID <= 0 then
			phantomPartyID = phantomPartyID + 1
			partyID = phantomPartyID
		end
		players[playerId] = {
			partyID = partyID,
			mmr = playerRating
		}
	end
	
	local partiesMMR = {}

	for playerId, data in pairs(players) do
		local partyID = data.partyID + 1
		partiesMMR[partyID] = partiesMMR[partyID] or {}
		partiesMMR[partyID].players = partiesMMR[partyID].players or {}
		partiesMMR[partyID].mmr = (partiesMMR[partyID].mmr or 0) + data.mmr
		table.insert(partiesMMR[partyID].players, playerId)
	end

	local sortedParties = {}
	for _, v in pairs(partiesMMR) do table.insert(sortedParties, v) end
	table.sort(sortedParties, function(a,b)
		return a.mmr > b.mmr
	end)

	-- This is just a table deepcopy function I found on stackexchange, feel free to replace it with whatever equivelant 12v12 has or move it to a utility functions file
	local function deepcopy(orig, copies)
		copies = copies or {}
		local orig_type = type(orig)
		local copy
		if orig_type == 'table' then
			if copies[orig] then
				copy = copies[orig]
			else
				copy = {}
				copies[orig] = copy
				for orig_key, orig_value in next, orig, nil do
					copy[deepcopy(orig_key, copies)] = deepcopy(orig_value, copies)
				end
				setmetatable(copy, deepcopy(getmetatable(orig), copies))
			end
		else -- number, string, boolean, etc
			copy = orig
		end
		return copy
	end
	
	local SortTeams = function()
	
		local getTeamAverageMMR = function(teams, teamId)
			local playersCount = #teams[teamId].players
			if playersCount > 0 then
				return teams[teamId].mmr / playersCount
			end
			return 0
		end
	
		local emptyTeams = {
			[2] = {
				players = {},
				mmr = 0
			}, 
			[3] = {
				players = {},
				mmr = 0
			}
		}
	
		local teamsA = deepcopy(emptyTeams)
		local teamsB = deepcopy(emptyTeams)
		local teamsC = deepcopy(emptyTeams)
		
		-- Sorting type A: add highest remaining party to lower team until out of parties
		
		for _, partyData in pairs(sortedParties) do -- For each party in the party list
			local teamId = getTeamAverageMMR(teamsA, 2) >= getTeamAverageMMR(teamsA, 3) and 3 or 2 -- Select team with lowest mmr
			
			-- Add highest mmr party to selected team
			for _, playerId in pairs(partyData.players) do -- For each player in highest mmr party
				-- This will split up the final party in very few scenarios
				-- where the mmr values are very unbalanced and the lowest
				-- mmr party has less than half the mmr of any solo player
				if #teamsA[teamId].players == MAX_PLAYERS_IN_TEAM then -- If selected team is full
					teamId = teamId == 2 and 3 or 2 -- Select other team
				end
				
				table.insert(teamsA[teamId].players, playerId) -- Add player to team
				teamsA[teamId].mmr = teamsA[teamId].mmr + players[playerId].mmr -- Add players mmr to team
			end
		end
			
		--======================================================================================--
			
		-- Sorting type B: add highest and lowest to first team, second highest/lowest to second team, repeat until out of parties
		
		for partyID = 1, #sortedParties do -- For each partyID (used instead of pairs() because I grab some parties from the lower end)
			local teamId = getTeamAverageMMR(teamsA, 2) >= getTeamAverageMMR(teamsA, 3) and 3 or 2 -- Select team with lowest mmr
			
			-- Add highest mmr party to selected team
			if partyID <= math.ceil(#sortedParties/2) then
				for _, playerId in pairs(sortedParties[partyID].players) do -- For each player in highest party
					if #teamsB[teamId].players == MAX_PLAYERS_IN_TEAM then -- If selected team is full
						teamId = teamId == 2 and 3 or 2 -- Select other team
					end
					table.insert(teamsB[teamId].players, playerId) -- Add player to team
					teamsB[teamId].mmr = teamsB[teamId].mmr + players[playerId].mmr -- Add players mmr to team
				end
			end
			-- Add lowest mmr party to selected team
			if partyID < math.ceil(#sortedParties/2) then
				for _, playerId in pairs(sortedParties[#sortedParties - partyID + 1].players) do -- For each player in highest party
					if #teamsB[teamId].players == MAX_PLAYERS_IN_TEAM then -- If selected team is full
						teamId = teamId == 2 and 3 or 2 -- Select other team
					end
					table.insert(teamsB[teamId].players, playerId) -- Add player to team
					teamsB[teamId].mmr = teamsB[teamId].mmr + players[playerId].mmr -- Add players mmr to team
				end
			end
		end
		
		--======================================================================================--
		
		-- Sorting type C: add highest party to each team then add from top end to lower team and bottom end to higher team
		
		-- Add highest mmr party to team 1
		for _, playerId in pairs(sortedParties[1].players) do -- For each player in highest party
			table.insert(teamsC[2].players, playerId) -- Add player to party
			teamsC[2].mmr = teamsC[2].mmr + players[playerId].mmr -- Add players mmr to party
		end
		
		-- Add second highest mmr party to team 2
		for _, playerId in pairs(sortedParties[2].players) do -- For each player in highest party
			table.insert(teamsC[3].players, playerId) -- Add player to party
			teamsC[3].mmr = teamsC[3].mmr + players[playerId].mmr -- Add players mmr to party
		end
		
		for partyID = 3, math.ceil(#sortedParties/2+1) do -- for each of half the remaining partyID's (used instead of pairs() because I grab some parties from the lower end)
			local teamId = getTeamAverageMMR(teamsA, 2) >= getTeamAverageMMR(teamsA,3) and 3 or 2 -- Select team with lowest mmr
			
			-- Add highest mmr party to lower team
			for _, playerId in pairs(sortedParties[partyID].players) do -- For each player in highest party
				if #teamsC[teamId].players == MAX_PLAYERS_IN_TEAM then -- If selected team is full
					teamId = teamId == 2 and 3 or 2 -- Select other team
				end
				table.insert(teamsC[teamId].players, playerId) -- Add player to party
				teamsC[teamId].mmr = teamsC[teamId].mmr + players[playerId].mmr -- Add players mmr to party
			end
			
			teamId = teamId == 2 and 3 or 2 -- Select other team
			
			-- Add lowest mmr party to higher team
			if partyID < math.ceil(#sortedParties/2+1) then
				for _, playerId in pairs(sortedParties[#sortedParties - partyID + 3].players) do -- For each player in highest party
					if #teamsC[teamId].players == MAX_PLAYERS_IN_TEAM then -- If selected team is full
						teamId = teamId == 2 and 3 or 2 -- Select other team
					end
					table.insert(teamsC[teamId].players, playerId) -- Add player to party
					teamsC[teamId].mmr = teamsC[teamId].mmr + players[playerId].mmr -- Add players mmr to party
				end
			end
		end
		
		--======================================================================================--
		
		-- Find the difference in mmr for each algorithm
		mmrDiffA = math.floor(math.abs(teamsA[2].mmr - teamsA[3].mmr) / MAX_PLAYERS_IN_TEAM)
		mmrDiffB = math.floor(math.abs(teamsB[2].mmr - teamsB[3].mmr) / MAX_PLAYERS_IN_TEAM)
		mmrDiffC = math.floor(math.abs(teamsC[2].mmr - teamsC[3].mmr) / MAX_PLAYERS_IN_TEAM)
		
		-- Return the algorithm with the lowest MMR difference
		return (mmrDiffA < mmrDiffB and mmrDiffA < mmrDiffC) and teamsA or mmrDiffB < mmrDiffC and teamsB or teamsC
	end
	
	local sortedTeams = SortTeams()
	
	self.weakTeam = sortedTeams[2].mmr < sortedTeams[3].mmr and 2 or 3
	self.mmrDiff = math.floor(math.abs(sortedTeams[2].mmr - sortedTeams[3].mmr) / MAX_PLAYERS_IN_TEAM)

	--DEBUG PRINT PART
	for teamId,teamData in pairs(sortedTeams) do
		AutoTeam:Debug("")
		AutoTeam:Debug("Team: ["..teamId.."]")
		for id, playerId in pairs(teamData.players) do
			
			-- Add each player to their team
			local player = PlayerResource:GetPlayer(playerId)
			if player then
				player:SetTeam(teamId)
				PlayerResource:SetCustomTeamAssignment(playerId,teamId)
			end
		
			AutoTeam:Debug(id .. " pid: "..playerId .. "	> "..playerId.." MMR: "..players[playerId].mmr .. " TEAM: "..players[playerId].partyID)
		end
	end
	
	AutoTeam:Debug("")
	AutoTeam:Debug("Team 2 averages MMR: " .. math.floor(teams[2].mmr/MAX_PLAYERS_IN_TEAM))
	AutoTeam:Debug("Team 3 averages MMR: " .. math.floor(teams[3].mmr/MAX_PLAYERS_IN_TEAM))	
end

function ShuffleTeam:SendNotificationForWeakTeam()
	if GameOptions:OptionsIsActive("no_bonus_for_weak_team") or GameOptions:OptionsIsActive("no_mmr_sort") then
		return
	end
	if not self.bonusPct then return end
	CustomGameEventManager:Send_ServerToTeam(self.weakTeam, "WeakTeamNotification", { bonusPct = self.bonusPct, mmrDiff = self.mmrDiff})
end

function ShuffleTeam:GiveBonusToHero(player)
	local hero = player:GetAssignedHero()
	if hero then
		hero:AddNewModifier(hero, nil, "modifier_bonus_for_weak_team_in_mmr", { duration = -1, bonusPct = self.bonusPct })
	else
		Timers:CreateTimer(2, function()
			self:GiveBonusToHero(player)
		end)
	end
end

function ShuffleTeam:GiveBonusToWeakTeam()
	if GameOptions:OptionsIsActive("no_bonus_for_weak_team") or GameOptions:OptionsIsActive("no_mmr_sort") then
		return
	end
	if self.mmrDiff < MIN_DIFF then return end
	self.bonusPct = math.min(BASE_BONUS + (math.floor((self.mmrDiff - MIN_DIFF) / BONUS_MMR_STEP)) * BONUS_FOR_STEP, MAX_BONUS)
	self.multGold = 1 + self.bonusPct / 100
	for playerId = 0, 23 do
		local player = PlayerResource:GetPlayer(playerId)
		if player and (player:GetTeam() == self.weakTeam) then
			self:GiveBonusToHero(player)
		end
	end
end
