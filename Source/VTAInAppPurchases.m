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
#define VTAInAppPurchasesDebug 0
#define VTAInAppPurchasesPListError 0
#define VTAInAppPurchasesCacheError 0
#define VTAInAppPurchasesClearInstantUnlock 0
#define VTAInAppPurchasesForceInvalidReceipt 0
#endif

NSString * const VTAInAppPurchasesProductListDidUpdateNotification = @"VTAInAppPurchasesProductListDidUpdateNotification";
NSString * const VTAInAppPurchasesProductsDidFinishUpdatingNotification = @"VTAInAppPurchasesProductsDidFinishUpdatingNotification";
NSString * const VTAInAppPurchasesPurchasesDidCompleteNotification = @"VTAInAppPurchasesPurchasesDidCompleteNotification";
NSString * const VTAInAppPurchasesRestoreDidCompleteNotification = @"VTAInAppPurchasesRestoreDidCompleteNotification";
NSString * const VTAInAppPurchasesProductDownloadStatusDidChangeNotification = @"VTAInAppPurchasesProductDownloadStatusDidChangeNotification";

NSString * const VTAInAppPurchasesReceiptDidValidateNotification = @"VTAInAppPurchasesReceiptDidValidate";
NSString * const VTAInAppPurchasesReceiptValidationDidFailNotification = @"VTAInAppPurchasesReceiptValidationDidFail";

NSString * const VTAInAppPurchasesNotificationErrorUserInfoKey = @"VTAInAppPurchasesNotificationErrorUserInfoKey";
NSString * const VTAInAppPurchasesProductsAffectedUserInfoKey = @"VTAInAppPurchasesProductsAffectedUserInfoKey";

static NSString * const VTAInAppPurchasesList = @"purchases.plist";
static NSString * const VTAInAppPurchasesInstantUnlockKey = @"VTAInAppPurchasesInstantUnlockKey";

static NSString * const VTAInAppPurchasesCacheRequestKey = @"VTAInAppPurchasesCacheRequestKey";

static NSString * const VTAInAppPurchasesListProductNameKey = @"VTAInAppPurchasesListProductNameKey";
static NSString * const VTAInAppPurchasesListProductLocationKey = @"VTAInAppPurchasesListProductLocationKey";
static NSString * const VTAInAppPurchasesListProductTitleKey = @"VTAInAppPurchasesListProductTitleKey";

@interface VTAInAppPurchases () <SKProductsRequestDelegate, SKRequestDelegate, SKPaymentTransactionObserver, NSURLSessionDelegate, NSURLSessionTaskDelegate>

@property (nonatomic, strong) NSArray *productIDs;
@property (nonatomic, strong) NSMutableDictionary *productLookupDictionary;
@property (nonatomic, strong) SKReceiptRefreshRequest *refreshRequest;

@property (nonatomic, strong) VTAInAppPurchasesReceiptValidation *validator;

@property (nonatomic, strong) NSMutableArray *instantUnlockProducts;

@property (nonatomic, readwrite) NSArray *productList;

@property (nonatomic, strong) NSMutableDictionary *titleList;

// New properties
@property (nonatomic, copy) void (^completion)(BOOL receiptIsValid);
@property (nonatomic, strong) NSURL *cacheURL;
@property (nonatomic, strong) NSArray *cachedPlistFile;
@property (nonatomic, strong) NSArray *incomingPlistFile;

@end

