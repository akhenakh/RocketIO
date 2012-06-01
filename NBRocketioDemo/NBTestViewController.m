//
//  NBTestViewController.m
//  NBRocketioDemo
//
//  Created by Fabrice Aneche on 5/31/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "NBTestViewController.h"
#import "RocketIO.h"

@interface NBTestViewController ()
@property(nonatomic, strong) RocketIO *socketIO;
@end

@implementation NBTestViewController

@synthesize textView = _textView;
@synthesize socketIO = _socketIO;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        _counter = 0;
        self.socketIO = [[RocketIO alloc] initWithDelegate:self];
        [_socketIO connectToHost:@"localhost" onPort:8001];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)viewDidUnload
{
    [self setTextView:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (IBAction)buttonAction:(id)sender {
    _textView.text = [_textView.text stringByAppendingString:[NSString stringWithFormat:@"sending event query with param %d\n", _counter]];
    NSRange range = NSMakeRange(_textView.text.length - 1, 1);
    [_textView scrollRangeToVisible:range];
    [_socketIO sendEvent:@"query" withData:[NSArray arrayWithObject:[NSNumber numberWithInt:_counter]]];
    _counter++;

}

#pragma mark SocketIO Delegate
- (void) rocketIODidConnect:(RocketIO *)socket {
    _textView.text = [_textView.text stringByAppendingString:[NSString stringWithFormat:@"websocket connected\n"]];
    NSRange range = NSMakeRange(_textView.text.length - 1, 1);
    [_textView scrollRangeToVisible:range];
}
- (void) rocketIODidDisconnect:(RocketIO *)socket {
    _textView.text = [_textView.text stringByAppendingString:[NSString stringWithFormat:@"websocket disconnected\n"]];
    NSRange range = NSMakeRange(_textView.text.length - 1, 1);
    [_textView scrollRangeToVisible:range];

}
- (void) rocketIO:(RocketIO *)socket didReceiveMessage:(SocketIOPacket *)packet {
    NSLog(@"didReceiveMessage packet data: %@", packet.data);
}
- (void) rocketIO:(RocketIO *)socket didReceiveJSON:(SocketIOPacket *)packet {
}
- (void) rocketIO:(RocketIO *)socket didReceiveEvent:(SocketIOPacket *)packet {
    NSLog(@"didReceiveEvent packet data: %@", packet.data);
    
    NSDictionary *eventDict = packet.dataAsJSON;
    _textView.text = [_textView.text stringByAppendingString:[NSString stringWithFormat:@"did received event name %@ param1 = %@\n", [eventDict objectForKey:@"name"], [[eventDict objectForKey:@"args"] objectAtIndex:0]  ]];
    
    NSRange range = NSMakeRange(_textView.text.length - 1, 1);
    [_textView scrollRangeToVisible:range];

}
- (void) rocketIO:(RocketIO *)socket didSendMessage:(SocketIOPacket *)packet {
    if ([packet.type isEqualToString:@"event"]) {
        NSLog(@"didSendMessage packet data: %@", packet.data);
        NSDictionary *eventDict = packet.dataAsJSON;
        _textView.text = [_textView.text stringByAppendingString:[NSString stringWithFormat:@"did send event name %@ param1 = %@\n", [eventDict objectForKey:@"name"], [[eventDict objectForKey:@"args"] objectAtIndex:0]  ]];
        
        NSRange range = NSMakeRange(_textView.text.length - 1, 1);
        [_textView scrollRangeToVisible:range];
    }
}
- (void) rocketIOHandshakeFailed:(RocketIO *)socket {
}

@end
