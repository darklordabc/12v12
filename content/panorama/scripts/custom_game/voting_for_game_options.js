const gameOptions = ["Super Towers", "Mega Creeps"];
const votesForInitOption = 12;

function VotingOptionsInit() {
	const votingPanel = $("#VoteOptionsButtons");
	votingPanel.GetParent().GetParent().GetParent().style.marginLeft = "0px";
	votingPanel.RemoveAndDeleteChildren();

	const createEventForVoteButton = function (panel, index) {
		panel.SetPanelEvent("onactivate", function () {
			PlayerVote(panel, index);
		});
	};
	gameOptions.forEach((optionName, index) => {
		const newOption = $.CreatePanel("Panel", votingPanel, "GameOption_" + index);
		newOption.BLoadLayoutSnippet("VoteOption");
		newOption.FindChildTraverse("VoteOptionText").text = optionName;
		newOption.vote = false;
		createEventForVoteButton(newOption, index);
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
