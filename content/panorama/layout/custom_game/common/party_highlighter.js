var parties;

function HighlightByParty(player_id, label) {
	let party_id = parties[player_id];

	if (party_id != undefined) {
		label.SetHasClass("Party_" + party_id, true);
	} else {
		label.SetHasClass("NoParty", true);
	}
}

SubscribeToNetTableKey("game_state", "parties", (value) => {
	parties = value;
});
