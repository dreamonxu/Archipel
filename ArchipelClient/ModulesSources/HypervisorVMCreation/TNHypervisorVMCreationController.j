/*
 * TNViewHypervisorControl.j
 *
 * Copyright (C) 2010 Antoine Mercadal <antoine.mercadal@inframonde.eu>
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

@import <Foundation/Foundation.j>

@import <AppKit/CPButton.j>
@import <AppKit/CPButtonBar.j>
@import <AppKit/CPPopUpButton.j>
@import <AppKit/CPSearchField.j>
@import <AppKit/CPTextField.j>
@import <AppKit/CPView.j>
@import <AppKit/CPWindow.j>

@import <TNKit/TNAlert.j>
@import <TNKit/TNTableViewDataSource.j>
@import <TNKit/TNUIKitScrollView.j>

@import "TNVirtualMachineAllocationController.j";
@import "TNVirtualMachineCloneController.j";
@import "TNVirtualMachineDataView.j";
@import "TNVirtualMachineSubscriptionController.j";

var TNArchipelTypeHypervisorControl             = @"archipel:hypervisor:control",
    TNArchipelTypeHypervisorControlRosterVM     = @"rostervm",
    TNArchipelTypeHypervisorControlManage       = @"manage",
    TNArchipelTypeHypervisorControlUnmanage     = @"unmanage",
    TNArchipelPushNotificationHypervisor        = @"archipel:push:hypervisor";

/*! @defgroup  hypervisorvmcreation Module Hypervisor VM Creation
    @desc This module allow to create and delete virtual machines
*/

/*! @ingroup hypervisorvmcreation
    Main controller of the module
*/
@implementation TNHypervisorVMCreationController : TNModule
{
    @outlet CPButtonBar                             buttonBarControl;
    @outlet CPButtonBar                             buttonBarNotManagedVMControl;
    @outlet CPPopUpButton                           popupDeleteMachine;
    @outlet CPSearchField                           fieldFilterVM;
    @outlet CPSearchField                           fieldFilterVMNotManaged;
    @outlet CPTableView                             tableVirtualMachines            @accessors(readonly);
    @outlet CPTableView                             tableVirtualMachinesNotManaged;
    @outlet CPTabView                               tabViewVMs;
    @outlet CPView                                  viewItemManagedVMs;
    @outlet CPView                                  viewItemNotManagedVMs;
    @outlet CPView                                  viewTableContainer;
    @outlet CPView                                  viewTableContainerNotManaged;
    @outlet TNVirtualMachineAllocationController    VMAllocationController;
    @outlet TNVirtualMachineCloneController         VMCloneController;
    @outlet TNVirtualMachineDataView                dataViewVMPrototype;
    @outlet TNVirtualMachineSubscriptionController  VMSubscriptionController;

    CPButton                                        _addSubscriptionButton;
    CPButton                                        _cloneButton;
    CPButton                                        _manageButton;
    CPButton                                        _minusButton;
    CPButton                                        _plusButton;
    CPButton                                        _removeSubscriptionButton;
    CPButton                                        _unmanageButton;
    TNTableViewDataSource                           _virtualMachinesDatasource;
    TNTableViewDataSource                           _virtualMachinesNotManagedDatasource;
}


#pragma mark -
#pragma mark Initialization

