"use strict";

let onClose = () => {
    $.GetContextPanel().visible = false;
}

let getTableRecord = (record, parent, id) => {
    let panel = $.CreatePanel('Panel', parent, id);
    panel.BLoadLayoutSnippet('TableRecord');

    panel.FindChildTraverse('Rank').text = record.rank;
    panel.FindChildTraverse('playerAvatar').steamid = record.steamId;
    panel.FindChildTraverse('playerUserName').steamid = record.steamId;
    panel.FindChildTraverse('Rating').text = record.rating;

    return panel;
}

let updateTable = (players) => {
    let body = $.GetContextPanel().FindChildTraverse('TableBody');
    body.RemoveAndDeleteChildren();

    players.forEach((player, i) => {
        getTableRecord(player, body, `player_${i}`);
    });
}

let addMenuButton = () => {
    let button = $.CreatePanel('Button', $.GetContextPanel(), 'OpenLeaderboard');
    button.SetPanelEvent('onactivate', () => {
        let panel = $.GetContextPanel();
        panel.visible = !panel.visible;
    });

    $.Utils.AttachMenuButton(button);
}

(function () {
    let players = [];
    for (let i = 0; i < 100; i++)
        players.push({
            rank: 20,
            steamId: 76561197988355984,
            rating: 1000
        });

    addMenuButton();
    updateTable(players);
    $.GetContextPanel().visible = false;
})();