//
//  VTAProduct.h
//  IAP Example Suite
//
//  Created by Simon Fairbairn on 19/06/2014.
//  Copyright (c) 2014 Voyage Travel Apps. All rights reserved.
//

#import <Foundation/Foundation.h>

@import StoreKit;

extern NSString * const VTAProductStatusDidChangeNotification;

@interface VTAProduct : NSObject

@property (nonatomic, readonly) NSString *productIdentifier;
@property (nonatomic, readonly, getter = isConsumable) BOOL consumable;
@property (nonatomic, readonly) NSString *storageKey;
@property (nonatomic, readonly) NSNumber *productValue;
@property (nonatomic, readonly) UIImage *productIcon;
@property (nonatomic, readonly) UIImage *productFeaturedImage;
@property (nonatomic, readonly) NSURL *localContentURL;


@property (nonatomic, strong) SKProduct *product;
@property (nonatomic) BOOL purchaseInProgress;
@property (nonatomic) BOOL purchased; // Only relevant for non-consumables
@property (nonatomic) BOOL hosted; // If the content is hosted elsewhere
@property (nonatomic) float progress;

-(instancetype)initWithProductDetailDictionary:(NSDictionary *)dict;

@end
