//
//  CONApiClient.h
//  APNSClient
//
//  Created by Sergio Artero Martinez on 11/10/13.
//  Copyright (c) 2013 Sergio Artero Martinez. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum _CONApiRequestError {
    ErrorGeneric = 0,
    Ok = 1, // 2xx
    ConnectionError = -1,
    ServerError = 500, // 5xx
    BadRequest = 400,
    Unauthorized = 401,
    Forbidden = 403,
    NotFound = 404,
    Conflict = 409,
    Gone = 410,
    UpgradeRequired = 426,
    TooManyRequests = 429
} CONApiRequestError;

typedef void (^requestCompletionBlock)(CONApiRequestError success, NSData *responseData);

@interface CONApiClient : NSObject


+ (void)publishPushToken:(NSString *)pushToken withCompletionBlock:(requestCompletionBlock)completion;
+ (void)revokePushToken:(NSString *)pushToken withCompletionBlock:(requestCompletionBlock)completion;
+ (void)triggerRemotePushWithToken:(NSString *)pushToken andCompletionBlock:(requestCompletionBlock)completion;
+ (void)acknowledgePushReceptionWithCorrelationId:(NSString *)guid
                                       withBearer:(NSString *)bearer
                                     andTimestamp:(NSTimeInterval)timestamp
                              withCompletionBlock:(requestCompletionBlock)completion;


@end
