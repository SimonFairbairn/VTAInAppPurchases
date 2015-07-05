//
//  VTAInAppPurchasesReceiptValidation.h
//  IAP Example Suite
//
//  Created by Simon Fairbairn on 03/10/2014.
//  Copyright (c) 2014 Voyage Travel Apps. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface VTAInAppPurchasesReceiptValidation : NSObject

@property (nonatomic, readonly) NSString *appIdentifier;
@property (nonatomic, readonly) NSMutableArray *arrayOfPurchasedIAPs;

/**
 *  Indicates whether the last validation of the receipt was successful or not
 */
@property (nonatomic, getter=isValid) BOOL valid;

/**
 *  The version number of the app when it was first purchased.
 */
@property (nonatomic, readonly) NSString *originalPurchasedVersion;

/**
 *  Validate the local receipt. 
 *
 *  @return A BOOL indicating whether or not validation was successful
 */
-(BOOL)validateReceipt;

@end
