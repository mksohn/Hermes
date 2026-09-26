//
//  main.m
//  Pithos
//
//  Created by Alex Crichton on 3/11/11.
//

#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>

static NSString * const HermesSparkleAutomaticallyChecksKey = @"SUEnableAutomaticChecks";
static NSString * const HermesSparkleAutomaticallyDownloadsKey = @"SUAutomaticallyUpdate";
static NSString * const HermesSparkleUpdateIntervalKey = @"SUScheduledCheckInterval";

static BOOL HermesBoolDefaultForKey(NSString *key, BOOL fallbackValue) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  return [defaults objectForKey:key] == nil ? fallbackValue : [defaults boolForKey:key];
}

static NSTimeInterval HermesUpdateCheckIntervalDefault(void) {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  return [defaults objectForKey:HermesSparkleUpdateIntervalKey] == nil
      ? 86400.0
      : [defaults doubleForKey:HermesSparkleUpdateIntervalKey];
}

@interface HermesSparkleFallbackUpdater : NSObject
@property (nonatomic) BOOL automaticallyChecksForUpdates;
@property (nonatomic) BOOL automaticallyDownloadsUpdates;
@property (nonatomic) NSTimeInterval updateCheckInterval;
- (IBAction)checkForUpdates:(id)sender;
@end

@implementation HermesSparkleFallbackUpdater

- (instancetype)init {
  self = [super init];
  if (self != nil) {
    _automaticallyChecksForUpdates = HermesBoolDefaultForKey(HermesSparkleAutomaticallyChecksKey, YES);
    _automaticallyDownloadsUpdates = HermesBoolDefaultForKey(HermesSparkleAutomaticallyDownloadsKey, NO);
    _updateCheckInterval = HermesUpdateCheckIntervalDefault();
  }
  return self;
}

- (void)setAutomaticallyChecksForUpdates:(BOOL)automaticallyChecksForUpdates {
  _automaticallyChecksForUpdates = automaticallyChecksForUpdates;
  [[NSUserDefaults standardUserDefaults] setBool:automaticallyChecksForUpdates
                                          forKey:HermesSparkleAutomaticallyChecksKey];
}

- (void)setAutomaticallyDownloadsUpdates:(BOOL)automaticallyDownloadsUpdates {
  _automaticallyDownloadsUpdates = automaticallyDownloadsUpdates;
  [[NSUserDefaults standardUserDefaults] setBool:automaticallyDownloadsUpdates
                                          forKey:HermesSparkleAutomaticallyDownloadsKey];
}

- (void)setUpdateCheckInterval:(NSTimeInterval)updateCheckInterval {
  _updateCheckInterval = updateCheckInterval;
  [[NSUserDefaults standardUserDefaults] setDouble:updateCheckInterval
                                            forKey:HermesSparkleUpdateIntervalKey];
}

- (IBAction)checkForUpdates:(id)sender {
  NSAlert *alert = [[NSAlert alloc] init];
  alert.messageText = @"Software Update Unavailable";
  alert.informativeText = @"Hermes could not load its bundled Sparkle framework, so update checking is unavailable in this build.";
  [alert addButtonWithTitle:@"OK"];
  [alert runModal];
}

@end

#if defined(__arm64__)
@interface SUUpdater : HermesSparkleFallbackUpdater
@end

@implementation SUUpdater
@end
#endif

static void HermesEnsureSparkleUpdaterClass(void) {
  if (NSClassFromString(@"SUUpdater") != Nil) {
    return;
  }

  NSString *privateFrameworksPath = [[NSBundle mainBundle] privateFrameworksPath];
  if (privateFrameworksPath != nil) {
    NSString *sparklePath = [privateFrameworksPath stringByAppendingPathComponent:@"Sparkle.framework"];
    NSBundle *sparkleBundle = [NSBundle bundleWithPath:sparklePath];
    [sparkleBundle load];
  }

  if (NSClassFromString(@"SUUpdater") != Nil) {
    return;
  }

  Class updaterClass = objc_allocateClassPair([HermesSparkleFallbackUpdater class], "SUUpdater", 0);
  if (updaterClass == Nil) {
    return;
  }

  objc_registerClassPair(updaterClass);
}

int main(int argc, char *argv[]) {
  @autoreleasepool {
    HermesEnsureSparkleUpdaterClass();
    return NSApplicationMain(argc, (const char **) argv);
  }
}
