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

@property (nonatomic, strong) NSNumberFormatter *formatter;
@property (nonatomic, strong) NSArray *products;

@property (nonatomic) VTAInAppPurchasesTableViewControllerProductType productType;

-(void)reload:(id)sender;
-(void)displayProducts:(NSNotification *)note;

@end
