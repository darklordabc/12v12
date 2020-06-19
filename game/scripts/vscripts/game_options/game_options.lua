if GameOptions == nil then GameOptions = class({}) end

local votesForInitOption = 12

local gameOptions = {
	[0] = {
		name = "super_towers",
		votes = 0,
		players = {}
	},
}

function GameOptions:Init()
	CustomGameEventManager:RegisterListener("PlayerVoteForGameOption",function(_, data)
		self:PlayerVoteForGameOption(data)
	end)
end

function GameOptions:PlayerVoteForGameOption(data)
	if not gameOptions[data.id] then return end
	
	if gameOptions[data.id].players[data.PlayerID] == nil then
		gameOptions[data.id].players[data.PlayerID] = true
		local newValue = gameOptions[data.id].votes + 1
		gameOptions[data.id].votes = newValue
	else
		gameOptions[data.id].players[data.PlayerID] = not gameOptions[data.id].players[data.PlayerID]
		local newValue = -1
		if gameOptions[data.id].players[data.PlayerID] then
			newValue = 1
		end
		gameOptions[data.id].votes = gameOptions[data.id].votes + newValue
	end
	
	local gameOptionsVotesForClient = {}
	for id, option in pairs(gameOptions) do
		gameOptionsVotesForClient[id] = option.votes
	end
	CustomNetTables:SetTableValue("game_state", "game_options", gameOptionsVotesForClient)
end

function GameOptions:OptionsIsActive(name)
	print("option check ", name)
	for _, option in pairs(gameOptions) do 
		if option.name == name then return option.votes >= votesForInitOption end
	end
	return nil
end
