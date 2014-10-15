//
//  VTAIAPHelper.h
//  IAP Example Suite
//
//  Created by Simon Fairbairn on 18/05/2014.
//  Copyright (c) 2014 Voyage Travel Apps. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, VTAInAppPurchasesStatus) {
    VTAInAppPurchasesStatusProductsLoadFailed     = -2,
    VTAInAppPurchasesStatusProductsListLoadFailed = -1,
    VTAInAppPurchasesStatusProductsLoading       = 0,
    VTAInAppPurchasesStatusProductsListLoaded     = 1,
    VTAInAppPurchasesStatusProductsLoaded        = 2
};

/**
 *  This notification will be sent when the product list is updated.
 */
extern NSString * const VTAInAppPurchasesProductListDidUpdateNotification;

/**
 *  This notification will be sent when either all of the products have been fetched
 *  from the store, or if there was a failure of some kind.
 *
 *  If there was a failure, the userInfo dictionary of the notification will have the 
 *  VTAInAppPurchasesNotificationErrorUserInfoKey set.
 */
extern NSString * const VTAInAppPurchasesProductsDidFinishUpdatingNotification;

/**
 *  This notification will be sent whenever a transaction has finished.
 *
 *  If there was an error, the userInfo dictionary will have the VTAInAppPurchaseesNotificationErrorUserInfoKey set.
 *  Also in that dictionary will be an array featuring the product involved in the transaction
 */
extern NSString * const VTAInAppPurchasesPurchasesDidCompleteNotification;

/**
 *  This notification will be sent whenever a restore has finished. If there's an error, the
 *  VTAInAppPurchaseesNotificationErrorUserInfoKey will be set
 */
extern NSString * const VTAInAppPurchasesRestoreDidCompleteNotification;

/**
 *  This notification will be sent when a product download status changed. The affected product
 *  will be in an array in the UserInfo dictionary under the key VTAInAppPurchasesProductsAffectedUserInfoKey.
 */
extern NSString * const VTAInAppPurchasesProductDownloadStatusDidChangeNotification;

/**
 *  This notification will be sent if the receipt was successfully validated.
 */
extern NSString * const VTAInAppPurchasesReceiptDidValidateNotification;

/**
 *  This notification will be sent if the receipt validation failed, and may be sent multiple times if validation
 *  is attempted repeatedly. 
 */
extern NSString * const VTAInAppPurchasesReceiptValidationDidFailNotification;

/**
 *  The keys for the UserInfo dictionary contained in some of the above notifications.
 */
extern NSString * const VTAInAppPurchasesProductsAffectedUserInfoKey;
extern NSString * const VTAInAppPurchasesNotificationErrorUserInfoKey;


@class VTAProduct;

@interface VTAInAppPurchases : NSObject

/**
 *  The URL of a remote product plist file.
 */
@property (nonatomic, copy) NSURL *remoteURL;

/**
 *  The URL of a local product plist file. If both this and the above properties are set,
 *  the remoteURL will take precident.
 */
@property (nonatomic, copy) NSURL *localURL;

/**
 *  Indicates the status of the product list loading. 
 *
 *  1. Neither the list nor the products have been loaded (`VTAInAppPurchaseStatusProductsLoading` if
 *      they're in the process of loading or `VTAInAppPurchaseStatusProductListLoadFailed` if they failed to load)
 *  2. The product list has been loaded and the `VTAProduct` objects have 
 *      been initialised. (`VTAInAppPurchaseStatusProductListLoaded`)
 *  3. The products have been loaded in from the App Store, and 
 *      the `VTAProduct` objects have been updated (`VTAInAppPurchaseStatusProductsLoaded`)
 */
@property (nonatomic, readonly) VTAInAppPurchasesStatus productsLoadingStatus;

/**
 *  A read only list of the currently loaded products. All objects will be of class VTAProduct
 */
@property (nonatomic, readonly) NSArray *productList;

/**
 *  The original purchased version of the app
 */
@property (nonatomic, readonly) NSString *originalVersionNumber;

// METHODS

/**
 *  @return The singleton instance of this class
 */
+(instancetype)sharedInstance;

/**
 *  Validates the receipt. This method will request a new receipt if validation
 *  fails or a receipt is not found.
 */
-(void)validateReceiptWithCompletionHandler:(void (^)(BOOL receiptIsValid))completion;

/**
 *  Load the products from one of the provided URLs, then start up the SKPaymentQueue
 *
 *  @return BOOL Returns YES if a valid local URL or any remote URL was provided
 */
-(void)loadProducts;

/**
 *  Initialises the purches of a product
 *
 *  @param product The VTAProduct to purchase
 */
-(void)purchaseProduct:(VTAProduct *)product;

/**
 *  Restores all non-consumable purchases
 */
-(void)restoreProducts;

/**
 *  Use this to bypass the store and immediately unlock a non-consumable product. 
 *
 *  WARNING: USING THIS METHOD WILL NOT GENERATE A PAYMENT AND WILL GIVE USERS IMMEDIATE ACCESS.
 *
 *  @param product The product to unlock
 */
-(void)unlockNonConsumableProduct:(VTAProduct *)product;

/**
 *  Returns the product for the given identifier, or nil if not found
 *
 *  @param identifier The identifier of the product
 *
 *  @return A VTAProduct object of the requested product, or nil
 */
-(VTAProduct *)vtaProductForIdentifier:(NSString *)identifier;

@end

