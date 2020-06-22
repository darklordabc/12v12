var patreons_levels = 3;
var patreons_game_perks = {
"patreon_perk_str_for_kill_t0": 0,
"patreon_perk_str_for_kill_t1": 1,
"patreon_perk_str_for_kill_t2": 2,
"patreon_perk_agi_for_kill_t0": 0,
"patreon_perk_agi_for_kill_t1": 1,
"patreon_perk_agi_for_kill_t2": 2,
"patreon_perk_int_for_kill_t0": 0,
"patreon_perk_int_for_kill_t1": 1,
"patreon_perk_int_for_kill_t2": 2,
"patreon_perk_cleave_t0": 0,
"patreon_perk_cleave_t1": 1,
"patreon_perk_cleave_t2": 2,
"patreon_perk_cd_after_deadth_t0": 0,
"patreon_perk_cd_after_deadth_t1": 1,
"patreon_perk_cd_after_deadth_t2": 2,
"patreon_perk_manaburn_t0": 0,
"patreon_perk_manaburn_t1": 1,
"patreon_perk_manaburn_t2": 2,
"patreon_perk_mp_regen_t0": 0,
"patreon_perk_mp_regen_t1": 1,
"patreon_perk_mp_regen_t2": 2,
"patreon_perk_hp_regen_t0": 0,
"patreon_perk_hp_regen_t1": 1,
"patreon_perk_hp_regen_t2": 2,
"patreon_perk_bonus_movespeed_t0": 0,
"patreon_perk_bonus_movespeed_t1": 1,
"patreon_perk_bonus_movespeed_t2": 2,
"patreon_perk_bonus_agi_t0": 0,
"patreon_perk_bonus_agi_t1": 1,
"patreon_perk_bonus_agi_t2": 2,
"patreon_perk_bonus_str_t0": 0,
"patreon_perk_bonus_str_t1": 1,
"patreon_perk_bonus_str_t2": 2,
"patreon_perk_bonus_int_t0": 0,
"patreon_perk_bonus_int_t1": 1,
"patreon_perk_bonus_int_t2": 2,
"patreon_perk_bonus_all_stats_t0": 0,
"patreon_perk_bonus_all_stats_t1": 1,
"patreon_perk_bonus_all_stats_t2": 2,
"patreon_perk_attack_range_t0": 0,
"patreon_perk_attack_range_t1": 1,
"patreon_perk_attack_range_t2": 2,
"patreon_perk_bonus_hp_pct_t0": 0,
"patreon_perk_bonus_hp_pct_t1": 1,
"patreon_perk_bonus_hp_pct_t2": 2,
"patreon_perk_cast_range_t0": 0,
"patreon_perk_cast_range_t1": 1,
"patreon_perk_cast_range_t2": 2,
"patreon_perk_cooldown_reduction_t0": 0,
"patreon_perk_cooldown_reduction_t1": 1,
"patreon_perk_cooldown_reduction_t2": 2,
"patreon_perk_damage_t0": 0,
"patreon_perk_damage_t1": 1,
"patreon_perk_damage_t2": 2,
"patreon_perk_evasion_t0": 0,
"patreon_perk_evasion_t1": 1,
"patreon_perk_evasion_t2": 2,
"patreon_perk_lifesteal_t0": 0,
"patreon_perk_lifesteal_t1": 1,
"patreon_perk_lifesteal_t2": 2,
"patreon_perk_mag_resist_t0": 0,
"patreon_perk_mag_resist_t1": 1,
"patreon_perk_mag_resist_t2": 2,
"patreon_perk_spell_amp_t0": 0,
"patreon_perk_spell_amp_t1": 1,
"patreon_perk_spell_amp_t2": 2,
"patreon_perk_spell_lifesteal_t0": 0,
"patreon_perk_spell_lifesteal_t1": 1,
"patreon_perk_spell_lifesteal_t2": 2,
"patreon_perk_status_resistance_t0": 0,
"patreon_perk_status_resistance_t1": 1,
"patreon_perk_status_resistance_t2": 2,
"patreon_perk_outcomming_heal_amplify_t0": 0,
"patreon_perk_outcomming_heal_amplify_t1": 1,
"patreon_perk_outcomming_heal_amplify_t2": 2,
"patreon_perk_debuff_time_t0": 0,
"patreon_perk_debuff_time_t1": 1,
"patreon_perk_debuff_time_t2": 2,
"patreon_perk_bonus_gold_t0": 0,
"patreon_perk_bonus_gold_t1": 1,
"patreon_perk_bonus_gold_t2": 2,
//"patreon_perk_gpm_t0": 0,
//"patreon_perk_gpm_t1": 1,
//"patreon_perk_gpm_t2": 2,
};

