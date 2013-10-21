//
//  OTRChatViewController.m
//  Off the Record
//
//  Created by Chris Ballinger on 8/11/11.
//  Copyright (c) 2011 Chris Ballinger. All rights reserved.
//
//  This file is part of ChatSecure.
//
//  ChatSecure is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ChatSecure is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ChatSecure.  If not, see <http://www.gnu.org/licenses/>.

#import "OTRChatViewController.h"
#import "OTREncryptionManager.h"
#import <QuartzCore/QuartzCore.h>
#import "Strings.h"
#import "OTRDoubleSetting.h"
#import "OTRConstants.h"
#import "OTRAppDelegate.h"
#import "OTRMessageTableViewCell.h"
#import "DAKeyboardControl.h"
#import "OTRManagedStatus.h"
#import "OTRManagedEncryptionStatusMessage.h"
#import "OTRStatusMessageCell.h"
#import "OTRUtilities.h"



@interface OTRChatViewController(Private)

- (void) refreshView;



@end

@implementation OTRChatViewController
@synthesize buddyListController;
@synthesize lockButton, unlockedButton,lockVerifiedButton;
@synthesize lastActionLink;
@synthesize buddy;
@synthesize instructionsLabel;
@synthesize chatHistoryTableView;
@synthesize swipeGestureRecognizer;

- (void) dealloc {
    self.lastActionLink = nil;
    self.buddyListController = nil;
    self.buddy = nil;
    self.chatHistoryTableView = nil;
}

- (void)viewDidUnload {
    [super viewDidUnload];
    self.lockButton = nil;
    self.unlockedButton = nil;
    self.instructionsLabel = nil;
    self.chatHistoryTableView = nil;
    _messagesFetchedResultsController = nil;
    _buddyFetchedResultsController = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (id)init {
    if (self = [super init]) {
        //set notification for when keyboard shows/hides
        self.title = CHAT_STRING;
    }
    return self;
}

- (CGFloat) chatBoxViewHeight {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return 50.0;
    } else {
        return 44.0;
    }
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}


