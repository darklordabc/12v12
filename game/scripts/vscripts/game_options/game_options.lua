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
	self.pauseTime = 0
	CustomGameEventManager:RegisterListener("PlayerVoteForGameOption",function(_, data)
		self:PlayerVoteForGameOption(data)
	end)
end

function GameOptions:UpdatePause()
	Timers:RemoveTimer("game_options_unpause")
	Convars:SetFloat("host_timescale", 0.1)

	Timers:CreateTimer(0, function()
		self.pauseTime = self.pauseTime - 0.1
		if self.pauseTime > 0 then
			return 0.1
		else
			return nil
		end
	end)
	Timers:CreateTimer("game_options_unpause",{
		useGameTime = false,
		endTime = self.pauseTime/10,
		callback = function()
			Convars:SetFloat("host_timescale", 1)
			return nil
		end
	})
end

function GameOptions:PlayerVoteForGameOption(data)
	if not gameOptions[data.id] then return end

	if gameOptions[data.id].players[data.PlayerID] == nil then
		gameOptions[data.id].players[data.PlayerID] = true
		local newValue = gameOptions[data.id].votes + 1
		gameOptions[data.id].votes = newValue
		self.pauseTime = self.pauseTime + 3
		self:UpdatePause()
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