/*! called at cib awaking
*/
- (void)awakeFromCib
{
    [viewTableContainer setBorderedWithHexColor:@"#C0C7D2"];
    [viewTableContainerNotManaged setBorderedWithHexColor:@"#C0C7D2"];

    // tab view
    var tabViewItemManagedVM = [[CPTabViewItem alloc] initWithIdentifier:@"tabViewItemManagedVM"],
        tabViewItemNotManagedVM = [[CPTabViewItem alloc] initWithIdentifier:@"tabViewItemNotManagedVM"];

    [tabViewItemManagedVM setLabel:CPLocalizedString(@"Archipel VMs", @"Archipel VMs")];
    [tabViewItemNotManagedVM setLabel:CPLocalizedString(@"Others VMs", @"Others VMs")];
    [tabViewItemManagedVM setView:viewItemManagedVMs];
    [tabViewItemNotManagedVM setView:viewItemNotManagedVMs];

    [tabViewVMs addTabViewItem:tabViewItemManagedVM];
    [tabViewVMs addTabViewItem:tabViewItemNotManagedVM];

    // VM table view
    _virtualMachinesDatasource   = [[TNTableViewDataSource alloc] init];
    [tableVirtualMachines setDelegate:self];
    [tableVirtualMachines setTarget:self];
    [tableVirtualMachines setDoubleAction:@selector(didManagedTableDoubleClick:)];
    [[tableVirtualMachines tableColumnWithIdentifier:@"self"] setDataView:[dataViewVMPrototype duplicate]];
    [tableVirtualMachines setSelectionHighlightStyle:CPTableViewSelectionHighlightStyleNone];
    [tableVirtualMachines setBackgroundColor:[CPColor colorWithHexString:@"F7F7F7"]];

    [_virtualMachinesDatasource setTable:tableVirtualMachines];
    [_virtualMachinesDatasource setSearchableKeyPaths:[@"nickname", @"JID"]];

    [fieldFilterVM setTarget:_virtualMachinesDatasource];
    [fieldFilterVM setAction:@selector(filterObjects:)];
    [tableVirtualMachines setDataSource:_virtualMachinesDatasource];

    _plusButton = [CPButtonBar plusButton];
    [_plusButton setTarget:self];
    [_plusButton setAction:@selector(openNewVirtualMachineWindow:)];
    [_plusButton setToolTip:CPBundleLocalizedString(@"Ask hypervisor to create a new virtual machine", @"Ask hypervisor to create a new virtual machine")];

    _minusButton = [CPButtonBar minusButton];
    [_minusButton setTarget:self];
    [_minusButton setAction:@selector(deleteVirtualMachine:)];
    [_minusButton setToolTip:CPBundleLocalizedString(@"Ask hypervisor to completely destroy all selected virtual machine", @"Ask hypervisor to completely destroy all selected virtual machine")];

    _addSubscriptionButton = [CPButtonBar plusButton];
    [_addSubscriptionButton setImage:[[CPImage alloc] initWithContentsOfFile:[[CPBundle mainBundle] pathForResource:@"IconsButtons/subscription-add.png"] size:CPSizeMake(16, 16)]];
    [_addSubscriptionButton setTarget:self];
    [_addSubscriptionButton setAction:@selector(openAddSubscriptionWindow:)];
    [_addSubscriptionButton setToolTip:CPBundleLocalizedString(@"Ask the virtual machine to add in its contact a user", @"Ask the virtual machine to add in its contact a user")];

    _removeSubscriptionButton = [CPButtonBar plusButton];
    [_removeSubscriptionButton setImage:[[CPImage alloc] initWithContentsOfFile:[[CPBundle mainBundle] pathForResource:@"IconsButtons/subscription-remove.png"] size:CPSizeMake(16, 16)]];
    [_removeSubscriptionButton setTarget:self];
    [_removeSubscriptionButton setAction:@selector(openRemoveSubscriptionWindow:)];
    [_removeSubscriptionButton setToolTip:CPBundleLocalizedString(@"Ask the virtual machine to remove a user from its contact", @"Ask the virtual machine to remove a user from its contact")];

    _cloneButton = [CPButtonBar minusButton];
    [_cloneButton setImage:[[CPImage alloc] initWithContentsOfFile:[[CPBundle mainBundle] pathForResource:@"IconsButtons/branch.png"] size:CPSizeMake(16, 16)]];
    [_cloneButton setTarget:self];
    [_cloneButton setAction:@selector(openCloneVirtualMachineWindow:)];
    [_cloneButton setToolTip:CPBundleLocalizedString(@"Create a clone virtual machine from the selected one", @"Create a clone virtual machine from the selected one")];

    [_minusButton setEnabled:NO];
    [_addSubscriptionButton setEnabled:NO];
    [_removeSubscriptionButton setEnabled:NO];

    _unmanageButton = [CPButtonBar minusButton];
    [_unmanageButton setImage:[[CPImage alloc] initWithContentsOfFile:[[CPBundle mainBundle] pathForResource:@"IconsButtons/unmanage.png"] size:CPSizeMake(16, 16)]];
    [_unmanageButton setTarget:self];
    [_unmanageButton setAction:@selector(unmanageVirtualMachine:)];
    [_unmanageButton setToolTip:CPLocalizedString("Unmanage the virtual machine", "Unmanage the virtual machine")];
    [_unmanageButton setEnabled:NO];

    [buttonBarControl setButtons:[_plusButton, _minusButton, _cloneButton, _addSubscriptionButton, _removeSubscriptionButton, _unmanageButton]];

    // Not managed VM Table View
    _virtualMachinesNotManagedDatasource = [[TNTableViewDataSource alloc] init];
    [tableVirtualMachinesNotManaged setDelegate:self];
    [tableVirtualMachinesNotManaged setTarget:self];
    [tableVirtualMachinesNotManaged setDoubleAction:@selector(didNotManagedTableDoubleClick:)];
    [[tableVirtualMachinesNotManaged tableColumnWithIdentifier:@"self"] setDataView:[dataViewVMPrototype duplicate]];
    [tableVirtualMachinesNotManaged setSelectionHighlightStyle:CPTableViewSelectionHighlightStyleNone];
    [tableVirtualMachinesNotManaged setBackgroundColor:[CPColor colorWithHexString:@"F7F7F7"]];

    [_virtualMachinesNotManagedDatasource setTable:tableVirtualMachinesNotManaged];
    [_virtualMachinesNotManagedDatasource setSearchableKeyPaths:[@"JID"]];

    [fieldFilterVMNotManaged setTarget:_virtualMachinesNotManagedDatasource];
    [fieldFilterVMNotManaged setAction:@selector(filterObjects:)];
    [tableVirtualMachinesNotManaged setDataSource:_virtualMachinesNotManagedDatasource];

    _manageButton = [CPButtonBar plusButton];
    [_manageButton setImage:[[CPImage alloc] initWithContentsOfFile:[[CPBundle mainBundle] pathForResource:@"IconsButtons/manage.png"] size:CPSizeMake(16, 16)]];
    [_manageButton setTarget:self];
    [_manageButton setAction:@selector(manageVirtualMachine:)];
    [_manageButton setEnabled:NO];
    [_manageButton setToolTip:CPLocalizedString(@"Ask hypervisor to manage this virtual machine", @"Ask hypervisor to manage this virtual machine")];

    [buttonBarNotManagedVMControl setButtons:[_manageButton]];

    [VMAllocationController setDelegate:self];
    [VMSubscriptionController setDelegate:self];
    [VMCloneController setDelegate:self];
}


