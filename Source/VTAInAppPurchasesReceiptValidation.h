//
//  VTAInAppPurchasesReceiptValidation.h
//  IAP Example Suite
//
//  Created by Simon Fairbairn on 03/10/2014.
//  Copyright (c) 2014 Voyage Travel Apps. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface VTAInAppPurchasesReceiptValidation : NSObject

@property (nonatomic, strong) NSString *appIdentifier;
@property (nonatomic, strong) NSMutableArray *arrayOfPurchasedIAPs;

/**
 *  The version number of the app when it was first purchased
 */
@property (nonatomic, strong) NSString *originalPurchasedVersion;


-(BOOL)validateReceipt;



@end
