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

(function() {
	$.Msg("Locking pick button, patreon level: ", patreonLevel)
	let pick_button = FindDotaHudElement("LockInButton")

	if (patreonLevel < 2) {
		pick_button.SetAcceptsFocus(false)
		pick_button.BAcceptsInput(false)
		pick_button.style.saturation = 0.0
		pick_button.style.brightness = 0.2
		_UpdatePickButton(wait_time[patreonLevel], pick_button)
	}
})()