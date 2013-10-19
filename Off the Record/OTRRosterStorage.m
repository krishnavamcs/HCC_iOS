//
//  OTRRosterStorage.m
//  Off the Record
//
//  Created by David on 10/18/13.
//  Copyright (c) 2013 Chris Ballinger. All rights reserved.
//

#import "OTRRosterStorage.h"

#import "OTRManagedBuddy.h"
#import "OTRManagedAccount.h"

#import "OTRAccountsManager.h"
#import "OTRManagedGroup.h"

#import "OTRConstants.h"

@implementation OTRRosterStorage


- (BOOL)configureWithParent:(XMPPRoster *)aParent queue:(dispatch_queue_t)queue
{
    return YES;
}

- (void)beginRosterPopulationForXMPPStream:(XMPPStream *)stream
{
    
}

- (void)endRosterPopulationForXMPPStream:(XMPPStream *)stream
{
    
}

- (void)handleRosterItem:(NSXMLElement *)item xmppStream:(XMPPStream *)stream
{
    NSLog(@"Item: %@",item);
    [MagicalRecord saveUsingCurrentThreadContextWithBlockAndWait:^(NSManagedObjectContext *localContext) {
        NSString *jidStr = [item attributeStringValueForName:@"jid"];
        XMPPJID *jid = [[XMPPJID jidWithString:jidStr] bareJID];
        
        OTRManagedBuddy * user = [self buddyWithJID:jid xmppStream:stream];
        
        NSString *subscription = [item attributeStringValueForName:@"subscription"];
        if ([subscription isEqualToString:@"remove"])
        {
            if (user)
            {
                [user MR_deleteEntity];
            }
        }
        else
        {
            if (user)
            {
                user.displayName = [item attributeStringValueForName:@"name"];
                OTRManagedGroup * group = [OTRManagedGroup fetchOrCreateWithName:@"buddy test"];
                [group addBuddiesObject:user];
                
            }
        }
    }];
}

- (void)handlePresence:(XMPPPresence *)presence xmppStream:(XMPPStream *)stream
{
    [MagicalRecord saveUsingCurrentThreadContextWithBlockAndWait:^(NSManagedObjectContext *localContext) {
        OTRManagedBuddy * user = [self buddyWithJID:[presence from] xmppStream:stream];
        if (user && ![presence isErrorPresence]) {
            OTRBuddyStatus buddyStatus;
            switch (presence.intShow)
            {
                case 0  :
                    buddyStatus = OTRBUddyStatusDnd;
                    break;
                case 1  :
                    buddyStatus = OTRBuddyStatusXa;
                    break;
                case 2  :
                    buddyStatus = OTRBuddyStatusAway;
                    break;
                case 3  :
                    buddyStatus = OTRBuddyStatusAvailable;
                    break;
                case 4  :
                    buddyStatus = OTRBuddyStatusAvailable;
                    break;
                default :
                    buddyStatus = OTRBuddyStatusOffline;
                    break;
            }
            [user newStatusMessage:[presence status] status:buddyStatus incoming:YES];
        }

    }];
}

- (BOOL)userExistsWithJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream
{
    OTRManagedBuddy * user = [OTRManagedBuddy fetchWithName:[jid bare] account:[self accountForStrem:stream]];
    if (user) {
        return YES;
    }
    return NO;
}

- (void)clearAllResourcesForXMPPStream:(XMPPStream *)stream
{
    
}

- (void)clearAllUsersAndResourcesForXMPPStream:(XMPPStream *)stream
{
    [MagicalRecord saveWithBlock:^(NSManagedObjectContext *localContext) {
        OTRManagedAccount * account = [self accountForStrem:stream];
        [account.buddies enumerateObjectsUsingBlock:^(OTRManagedBuddy * buddy, BOOL *stop) {
            [buddy MR_deleteEntity];
        }];
    }];
}

- (NSArray *)jidsForXMPPStream:(XMPPStream *)stream
{
    NSMutableArray * jidArray = [NSMutableArray array];
    OTRManagedAccount * account = [self accountForStrem:stream];
    [account.buddies enumerateObjectsUsingBlock:^(OTRManagedBuddy * buddy, BOOL *stop) {
        [jidArray addObject:[XMPPJID jidWithString:buddy.accountName]];
    }];
    return jidArray;
}

- (void)setPhoto:(UIImage *)image forUserWithJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream
{
    [MagicalRecord saveWithBlock:^(NSManagedObjectContext *localContext) {
        OTRManagedBuddy * user = [self buddyWithJID:jid xmppStream:stream];
        [user setPhoto:image];
    }];
}

-(OTRManagedBuddy *)buddyWithJID:(XMPPJID *)jid xmppStream:(XMPPStream *)stream
{
    return [OTRManagedBuddy fetchOrCreateWithName:[jid bare] account:[self accountForStrem:stream]];
}

-(OTRManagedAccount *)accountForStrem:(XMPPStream *)stream
{
    //fixme to new constants of finding account
    return [OTRAccountsManager accountForProtocol:@"xmpp" accountName:[stream.myJID bare]];
}

@end
