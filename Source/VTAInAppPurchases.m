//
//  VTAIAPHelper.m
//  IAP Example Suite
//
//  Created by Simon Fairbairn on 18/05/2014.
//  Copyright (c) 2014 Voyage Travel Apps. All rights reserved.
//

#import <StoreKit/StoreKit.h>

#import "VTAInAppPurchases.h"
#import "VTAProduct.h"
#import "VTAInAppPurchasesReceiptValidation.h"

#ifdef DEBUG
#define VTAInAppPurchasesDebug 1
#define VTAInAppPurchasesPListError 0
#endif

NSString * const VTAInAppPurchasesProductListDidUpdateNotification = @"VTAInAppPurchasesProductListDidUpdateNotification";
NSString * const VTAInAppPurchasesProductsDidFinishUpdatingNotification = @"VTAInAppPurchasesProductsDidFinishUpdatingNotification";
NSString * const VTAInAppPurchasesPurchasesDidCompleteNotification = @"VTAInAppPurchasesPurchasesDidCompleteNotification";
NSString * const VTAInAppPurchasesRestoreDidCompleteNotification = @"VTAInAppPurchasesRestoreDidCompleteNotification";
NSString * const VTAInAppPurchasesProductDownloadStatusDidChangeNotification = @"VTAInAppPurchasesProductDownloadStatusDidChangeNotification";

NSString * const VTAInAppPurchasesNotificationErrorUserInfoKey = @"VTAInAppPurchasesNotificationErrorUserInfoKey";
NSString * const VTAInAppPurchasesProductsAffectedUserInfoKey = @"VTAInAppPurchasesProductsAffectedUserInfoKey";

NSString * const VTAInAppPurchasesList = @"purchases.plist";

static NSString * const VTAInAppPurchasesCacheRequestKey = @"VTAInAppPurchasesCacheRequestKey";

static NSString * const VTAInAppPurchasesListProductNameKey = @"VTAInAppPurchasesListProductNameKey";
static NSString * const VTAInAppPurchasesListProductLocationKey = @"VTAInAppPurchasesListProductLocationKey";

@interface VTAInAppPurchases () <SKProductsRequestDelegate, SKRequestDelegate, SKPaymentTransactionObserver, NSURLSessionDelegate, NSURLSessionTaskDelegate>

@property (nonatomic, strong) NSArray *productIDs;
@property (nonatomic, strong) NSMutableDictionary *productLookupDictionary;
@property (nonatomic, strong) SKReceiptRefreshRequest *refreshRequest;

@property (nonatomic, strong) VTAInAppPurchasesReceiptValidation *validator;

@end

@implementation VTAInAppPurchases {
    BOOL _receiptValidationFailed;
    BOOL _receiptRefreshFailed;
    BOOL _refreshingReceipt;
}

#pragma mark - Properties

-(NSMutableDictionary *) productLookupDictionary {
    if ( !_productLookupDictionary ) {
        _productLookupDictionary = [NSMutableDictionary new];
    }
    return _productLookupDictionary;
}

-(VTAInAppPurchasesReceiptValidation *) validator {
    if ( !_validator ) {
        _validator = [[VTAInAppPurchasesReceiptValidation alloc] init];
    }
    return _validator;
}

#pragma mark - Initialisation

