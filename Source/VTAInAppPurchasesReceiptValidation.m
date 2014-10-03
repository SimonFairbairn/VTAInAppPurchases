//
//  VTAInAppPurchasesReceiptValidation.m
//  IAP Example Suite
//
//  Created by Simon Fairbairn on 03/10/2014.
//  Copyright (c) 2014 Voyage Travel Apps. All rights reserved.
//

#import "VTAInAppPurchasesReceiptValidation.h"
#import "Bio.h"
#import "pkcs7.h"
#import "x509.h"
#import "sha.h"

#ifdef DEBUG
#define VTAInAppPurchasesReceiptValidationDebug 0
#endif

@implementation VTAInAppPurchasesReceiptValidation

#pragma mark - Properties

-(NSMutableArray *)arrayOfPurchasedIAPs {
    if ( !_arrayOfPurchasedIAPs ) {
        _arrayOfPurchasedIAPs = [NSMutableArray array];
    }
    return _arrayOfPurchasedIAPs;
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

-(BOOL)validateReceipt {
    
#if VTAInAppPurchasesReceiptValidationDebug
    NSLog(@"%s ", __PRETTY_FUNCTION__);
#endif
    
    self.arrayOfPurchasedIAPs = nil;
    
    OpenSSL_add_all_digests();
    
    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    
    if ( ![[NSFileManager defaultManager] fileExistsAtPath:receiptURL.path] ) {
        
#if VTAInAppPurchasesReceiptValidationDebug
        NSLog(@"No receipt.");
#endif
        return NO;
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
        
        // Get the set
        ASN1_get_object(&p, &length, &type, &xclass, end - p);
        
        if ( type != V_ASN1_SET ) {
            return NO;
        }
        
        NSData *hashData;
        NSData *opaqueValueData;
        NSData *bundleIDData;
        
        while (p < end  ) {
            
            // Get the sequence
            ASN1_get_object(&p, &length, &type, &xclass, end - p);
            
            if ( type != V_ASN1_SEQUENCE ) {
                break;
            }
            
            const unsigned char *seq_end = p + length; // The end of this sequence is the current position + the length of the object
            int attr_type = 0, attr_version = 0;
            
            attr_type = [self readInteger:&p withLength:seq_end - p];
            attr_version = [self readInteger:&p withLength:seq_end - p];
            
            NSData *data = [self readOctet:&p withLength:seq_end - p];
            
            switch ( attr_type ) {
                    
                    // Bundle Identifier (
                case 2: {
                    bundleIDData = [data copy];
                    
                    const uint8_t *s = (const uint8_t*)data.bytes;
                    NSString *string = [self readString:&s withLength:data.length];
                    
                    
#if VTAInAppPurchasesReceiptValidationDebug
                    //                    NSLog(@"Product identifier: %@", string);
#endif
                    self.appIdentifier = string;
                    
                    break;
                }
                    
                case 4: {
                    opaqueValueData = [data copy];
                    break;
                }
                case 5: {
                    hashData = [data copy];
                    break;
                }
                    
                    // In App Purchases
                case 17: {
                    
                    int seq_type = 0;
                    long seq_length = 0;
                    const unsigned char *str_p = data.bytes;
                    
                    // Getting the actual object itself, in this case a set.
                    ASN1_get_object(&str_p, &seq_length, &seq_type, &xclass, seq_end - str_p);
                    
                    const unsigned char *inner_seq_end = str_p + seq_length;
                    
                    // Should be a SET of SEQUENCES
                    if ( seq_type == V_ASN1_SET ) {
                        
                        while ( str_p < inner_seq_end ) {
                            
                            long inner_seq_length = 0;
                            ASN1_get_object(&str_p, &inner_seq_length, &type, &xclass, seq_end - str_p);
                            
                            int iapType = [self readInteger:&str_p withLength:inner_seq_end - str_p];
                            [self readInteger:&str_p withLength:inner_seq_end - str_p];
                            
                            NSData *data = [self readOctet:&str_p withLength:inner_seq_end - str_p];
                            
                            switch (iapType) {
                                case 1702: {
                                    const uint8_t *s = (const uint8_t*)data.bytes;
                                    NSString *string = [self readString:&s withLength:data.length];
                                    
#if VTAInAppPurchasesReceiptValidationDebug
                                    //                                    NSLog(@"IAP Purchase: %@", string);
#endif
                                    
                                    [self.arrayOfPurchasedIAPs addObject:string];
                                    break;
                                }
                            }
                        }
                    }
                    str_p += seq_length;
                    
                    break;
                }
                    
                    // Original purchased version
                case 19: {
                    const uint8_t *s = (const uint8_t*)data.bytes;
                    NSString *string = [self readString:&s withLength:data.length];
                    self.originalPurchasedVersion = string;
                    
                    
#if VTAInAppPurchasesReceiptValidationDebug
                    //                    NSLog(@"Original Version: %@", string);
#endif
                    
                    break;
                }
                default:
                    break;
            }
            
            // Move forward by the length of the object
            //            p += length;
            
            // If there is anything left in p for this sequence, fast forward through it.
            while (p < seq_end) {
                ASN1_get_object(&p, &length, &type, &xclass, seq_end - p);
                
                p += length;
            }
            
        }
        
        // TODO: Figure out why the hash is longer
        
        NSUUID *uuid = [[UIDevice currentDevice] identifierForVendor];
        unsigned char uuidBytes[16];
        [uuid getUUIDBytes:uuidBytes];
        
        NSMutableData *data = [NSMutableData data];
        [data appendBytes:uuidBytes length:sizeof(uuidBytes)];
        [data appendData:opaqueValueData];
        //         [data appendData:bundleIDData];
        
        NSMutableData *expectedHash = [NSMutableData dataWithLength:SHA_DIGEST_LENGTH];
        SHA1((const uint8_t*)data.bytes, data.length, (uint8_t*)expectedHash.mutableBytes);
        
        if ( [expectedHash isEqualToData:hashData] ) {
            
#if VTAInAppPurchasesReceiptValidationDebug
            NSLog(@"Matches");
#endif
            
        } else {
            
#if VTAInAppPurchasesReceiptValidationDebug
            NSLog(@"No match");
#endif
            
        }
        
        return YES;
    }    
    return NO;
}




@end