#pragma mark -
#pragma mark TNModule overrides

/*! called when module is loaded
*/
- (void)willLoad
{
    [super willLoad];

    [self registerSelector:@selector(_didReceivePush:) forPushNotificationType:TNArchipelPushNotificationHypervisor];

    var center = [CPNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(_reload:) name:TNStropheRosterAddedContactNotification object:nil];
    [center addObserver:self selector:@selector(_reload:) name:TNStropheContactPresenceUpdatedNotification object:nil];
    [center postNotificationName:TNArchipelModulesReadyNotification object:self];

    [tableVirtualMachines setDelegate:nil];
    [tableVirtualMachines setDelegate:self];
    [tableVirtualMachinesNotManaged setDelegate:nil];
    [tableVirtualMachinesNotManaged setDelegate:self];

    [self populateVirtualMachinesTable];
}

/*! called when the module hides
*/
- (void)willHide
{
    [VMCloneController closeWindow:nil];
    [VMSubscriptionController closeAddSubscriptionWindow:nil];
    [VMSubscriptionController closeRemoveSubscriptionWindow:nil];
    [VMAllocationController closeWindow:nil];

    [super willHide];
}

/*! called when module is unloaded
*/
- (void)willUnload
{
    [_virtualMachinesDatasource removeAllObjects];
    [_virtualMachinesNotManagedDatasource removeAllObjects];
    [tableVirtualMachines reloadData];
    [tableVirtualMachinesNotManaged reloadData];

    [super willUnload];
}