-(void)setupLockButton
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    UIImage *buttonImage = [UIImage imageNamed:@"Lock_Locked.png"];
    [button setBackgroundImage:buttonImage forState:UIControlStateNormal];
    CGRect buttonFrame = [button frame];
    buttonFrame.size.width = buttonImage.size.width;
    buttonFrame.size.height = buttonImage.size.height;
    [button setFrame:buttonFrame];
    [button addTarget:self action:@selector(lockButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    
    self.lockButton = [[UIBarButtonItem alloc] initWithCustomView:button];
    
    button = [UIButton buttonWithType:UIButtonTypeCustom];
    buttonImage = [UIImage imageNamed:@"Lock_Unlocked.png"];
    [button setBackgroundImage:buttonImage forState:UIControlStateNormal];
    buttonFrame = [button frame];
    buttonFrame.size.width = buttonImage.size.width;
    buttonFrame.size.height = buttonImage.size.height;
    [button setFrame:buttonFrame];
    [button addTarget:self action:@selector(lockButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    
    self.unlockedButton = [[UIBarButtonItem alloc] initWithCustomView:button];
    
    button = [UIButton buttonWithType:UIButtonTypeCustom];
    buttonImage = [UIImage imageNamed:@"Lock_Locked_Verified.png"];
    [button setBackgroundImage:buttonImage forState:UIControlStateNormal];
    buttonFrame = [button frame];
    buttonFrame.size.width = buttonImage.size.width;
    buttonFrame.size.height = buttonImage.size.height;
    [button setFrame:buttonFrame];
    [button addTarget:self action:@selector(lockButtonPressed) forControlEvents:UIControlEventTouchUpInside];
    
    self.lockVerifiedButton = [[UIBarButtonItem alloc] initWithCustomView:button];
    
    [self refreshLockButton];
}

-(void)refreshLockButton
{
    [OTRCodec isGeneratingKeyForBuddy:self.buddy completion:^(BOOL isGeneratingKey) {
        if (isGeneratingKey) {
            [self addLockSpinner];
        }
    }];
    UIBarButtonItem * rightBarItem = self.navigationItem.rightBarButtonItem;
    if ([rightBarItem isEqual:lockButton] || [rightBarItem isEqual:lockVerifiedButton] || [rightBarItem isEqual:unlockedButton] || !rightBarItem) {
        BOOL trusted = [[OTRKit sharedInstance] finerprintIsVerifiedForUsername:buddy.accountName accountName:buddy.account.username protocol:buddy.account.protocol];
        
        int16_t currentEncryptionStatus = [self.buddy currentEncryptionStatus].statusValue;
        
        if(currentEncryptionStatus == kOTRKitMessageStateEncrypted && trusted)
        {
            self.navigationItem.rightBarButtonItem = self.lockVerifiedButton;
        }
        else if(currentEncryptionStatus == kOTRKitMessageStateEncrypted)
        {
            self.navigationItem.rightBarButtonItem = self.lockButton;
        }
        else
        {
            self.navigationItem.rightBarButtonItem = self.unlockedButton;
        }
        self.navigationItem.rightBarButtonItem.accessibilityLabel = @"lock";
    }
    
}

-(void)lockButtonPressed
{
    NSString *encryptionString = INITIATE_ENCRYPTED_CHAT_STRING;
    NSString * verifiedString = VERIFY_STRING;
    
    if ([self.buddy currentEncryptionStatus].statusValue == kOTRKitMessageStateEncrypted) {
        encryptionString = CANCEL_ENCRYPTED_CHAT_STRING;
    }
    UIActionSheet *popupQuery = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:CANCEL_STRING destructiveButtonTitle:nil otherButtonTitles:encryptionString, verifiedString, CLEAR_CHAT_HISTORY_STRING, nil];
    popupQuery.accessibilityLabel = @"secure";
    popupQuery.actionSheetStyle = UIActionSheetStyleBlackOpaque;
    popupQuery.tag = ACTIONSHEET_ENCRYPTION_OPTIONS_TAG;
    [OTR_APP_DELEGATE presentActionSheet:popupQuery inView:self.view];
}



#pragma mark - View lifecycle

- (void) loadView {
    [super loadView];
    self.view.backgroundColor = [UIColor whiteColor];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _heightForRow = [NSMutableArray array];
    _messageBubbleComposing = [UIImage imageNamed:@"MessageBubbleTyping"];
    
    self.chatHistoryTableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height)];
    
    
    UIEdgeInsets insets = self.chatHistoryTableView.contentInset;
    insets.bottom = kChatBarHeight1;
    if(SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"7.0")) {
        //insets.top = [self.navigationController navigationBar].frame.size.height;
    }
    
    self.chatHistoryTableView.contentInset = self.chatHistoryTableView.scrollIndicatorInsets = insets;
    
    self.chatHistoryTableView.dataSource = self;
    self.chatHistoryTableView.delegate = self;
    self.chatHistoryTableView.autoresizingMask = (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);;
    self.chatHistoryTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.chatHistoryTableView.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:self.chatHistoryTableView];
    
    [self.chatHistoryTableView scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
    
    
    _messageFontSize = [OTRSettingsManager floatForOTRSettingKey:kOTRSettingKeyFontSize];
    _previousTextViewContentHeight = MessageFontSize+20;
        
    CGRect barRect = CGRectMake(0, self.view.frame.size.height-kChatBarHeight1, self.view.frame.size.width, kChatBarHeight1);
    
    chatInputBar = [[OTRChatInputBar alloc] initWithFrame:barRect withDelegate:self];
   
    [self.view addSubview:chatInputBar];
    
    self.view.keyboardTriggerOffset = chatInputBar.frame.size.height;
    
    
    __weak OTRChatViewController * chatViewController = self;
    __weak OTRChatInputBar * weakChatInputbar = chatInputBar;
    [self.view addKeyboardPanningWithActionHandler:^(CGRect keyboardFrameInView) {
        CGRect messageInputBarFrame = weakChatInputbar.frame;
        messageInputBarFrame.origin.y = keyboardFrameInView.origin.y - messageInputBarFrame.size.height;
        weakChatInputbar.frame = messageInputBarFrame;
        
        UIEdgeInsets tableViewContentInset = chatViewController.chatHistoryTableView.contentInset;
        tableViewContentInset.bottom = chatViewController.view.frame.size.height-weakChatInputbar.frame.origin.y;
        chatViewController.chatHistoryTableView.contentInset = chatViewController.chatHistoryTableView.scrollIndicatorInsets = tableViewContentInset;
        [chatViewController scrollToBottomAnimated:NO];
    }];
    
    swipeGestureRecognizer = [[UISwipeGestureRecognizer alloc]initWithTarget:self action:@selector(handleSwipeFrom)];
    [self.view addGestureRecognizer:swipeGestureRecognizer];
    
    [self setupLockButton];
    
}

