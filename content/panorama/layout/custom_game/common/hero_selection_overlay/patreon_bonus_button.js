var isPatreon = false;

function OnMouseOver() {
	if (isPatreon) return;
	$.DispatchEvent('DOTAShowTextTooltip', '#patreon_bonus_button_tooltip');
}

var updatedOnce = false;
SubscribeToNetTableKey('game_state', 'patreon_bonuses', function(patreonBonuses) {
	var playerBonuses = patreonBonuses[Game.GetLocalPlayerID()];
	if (!playerBonuses) return;

	if (updatedOnce) return;
	updatedOnce = true;

	isPatreon = playerBonuses.level > 0;
	$('#PatreonBonusButton').enabled = isPatreon;
});

SubscribeToNetTableKey('game_state', 'patreon_bonuses', function(patreonBonuses) {
	var localStats = patreonBonuses[Game.GetLocalPlayerID()];
	$('#PatreonBonusButton').SetHasClass('IsPatron', Boolean(localStats && localStats.level));
});