@implementation VTAInAppPurchases {
    BOOL _receiptValidationFailed;
    BOOL _receiptRefreshFailed;
    BOOL _observerAdded;
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

-(NSMutableArray *) instantUnlockProducts {
    if ( !_instantUnlockProducts ) {
        _instantUnlockProducts = [[[NSUserDefaults standardUserDefaults] objectForKey:VTAInAppPurchasesInstantUnlockKey] mutableCopy];

#if VTAInAppPurchasesClearInstantUnlock
        _instantUnlockProducts = nil;
        [[NSUserDefaults standardUserDefaults] setObject:nil forKey:VTAInAppPurchasesInstantUnlockKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
#endif
        
        if ( !_instantUnlockProducts ) {
            _instantUnlockProducts = [NSMutableArray new];
        }
    }
    return _instantUnlockProducts;
}

-(NSMutableDictionary *) titleList {
    if ( !_titleList ) {
        _titleList = [NSMutableDictionary new];
    }
    return _titleList;
}

-(NSURL *) cacheURL {
    if ( !_cacheURL ) {
        NSURL *cachesURL = [[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] firstObject];
        _cacheURL = [cachesURL URLByAppendingPathComponent:@"VTAInAppPurchasesCache.plist"];
    }
    return _cacheURL;
}

-(NSArray *) cachedPlistFile {
    if ( !_cachedPlistFile ) {
        _cachedPlistFile = [NSArray arrayWithContentsOfURL:self.cacheURL];
    }
    return _cachedPlistFile;
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

/**
 *  Validates the receipt using the receipt validator.
 */
-(void)validateReceiptWithCompletionHandler:(void (^)(BOOL))completion {
    
#if VTAInAppPurchasesDebug
    NSLog(@"Validating receipt.");
#endif
    
    self.completion = completion;
    
    if ( ![self.validator validateReceipt] ) {
        [self failValidation];
    } else {

#if VTAInAppPurchasesDebug
        NSLog(@"Receipt is valid.");
#endif
        if ( self.completion ) {
            self.completion(YES);
        }

        _receiptValidationFailed = NO;
        _originalVersionNumber = self.validator.originalPurchasedVersion;
        [[NSNotificationCenter defaultCenter] postNotificationName:VTAInAppPurchasesReceiptDidValidateNotification object:self];        
    }
}

/**
 *  If validation fails, we will only attempt to refresh it once.
 */
-(void)failValidation {
    
#if VTAInAppPurchasesDebug
    NSLog(@"%s ", __PRETTY_FUNCTION__);
#endif

    if ( !_receiptValidationFailed ) {
    
#if VTAInAppPurchasesDebug
        NSLog(@"Requesting new receipt.");
#endif
        // Only attempt to fetch new receipt if we have a secure connection
        NSURL *appleSite = [NSURL URLWithString:@"https://www.apple.com"];
        NSURLSession *testSession = [NSURLSession sharedSession];
        NSURLSessionDataTask *fetchRemoteSiteTask = [testSession dataTaskWithRequest:[NSURLRequest requestWithURL:appleSite] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if ( !error ) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.refreshRequest = [[SKReceiptRefreshRequest alloc] init];
                    self.refreshRequest.delegate = self;
                    [self.refreshRequest start];
                });
            } else {
                self.completion(NO);
            }
            
        }];
        [fetchRemoteSiteTask resume];
    } else {

#if VTAInAppPurchasesDebug
        NSLog(@"Second attempt failed.");
#endif
        
        self.completion(NO);
    }
    _receiptValidationFailed = YES;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:VTAInAppPurchasesReceiptValidationDidFailNotification object:self];
}

-(void)listLoadFailedWithError:(NSError *)error {

#if VTAInAppPurchasesDebug
    NSLog(@"List load failed with error: %@", error.localizedDescription);
#endif
    if ( !error ) {
        [NSException raise:NSInvalidArgumentException format:@"The method listLoadFailedWithError: requires an NSError paramter"];
    }
    _productsLoadingStatus = VTAInAppPurchasesStatusProductsListLoadFailed;
    NSDictionary *userInfo = @{VTAInAppPurchasesNotificationErrorUserInfoKey : error };
    [[NSNotificationCenter defaultCenter] postNotificationName:VTAInAppPurchasesProductsDidFinishUpdatingNotification object:self userInfo:userInfo];
}

/**
 *  STEP 1: Load the products from the plist file. Mark the productsLoading status as loading.
 *  We'll cache the plist file for one day then merge the latest with the existing cache.
 *
 *  The keys we'll be adding to the plist will be a localized name and a purchased bool.
 */