/*! called when MainMenu is ready
*/
- (void)menuReady
{
    [[_menu addItemWithTitle:CPBundleLocalizedString(@"Create new virtual machine", @"Create new virtual machine") action:@selector(openNewVirtualMachineWindow:) keyEquivalent:@""] setTarget:self];
    [[_menu addItemWithTitle:CPBundleLocalizedString(@"Delete virtual machine", @"Delete virtual machine") action:@selector(deleteVirtualMachine:) keyEquivalent:@""] setTarget:self];
    [_menu addItem:[CPMenuItem separatorItem]];
    [[_menu addItemWithTitle:CPBundleLocalizedString(@"Clone this virtual machine", @"Clone this virtual machine") action:@selector(openCloneVirtualMachineWindow:) keyEquivalent:@""] setTarget:self];
    [_menu addItem:[CPMenuItem separatorItem]];
    [[_menu addItemWithTitle:CPBundleLocalizedString(@"Add a user subscription", @"Add a user subscription") action:@selector(openAddSubscriptionWindow:) keyEquivalent:@""] setTarget:self];
    [[_menu addItemWithTitle:CPBundleLocalizedString(@"Remove a user subscription", @"Remove a user subscription") action:@selector(openRemoveSubscriptionWindow:) keyEquivalent:@""] setTarget:self];
}

/*! called when permissions changes
*/
- (void)permissionsChanged
{
    var tableManagedCondition = ([tableVirtualMachines numberOfSelectedRows] > 0),
        tableNotManagedCondition = ([tableVirtualMachinesNotManaged numberOfSelectedRows] > 0);

    [self setControl:_manageButton enabledAccordingToPermission:@"manage" specialCondition:tableNotManagedCondition];
    [self setControl:_unmanageButton enabledAccordingToPermission:@"unmanage" specialCondition:tableManagedCondition];
    [self setControl:_plusButton enabledAccordingToPermission:@"alloc"];
    [self setControl:_minusButton enabledAccordingToPermission:@"free" specialCondition:tableManagedCondition];
    [self setControl:_cloneButton enabledAccordingToPermission:@"clone" specialCondition:tableManagedCondition];
    [self setControl:_addSubscriptionButton enabledAccordingToPermission:@"subscription_add" specialCondition:tableManagedCondition];
    [self setControl:_removeSubscriptionButton enabledAccordingToPermission:@"subscription_remove" specialCondition:tableManagedCondition];

    if (![self currentEntityHasPermission:@"alloc"])
        [VMAllocationController closeWindow:nil];

    if (![self currentEntityHasPermission:@"subscription_add"])
        [VMSubscriptionController closeAddSubscriptionWindow:nil];

    if (![self currentEntityHasPermission:@"subscription_remove"])
        [VMSubscriptionController closeRemoveSubscriptionWindow:nil];

    [self tableViewSelectionDidChange:nil];

    [self populateVirtualMachinesTable];
}

#pragma mark -
#pragma mark Notification handlers

/*! called when an Archipel push is recieved
    @param somePushInfo CPDictionary containing the push information
*/
- (BOOL)_didReceivePush:(CPDictionary)somePushInfo
{
    var sender  = [somePushInfo objectForKey:@"owner"],
        type    = [somePushInfo objectForKey:@"type"],
        change  = [somePushInfo objectForKey:@"change"],
        date    = [somePushInfo objectForKey:@"date"];

    [self populateVirtualMachinesTable];

    return YES;
}

/*! reload the content of the table when contact add or presence changes
    @param aNotification the notification
*/
- (void)_reload:(CPNotification)aNotification
{
    if ([_entity XMPPShow] != TNStropheContactStatusOffline)
        [self populateVirtualMachinesTable];
}

/*! reoload the table when a VM change it's status
    @param aNotification the notification
*/
- (void)_didChangeVMStatus:(CPNotification)aNotif
{
    [tableVirtualMachines reloadData];
    [tableVirtualMachinesNotManaged reloadData];
}

