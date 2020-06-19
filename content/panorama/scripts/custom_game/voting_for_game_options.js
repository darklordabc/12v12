const gameOptions = ["game_option_super_towers"];
const votesForInitOption = 12;

function VotingOptionsInit() {
	const votingPanel = $("#VoteOptionsButtons");
	votingPanel.RemoveAndDeleteChildren();

	const createEventForVoteButton = function (panel, index, optionName) {
		panel.SetPanelEvent("onactivate", function () {
			PlayerVote(panel, index);
		});
		panel.SetPanelEvent("onmouseover", function () {
			$.DispatchEvent("DOTAShowTextTooltip", panel, $.Localize(optionName + "_tooltip"));
		});
		panel.SetPanelEvent("onmouseout", function () {
			$.DispatchEvent("DOTAHideTextTooltip", panel);
		});
	};
	gameOptions.forEach((optionName, index) => {
		const newOption = $.CreatePanel("Panel", votingPanel, "GameOption_" + index);
		newOption.BLoadLayoutSnippet("VoteOption");
		newOption.FindChildTraverse("VoteOptionText").text = $.Localize(optionName);
		newOption.vote = false;
		createEventForVoteButton(newOption, index, optionName);
	});

	const removeCancelButton = () => {
		const cancelButton = FindDotaHudElement("CancelAndUnlockButton");
		if (cancelButton) {
			if (!Game.IsInToolsMode()) {
				FindDotaHudElement("CancelAndUnlockButton").DeleteAsync(0);
			}
		} else {
			$.Schedule(0.1, removeCancelButton);
		}
	};
	removeCancelButton();

	SubscribeToNetTableKey("game_state", "game_options", (gameOptions) => {
		for (var id in gameOptions) {
			const optionPanel = $("#GameOption_" + id).FindChildTraverse("VoteOptionTotalVotesText");
			optionPanel.text = gameOptions[id];
			optionPanel.SetHasClass("init", gameOptions[id] >= votesForInitOption);
		}
	});
}
function PlayerVote(panel, id) {
	panel.vote = !panel.vote;
	panel.FindChildTraverse("VoteOptionLocalVote").SetHasClass("choosed", panel.vote);
	GameEvents.SendCustomGameEventToServer("PlayerVoteForGameOption", { id: id });
	panel.FindChildTraverse("VoteOptionButton").SetHasClass("active", panel.vote);
}

VotingOptionsInit();
