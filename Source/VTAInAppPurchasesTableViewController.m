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

@property (nonatomic, readwrite) NSArray *products;
@property (nonatomic, readwrite) NSArray *purchasedProducts;
@property (nonatomic, strong) NSMutableArray *loadingProducts;

@end

@implementation VTAInAppPurchasesTableViewController

#pragma mark - Properties

-(NSArray *) loadingProducts {
    if ( !_loadingProducts ) {
        _loadingProducts = [NSMutableArray array];
    }
    return _loadingProducts;
}

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
    [self.tableView registerNib:[UINib nibWithNibName:@"VTAInAppPurchasesTableViewCell" bundle:nil] forCellReuseIdentifier:VTAInAppPurchasesTableViewCellIdentifier];
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 93.0f;
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

#pragma mark - Actions

-(IBAction)reload:(id)sender; {
    
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
        if ( self.separatePurchased ) {
            for ( int i = 0; i < (int)[self.purchasedProducts count]; i++ ) {
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:i inSection:1];
                [ips addObject:indexPath];
            }
            
        }
        
        // Set the model object to nil
        self.products = nil;
        self.purchasedProducts = nil;

        BOOL forceReload = NO;
        // If there's a sender, then it means it's been activated by the user, so animate nicely
        if ( sender ) {
            forceReload = YES;
            [self.tableView deleteRowsAtIndexPaths:ips withRowAnimation:UITableViewRowAnimationAutomatic];
        } else {
            // Otherwise, straight reload
            [self.tableView reloadData];
        }

        if ( forceReload || [VTAInAppPurchases sharedInstance].productsLoading != VTAInAppPurchaseStatusProductsLoaded ) {
            // Call the IAP singleton to reload the products
            [[VTAInAppPurchases sharedInstance] loadProducts];
        } else {
            [self displayProducts:nil];
        }
        
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return (self.separatePurchased) ? 2 : 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    
    if ( section == 0 ) {
        return [self.products count];
    } else {
        NSInteger count = [self.purchasedProducts count];
        if ( self.defaultPurchasedRow ) {
            count++;
        }
        
        return count;
    }
    
    return [self.products count]; 
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    VTAInAppPurchasesTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:VTAInAppPurchasesTableViewCellIdentifier  forIndexPath:indexPath];
    
    VTAProduct *product;
    if ( indexPath.section == 1 ) {
        NSInteger index = indexPath.row;
        if ( self.defaultPurchasedRow ) {
            if ( indexPath.row == 0 ) {
                cell.titleLabel.text = self.defaultPurchasedRow;
                cell.hideProgressBar = YES;
                cell.priceLabel.hidden = YES;
                return cell;
            } else {
                index--;
            }
        }
        product = [self.purchasedProducts objectAtIndex:index];
    } else {
        product = [self.products objectAtIndex:indexPath.row];
    }

    [self.formatter setLocale:product.product.priceLocale];
    
    cell.statusLabel.text = nil;
    if ( product.purchaseInProgress && product.hosted ) {
        cell.hideProgressBar = NO;
        cell.progressView.progress = product.progress;
        cell.statusLabel.text = @"Downloading";
    } else if ( !product.purchaseInProgress ) {
        cell.hideProgressBar = YES;
    }
    
    cell.nonConsumable = product.consumable;
    cell.titleLabel.text = (product.product.localizedTitle) ? product.product.localizedTitle : product.productTitle;
    cell.priceLabel.text = (!product.consumable && product.purchased) ? @"Purchased" : [self.formatter stringFromNumber:product.product.price];

    [cell addThumbnailImage:product.productIcon animated:NO];
    [cell setNeedsUpdateConstraints];
    [cell updateConstraintsIfNeeded];
    
    return cell;
}

#pragma mark - UITableViewDelegate

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    //    [self performSegueWithIdentifier:@"pushDetail" sender:self];
}