-(void)loadProducts {
    
#if VTAInAppPurchasesDebug
    NSLog(@"%s ", __PRETTY_FUNCTION__);
#endif
    
    NSError *plistError = [NSError errorWithDomain:@"com.voyagetravelapps.VTAInAppPurchases" code:1 userInfo:@{NSLocalizedDescriptionKey : @"Property list was nil"}];
    
    
    if ( !self.remoteURL && !self.localURL ) {
        [self listLoadFailedWithError:plistError];
        return;
    }
    
    _productsLoadingStatus = VTAInAppPurchasesStatusProductsLoading;
    
    if ( [self cacheIsValid] ) {

#if VTAInAppPurchasesDebug
        NSLog(@"Reading from cache");
#endif

        [self setupProductsUsingCache:YES];
        return;
    }
        
#if VTAInAppPurchasesDebug
    NSLog(@"Cache not available or expired");
#endif
    
    if ( self.remoteURL ) {

#if VTAInAppPurchasesDebug
        NSLog(@"Loading Remote URL");
#endif
        
            NSURLSession *fetchSession = [NSURLSession sharedSession];
            NSURLSessionDataTask *fetchRemotePlistTask = [fetchSession dataTaskWithRequest:[NSURLRequest requestWithURL:self.remoteURL] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                
                id productIDs;
                
                if ( error ) {
                    
#if VTAInAppPurchasesDebug
                    NSLog(@"Error connection: %@", error.localizedDescription);
#endif
                    
                } else {
                    
                    productIDs = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:nil error:&error];

                }
                
#if VTAInAppPurchasesPListError
                productIDs = nil;
#endif
                
                if ( error || (!error && ![productIDs isKindOfClass:[NSArray class]] ) ) {
                    [self attemptRecoveryWithCacheAfterPlistError:error];
                } else {
                    self.incomingPlistFile = (NSArray *)productIDs;
                    if (!self.incomingPlistFile ) {
                        [self attemptRecoveryWithCacheAfterPlistError:plistError];
                    } else {
                        [self setupProductsUsingCache:NO];
                    }
                }
                
            }];
            [fetchRemotePlistTask resume];

        
    } else if ( self.localURL ) {

#if VTAInAppPurchasesDebug
        NSLog(@"Loading local URL");
#endif
        
        self.incomingPlistFile = [NSArray arrayWithContentsOfURL:self.localURL];

#if VTAInAppPurchasesPListError
        self.incomingPlistFile = nil;
#endif
        if (!self.incomingPlistFile ) {
            [self attemptRecoveryWithCacheAfterPlistError:plistError];
        } else {
            [self setupProductsUsingCache:NO];
        }
    }
}

#pragma mark - Cache methods

-(BOOL)cacheIsValid {
    
#if VTAInAppPurchasesDebug
    NSLog(@"%s", __PRETTY_FUNCTION__);
#endif
    
    if ( self.cachedPlistFile ) {
        
        NSNumber *secondsSinceLastUpdate = [[NSUserDefaults standardUserDefaults] objectForKey:VTAInAppPurchasesCacheRequestKey];
        
#if VTAInAppPurchasesDebug
        NSLog(@"%@", secondsSinceLastUpdate);
        secondsSinceLastUpdate = nil;
#endif
        
        NSDate *lastUpdate = [NSDate dateWithTimeIntervalSinceReferenceDate:([secondsSinceLastUpdate intValue] + 24 * 60 * 60)];
        NSDate *now = [NSDate date];
        
        if ( secondsSinceLastUpdate || [[now laterDate:lastUpdate] isEqualToDate:lastUpdate]  ) {
            return YES;
        }
        
    }
    return NO;
}

-(void)attemptRecoveryWithCacheAfterPlistError:(NSError *)error {

#if VTAInAppPurchasesDebug
    NSLog(@"%s\n%@", __PRETTY_FUNCTION__, error.localizedDescription);
#endif
    
    NSArray *cacheFile = self.cachedPlistFile;
    
#if VTAInAppPurchasesCacheError
    cacheFile = nil;
#endif
    
    if ( cacheFile ) {
        self.incomingPlistFile = [self.cachedPlistFile copy];
        [self setupProductsUsingCache:YES];
    } else {
        [self listLoadFailedWithError:error];
    }
}

/**
 *  STEP 2: Extract the products from the plist file and check whether or not non-consumable
 *  products have been purchased. Start the StoreKit request. Mark the productsLoading as listLoaded.
 */
