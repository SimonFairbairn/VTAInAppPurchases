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
#import "Bio.h"
#import "pkcs7.h"
#import "x509.h"

#define VTAInAppPurchasesDebug 1

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
@property (nonatomic, strong) NSMutableArray *arrayOfPurchasedIAPs;

@end

@implementation VTAInAppPurchases

#pragma mark - Properties

-(NSMutableDictionary *) productLookupDictionary {
    if ( !_productLookupDictionary ) {
        _productLookupDictionary = [NSMutableDictionary new];
    }
    return _productLookupDictionary;
}

-(NSMutableArray *)arrayOfPurchasedIAPs {
    if ( !_arrayOfPurchasedIAPs ) {
        _arrayOfPurchasedIAPs = [NSMutableArray array];
    }
    return _arrayOfPurchasedIAPs;
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

-(int)readInteger:(const uint8_t**)p withLength:(long)max {
    int tag, asn1Class;
    long length;
    int value = 0;
    ASN1_get_object(p, &length, &tag, &asn1Class, max);
    if (tag == V_ASN1_INTEGER)
    {
        for (int i = 0; i < length; i++)
        {
            value = value * 0x100 + (*p)[i];
        }
    }
    *p += length;
    return value;
}

-(NSData *)readOctet:(const uint8_t**)p withLength:(long)max {
    int tag, asn1Class;
    long length;
    NSData *data = nil;
    ASN1_get_object(p, &length, &tag, &asn1Class, max);
    if (tag == V_ASN1_OCTET_STRING)
    {
        data = [NSData dataWithBytes:*p length:max];
    }
    *p += length;
    return data;
}

-(NSString *)readString:(const uint8_t **)p withLength:(long)max {
    int tag, asn1Class;
    long length;
    NSString *value = nil;
    ASN1_get_object(p, &length, &tag, &asn1Class, max);
    if (tag == V_ASN1_UTF8STRING)
    {
        value = [[NSString alloc] initWithBytes:*p length:length encoding:NSUTF8StringEncoding];
    }
    *p += length;
    return value;
}

-(void)validateReceipt {
    
    OpenSSL_add_all_digests();
    
    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    
    self.refreshRequest = [[SKReceiptRefreshRequest alloc] init];
    self.refreshRequest.delegate = self;
    
    if ( ![[NSFileManager defaultManager] fileExistsAtPath:receiptURL.path] ) {
#ifdef DEBUG
#if VTAInAppPurchasesDebug
        NSLog(@"No receipt");
#endif
#endif
        [self.refreshRequest start];
        return;
    }
    
    // Find Apple's certificate in the bundle
    NSURL *certificateURL = [[NSBundle mainBundle] URLForResource:@"AppleIncRootCertificate" withExtension:@"cer"];
    
    // Read the data of both the receipt and the certificate
    NSData *receiptData = [NSData dataWithContentsOfURL:receiptURL];
    NSData *certificateData = [NSData dataWithContentsOfURL:certificateURL];
    
    // Create new BIO objects of both
    BIO *b_receipt = BIO_new_mem_buf((void *)[receiptData bytes], (int)[receiptData length]);
    BIO *b_x509 = BIO_new_mem_buf((void *)[certificateData bytes], (int)[certificateData length]);
    
    // Put the receipt data in a p7 representation
    PKCS7 *p7 = d2i_PKCS7_bio(b_receipt, NULL);
    
    // Create a new certificate store and add the Apple Root CA to the store
    X509_STORE *store = X509_STORE_new();
    X509 *appleRootCA = d2i_X509_bio(b_x509, NULL);
    X509_STORE_add_cert(store, appleRootCA);
    
    // Verify signature
    BIO *b_receiptPayload = BIO_new(BIO_s_mem());
    int result = PKCS7_verify(p7, NULL, store, NULL, b_receiptPayload, 0);
    
    // Test the result
    if ( result == 1 ) {
        
        // Stream of bytes that represents the receipt
        ASN1_OCTET_STRING *octets = p7->d.sign->contents->d.data;
        
        const unsigned char *p = octets->data;
        const unsigned char *end = p + octets->length;
        
        int type = 0, xclass = 0;
        long length = 0;
        
        ASN1_get_object(&p, &length, &type, &xclass, end - p);
        
        if ( type != V_ASN1_SET ) {
            return;
        }
        
        while (p < end  ) {
            
            // Get the sequence
            ASN1_get_object(&p, &length, &type, &xclass, end - p);
            
            if ( type != V_ASN1_SEQUENCE ) {
                break;
            }
            
            const unsigned char *seq_end = p + length; // The end of this sequence is the current position + the length of the object
            int attr_type = 0, attr_version = 0;
            
            ASN1_get_object(&p, &length, &type, &xclass, seq_end - p);
            
            if ( type == V_ASN1_INTEGER && length == 1 ) {
                attr_type = p[0];
            }
            
            // Move forward by length of object
            p += length;
            
            // Get attribute version (integer)
            ASN1_get_object(&p, &length, &type, &xclass, seq_end - p);
            
            if ( type == V_ASN1_INTEGER && length == 1 ) {
                attr_version = p[0];
                attr_version = attr_version;
            }
            
            // Move forward by length of object
            p += length;
            
            // Get object itself (octet string)
            ASN1_get_object(&p, &length, &type, &xclass, seq_end - p);
            
            switch ( attr_type ) {
                    
                    // Bundle Identifier (
                case 2: {
                    int str_type = 0;
                    long str_length = 0;
                    
                    // We copy p because we want to continue through the data separate from the outer loop
                    const unsigned char *str_p = p;
                    ASN1_get_object(&str_p, &str_length, &str_type, &xclass, seq_end - str_p);
                    
#ifdef DEBUG
#if VTAInAppPurchasesDebug
                    NSLog(@"%i", str_type);
#endif
#endif
                    
                    
                    if ( str_type == V_ASN1_UTF8STRING ) {
                        NSString *string = [[NSString alloc] initWithBytes:str_p length:(NSUInteger)str_length encoding:NSUTF8StringEncoding];
#ifdef DEBUG
#if VTAInAppPurchasesDebug
                        NSLog(@"Product identifier: %@", string);
#endif
#endif
                    }
                    
                    break;
                }
                    
                    // In App Purchases
                case 17: {
                    int seq_type = 0;
                    long seq_length = 0;
                    const unsigned char *str_p = p;
                    
                    // Getting the actual object itself, in this case a set.
                    ASN1_get_object(&str_p, &seq_length, &seq_type, &xclass, seq_end - str_p);
                    
                    // Should be a SET of SEQUENCES
                    if ( seq_type == V_ASN1_SET ) {
                        while ( str_p < seq_end ) {
                            
                            int iapType = 0;
                            int iapVersion = 0;
                            
                            ASN1_get_object(&str_p, &seq_length, &seq_type, &xclass, seq_end - str_p);
                            
                            const unsigned char *inner_seq_end = str_p + seq_length;
                            
                            // Get the type
                            iapType = [self readInteger:&str_p withLength:inner_seq_end - str_p];
                            iapVersion = [self readInteger:&str_p withLength:inner_seq_end - str_p];
                            NSData *data = [self readOctet:&str_p withLength:inner_seq_end - str_p];
                            
                            switch (iapType) {
                                case 1702: {
                                    const uint8_t *s = (const uint8_t*)data.bytes;
                                    NSString *string = [self readString:&s withLength:data.length];
                                    [self.arrayOfPurchasedIAPs addObject:string];
                                    break;
                                }
                            }
                        }
                    }
                    
                    break;
                }
                    
                    // Original purchased version
                case 19: {
                    int str_type = 0;
                    long str_length = 0;
                    const unsigned char *str_p = p;
                    ASN1_get_object(&str_p, &str_length, &str_type, &xclass, seq_end - str_p);
                    
                    if ( str_type == V_ASN1_UTF8STRING ) {
                        NSString *string = [[NSString alloc] initWithBytes:str_p length:(NSUInteger)str_length encoding:NSUTF8StringEncoding];
                        self.originalPurchasedVersion = string;
                    }
                    
                    break;
                }
                default:
                    break;
            }
            
            // Move forward by the length of the object
            p += length;
            
            // If there is anything left in p for this sequence, fast forward through it.
            while (p < seq_end) {
                ASN1_get_object(&p, &length, &type, &xclass, seq_end - p);
                
                p += length;
            }
            
        }
        
    } else {
        // Try refreshing the receipt
        
#ifdef DEBUG
#if VTAInAppPurchasesDebug
        NSLog(@"Verification failed. ");
#endif
#endif
        
        [self.refreshRequest start];
    }
    
}

-(void)validateProductsShouldUseDefaults:(BOOL)useDefaults {
    // 1. Go through the list of purchased products and set the purchased property
    //      1a. If useDefaults is set, use the NSUserDefaults to set the purchased property
    //      1b. Otherwise, set all NSUserDefault products to NO, then set only the ones to YES that are in the list of purchased products
    // verified by receipt
}

/**
 *  STEP 1: Load the products from the plist file. Mark the productsLoading status as loading
 */
-(void)loadProducts {
    if ( !self.remoteURL && !self.localURL ) return;
    
    _productsLoading = VTAInAppPurchaseStatusProductsLoading;
    
    if ( self.remoteURL ) {
        
        NSNumber *secondsSinceLastUpdate = [[NSUserDefaults standardUserDefaults] objectForKey:VTAInAppPurchasesCacheRequestKey];
        
#ifdef DEBUG
#if VTAInAppPurchasesDebug
        NSLog(@"%@", secondsSinceLastUpdate);
        secondsSinceLastUpdate = nil;
#endif
#endif
        
        NSDate *lastUpdate = [NSDate dateWithTimeIntervalSinceReferenceDate:([secondsSinceLastUpdate intValue] + 24 * 60 * 60)];
        NSDate *now = [NSDate date];
        NSURL *cachesURL = [[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] firstObject];
        cachesURL = [cachesURL URLByAppendingPathComponent:@"VTAInAppPurchasesCache.plist"];
        
        NSArray *cachedData = [NSArray arrayWithContentsOfURL:cachesURL];
        
        if ( !secondsSinceLastUpdate || [[now laterDate:lastUpdate] isEqualToDate:now]  ) {
            
#ifdef DEBUG
#if VTAInAppPurchasesDebug
            NSLog(@"Cache not available or expired");
#endif
#endif
            
            NSURLSession *fetchSession = [NSURLSession sharedSession];
            NSURLSessionDataTask *fetchRemotePlistTask = [fetchSession dataTaskWithRequest:[NSURLRequest requestWithURL:self.remoteURL] completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                NSError *readingError;
                
                NSArray *products = cachedData;
                
                if ( error ) {
                    
#ifdef DEBUG
#if VTAInAppPurchasesDebug
                    NSLog(@"Error connection: %@", error.localizedDescription);
#endif
#endif
                    
                    [self productLoadingDidFinishWithError:error];
                    
                } else {
                    
                    id productIDs = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:nil error:&readingError];
                    
                    if ( !readingError && [productIDs isKindOfClass:[NSArray class]]) {
                        
#ifdef DEBUG
#if VTAInAppPurchasesDebug
                        NSLog(@"Products successfully loaded from network");
#endif
#endif
                        
                        products = (NSArray *)productIDs;
                        
                        if ( [products writeToURL:cachesURL atomically:YES] ) {
                            NSTimeInterval interval = [NSDate timeIntervalSinceReferenceDate];
                            [[NSUserDefaults standardUserDefaults] setObject:@(interval) forKey:VTAInAppPurchasesCacheRequestKey];
                        }
                        
                    } else {
#ifdef DEBUG
#if VTAInAppPurchasesDebug
                        NSLog(@"Error reading: %@\n%@", readingError.localizedDescription, readingError.localizedFailureReason);
#endif
#endif
                        [self productLoadingDidFinishWithError:readingError];
                        
                        
                    }
                }
                
                [self setupProductsWithPropertyList:products];
            }];
            [fetchRemotePlistTask resume];
        } else {
            
#ifdef DEBUG
#if VTAInAppPurchasesDebug
            NSLog(@"Loading from cache");
#endif
#endif
            [self setupProductsWithPropertyList:cachedData];
            
        }
        
    } else if ( self.localURL ) {
        
        [self setupProductsWithPropertyList:[NSArray arrayWithContentsOfURL:self.localURL]];
    }
    
}

