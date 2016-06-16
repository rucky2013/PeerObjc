//
//  ViewController.m
//  Example
//
//  Created by zhubch on 1/8/16.
//  Copyright © 2016 zhubch. All rights reserved.
//

#import "ViewController.h"
#import <PeerObjc/PeerObjc.h>
#import "ZHUtils.h"
#import "TextChatViewController.h"
#import "MediaViewController.h"

#import <VideoToolbox/VideoToolbox.h>

@interface ViewController ()
@property (nonatomic,weak) IBOutlet UITextField *myPeerIdText;
@property (nonatomic,weak) IBOutlet UITextField *otherPeerIdText;
@property (nonatomic,strong) ZHDataConnection *dataConnection;
@property (nonatomic,strong) ZHMediaConnection *mediaConnection;

@end

@implementation ViewController
{
    ZHPeer *p;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    p = [[ZHPeer alloc]initWithPeerId:@"123113" options:nil];
    
    __weak ViewController *__self = self;
    p.onOpen = ^(NSString *peerId){
        __self.myPeerIdText.text = peerId;
        NSLog(@"%@",peerId);
    };
    
    p.onError = ^(NSError *err){
        NSLog(@"%@",err);
    };
    
    p.onConnection = ^(Connection *conn){
        NSString *segue;
        if ([conn isKindOfClass:[ZHDataConnection class]]) {
            __self.dataConnection = (ZHDataConnection*)conn;
            segue = @"text";
        }else{
            __self.mediaConnection = (ZHMediaConnection*)conn;
            segue = @"media";
        }
        NSString *msg =  [NSString stringWithFormat:@"%@%@",conn.destId,[conn isKindOfClass:[ZHDataConnection class]] ? @"":@""];
        UIAlertView *alert = [[UIAlertView alloc]initWithTitle:@"提示" message:msg delegate:nil cancelButtonTitle:@"取消" otherButtonTitles:@"确定", nil];
        alert.clickedButton = ^(NSInteger buttonIndex,UIAlertView *alertView){
            if (buttonIndex == 1) {
                [__self performSegueWithIdentifier:segue sender:nil];
            }else {
                [conn close];
            }
        };
        [alert show];
    };
}

- (IBAction)textChat:(id)sender
{
    if (_otherPeerIdText.text.length) {
        _dataConnection = [p connectToPeer:_otherPeerIdText.text options:@{@"label":@"text",@"serialization":@"none",@"metadata":@{@"message":@"12345"}}];
        [self performSegueWithIdentifier:@"text" sender:nil];
        return;
    }
    showToast(@"请输入对方的peerID");
}

- (IBAction)videoChat:(id)sender
{
    if (_otherPeerIdText.text.length) {
        _mediaConnection = [p callPeer:_otherPeerIdText.text options:@{@"label":@"chat",@"serialization":@"none",@"metadata":@{@"message":@"12345"}}];
        [self performSegueWithIdentifier:@"media" sender:nil];
        return;
    }
    showToast(@"请输入对方的peerID");
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"text"]) {
        TextChatViewController *vc = segue.destinationViewController;
        vc.conn = _dataConnection;
    }else if([segue.identifier isEqualToString:@"media"]){
        MediaViewController *vc = segue.destinationViewController;
        vc.conn = _mediaConnection;
    }
}

@end