-(void)setupProductsUsingCache:(BOOL)usingCache {

#if VTAInAppPurchasesDebug
    NSLog(@"%s ", __PRETTY_FUNCTION__);
#endif
    
    NSMutableArray *updatedIncomingFile = [NSMutableArray array];
    NSMutableArray *array = [NSMutableArray array];
    NSMutableArray *productIDs = [NSMutableArray array];
    
    if ( !usingCache && self.cachedPlistFile ) {
        
#if VTAInAppPurchasesDebug
        NSLog(@"Previous cache file found.");
#endif
        
        for ( NSDictionary *incomingDictionary in self.incomingPlistFile ) {
            NSMutableDictionary *mutableIncomingDictionary = [incomingDictionary mutableCopy];
            for ( NSDictionary *cachedDictionary in self.cachedPlistFile ) {
                if ( [incomingDictionary[@"productIdentifier"] isEqualToString:cachedDictionary[@"productIdentifier"]] ) {
                    if ( [cachedDictionary[@"purchased"] boolValue] ) {

#if VTAInAppPurchasesDebug
                        NSLog(@"Setting purchased flag on %@.", incomingDictionary[@"productIdentifier"]);
#endif
                        
                        [mutableIncomingDictionary setValue:@(YES) forKey:@"purchased"];
                    }
                    if ( cachedDictionary[@"productTitle"] ) {
                        [mutableIncomingDictionary setValue:cachedDictionary[@"productTitle"] forKey:@"productTitle"];
                    }
                }
            }
            [updatedIncomingFile addObject:mutableIncomingDictionary];
        }
    } else if ( usingCache && !self.cachedPlistFile ) {
        updatedIncomingFile = [self.incomingPlistFile mutableCopy];
    } else if ( !usingCache && !self.cachedPlistFile ){
        updatedIncomingFile = [self.incomingPlistFile mutableCopy];
    } else if ( usingCache ) {
        updatedIncomingFile = [self.cachedPlistFile mutableCopy];
    }

    for ( id dictionary in updatedIncomingFile ) {
        if ( [dictionary isKindOfClass:[NSDictionary class]] ) {
            VTAProduct *product = [[VTAProduct alloc] initWithProductDetailDictionary:dictionary];
            [array addObject:product];
            [productIDs addObject:product.productIdentifier];
            [self.productLookupDictionary setObject:product forKey:product.productIdentifier];
        }
    }
    
    self.productList = [array copy];
    
#if VTAInAppPurchasesDebug
    NSLog(@"New product list: %@", self.productList);
#endif
    
    [self writePlistFileToCache:updatedIncomingFile];
    
    self.incomingPlistFile = [updatedIncomingFile copy];
    
    SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:[NSSet setWithArray:productIDs]];
    request.delegate = self;
    [request start];
    
    _productsLoadingStatus = VTAInAppPurchasesStatusProductsListLoaded;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:VTAInAppPurchasesProductListDidUpdateNotification object:self];
}

-(BOOL)writePlistFileToCache:(NSArray *)file {
    
#if VTAInAppPurchasesDebug
    NSLog(@"%s", __PRETTY_FUNCTION__);
#endif
    
    if ( [file writeToURL:self.cacheURL atomically:YES] ) {
        NSTimeInterval interval = [NSDate timeIntervalSinceReferenceDate];
        [[NSUserDefaults standardUserDefaults] setObject:@(interval) forKey:VTAInAppPurchasesCacheRequestKey];
        self.cachedPlistFile = nil;
        
#if VTAInAppPurchasesDebug
        NSLog(@"Cache write success.");
#endif
        
        return YES;
    } else {
#if VTAInAppPurchasesDebug
        NSLog(@"Cache write failure");
#endif
    }
    return NO;
}

#pragma mark - Product handling methods

/**
 *  STEP 3: Once the delegate has received a response, the products will have been updated with their
 *  SKProduct objects or there will have been some sort of failure.
 */
-(void)productLoadingDidFinishWithError:(NSError *)error {
    
#if VTAInAppPurchasesDebug
    NSLog(@"%s ", __PRETTY_FUNCTION__);
#endif
    
    if ( self.productList ) {
        [self updateCache];
        if ( !_observerAdded ) {
            [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
            _observerAdded = YES;
        }
    }
    
    NSDictionary *userInfo;
    
    if ( error ) {

#if VTAInAppPurchasesDebug
        NSLog(@"Product loading error: %@", error);
#endif
        
        userInfo = @{VTAInAppPurchasesNotificationErrorUserInfoKey : error };
        _productsLoadingStatus = VTAInAppPurchasesStatusProductsLoadFailed;
    } else {
        _productsLoadingStatus = VTAInAppPurchasesStatusProductsLoaded;
    }
    
    [self validateProducts];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:VTAInAppPurchasesProductsDidFinishUpdatingNotification object:nil userInfo:userInfo];
}