+(instancetype)sharedInstance {
    static id sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

#pragma mark - Methods

-(void)validateReceipt {
    if ( ![self.validator validateReceipt] ) {
        [self failValidation];
    } else {
#if VTAInAppPurchasesDebug
        NSLog(@"Receipt is valid.");
#endif
        _receiptValidationFailed = NO;
    }
}

-(void)failValidation {
    
#if VTAInAppPurchasesDebug
    NSLog(@"%s ", __PRETTY_FUNCTION__);
#endif

    if ( !_receiptValidationFailed ) {
    
#if VTAInAppPurchasesDebug
        NSLog(@"Requesting new receipt.");
#endif
        
        self.refreshRequest = [[SKReceiptRefreshRequest alloc] init];
        self.refreshRequest.delegate = self;
        [self.refreshRequest start];
    }
    _receiptValidationFailed = YES;
    _refreshingReceipt = YES;
}

/**
 *  STEP 1: Load the products from the plist file. Mark the productsLoading status as loading
 */
-(void)loadProducts {
    
#if VTAInAppPurchasesDebug
    NSLog(@"%s ", __PRETTY_FUNCTION__);
#endif
    
    if ( !self.remoteURL && !self.localURL ) return;
    
    _productsLoading = VTAInAppPurchaseStatusProductsLoading;
    
    if ( self.remoteURL ) {
        
        NSNumber *secondsSinceLastUpdate = [[NSUserDefaults standardUserDefaults] objectForKey:VTAInAppPurchasesCacheRequestKey];

#if VTAInAppPurchasesDebug
        NSLog(@"%@", secondsSinceLastUpdate);
        secondsSinceLastUpdate = nil;
#endif
        
        NSDate *lastUpdate = [NSDate dateWithTimeIntervalSinceReferenceDate:([secondsSinceLastUpdate intValue] + 24 * 60 * 60)];
        NSDate *now = [NSDate date];
        NSURL *cachesURL = [[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] firstObject];
        cachesURL = [cachesURL URLByAppendingPathComponent:@"VTAInAppPurchasesCache.plist"];
        
        NSArray *cachedData = [NSArray arrayWithContentsOfURL:cachesURL];
        
        if ( !secondsSinceLastUpdate || [[now laterDate:lastUpdate] isEqualToDate:now]  ) {
            
#if VTAInAppPurchasesDebug
            NSLog(@"Cache not available or expired");
#endif
            
            NSURLSession *fetchSession = [NSURLSession sharedSession];
            NSURLSessionDataTask *fetchRemotePlistTask = [fetchSession dataTaskWithRequest:[NSURLRequest requestWithURL:self.remoteURL] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                NSError *readingError;
                
                NSArray *products = cachedData;
                
                if ( error ) {
                    
#if VTAInAppPurchasesDebug
                    NSLog(@"Error connection: %@", error.localizedDescription);
#endif
                    
                    [self productLoadingDidFinishWithError:error];
                    
                } else {
                    
                    id productIDs = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:nil error:&readingError];
                    
                    if ( !readingError && [productIDs isKindOfClass:[NSArray class]]) {

#if VTAInAppPurchasesDebug
                        NSLog(@"Products successfully loaded from network");
#endif
                        
                        products = (NSArray *)productIDs;
                        
                        if ( [products writeToURL:cachesURL atomically:YES] ) {
                            NSTimeInterval interval = [NSDate timeIntervalSinceReferenceDate];
                            [[NSUserDefaults standardUserDefaults] setObject:@(interval) forKey:VTAInAppPurchasesCacheRequestKey];
                        }
                        
                    } else {

#if VTAInAppPurchasesDebug
                        NSLog(@"Error reading: %@\n%@", readingError.localizedDescription, readingError.localizedFailureReason);
#endif
                        
                        [self productLoadingDidFinishWithError:readingError];
                    }
                }
                
                [self setupProductsWithPropertyList:products];
            }];
            [fetchRemotePlistTask resume];
        } else {
            
#if VTAInAppPurchasesDebug
            NSLog(@"Loading from cache");
#endif
            [self setupProductsWithPropertyList:cachedData];
            
        }
        
    } else if ( self.localURL ) {
        
        NSArray *plist = [NSArray arrayWithContentsOfURL:self.localURL];

#if VTAInAppPurchasesPListError
        plist = nil;
#endif
        
        [self setupProductsWithPropertyList:plist];
    }
}

/**
 *  STEP 2: Extract the products from the plist file and check whether or not non-consumable
 *  products have been purchased. Start the StoreKit request. Mark the productsLoading as listLoaded.
 */
