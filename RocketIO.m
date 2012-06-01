//
// Initial project by Philipp Kyeck philipp@beta-interactive.de. 
// Namespace support by Sam Lown sam@cabify.com at Cabify.
// Socket Rocket port by Fabrice Aneche akh at nobugware.com


#import "RocketIO.h"
#import "SRWebSocket.h"

@interface RocketIO() <SRWebSocketDelegate>

@property(nonatomic, copy) NSString *host;

@property(nonatomic, copy) NSString *sid;
@property(nonatomic, copy) NSString *endpoint;
@property(nonatomic, strong) SRWebSocket *webSocket;
// heartbeat
@property(nonatomic, strong) NSTimer *timeout;
@property(nonatomic, strong) NSMutableArray *queue;
// acknowledge
@property(nonatomic, strong) NSMutableDictionary *acks;
@property(nonatomic, strong) NSMutableData *responseData;


- (void) onTimeout;
- (void) setTimeout;

- (void) onConnect:(SocketIOPacket *)packet;
- (void) onDisconnect;

- (void) doQueue;
- (NSString *) addAcknowledge:(SocketIOCallback)function;
- (void) removeAcknowledgeForKey:(NSString *)key;
- (NSArray *) arrayOfCaptureComponentsOfString:(NSString *)data matchedByRegex:(NSString *)regex;


@end

@implementation RocketIO

@synthesize host = _host;
@synthesize sid = _sid;
@synthesize endpoint = _endpoint;
@synthesize webSocket = _webSocket;
@synthesize timeout = _timeout;
@synthesize queue = _queue;
@synthesize acks = _acks;
@synthesize responseData = _responseData;

- (id) initWithDelegate:(id<RocketIODelegate>)delegate
{
    self = [super init];
    if (self)
    {
        _delegate = delegate;
        self.queue = [[NSMutableArray alloc] init];
        _ackCount = 0;
        self.acks = [[NSMutableDictionary alloc] init];
        self.responseData = [NSMutableData data];

    }
    return self;
}

- (void) connectToHost:(NSString *)host onPort:(NSInteger)port
{
    [self connectToHost:host onPort:port withParams:nil withNamespace:@""];
}

- (void) connectToHost:(NSString *)host onPort:(NSInteger)port withParams:(NSDictionary *)params
{
    [self connectToHost:host onPort:port withParams:params withNamespace:@""];
}

- (void) connectToHost:(NSString *)host onPort:(NSInteger)port withParams:(NSDictionary *)params withNamespace:(NSString *)endpoint
{
    if (!_isConnected && !_isConnecting) 
    {
        _isConnecting = YES;
        
        self.host = host;
        _port = port;
        self.endpoint = endpoint;
        
        // create a query parameters string
        NSMutableString *query = [[NSMutableString alloc] initWithString:@""];
        [params enumerateKeysAndObjectsUsingBlock: ^(id key, id value, BOOL *stop) {
            [query appendFormat:@"&%@=%@",key,value];
        }];
        
        // do handshake via HTTP request
        NSString *s = [NSString stringWithFormat:HANDSHAKE_URL, _host, _port, rand(), query];
        
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:s]];
        [[NSURLConnection alloc] initWithRequest:request delegate:self];
        
    }
}

- (void) disconnect
{
    [self sendDisconnect];
}

- (void) onTimeout 
{
    [self onDisconnect];
}

- (void) setTimeout 
{
    if (_timeout != nil) 
    {   
        [_timeout invalidate];
        self.timeout = nil;
    }
    
    self.timeout = [NSTimer scheduledTimerWithTimeInterval:_heartbeatTimeout
                                                 target:self 
                                               selector:@selector(onTimeout) 
                                               userInfo:nil 
                                                repeats:NO];
}

- (void) doQueue 
{
    
    // TODO send all packets at once ... not as seperate packets
    while ([_queue count] > 0) 
    {
        SocketIOPacket *packet = [_queue objectAtIndex:0];
        [self send:packet];
        [_queue removeObject:packet];
    }
}

- (void) onConnect:(SocketIOPacket *)packet
{
    
    _isConnected = YES;
    
    // Send the connected packet so the server knows what it's dealing with.
    // Only required when endpoint/namespace is present
    if ([_endpoint length] > 0) {
        // Make sure the packet we received has an endpoint, otherwise send it again
        if (![packet.endpoint isEqualToString:_endpoint]) {
            [self sendConnect];
            return;
        }
    }
    
    _isConnecting = NO;
    
    if ([_delegate respondsToSelector:@selector(rocketIODidConnect:)]) 
    {
        [_delegate rocketIODidConnect:self];
    }
    
    // send any queued packets
    [self doQueue];
    
    [self setTimeout];
}