-(void)updateCache {
    
#if VTAInAppPurchasesDebug
    NSLog(@"%s ", __PRETTY_FUNCTION__);
#endif
    
    NSMutableArray *arrayOfProductsInPlist = [NSMutableArray array];
    for ( VTAProduct *product in self.productList ) {
        if ( !product.productTitle ) {
            product.productTitle = product.product.localizedTitle;
        }
        for ( NSDictionary *productDictionary in self.incomingPlistFile ) {
            
            if ( [productDictionary[@"productIdentifier"] isEqualToString:product.productIdentifier] ) {
                NSMutableDictionary *dictionary = [productDictionary mutableCopy];
                dictionary[@"productTitle"] = (product.productTitle) ? product.productTitle : product.productIdentifier;
                dictionary[@"purchased"] = @(product.purchased);
                [arrayOfProductsInPlist addObject:dictionary];
            }
        }
        
    }
    
    
    
    [self writePlistFileToCache:arrayOfProductsInPlist];
    self.incomingPlistFile = [arrayOfProductsInPlist copy];
//    self.cachedPlistFile = [arrayOfProductsInPlist copy];
}

/**
 *  Validating products. If the receipt is valid, then we go through what's in the receipt
 *  and update the purchase status based on the arrayOfPurchasedIAPs property
 */
-(void)validateProducts {
    
#if VTAInAppPurchasesDebug
    NSLog(@"%s ", __PRETTY_FUNCTION__);
#endif
    
    if ( self.validator.valid ) {
        for ( VTAProduct *product in self.productList ) {
            
            product.purchased = NO;
            
            for ( NSString *identifier in self.validator.arrayOfPurchasedIAPs ) {
                [self checkIdentifier:identifier forProduct:product];
            }
            
            for ( NSString *identifier in self.instantUnlockProducts ) {
                [self checkIdentifier:identifier forProduct:product];
            }
        }
    }
    [self updateCache];
}

-(void)checkIdentifier:(NSString *)identifier forProduct:(VTAProduct *)product {
    if ( [product.productIdentifier isEqualToString:identifier] ) {
        product.purchased = YES;
//        product.productTitle = ( product.product.localizedTitle ) ? product.product.localizedTitle : product.productIdentifier;
        
        // Recurse through child products
        if ( [product.childProducts count] > 0 ) {
            for ( NSString *childIdentifier in product.childProducts ) {
                VTAProduct *childProduct = [self vtaProductForIdentifier:childIdentifier];
                [self checkIdentifier:childIdentifier forProduct:childProduct];
            }
        }
    }
}

