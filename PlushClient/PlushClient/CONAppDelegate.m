//
//  CONAppDelegate.m
//  PlushClient
//
//  Created by Sergio Artero Martinez on 16/11/13.
//  Copyright (c) 2013 Sergio Artero Martinez. All rights reserved.
//

#import "CONAppDelegate.h"
#import "CONApiClient.h"
#import <Crashlytics/Crashlytics.h>
#import "NetworkClock.h"

#define PUSH_TOKEN_USERDEFAULTS_KEY @"PUSH_TOKEN"
#define CRASHLYTICS_API_KEY @"f519d380eede405be6309521dcb13f7e97f4ad35"

@implementation CONAppDelegate

@synthesize managedObjectContext = __managedObjectContext;
@synthesize managedObjectModel = __managedObjectModel;
@synthesize persistentStoreCoordinator = __persistentStoreCoordinator;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    
    [Crashlytics startWithAPIKey:CRASHLYTICS_API_KEY];
    
    
    [[UIApplication sharedApplication] registerForRemoteNotificationTypes:(UIRemoteNotificationTypeBadge |
                                                                           UIRemoteNotificationTypeSound |
                                                                           UIRemoteNotificationTypeAlert)];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reachabilityChanged:) name:kReachabilityChangedNotification object:nil];
    
    self.internetReachability = [Reachability reachabilityForInternetConnection];
    [self.internetReachability startNotifier];
    
    self.wifiReachability = [Reachability reachabilityForLocalWiFi];
    [self.wifiReachability startNotifier];
    
    self.curReachabilityStatus = [self.wifiReachability currentReachabilityStatus];
    
    [NetworkClock sharedInstance];
    
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

#pragma mark - Push notifications
- (void)application:(UIApplication*)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    
    //wellknown tokens:
    //sergioa: 5860688ec508e21ca2dc13d0390fe18e498b35019064326f196599eac75583c3
    CLSNSLog(@"Application did register for remote notifications with token %@", deviceToken);
    
    NSString *token = [[deviceToken description] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]];
    token = [token stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    NSString *storedToken = [defaults objectForKey:PUSH_TOKEN_USERDEFAULTS_KEY];
    if (![storedToken isEqualToString:token]) {
        CLSNSLog(@"Token changen, updating token...");
        [CONApiClient publishPushToken:token withCompletionBlock:^(CONApiRequestError success, NSData *responseData) {
            if (success == Ok) {
                CLSNSLog(@"Token published");
                [defaults setObject:token forKey:PUSH_TOKEN_USERDEFAULTS_KEY];
                [defaults synchronize];
            } else {
                CLSNSLog(@"Unable to publish token");
            }
        }];
    }
}

- (void)application:(UIApplication*)application didFailToRegisterForRemoteNotificationsWithError:(NSError*)error
{
    CLSNSLog(@"Application did fail to register for remote notifications.");
}


- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult result))handler
{
    // Remote notification payload: { "aps": {"content-available": 1}, "meta": {"correlation-id:": "guid"}}
    CLSNSLog(@"Received remote push trigger notification");
    
    NSDictionary *meta = userInfo[@"meta"];
    if (meta) {
        NSString *pushCorrelationId = meta[@"correlation_id"];
        NSTimeInterval network = [[[NetworkClock sharedInstance] networkTime] timeIntervalSince1970];
        NSTimeInterval remote = [meta[@"issued_at"] doubleValue];
        
        NSString *reachability = nil;
        switch(self.curReachabilityStatus) {
            case ReachableViaWiFi:
                reachability = @"wifi";
                break;
            case ReachableViaWWAN:
                reachability = @"3g";
                break;
            default:
                reachability = @"unknown";
                break;
        }
        
        CLSNSLog(@"Acknowledge push notification %@ issued at %fwith reception time %f and bearer %@", pushCorrelationId, remote, network, reachability);
        
        [self insertReportWithCorrelationId:pushCorrelationId
                                 receivedAt:network
                                   issuedAt:remote
                                     bearer:reachability
                               batteryState:[[UIDevice currentDevice] batteryState]];
        
        //        [self saveToFile];
        
        //        [CONApiClient acknowledgePushReceptionWithCorrelationId:pushCorrelationId
        //                                                     withBearer:reachability
        //                                                   andTimestamp:curtime
        //                                            withCompletionBlock:nil];
    }
    
    handler(UIBackgroundFetchResultNoData);
}