- (void) onDisconnect 
{
    BOOL wasConnected = _isConnected;
    
    _isConnected = NO;
    _isConnecting = NO;
    _sid = nil;
    
    [_queue removeAllObjects];
    
    // Kill the heartbeat timer
    if (_timeout != nil) {
        [_timeout invalidate];
        _timeout = nil;
    }
    
    // Disconnect the websocket, just in case
    if (_webSocket != nil && (_webSocket.readyState < SR_CLOSING) ) {
        [_webSocket close];
    }
    
    if (wasConnected && [_delegate respondsToSelector:@selector(rocketIODidDisconnect:)]) 
    {
        [_delegate rocketIODidDisconnect:self];
    }
}


//https://gist.github.com/1896546
- (NSArray *) arrayOfCaptureComponentsOfString:(NSString *)data matchedByRegex:(NSString *)regex
{
    NSError *error = NULL;
    NSRegularExpression *regExpression = [NSRegularExpression regularExpressionWithPattern:regex options:NSRegularExpressionCaseInsensitive error:&error];
    
    NSMutableArray *test = [NSMutableArray array];
    
    NSArray *matches = [regExpression matchesInString:data options:NSRegularExpressionSearch range:NSMakeRange(0, data.length)];
    
    for(NSTextCheckingResult *match in matches) {
        NSMutableArray *result = [NSMutableArray arrayWithCapacity:match.numberOfRanges];
        for(NSInteger i=0; i<match.numberOfRanges; i++) {
            NSRange matchRange = [match rangeAtIndex:i];
            NSString *matchStr = nil;
            if(matchRange.location != NSNotFound) {
                matchStr = [data substringWithRange:matchRange];
            } else {
                matchStr = @"";
            }
            [result addObject:matchStr];
        }
        [test addObject:result];
    }
    return test;
}