/**
 *  STEP 2: Extract the products from the plist file and check whether or not non-consumable
 *  products have been purchased. Start the StoreKit request. Mark the productsLoading as listLoaded.
 */
-(void)setupProductsWithPropertyList:(NSArray *)propertyList {
    
#ifdef DEBUG
#if VTAInAppPurchasesDebug
    NSLog(@"%s ", __PRETTY_FUNCTION__);
#endif
#endif
    
    if ( !propertyList ) {
        NSError *error = [NSError errorWithDomain:@"com.voyagetravelapps.VTAInAppPurchases" code:1 userInfo:@{NSLocalizedDescriptionKey : @"Property list was nil"}];
        [self productLoadingDidFinishWithError:error];
        _productsLoading = VTAInAppPurchaseStatusProductListLoadFailed;
    } else {
        // Load the previous purchase information from a pList stored in NSUserDefaults, which is an array of product IDs used to identify
        // if a product has previously been purchased.
        // If it has, we'll set the purchased property on VTAProduct to YES.
        NSArray *arrayOfPurchases = [[NSUserDefaults standardUserDefaults] objectForKey:VTAInAppPurchasesList];
        
        NSMutableArray *array = [NSMutableArray array];
        NSMutableArray *productIDs = [NSMutableArray array];
        
        for ( id dictionary in propertyList ) {
            
            if ( [dictionary isKindOfClass:[NSDictionary class]] ) {
                
                VTAProduct *product = [[VTAProduct alloc] initWithProductDetailDictionary:dictionary];

                // self validateProducts
                for ( NSDictionary *productInfo in arrayOfPurchases ) {
                    if ( [dictionary[@"productIdentifier"] isEqualToString:productInfo[VTAInAppPurchasesListProductNameKey]] ) {
                        product.purchased = YES;
                    }
                }
                // end validations
                
                [array addObject:product];
                [productIDs addObject:product.productIdentifier];
                [self.productLookupDictionary setObject:product forKey:product.productIdentifier];
            }
        }
        
        _productList = [array copy];
        _productsLoading = VTAInAppPurchaseStatusProductListLoaded;
        
        SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:[NSSet setWithArray:productIDs]];
        request.delegate = self;
        [request start];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:VTAInAppPurchasesProductListDidUpdateNotification object:self];
}

