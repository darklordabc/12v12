var hasPatreonStatus = true;
var isPatron = false;
var patreonLevel = 0
var patreonPerks = []
var offPatreonButton  = true
var offVOIconButton  = true
var giftNotificationRemainingTime = 0;
var giftNotificationScheduler = false;
var paymentTargetID = Game.GetLocalPlayerID();
var lastConfirmedDonationTarget = Game.GetLocalPlayerID();
var donation_target_dropdown = false;

$( "#PatreonPerksContainer" ).RemoveAndDeleteChildren()

class PatreonPerk {
	constructor( name, level, overrideImage ) {
		this.panel = $.CreatePanel( "Panel", $( "#PatreonPerksContainer" ), "" )
		this.panel.BLoadLayoutSnippet( "PatreonPerk" )

		this.panel.FindChildTraverse( "PatreonPerkImage" ).SetImage( overrideImage || "file://{resources}/layout/custom_game/common/patreon/perks/" + name + ".png" )

		this.panel.FindChildTraverse( "PatreonPerkTitle" ).text = $.Localize( "#" + name )
		this.panel.FindChildTraverse( "PateonPerkDescription" ).text = $.Localize( "#" + name + "_description" )

		this.access = this.panel.FindChildTraverse( "PatreonPerkAccess" )
		this.level = level
		this.UpdateLevel()

		patreonPerks.push( this )
	}

	UpdateLevel() {
		if ( patreonLevel >= this.level ) {
			this.access.text = $.Localize( "available_perk" )
			this.access.SetHasClass( "Available", true )
		} else {
			if ( this.level < 2 ) {
				this.access.text = ""
			} else {
				this.access.text = $.Localize( "high_tier_supporter_perk" )
			}
			this.access.SetHasClass( "Available", false )
		}
	}
}

GameEvents.Subscribe('is_local_server', function() {
	$('#LocalServerWarningContainer').style.visibility = 'visible';
	$('#LocalServerWarningContainer').style.opacity = '1.0';
});

function CloseLocalServerWarning() {
	$('#LocalServerWarningContainer').style.visibility = 'collapse';
}

function Divider() {
	let panel = $.CreatePanel( "Panel", $( "#PatreonPerksContainer" ), "" )
	panel.AddClass( "Divider" )
}

function OnPatreonButtonPressed() {
    var panel = $('#PatreonWindow');

    panel.visible = !panel.visible;
}

var shouldHideNewMethodsAnnouncement = false;
function hideNewMethodsAnnouncement() {
	shouldHideNewMethodsAnnouncement = true;
	updatePatreonButton();
}

function updatePatreonButton() {
	// TODO: Either remove full button, or revert this change
		var minimizePatreonButton = true;
		$('#PatreonButtonPanel').visible = hasPatreonStatus;
		$('#PatreonButton').visible = !minimizePatreonButton;
	if (offPatreonButton){
		$('#PatreonButtonSmallerImage').visible = minimizePatreonButton;
	}
	// Show icon only when chat wheel is loaded as it's not a common module yet
	if (offVOIconButton){
		$('#VOIcon').visible = Boolean(GameUI.CustomUIConfig().chatWheelLoaded) && Game.GetDOTATime(false, false) <= 120;
	}
	if (Game.GetDOTATime(false, false) > 120){
		$('#CloseVOIconButton').visible = false
	}
	$('#NewMethodsAnnouncement').visible = !shouldHideNewMethodsAnnouncement && !isPatron && $.Language() !== 'russian' && Game.GetDOTATime(false, false) <= 120;
}

function setPaymentWindowVisible(visible) {
	GameEvents.SendCustomGameEventToServer('patreon:payments:window', { visible: visible });
	$('#PaymentWindow').visible = visible;
	$('#SupportButtonPaymentWindow').checked = visible;
	if (visible) {
		updatePaymentWindow();
		donation_target_dropdown.enabled = true;
	} else {
		$('#PaymentConfirmationContainer').visible = visible;
		donation_target_dropdown.enabled = false;
	}
}

/** @param {'success' | 'loading' | { error: string }} status */
function setPaymentWindowStatus(status) {
	var isError = typeof status === 'object';
	$('#PaymentWindowBody').visible = status === 'success';
	$('#PaymentWindowLoader').visible = status === 'loading';
	$('#PaymentWindowError').visible = isError;
	if (isError) {
		$('#PaymentWindowErrorMessage').text = status.error;
	}
}

function togglePaymentWindowVisible() {
	setPaymentWindowVisible(!$('#PaymentWindow').visible);
}

function ShowPaymentConfirmationWindow() {
	$('#PaymentConfirmationAvatar').steamid = Game.GetPlayerInfo(paymentTargetID).player_steamid;
	$('#PaymentConfirmationAvatarLabel').text = Players.GetPlayerName(paymentTargetID);
	$('#PaymentConfirmationContainer').style.visibility = 'visible';
}

