# Socket.IO / Objective C Library

  Interface to communicate between Objective C and [Socket.IO](http://socket.io/)  
  with the help of websockets. It's completely based on [socket.IO-objc](https://raw.github.com/pkyeck/socket.IO-objc)  
  Most dependencies have been removed from the original project.  
  It now uses iOS 5 JSON and iOS 4 Regex, so iOS >= 5 is needed.  
  It's ARC enabled.  
  Not heavily tested but seems to work for my needs, feel free to contribute.  

  You need [SocketRocket](https://github.com/square/SocketRocket) for the websocket.  

## Usage

  The easiest way to connect to your Socket.IO / node.js server is

    RocketIO *rocketIO = [[RocketIO alloc] initWithDelegate:self];
    [rocketIO connectToHost:@"localhost" onPort:3000];

  If required, additional parameters can be included in the handshake by adding an `NSDictionary` to the `withParams` option:

    [rocketIO connectToHost:@"localhost" onPort:3000 withParams:[NSDictionary dictionaryWithObjectsAndKeys:@"1234","auth_token",nil]];

  A namespace can also be defined in the connection details:

    [rocketIO connectToHost:@"localhost" onPort:3000 withParams:nil withNamespace:@"/users"];

  There are different methods to send data to the server 

    - (void) sendMessage:(NSString *)data;
	- (void) sendMessage:(NSString *)data withAcknowledge:(SocketIOCallback)function;
	- (void) sendJSON:(NSDictionary *)data;
	- (void) sendJSON:(NSDictionary *)data withAcknowledge:(SocketIOCallback)function;
	- (void) sendEvent:(NSString *)eventName withData:(NSDictionary *)data;
	- (void) sendEvent:(NSString *)eventName withData:(NSDictionary *)data andAcknowledge:(SocketIOCallback)function;
	
  So you could send a normal Message like this

    [rocketIO sendMessage:@"hello world"];

  or an Event (including some data) like this

    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
	[dict setObject:@"test1" forKey:@"key1"];
	[dict setObject:@"test2" forKey:@"key2"];
	
	[rocketIO sendEvent:@"welcome" withData:dict];
	
  If you want the server to acknowledge your Message/Event you would also pass a SocketIOCallback block
	
	SocketIOCallback cb = ^(id argsData) {
		NSDictionary *response = argsData;
		// do something with response
	};
	[rocketIO sendEvent:@"welcomeAck" withData:dict andAcknowledge:cb];
	
  All delegate methods are optional - you could implement the following

    - (void) rocketIODidConnect:(RocketIO *)socket;
	- (void) rocketIODidDisconnect:(RocketIO *)socket;
	- (void) rocketIO:(RocketIO *)socket didReceiveMessage:(SocketIOPacket *)packet;
	- (void) rocketIO:(RocketIO *)socket didReceiveJSON:(SocketIOPacket *)packet;
	- (void) rocketIO:(RocketIO *)socket didReceiveEvent:(SocketIOPacket *)packet;
	- (void) rocketIO:(RocketIO *)socket didSendMessage:(SocketIOPacket *)packet;

  To process an incoming Message just

    - (void) rocketIO:(RocketIO *)socket didReceiveMessage:(SocketIOPacket *)packet
	{
	    NSLog(@"didReceiveMessage() >>> data: %@", packet.data);
	}

## Demo

  The demo is working great with [Tornadio2 gen example](https://github.com/mrjoes/tornadio2/)
  but should work with any SocketIO compatible server.
  
## Next steps

  For one, Rooms are not yet supported.
  Error command handling still missing.
  ... and there may be other things I didn't think of.

## Authors

Initial project by Philipp Kyeck <philipp@beta-interactive.de>.
Namespace support by Sam Lown <sam@cabify.com> at Cabify.
Socket Rocket, ARC and iOS 5 Fabrice Aneche akh at nobugware.com

## License 

(The MIT License)

Copyright (c) 2011 Philipp Kyeck <philipp@beta-interactive.de>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.
 
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.