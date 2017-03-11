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
@property (nonatomic, strong) NSMutableArray *internalProductsToIgnore;


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

-(NSMutableArray *)internalProductsToIgnore {
    if ( !_internalProductsToIgnore ) {
        _internalProductsToIgnore = [NSMutableArray new];
    }
    return _internalProductsToIgnore;
}

-(void)setShowRestoreButtonInNavBar:(BOOL)showRestoreButtonInNavBar {
    _showRestoreButtonInNavBar = showRestoreButtonInNavBar;
    
    if ( _showRestoreButtonInNavBar ) {
            self.navigationItem.rightBarButtonItem = self.restoreButton;
    } else {
        self.navigationItem.rightBarButtonItem = nil;
    }
    
}

-(UIBarButtonItem *)restoreButton {
    if ( !_restoreButton ) {
        _restoreButton = [[UIBarButtonItem alloc] initWithTitle:@"Restore Purchases" style:UIBarButtonItemStylePlain target:self action:@selector(restorePurchases:)];
    }
    return _restoreButton;
}


#pragma mark - View Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.tableView registerNib:[UINib nibWithNibName:@"VTAInAppPurchasesTableViewCell" bundle:nil] forCellReuseIdentifier:VTAInAppPurchasesTableViewCellIdentifier];
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 93.0f;
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(reload:) forControlEvents:UIControlEventValueChanged];
    
    if ( self.delegate && self.delegate && [self.delegate respondsToSelector:@selector(configureVTAInAppPurchasesTableViewController:)]  ) {
        [self.delegate configureVTAInAppPurchasesTableViewController:self];
    }
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

-(void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void)viewDidAppear:(BOOL)animated {
    
    [super viewDidAppear:animated];
    
    // Only refresh automatically if we haven't already loaded the products
    if ( !self.products  ) {
        
        if ( [VTAInAppPurchases sharedInstance].productsLoadingStatus != VTAInAppPurchasesStatusProductsLoaded ) {
            
            [self.refreshControl beginRefreshing];
            [self.tableView setContentOffset:CGPointMake(0, self.tableView.contentOffset.y-self.refreshControl.frame.size.height) animated:YES];
            
            // Passing nil lets the method know that this was not a user-generated refresh
            [self reload:nil];
        } else {
            [self displayProducts:nil];
        }
    }
}

-(void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self.refreshControl endRefreshing];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Methods

-(NSIndexPath *)indexPathForProduct:(VTAProduct *)product {
    if ( ![self.products containsObject:product] ) {
        return nil;
    }
    
    NSInteger row = [self.products indexOfObject:product];
    if ( self.defaultPurchasedRow ) {
        row++;
    }
    return [NSIndexPath indexPathForRow:row inSection:0];
}

-(VTAProduct *)productForIndexPath:(NSIndexPath *)ip {
    if ( self.defaultPurchasedRow ) {
        if ( ip.row > 0 ) {
            return self.products[ip.row - 1];
        } else {
            return nil;
        }
    } else {
        return self.products[ip.row];
    }
    return nil;
}

#pragma mark - Actions

-(IBAction)reload:(id)sender; {
    
    // If we're not already loading
    if ( [VTAInAppPurchases sharedInstance].productsLoadingStatus != VTAInAppPurchasesStatusProductsLoading &&
        [VTAInAppPurchases sharedInstance].productsLoadingStatus != VTAInAppPurchasesStatusProductsListLoaded
        ) {
        
        // Make a note of all of the existing products in the list
        NSMutableArray *ips = [NSMutableArray new];
        for ( int i = 0; i < (int)[self.products count]; i++ ) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:i inSection:0];
            [ips addObject:indexPath];
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
        
        if ( forceReload || [VTAInAppPurchases sharedInstance].productsLoadingStatus != VTAInAppPurchasesStatusProductsLoaded ) {
            // Call the IAP singleton to reload the products
            [[VTAInAppPurchases sharedInstance] validateReceiptWithCompletionHandler:^(BOOL receiptIsValid) {
                [[VTAInAppPurchases sharedInstance] loadProducts];
            }];
            
        } else {
            [self displayProducts:nil];
        }
        
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    NSInteger addition = 0;
    if ( self.defaultPurchasedRow ) {
        addition = 1;
    }
    return [self.products count] + addition;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    VTAInAppPurchasesTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:VTAInAppPurchasesTableViewCellIdentifier  forIndexPath:indexPath];
    cell.priceLabel.hidden = NO;
    cell.statusLabel.hidden = NO;
    
    VTAProduct *product;
    
    if ( self.defaultPurchasedRow ) {
        if ( indexPath.row == 0 ) {
            cell.titleLabel.text = self.defaultPurchasedRow;

            cell.hideProgressBar = YES;
            cell.priceLabel.hidden = YES;
            cell.statusLabel.hidden = YES;
            return cell;
        } else {
            product = [self.products objectAtIndex:(indexPath.row - 1)];
        }
    } else {
        product = [self.products objectAtIndex:indexPath.row];
    }
    
    [self.formatter setLocale:product.product.priceLocale];
    
    cell.statusLabel.text = nil;
    cell.hideProgressBar = YES;
    if ( ( product.purchaseInProgress && product.hosted ) || ( product.parentProduct.purchaseInProgress && product.parentProduct.hosted ) ) {
        cell.hideProgressBar = NO;
        cell.progressView.progress = product.progress;
        cell.statusLabel.text = NSLocalizedString(@"Downloading", nil);
    }
    
    cell.nonConsumable = product.consumable;
    cell.titleLabel.text = (product.product.localizedTitle) ? product.product.localizedTitle : product.productTitle;
    cell.priceLabel.text = (!product.consumable && product.purchased) ? NSLocalizedString(@"Purchased", nil) : [self.formatter stringFromNumber:product.product.price];
    
    [cell addThumbnailImage:product.productIcon animated:NO];
    [cell setNeedsUpdateConstraints];
    [cell updateConstraintsIfNeeded];
    
    if ( self.delegate && [self.delegate respondsToSelector:@selector(configureTableViewCell:atIndexPath:forVTAInAppPurchasesTableViewController:)] ) {
        [self.delegate configureTableViewCell:cell atIndexPath:indexPath forVTAInAppPurchasesTableViewController:self];
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
        [self performSegueWithIdentifier:@"detailSegue" sender:self];
}