-(void)handleSwipeFrom
{
    if (swipeGestureRecognizer.direction == UISwipeGestureRecognizerDirectionRight && UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (void) showDisconnectionAlert:(NSNotification*)notification {
    NSMutableString *message = [NSMutableString stringWithFormat:DISCONNECTED_MESSAGE_STRING, buddy.account.username];
    if ([OTRSettingsManager boolForOTRSettingKey:kOTRSettingKeyDeleteOnDisconnect]) {
        [message appendFormat:@" %@", DISCONNECTION_WARNING_STRING];
    }
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:DISCONNECTED_TITLE_STRING message:message delegate:nil cancelButtonTitle:OK_STRING otherButtonTitles: nil];
    [alert show];
}

- (void) setBuddy:(OTRManagedBuddy *)newBuddy {
    [self saveCurrentMessageText];
    
    buddy = newBuddy;
    
    [self refreshView];
    if (buddy) {
        self.title = newBuddy.displayName;
        [self refreshLockButton];
        [self updateChatState:NO];
    }
    
    
}

-(BOOL)isComposingVisible
{
    if ([self.chatHistoryTableView numberOfRowsInSection:0] == [[self.messagesFetchedResultsController fetchedObjects] count]) {
        return NO;
    }
    return YES;
}
-(NSIndexPath *)lastIndexPath
{
    return [NSIndexPath indexPathForRow:([self.chatHistoryTableView numberOfRowsInSection:0] - 1) inSection:0];
}


-(void)removeComposing
{
    [self.chatHistoryTableView beginUpdates];
    [self.chatHistoryTableView deleteRowsAtIndexPaths:@[[self lastIndexPath]] withRowAnimation:UITableViewRowAnimationAutomatic];
    [self.chatHistoryTableView endUpdates];
    [self scrollToBottomAnimated:YES];
    
}
-(void)addComposing
{
    NSIndexPath * lastIndexPath = [self lastIndexPath];
    NSInteger newLast = [lastIndexPath indexAtPosition:lastIndexPath.length-1]+1;
    lastIndexPath = [[lastIndexPath indexPathByRemovingLastIndex] indexPathByAddingIndex:newLast];
    [self.chatHistoryTableView beginUpdates];
    [self.chatHistoryTableView insertRowsAtIndexPaths:@[lastIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    [self.chatHistoryTableView endUpdates];
    [self scrollToBottomAnimated:YES];
}

- (void)updateChatState:(BOOL)animated
{
    switch (self.buddy.chatStateValue) {
        case kOTRChatStateComposing:
            {
                if (![self isComposingVisible]) {
                    [self addComposing];
                }
            }
        break;
        case kOTRChatStatePaused:
            {
                if (![self isComposingVisible]) {
                [self addComposing];
                }
            }
            break;
        case kOTRChatStateActive:
            if ([self isComposingVisible]) {
                [self removeComposing];
            }
            break;
        default:
            if ([self isComposingVisible]) {
                [self removeComposing];
            }
            break;
    }
}
- (void)textViewDidBeginEditing:(UITextView *)textView
{
    [self scrollToBottomAnimated:YES];
}

- (void) encryptionStateChangeNotification:(NSNotification *) notification
{
    [self refreshLockButton];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return YES;
    } else {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSLog(@"buttonIndex: %d",buttonIndex);
    if(actionSheet.tag == ACTIONSHEET_ENCRYPTION_OPTIONS_TAG)
    {
        if (buttonIndex == 1) // Verify
        {
            NSString *msg = nil;
            NSString *ourFingerprintString = [[OTRKit sharedInstance] fingerprintForAccountName:buddy.account.username protocol:buddy.account.protocol];
            NSString *theirFingerprintString = [[OTRKit sharedInstance] fingerprintForUsername:buddy.accountName accountName:buddy.account.username protocol:buddy.account.protocol];
            BOOL trusted = [[OTRKit sharedInstance] finerprintIsVerifiedForUsername:buddy.accountName accountName:buddy.account.username protocol:buddy.account.protocol];
            
            
            UIAlertView * alert;
            if(ourFingerprintString && theirFingerprintString) {
                msg = [NSString stringWithFormat:@"%@, %@:\n%@\n\n%@ %@:\n%@\n", YOUR_FINGERPRINT_STRING, buddy.account.username, ourFingerprintString, THEIR_FINGERPRINT_STRING, buddy.accountName, theirFingerprintString];
                if(trusted)
                {
                    alert = [[UIAlertView alloc] initWithTitle:VERIFY_FINGERPRINT_STRING message:msg delegate:self cancelButtonTitle:VERIFIED_STRING otherButtonTitles:NOT_VERIFIED_STRING, nil];
                    alert.tag = ALERTVIEW_VERIFIED_TAG;
                }
                else
                {
                    alert = [[UIAlertView alloc] initWithTitle:VERIFY_FINGERPRINT_STRING message:msg delegate:self cancelButtonTitle:VERIFY_LATER_STRING otherButtonTitles:VERIFIED_STRING, nil];
                    alert.tag = ALERTVIEW_NOT_VERIFIED_TAG;
                }
            } else {
                msg = SECURE_CONVERSATION_STRING;
               alert = [[UIAlertView alloc] initWithTitle:nil message:msg delegate:nil cancelButtonTitle:nil otherButtonTitles:OK_STRING, nil];
            }
                            
            [alert show];
        }
        else if (buttonIndex == 0) // Initiate/cancel encryption
        {
            if([self.buddy currentEncryptionStatus].statusValue == kOTRKitMessageStateEncrypted)
            {
                [[OTRKit sharedInstance]disableEncryptionForUsername:buddy.accountName accountName:buddy.account.username protocol:buddy.account.protocol];
            } else {
                OTRManagedBuddy* theBuddy = buddy;
                OTRManagedMessage * newMessage = [OTRManagedMessage newMessageToBuddy:theBuddy message:@"" encrypted:YES];
                //OTRManagedMessage *encodedMessage = [OTRCodec encodeMessage:newMessage];
                [OTRCodec encodeMessage:newMessage startGeneratingKeysBlock:^{
                    //display activity
                    NSLog(@"Generating key");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self addLockSpinner];
                    });
                } completion:^(OTRManagedMessage *message) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if ([self.buddy isEqual:message.buddy]) {
                            [self removeLockSpinner];
                        }
                        [OTRManagedMessage sendMessage:message];
                    });
                    
                }];
                
            }
        }
        else if (buttonIndex == 2) { // Clear Chat History
            [buddy deleteAllMessages];
        }
        else if (buttonIndex == actionSheet.cancelButtonIndex) // Cancel
        {
            
        }
    }
}

