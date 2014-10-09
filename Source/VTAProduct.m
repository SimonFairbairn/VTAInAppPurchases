//
//  VTAProduct.m
//  IAP Example Suite
//
//  Created by Simon Fairbairn on 19/06/2014.
//  Copyright (c) 2014 Voyage Travel Apps. All rights reserved.
//

#import "VTAProduct.h"

#define VTAProductDebug 1

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
        NSDictionary *descriptionDictionary = dict[@"longDescription"];
        
        [self objectIsDictionary:dict];
        [self objectIsDictionary:descriptionDictionary];
        
        // Currently only supports English
        _longDescription = descriptionDictionary[@"English"];
        
        [self objectIsString:_longDescription];
        [self objectIsString:_productIdentifier];
        [self objectIsString:_storageKey];
        
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
    return [NSString stringWithFormat:@"%@, %@, %@, %i", self.productIdentifier, self.storageKey, self.productValue, self.consumable ];
}

-(void)loadImageAtLocation:(id)location withCompletionHandler:(void (^)(UIImage *image))completionHandler {

    if ( [location isKindOfClass:[NSString class]] && ![location isEqualToString:@""] ) {
        
        NSString *iconLocation = (NSString *)location;
        NSURL *urlOfIcon = [NSURL URLWithString:iconLocation];
        
        if ( ![urlOfIcon scheme] ) {
            completionHandler([UIImage imageNamed:iconLocation]);
        } else {
            
            NSURL *cachesDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] firstObject];
            NSURL *fileURL = [cachesDirectory URLByAppendingPathComponent:[iconLocation lastPathComponent]];

#ifdef DEBUG
#if VTAProductDebug
            NSLog(@"File URL: %@", fileURL);
            fileURL = nil;
#endif
#endif
            
            UIImage *property = [UIImage imageWithContentsOfFile:[fileURL path]];
            
            if ( property ) {
                completionHandler(property);
            } else {
                
                NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:iconLocation]];
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