-(NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if ( section == 1 ) {
        return NSLocalizedString(@"Purchased", nil);
    }
    return nil;
}

#pragma mark - Notifications

-(void)handlePurchaseCompletion:(NSNotification *)note {
    if ( note.userInfo[VTAInAppPurchasesNotificationErrorUserInfoKey] ) {
//        [UIAlertView alloc] initWithTitle:@"Purchase failed" message:<#(NSString *)#> delegate:<#(id)#> cancelButtonTitle:<#(NSString *)#> otherButtonTitles:<#(NSString *), ...#>, nil
    } else {
        NSArray *products = note.userInfo[VTAInAppPurchasesProductsAffectedUserInfoKey];
        VTAProduct *product = products.firstObject;
        
        // If the purchase was unsuccessful for any reason, bail out here.
        if ( !product.purchased ) {
            return;
        }
        
        if ( self.delegate && [self.delegate respondsToSelector:@selector(vtaInAppPurchasesTableViewController:productWasPurchased:)]) {
            
                [self.delegate vtaInAppPurchasesTableViewController:self productWasPurchased:product];
        }
    }
}

-(void)handleRestoreCompletion:(NSNotification *)note {
    [self displayProducts:note];    
}

/**
 *  This method is called once the loading of the product list AND the loading of the products from
 *  the store has completed. The UserInfo dictionary will be populated if an error occurred along the way.
 *
 *  @param note an NSNotication object.
 */