/*! update the GUI according to the selected entity in table
    @param aNotification the notification
*/
- (void)tableViewSelectionDidChange:(CPNotification)aNotification
{
    switch ([aNotification object])
    {
        case tableVirtualMachines:
            [_minusButton setEnabled:NO];
            [_cloneButton setEnabled:NO];
            [_unmanageButton setEnabled:NO];
            [_addSubscriptionButton setEnabled:NO];
            [_removeSubscriptionButton setEnabled:NO];

            var condition = ([tableVirtualMachines numberOfSelectedRows] > 0);

            [self setControl:_minusButton enabledAccordingToPermission:@"free" specialCondition:condition];
            [self setControl:_cloneButton enabledAccordingToPermission:@"clone" specialCondition:condition];
            [self setControl:_addSubscriptionButton enabledAccordingToPermission:@"subscription_add" specialCondition:condition];
            [self setControl:_removeSubscriptionButton enabledAccordingToPermission:@"subscription_remove" specialCondition:condition];
            [self setControl:_unmanageButton enabledAccordingToPermission:@"unmanage" specialCondition:condition];

        case tableVirtualMachinesNotManaged:
            [_manageButton setEnabled:NO];
            var condition = ([tableVirtualMachinesNotManaged numberOfSelectedRows] > 0);
            [self setControl:_manageButton enabledAccordingToPermission:@"manage" specialCondition:condition];
    }
}


#pragma mark -
#pragma mark Utilities

/*! will populate the table of virtual machine according to permissions
    if entity has rostervm permissions, the it will ask for the hyperisor's roster,
    otherwise it will populate according to the user roster
*/
- (void)populateVirtualMachinesTable
{
    if ([self currentEntityHasPermission:@"rostervm"])
        [self getHypervisorRoster];
    else
    {
        [_virtualMachinesDatasource removeAllObjects];
        [_virtualMachinesNotManagedDatasource removeAllObjects];
        for (var i = 0; i < [[[[TNStropheIMClient defaultClient] roster] contacts] count]; i++)
        {
            var contact = [[[[TNStropheIMClient defaultClient] roster] contacts] objectAtIndex:i];

            if (([[[TNStropheIMClient defaultClient] roster] analyseVCard:[contact vCard]] == TNArchipelEntityTypeVirtualMachine)
                && [[contact resources] count]
                && ([[contact resources] objectAtIndex:0] == [[_entity JID] node]))
            {
                [_virtualMachinesDatasource addObject:contact];
                [[CPNotificationCenter defaultCenter] addObserver:self selector:@selector(_didChangeVMStatus:) name:TNStropheContactPresenceUpdatedNotification object:contact];
            }
        }
        [tableVirtualMachines reloadData];
        [tableVirtualMachinesNotManaged reloadData];
    }
}


#pragma mark -
#pragma mark Actions

/*! add double clicked vm to roster if not present or go to virtual machine
    @param sender the sender of the action
*/
- (IBAction)didManagedTableDoubleClick:(id)aSender
{
    var vm = [_virtualMachinesDatasource objectAtIndex:[tableVirtualMachines selectedRow]];

    if (![[[TNStropheIMClient defaultClient] roster] containsJID:[vm JID]])
    {
        var alert = [TNAlert alertWithMessage:CPBundleLocalizedString(@"Adding contact", @"Adding contact")
                                    informative:CPBundleLocalizedString(@"Would you like to add ", @"Would you like to add ") + [vm nickname] + CPBundleLocalizedString(@" to your roster", @" to your roster")
                                     target:self
                                     actions:[[CPBundleLocalizedString(@"Add contact", @"Add contact"), @selector(performAddToRoster:)], [CPBundleLocalizedString(@"Cancel", @"Cancel"), nil]]];
        [alert setUserInfo:vm];
        [alert runModal];
    }
}

/*! add double clicked vm to roster if not present or go to virtual machine
    @param sender the sender of the action
*/
- (IBAction)didNotManagedTableDoubleClick:(id)aSender
{
    [self manageVirtualMachine:aSender];
}