var patreonLevel = 0;
var patreonCurrentPerk;

function print(val){
	$.Msg(val);
}

function SetPlayerPatreonLevel(data){
	patreonLevel = data.patreonLevel;
	patreonCurrentPerk = data.patreonCurrentPerk;
	CreatePatreonsGamePerks();
}

function HidePatreonsGamePerksHint(){
	var settingsButton = $("#SetPatreonGamePerkButton")
	$.DispatchEvent( 'DOTAHideTextTooltip', settingsButton);
	settingsButton.SetImage("file://{resources}/layout/custom_game/common/patreon/game_perk/patreon_button_setting_no_glow.png")
}

function ShowPatreonsGamePerksHint(){
	var settingsButton = $("#SetPatreonGamePerkButton")
	$.DispatchEvent( 'DOTAShowTextTooltip', settingsButton, $.Localize("#patreonperktooltip_hint"));
	settingsButton.SetImage("file://{resources}/layout/custom_game/common/patreon/game_perk/patreon_button_setting_glow.png")
}

function ShowPatreonsGamePerks(){
	var perksPanel = $("#PatreonsGamePerkMenu");
	var perksPanelClose = $("#ClosePatreonsPerks");
	perksPanel.visible = true;
	perksPanelClose.visible = true;
}

function HidePatreonsGamePerks(){
	var perksPanel = $("#PatreonsGamePerkMenu");
	var perksPanelClose = $("#ClosePatreonsPerks");
	if(perksPanel != null){
		perksPanel.visible = false;
	}
	if(perksPanelClose != null){
		perksPanelClose.visible = false;
	}
}

function ReloadSetttingButton(){
	var settingPerksButton = $("#SetPatreonGamePerkButton")

	settingPerksButton.SetImage("file://{resources}/layout/custom_game/common/patreon/game_perk/patreon_button_setting_no_glow.png")

	settingPerksButton.SetPanelEvent( "onmouseover", function() {
		ShowPatreonsGamePerksHint();
	} )
	settingPerksButton.SetPanelEvent( "onmouseout", function() {
		HidePatreonsGamePerksHint();
	} )
	settingPerksButton.SetPanelEvent( "onactivate", function() {
		ShowPatreonsGamePerks();
	} )
}

function SetPatreonsPerkButtonAction(panel, perkName){
	panel.SetPanelEvent( "onactivate", function() {
		patreonCurrentPerk = perkName
		var settingPerksButton = $("#SetPatreonGamePerkButton")

		settingPerksButton.SetImage("file://{resources}/layout/custom_game/common/patreon/game_perk/icons/"+perkName+".png")
		GameEvents.SendCustomGameEventToServer( "set_patreon_game_perk", {
			newPerkName: perkName
		} )
		settingPerksButton.SetPanelEvent( "onmouseover", function() {
			$.DispatchEvent( 'DOTAShowTextTooltip', settingPerksButton, $.Localize(perkName+"_tooltip"));
		} )
		settingPerksButton.SetPanelEvent( "onmouseout", function() {
			$.DispatchEvent( 'DOTAHideTextTooltip', settingPerksButton);
		} )
		settingPerksButton.SetPanelEvent( "onactivate", function() {} )

		$("#PatreonsGamePerkMenu").DeleteAsync(0)
		$("#ClosePatreonsPerks").DeleteAsync(0)
	} )

	panel.SetPanelEvent( "onmouseover", function() {
		$.DispatchEvent( 'DOTAShowTextTooltip', panel, $.Localize(perkName+"_tooltip"));
	} )
	panel.SetPanelEvent( "onmouseout", function() {
		$.DispatchEvent( 'DOTAHideTextTooltip', panel);
	} )
}