-(NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if ( section == 1 ) {
        return @"Purchased";
    }
    return nil;
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
    
    [self listPurchasedProducts];    
    
    if ( [note.userInfo objectForKey:VTAInAppPurchasesNotificationErrorUserInfoKey] ) {
        
        NSError *error = [note.userInfo objectForKey:VTAInAppPurchasesNotificationErrorUserInfoKey];
        
#ifdef DEBUG
        NSLog(@"Couldn't display products: %@", error.localizedDescription);
#endif
        // List purchased non-consumables
        
        
    } else {
        
        NSMutableArray *array = [NSMutableArray new];

        for ( VTAProduct *product in [VTAInAppPurchases sharedInstance].productList ) {
 
            switch (self.productType) {
                case VTAInAppPurchasesTableViewControllerProductTypeAll: {
                    if ( self.separatePurchased && product.purchased ) {

                    } else {
                        [array addObject:product];
                    }
                    break;
                    
                }
                case VTAInAppPurchasesTableViewControllerProductTypeConsumables: {
                    if ( product.consumable ) {
                        if ( self.separatePurchased && product.purchased ) {

                        } else {
                            [array addObject:product];
                        }
                    }

                    break;
                    
                }
                case VTAInAppPurchasesTableViewControllerProductTypeNonConsumables: {
                    if ( !product.consumable ) {
                        if ( self.separatePurchased && product.purchased ) {

                        } else {
                            [array addObject:product];
                        }
                    }
                    
                    break;
                    
                }
                    
                default:
                    break;
            }
        }
        
        for ( NSString *productToIgnore in self.productsToIgnore ) {
            VTAProduct *vtaProductToIgnore = [[VTAInAppPurchases sharedInstance] vtaProductForIdentifier:productToIgnore];
            [array removeObject:vtaProductToIgnore];
        }
                
        self.products = array;
    }
    
    [self.tableView reloadData];
    [self.refreshControl endRefreshing];
}

-(void)listPurchasedProducts {
    NSMutableArray *purchasedProducts = [NSMutableArray new];
    
    for ( VTAProduct *product in [VTAInAppPurchases sharedInstance].productList ) {
        
        switch (self.productType) {
            case VTAInAppPurchasesTableViewControllerProductTypeAll: {
                if ( product.purchased ) {
                    [purchasedProducts addObject:product];
                }
                break;
                
            }
            case VTAInAppPurchasesTableViewControllerProductTypeConsumables: {
                if ( product.consumable ) {
                    if ( product.purchased ) {
                        [purchasedProducts addObject:product];
                    }
                }
                
                break;
                
            }
            case VTAInAppPurchasesTableViewControllerProductTypeNonConsumables: {
                if ( !product.consumable ) {
                    if ( product.purchased ) {
                        [purchasedProducts addObject:product];
                    }
                }
                
                break;
                
            }
            default:
                break;
        }
    }
    
    for ( NSString *productToIgnore in self.productsToIgnore ) {
        VTAProduct *vtaProductToIgnore = [[VTAInAppPurchases sharedInstance] vtaProductForIdentifier:productToIgnore];
        [purchasedProducts removeObject:vtaProductToIgnore];
    }
    self.purchasedProducts = purchasedProducts;
}

-(void)updateProduct:(NSNotification *)note {
    
    NSArray *products = note.userInfo[VTAInAppPurchasesProductsAffectedUserInfoKey];
    
    NSMutableArray *productIps = [NSMutableArray array];
    NSMutableArray *purchasedProductIps = [NSMutableArray array];
    for ( VTAProduct *product in products ) {
        NSUInteger index = [self.products indexOfObject:product];
        if ( index != NSNotFound ) {
            [productIps addObject:[NSIndexPath indexPathForRow:index inSection:0]];

        } else {
            index = [self.purchasedProducts indexOfObject:product];
            if ( index != NSNotFound ) {
                [purchasedProductIps addObject:[NSIndexPath indexPathForRow:index inSection:1]];
            }
        }
    }
    if ( [productIps count] > 0 ) {
        [self.tableView reloadRowsAtIndexPaths:productIps withRowAnimation:UITableViewRowAnimationAutomatic];
    }
    if ( [self.tableView numberOfSections] > 1 && [purchasedProductIps count] > 0) {
        [self.tableView reloadRowsAtIndexPaths:purchasedProductIps withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

-(void)productDownloadChanged:(NSNotification *)note {
    
    VTAProduct *product = [[note.userInfo objectForKey:VTAInAppPurchasesProductsAffectedUserInfoKey] firstObject];
    if ( product ) {
        NSUInteger row = [self.products indexOfObject:product];
        NSIndexPath *ip = [NSIndexPath indexPathForRow:row inSection:0];
        if ( [self.loadingProducts containsObject:product] ) {
            VTAInAppPurchasesTableViewCell *cell = (VTAInAppPurchasesTableViewCell *)[self.tableView cellForRowAtIndexPath:ip];
            
            if ( product.purchaseInProgress && product.hosted ) {
                cell.progressView.progress = product.progress;
            } else if ( !product.purchaseInProgress ) {
                [self.tableView reloadRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationFade];
                [self.loadingProducts removeObject:product];
            }
        } else {
            [self.tableView reloadRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationFade];
            [self.loadingProducts addObject:product];
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
