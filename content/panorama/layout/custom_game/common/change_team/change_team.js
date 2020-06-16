function ChangeTeam() {
	GameEvents.SendCustomGameEventToServer("PlayerChangeTeam", {});
}
function ShowTeamChangePanel() {
	$("#ChangeTeamPanel").SetHasClass("show", true)
}
function HideTeamChangePanel() {
	$("#ChangeTeamPanel").SetHasClass("show", false)
}
function ChangeTeamInit() {
	GameEvents.Subscribe("ShowTeamChangePanel", ShowTeamChangePanel);
	GameEvents.Subscribe("HideTeamChangePanel", HideTeamChangePanel);
}

ChangeTeamInit();
