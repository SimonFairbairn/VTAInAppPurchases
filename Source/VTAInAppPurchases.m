//
//  VTAIAPHelper.m
//  IAP Example Suite
//
//  Created by Simon Fairbairn on 18/05/2014.
//  Copyright (c) 2014 Voyage Travel Apps. All rights reserved.
//

#import <StoreKit/StoreKit.h>
#import <Crashlytics/Crashlytics.h> // If using Answers with Crashlytics

#import "VTAInAppPurchases.h"
#import "VTAProduct.h"
#import "VTAInAppPurchasesReceiptValidation.h"

#ifdef DEBUG
#define VTAInAppPurchasesDebug 0
#define VTAInAppPurchasesDownloadDebug 0
#define VTAInAppPurchasesSKProductLoadFailure 0
#define VTAInAppPurchasesShortCacheTime 0
#define VTAInAppPurchasesResetCache 0
#define VTAInAppPurchasesCacheError 0
#define VTAInAppPurchasesPListError 0
#define VTAInAppPurchasesCacheWriteError 0
#define VTAInAppPurchasesClearInstantUnlock 0
#define VTAInAppPurchasesForceInvalidReceipt 0
#define VTAInAppPurchasesForceNilProduct 0
#define VTAInAppPurchasesCannotMakePurchases 0
#endif

NSString * const VTAInAppPurchasesErrorDomain = @"VTAInAppPurchasesErrorDomain";
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
@property (nonatomic, strong) NSURL *documentsURL;
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

-(NSURL *)documentsURL {
    if ( !_documentsURL ) {
        NSURL *documents = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
        _documentsURL = [documents URLByAppendingPathComponent:@"VTAInAppPurchasesCache.plist"];
#if VTAInAppPurchasesDebug
        NSLog(@"%s: %@", __PRETTY_FUNCTION__, _documentsURL);
#endif
        
    }
    return _documentsURL;
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
        _cachedPlistFile = [NSArray arrayWithContentsOfURL:self.documentsURL];
        if ( !_cachedPlistFile ) {
            _cachedPlistFile = [NSArray arrayWithContentsOfURL:self.cacheURL];
        }
    }
    return _cachedPlistFile;
}

-(NSNumber *)cacheDays {
    if ( !_cacheDays ) {
        _cacheDays = @(1);
    }
    return _cacheDays;
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
    NSLog(@"%s: Validating receipt.", __PRETTY_FUNCTION__);
#endif
    
    self.completion = completion;
    
    if ( ![self.validator validateReceipt] ) {
        [self failValidation];
    } else {
        
        _receiptValidationFailed = NO;
        _originalVersionNumber = self.validator.originalPurchasedVersion;        

#if VTAInAppPurchasesDebug
        NSLog(@"%s: Receipt is valid.", __PRETTY_FUNCTION__);
#endif
        if ( self.completion ) {
#if VTAInAppPurchasesDebug
            NSLog(@"%s: Running completion handler.", __PRETTY_FUNCTION__);
#endif
            
            self.completion(YES);
        }

        [[NSNotificationCenter defaultCenter] postNotificationName:VTAInAppPurchasesReceiptDidValidateNotification object:self];
    }
}

/**
 *  If validation fails, we will only attempt to refresh it once.
 */
-(void)failValidation {
    
    if ( !_receiptValidationFailed ) {
    
#if VTAInAppPurchasesDebug
        NSLog(@"%s: Requesting new receipt.", __PRETTY_FUNCTION__);
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
        NSLog(@"%s: Second attempt failed.", __PRETTY_FUNCTION__);
#endif
        
        self.completion(NO);
    }
    _receiptValidationFailed = YES;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:VTAInAppPurchasesReceiptValidationDidFailNotification object:self];
}

