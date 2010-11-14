/*
 * TNTagView.j
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
@import <AppKit/AppKit.j>

TNTagsControllerNodeReadyNotification = @"TNTagsControllerNodeReadyNotification";

/*! @ingroup archipelcore
    Tagging view
*/
@implementation TNTagsController : CPObject
{
    @outlet CPView      mainView            @accessors(readonly);

    TNStropheConnection _connection         @accessors(property=connection);
    TNPubSubController  _pubsubController   @accessors(property=pubSubController);
    TNPubSubNode        _pubsubTagsNode;

    CPButton            _buttonSave;
    CPTokenField        _tokenFieldTags;
    id                  _currentRosterItem;
}


//#pragma mark -
//#pragma mark Initialization

/*! Configure the view at cib awaking
*/
- (void)awakeFromCib
{
    var frame = [mainView frame],
        bundle = [CPBundle bundleForClass:[self class]],
        gradBG = [[CPImage alloc] initWithContentsOfFile:[bundle pathForResource:@"gradientGray2.png"]],
        tokenFrame;

    [mainView setBackgroundColor:[CPColor colorWithPatternImage:gradBG]];
    [mainView setAutoresizingMask:CPViewHeightSizable | CPViewWidthSizable];

    _currentRosterItem  = nil;

    _tokenFieldTags = [CPTokenField textFieldWithStringValue:@"" placeholder:@"You can't assign tags here" width:CPRectGetWidth(frame) - 45];
    tokenFrame = [_tokenFieldTags frame];
    tokenFrame.origin = CPPointMake(0.0, 1.0);
    [_tokenFieldTags setFrame:tokenFrame];
    [_tokenFieldTags setAutoresizingMask:CPViewWidthSizable];
    [_tokenFieldTags setDelegate:self];
    [mainView addSubview:_tokenFieldTags];


    _buttonSave = [CPButton buttonWithTitle:@"Tag" bezelStyle:CPRoundedBezelStyle];
    [_buttonSave setAutoresizingMask:CPViewMinXMargin];
    [_buttonSave setFrameOrigin:CPPointMake(CPRectGetWidth(frame) - CPRectGetWidth([_buttonSave frame]) - 3, 3)];
    [_buttonSave setTarget:self];
    [_buttonSave setAction:@selector(performSetTags:)];
    [_buttonSave setEnabled:NO];

    [mainView addSubview:_buttonSave];

    [[CPNotificationCenter defaultCenter] addObserver:self selector:@selector(didRosterItemChange:) name:TNArchipelNotificationRosterSelectionChanged object:nil];
    [[CPNotificationCenter defaultCenter] addObserver:self selector:@selector(didRetrieveSubscriptions:) name:TNStrophePubSubSubscriptionsRetrievedNotification object:nil];
}


//#pragma mark -
//#pragma mark Utility methods

/*! return all tags used for the given JID
    @param aJID the JID to match
    @return CPArray containings the tags associated to the JID
*/
- (CPArray)getTagsForJID:(CPString)aJID
{
    var ret = [CPArray array];

    for (var i = 0; i < [[_pubsubTagsNode content] count]; i++)
    {
        var tag = [[[_pubsubTagsNode content] objectAtIndex:i] firstChildWithName:@"tag"];

        if ([tag valueForAttribute:@"jid"] == aJID)
            [ret addObject:[tag valueForAttribute:@"name"]];
    }

    return ret;
}

/*! send retract for all given tags items of a JID
    @param aJID the JID to match
*/
- (void)removeAllTagsForJID:(CPString)aJID
{
    for (var i = 0; i < [[_pubsubTagsNode content] count]; i++)
    {
        var item    = [[_pubsubTagsNode content] objectAtIndex:i],
            tag     = [item firstChildWithName:@"tag"];

        if ([tag valueForAttribute:@"jid"] == aJID)
            [_pubsubTagsNode retractItemWithID:[item valueForAttribute:@"id"]];
    }
}