-(void)addLockSpinner {
    UIActivityIndicatorView * activityIndicatorView = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0, 0, 25, 25)];
    activityIndicatorView.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
    [activityIndicatorView sizeToFit];
    [activityIndicatorView setAutoresizingMask:(UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin)];
    UIBarButtonItem * activityBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:activityIndicatorView];
    [activityIndicatorView startAnimating];
    self.navigationItem.rightBarButtonItem = activityBarButtonItem;
}
-(void)removeLockSpinner {
    self.navigationItem.rightBarButtonItem = nil;
    [self refreshLockButton];
}

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(alertView.cancelButtonIndex != buttonIndex && alertView.tag == ALERTVIEW_NOT_VERIFIED_TAG)
    {
        [[OTRKit sharedInstance] changeVerifyFingerprintForUsername:buddy.accountName accountName:buddy.account.username protocol:buddy.account.protocol verrified:YES];
        [self refreshLockButton];
    }
    else if(alertView.cancelButtonIndex != buttonIndex && alertView.tag == ALERTVIEW_VERIFIED_TAG)
    {
        [[OTRKit sharedInstance] changeVerifyFingerprintForUsername:buddy.accountName accountName:buddy.account.username  protocol:buddy.account.protocol verrified:NO];
        [self refreshLockButton];
    }
}