-(void)setupProductsWithPropertyList:(NSArray *)propertyList {
    
#if VTAInAppPurchasesDebug
    NSLog(@"%s ", __PRETTY_FUNCTION__);
#endif
    
    if ( !propertyList ) {
        NSError *error = [NSError errorWithDomain:@"com.voyagetravelapps.VTAInAppPurchases" code:1 userInfo:@{NSLocalizedDescriptionKey : @"Property list was nil"}];
        [self productLoadingDidFinishWithError:error];
        _productsLoading = VTAInAppPurchaseStatusProductListLoadFailed;
    } else {
        
        NSMutableArray *array = [NSMutableArray array];
        NSMutableArray *productIDs = [NSMutableArray array];
        
        for ( id dictionary in propertyList ) {
            if ( [dictionary isKindOfClass:[NSDictionary class]] ) {
                VTAProduct *product = [[VTAProduct alloc] initWithProductDetailDictionary:dictionary];
                [array addObject:product];
                [productIDs addObject:product.productIdentifier];
                [self.productLookupDictionary setObject:product forKey:product.productIdentifier];
            }
        }
        
        _productList = [array copy];
        _productsLoading = VTAInAppPurchaseStatusProductListLoaded;

        [self validateProductsShouldUseDefaults:NO];
        
        SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:[NSSet setWithArray:productIDs]];
        request.delegate = self;
        [request start];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:VTAInAppPurchasesProductListDidUpdateNotification object:self];
}

/**
 *  STEP 3: Once the delegate has received a response, the products will have been updated with their
 *  SKProduct objects or there will have been some sort of failure.
 */
-(void)productLoadingDidFinishWithError:(NSError *)error {
    
#if VTAInAppPurchasesDebug
    NSLog(@"%s ", __PRETTY_FUNCTION__);
#endif
    
    if ( self.productList ) {
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    }
    
    NSDictionary *userInfo;
    
    if ( error ) {
        userInfo = @{VTAInAppPurchasesNotificationErrorUserInfoKey : error };
        _productsLoading = VTAInAppPurchaseStatusProductLoadFailed;
    } else {
        _productsLoading = VTAInAppPurchaseStatusProductsLoaded;
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:VTAInAppPurchasesProductsDidFinishUpdatingNotification object:nil userInfo:userInfo];
}

-(void)validateProductsShouldUseDefaults:(BOOL)useDefaults {
    
#if VTAInAppPurchasesDebug
    NSLog(@"%s ", __PRETTY_FUNCTION__);
    NSLog(@"Should use defaults: %i", useDefaults);
    NSLog(@"Receipt validation status %i", _receiptValidationFailed);
#endif
    
    // 1. Go through the list of purchased products and set the purchased property
    //      1a. If useDefaults is set, use the NSUserDefaults to set the purchased property
    //      1b. If validation failed is set to YES, use defaults.
    //      1c. If validation failed is set to NO, set all NSUserDefault products to NO, then set only the ones to YES that are in the list of purchased products
    // verified by receipt
    
    // Load the previous purchase information from a pList stored in NSUserDefaults, which is an array of product IDs used to identify
    // if a product has previously been purchased.
    // If it has, we'll set the purchased property on VTAProduct to YES.
    
    NSArray *arrayOfPurchases = [[NSUserDefaults standardUserDefaults] objectForKey:VTAInAppPurchasesList];
    if ( useDefaults || _receiptValidationFailed ) {
        
        // self validateProducts
        
        for ( VTAProduct *product in self.productList ) {
            for ( NSDictionary *productInfo in arrayOfPurchases ) {
                if ( [product.productIdentifier isEqualToString:productInfo[VTAInAppPurchasesListProductNameKey]] ) {
                    product.purchased = YES;
                }
            }
        }
        
        // end validations
    } else {
        
        [[NSUserDefaults standardUserDefaults] setObject:nil forKey:VTAInAppPurchasesList];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        for ( VTAProduct *product in self.productList ) {
            
            if ( product.storageKey ) {
                [[NSUserDefaults standardUserDefaults] setObject:nil forKey:product.storageKey];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }
            
            for ( NSString *identifier in self.validator.arrayOfPurchasedIAPs ) {
                if ( [product.productIdentifier isEqualToString:identifier] ) {
                    
                    product.purchased = YES;
                    [self addProductToUnlockList:product];
                }
            }
        }
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:VTAInAppPurchasesProductListDidUpdateNotification object:self];
}

-(VTAProduct *)vtaProductForIdentifier:(NSString *)identifier {
    return self.productLookupDictionary[identifier];
}

#pragma mark - Handling transactions