/*! ask the hypervisor to manage selected virtual machines
    @param sender the sender of the action
*/
- (IBAction)manageVirtualMachine:(id)aSender
{
    if ([tableVirtualMachinesNotManaged numberOfSelectedRows] <= 0)
    {
        [TNAlert showAlertWithMessage:CPBundleLocalizedString(@"Error", @"Error")
                          informative:CPLocalizedString(@"You must select at least a virtual machine", @"You must select at least a virtual machine")];
        return;
    }

    var titleMessage = CPLocalizedString("Manage virtual machine", "Manage virtual machine"),
        informativeMessage = CPLocalizedString(@"Are you sure you want Archipel to manage this virtual machine?", @"Are you sure you want Archipel to manage this virtual machine?");

    if ([tableVirtualMachinesNotManaged numberOfSelectedRows] > 1)
    {
        titleMessage = CPLocalizedString("Manage virtual machines", "Manage virtual machines");
        informativeMessage = CPLocalizedString(@"Are you sure you want Archipel to manage these virtual machines?", @"Are you sure you want Archipel to manage these virtual machines?");
    }

    var vms = [_virtualMachinesNotManagedDatasource objectsAtIndexes:[tableVirtualMachinesNotManaged selectedRowIndexes]],
        alert = [TNAlert alertWithMessage:titleMessage
                                informative:informativeMessage
                                 target:self
                                 actions:[[CPLocalizedString(@"Manage", @"Manage"), @selector(performManage:)], [CPBundleLocalizedString(@"Cancel", @"Cancel"), nil]]];
    [alert setUserInfo:vms];
    [alert runModal];
}

/*! unmanage selected virtual machines
    @param sender the sender of the action
*/
- (IBAction)unmanageVirtualMachine:(id)aSender
{
    if ([tableVirtualMachines numberOfSelectedRows] <= 0)
    {
        [TNAlert showAlertWithMessage:CPBundleLocalizedString(@"Error", @"Error")
                          informative:CPLocalizedString(@"You must select at least a virtual machine", @"You must select at least a virtual machine")];
        return;
    }

    var titleMessage = CPLocalizedString("Manage virtual machine", "Manage virtual machine"),
        informativeMessage = CPLocalizedString(@"Are you sure you want Archipel to manage this virtual machine?", @"Are you sure you want Archipel to manage this virtual machine?");

    if ([tableVirtualMachines numberOfSelectedRows] > 1)
    {
        titleMessage = CPLocalizedString("Unmanage virtual machines", "Umnanage virtual machines");
        informativeMessage = CPLocalizedString(@"Are you sure you want Archipel to unmanage these virtual machines?", @"Are you sure you want Archipel to unmanage these virtual machines?");
    }

    var vms = [_virtualMachinesDatasource objectsAtIndexes:[tableVirtualMachines selectedRowIndexes]],
        alert = [TNAlert alertWithMessage:titleMessage
                                informative:informativeMessage
                                 target:self
                                 actions:[[CPLocalizedString(@"Unmanage", @"Unmanage"), @selector(performUnmanage:)], [CPBundleLocalizedString(@"Cancel", @"Cancel"), nil]]];
    [alert setUserInfo:vms];
    [alert runModal];
}

/*! delete selected virtual machines
    @param sender the sender of the action
*/
- (IBAction)deleteVirtualMachine:(id)aSender
{
    [VMAllocationController deleteVirtualMachine];
}

/*! Opens the clone virtual machine window
    @param sender the sender of the action
*/
- (IBAction)openCloneVirtualMachineWindow:(id)aSender
{
    [self requestVisible];
    if (![self isVisible])
        return;

    if ([tableVirtualMachines numberOfSelectedRows] != 1)
    {
         [TNAlert showAlertWithMessage:CPBundleLocalizedString(@"Error", @"Error")
                           informative:CPBundleLocalizedString(@"You must select one (and only one) virtual machine", @"You must select one (and only one) virtual machine")];
         return;
    }

    [VMCloneController openWindow:_cloneButton];
}

