//
//  VTAProduct.h
//  IAP Example Suite
//
//  Created by Simon Fairbairn on 19/06/2014.
//  Copyright (c) 2014 Voyage Travel Apps. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

/**
 *  Sent whenever the status of the product changed. Currently it's used to notify
 *  interested objects when either the productIcon or productFeaturedImage has
 *  finished downloading (if hosted on remote servers).
 */
extern NSString * const VTAProductStatusDidChangeNotification;

@interface VTAProduct : NSObject

/**
 *  The keys from the plist file. 
 */
@property (nonatomic, readonly) NSString *productIdentifier;
@property (nonatomic, readonly, getter = isConsumable) BOOL consumable;
@property (nonatomic, readonly) NSString *storageKey;
@property (nonatomic, readonly) NSNumber *productValue;
@property (nonatomic, readonly) UIImage *productIcon;
@property (nonatomic, readonly) UIImage *productFeaturedImage;

/**
 *  The full URL to the local content.
 */
@property (nonatomic, readonly) NSURL *localContentURL;

/**
 *  A reference to the SK product
 */
@property (nonatomic, strong) SKProduct *product;

/**
 *  Is a purchase of this product in progress?
 */
@property (nonatomic) BOOL purchaseInProgress;

/**
 *  Has the product been purchased? Only relevant for non-consumable products.
 */
@property (nonatomic) BOOL purchased;

/**
 *  Set to YES if the content is hosted with Apple
 */
@property (nonatomic) BOOL hosted;

/**
 *  The download progress, a float between 0 and 1.
 */
@property (nonatomic) float progress;


/**
 *  WARNING: You should not initialise this class directly.
 */
-(instancetype)initWithProductDetailDictionary:(NSDictionary *)dict;

@end