-(void)unlockNonConsumableProduct:(VTAProduct *)product saveToDefaults:(BOOL)shouldSave {
#if VTAInAppPurchasesDebug
    NSLog(@"%s ", __PRETTY_FUNCTION__);
#endif
    
    // If we're instantly unlocking this product, we need to make a note of its identifer
    // so that it can be saved locally
    NSMutableArray *arrayOfProductIdentifiersToSave = [NSMutableArray array];
    if ( shouldSave ) {
        [arrayOfProductIdentifiersToSave addObject:product.productIdentifier];
    }

    // Regular unlocking procedure for all products
    if ( product.product ) {
        product.productTitle = product.product.localizedTitle;
    }
    product.purchased = YES;
    
    // Make a note of all the products to be affected
    NSMutableArray *arrayOfPurchasedProducts = [@[product] mutableCopy];
    
    // If this product unlocks other products..
    for ( NSString *childProductIdentifer in product.childProducts ) {
        VTAProduct *childProduct = [self vtaProductForIdentifier:childProductIdentifer];
        
        // ..we need to force a save as it will not be logged in the receipt.
        shouldSave = YES;
        childProduct.purchased = YES;
        if ( childProduct.product ) {
            childProduct.productTitle = childProduct.product.localizedTitle;
        }

        // Add the product identifier to the list to be saved to NSUserDefaults
        [arrayOfProductIdentifiersToSave addObject:childProduct.productIdentifier];
        
        // Make a note that this product was affected as well
        [arrayOfPurchasedProducts addObject:childProduct ];
    }
    
    // If we instantly unlocked a product, or there are child products...
    if ( shouldSave ) {
        
        // ...go through each of the identifiers
        for ( NSString *productIdentifier in arrayOfProductIdentifiersToSave ) {
            
            // If it already exists in the array, no need to add it again
            BOOL exists = NO;
            for (NSString *string in self.instantUnlockProducts) {
                if ( [string isEqualToString:productIdentifier] ) {
                    exists = YES;
                    break;
                }
            }
            if ( !exists ) {
                [self.instantUnlockProducts addObject:productIdentifier];
                [[NSUserDefaults standardUserDefaults] setObject:[self.instantUnlockProducts copy] forKey:VTAInAppPurchasesInstantUnlockKey];
            }
        }
        [[NSUserDefaults standardUserDefaults] synchronize];
    }

    // Write all of these changes to the cache
    [self updateCache];
    
    // Finally, notifiy
    NSDictionary *userInfo = @{VTAInAppPurchasesProductsAffectedUserInfoKey : [arrayOfPurchasedProducts copy]};
    [[NSNotificationCenter defaultCenter] postNotificationName:VTAProductStatusDidChangeNotification object:self userInfo:userInfo];
}

-(void)unlockNonConsumableProduct:(VTAProduct *)product {
    // For instant unlocks, we will require a save to the defaults
    [self unlockNonConsumableProduct:product saveToDefaults:YES];
}

-(void)addConsumableProductValue:(VTAProduct *)product {
    if ( product.storageKey ) {
        NSNumber *number = [[NSUserDefaults standardUserDefaults] objectForKey:product.storageKey];
        number = @([number intValue] + [product.productValue intValue]);
        [[NSUserDefaults standardUserDefaults] setObject:number forKey:product.storageKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

-(void)applyProductValue:(VTAProduct *)product {
    if ( product.storageKey ) {
        [self addConsumableProductValue:product];
    }
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
        [self unlockNonConsumableProduct:product saveToDefaults:NO];
    } else {
        [self addConsumableProductValue:product];
    }
    
    NSDictionary *userInfo = @{VTAInAppPurchasesProductsAffectedUserInfoKey : @[product]};
    [[NSNotificationCenter defaultCenter] postNotificationName:VTAInAppPurchasesPurchasesDidCompleteNotification object:self userInfo:userInfo];
}



#pragma mark -
#pragma mark - SKProductsRequestDelegate

-(void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    
#if VTAInAppPurchasesDebug
    NSLog(@"%s ", __PRETTY_FUNCTION__);
#endif
    
    NSMutableArray *newProductList = [self.productList mutableCopy];
    for ( NSString *productID in response.invalidProductIdentifiers ) {
        
        VTAProduct *productToRemove = [self.productLookupDictionary objectForKey:productID];
        
#if VTAInAppPurchasesDebug
        NSLog(@"Product invalid. Identifier: %@. Product: %@", productID, productToRemove);
#endif
        
        [newProductList removeObject:productToRemove];
    }
    
    for ( SKProduct *product in response.products ) {
        VTAProduct *vtaProduct = [self.productLookupDictionary objectForKey:product.productIdentifier];
        vtaProduct.product = product;
        if ( vtaProduct.purchased ) {
            vtaProduct.productTitle = product.localizedTitle;
        }
    }
    
    self.productList = [newProductList copy];
    
    if ( _receiptValidationFailed && _receiptRefreshFailed ) {
        _receiptRefreshFailed = NO;
        _receiptValidationFailed = NO;
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
            [self validateReceiptWithCompletionHandler:self.completion];
            _receiptRefreshFailed = YES;
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
        self.completion(NO);
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
#if VTAInAppPurchasesDebug
                    NSLog(@"Begin download: %@", transaction.payment.productIdentifier);
#endif
                    
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
                
#if VTAInAppPurchasesDebug
                NSLog(@"Deferring: %@", transaction.payment.productIdentifier);
#endif
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

#if VTAInAppPurchasesDebug
                NSLog(@"Download failed: %@", download.error.localizedDescription);
#endif
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