/*! open the add subscription window
    @param sender the sender of the action
*/
- (IBAction)openNewVirtualMachineWindow:(id)aSender
{
    [self requestVisible];
    if ([self isVisible])
        [VMAllocationController openWindow:_plusButton];
}

/*! open the add subscription window
    @param sender the sender of the action
*/
- (IBAction)openAddSubscriptionWindow:(id)aSender
{
    [self requestVisible];
    if (![self isVisible])
        return;

    if ([tableVirtualMachines numberOfSelectedRows] != 1)
    {
         [TNAlert showAlertWithMessage:CPBundleLocalizedString(@"Error", @"Error")
                           informative:CPBundleLocalizedString(@"You must select one (and only one) virtual machine", @"You must select one (and only one) virtual machine")];
         return;
    }

    [VMSubscriptionController openAddSubsctiptionWindow:_addSubscriptionButton];
}

/*! open the add subscription window
    @param sender the sender of the action
*/
- (IBAction)openRemoveSubscriptionWindow:(id)aSender
{
    [self requestVisible];
    if (![self isVisible])
        return;

    if ([tableVirtualMachines numberOfSelectedRows] != 1)
    {
         [TNAlert showAlertWithMessage:CPBundleLocalizedString(@"Error", @"Error")
                           informative:CPBundleLocalizedString(@"You must select one (and only one) virtual machine", @"You must select one (and only one) virtual machine")];
         return;
    }

    [VMSubscriptionController openRemoveSubscriptionWindow:_removeSubscriptionButton];
}


#pragma mark -
#pragma mark XMPP Controls

/*! add given given virtual machine to roster
    @param someUserInfo info from TNAlert
*/
- (void)performAddToRoster:(id)someUserInfo
{
    var vm = someUserInfo;

    [[[TNStropheIMClient defaultClient] roster] addContact:[vm JID] withName:[[vm JID] bare] inGroupWithPath:nil];
    [[[TNStropheIMClient defaultClient] roster] askAuthorizationTo:[vm JID]];
    [[[TNStropheIMClient defaultClient] roster] authorizeJID:[vm JID]];
}

/*! ask hypervisor to manage virtual machines
    @param someVirtualMachines CPArray of virtual machines
*/
- (void)performManage:(CPArray)someVirtualMachines
{
    var stanza = [TNStropheStanza iqWithType:@"set"];

    [stanza addChildWithName:@"query" andAttributes:{"xmlns": TNArchipelTypeHypervisorControl}];
    [stanza addChildWithName:@"archipel" andAttributes:{
        "action": TNArchipelTypeHypervisorControlManage}];

    for (var i = 0; i < [someVirtualMachines count]; i++)
    {
        var vm = [someVirtualMachines objectAtIndex:i];
        [stanza addChildWithName:@"item" andAttributes:{"jid": [vm JID]}];
        [stanza up];
    }

    [self setModuleStatus:TNArchipelModuleStatusWaiting];
    [_entity sendStanza:stanza andRegisterSelector:@selector(_didPerformManage:) ofObject:self];
}

- (BOOL)_didPerformManage:(TNStropheStanza)aStanza
{
    if ([aStanza type] == @"result")
    {
        [self setModuleStatus:TNArchipelModuleStatusReady];
    }
    else
    {
        [self handleIqErrorFromStanza:aStanza];
        [self setModuleStatus:TNArchipelModuleStatusError];
    }

    return NO;
}

/*! ask hypervisor to unmanage virtual machines
    @param someVirtualMachines CPArray of virtual machines
*/
- (void)performUnmanage:(CPArray)someVirtualMachines
{
    var stanza = [TNStropheStanza iqWithType:@"set"];

    [stanza addChildWithName:@"query" andAttributes:{"xmlns": TNArchipelTypeHypervisorControl}];
    [stanza addChildWithName:@"archipel" andAttributes:{
        "action": TNArchipelTypeHypervisorControlUnmanage}];

    for (var i = 0; i < [someVirtualMachines count]; i++)
    {
        var vm = [someVirtualMachines objectAtIndex:i];
        [stanza addChildWithName:@"item" andAttributes:{"jid": [vm JID]}];
        [stanza up];
    }

    [self setModuleStatus:TNArchipelModuleStatusWaiting];
    [_entity sendStanza:stanza andRegisterSelector:@selector(_didPerformUnmanage:) ofObject:self];
}

