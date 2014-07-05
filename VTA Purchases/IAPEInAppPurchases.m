//
//  IAPEInAppPurchases.m
//  VTA Purchases
//
//  Created by Simon Fairbairn on 05/07/2014.
//  Copyright (c) 2014 Voyage Travel Apps. All rights reserved.
//

#import "IAPEInAppPurchases.h"

@implementation IAPEInAppPurchases

+(instancetype)sharedInstance {
    static IAPEInAppPurchases *sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

-(id)init {
    if ( self = [super init] ) {
        self.localURL = [[NSBundle mainBundle] URLForResource:@"productListExample" withExtension:@"plist"];
        // OR: self.remoteURL = [NSURL URLWithString:@"http://yourwebsite.com/ExampleProductList.plist"];
    }
    
    return self;
}

@end
