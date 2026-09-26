//
//  NSString+UUID.m
//  LastFMAPI
//
//  Created by Nicolas Haunold on 4/26/09.
//  Copyright 2009 Tapolicious Software. All rights reserved.
//

// Thanks to Sam Steele / c99koder for -[NSString md5sum];

#import "NSString+FMEngine.h"
#import <CommonCrypto/CommonDigest.h>

@implementation NSString (FMEngineAdditions)

+ (NSString *)stringWithNewUUID {
    CFUUIDRef uuidObj = CFUUIDCreate(nil);

    NSString *newUUID = (__bridge_transfer NSString*)CFUUIDCreateString(nil, uuidObj);
    CFRelease(uuidObj);
    return newUUID;
}

- (NSString*) urlEncoded {
  NSMutableCharacterSet *allowedCharacters = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
  [allowedCharacters removeCharactersInString:@"!*'();:@&=+$,/?%#[]"];
  return [self stringByAddingPercentEncodingWithAllowedCharacters:allowedCharacters];
}

- (NSString *)md5sum {
  unsigned char digest[CC_MD5_DIGEST_LENGTH], i;

  // Last.fm API signatures are defined as MD5, so keep this compatibility
  // call isolated to the legacy FMEngine integration.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  CC_MD5([self UTF8String], (uint32_t)[self lengthOfBytesUsingEncoding:NSUTF8StringEncoding], digest);
#pragma clang diagnostic pop

  NSMutableString *ms = [NSMutableString string];
  for (i=0;i<CC_MD5_DIGEST_LENGTH;i++) {
    [ms appendFormat: @"%02x", (int)(digest[i])];
  }
  return [ms copy];
}

@end