// Purchasing and restoring
-(void)purchaseProduct:(VTAProduct *)product {
    
    if ( [SKPaymentQueue canMakePayments] ) {
        
        SKPayment *payment = [SKPayment paymentWithProduct:product.product];
        [[SKPaymentQueue defaultQueue] addPayment:payment];
        product.purchaseInProgress = YES;
        
    } else {
        
        // Handle not allowed error

#if VTAInAppPurchasesDebug
        NSLog(@"Can't make payments");
#endif
        
    }
}

-(void)restoreProducts {
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

// Handling errors
-(void)handleStoreKitError:(NSError *)error forTransaction:(SKPaymentTransaction *)transaction {
    
#if VTAInAppPurchasesDebug
    NSLog(@"%s\n%@", __PRETTY_FUNCTION__, [error localizedDescription]);
#endif
    
    NSMutableDictionary *userInfo = [NSMutableDictionary new];
    if ( error ) {
        [userInfo setObject:error forKey:VTAInAppPurchasesNotificationErrorUserInfoKey];
    }
    if ( [self.productLookupDictionary objectForKey:transaction.payment.productIdentifier] ) {
        [userInfo setObject:@[[self.productLookupDictionary objectForKey:transaction.payment.productIdentifier]] forKey:VTAInAppPurchasesProductsAffectedUserInfoKey];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:VTAInAppPurchasesPurchasesDidCompleteNotification object:self userInfo:userInfo];
    
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    
    VTAProduct *product = [self.productLookupDictionary objectForKey:transaction.payment.productIdentifier];
    product.purchaseInProgress = NO;
    
}

// Providing content
-(void)provideContentForRestoredTransaction:(SKPaymentTransaction *)transaction {
    [self provideContent:transaction];
}

-(void)provideContentForTransaction:(SKPaymentTransaction *)transaction {
    [self provideContent:transaction];
}

-(void)provideContent:(SKPaymentTransaction *)transaction {
    
    VTAProduct *product = [self.productLookupDictionary objectForKey:transaction.payment.productIdentifier];
    
    // If there's no product, which might happen if we have a product in iTunes connect but not in our plist
    // We need to return without taking any further action
    if ( !product ) return;
    
    product.purchaseInProgress = NO;
    
    if ( !product.consumable ) {
        
        [self unlockNonConsumableProduct:product];
        
    } else {
        [self addProductValue:product];
    }
    
    NSDictionary *userInfo = @{VTAInAppPurchasesProductsAffectedUserInfoKey : @[product]};
    [[NSNotificationCenter defaultCenter] postNotificationName:VTAInAppPurchasesPurchasesDidCompleteNotification object:self userInfo:userInfo];
    
}

-(void)unlockNonConsumableProduct:(VTAProduct *)product {
    [self addProductToUnlockList:product];
    product.purchased = YES;
}

-(void)addProductValue:(VTAProduct *)product {
    NSNumber *number = [[NSUserDefaults standardUserDefaults] objectForKey:product.storageKey];
    number = @([number intValue] + [product.productValue intValue]);
    [[NSUserDefaults standardUserDefaults] setObject:number forKey:product.storageKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

-(void)addProductToUnlockList:(VTAProduct *)product {
    if ( product.storageKey ) {
        [self addProductValue:product];
    }
    NSArray *purchasedObjects = [[NSUserDefaults standardUserDefaults] objectForKey:VTAInAppPurchasesList];
    
    if ( !purchasedObjects ) {
        purchasedObjects = [NSArray new];
    }
    
    NSMutableDictionary *dictionary = [NSMutableDictionary new];
    [dictionary setObject:product.productIdentifier forKey:VTAInAppPurchasesListProductNameKey];
    
    NSArray *updatedPurchasedObjects = [purchasedObjects arrayByAddingObject:dictionary];
    [[NSUserDefaults standardUserDefaults] setObject:updatedPurchasedObjects forKey:VTAInAppPurchasesList];
}

#pragma mark - SKProductsRequestDelegate

-(void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    
#if VTAInAppPurchasesDebug
    NSLog(@"%s ", __PRETTY_FUNCTION__);
#endif
    
    NSMutableArray *newProductList = [self.productList mutableCopy];
    for ( NSString *productID in response.invalidProductIdentifiers ) {
        VTAProduct *productToRemove = [self.productLookupDictionary objectForKey:productID];
        [newProductList removeObject:productToRemove];
    }
    
    for ( SKProduct *product in response.products ) {
        VTAProduct *vtaProduct = [self.productLookupDictionary objectForKey:product.productIdentifier];
        vtaProduct.product = product;
    }
    
    _productList = [newProductList copy];
    
    if ( _receiptValidationFailed && _receiptRefreshFailed ) {
        
        
        _receiptRefreshFailed = NO;
        _receiptValidationFailed = NO;
        [self validateReceipt];
        [self validateProductsShouldUseDefaults:NO];
    }
    
    [self productLoadingDidFinishWithError:nil];
}

#pragma mark - SKRequestDelegate

-(void)requestDidFinish:(SKRequest *)request {
    
#if VTAInAppPurchasesDebug
    NSLog(@"%s ", __PRETTY_FUNCTION__);
#endif
    
    if ( request == self.refreshRequest ) {
        
#if VTAInAppPurchasesDebug
        NSLog(@"Refresh request finished");
#endif
        
        if ( _receiptValidationFailed && !_receiptRefreshFailed ) {
#if VTAInAppPurchasesDebug
            NSLog(@"Validating receipt");
#endif
            [self validateReceipt];
            [self validateProductsShouldUseDefaults:NO];
            _receiptRefreshFailed = YES;
        } else if ( _receiptRefreshFailed && _receiptValidationFailed ) {
            [self validateProductsShouldUseDefaults:YES];
        }
    } 
}

-(void)request:(SKRequest *)request didFailWithError:(NSError *)error {

#if VTAInAppPurchasesDebug
    NSLog(@"%s ", __PRETTY_FUNCTION__);
#endif
    
    if ( request == self.refreshRequest ) {
        
#if VTAInAppPurchasesDebug
        NSLog(@"Receipt refresh failed");
#endif
        _receiptRefreshFailed = YES;
        [self validateProductsShouldUseDefaults:YES];
    } else {
        [self productLoadingDidFinishWithError:error];
    }
    
}

#pragma mark - SKPaymentTransactionObserver

-(void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions {
    
    for ( SKPaymentTransaction *transaction in transactions ) {
        switch(transaction.transactionState) {
            case SKPaymentTransactionStatePurchasing: {
                
#if VTAInAppPurchasesDebug
                NSLog(@"Purchasing: %@", transaction.payment.productIdentifier);
#endif
                
                break;
            }
            case SKPaymentTransactionStateFailed: {
                

#if VTAInAppPurchasesDebug
                NSLog(@"Failed: %@", transaction.payment.productIdentifier);
#endif
                
                
                [self handleStoreKitError:transaction.error forTransaction:(SKPaymentTransaction *)transaction];
                [queue finishTransaction:transaction];
                break;
            }
            case SKPaymentTransactionStateRestored: {
                if ( transaction.downloads ) {
                    
                    VTAProduct *product = [self.productLookupDictionary objectForKey:transaction.payment.productIdentifier];
                    product.purchased = NO;
                    product.purchaseInProgress = YES;
                    
                    [[SKPaymentQueue defaultQueue] startDownloads:transaction.downloads];
                } else {
                    [self provideContentForRestoredTransaction:transaction];
                    [queue finishTransaction:transaction];

#if VTAInAppPurchasesDebug
                    NSLog(@"Restore completed: %@", transaction.payment.productIdentifier);
#endif
                }
                break;
            }
            case SKPaymentTransactionStatePurchased: {
                //                NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
                //                NSData *receipt = [NSData dataWithContentsOfURL:receiptURL];
                // Process transaction
                
                if ( transaction.downloads ) {
                    [[SKPaymentQueue defaultQueue] startDownloads:transaction.downloads];
                } else {
                    [self provideContentForTransaction:transaction];
                    [queue finishTransaction:transaction];

#if VTAInAppPurchasesDebug
                    NSLog(@"Purchase completed: %@", transaction.payment.productIdentifier);
#endif
                }
                
                // Don't try to get a local state for this payment. Don't keep a cache!
                break;
            }
                // iOS 8
            case SKPaymentTransactionStateDeferred: {
                // Allow user to continue to use the app
                // It may be some time (up to 24 hours)
                break;
            }
        }
    }
    
}

-(void)paymentQueue:(SKPaymentQueue *)queue removedTransactions:(NSArray *)transactions {
    // When a transaction was removed
}


// DOWNLOADS
-(void)paymentQueue:(SKPaymentQueue *)queue updatedDownloads:(NSArray *)downloads {
    
    // When a hosted download updates
    for ( SKDownload *download in downloads ) {
        
        VTAProduct *product = [self.productLookupDictionary objectForKey:download.transaction.payment.productIdentifier];
        NSError *downloadError;
        
        switch (download.downloadState) {
            case SKDownloadStateFailed: {
                
                downloadError = download.error;
                [[SKPaymentQueue defaultQueue] finishTransaction:download.transaction];
                
                break;
            }
                
                
            case SKDownloadStateFinished: {
                product.purchaseInProgress = NO;
                
                NSString *contentsPath = [[download.contentURL URLByAppendingPathComponent:@"Contents"] path];
                NSArray *array = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:contentsPath error:nil];
                
                if ( [[NSFileManager defaultManager] createDirectoryAtPath:[product.localContentURL path] withIntermediateDirectories:YES attributes:nil error:&downloadError] ) {
                    for ( NSString *path in array ) {
                        
                        [[NSFileManager defaultManager] removeItemAtPath:[[product.localContentURL URLByAppendingPathComponent:path] path] error:nil];
                        
                        [[NSFileManager defaultManager] copyItemAtPath:[contentsPath stringByAppendingPathComponent:path] toPath:[[product.localContentURL URLByAppendingPathComponent:path] path] error:&downloadError];
                        
                        if ( downloadError.code == 516 ) {
                            // File exists. Ignore.
                            downloadError = nil;
                        }
                        
                        [[product.localContentURL URLByAppendingPathComponent:path] setResourceValue:[NSNumber numberWithBool:YES]
                                                                                              forKey:NSURLIsExcludedFromBackupKey
                                                                                               error:nil];
                        

#if VTAInAppPurchasesDebug
                        NSLog(@"%s Moving from %@ to %@", __PRETTY_FUNCTION__, [contentsPath stringByAppendingPathComponent:path], [[product.localContentURL URLByAppendingPathComponent:path] path]);
#endif
                        
                        if ( downloadError ) {
                            break;
                        }
                    }
                }
                
                if ( downloadError ) {
                    
#if VTAInAppPurchasesDebug
                    NSLog(@"%s Failed to move file: %@", __PRETTY_FUNCTION__, downloadError.localizedDescription);
#endif
                    
                } else {
                    [self provideContentForTransaction:download.transaction];
                }
                [[SKPaymentQueue defaultQueue] finishTransaction:download.transaction];
                break;
            }
            case SKDownloadStateActive: {
                product.progress = download.progress;
                break;
            }
            case SKDownloadStateCancelled: {
                [[SKPaymentQueue defaultQueue] finishTransaction:download.transaction];
            }
            default:
                break;
        }
        
        NSDictionary *productsAffected;
        if ( downloadError ) {
            productsAffected = @{VTAInAppPurchasesNotificationErrorUserInfoKey : downloadError, VTAInAppPurchasesProductsAffectedUserInfoKey: @[product]};
        } else {
            productsAffected = @{VTAInAppPurchasesProductsAffectedUserInfoKey: @[product]};
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:VTAInAppPurchasesProductDownloadStatusDidChangeNotification object:self userInfo:productsAffected];
        
    }
}

// RESTORING
-(void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
    // Successful restore
    [[NSNotificationCenter defaultCenter] postNotificationName:VTAInAppPurchasesRestoreDidCompleteNotification object:self userInfo:nil];
}

-(void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
    NSDictionary *errorDict = @{VTAInAppPurchasesNotificationErrorUserInfoKey: error};
    [[NSNotificationCenter defaultCenter] postNotificationName:VTAInAppPurchasesRestoreDidCompleteNotification object:self userInfo:errorDict];
}


@end