function ConfirmPaymentTarget() {
	$('#PaymentConfirmationContainer').style.visibility = 'collapse';
	lastConfirmedDonationTarget = paymentTargetID;
	updatePaymentWindow()
}

function ResetPaymentTarget() {
	$('#PaymentConfirmationContainer').style.visibility = 'collapse';
}

var createPaymentRequest = createEventRequestCreator('patreon:payments:create');

var paymentWindowUpdateListener;
var paymentWindowPostUpdateTimer;
function updatePaymentWindow() {
	if (paymentTargetID != lastConfirmedDonationTarget && paymentTargetID != Game.GetLocalPlayerID()) {
		ShowPaymentConfirmationWindow();
		return;
	}

	if (paymentWindowUpdateListener != null) {
		GameEvents.Unsubscribe(paymentWindowUpdateListener);
	}

	if (paymentWindowPostUpdateTimer != null) {
		$.CancelScheduled(paymentWindowPostUpdateTimer);
	}

	setPaymentWindowStatus('loading');

	var provider;
	for (var child of $('#PaymentWindowProviders').Children()) {
		if (child.checked) {
			provider = child.GetAttributeString("value", undefined);
		}
	}

	var paymentKind;
	for (var child of $('#PaymentWindowPaymentKinds').Children()) {
		if (child.checked) {
			paymentKind = child.GetAttributeString("value", undefined);
		}
	}

	var requestData = { provider: provider, paymentKind: paymentKind, paymentTargetID: paymentTargetID };
	paymentWindowUpdateListener = createPaymentRequest(requestData, function(response) {
		if (response.url != null) {
			$('#PaymentWindowBody').SetURL(response.url);
			paymentWindowPostUpdateTimer = $.Schedule(1, function() {
				paymentWindowPostUpdateTimer = undefined;
				setPaymentWindowStatus('success');
			});
		} else {
			setPaymentWindowStatus({ error: response.error || 'Unknown error' });
		}
	});
}

function openUpgradePaymentWindow() {
	$('#PaymentWindowPaymentKinds').visible = false;
	$('#PaymentWindowPaymentKindsUpgradeTo2').checked = true;
	setPaymentWindowVisible(true);
}

function openPurchasePaymentWindow(value) {
	for (var child of $('#PaymentWindowProviders').Children()) {
		if (child.GetAttributeString("value", undefined) === value) {
			child.checked = true;
		}
	}

	setPaymentWindowVisible(true);
}

GameEvents.Subscribe('patreon:payments:update', function(response) {
	if (response.error) {
		setPaymentWindowStatus({ error: response.error });
	} else {
		setPaymentWindowVisible(false);
	}
});

function SetPatreonLevel( level ) {
	patreonLevel = level

	let visible1 = false
	let visible2 = false
	let visible3 = false
	let visible4 = false
	let visible5 = false

	if ( level < 1 ) {
		visible1 = true
		visible2 = true
	} else {
		if ( level < 2 ) {
			visible3 = true
		} else {
			visible4 = true
		}

		visible5 = true
	}
	$( "#IsNotPatreonText" ).visible = visible1
	$( "#PatreonSupportButtons" ).visible = visible2
	$( "#PatreonSupporter" ).visible = visible3
	$( "#PatreonSupporterHigh" ).visible = visible4
	$( "#ThanksText" ).visible = visible5
}

function ClosePatreonButton() {
	$("#PatreonButtonSmallerImage").visible = false
	$("#ClosePatreonButton").visible = false
	offPatreonButton = false
	$("#CloseVOIconButton").style.marginRight = "0px";
}

function ShowClosePatreonButton() {
	$("#ClosePatreonButton").visible = true
}

function HideClosePatreonButton() {
	$("#ClosePatreonButton").visible = false
}

function ShowVOIconButton() {
	var panel = $("#VOIcon");
	$.DispatchEvent( 'DOTAShowTextTooltip', panel, $.Localize('#votooltip'));
	$("#CloseVOIconButton").visible = true
}

function HideVOIconButton() {
	var panel = $("#VOIcon");
	$.DispatchEvent( 'DOTAHideTextTooltip', panel);
	$("#CloseVOIconButton").visible = false
}

function CloseVOIconButton() {
	$("#VOIcon").visible = false
	$("#CloseVOIconButton").visible = false
	offVOIconButton = false
}

$.GetContextPanel().RemoveClass('IsPatron');

new PatreonPerk( "our_thanks_and_appreciation", 1 )
Divider()
new PatreonPerk( "supporter_perks_low", 1 )
Divider()
new PatreonPerk( "first_pick_low", 1 )
Divider()
new PatreonPerk( "instant_transfer", 1 )
Divider()
new PatreonPerk( "immune_kick_troll", 1 )
Divider()

