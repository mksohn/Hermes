#import <SPMediaKeyTap/SPMediaKeyTap.h>

#import "PlaybackController.h"
#import "PreferencesController.h"
#import "URLConnection.h"

static NSString * const HMSPreferencesToolbarItemGeneral = @"general";
static NSString * const HMSPreferencesToolbarItemPlayback = @"playback";
static NSString * const HMSPreferencesToolbarItemNetwork = @"network";

@implementation PreferencesController

- (void)awakeFromNib {
  [super awakeFromNib];

  [self configureToolbar];

  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(proxyServerValidityChanged:) name:URLConnectionProxyValidityChangedNotification object:nil];
}

- (void)configureToolbar {
  [toolbar setDelegate:self];

  if ([[toolbar items] count] == 0) {
    for (NSString *identifier in [self toolbarDefaultItemIdentifiers:toolbar]) {
      [toolbar insertItemWithItemIdentifier:identifier atIndex:[[toolbar items] count]];
    }
  }
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)aToolbar {
  return @[
    HMSPreferencesToolbarItemGeneral,
    HMSPreferencesToolbarItemPlayback,
    HMSPreferencesToolbarItemNetwork
  ];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)aToolbar {
  return @[
    HMSPreferencesToolbarItemGeneral,
    HMSPreferencesToolbarItemPlayback,
    HMSPreferencesToolbarItemNetwork
  ];
}

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)aToolbar {
  return [self toolbarDefaultItemIdentifiers:aToolbar];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)aToolbar
     itemForItemIdentifier:(NSString *)identifier
 willBeInsertedIntoToolbar:(BOOL)willBeInserted {
  if ([identifier isEqualToString:HMSPreferencesToolbarItemGeneral]) {
    return [self toolbarItemWithIdentifier:identifier
                                     label:@"General"
                              paletteLabel:@"General"
                                   toolTip:@"General Settings"
                                     image:@"NSPreferencesGeneral"
                                    action:@selector(showGeneral:)];
  }

  if ([identifier isEqualToString:HMSPreferencesToolbarItemPlayback]) {
    return [self toolbarItemWithIdentifier:identifier
                                     label:@"Playback"
                              paletteLabel:@"Playback"
                                   toolTip:@"Playback Settings"
                                     image:@"play"
                                    action:@selector(showPlayback:)];
  }

  if ([identifier isEqualToString:HMSPreferencesToolbarItemNetwork]) {
    return [self toolbarItemWithIdentifier:identifier
                                     label:@"Network"
                              paletteLabel:@"Network"
                                   toolTip:@"Network Settings"
                                     image:@"NSNetwork"
                                    action:@selector(showNetwork:)];
  }

  return nil;
}

- (NSToolbarItem *)toolbarItemWithIdentifier:(NSString *)identifier
                                       label:(NSString *)label
                                paletteLabel:(NSString *)paletteLabel
                                     toolTip:(NSString *)toolTip
                                       image:(NSString *)imageName
                                      action:(SEL)action {
  NSToolbarItem *item = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
  [item setLabel:label];
  [item setPaletteLabel:paletteLabel];
  [item setToolTip:toolTip];
  [item setImage:[NSImage imageNamed:imageName]];
  [item setTarget:self];
  [item setAction:action];
  return item;
}

- (void)windowDidBecomeMain:(NSNotification *)notification {
  /* See HermesAppDelegate#updateStatusBarIcon */
  [window setCanHide:NO];

  if (PREF_KEY_BOOL(STATUS_BAR_ICON_BW))
    statusItemShowBlackAndWhiteIcon.state = NSControlStateValueOn;
  else if (PREF_KEY_BOOL(STATUS_BAR_ICON_ALBUM))
    statusItemShowAlbumArt.state = NSControlStateValueOn;
  else
    statusItemShowColorIcon.state = NSControlStateValueOn;

  NSString *last = PREF_KEY_VALUE(LAST_PREF_PANE);
  if (NSClassFromString(@"NSUserNotification") != nil) {
    [notificationEnabled setTitle:@""];
    [notificationType setHidden:NO];
  }

  if (itemIdentifiers == nil) {
    itemIdentifiers = [[toolbar items] valueForKey:@"itemIdentifier"];
  }

  if ([last isEqual:@"playback"]) {
    [toolbar setSelectedItemIdentifier:@"playback"];
    [self setPreferenceView:playback as:@"playback"];
  } else if ([last isEqual:@"network"]) {
    [toolbar setSelectedItemIdentifier:@"network"];
    [self setPreferenceView:network as:@"network"];
  } else {
    [toolbar setSelectedItemIdentifier:@"general"];
    [self setPreferenceView:general as:@"general"];
  }
}