- (void) refreshView {
    _messagesFetchedResultsController = nil;
    _buddyFetchedResultsController = nil;
    if (!buddy) {
        if (!instructionsLabel) {
            int labelWidth = 500;
            int labelHeight = 100;
            self.instructionsLabel = [[UILabel alloc] initWithFrame:CGRectMake(self.view.frame.size.width/2-labelWidth/2, self.view.frame.size.height/2-labelHeight/2, labelWidth, labelHeight)];
            instructionsLabel.text = CHAT_INSTRUCTIONS_LABEL_STRING;
            instructionsLabel.numberOfLines = 2;
            instructionsLabel.backgroundColor = self.chatHistoryTableView.backgroundColor;
            [self.view addSubview:instructionsLabel];
            self.navigationItem.rightBarButtonItem = nil;
        }
    } else {
        if (instructionsLabel) {
            [self.instructionsLabel removeFromSuperview];
            self.instructionsLabel = nil;
        }
        [self buddyFetchedResultsController];
        _heightForRow = [NSMutableArray array];
        _previousShownSentDate = nil;
        [self.buddy allMessagesRead];
        [self.chatHistoryTableView reloadData];
        //[self.textView resignFirstResponder];
        //[self moveMessageBarBottom];
        
        _messageFontSize = [OTRSettingsManager floatForOTRSettingKey:kOTRSettingKeyFontSize];
        
        
        
        if(![self.buddy.composingMessageString length])
        {
            [self.buddy sendActiveChatState];
            chatInputBar.textView.text = nil;
        }
        else{
            chatInputBar.textView.text = self.buddy.composingMessageString;
            
        }
        
        [self scrollToBottomAnimated:NO];
        [self refreshLockButton];
    }
    
}

- (void)viewWillDisappear:(BOOL)animated
{

    [self.buddy allMessagesRead];
    
    [super viewWillDisappear:animated];
}

-(void)viewDidDisappear:(BOOL)animated
{
    [self setBuddy:nil];
    [super viewDidDisappear:animated];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self refreshView];
    [self updateChatState:NO];
    
    
}

-(void)saveCurrentMessageText
{
    self.buddy.composingMessageString = chatInputBar.textView.text;
    if(![self.buddy.composingMessageString length])
    {
        [self.buddy sendInactiveChatState];
    }
    chatInputBar.textView.text = nil;
}

/*- (void)debugButton:(UIBarButtonItem *)sender
{
	textView.contentView.drawDebugFrames = !textView.contentView.drawDebugFrames;
	[DTCoreTextLayoutFrame setShouldDrawDebugFrames:textView.contentView.drawDebugFrames];
	[self.view setNeedsDisplay];
}*/


