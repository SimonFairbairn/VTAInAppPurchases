//
//  VTAProduct.m
//  IAP Example Suite
//
//  Created by Simon Fairbairn on 19/06/2014.
//  Copyright (c) 2014 Voyage Travel Apps. All rights reserved.
//

#import "VTAProduct.h"

NSString * const VTAProductStatusDidChangeNotification = @"VTAProductStatusDidChangeNotification";

@implementation VTAProduct

-(instancetype)initWithProductDetailDictionary:(NSDictionary *)dict {

    if ( self = [super init] ) {
        
        _consumable = [dict[@"consumable"] boolValue];
        _productIdentifier = dict[@"productIdentifier"];
        _productValue = dict[@"productValue"];
        _storageKey = dict[@"storageKey"];
        _hosted = [dict[@"hosted"] boolValue];
        
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
            NSLog(@"%@", fileURL);
            fileURL = nil;
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
                        NSLog(@"No response from network: %@", error.localizedDescription);
#endif
                        return;
                    }
                    
                    if ( !error ) {
                        NSURL *newLocation = [cachesDirectory URLByAppendingPathComponent:[[response URL] lastPathComponent]];
                        
                        [[NSFileManager defaultManager] removeItemAtURL:newLocation error:nil];
                        [[NSFileManager defaultManager] copyItemAtURL:location toURL:newLocation error:&copyError];
                        
                        if ( !copyError ) {
                            UIImage *loadedImage = [UIImage imageWithContentsOfFile:[newLocation path]];
                            dispatch_async(dispatch_get_main_queue(), ^{
                                completionHandler(loadedImage);
                            });
                            
                        } else {
                            
#ifdef DEBUG
                            NSLog(@"%@", copyError.localizedDescription);
#endif
                            
                        }
                    } else {
#ifdef DEBUG
                        NSLog(@"%@", error.localizedDescription);
#endif
                    }
                    

                    
                }];
                
                [task resume];
            }
        }
    }
}



@end