- (void) setPreferenceView:(NSView*) view as:(NSString*)name {
  NSView *container = [window contentView];
  if ([[container subviews] count] > 0) {
    NSView *prev_view = [container subviews][0];
    if (prev_view == view) {
      return;
    }
    [prev_view removeFromSuperviewWithoutNeedingDisplay];
  }

  NSRect frame = [view bounds];
  frame.origin.y = NSHeight([container frame]) - NSHeight([view bounds]);
  [view setFrame:frame];
  [view setAutoresizingMask:NSViewMinYMargin | NSViewWidthSizable];
  [container addSubview:view];
  [window setInitialFirstResponder:view];

  NSRect windowFrame = [window frame];
  NSRect contentRect = [window contentRectForFrameRect:windowFrame];
  windowFrame.size.height = NSHeight(frame) + NSHeight(windowFrame) - NSHeight(contentRect);
  windowFrame.size.width = NSWidth(frame);
  windowFrame.origin.y = NSMaxY([window frame]) - NSHeight(windowFrame);
  [window setFrame:windowFrame display:YES animate:YES];

  NSUInteger toolbarItemIndex = [itemIdentifiers indexOfObject:name];
  NSString *title = @"Preferences";
  if (toolbarItemIndex != NSNotFound) {
    title = [[toolbar items][toolbarItemIndex] label];
  }
  [window setTitle:title];

  if ([HMSAppDelegate playback].mediaKeyTap == nil) {
    mediaKeysCheckbox.enabled = NO;
#ifndef MPREMOTECOMMANDCENTER_MEDIA_KEYS_BROKEN
    if ([HMSAppDelegate playback].remoteCommandCenter != nil) {
      mediaKeysCheckbox.integerValue = YES;
      mediaKeysLabel.stringValue = @"Play/pause and next track keys are always enabled in macOS 10.12.2 and later.";
    } else {
#endif
#if DEBUG
      mediaKeysLabel.stringValue = @"Media keys are not available because this version of Hermes is compiled in debug mode.";
#else
      mediaKeysLabel.stringValue = @"Media keys are unavailable for an unknown reason.";
#endif
#ifndef MPREMOTECOMMANDCENTER_MEDIA_KEYS_BROKEN
    }
#endif
  }

  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:name forKey:LAST_PREF_PANE];
}

- (IBAction) showGeneral: (id) sender {
  [self setPreferenceView:general as:@"general"];
}

- (IBAction) showPlayback: (id) sender {
  [self setPreferenceView:playback as:@"playback"];
}

- (IBAction) showNetwork: (id) sender {
  [self setPreferenceView:network as:@"network"];
}

- (IBAction) statusItemIconChanged:(id)sender {
  if (sender == statusItemShowColorIcon) {
    PREF_KEY_SET_BOOL(STATUS_BAR_ICON_BW, NO);
    PREF_KEY_SET_BOOL(STATUS_BAR_ICON_ALBUM, NO);
  } else if (sender == statusItemShowBlackAndWhiteIcon) {
    PREF_KEY_SET_BOOL(STATUS_BAR_ICON_BW, YES);
    PREF_KEY_SET_BOOL(STATUS_BAR_ICON_ALBUM, NO);
  } else if (sender == statusItemShowAlbumArt) {
    PREF_KEY_SET_BOOL(STATUS_BAR_ICON_BW, NO);
    PREF_KEY_SET_BOOL(STATUS_BAR_ICON_ALBUM, YES);
  }
  [HMSAppDelegate updateStatusItem:sender];
}

- (IBAction) bindMediaChanged: (id) sender {
  SPMediaKeyTap *mediaKeyTap = [HMSAppDelegate playback].mediaKeyTap;
  if (!mediaKeyTap)
    return;

  if (PREF_KEY_BOOL(PLEASE_BIND_MEDIA)) {
    [mediaKeyTap startWatchingMediaKeys];
  } else {
    [mediaKeyTap stopWatchingMediaKeys];
  }
}

- (IBAction) show: (id) sender {
  [NSApp activateIgnoringOtherApps:YES];
  [window makeKeyAndOrderFront:sender];
}

- (IBAction)proxySettingsChanged:(id)sender {
  BOOL proxyValid = NO;
  NSString *proxyHost = nil;
  NSInteger proxyPort = 0;

  switch (PREF_KEY_INT(ENABLED_PROXY)) {
    case PROXY_SYSTEM:
      proxyValid = YES;
      break;
    case PROXY_HTTP:
      proxyHost = PREF_KEY_VALUE(PROXY_HTTP_HOST);
      proxyPort = PREF_KEY_INT(PROXY_HTTP_PORT);
      break;
    case PROXY_SOCKS:
      proxyHost = PREF_KEY_VALUE(PROXY_SOCKS_HOST);
      proxyPort = PREF_KEY_INT(PROXY_SOCKS_PORT);
      break;
    default:
      proxyValid = YES;
      break;
  }
  if (!proxyValid) {
    proxyValid = [URLConnection validProxyHost:&proxyHost port:proxyPort];
  }
  proxyServerErrorMessage.hidden = proxyValid;
}

- (void)proxyServerValidityChanged:(NSNotification *)notification {
  BOOL proxyServerValid = [notification.userInfo[@"isValid"] boolValue];
  proxyServerErrorMessage.hidden = proxyServerValid;
  if (!proxyServerValid) {
    [self showNetwork:nil];
    [window orderFront:nil];
  }
}

@end

