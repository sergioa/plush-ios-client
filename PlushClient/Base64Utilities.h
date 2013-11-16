//
//  Base64Utilities.h
//  PlushClient
//
//  Created by Sergio Artero Martinez on 19/10/13.
//  Copyright (c) 2013 Sergio Artero Martinez. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Base64Utilities : NSObject

// Base 64 code & decode from : https://github.com/mikeho/QSUtilities/blob/master/QSStrings.m
+ (NSString *)encodeBase64WithData:(NSData *)objData;
+ (NSData *)decodeBase64WithString:(NSString *)strBase64;

@end
