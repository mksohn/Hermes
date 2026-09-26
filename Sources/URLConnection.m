#import <CFNetwork/CFNetwork.h>

#import "PreferencesController.h"
#import "URLConnection.h"

NSString * const URLConnectionProxyValidityChangedNotification = @"URLConnectionProxyValidityChangedNotification";

static const NSTimeInterval URLConnectionTimeout = 10.0;

@interface URLConnection () <NSURLSessionDelegate> {
  NSURLRequest *request;
  NSURLSession *session;
  NSURLSessionDataTask *task;
  URLConnectionCallback cb;
  URLConnection *activeConnection;
  BOOL useHermesProxy;
}

+ (NSDictionary*) hermesProxySettings;
+ (NSDictionary*) HTTPProxySettingsWithHost:(NSString*)host
                                      port:(NSInteger)port;
+ (NSDictionary*) SOCKSProxySettingsWithHost:(NSString*)host
                                       port:(NSInteger)port;
- (void) finishWithData:(NSData*)data error:(NSError*)error;

@end

@implementation URLConnection

- (void) dealloc {
  [task cancel];
  [session invalidateAndCancel];
}

/**
 * @brief Creates a new instance for the specified request
 *
 * @param request the request to be sent
 * @param cb the callback to invoke when the request is done. If an error
 *        happened, then the data will be nil, and the error will be valid.
 *        Otherwise the data will be valid and the error will be nil.
 */
+ (URLConnection*) connectionForRequest:(NSURLRequest*)request
                      completionHandler:(void(^)(NSData*, NSError*)) cb {

  URLConnection *c = [[URLConnection alloc] init];
  c->request = [request copy];
  c->cb = [cb copy];
  c->useHermesProxy = YES;
  [c setHermesProxy];
  return c;
}

/**
 * @brief Start sending this request to the server
 */
- (void) start {
  if (task != nil) {
    return;
  }

  NSURLSessionConfiguration *configuration =
      [NSURLSessionConfiguration ephemeralSessionConfiguration];
  configuration.timeoutIntervalForRequest = URLConnectionTimeout;
  if (useHermesProxy) {
    configuration.connectionProxyDictionary = [URLConnection hermesProxySettings];
  }

  activeConnection = self;
  session = [NSURLSession sessionWithConfiguration:configuration
                                          delegate:self
                                     delegateQueue:[NSOperationQueue mainQueue]];
  task = [session dataTaskWithRequest:request
                    completionHandler:^(NSData *data,
                                        NSURLResponse *response,
                                        NSError *error) {
    [self finishWithData:data error:error];
  }];
  [task resume];
}

- (void) setHermesProxy {
  useHermesProxy = YES;
}

- (void) finishWithData:(NSData*)data error:(NSError*)error {
  URLConnectionCallback callback = cb;
  NSURLSession *finishedSession = session;
  NSData *callbackData = error == nil ? (data ?: [NSData data]) : nil;

  cb = nil;
  task = nil;
  session = nil;
  activeConnection = nil;

  [finishedSession finishTasksAndInvalidate];
  if (callback != nil) {
    callback(callbackData, error);
  }
}

- (void) URLSession:(NSURLSession*)URLSession
didReceiveChallenge:(NSURLAuthenticationChallenge*)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition,
                             NSURLCredential *credential))completionHandler {
  NSURLProtectionSpace *protectionSpace = [challenge protectionSpace];
  if ([[protectionSpace authenticationMethod] isEqualToString:NSURLAuthenticationMethodServerTrust] &&
      [protectionSpace serverTrust] != NULL) {
    NSURLCredential *credential =
        [NSURLCredential credentialForTrust:[protectionSpace serverTrust]];
    completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
    return;
  }

  completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
}

+ (NSDictionary*) hermesProxySettings {
  switch (PREF_KEY_INT(ENABLED_PROXY)) {
    case PROXY_HTTP:
      return [self HTTPProxySettingsWithHost:PREF_KEY_VALUE(PROXY_HTTP_HOST)
                                        port:PREF_KEY_INT(PROXY_HTTP_PORT)];

    case PROXY_SOCKS:
      return [self SOCKSProxySettingsWithHost:PREF_KEY_VALUE(PROXY_SOCKS_HOST)
                                         port:PREF_KEY_INT(PROXY_SOCKS_PORT)];

    case PROXY_SYSTEM:
    default:
      return CFBridgingRelease(CFNetworkCopySystemProxySettings());
  }
}

+ (BOOL)validProxyHost:(NSString **)host port:(NSInteger)port {
  static BOOL wasValid = YES;
  *host = [*host stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
  BOOL isValid = (([*host length] > 0) &&
                  (port > 0 && port <= 65535) &&
                  [NSHost hostWithName:*host].address != nil);
  if (isValid != wasValid) {
    [[NSNotificationCenter defaultCenter] postNotificationName:URLConnectionProxyValidityChangedNotification
                                                        object:nil
                                                      userInfo:@{@"isValid": @(isValid)}];
    wasValid = isValid;
  }
  return isValid;
}

+ (NSDictionary*) HTTPProxySettingsWithHost:(NSString*)host
                                      port:(NSInteger)port {
  if (![self validProxyHost:&host port:port]) return nil;
  return @{(NSString*)kCFNetworkProxiesHTTPEnable: @YES,
           (NSString*)kCFNetworkProxiesHTTPProxy: host,
           (NSString*)kCFNetworkProxiesHTTPPort: @(port),
           (NSString*)kCFNetworkProxiesHTTPSEnable: @YES,
           (NSString*)kCFNetworkProxiesHTTPSProxy: host,
           (NSString*)kCFNetworkProxiesHTTPSPort: @(port)};
}

+ (NSDictionary*) SOCKSProxySettingsWithHost:(NSString*)host
                                       port:(NSInteger)port {
  if (![self validProxyHost:&host port:port]) return nil;
  return @{(NSString*)kCFNetworkProxiesSOCKSEnable: @YES,
           (NSString*)kCFNetworkProxiesSOCKSProxy: host,
           (NSString*)kCFNetworkProxiesSOCKSPort: @(port)};
}

@end