//detailedView delegate methods
- (void)splitViewController:(UISplitViewController*)svc 
     willHideViewController:(UIViewController *)aViewController 
          withBarButtonItem:(UIBarButtonItem*)barButtonItem 
       forPopoverController:(UIPopoverController*)pc
{  
    [barButtonItem setTitle:BUDDY_LIST_STRING];
    
    
    
    self.navigationItem.leftBarButtonItem = barButtonItem;
}


- (void)splitViewController:(UISplitViewController*)svc 
     willShowViewController:(UIViewController *)aViewController 
  invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem
{
    self.navigationItem.leftBarButtonItem = nil;
}

- (void)scrollToBottomAnimated:(BOOL)animated {
    NSInteger numberOfRows = [self.chatHistoryTableView numberOfRowsInSection:0];
    if (numberOfRows) {
        [self.chatHistoryTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:numberOfRows-1 inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:animated];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    //    NSLog(@"heightForRowAtIndexPath: %@", indexPath);
    
    if (indexPath.row < [[self.messagesFetchedResultsController sections][indexPath.section] numberOfObjects])
    {
        NSArray *messageDetails = nil;
        if ([_heightForRow count] > indexPath.row) {
            messageDetails = _heightForRow[indexPath.row];
        }
        
        CGFloat messageSentDateLabelHeight = 0;
        CGFloat messageDeliveredLabelHeight = 0;
        CGFloat messageTextLabelHeight = 0;
        
        if (messageDetails) {
            messageSentDateLabelHeight = [messageDetails[0] floatValue];
            messageTextLabelHeight = [messageDetails[1] CGSizeValue].height;
            messageDeliveredLabelHeight = [messageDetails[2] floatValue];
        }
        
        id messageOrStatus = [self.messagesFetchedResultsController objectAtIndexPath:indexPath];
        if([messageOrStatus isKindOfClass:[OTRManagedMessage class]])
        {
            OTRManagedMessage * message = (OTRManagedMessage *)messageOrStatus;
            
            
            if (!messageDetails)
            {
                if ((!_previousShownSentDate || [message.date timeIntervalSinceDate:_previousShownSentDate] > MESSAGE_SENT_DATE_SHOW_TIME_INTERVAL)) {
                    _previousShownSentDate = message.date;
                    messageSentDateLabelHeight = MESSAGE_SENT_DATE_LABEL_HEIGHT;
                }
                CGSize messageTextLabelSize = [OTRMessageTableViewCell messageTextLabelSize:message.message];
                messageTextLabelHeight = messageTextLabelSize.height;
                
                
                //messageTextLabelHeight = MESSAGE_DELIVERED_LABEL_HEIGHT;
                
                
                _heightForRow[indexPath.row] = @[@(messageSentDateLabelHeight), [NSValue valueWithCGSize:messageTextLabelSize], @(messageDeliveredLabelHeight)];
            }
            
            return messageSentDateLabelHeight+messageTextLabelHeight+messageDeliveredLabelHeight+MESSAGE_MARGIN_TOP+MESSAGE_MARGIN_BOTTOM;
        }
        else
        {
            if(!messageDetails)
            {
                _heightForRow[indexPath.row] = @[@(MESSAGE_SENT_DATE_LABEL_HEIGHT), [NSValue valueWithCGSize:CGSizeZero], @(messageDeliveredLabelHeight)];
            }
            
            return MESSAGE_SENT_DATE_LABEL_HEIGHT;
        }
        
        
    }
    else
    {
        //Composing messsage height
        CGSize messageTextLabelSize =[OTRMessageTableViewCell messageTextLabelSize:@"T"];
        return messageTextLabelSize.height+MESSAGE_MARGIN_TOP+MESSAGE_MARGIN_BOTTOM;
    }
    
    
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger numMessages = [[self.messagesFetchedResultsController sections][section] numberOfObjects];
    if (buddy.chatStateValue == kOTRChatStateComposing || buddy.chatStateValue == kOTRChatStatePaused) {
        numMessages +=1;
    }
    return numMessages;
    
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger lastIndex = ([[self.messagesFetchedResultsController sections][indexPath.section] numberOfObjects]-1);
    BOOL isLastRow = indexPath.row > lastIndex;
    BOOL isComposing = buddy.chatStateValue == kOTRChatStateComposing;
    BOOL isPaused = buddy.chatStateValue == kOTRChatStatePaused;
    BOOL isComposingRow = ((isComposing || isPaused) && isLastRow);
    if (isComposingRow){
        UITableViewCell * cell;
        static NSString *ComposingCellIdentifier = @"composingCell";
        cell = [tableView dequeueReusableCellWithIdentifier:ComposingCellIdentifier];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:ComposingCellIdentifier];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            UIImageView *messageBackgroundImageView;
            messageBackgroundImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
            messageBackgroundImageView.tag = MESSAGE_BACKGROUND_IMAGE_VIEW_TAG;
            messageBackgroundImageView.backgroundColor = tableView.backgroundColor; // speeds scrolling
            [cell.contentView addSubview:messageBackgroundImageView];
            
            messageBackgroundImageView.frame = CGRectMake(0, 0, _messageBubbleComposing.size.width, _messageBubbleComposing.size.height);
            messageBackgroundImageView.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
            messageBackgroundImageView.image = _messageBubbleComposing;
            

        }
        return cell;
    }
    else if( [[self.messagesFetchedResultsController sections][indexPath.section] numberOfObjects] > indexPath.row) {
        
        id messageOrStatus = [self.messagesFetchedResultsController objectAtIndexPath:indexPath];
        NSArray *messageDetails = _heightForRow[indexPath.row];
        BOOL showDate = [messageDetails[0] boolValue];

        if ([messageOrStatus isKindOfClass:[OTRManagedMessage class]]) {
            OTRManagedMessage * message = (OTRManagedMessage *)messageOrStatus;
            static NSString *CellIdentifier = @"Cell";
            OTRMessageTableViewCell * cell;
            cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
            if (!cell) {
                cell = [[OTRMessageTableViewCell alloc] initWithMessage:message withDate:showDate reuseIdentifier:CellIdentifier];
            } else {
                cell.showDate = showDate;
                cell.message = message;
                
            }
            return cell;
        }
        else if ([messageOrStatus isKindOfClass:[OTRManagedStatus class]] || [messageOrStatus isKindOfClass:[OTRManagedEncryptionStatusMessage class]])
        {
            static NSString *CellIdentifier = @"statusCell";
            UITableViewCell * cell;
            cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
            if (!cell) {
                cell = [[OTRStatusMessageCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
            }
            
            
            NSString * cellText = nil;
            OTRManagedMessageAndStatus * managedStatus = (OTRManagedMessageAndStatus *)messageOrStatus;
            
            if ([messageOrStatus isKindOfClass:[OTRManagedStatus class]]) {
                if (managedStatus.isIncomingValue) {
                    cellText = [NSString stringWithFormat:INCOMING_STATUS_MESSAGE,managedStatus.message];
                }
                else{
                    cellText = [NSString stringWithFormat:YOUR_STATUS_MESSAGE,managedStatus.message];
                }
            }
            else{
                cellText = managedStatus.message;
            }
            
            
            ((OTRStatusMessageCell *)cell).statusMessageLabel.text = cellText;
            
            cell.userInteractionEnabled = NO;
            return cell;
        }
    }
}

#pragma mark - NSFetchedResultsControllerDelegate

-(NSFetchedResultsController *)buddyFetchedResultsController{
    if (_buddyFetchedResultsController)
        return _buddyFetchedResultsController;
    
    NSPredicate * buddyFilter = [NSPredicate predicateWithFormat:@"self == %@",self.buddy];
    //NSPredicate * chatStateFilter = [NSPredicate predicateWithFormat:@"chatState == %d OR chatState == %d",kOTRChatStateComposing,kOTRChatStatePaused];
    //NSPredicate *predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[buddyFilter,chatStateFilter]];
    
    _buddyFetchedResultsController = [OTRManagedBuddy MR_fetchAllGroupedBy:nil withPredicate:buddyFilter sortedBy:nil ascending:YES delegate:self];
    
    return _buddyFetchedResultsController;
}

- (NSFetchedResultsController *)messagesFetchedResultsController {
    if (_messagesFetchedResultsController)
    {
        return _messagesFetchedResultsController;
    }
    
    NSPredicate * buddyFilter = [NSPredicate predicateWithFormat:@"self.buddy == %@",self.buddy];
    NSPredicate * encryptionFilter = [NSPredicate predicateWithFormat:@"isEncrypted == NO"];
    NSPredicate * messagePredicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[buddyFilter,encryptionFilter]];

    _messagesFetchedResultsController = [OTRManagedMessageAndStatus MR_fetchAllGroupedBy:nil withPredicate:messagePredicate sortedBy:@"date" ascending:YES delegate:self];

    return _messagesFetchedResultsController;
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    [self updateChatState:YES];
    [self refreshLockButton];
    if ([controller isEqual:self.messagesFetchedResultsController])
    {
        [self.chatHistoryTableView beginUpdates];
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath {
    UITableView *tableView = nil;
    
    if ([controller isEqual:_messagesFetchedResultsController])
    {
        tableView = self.chatHistoryTableView;
        
        
        switch(type) {
            case NSFetchedResultsChangeInsert:
            {
                [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationBottom];
                
                
                id possibleMessage = [controller objectAtIndexPath:newIndexPath];
                if ([possibleMessage isKindOfClass:[OTRManagedMessage class]]) {
                    ((OTRManagedMessage *)possibleMessage).isReadValue = YES;
                }
                
            }
                break;
            case NSFetchedResultsChangeUpdate:
            {
                [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            }
                break;
            case NSFetchedResultsChangeDelete:
            {
                [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            }
                break;
        }
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    if ([controller isEqual:self.messagesFetchedResultsController])
    {
        [self.chatHistoryTableView endUpdates];
        [self scrollToBottomAnimated:YES];
    }
}

#pragma mark OTRChatInputBarDelegate

- (void)sendButtonPressedForInputBar:(OTRChatInputBar *)inputBar
{
    NSString * text = inputBar.textView.text;
    if ([text length]) {
        NSLog(@"Send: %@",text);
        BOOL secure = [self.buddy currentEncryptionStatus].statusValue == kOTRKitMessageStateEncrypted;
        [buddy sendMessage:text secure:secure];
        chatInputBar.textView.text = nil;
    }
}

-(BOOL)inputBar:(OTRChatInputBar *)inputBar shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
     NSRange textFieldRange = NSMakeRange(0, [inputBar.textView.text length]);
     
     [buddy sendComposingChatState];
     
     if (NSEqualRanges(range, textFieldRange) && [text length] == 0)
     {
          [buddy sendActiveChatState];
     }
     
     return YES;
}

-(void)didChangeFrameForInputBur:(OTRChatInputBar *)inputBar
{
    UIEdgeInsets tableViewInsets = self.chatHistoryTableView.contentInset;
    tableViewInsets.bottom = self.view.frame.size.height - inputBar.frame.origin.y;
    self.chatHistoryTableView.contentInset = self.chatHistoryTableView.scrollIndicatorInsets = tableViewInsets;
    self.view.keyboardTriggerOffset = inputBar.frame.size.height;
}

- (void)inputBarDidBeginEditing:(OTRChatInputBar *)inputBar
{
    [self scrollToBottomAnimated:YES];
}


@end
