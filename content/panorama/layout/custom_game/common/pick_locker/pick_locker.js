var wait_time = [
	6, // 0 level patreon
	3, // 1 level patreon
	0 // 2 level patreon
]

function _UpdatePickButton(time, button) {
	button.GetChild(0).text = $.Localize("#SupportersOnly") + " (" + time + ")"
	if (time <= 0) {
		button.SetAcceptsFocus(true)
		button.BAcceptsInput(true)
		button.style.saturation = 1
		button.style.brightness = 1
		button.GetChild(0).text = $.Localize("#DOTA_Hero_Selection_LOCKIN")
		return
	}
	$.Schedule(1, function() {
		_UpdatePickButton(time-1, button)
	})
}

function _InitPickLocker(level) {
	$.Msg("Locking pick button, patreon level: ", level)
	let pick_button = FindDotaHudElement("LockInButton")

	if (level < 2) {
		let time = wait_time[level]
		pick_button.SetAcceptsFocus(false)
		pick_button.BAcceptsInput(false)
		pick_button.style.saturation = 0.0
		pick_button.style.brightness = 0.2
		pick_button.GetChild(0).style.textTransform = "lowercase"
		pick_button.GetChild(0).text = $.Localize("#SupportersOnly") + " (" + time + ")"
		_UpdatePickButton(time, pick_button)
	}
}

SubscribeToNetTableKey("game_state", "patreon_bonuses", function (patreon_bonuses) {
	let local_stats = patreon_bonuses[Game.GetLocalPlayerID()];
	let level = 0
	if (local_stats && local_stats.level) {
		level = local_stats.level
	}
	_InitPickLocker(level)
})