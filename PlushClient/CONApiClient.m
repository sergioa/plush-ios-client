//
//  CONApiClient.m
//  APNSClient
//
//  Created by Sergio Artero Martinez on 11/10/13.
//  Copyright (c) 2013 Sergio Artero Martinez. All rights reserved.
//

#import "CONApiClient.h"
#import "Base64Utilities.h"
#import <Crashlytics/Crashlytics.h>

#define ROOT_PATH @"http://plush.juandebravo.com/api"
#define DEVICE_TOKEN_URI @"/device_tokens/%@"
#define SEND_PUSH_URI @"push"
#define BROADCAST_PUSH_URI @"broadcast"

#ifdef  DEBUG
#define APP_KEY @"5dlyvenDwAjORAFRmlcXaU"
#define APP_SECRET @"lBla5o4fpmh-suOCoWaUlA"
#else
#define APP_KEY @"Zs2AsXBBAv3Rfo0dxpx6fK"
#define APP_SECRET @"I5sW94fudtH9JEuFTfjEAz"
#endif


#define USER_AGENT_HEADER @"User-Agent"
#define ACCEPT_HEADER @"Accept"
#define ACCEPT_APPLICATION_JSON @"application/json"

@implementation CONApiClient

+ (NSString *)pathForResource:(NSString *)theResourcePath
{
    if ([theResourcePath characterAtIndex:0] == '/') {
        return [NSString stringWithFormat:@"%@%@", ROOT_PATH, theResourcePath];
    } else {
        return theResourcePath;
    }
}

+ (void)publishPushToken:(NSString *)pushToken withCompletionBlock:(requestCompletionBlock)completion
{
    [self sendRequestToPath:[NSString stringWithFormat:DEVICE_TOKEN_URI, pushToken]
                usingMethod:@"PUT"
             withBinaryData:nil
         andCompletionBlock:completion];
}

+ (void)unpublishPushToken:(NSString *)pushToken withCompletionBlock:(requestCompletionBlock)completion
{
    [self sendRequestToPath:[NSString stringWithFormat:DEVICE_TOKEN_URI, pushToken]
                usingMethod:@"DELETE"
             withBinaryData:nil
         andCompletionBlock:completion];
}

+ (void)acknowledgePushReceptionWithCorrelationId:(NSString *)guid
                                       withBearer:(NSString *)bearer
                                     andTimestamp:(NSTimeInterval)timestamp
                              withCompletionBlock:(requestCompletionBlock)completion
{
    [self sendRequestToPath:@"/acknowledge"
                usingMethod:@"POST"
             withBinaryData:[self httpBodyForRequestData:[NSArray arrayWithObject:@{@"correlation-id": guid,
                                                                                    @"bearer": bearer,
                                                                                    @"reception-time": [NSNumber numberWithFloat:timestamp]}]]
         andCompletionBlock:completion];
}

+ (void)sendRequestToPath:(NSString *)path
                    usingMethod:(NSString *)method
                 withBinaryData:(NSData *)data
                    andCompletionBlock:(requestCompletionBlock)completion
{
    NSString *requestPath = [self pathForResource:path];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:requestPath]];
    
    NSString *authHeader = [NSString stringWithFormat:@"%@:%@", APP_KEY, APP_SECRET];
    NSString *base64authheader = [Base64Utilities encodeBase64WithData:[authHeader dataUsingEncoding:NSUTF8StringEncoding]];    
    NSDictionary *headers = @{ ACCEPT_HEADER: ACCEPT_APPLICATION_JSON,
                                       @"Authorization": [NSString stringWithFormat:@"Basic %@", base64authheader]};

    
    for (NSString *headerKey in [headers allKeys]) {
        [request addValue:[headers valueForKey:headerKey] forHTTPHeaderField:headerKey];
    }
    
    [request setHTTPBody:data];
    [request setHTTPMethod:method];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSHTTPURLResponse *response = nil;
        NSError *error = nil;
        NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        
        CLSNSLog(@"Received: (%ld) %@ - error:%@", (long)response.statusCode, [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding], error);
        
        CONApiRequestError statusCode;
        if (response.statusCode % 200 == Ok) {
            statusCode = Ok;
        } else {
            statusCode = ErrorGeneric;
        }
        
        if (completion) {
            completion(statusCode, responseData);
        }
    });
}

+ (NSData *)httpBodyForRequestData:(NSArray *)requestData
{
    if (requestData == nil || ([requestData count] == 0)) {
        return nil;
    }
    NSError *error = nil;
    NSData *retValue = nil;
    if ([requestData count] == 1) {
        retValue = [NSJSONSerialization dataWithJSONObject:[requestData objectAtIndex:0] options:0 error:&error];
    } else {
        retValue = [NSJSONSerialization dataWithJSONObject:requestData options:0 error:&error];
    }
    if (error == nil) {
        return retValue;
    }
    return nil;
}

@end