function UpdateBlockPatreonsPerk(panel, currectPatreonLevel){
	panel.SetPanelEvent( "onmouseover", function() {
		$.DispatchEvent( 'DOTAShowTextTooltip', panel, $.Localize("#patreon_perks_list_error_tier_"+currectPatreonLevel));
	} )
	panel.SetPanelEvent( "onmouseout", function() {
		$.DispatchEvent( 'DOTAHideTextTooltip', panel);
	} )
}
function CreatePatreonsGamePerks(){
	for (var x = 0; x < patreons_levels; x++) {
		var tier = x;
		var patreonGamePerksTier = $.CreatePanel("Panel", $("#PatreonsGamePerksTierList"), "");
		patreonGamePerksTier.AddClass("PatreonGamePerksTier");

		var patreonGamePerksTierHeader = $.CreatePanel("Panel", patreonGamePerksTier, "");
		patreonGamePerksTierHeader.AddClass("PatreonGamePerksTierHeader");

		var patreonGamePerksTierHeaderText = $.CreatePanel("Label", patreonGamePerksTierHeader, "");
		patreonGamePerksTierHeaderText.AddClass("PatreonGamePerksTierHeaderTextMain");
		patreonGamePerksTierHeaderText.AddClass("PatreonGamePerksTierHeaderTextTier"+tier);
		patreonGamePerksTierHeaderText.text = $.Localize("#patreon_game_perk_tolltip_tier_"+tier);

		var perkPanelListForTier = $.CreatePanel("Panel", patreonGamePerksTier, "");
		perkPanelListForTier.AddClass("PerkPanelListForTier");

		for (var key in patreons_game_perks) {
			if (patreons_game_perks[key] == tier){
				var perkPanel = $.CreatePanel("Panel", perkPanelListForTier, "");
				perkPanel.AddClass("GamePerkForPatreon");

				var perkIconImage = $.CreatePanel("Image", perkPanel, "");
				perkIconImage.AddClass("GamePerkImage");
				perkIconImage.SetImage("file://{resources}/layout/custom_game/common/patreon/game_perk/icons/"+key+".png")
				perkIconImage.icon = key

				var perkLabelText = $.CreatePanel("Label", perkPanel, "");
				perkLabelText.AddClass("GamePerkText");
				perkLabelText.text = $.Localize(key);

				if (patreons_game_perks[key] == patreonLevel){
					perkIconImage.AddClass("GamePerkImageHover");
					SetPatreonsPerkButtonAction(perkIconImage, key);
				}else{
					perkIconImage.AddClass("GamePerkImageNotAvailable");
					perkLabelText.AddClass("GamePerkTextNotAvailable");
					UpdateBlockPatreonsPerk(perkIconImage, patreons_game_perks[key]);
				}
			}
		}
		if (patreonCurrentPerk != null){
				var settingPerksButton = $("#SetPatreonGamePerkButton")

				settingPerksButton.SetImage("file://{resources}/layout/custom_game/common/patreon/game_perk/icons/"+patreonCurrentPerk+".png")
				settingPerksButton.SetPanelEvent( "onmouseover", function() {
					$.DispatchEvent( 'DOTAShowTextTooltip', settingPerksButton, $.Localize(patreonCurrentPerk+"_tooltip"));
				} )
				settingPerksButton.SetPanelEvent( "onmouseout", function() {
					$.DispatchEvent( 'DOTAHideTextTooltip', settingPerksButton);
				} )
				settingPerksButton.SetPanelEvent( "onactivate", function() {} )
				$("#PatreonsGamePerkMenu").DeleteAsync(0)
				$("#ClosePatreonsPerks").DeleteAsync(0)
		}
	}
	if (patreonCurrentPerk == null){
		$.Schedule(3, function() {
			var perksPanel = $("#PatreonsGamePerkMenu");
			var perksPanelClose = $("#ClosePatreonsPerks");
			if (!perksPanel.visible){
				perksPanel.visible = true;
				perksPanelClose.visible = true;
			}
		});
    }
}
function PatreonsGamePerkInit(){
	GameEvents.Subscribe('reload_patreon_perk_setings_button', ReloadSetttingButton);
	GameEvents.Subscribe('return_patreon_level_and_perks', SetPlayerPatreonLevel);
	GameEvents.SendCustomGameEventToServer("check_patreon_level_and_perks", {});
}
PatreonsGamePerkInit();
