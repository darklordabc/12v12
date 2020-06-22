function ChangeTeam() {
	GameEvents.SendCustomGameEventToServer("PlayerChangeTeam", {});
}
function ShowTeamChangePanel() {
	$("#ChangeTeamPanel").SetHasClass("show", true);
}
function HideTeamChangePanel() {
	$("#ChangeTeamPanel").SetHasClass("show", false);
}
var notidicationHideTimer;
function HideTeamChangeNotification() {
	$("#ChangeTeamNotification").SetHasClass("show", false);
}
function PlayerChangedTeam(data) {
	const notificationPanel = $("#ChangeTeamNotification");
	const createNotification = function () {
		notificationPanel.SetHasClass("show", true);
		const playerInfo = Game.GetPlayerInfo(data.playerId);
		$("#ChangeTeamHeroChangedTeam").BCreateChildren(
			'<DOTAScenePanel hittest="false" id="VotingToKickVotingHeroModel" style="width:210px;height:210px;" unit="' +
				playerInfo.player_selected_hero +
				'" particleonly="false"/>',
		);
		$("#ChangeTeamPlayerText").text = playerInfo.player_name + " " + $.Localize("player_changed_team");
		notidicationHideTimer = $.Schedule(5, HideTeamChangeNotification);
	};
	if (notificationPanel.BHasClass("show")) {
		if (notidicationHideTimer) $.CancelScheduled(notidicationHideTimer);
		HideTeamChangeNotification();
		$.Schedule(0.5, createNotification)
	} else {
		createNotification();
	}
}
function ChangeTeamInit() {
	GameEvents.Subscribe("ShowTeamChangePanel", ShowTeamChangePanel);
	GameEvents.Subscribe("HideTeamChangePanel", HideTeamChangePanel);
	GameEvents.Subscribe("PlayerChangedTeam", PlayerChangedTeam);
}

ChangeTeamInit();
