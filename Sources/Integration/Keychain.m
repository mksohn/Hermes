//
//  Keychain.h
//  Hermes
//
//  Created by Alex Crichton on 11/19/11.
//

#import "Keychain.h"
#import <Security/Security.h>

static NSMutableDictionary *KeychainQueryForUsername(NSString *username) {
  NSMutableDictionary *query = [@{
    (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
    (__bridge id)kSecAttrService: @KEYCHAIN_SERVICE_NAME,
    (__bridge id)kSecAttrAccount: username
  } mutableCopy];
  return query;
}

BOOL KeychainSetItem(NSString* username, NSString* password) {
  if (username == nil || password == nil) {
    return NO;
  }

  NSData *passwordData = [password dataUsingEncoding:NSUTF8StringEncoding];
  if (passwordData == nil) {
    return NO;
  }

  NSMutableDictionary *query = KeychainQueryForUsername(username);
  NSDictionary *attributes = @{
    (__bridge id)kSecValueData: passwordData
  };

  OSStatus result = SecItemUpdate((__bridge CFDictionaryRef)query,
                                  (__bridge CFDictionaryRef)attributes);
  if (result == errSecItemNotFound) {
    query[(__bridge id)kSecValueData] = passwordData;
    result = SecItemAdd((__bridge CFDictionaryRef)query, NULL);
  }

  return result == errSecSuccess;
}

NSString *KeychainGetPassword(NSString* username) {
  if (username == nil) {
    return nil;
  }

  NSMutableDictionary *query = KeychainQueryForUsername(username);
  query[(__bridge id)kSecReturnData] = @YES;
  query[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;

  CFTypeRef passwordDataRef = NULL;
  OSStatus result = SecItemCopyMatching((__bridge CFDictionaryRef)query,
                                        &passwordDataRef);

  if (result != errSecSuccess || passwordDataRef == NULL) {
    return nil;
  }

  NSData *passwordData = (__bridge NSData *)passwordDataRef;
  NSString *password = [[NSString alloc] initWithData:passwordData
                                             encoding:NSUTF8StringEncoding];
  CFRelease(passwordDataRef);

  return password;
}
