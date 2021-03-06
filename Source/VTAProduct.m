//
//  VTAProduct.m
//  IAP Example Suite
//
//  Created by Simon Fairbairn on 19/06/2014.
//  Copyright (c) 2014 Voyage Travel Apps. All rights reserved.
//

#import "VTAProduct.h"

#ifdef DEBUG
#define VTAProductDebug 0
#endif

NSString * const VTAProductStatusDidChangeNotification = @"VTAProductStatusDidChangeNotification";

@implementation VTAProduct

-(instancetype)initWithProductDetailDictionary:(NSDictionary *)dict {

    if ( self = [super init] ) {
        
        [self objectIsDictionary:dict];
        
        _consumable = [dict[@"consumable"] boolValue];
        _productIdentifier = dict[@"productIdentifier"];
        _productValue = dict[@"productValue"];
        _storageKey = dict[@"storageKey"];
        _hosted = [dict[@"hosted"] boolValue];
        _childProducts = dict[@"childProducts"];
        _productTitle = dict[@"productTitle"];
        _purchased = [dict[@"purchased"] boolValue];
        _maximumChildPurchasesBeforeHiding = dict[@"maxChildren"];
        NSDictionary *descriptionDictionary = dict[@"longDescription"];
        
        [self objectIsDictionary:dict];
        [self objectIsDictionary:descriptionDictionary];
        
        // Currently only supports English
        _longDescription = descriptionDictionary[@"English"];

        [self objectIsArray:_childProducts];
        [self objectIsString:_longDescription];
        [self objectIsString:_productIdentifier];
        [self objectIsString:_storageKey];
        [self objectIsString:_productTitle];
        
        NSString *localPath = dict[@"localContentPath"];
        if ( localPath && ![localPath isEqualToString:@""]) {
            
            if ( _hosted ) {
                _localContentURL = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
                _localContentURL = [_localContentURL URLByAppendingPathComponent:dict[@"localContentPath"] isDirectory:YES];
            } else {
                NSURL *bundleURL = [[NSBundle mainBundle] resourceURL];
                _localContentURL = [bundleURL URLByAppendingPathComponent:dict[@"localContentPath"] isDirectory:YES];
                
            }
        }
        
        if ( [_storageKey isEqualToString:@""] ) {
            _storageKey = nil;
        }
      
        [self loadImageAtLocation:dict[@"productIcon"] withCompletionHandler:^(UIImage *image) {
            if ( image ) {
                _productIcon = image;
                [[NSNotificationCenter defaultCenter] postNotificationName:VTAProductStatusDidChangeNotification object:self userInfo:nil];
            }
        }];
        [self loadImageAtLocation:dict[@"featuredImage"] withCompletionHandler:^(UIImage *image) {
            if ( image ) {
                _productFeaturedImage = image;
                [[NSNotificationCenter defaultCenter] postNotificationName:VTAProductStatusDidChangeNotification object:self userInfo:nil];
                
            }
        }];
     }
    
    return self;
}

-(BOOL)objectIsArray:(id)object {
    if ( object  && ![object isKindOfClass:[NSArray class]] ) {
        [NSException raise:NSInvalidArgumentException format:@"This is not a required NSArray object"];
        return NO;
    }
    return YES;
}


-(BOOL)objectIsDictionary:(id)object {
    if ( object  && ![object isKindOfClass:[NSDictionary class]] ) {
        [NSException raise:NSInvalidArgumentException format:@"This is not a required NSDictionary object"];
        return NO;
    }
    return YES;
}

-(BOOL)objectIsString:(id)object {
    if ( object && ![object isKindOfClass:[NSString class]]) {
        [NSException raise:NSInvalidArgumentException format:@"This is not a required NSString object"];
        return NO;
    }
    return YES;
}