-(void)listLoadFailedWithError:(NSError *)error {

#if VTAInAppPurchasesDebug
    NSLog(@"%s: List load failed with error: %@", __PRETTY_FUNCTION__, error.localizedDescription);
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
    
    NSError *plistError = [NSError errorWithDomain:VTAInAppPurchasesErrorDomain code:VTAInAppPurchasesErrorCodePlistFileInvalid userInfo:@{NSLocalizedDescriptionKey : @"Property list was nil"}];
    
    
    if ( !self.remoteURL && !self.localURL ) {
        [self listLoadFailedWithError:plistError];
        return;
    }
    
    _productsLoadingStatus = VTAInAppPurchasesStatusProductsLoading;
    
    if ( [self cacheIsValid] ) {

#if VTAInAppPurchasesDebug
        NSLog(@"%s: Reading from cache", __PRETTY_FUNCTION__);
#endif

        [self setupProductsUsingCache:YES];
        return;
    }
        
#if VTAInAppPurchasesDebug
    NSLog(@"%s: Cache not available or expired", __PRETTY_FUNCTION__);
#endif
    
    if ( self.remoteURL ) {

#if VTAInAppPurchasesDebug
        NSLog(@"%s: Loading Remote URL", __PRETTY_FUNCTION__);
#endif
        
            NSURLSession *fetchSession = [NSURLSession sharedSession];
            NSURLSessionDataTask *fetchRemotePlistTask = [fetchSession dataTaskWithRequest:[NSURLRequest requestWithURL:self.remoteURL] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                
#if VTAInAppPurchasesShortCacheTime
                NSLog(@"%s: Sleeping", __PRETTY_FUNCTION__);
                [NSThread sleepForTimeInterval:10];
                NSLog(@"%s: Resuming", __PRETTY_FUNCTION__);
#endif
                
                
                id productIDs;
                
                if ( error ) {
                    
#if VTAInAppPurchasesDebug
                    NSLog(@"%s: Error connection: %@", __PRETTY_FUNCTION__, error.localizedDescription);
#endif
                    
                } else {
                    productIDs = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:nil error:&error];
                    NSDate *interval = [NSDate new];
#if VTAInAppPurchasesDebug
					NSLog(@"%s: New file received. Setting cache expiry: %@", __PRETTY_FUNCTION__, interval);
#endif
					
                    [[NSUserDefaults standardUserDefaults] setObject:interval forKey:VTAInAppPurchasesCacheRequestKey];
					[[NSUserDefaults standardUserDefaults] synchronize];
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
        NSLog(@"%s: Loading local URL", __PRETTY_FUNCTION__);
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
    
    if ( self.cachedPlistFile ) {
		
		NSLog(@"%@",  [[NSUserDefaults standardUserDefaults] objectForKey:VTAInAppPurchasesCacheRequestKey]);
		
        id isPreviousDate = [[NSUserDefaults standardUserDefaults] objectForKey:VTAInAppPurchasesCacheRequestKey];
		NSDate *previousDate;
		if ( [isPreviousDate isKindOfClass:[NSDate class]] ) {
			previousDate = (NSDate *)isPreviousDate;
		}
        
#if VTAInAppPurchasesResetCache
        NSLog(@"%s: Debug. Clearing cache.", __PRETTY_FUNCTION__);
//        secondsSinceLastUpdate = nil;
#endif
		NSDate *expiryDate = [previousDate dateByAddingTimeInterval:([self.cacheDays integerValue] * 24 * 60 * 60 )];
	
        
#if VTAInAppPurchasesShortCacheTime
        expiryDate = [NSDate dateWithTimeIntervalSinceReferenceDate:([secondsSinceLastUpdate intValue] + 30)];
#endif
        NSDate *now = [NSDate date];

#if VTAInAppPurchasesDebug
        NSLog(@"%s: Last updated: %@. Now: %@", __PRETTY_FUNCTION__, expiryDate, now);
#endif
        
        if ( previousDate && [[now laterDate:expiryDate] isEqualToDate:expiryDate]  ) {
            return YES;
        }
    }
    return NO;
}

-(void)attemptRecoveryWithCacheAfterPlistError:(NSError *)error {

#if VTAInAppPurchasesDebug
    NSLog(@"%s: %@", __PRETTY_FUNCTION__, error.localizedDescription);
#endif
    
    NSArray *cacheFile = self.cachedPlistFile;
    
#if VTAInAppPurchasesCacheError
    cacheFile = nil;
#endif
    
    if ( cacheFile ) {
        self.incomingPlistFile = [self.cachedPlistFile copy];
        [self setupProductsUsingCache:YES];
    } else {
        
#if VTAInAppPurchasesDebug
        NSLog(@"%s: Attempting recovery. Trying to load local URL.", __PRETTY_FUNCTION__);
#endif
        
        if ( self.localURL ) {
            self.incomingPlistFile = [NSArray arrayWithContentsOfURL:self.localURL];
            if (!self.incomingPlistFile ) {
                [self listLoadFailedWithError:error];
            } else {
                [self setupProductsUsingCache:YES];
            }
        } else {
            [self listLoadFailedWithError:error];
        }
    }
}

/**
 *  STEP 2: Extract the products from the plist file and check whether or not non-consumable
 *  products have been purchased. Start the StoreKit request. Mark the productsLoading as listLoaded.
 */
-(void)setupProductsUsingCache:(BOOL)usingCache {
    [self setupProductsUsingCache:usingCache startProductRequest:YES];
}

-(void)setupProductsUsingCache:(BOOL)usingCache startProductRequest:(BOOL)startRequest {

    NSMutableArray *updatedIncomingFile = [NSMutableArray array];
    NSMutableArray *array = [NSMutableArray array];
    NSMutableArray *productIDs = [NSMutableArray array];
    
    if ( !usingCache && self.cachedPlistFile ) {
        
#if VTAInAppPurchasesDebug
        NSLog(@"%s: Previous cache file found.", __PRETTY_FUNCTION__);
#endif
        
        for ( NSDictionary *incomingDictionary in self.incomingPlistFile ) {
            NSMutableDictionary *mutableIncomingDictionary = [incomingDictionary mutableCopy];
            for ( NSDictionary *cachedDictionary in self.cachedPlistFile ) {
                if ( [incomingDictionary[@"productIdentifier"] isEqualToString:cachedDictionary[@"productIdentifier"]] ) {
                    if ( [cachedDictionary[@"purchased"] boolValue] ) {

#if VTAInAppPurchasesDebug
                        NSLog(@"%s: Setting purchased flag on %@.", __PRETTY_FUNCTION__, incomingDictionary[@"productIdentifier"]);
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
#if VTAInAppPurchasesDebug
        NSLog(@"%s: Using cache but no cachedPlistFile.", __PRETTY_FUNCTION__);
#endif
        
        updatedIncomingFile = [self.incomingPlistFile mutableCopy];
    } else if ( !usingCache && !self.cachedPlistFile ){
#if VTAInAppPurchasesDebug
        NSLog(@"%s: Not using cache and no cachedPlistFile.", __PRETTY_FUNCTION__);
#endif
        
        updatedIncomingFile = [self.incomingPlistFile mutableCopy];
    } else if ( usingCache ) {
        
#if VTAInAppPurchasesDebug
        NSLog(@"%s: Using cache.", __PRETTY_FUNCTION__);
#endif
        
        updatedIncomingFile = [self.cachedPlistFile mutableCopy];
    }

    for ( id dictionary in updatedIncomingFile ) {
        if ( [dictionary isKindOfClass:[NSDictionary class]] ) {
            VTAProduct *product = [[VTAProduct alloc] initWithProductDetailDictionary:dictionary];
#if VTAInAppPurchasesForceNilProduct
//            product = nil;
#endif
            if ( product ) {
                [array addObject:product];
                [productIDs addObject:product.productIdentifier];
                [self.productLookupDictionary setObject:product forKey:product.productIdentifier];
            }
        }
    }
    
    self.productList = [array copy];

    for ( VTAProduct *product in self.productList ) {
        if ( product.childProducts ) {
            for ( NSString *childProductId in product.childProducts ) {
                VTAProduct *childProduct = [self vtaProductForIdentifier:childProductId];
                childProduct.parentProduct = product;
            }
        }
    }
    
#if VTAInAppPurchasesDebug
    NSLog(@"%s: New product list: %@", __PRETTY_FUNCTION__, self.productList);
#endif
    
    [self writePlistFileToCache:updatedIncomingFile];
    
    if ( startRequest ) {
        self.incomingPlistFile = [updatedIncomingFile copy];
        
        SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:[NSSet setWithArray:productIDs]];
        request.delegate = self;
        [request start];
        
        _productsLoadingStatus = VTAInAppPurchasesStatusProductsListLoaded;
        
        [[NSNotificationCenter defaultCenter] postNotificationName:VTAInAppPurchasesProductListDidUpdateNotification object:self];
    }
}

-(BOOL)writePlistFileToCache:(NSArray *)file {
    
#if VTAInAppPurchasesCacheWriteError
    file = nil;
#endif
    
    if ( [file writeToURL:self.documentsURL atomically:YES] ) {
        self.cachedPlistFile = nil;
        
#if VTAInAppPurchasesDebug
        NSLog(@"%s: Cache write success.", __PRETTY_FUNCTION__);
#endif
        
        return YES;
    } else {
#if VTAInAppPurchasesDebug
        NSLog(@"%s: Cache write failure", __PRETTY_FUNCTION__);
#endif
		
		NSDictionary *userInfo = [NSDictionary new];
		if ( file ) {
			userInfo = @{@"File" : file};
		}
		
		NSError *error = [NSError errorWithDomain:VTAInAppPurchasesErrorDomain code:VTAInAppPurchasesErrorCodeCacheWriteFailure userInfo:userInfo];
		[CrashlyticsKit recordError:error];
    }
	
    return NO;
}

#pragma mark - Product handling methods

/**
 *  STEP 3: Once the delegate has received a response, the products will have been updated with their
 *  SKProduct objects or there will have been some sort of failure.
 */
-(void)productLoadingDidFinishWithError:(NSError *)error {
    
#if VTAInAppPurchasesSKProductLoadFailure
    error = [NSError errorWithDomain:VTAInAppPurchasesErrorDomain code:102 userInfo:@{NSLocalizedDescriptionKey : @"Couldn't load products from App Store"}];
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
        NSLog(@"%s: Product loading error: %@", __PRETTY_FUNCTION__, error);
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
#if VTAInAppPurchasesDebug
	NSLog(@"%@", self.incomingPlistFile);
#endif
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
    
    if ( !product ) return;
    
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
    VTAProduct *product = self.productLookupDictionary[identifier];
    // If we don't have a product, then stuff hasn't been set up yet
    // Try to get the cached product
    if ( !product ) {
        
#if VTAInAppPurchasesDebug
        NSLog(@"%s. Product not available. Attempting to load from cache.", __PRETTY_FUNCTION__);
#endif
        
        [self setupProductsUsingCache:YES startProductRequest:NO];
        product = self.productLookupDictionary[identifier];
#if VTAInAppPurchasesDebug
        NSLog(@"%s. Load attempt: %@.", __PRETTY_FUNCTION__, product);
#endif
        
    }
    return product;
}

#pragma mark - Handling transactions

// Purchasing and restoring
-(void)purchaseProduct:(VTAProduct *)product {
    
    BOOL canMakePayments = [SKPaymentQueue canMakePayments];
    
#if VTAInAppPurchasesCannotMakePurchases
    canMakePayments = NO;
#endif
    
    if ( canMakePayments ) {
        
        SKPayment *payment = [SKPayment paymentWithProduct:product.product];
        [[SKPaymentQueue defaultQueue] addPayment:payment];
        product.purchaseInProgress = YES;
        
    } else {
        

        // Handle not allowed error
        NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : @"This Apple ID is unable to make payments. Please check your payment information." };
        NSError *error = [NSError errorWithDomain:VTAInAppPurchasesErrorDomain code:VTAInAppPurchasesErrorCodeCannotMakePayments userInfo:userInfo];
        
        NSDictionary *errorDict = @{ VTAInAppPurchasesNotificationErrorUserInfoKey : error, VTAInAppPurchasesProductsAffectedUserInfoKey : @[product] };
        
        [[NSNotificationCenter defaultCenter] postNotificationName:VTAInAppPurchasesPurchasesDidCompleteNotification object:nil userInfo:errorDict];
#if VTAInAppPurchasesDebug
        NSLog(@"%s: Can't make payments", __PRETTY_FUNCTION__);
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

#if VTAInAppPurchasesDebug
    NSLog(@"%s: Providing content for product: %@", __PRETTY_FUNCTION__, product.productIdentifier);
#endif
    
    
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
    
    NSMutableArray *newProductList = [self.productList mutableCopy];
    
#if VTAInAppPurchasesSKProductLoadFailure
    response = nil;
#endif
    
    for ( NSString *productID in response.invalidProductIdentifiers ) {
        
        VTAProduct *productToRemove = [self.productLookupDictionary objectForKey:productID];
        
#if VTAInAppPurchasesDebug
        NSLog(@"%s: Product invalid. Identifier: %@. Product: %@", __PRETTY_FUNCTION__, productID, productToRemove);
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
    
    if ( request == self.refreshRequest ) {
        
#if VTAInAppPurchasesDebug
        NSLog(@"%s: Refresh request finished", __PRETTY_FUNCTION__);
#endif
        
        if ( _receiptValidationFailed && !_receiptRefreshFailed ) {

#if VTAInAppPurchasesDebug
            NSLog(@"%s: Validating receipt", __PRETTY_FUNCTION__);
#endif
            [self validateReceiptWithCompletionHandler:self.completion];
            _receiptRefreshFailed = YES;
        }
    } 
}

-(void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    
    if ( request == self.refreshRequest ) {
        
#if VTAInAppPurchasesDebug
        NSLog(@"%s: Receipt refresh failed: %@", __PRETTY_FUNCTION__, error.localizedDescription);
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
                NSLog(@"%s: Purchasing: %@", __PRETTY_FUNCTION__, transaction.payment.productIdentifier);
#endif
                
                break;
            }
            case SKPaymentTransactionStateFailed: {
                

#if VTAInAppPurchasesDebug
                NSLog(@"%s: Failed: %@", __PRETTY_FUNCTION__, transaction.payment.productIdentifier);
#endif
                
                
                [self handleStoreKitError:transaction.error forTransaction:(SKPaymentTransaction *)transaction];
                [queue finishTransaction:transaction];
                break;
            }
            case SKPaymentTransactionStateRestored: {
                if ( transaction.downloads && transaction.downloads.count > 0 ) {
                    
                    VTAProduct *product = [self.productLookupDictionary objectForKey:transaction.payment.productIdentifier];
                    product.purchased = NO;
                    product.purchaseInProgress = YES;
                    
                    [[SKPaymentQueue defaultQueue] startDownloads:transaction.downloads];
                } else {
                    [self provideContentForRestoredTransaction:transaction];
                    [queue finishTransaction:transaction];

#if VTAInAppPurchasesDebug
                    NSLog(@"%s: Restore completed: %@", __PRETTY_FUNCTION__, transaction.payment.productIdentifier);
#endif
                }
                break;
            }
            case SKPaymentTransactionStatePurchased: {
                //                NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
                //                NSData *receipt = [NSData dataWithContentsOfURL:receiptURL];
                // Process transaction
                if ( transaction.downloads && transaction.downloads.count > 0 ) {
#if VTAInAppPurchasesDebug
                    NSLog(@"%s: Begin download: %@", __PRETTY_FUNCTION__, transaction.payment.productIdentifier);
#endif
                    
                    [[SKPaymentQueue defaultQueue] startDownloads:transaction.downloads];
                } else {
                    [self provideContentForTransaction:transaction];
                    [queue finishTransaction:transaction];

#if VTAInAppPurchasesDebug
                    NSLog(@"%s: Purchase completed: %@", __PRETTY_FUNCTION__, transaction.payment.productIdentifier);
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
                NSLog(@"%s: Deferring: %@", __PRETTY_FUNCTION__, transaction.payment.productIdentifier);
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
#if VTAInAppPurchasesForceNilProduct
        product = nil;
#endif
        
        NSError *downloadError;
        
        switch (download.downloadState) {
            case SKDownloadStateFailed: {

#if VTAInAppPurchasesDebug
                NSLog(@"%s: Download failed: %@", __PRETTY_FUNCTION__, download.error.localizedDescription);
#endif
                downloadError = download.error;
                [[SKPaymentQueue defaultQueue] finishTransaction:download.transaction];
                
                break;
            }
                
                
            case SKDownloadStateFinished: {
                product.purchaseInProgress = NO;
                NSString *contentsPath = [[download.contentURL URLByAppendingPathComponent:@"Contents"] path];
                NSArray *array = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:contentsPath error:nil];
                
#if VTAInAppPurchasesDebug
                NSLog(@"%s: Download finished for product: %@", __PRETTY_FUNCTION__, product.productIdentifier);
#endif
                
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
                        

#if VTAInAppPurchasesDownloadDebug
                        NSLog(@"VTAInAppPurchases: %s Moving from %@ to %@", __PRETTY_FUNCTION__, [contentsPath stringByAppendingPathComponent:path], [[product.localContentURL URLByAppendingPathComponent:path] path]);
#endif
                        
//                        if ( downloadError ) {
//                            break;
//                        }
                    }
                }
#if VTAInAppPurchasesDownloadDebug
//                downloadError = [NSError errorWithDomain:@"VTAInAppPurchasesError" code:100 userInfo:@{NSLocalizedDescriptionKey : @"Forced download error"}];
#endif
                
                if ( downloadError ) {
                    
#if VTAInAppPurchasesDownloadDebug
                    NSLog(@"VTAInAppPurchases: %s Failed to move file: %@", __PRETTY_FUNCTION__, downloadError.localizedDescription);
#endif
                    
                } else {
                    [self provideContentForTransaction:download.transaction];
                }
                
                // Finish transaction
                [[SKPaymentQueue defaultQueue] finishTransaction:download.transaction];
                break;
            }
            case SKDownloadStateActive: {
                product.progress = download.progress;
#if VTAInAppPurchasesDownloadDebug
                NSLog(@"%s updating progress: %@ for product: %@", __PRETTY_FUNCTION__, @(product.progress), product.productIdentifier);
#endif
                
                break;
            }
            case SKDownloadStateCancelled: {
                [[SKPaymentQueue defaultQueue] finishTransaction:download.transaction];
            }
            default:
                break;
        }
        
        NSMutableDictionary *productsAffected = [NSMutableDictionary new];
        if ( product ) {
            [productsAffected setObject:@[product] forKey:VTAInAppPurchasesProductsAffectedUserInfoKey];
        }
        if ( downloadError ) {
            [productsAffected setObject:downloadError forKey:VTAInAppPurchasesNotificationErrorUserInfoKey];
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
