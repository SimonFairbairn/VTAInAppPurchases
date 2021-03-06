//
//  IAPESTableViewController.h
//  IAP Example Suite
//
//  Created by Simon Fairbairn on 18/05/2014.
//  Copyright (c) 2014 Voyage Travel Apps. All rights reserved.
//

#import <UIKit/UIKit.h>


@class VTAProduct, VTAInAppPurchasesTableViewController, VTAInAppPurchasesTableViewCell, VTAInAppPurchasesDetailViewController;

@protocol VTAInAppPurchasesTableViewControllerDelegate <NSObject>

@optional

-(void)configureVTAInAppPurchasesTableViewController:(VTAInAppPurchasesTableViewController *)vc;
-(void)configureTableViewCell:(VTAInAppPurchasesTableViewCell *)cell atIndexPath:(NSIndexPath *)ip forVTAInAppPurchasesTableViewController:(VTAInAppPurchasesTableViewController *)vc;
-(void)vtaInAppPurchasesTableViewController:(VTAInAppPurchasesTableViewController *)vc willSegueToVTAInAppPurchasesDetailViewController:(VTAInAppPurchasesDetailViewController *)detailVC;
-(void)vtaInAppPurchasesTableViewController:(VTAInAppPurchasesTableViewController *)vc productWasPurchased:(VTAProduct *)product;

@end


static NSString * const IAPESTableViewCellIdentifier = @"IAPESTableViewCellIdentifier";

typedef NS_ENUM(NSUInteger, VTAInAppPurchasesTableViewControllerProductType) {
    VTAInAppPurchasesTableViewControllerProductTypeAll,
    VTAInAppPurchasesTableViewControllerProductTypeConsumables,
    VTAInAppPurchasesTableViewControllerProductTypeNonConsumables
};

@interface VTAInAppPurchasesTableViewController : UITableViewController 


@property (nonatomic, strong) UIBarButtonItem *restoreButton;

/**
 *  The controller delegate, for customising the controller and cell views
 */
@property (nonatomic, weak) id<VTAInAppPurchasesTableViewControllerDelegate> delegate;

/**
 *  A configurable number formatter for displaying product prices. Defaults to standard currency, and 
 *  configures the locale to the locale of the priceLocale property of SKProduct
 */
@property (nonatomic, strong) NSNumberFormatter *formatter;

/**
 *  A read-only list of the currently available products
 */
@property (nonatomic, readonly) NSArray *products;


@property (nonatomic) BOOL showRestoreButtonInNavBar;

/**
 *  An array of product identifiers that should be ignored when constructing the product list
 */
@property (nonatomic, copy) NSArray *productsToIgnore;

/**
 *  Set this to have the first row of the purchased section be a non-IAP default value, for when
 *  you want to always have a row in the purchased section even when everything else is unpurchased.
 */
@property (nonatomic, copy) NSString *defaultPurchasedRow;

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

-(VTAProduct *)productForIndexPath:(NSIndexPath *)ip;

-(NSIndexPath *)indexPathForProduct:(VTAProduct *)product;

@end