/*! called when pubsub is recovered
*/
- (void)didRetrieveSubscriptions:(CPNotification)aNotification
{
    var server = [TNStropheJID stropheJIDWithString:@"pubsub." + [[_connection JID] domain]],
        nodeName = @"/archipel/tags";

    _pubsubTagsNode = [_pubsubController nodeWithName:nodeName];

    if (!_pubsubTagsNode)
        [_pubsubController subscribeToNodeWithName:nodeName server:server nodeDelegate:self];
    else
    {
        [_pubsubTagsNode setDelegate:self];
        [_pubsubTagsNode retrieveItems];
    }

}

//#pragma mark -
//#pragma mark Notifications handlers

/*! this handler is triggered when user changes the selected item in roster
    It will populate the content of the CPTokenField with entity tags
    @param aNotification CPNotification the notification that triggers the message
*/
- (void)didRosterItemChange:(CPNotification)aNotification
{
    _currentRosterItem = [aNotification object];

    [_tokenFieldTags setObjectValue:[]];

    if ([_currentRosterItem class] !== TNStropheContact)
    {
        [_buttonSave setEnabled:NO];

        [_tokenFieldTags setPlaceholderString:@"You can't assign tags here"];
        [_tokenFieldTags setEnabled:NO];
        [_tokenFieldTags setObjectValue:[]];
    }
    else
    {
        [_buttonSave setEnabled:YES];

        [_tokenFieldTags setPlaceholderString:@"Enter coma separated tags"];
        [_tokenFieldTags setEnabled:YES];

        if (_currentRosterItem)
            [_tokenFieldTags setObjectValue:[self getTagsForJID:[_currentRosterItem JID]]];

    }
}


//#pragma mark -
//#pragma mark Actions

/*! Action that will remove all tags of the current entity, and readd the new ones
    @param sender the sender of the action
*/
- (IBAction)performSetTags:(id)sender
{
    if ([_currentRosterItem class] != TNStropheContact)
        return;

    [self removeAllTagsForJID:[_currentRosterItem JID]];

    var content = [_tokenFieldTags objectValue];

    for (var i = 0; i < [content count]; i++)
    {
        var tag = [content objectAtIndex:i];

        [_pubsubTagsNode publishItem:[TNXMLNode nodeWithName:@"tag" andAttributes:{@"jid": [_currentRosterItem JID], @"name": tag}]]
    }
}


//#pragma mark -
//#pragma mark Delegates

/*! delegate of CPTokenField that will return the list of available tags
*/
- (void)tokenField:(CPTokenField)aTokenField completionsForSubstring:(CPString)aSubstring indexOfToken:(int)anIndex indexOfSelectedItem:(int)anIndex
{
    var availableTags = [CPArray array];

    for (var i = 0; i < [[_pubsubTagsNode content] count]; i++)
    {
        var tag = [[[[_pubsubTagsNode content] objectAtIndex:i] firstChildWithName:@"tag"] valueForAttribute:@"name"];

        if ((tag.indexOf(aSubstring) != -1) && ![availableTags containsObject:tag])
            [availableTags addObject:tag];
    }

    return availableTags;
}

/*! delegate of TNPubSubNode that will recover the content of the node after an event
*/
- (void)pubSubNode:(TNPubSubNode)aPubSubMode receivedEvent:(TNStropheStanza)aStanza
{
    [_pubsubTagsNode retrieveItems];
}

- (void)pubSubNode:(TNPubSubNode)aPubSubMode subscribed:(BOOL)isSubscribed
{
    if (isSubscribed)
        [_pubsubTagsNode retrieveItems];
}

- (void)pubSubNode:(TNPubSubNode)aPubSubMode retrievedItems:(BOOL)isRetrieved
{
    if (isRetrieved)
        [[CPNotificationCenter defaultCenter] postNotificationName:TNTagsControllerNodeReadyNotification object:aPubSubMode];
}


@end