/**
 *  STEP 3: Once the delegate has received a response, the products will have been updated with their
 *  SKProduct objects or there will have been some sort of failure. Mark the productsLoading as
 */
-(void)productLoadingDidFinishWithError:(NSError *)error {
    
    if ( self.productList ) {
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    }
    
    NSDictionary *userInfo;
    
    if ( error ) {
        userInfo = @{VTAInAppPurchasesNotificationErrorUserInfoKey : error };
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:VTAInAppPurchasesProductsDidFinishUpdatingNotification object:nil userInfo:userInfo];
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
#ifdef DEBUG
#if VTAInAppPurchasesDebug
        NSLog(@"Can't make payments");
#endif
#endif
        
    }
}

-(void)restoreProducts {
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

// Handling errors
-(void)handleStoreKitError:(NSError *)error forTransaction:(SKPaymentTransaction *)transaction {
    
#ifdef DEBUG
#if VTAInAppPurchasesDebug
    NSLog(@"%s\n%@", __PRETTY_FUNCTION__, [error localizedDescription]);
#endif
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
        
    }
    
    if ( product.consumable || (!product.consumable && product.storageKey) ) {
        
        NSNumber *number = [[NSUserDefaults standardUserDefaults] objectForKey:product.storageKey];
        number = @([number intValue] + [product.productValue intValue]);
        [[NSUserDefaults standardUserDefaults] setObject:number forKey:product.storageKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    NSDictionary *userInfo = @{VTAInAppPurchasesProductsAffectedUserInfoKey : @[product]};
    [[NSNotificationCenter defaultCenter] postNotificationName:VTAInAppPurchasesPurchasesDidCompleteNotification object:self userInfo:userInfo];
    
}

-(void)unlockNonConsumableProduct:(VTAProduct *)product {
    NSArray *purchasedObjects = [[NSUserDefaults standardUserDefaults] objectForKey:VTAInAppPurchasesList];
    
    if ( !purchasedObjects ) {
        purchasedObjects = [NSArray new];
    }
    
    NSMutableDictionary *dictionary = [NSMutableDictionary new];
    [dictionary setObject:product.productIdentifier forKey:VTAInAppPurchasesListProductNameKey];
    
    NSArray *updatedPurchasedObjects = [purchasedObjects arrayByAddingObject:dictionary];
    [[NSUserDefaults standardUserDefaults] setObject:updatedPurchasedObjects forKey:VTAInAppPurchasesList];
    product.purchased = YES;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:VTAInAppPurchasesProductListDidUpdateNotification object:self];
}

#pragma mark - SKProductsRequestDelegate

-(void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    
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
    
    _productsLoading = VTAInAppPurchaseStatusProductsLoaded;
    [self productLoadingDidFinishWithError:nil];
}

#pragma mark - SKRequestDelegate

-(void)requestDidFinish:(SKRequest *)request {
    
    if ( request == self.refreshRequest ) {
        [self validateReceipt];
    }
}

-(void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    if ( request == self.refreshRequest ) {
        
#ifdef DEBUG
#if VTAInAppPurchasesDebug
        NSLog(@"Receipt refresh failed");
#endif
#endif
      
        // Check unlock
        
        
    } else {
        [self productLoadingDidFinishWithError:error];
    }
    
}

#pragma mark - SKPaymentTransactionObserver

-(void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions {
    
    for ( SKPaymentTransaction *transaction in transactions ) {
        switch(transaction.transactionState) {
            case SKPaymentTransactionStatePurchasing: {
                
#ifdef DEBUG
#if VTAInAppPurchasesDebug
                NSLog(@"Purchasing: %@", transaction.payment.productIdentifier);
#endif
#endif
                
                break;
            }
            case SKPaymentTransactionStateFailed: {
                
#ifdef DEBUG
#if VTAInAppPurchasesDebug
                NSLog(@"Failed: %@", transaction.payment.productIdentifier);
#endif
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
#ifdef DEBUG
#if VTAInAppPurchasesDebug
                    NSLog(@"Restore completed: %@", transaction.payment.productIdentifier);
#endif
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
#ifdef DEBUG
#if VTAInAppPurchasesDebug
                    NSLog(@"Purchase completed: %@", transaction.payment.productIdentifier);
#endif
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
                        
#ifdef DEBUG
#if VTAInAppPurchasesDebug
                        NSLog(@"%s Moving from %@ to %@", __PRETTY_FUNCTION__, [contentsPath stringByAppendingPathComponent:path], [[product.localContentURL URLByAppendingPathComponent:path] path]);
#endif
#endif
                        
                        if ( downloadError ) {
                            break;
                        }
                    }
                }
                
                
                
                
                
                if ( downloadError ) {
                    
#ifdef DEBUG
#if VTAInAppPurchasesDebug
                    NSLog(@"%s Failed to move file: %@", __PRETTY_FUNCTION__, downloadError.localizedDescription);
#endif
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