- (void)reachabilityChanged:(NSNotification *)notification
{
    Reachability* curReach = [notification object];
    NSParameterAssert([curReach isKindOfClass:[Reachability class]]);
    
    NetworkStatus wifiReachability = [self.wifiReachability currentReachabilityStatus];
    NetworkStatus internetReachability = [self.internetReachability currentReachabilityStatus];
    
    if (wifiReachability == ReachableViaWiFi) {
        self.curReachabilityStatus = ReachableViaWiFi;
    } else if (internetReachability == ReachableViaWWAN) {
        self.curReachabilityStatus = ReachableViaWWAN;
    } else {
        self.curReachabilityStatus = NotReachable;
    }
}

- (void)insertReportWithCorrelationId:(NSString *)correlationId
                           receivedAt:(NSTimeInterval)receivedAt
                             issuedAt:(NSTimeInterval)issuedAt
                               bearer:(NSString *)bearer
                         batteryState:(UIDeviceBatteryState)batteryState
{
    NSManagedObjectContext *context = [self managedObjectContext];
    NSManagedObject *report = [NSEntityDescription
                               insertNewObjectForEntityForName:@"Push"
                               inManagedObjectContext:context];
    [report setValue:correlationId forKey:@"correlation_id"];
    [report setValue:[NSNumber numberWithDouble:receivedAt] forKey:@"received_at"];
    [report setValue:[NSNumber numberWithDouble:issuedAt] forKey:@"issued_at"];
    [report setValue:bearer forKey:@"bearer"];
    [report setValue:[NSNumber numberWithInteger:batteryState] forKey:@"battery_state"];
    
    NSError *error;
    [context save:&error];
    
}

- (void)saveToFile
{
    NSManagedObjectContext *context = [self managedObjectContext];
    
    NSEntityDescription *entityDesc = [NSEntityDescription entityForName:@"Push" inManagedObjectContext:context];
    
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:entityDesc];
    
    NSError *error;
    NSArray *objects = [context executeFetchRequest:request error:&error];
    
    CLSNSLog(@"Number of objects %lu", (unsigned long)[objects count]);
    
    NSManagedObject *reportItem = nil;
    for (int i=0; i<[objects count]; i++) {
        reportItem = [objects objectAtIndex:i];
        CLSNSLog(@"Item: correlation_id %@\nreceived_at %f\n issued_at %f\nbearer %@\nbattery_state %ld", [reportItem valueForKey:@"correlation_id"],
                 [[reportItem valueForKey:@"received_at"] doubleValue],
                 [[reportItem valueForKey:@"issued_at"] doubleValue],
                 [reportItem valueForKey:@"bearer"],
                 (long)[[reportItem valueForKey:@"battery_state"] integerValue]);
    }
}

- (NSManagedObjectContext *)managedObjectContext
{
    if (__managedObjectContext != nil) {
        return __managedObjectContext;
    }
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        __managedObjectContext = [[NSManagedObjectContext alloc] init];
        [__managedObjectContext setPersistentStoreCoordinator: coordinator];
    }
    return __managedObjectContext;
}

- (NSManagedObjectModel *)managedObjectModel {
    if (__managedObjectModel != nil) {
        return __managedObjectModel;
    }
    __managedObjectModel = [NSManagedObjectModel mergedModelFromBundles:nil];
    
    return __managedObjectModel;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
    if (__persistentStoreCoordinator != nil) {
        return __persistentStoreCoordinator;
    }
    NSURL *storeUrl = [NSURL fileURLWithPath: [[self applicationDocumentsDirectory]
                                               stringByAppendingPathComponent: @"plush-client.sqlite"]];
    NSError *error = nil;
    __persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc]
                                    initWithManagedObjectModel:[self managedObjectModel]];
    if(![__persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                   configuration:nil URL:storeUrl options:nil error:&error]) {
        /*Error for store creation should be handled in here*/
    }
    
    return __persistentStoreCoordinator;
}

- (NSString *)applicationDocumentsDirectory {
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
}

@end
