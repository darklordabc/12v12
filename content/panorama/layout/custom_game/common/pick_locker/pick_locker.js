var wait_time = [
	6, // 0 level patreon
	3, // 1 level patreon
	0 // 2 level patreon
]

var localized_text = [
	$.Localize("#HighSupportersOnly"),
	$.Localize("#SupportersOnly"),
	$.Localize("#DOTA_Hero_Selection_LOCKIN"),
]

var interval = 0.3

function _InvokeUpdate(new_time, button) {
	$.Schedule(interval, function() {
		_UpdatePickButton(new_time, button)
	})
}

function _UpdatePickButton(time, button) {
	// waiting until ban phase or pause expires
	if (Game.IsInBanPhase() || Game.IsGamePaused()) { 
		_InvokeUpdate(time, button)
		return
	}

	let lock_text = localized_text[0]
	if (time <= 3) {
		lock_text = localized_text[1]
	}
	
	button.GetChild(0).text = `${lock_text} (${time.toFixed(0)})`
	if (time < interval) {
		button.SetAcceptsFocus(true)
		button.BAcceptsInput(true)
		button.style.saturation = null
		button.style.brightness = null

		button.GetChild(0).text = localized_text[2]
		return
	}
	_InvokeUpdate(time - interval, button)
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

		let label = pick_button.GetChild(0)
		label.style.width = "95%"
		label.style.height = "25px"
		label.style.horizontalAlign = "left"
		label.style.textOverflow = "shrink"

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