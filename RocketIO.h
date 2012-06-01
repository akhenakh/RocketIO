//
//  NBRocketIO.h
//  NBRocketioDemo
//
// Initial project by Philipp Kyeck philipp@beta-interactive.de. 
// Namespace support by Sam Lown sam@cabify.com at Cabify.
// Socket Rocket port by Fabrice Aneche akh at nobugware.com

#import <Foundation/Foundation.h>

@class RocketIO;
@class SocketIOPacket;

typedef void(^SocketIOCallback)(id argsData);

#define HANDSHAKE_URL @"http://%@:%d/socket.io/1/?t=%d%@"
#define SOCKET_URL @"ws://%@:%d/socket.io/1/websocket/%@"

@protocol RocketIODelegate <NSObject>
@optional
- (void) rocketIODidConnect:(RocketIO *)socket;
- (void) rocketIODidDisconnect:(RocketIO *)socket;
- (void) rocketIO:(RocketIO *)socket didReceiveMessage:(SocketIOPacket *)packet;
- (void) rocketIO:(RocketIO *)socket didReceiveJSON:(SocketIOPacket *)packet;
- (void) rocketIO:(RocketIO *)socket didReceiveEvent:(SocketIOPacket *)packet;
- (void) rocketIO:(RocketIO *)socket didSendMessage:(SocketIOPacket *)packet;
- (void) rocketIOHandshakeFailed:(RocketIO *)socket;
@end

@interface RocketIO : NSObject {
    
    BOOL _isConnected;
    BOOL _isConnecting;
    
    NSInteger _port;
    NSInteger _ackCount;
    NSTimeInterval _heartbeatTimeout;
    
    id<RocketIODelegate> _delegate;
}

- (id) initWithDelegate:(id<RocketIODelegate>)delegate;
- (void) connectToHost:(NSString *)host onPort:(NSInteger)port;
- (void) connectToHost:(NSString *)host onPort:(NSInteger)port withParams:(NSDictionary *)params;
- (void) connectToHost:(NSString *)host onPort:(NSInteger)port withParams:(NSDictionary *)params withNamespace:(NSString *)endpoint;
- (void) disconnect;
- (void) sendMessage:(NSString *)data;
- (void) sendMessage:(NSString *)data withAcknowledge:(SocketIOCallback)function;
- (void) sendJSON:(NSDictionary *)data;
- (void) sendJSON:(NSDictionary *)data withAcknowledge:(SocketIOCallback)function;
- (void) sendEvent:(NSString *)eventName withData:(NSDictionary *)data;
- (void) sendEvent:(NSString *)eventName withData:(NSDictionary *)data andAcknowledge:(SocketIOCallback)function;
- (void) sendAcknowledgement:(NSString*)pId withArgs:(NSArray *)data;

@end


@interface SocketIOPacket : NSObject
{
    NSString *type;
    NSString *pId;
    NSString *ack;
    NSString *name;
    NSString *data;
    NSArray *args;
    NSString *endpoint;
    
@private
    NSArray *_types;
}

@property (nonatomic, copy) NSString *type;
@property (nonatomic, copy) NSString *pId;
@property (nonatomic, copy) NSString *ack;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *data;
@property (nonatomic, copy) NSString *endpoint;
@property (nonatomic, copy) NSArray *args;

- (id) initWithType:(NSString *)packetType;
- (id) initWithTypeIndex:(int)index;
- (id) dataAsJSON;
- (NSNumber *) typeAsNumber;
- (NSString *) typeForIndex:(int)index;

@end