-(void)displayProducts:(NSNotification *)note {
    
    if ( [note.userInfo objectForKey:VTAInAppPurchasesNotificationErrorUserInfoKey] ) {
        
#ifdef DEBUG
        NSError *error = [note.userInfo objectForKey:VTAInAppPurchasesNotificationErrorUserInfoKey];
        NSLog(@"Couldn't display products: %@", error.localizedDescription);
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
                        if ( product.childProducts && product.maximumChildPurchasesBeforeHiding ) {
                            NSLog(@"%@", product.maximumChildPurchasesBeforeHiding);
                            NSInteger numberToHide = 0;
                            for ( NSString *identifier in product.childProducts ) {

                                VTAProduct *product = [[VTAInAppPurchases sharedInstance] vtaProductForIdentifier:identifier];

                                
                                if ( product.purchased ) {
                                    numberToHide++;
                                }
                            }
                            if ( numberToHide < [product.maximumChildPurchasesBeforeHiding integerValue] ) {
                                [array addObject:product];
                            }
                            
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

-(void)updateProduct:(NSNotification *)note {
    
    NSArray *products = note.userInfo[VTAInAppPurchasesProductsAffectedUserInfoKey];
    
    NSMutableArray *productIps = [NSMutableArray array];
    NSMutableArray *purchasedProductIps = [NSMutableArray array];
    for ( VTAProduct *product in products ) {
        __block NSUInteger index = NSNotFound;
        [self.products enumerateObjectsUsingBlock:^(VTAProduct *aProduct, NSUInteger idx, BOOL *stop) {
            if ( [aProduct.productIdentifier isEqualToString:product.productIdentifier]) {
                index = idx;
                *stop = YES;
            }
        }];
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
        
        NSIndexPath *ip = [self indexPathForProduct:product];
        if ( [self.loadingProducts containsObject:product] ) {
            [self updateCellAtIndexPath:ip withProduct:product];
            for ( NSString *childProductId in product.childProducts ) {
                VTAProduct *childProduct = [[VTAInAppPurchases sharedInstance] vtaProductForIdentifier:childProductId];
                if ( [self.loadingProducts containsObject:childProduct] ) {
                    NSIndexPath *childIP = [self indexPathForProduct:childProduct];
                    if ( childIP ) {
                        [self updateCellAtIndexPath:childIP withProduct:childProduct];
                    }
                }
            }
        } else {
            NSMutableArray *ips = [NSMutableArray new];
            if ( ip ) {
                [ips addObject:ip];
            }
                [self.loadingProducts addObject:product];
            for ( NSString *childID in product.childProducts ) {
                VTAProduct *childProduct = [[VTAInAppPurchases sharedInstance] vtaProductForIdentifier:childID];

                NSIndexPath *ip = [self indexPathForProduct:childProduct];
                if ( ip ) {
                    [ips addObject:ip];
                    [self.loadingProducts addObject:childProduct];
                }
            }
            [self.tableView reloadRowsAtIndexPaths:ips withRowAnimation:UITableViewRowAnimationNone];
        }
    }
    
    NSError *error = [note.userInfo objectForKey:VTAInAppPurchasesNotificationErrorUserInfoKey];
    if ( error ) {
        
        NSString *text = NSLocalizedString(@"Couldn't download files. Please check your Internet connection, then try restoring again.", nil);
        if ( product ) {
            text = [NSString stringWithFormat:NSLocalizedString(@"Couldn't download files for %@. Please check your Internet connection, then try restoring again.", nil), product.product.localizedTitle];
        }		
		UIAlertController *controller = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Download Failed", nil) message:text preferredStyle:UIAlertControllerStyleAlert];
		
		UIAlertAction *action = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", nil) style:UIAlertActionStyleCancel handler:nil];
		[controller addAction:action];
		
		[self presentViewController:controller animated:YES completion:nil];
		
        [self.tableView reloadData];
    }
}

-(void)updateCellAtIndexPath:(NSIndexPath *)ip withProduct:(VTAProduct *)product {
    VTAInAppPurchasesTableViewCell *cell = (VTAInAppPurchasesTableViewCell *)[self.tableView cellForRowAtIndexPath:ip];
    
    
    if ( ( product.purchaseInProgress && product.hosted ) || ( product.parentProduct.purchaseInProgress && product.parentProduct.hosted ) ) {
        if ( product.purchaseInProgress && product.hosted ) {
            cell.progressView.progress = product.progress;
        } else {
            cell.progressView.progress = product.parentProduct.progress;
        }
        
    } else if ( !product.purchaseInProgress || !product.parentProduct.purchaseInProgress ) {
        if ( ip ) {
            [self.tableView reloadRowsAtIndexPaths:@[ip] withRowAnimation:UITableViewRowAnimationNone];            
        }

        [self.loadingProducts removeObject:product];
        if ( product.parentProduct ) {
            [self.loadingProducts removeObject:product.parentProduct];
        }
        if ( [self.loadingProducts count] < 1 ) {
            [self displayProducts:nil];
        }
    }
    
}

-(IBAction)restorePurchases:(id)sender {
    self.products = nil;
    [self.tableView reloadData];
    [self.refreshControl beginRefreshing];
    
    [[VTAInAppPurchases sharedInstance] validateReceiptWithCompletionHandler:^(BOOL receiptIsValid) {
        [[VTAInAppPurchases sharedInstance] restoreProducts];
    }];
}

#pragma mark - Segue

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    NSIndexPath *ip = [self.tableView indexPathForSelectedRow];
    VTAProduct *product = [self productForIndexPath:ip];
    
    VTAInAppPurchasesDetailViewController *detailVC;
    if ( [segue.destinationViewController isKindOfClass:[UINavigationController class]] ) {
        UINavigationController *navVC = (UINavigationController *)segue.destinationViewController;
        if ( [navVC.topViewController isKindOfClass:[VTAInAppPurchasesDetailViewController class]] ) {
            detailVC = (VTAInAppPurchasesDetailViewController *)navVC.topViewController;
        }
    }
    
    if ( [segue.destinationViewController isKindOfClass:[VTAInAppPurchasesDetailViewController class]] ) {
        detailVC = (VTAInAppPurchasesDetailViewController *)segue.destinationViewController;
    }
    
    if ( self.traitCollection.userInterfaceIdiom == UIUserInterfaceIdiomPad ) { 
        detailVC.navigationItem.leftBarButtonItem = self.splitViewController.displayModeButtonItem;
    }
    self.title = @"Products";
    
    detailVC.product = product;
    
    
    if ( self.delegate && [self.delegate respondsToSelector:@selector(vtaInAppPurchasesTableViewController:willSegueToVTAInAppPurchasesDetailViewController:)] ) {
        [self.delegate vtaInAppPurchasesTableViewController:self willSegueToVTAInAppPurchasesDetailViewController:detailVC];
    }
    
}

@end
