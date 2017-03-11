//
//  IAPEProductListTableViewController.m
//  VTA Purchases
//
//  Created by Simon Fairbairn on 05/07/2014.
//  Copyright (c) 2014 Voyage Travel Apps. All rights reserved.
//

#import "IAPEProductListTableViewController.h"
#import "VTAInAppPurchases.h"
#import "VTAProduct.h"
#import "VTAInAppPurchasesTableViewCell.h"

@implementation IAPEProductListTableViewController

-(void)viewDidAppear:(BOOL)animated {
    
    [super viewDidAppear:animated];

    // Set the type of purchases we're interested in (default is all)
    self.productType = VTAInAppPurchasesTableViewControllerProductTypeAll;

	
    if ( [VTAInAppPurchases sharedInstance].productsLoadingStatus == VTAInAppPurchasesStatusProductsListLoaded
        || [VTAInAppPurchases sharedInstance].productsLoadingStatus == VTAInAppPurchasesStatusProductsLoaded ) {
        
        // If we've loaded either the list or all of the products, we have enough information to provide the content
        [self unlockLocalContent];
    } else {
        
        // Otherwise, we'll add a notification to let us know when the product list has been updated
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(unlockLocalContent) name:VTAInAppPurchasesProductListDidUpdateNotification object:nil];
    }
    
}

-(void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Actions

// Handling restoration
-(IBAction)restorePurchases:(id)sender {

    // Delete the product list. This will be reloaded on completion.
//    self.products = nil;
    [self.tableView reloadData];
    [self.refreshControl beginRefreshing];
    [[VTAInAppPurchases sharedInstance] restoreProducts];
}

#pragma mark - Notifications

/**
 *  The puchase completion notification contains a userInfo dictionary with two keys, one of them is an
 *  array of products (currently that array will only be populated with one product) that were the subject
 *  of the transaction.
 *
 *  If there was an error, an error object will be passed along detailing the problem encountered.
 */
-(void)handlePurchaseCompletion:(NSNotification *)note {
    
    VTAProduct *product = [[note.userInfo objectForKey:VTAInAppPurchasesProductsAffectedUserInfoKey] firstObject];
    NSError *error = [note.userInfo objectForKey:VTAInAppPurchasesNotificationErrorUserInfoKey];
    
    if ( error ) {
        
        // Handle the error.
        
    } else if ( product ) {
        
        /**
         *  Reload the relevant row to show the updated details
         */
        NSInteger row = [self.products indexOfObject:product];
        if ( row < [self.tableView numberOfRowsInSection:0] ) {
            [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:row inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
        
        [self unlockLocalContentForProduct:product];
        
    }
}

/**
 *  This method will be called once a restoration has completed. 
 *
 *  In this example, when we initiate a restore we delete all of the products from the tableView, this
 *  simply calls the `displayProducts:` method to reload the data, which will indicate the purchase
 *  status of each product.
 *
 *  @param note An NSNotification object with details of the notification.
 */
-(void)handleRestoreCompletion:(NSNotification *)note {
    [self displayProducts:note];
}

/**
 *  This method will be called when the download status on a product changes.
 *
 *  @param note An NSNotification object with a userInfo dictionary passing along the relevant product.
 */
-(void)productDownloadChanged:(NSNotification *)note {
    
    // Grab the product from the dictionary
    VTAProduct *product = [[note.userInfo objectForKey:VTAInAppPurchasesProductsAffectedUserInfoKey] firstObject];
    
    // Check if we have one (if we don't, something went wrong)
    if ( product ) {
        
        // Get the relevant IndexPath of the product so we can grab the cell
        NSUInteger row = [self.products indexOfObject:product];
        NSIndexPath *ip = [NSIndexPath indexPathForRow:row inSection:0];
        
        VTAInAppPurchasesTableViewCell *cell = (VTAInAppPurchasesTableViewCell *)[self.tableView cellForRowAtIndexPath:ip];

        if ( product.purchaseInProgress && product.hosted ) {
            
            // If it's an in-progress purchase with hosted content, show the progress bar and update the progress
            cell.progressView.hidden = NO;
            cell.progressView.progress = product.progress;
            
        } else if ( !product.purchaseInProgress ) {
            
            // Otherwise, if the purchase has completed or failed, we can hide the progress bar
            cell.progressView.hidden = YES;
        }
    }
}


#pragma mark - Handling the content

/**
 *  EXAMPLE IMPLEMENTATION: This method goes through all of the valid products and, if it's a non-consumable
 *  product with a local URL, then we need to make that content accessible to the user.
 */
-(void)unlockLocalContent {
    for (VTAProduct *product in [VTAInAppPurchases sharedInstance].productList ) {
        if ( !product.consumable && product.localContentURL ) {
            [self unlockLocalContentForProduct:product];
        }
    }
}

/**
 *  Here's where we'd actually make the products available to the user by, for example, giving them
 *  access to assets contained within either an unlocked local directory or the downloaded directory
 *  (which is stored by default in the Documents folder, where the localContentPath object on the VTAProduct 
 *  will be a subfolder of the Documents folder).
 *
 *  @param product a VTAProduct object describing the product
 */
-(void)unlockLocalContentForProduct:(VTAProduct *)product {
    
}

#pragma mark - Table view data source

// Required tableView methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.products count];
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    VTAInAppPurchasesTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"IAPCell"  forIndexPath:indexPath];
    
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

@end

