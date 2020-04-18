let getHUDRoot = () => {
    var parent = $.GetContextPanel().GetParent();
    while(parent.GetParent() != null)
        parent = parent.GetParent();

    return parent;
}

/**
 * List of useful panels
 */
let getPanelsList = () => {
    let hudRoot = getHUDRoot();

    return {
        HUDRoot: hudRoot,
        MenuButtons: hudRoot.FindChildTraverse('MenuButtons').FindChildTraverse('ButtonBar'),
    }
}

let attachMenuButton = (panel) => {
    let menu = $.Utils.Panels.MenuButtons;
    let existingPanel = menu.FindChildTraverse(panel.id);
    panel.SetParent(existingPanel);

    if (existingPanel)
        existingPanel.DeleteAsync(0.1);

    panel.SetParent(menu);
}

/**
 * API Utils Section
 */
let getUtils = () => {
    return {
        Panels: getPanelsList(),
        AttachMenuButton: attachMenuButton
    }
}

(function () {
    //if (!$.Utils)
        $.Utils = getUtils();
})();