-(NSString *)description {
    return [NSString stringWithFormat:@"%@\n    Storage key: %@\n    Product Value: %@\n    Consumable: %i\n    Purchased: %i", self.productIdentifier, self.storageKey, self.productValue, self.consumable, self.purchased];
}

-(void)loadImageAtLocation:(id)location withCompletionHandler:(void (^)(UIImage *image))completionHandler {

    if ( [location isKindOfClass:[NSString class]] && ![location isEqualToString:@""] ) {
        
        NSString *iconLocation = (NSString *)location;
        NSURL *urlOfIcon = [NSURL URLWithString:iconLocation];
        
        if ( ![urlOfIcon scheme] ) {
            completionHandler([UIImage imageNamed:iconLocation]);
        } else {
            CGFloat scale = [[UIScreen mainScreen] scale];
            
            // Attempt to load image from cache
            NSURL *cachesDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] firstObject];
            
            NSString *fileName = [iconLocation lastPathComponent];
            NSString *fileNameNoExtension = [fileName stringByDeletingPathExtension];
            NSString *fileNameExtension = [fileName pathExtension];
            
            NSString *scaleString = @"";
            if ( scale == 2.0f ) {
                scaleString = @"@2x";
            } else if (scale == 3.0f ) {
                scaleString = @"@3x";
            }
            
            if ( [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad ) {
                scaleString = [scaleString stringByAppendingString:@"~ipad"];
            }
            
            NSString *scaledImage = [[fileNameNoExtension stringByAppendingString:scaleString] stringByAppendingFormat:@".%@", fileNameExtension];
            NSURL *fileURL = [cachesDirectory URLByAppendingPathComponent:scaledImage];
            
            NSString *scaledImageURL = [[iconLocation stringByDeletingLastPathComponent] stringByAppendingPathComponent:scaledImage];
            
#ifdef DEBUG
#if VTAProductDebug
            NSLog(@"Icon location: %@", iconLocation);
            NSLog(@"File URL: %@", fileURL);
            NSLog(@"Scaled Image URL: %@", scaledImageURL);
            fileURL = nil;
#endif
#endif
            NSData *imageData = [NSData dataWithContentsOfURL:fileURL];
            UIImage *property = [UIImage imageWithData:imageData scale:scale];
            
            if ( property ) {
                completionHandler(property);
            } else {
                
                NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:scaledImageURL]];
                NSURLSession *session = [NSURLSession sharedSession];
                
                NSURLSessionDownloadTask *task = [session downloadTaskWithRequest:request completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
                    
                    NSError *copyError;
                    
                    if ( !response ) {
#ifdef DEBUG
#if VTAProductDebug
                        NSLog(@"No response from network: %@", error.localizedDescription);
#endif
#endif
                        return;
                    }
                    
                    if ( !error ) {
                        NSURL *newLocation = [cachesDirectory URLByAppendingPathComponent:[[response URL] lastPathComponent]];
                        
                        [[NSFileManager defaultManager] removeItemAtURL:newLocation error:nil];
                        [[NSFileManager defaultManager] copyItemAtURL:location toURL:newLocation error:&copyError];
                        
#if VTAProductDebug
                        NSLog(@"Copying from %@\nto %@", location, newLocation );
#endif
                        
                        if ( !copyError ) {
                            NSData *data = [NSData dataWithContentsOfURL:newLocation];
                            UIImage *loadedImage = [UIImage imageWithData:data scale:[[UIScreen mainScreen] scale]];
                            dispatch_async(dispatch_get_main_queue(), ^{
                                completionHandler(loadedImage);
                            });
                            
                        } else {
                            
#ifdef DEBUG
#if VTAProductDebug
                            NSLog(@"%@", copyError.localizedDescription);
#endif
#endif
                            
                        }
                    } else {
#ifdef DEBUG
#if VTAProductDebug
                        NSLog(@"%@", error.localizedDescription);
#endif
#endif
                    }
                    

                    
                }];
                
                [task resume];
            }
        }
    }
}



@end
