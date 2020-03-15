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

function _InitPickLocker(data) {
	$.Msg("Locking pick button, patreon level: ", data.level)
	let pick_button = FindDotaHudElement("LockInButton")

	if (data.level < 2) {
		let time = wait_time[data.level]
		pick_button.SetAcceptsFocus(false)
		pick_button.BAcceptsInput(false)
		pick_button.style.saturation = 0.0
		pick_button.style.brightness = 0.2
		pick_button.GetChild(0).style.textTransform = "lowercase"
		pick_button.GetChild(0).text = $.Localize("#SupportersOnly") + " (" + time + ")"
		_UpdatePickButton(time, pick_button)
	}
}

(function() {
	GameEvents.SendCustomGameEventToServer("request_patreon_level", {})
	GameEvents.Subscribe("report_patreon_level", _InitPickLocker)
})()