- (BOOL)_didPerformUnmanage:(TNStropheStanza)aStanza
{
    if ([aStanza type] == @"result")
    {
        [self setModuleStatus:TNArchipelModuleStatusReady];
    }
    else
    {
        [self handleIqErrorFromStanza:aStanza];
        [self setModuleStatus:TNArchipelModuleStatusError];
    }

    return NO;
}

/*! get the hypervisor roster content
*/
- (void)getHypervisorRoster
{
    var stanza = [TNStropheStanza iqWithType:@"get"];

    [stanza addChildWithName:@"query" andAttributes:{"xmlns": TNArchipelTypeHypervisorControl}];
    [stanza addChildWithName:@"archipel" andAttributes:{
        "action": TNArchipelTypeHypervisorControlRosterVM}];

    [self setModuleStatus:TNArchipelModuleStatusWaiting];
    [_entity sendStanza:stanza andRegisterSelector:@selector(_didReceiveHypervisorRoster:) ofObject:self];
}

/*! compute the answer of the hypervisor about its roster
    @param aStanza TNStropheStanza containing hypervisor answer
*/
- (BOOL)_didReceiveHypervisorRoster:(TNStropheStanza)aStanza
{
    if ([aStanza type] == @"result")
    {
        var queryItems  = [aStanza childrenWithName:@"item"],
            center      = [CPNotificationCenter defaultCenter];

        [_virtualMachinesDatasource removeAllObjects];
        [_virtualMachinesNotManagedDatasource removeAllObjects];

        for (var i = 0; i < [queryItems count]; i++)
        {
            var JID = [TNStropheJID stropheJIDWithString:[[queryItems objectAtIndex:i] text]];

            // @TODO: do not check for nil value later
            // but for the moment, keep compatibility with older version of Agent
            if (![[queryItems objectAtIndex:i] valueForAttribute:@"managed"] || [[queryItems objectAtIndex:i] valueForAttribute:@"managed"] == "True")
            {
                var entry   = [[[TNStropheIMClient defaultClient] roster] contactWithBareJID:JID];

                if (entry)
                {
                   if ([[[TNStropheIMClient defaultClient] roster] analyseVCard:[entry vCard]] == TNArchipelEntityTypeVirtualMachine)
                   {
                       [_virtualMachinesDatasource addObject:entry];
                       [center addObserver:self selector:@selector(_didChangeVMStatus:) name:TNStropheContactPresenceUpdatedNotification object:entry];
                   }
                }
                else
                {
                    var contact = [TNStropheContact contactWithConnection:nil JID:JID group:nil];
                    [contact setNickname:@"This machine is not in your roster. Double click to add it."];
                    [_virtualMachinesDatasource addObject:contact];
                }
            }
            else
            {
                var contact = [TNStropheContact contactWithConnection:nil JID:JID group:nil];
                [contact setNickname:@"This virtual machine is not managed by Archipel. Double click on it to manage."];

                [_virtualMachinesNotManagedDatasource addObject:contact];
            }
        }

        [tableVirtualMachines reloadData];
        [tableVirtualMachinesNotManaged reloadData];
        [self setModuleStatus:TNArchipelModuleStatusReady];
    }
    else
    {
        [self handleIqErrorFromStanza:aStanza];
        [self setModuleStatus:TNArchipelModuleStatusError];
    }

    return NO;
}

/*! remove a virtual machine from the roster
*/
- (void)performRemoveFromRoster:(id)someUserInfo
{
    [[[TNStropheIMClient defaultClient] roster] removeContact:someUserInfo];
}

@end



// add this code to make the CPLocalizedString looking at
// the current bundle.
function CPBundleLocalizedString(key, comment)
{
    return CPLocalizedStringFromTableInBundle(key, nil, [CPBundle bundleForClass:TNHypervisorVMCreationController], comment);
}