typedef void(^URLConnectionCallback)(NSData*, NSError*);

extern NSString * const URLConnectionProxyValidityChangedNotification;

@interface URLConnection : NSObject

+ (URLConnection*) connectionForRequest:(NSURLRequest*)request
                      completionHandler:(URLConnectionCallback) cb;
+ (BOOL) validProxyHost:(NSString **)host port:(NSInteger)port;

- (void) start;
- (void) setHermesProxy;

@end
