"use strict";

function onClose() {
    $('#Leaderboard').visible = false;
}

function getTableRecord(record, parent, id) {
    let panel = $.CreatePanel('Panel', parent, id);
    panel.BLoadLayoutSnippet('TableRecord');

    panel.FindChildTraverse('Rank').text = record.rank;
    panel.FindChildTraverse('PlayerAvatar').steamid = record.steamId;
    panel.FindChildTraverse('PlayerUserName').steamid = record.steamId;
    panel.FindChildTraverse('Rating').text = record.rating;

    return panel;
}

function updateTable(players) {
    let body = $.GetContextPanel().FindChildTraverse('TableBody');
    body.RemoveAndDeleteChildren();

    players.forEach((player, i) => {
        getTableRecord(player, body);
    });
}


function attachMenuButton(panel) {
    let menu = GetDotaHud().FindChildTraverse('MenuButtons').FindChildTraverse('ButtonBar');
    let existingPanel = menu.FindChildTraverse(panel.id);

    if (existingPanel)
        existingPanel.DeleteAsync(0.1);

    panel.SetParent(menu);
}

function addMenuButton() {
    let button = $.CreatePanel('Button', $.GetContextPanel(), 'OpenLeaderboard');
    button.SetPanelEvent('onactivate', () => {
        let panel = $('#Leaderboard');
        panel.visible = !panel.visible;
    });

    attachMenuButton(button);
}

(function () {
    $('#Leaderboard').visible = false;
    addMenuButton();

    SubscribeToNetTableKey('game_state', 'leaderboard', (leaderboardObj) => {
        let leaderboard = Object.values(leaderboardObj);
        if (leaderboard.length == 0)
            return;

        leaderboard.forEach((r, i) => r.rank = i + 1);

        updateTable(leaderboard);
    })
})();