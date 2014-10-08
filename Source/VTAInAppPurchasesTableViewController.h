//
//  IAPESTableViewController.h
//  IAP Example Suite
//
//  Created by Simon Fairbairn on 18/05/2014.
//  Copyright (c) 2014 Voyage Travel Apps. All rights reserved.
//

#import <UIKit/UIKit.h>

static NSString * const IAPESTableViewCellIdentifier = @"IAPESTableViewCellIdentifier";

typedef NS_ENUM(NSUInteger, VTAInAppPurchasesTableViewControllerProductType) {
    VTAInAppPurchasesTableViewControllerProductTypeAll,
    VTAInAppPurchasesTableViewControllerProductTypeConsumables,
    VTAInAppPurchasesTableViewControllerProductTypeNonConsumables
};

@interface VTAInAppPurchasesTableViewController : UITableViewController 

/**
 *  A configurable number formatter for displaying product prices.
 */
@property (nonatomic, strong) NSNumberFormatter *formatter;

/**
 *  A read-only list of the currently available products
 */
@property (nonatomic, readonly) NSArray *products;

/**
 *  An array of product identifiers that should be ignored when constructing the product list
 */
@property (nonatomic, copy) NSArray *productsToIgnore;

/**
 *  The type of products should be shown by the table view controller (All, Consumables, Non-consumables)
 */
@property (nonatomic) VTAInAppPurchasesTableViewControllerProductType productType;

/**
 *  Force the controller to reload the products
 *
 *  @param sender The object requesting the reload (typically a UIRefreshControl)
 */
-(IBAction)reload:(id)sender;

/**
 *  This method is used to display the products after they have been loaded. It can be overridden for
 *  custom display logic.
 *
 *  @param note The NSNotification that initiated the reload, in this case the VTAInAppPurchasesProductsDidFinishUpdatingNotification.
 */
-(void)displayProducts:(NSNotification *)note;

@end
