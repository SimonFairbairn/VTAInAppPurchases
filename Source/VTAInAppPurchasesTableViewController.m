//
//  IAPESTableViewController.m
//  IAP Example Suite
//
//  Created by Simon Fairbairn on 18/05/2014.
//  Copyright (c) 2014 Voyage Travel Apps. All rights reserved.
//

#import <StoreKit/StoreKit.h>

#import "VTAInAppPurchasesTableViewController.h"
#import "VTAInAppPurchases.h"
#import "VTAInAppPurchasesDetailVC.h"
#import "VTAInAppPurchasesTableViewCell.h"
#import "VTAInAppPurchasesDetailVC.h"
#import "VTAProduct.h"

@interface VTAInAppPurchasesTableViewController ()


@end

@implementation VTAInAppPurchasesTableViewController

#pragma mark - Properties

-(NSNumberFormatter *) formatter {
    if ( !_formatter ) {
        _formatter = [[NSNumberFormatter alloc] init];
        _formatter.formatterBehavior = NSNumberFormatterBehavior10_4;
        [_formatter setNumberStyle:NSNumberFormatterCurrencyStyle];
    }
    return _formatter;
}

#pragma mark - View Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.tableView registerNib:[UINib nibWithNibName:@"IAPESTableViewCell" bundle:nil] forCellReuseIdentifier:IAPESTableViewCellIdentifier];
    self.tableView.rowHeight = 93.0f;
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(reload:) forControlEvents:UIControlEventValueChanged];

}

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(displayProducts:) name:VTAInAppPurchasesProductsDidFinishUpdatingNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handlePurchaseCompletion:) name:VTAInAppPurchasesPurchasesDidCompleteNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleRestoreCompletion:) name:VTAInAppPurchasesRestoreDidCompleteNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateProduct:) name:VTAProductStatusDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(productDownloadChanged:) name:VTAInAppPurchasesProductDownloadStatusDidChangeNotification object:nil];
    
    [self.tableView reloadData];    
}

-(void)viewDidAppear:(BOOL)animated {
    
    [super viewDidAppear:animated];

    // Only refresh automatically if we haven't already loaded the products
    if ( !self.products ) {
        
        [self.refreshControl beginRefreshing];
        [self.tableView setContentOffset:CGPointMake(0, self.tableView.contentOffset.y-self.refreshControl.frame.size.height) animated:YES];
        
        // Passing nil lets the method know that this was not a user-generated refresh
        [self reload:nil];
    }
}

-(void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.refreshControl endRefreshing];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void)reload:(id)sender {
    
    // If we're not already loading
    if ( [VTAInAppPurchases sharedInstance].productsLoading != VTAInAppPurchaseStatusProductsLoading &&
        [VTAInAppPurchases sharedInstance].productsLoading != VTAInAppPurchaseStatusProductListLoaded
        ) {
        
        // Make a note of all of the existing products in the list
        NSMutableArray *ips = [NSMutableArray new];
        for ( int i = 0; i < (int)[self.products count]; i++ ) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:i inSection:0];
            [ips addObject:indexPath];
        }
        
        // Set the model object to nil
        self.products = nil;

        // If there's a sender, then it means it's been activated by the user, so animate nicely
        if ( sender ) {
            [self.tableView deleteRowsAtIndexPaths:ips withRowAnimation:UITableViewRowAnimationAutomatic];
        } else {
            // Otherwise, straight reload
            [self.tableView reloadData];
        }

        // Call the IAP singleton to reload the products
        [[VTAInAppPurchases sharedInstance] loadProducts];
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return [self.products count]; 
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    VTAInAppPurchasesTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:IAPESTableViewCellIdentifier  forIndexPath:indexPath];
    
    VTAProduct *product = [self.products objectAtIndex:indexPath.row];
    
    [self.formatter setLocale:product.product.priceLocale];
    
    cell.progressView.hidden = YES;
    
    cell.nonConsumable = product.consumable;
    cell.titleLabel.text = product.product.localizedTitle;
    cell.priceLabel.text = [self.formatter stringFromNumber:product.product.price];
    [cell addThumbnailImage:product.productIcon animated:NO];
        
    if ( !product.consumable && product.purchased ) {
        cell.statusLabel.hidden = NO;
        cell.statusLabel.text = @"Purchased";
    } else {
        cell.statusLabel.hidden = YES;
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    //    [self performSegueWithIdentifier:@"pushDetail" sender:self];
}

#pragma mark - Notifications

-(void)handlePurchaseCompletion:(NSNotification *)note {
    
}

-(void)handleRestoreCompletion:(NSNotification *)note {
    
}

/**
 *  This method is called once the loading of the product list AND the loading of the products from
 *  the store has completed. The UserInfo dictionary will be populated if an error occurred along the way.
 *
 *  @param note an NSNotication object.
 */
-(void)displayProducts:(NSNotification *)note {
    
    if ( [note.userInfo objectForKey:VTAInAppPurchasesNotificationErrorUserInfoKey] ) {
        
        NSError *error = [note.userInfo objectForKey:VTAInAppPurchasesNotificationErrorUserInfoKey];
        
#ifdef DEBUG
        NSLog(@"%@", error.localizedDescription);
#endif
        
    } else {
        
        NSMutableArray *array = [NSMutableArray new];
        
        for ( VTAProduct *product in [VTAInAppPurchases sharedInstance].productList ) {
            
            switch (self.productType) {
                case VTAInAppPurchasesTableViewControllerProductTypeAll: {
                    [array addObject:product];
                    break;
                    
                }
                case VTAInAppPurchasesTableViewControllerProductTypeConsumables: {
                    if ( product.consumable ) {
                        [array addObject:product];
                    }

                    break;
                    
                }
                case VTAInAppPurchasesTableViewControllerProductTypeNonConsumables: {
                    if ( !product.consumable ) {
                        [array addObject:product];
                    }
                    
                    break;
                    
                }
                    
                default:
                    break;
            }
        }
        
        self.products = array;
    }
    
    [self.tableView reloadData];
    [self.refreshControl endRefreshing];
}

-(void)updateProduct:(NSNotification *)note {
    
}

-(void)productDownloadChanged:(NSNotification *)note {
    
    VTAProduct *product = [[note.userInfo objectForKey:VTAInAppPurchasesProductsAffectedUserInfoKey] firstObject];
    if ( product ) {
        NSUInteger row = [self.products indexOfObject:product];
        NSIndexPath *ip = [NSIndexPath indexPathForRow:row inSection:0];
        
        VTAInAppPurchasesTableViewCell *cell = (VTAInAppPurchasesTableViewCell *)[self.tableView cellForRowAtIndexPath:ip];
        
        if ( product.purchaseInProgress && product.hosted ) {
            cell.progressView.hidden = NO;
            cell.progressView.progress = product.progress;
        } else if ( !product.purchaseInProgress ) {
            cell.progressView.hidden = YES;
        }
    }
}

#pragma mark - Segue

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    NSIndexPath *ip = [self.tableView indexPathForSelectedRow];
    VTAProduct *product = self.products[ip.row];
    
    VTAInAppPurchasesDetailViewController *detailVC = (VTAInAppPurchasesDetailViewController *)[segue destinationViewController];
    detailVC.product = product;
}

@end