- (void) onData:(NSString *)data 
{
    
    // data arrived -> reset timeout
    [self setTimeout];
    
    // check if data is valid (from socket.io.js)
    NSString *regexString = @"^([^:]+):([0-9]+)?(\\+)?:([^:]+)?:?(.*)?$";
    NSString *regexPieces = @"^([0-9]+)(\\+)?(.*)";
    
    // valid data-string arrived
    
    NSArray *test = [self arrayOfCaptureComponentsOfString:data matchedByRegex:regexString];
    if ([test count] > 0) {
        
        NSArray *result = [test objectAtIndex:0];

        
        int idx = [[result objectAtIndex:1] intValue];
        SocketIOPacket *packet = [[SocketIOPacket alloc] initWithTypeIndex:idx];
        
        packet.pId = [result objectAtIndex:2];
        
        packet.ack = [result objectAtIndex:3];
        packet.endpoint = [result objectAtIndex:4];        
        packet.data = [result objectAtIndex:5];
        
        
        switch (idx) 
        {
            case 0: 
            {
                [self onDisconnect];
            }
                break;
                
                
            case 1:
            {
                // from socket.io.js ... not sure when data will contain sth?! 
                // packet.qs = data || '';
                [self onConnect:packet];
            }
                break;
                
            case 2: 
            {
                [self sendHeartbeat];
            }
                break;
                
            case 3:
            {
                if (packet.data && ![packet.data isEqualToString:@""])
                {
                    if ([_delegate respondsToSelector:@selector(rocketIO:didReceiveMessage:)]) 
                    {
                        [_delegate rocketIO:self didReceiveMessage:packet];
                    }
                }
            }
                break;
                
            case 4:
            {
                if (packet.data && ![packet.data isEqualToString:@""])
                {
                    if ([_delegate respondsToSelector:@selector(rocketIO:didReceiveJSON:)]) 
                    {
                        [_delegate rocketIO:self didReceiveJSON:packet];
                    }
                }
            }
                break;
                
            case 5:
            {
                if (packet.data && ![packet.data isEqualToString:@""])
                { 
                    NSDictionary *json = [packet dataAsJSON];
                    packet.name = [json objectForKey:@"name"];
                    packet.args = [json objectForKey:@"args"];
                    if ([_delegate respondsToSelector:@selector(rocketIO:didReceiveEvent:)]) 
                    {
                        [_delegate rocketIO:self didReceiveEvent:packet];
                    }
                }
            }
                break;
                
            case 6:
            {
                NSArray *pieces = [self arrayOfCaptureComponentsOfString:packet.data matchedByRegex:regexPieces];
                
                if ([pieces count] > 0) 
                {
                    NSArray *piece = [pieces objectAtIndex:0];
                    int ackId = [[piece objectAtIndex:1] intValue];
                    
                    NSString *argsStr = [piece objectAtIndex:3];
                    id argsData = nil;
                    if (argsStr && ![argsStr isEqualToString:@""])
                    {
                        NSError *e = nil;
                        argsData = [NSJSONSerialization JSONObjectWithData:[argsStr dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:&e];
                        
                        if ([argsData count] > 0)
                        {
                            argsData = [argsData objectAtIndex:0];
                        }
                    }
                    
                    // get selector for ackId
                    NSString *key = [NSString stringWithFormat:@"%d", ackId];
                    SocketIOCallback callbackFunction = [_acks objectForKey:key];
                    if (callbackFunction != nil)
                    {
                        callbackFunction(argsData);
                        [self removeAcknowledgeForKey:key];
                    }
                }
            }
                
                break;
                
            case 7:
            {
                NSLog(@"RocketIO error");
            }
                break;
                
            case 8:
            {
                // Noop
            }
                break;
                
            default:
            {
                NSLog(@"RocketIO command not found or not yet supported");

            }
                break;
        }
        
    }
    else
    {
        NSLog(@"RocketIO ERROR: data that has arrived wasn't valid");
    }
}



# pragma mark -
# pragma mark private methods

- (void) openSocket
{
    NSString *urlString = [NSString stringWithFormat:SOCKET_URL, _host, _port, _sid];
    
    [_webSocket close];
    self.webSocket = nil;
    
    self.webSocket = [[SRWebSocket alloc] initWithURL:[NSURL URLWithString:urlString]];
    _webSocket.delegate = self;
    [_webSocket open];
}

- (void) sendDisconnect
{
    SocketIOPacket *packet = [[SocketIOPacket alloc] initWithType:@"disconnect"];
    [self send:packet];
}

- (void) sendConnect
{
    SocketIOPacket *packet = [[SocketIOPacket alloc] initWithType:@"connect"];
    [self send:packet];
}

- (void) sendHeartbeat
{
    SocketIOPacket *packet = [[SocketIOPacket alloc] initWithType:@"heartbeat"];
    [self send:packet];
}

- (void) send:(SocketIOPacket *)packet
{   

    NSNumber *type = [packet typeAsNumber];
    NSMutableArray *encoded = [NSMutableArray arrayWithObject:type];
    
    NSString *pId = packet.pId != nil ? packet.pId : @"";
    if ([packet.ack isEqualToString:@"data"])
    {
        pId = [pId stringByAppendingString:@"+"];
    }
    
    // Do not write pid for acknowledgements
    if ([type intValue] != 6) {
        [encoded addObject:pId];
    }
    
    // Add the end point for the namespace to be used, as long as it is not
    // an ACK, heartbeat, or disconnect packet
    if ([type intValue] != 6 && [type intValue] != 2 && [type intValue] != 0) {
        [encoded addObject:_endpoint];
    } else {
        [encoded addObject:@""];
    }
    
    if (packet.data != nil)
    {
        NSString *ackpId = @"";
        // This is an acknowledgement packet, so, prepend the ack pid to the data
        if ([type intValue] == 6) {
            ackpId = [NSString stringWithFormat:@":%@%@", packet.pId, @"+"];
        }
        
        [encoded addObject:[NSString stringWithFormat:@"%@%@", ackpId, packet.data]];
    }
    
    NSString *req = [encoded componentsJoinedByString:@":"];
    if (!_isConnected) 
    {
        [_queue addObject:packet];
    } 
    else 
    {
        [_webSocket send:req];
        
        if ([_delegate respondsToSelector:@selector(rocketIO:didSendMessage:)])
        {
            [_delegate rocketIO:self didSendMessage:packet];
        }
    }
}

- (void) sendMessage:(NSString *)data
{
    [self sendMessage:data withAcknowledge:nil];
}

- (void) sendMessage:(NSString *)data withAcknowledge:(SocketIOCallback)function
{
    SocketIOPacket *packet = [[SocketIOPacket alloc] initWithType:@"message"];
    packet.data = data;
    packet.pId = [self addAcknowledge:function];
    [self send:packet];
}

- (void) sendJSON:(NSDictionary *)data
{
    [self sendJSON:data withAcknowledge:nil];
}

- (void) sendJSON:(NSDictionary *)data withAcknowledge:(SocketIOCallback)function
{
    SocketIOPacket *packet = [[SocketIOPacket alloc] initWithType:@"json"];
    NSError *e = nil;
    packet.data = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:data options:NSJSONWritingPrettyPrinted error:&e] encoding:NSUTF8StringEncoding];
    packet.pId = [self addAcknowledge:function];
    [self send:packet];
}