new PatreonPerk( "first_pick_high", 2 )
Divider()
new PatreonPerk( "supporter_perks_high", 2 )
//Divider()

SetPatreonLevel( 0 )

SubscribeToNetTableKey('game_state', 'patreon_bonuses', function (data) {
	UpdatePaymentTargetList(data);

	var status = data[Game.GetLocalPlayerID()];
	if (!status) return;

	hasPatreonStatus = true;
	isPatron = status.level > 0;
	$.GetContextPanel().SetHasClass('IsPatron', isPatron);
	updatePatreonButton();

	SetPatreonLevel( status.level )

	var isAutoControlled = status.endDate != null;
	//$('#PatreonSupporterUpgrade').visible = isAutoControlled && status.level < 2;

	//$('#PatreonSupporterStatusExpiriesIn').visible = isAutoControlled;

	//if (isAutoControlled) {
	//	var endDate = new Date(status.endDate);
	//	var daysLeft = Math.ceil((endDate - Date.now()) / 1000 / 60 / 60 / 24);
	//	$('#PatreonSupporterStatus').SetDialogVariable('support_days_left', daysLeft);
	//	$('#PatreonSupporterStatus').SetDialogVariable('support_end_date', formatDate(endDate));
	//}
});

GameEvents.Subscribe('patreon:gift:notification', function(data) {
	$('#GiftNotificationAvatar').steamid =  Game.GetPlayerInfo(data.playerId).player_steamid
	$('#GiftNotificationName').text = Players.GetPlayerName(data.playerId)
	$('#GiftNotificationLabel').text = $.Localize('#received_gift_' + data.level)
	$('#GiftNotificationPanel').style.opacity = 1;

	Particles.CreateParticle("particles/patreon_gift_tier_" + data.level + ".vpcf", ParticleAttachment_t.PATTACH_EYES_FOLLOW, 0)
	if (data.level == 1) {
		Game.EmitSound("Waitingforplayers_Boost_Shared")
		Game.EmitSound("Loot_Drop_Stinger_Rare")
	} else if (data.level == 2) {
		Game.EmitSound("Waitingforplayers_Boost_Shared")
		Game.EmitSound("Loot_Drop_Stinger_Ancient")
	}

	giftNotificationRemainingTime = 8;
	if (giftNotificationScheduler) {
		$.CancelScheduled(giftNotificationScheduler);
	}
	giftNotificationScheduler = $.Schedule(0.1, GiftNotificationTick);
});

function GiftNotificationTick() {
	giftNotificationRemainingTime -= 0.1;
	if (giftNotificationRemainingTime > 0) {
		giftNotificationScheduler = $.Schedule(0.1, GiftNotificationTick);
	} else {
		$('#GiftNotificationPanel').style.opacity = 0;
		giftNotificationScheduler = false;
	}
}

function UpdatePaymentTargetList(patreonData) {
	if (donation_target_dropdown) {
		for(var id = 0; id <= 23; id++) {
			if (Players.IsValidPlayerID(id)) {
				if (patreonData[id] && patreonData[id].level > 0) {
					var this_player_option = $('#PatreonOption' + id);
					if (this_player_option) {
						this_player_option.DeleteAsync(0)
					}
				}
			}
		}
	} else {
		var dropdown_parent = $('#PaymentWindowUserSelectorContainer');
		donation_target_dropdown = $.CreatePanel('DropDown', dropdown_parent, 'PaymentWindowDropDown');
		var layout_string = '<root><DropDown style="margin-left: 5px;" oninputsubmit="updatePaymentWindow()" >';
		var local_id = Game.GetLocalPlayerID();

		layout_string += `<Label text="${Players.GetPlayerName(local_id)}" id="PatreonOption${local_id}" onmouseover="UpdatePaymentTarget(${local_id})" />`;

		for(var id = 0; id <= 23; id++) {
			if (Players.IsValidPlayerID(id) && id != local_id) {
				if (!patreonData[id] || patreonData[id].level <= 0) {
					layout_string += `<Label text="${Players.GetPlayerName(id)}" id="PatreonOption${id}" onmouseover="UpdatePaymentTarget(${id})" />`;
				}
			}
		}
		layout_string = layout_string + '</DropDown></root>';
		donation_target_dropdown.BLoadLayoutFromString(layout_string, false, true);

		donation_target_dropdown.SetSelected("PatreonOption" + local_id);
		UpdatePaymentTarget(local_id);
	}
}

function UpdatePaymentTarget(id) {
	$('#PaymentWindowAvatar').steamid = Game.GetPlayerInfo(id).player_steamid;
	paymentTargetID = id;
	if (paymentTargetID == Game.GetLocalPlayerID()) {
		lastConfirmedDonationTarget = Game.GetLocalPlayerID();
	}
}

setInterval(updatePatreonButton, 1000);
$('#PatreonWindow').visible = false;
setPaymentWindowVisible(false);