- (void) sendEvent:(NSString *)eventName withData:(NSDictionary *)data
{
    [self sendEvent:eventName withData:data andAcknowledge:nil];
}

- (void) sendEvent:(NSString *)eventName withData:(NSDictionary *)data andAcknowledge:(SocketIOCallback)function
{
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithObject:eventName forKey:@"name"];
    if (data != nil) // do not require arguments
        [dict setObject:data forKey:@"args"];
    
    SocketIOPacket *packet = [[SocketIOPacket alloc] initWithType:@"event"];
    NSError *e = nil;
    packet.data =  [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&e] encoding:NSUTF8StringEncoding];
    packet.pId = [self addAcknowledge:function];
    if (function) 
    {
        packet.ack = @"data";
    }
    [self send:packet];
}

- (void)sendAcknowledgement:(NSString *)pId withArgs:(NSArray *)data {
    SocketIOPacket *packet = [[SocketIOPacket alloc] initWithType:@"ack"];
    NSError *e = nil;
    packet.data =  [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:data options:NSJSONWritingPrettyPrinted error:&e] encoding:NSUTF8StringEncoding];
    packet.pId = pId;
    packet.ack = @"data";
    
    [self send:packet];
}


# pragma mark -
# pragma mark Acknowledge methods

- (NSString *) addAcknowledge:(SocketIOCallback)function
{
    if (function)
    {
        ++_ackCount;
        NSString *ac = [NSString stringWithFormat:@"%d", _ackCount];
        [_acks setObject:[function copy] forKey:ac];
        return ac;
    }
    return nil;
}

- (void) removeAcknowledgeForKey:(NSString *)key
{
    [_acks removeObjectForKey:key];
}

#pragma mark NSURLConnection
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	[_responseData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	[_responseData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    
    _isConnected = NO;
    _isConnecting = NO;
    
    if ([_delegate respondsToSelector:@selector(rocketIOHandshakeFailed:)])
    {
        [_delegate rocketIOHandshakeFailed:self];
    }

}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    NSString *responseString = [[NSString alloc] initWithData:_responseData encoding:NSUTF8StringEncoding];
    
    NSArray *data = [responseString componentsSeparatedByString:@":"];
    
    self.sid = [data objectAtIndex:0];
    
    // add small buffer of 7sec (magic xD)
    _heartbeatTimeout = [[data objectAtIndex:1] floatValue] + 7.0;
    
    // index 2 => connection timeout
    
    //NSString *t = [data objectAtIndex:3];
    //NSArray *transports = [t componentsSeparatedByString:@","];
    
    [self openSocket];

}


#pragma mark SRWebSocket delegate

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {
    if ([message isKindOfClass:[NSString class]]) {
        [self onData:message];
    } else {
        NSLog(@"message was not string");
    }
}
- (void)webSocketDidOpen:(SRWebSocket *)webSocket {
}
- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
    [self onDisconnect];
}
- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    [self onDisconnect];
}


@end


# pragma mark SocketIOPacket implementation

@implementation SocketIOPacket

@synthesize type, pId, name, ack, data, args, endpoint;

- (id) init
{
    self = [super init];
    if (self)
    {
        _types = [NSArray arrayWithObjects: @"disconnect", 
                  @"connect", 
                  @"heartbeat", 
                  @"message", 
                  @"json", 
                  @"event", 
                  @"ack", 
                  @"error", 
                  @"noop", 
                  nil] ;
    }
    return self;
}

- (id) initWithType:(NSString *)packetType
{
    self = [self init];
    if (self)
    {
        self.type = packetType;
    }
    return self;
}

- (id) initWithTypeIndex:(int)index
{
    self = [self init];
    if (self)
    {
        self.type = [self typeForIndex:index];
    }
    return self;
}

- (id) dataAsJSON
{
    NSError *e = nil;
    return [NSJSONSerialization JSONObjectWithData:[self.data dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:&e];
}

- (NSNumber *) typeAsNumber
{
    int index = [_types indexOfObject:self.type];
    NSNumber *num = [NSNumber numberWithInt:index];
    return num;
}

- (NSString *) typeForIndex:(int)index
{
    return [_types objectAtIndex:index];
}



@end