//
//  IAPESDetailVC.m
//  IAP Example Suite
//
//  Created by Simon Fairbairn on 18/05/2014.
//  Copyright (c) 2014 Voyage Travel Apps. All rights reserved.
//

#import <StoreKit/StoreKit.h>

#import "VTAInAppPurchasesDetailVC.h"
#import "VTAInAppPurchases.h"
#import "VTAProduct.h"

@interface VTAInAppPurchasesDetailViewController ()

@property (nonatomic, weak) IBOutlet UILabel *titleLabel;
@property (nonatomic, weak) IBOutlet UILabel *priceLabel;
@property (nonatomic, weak) IBOutlet UITextView *descriptionField;
@property (nonatomic, weak) IBOutlet UIButton *buyButton;
@property (weak, nonatomic) IBOutlet UIImageView *featuredImage;

@property (nonatomic, strong) NSNumberFormatter *priceFormatter;

@property (nonatomic, weak) IBOutlet UIProgressView *progressView;
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;

@property (weak, nonatomic) IBOutlet UIButton *pauseButton;
@property (weak, nonatomic) IBOutlet UIButton *resumeButton;
@property (weak, nonatomic) IBOutlet UIButton *cancelButton;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *imageHeight;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *textviewHeight;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *purchaseIndicator;

@end

@implementation VTAInAppPurchasesDetailViewController

#pragma mark - Properties

-(NSNumberFormatter *) priceFormatter {
    if ( !_priceFormatter ) {
        _priceFormatter = [[NSNumberFormatter alloc] init];
        _priceFormatter.formatterBehavior = NSNumberFormatterBehavior10_4;
        [_priceFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
    }
    return _priceFormatter;
}

#pragma mark - View Lifecycle

-(void)viewDidLoad {
    [super viewDidLoad];
    
    [self.priceFormatter setLocale:self.product.product.priceLocale];
    
    self.titleLabel.text = self.product.product.localizedTitle;
    self.priceLabel.text = [self.priceFormatter stringFromNumber:self.product.product.price];
    self.descriptionField.text = self.product.product.localizedDescription;

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updatePurchase:) name:VTAInAppPurchasesPurchasesDidCompleteNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateDownload:) name:VTAInAppPurchasesProductDownloadStatusDidChangeNotification object:nil];
    
}

-(void)viewWillAppear:(BOOL)animated {
    
    [super viewWillAppear:animated];
    
    if ( self.product.purchaseInProgress ) {
        self.buyButton.enabled = NO;
        [self.purchaseIndicator startAnimating];
    }
    
    if ( !self.product.consumable && self.product.purchased ) {
        self.buyButton.enabled = NO;
        self.statusLabel.text = @"Purchased";
        self.statusLabel.hidden = NO;
    }
    
    if ( self.product.productFeaturedImage ) {
        self.imageHeight.constant = 150.0f;
        self.featuredImage.image = self.product.productFeaturedImage;
    }
    
    [self refresh];
    
    CGSize textViewSize = [self.descriptionField sizeThatFits:CGSizeMake(self.descriptionField.frame.size.width, FLT_MAX)];
                           
    self.textviewHeight.constant = textViewSize.height;
    
}

-(void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void)refresh {

}

-(void)completePurchase {
    
    if ( self.product.consumable || !self.product.purchased ) {
        self.buyButton.enabled = YES;
    }

    [self.purchaseIndicator stopAnimating];
    self.statusLabel.hidden = NO;
    
    if ( self.product.consumable ) {
        [UIView animateWithDuration:0.5 delay:1.0 options:0 animations:^{
            self.statusLabel.alpha = 0.0f;
        } completion:^(BOOL finished) {
            self.statusLabel.alpha = 1.0f;
            self.statusLabel.hidden = YES;
        }];
    }
}

#pragma mark - Actions

-(IBAction)buyProduct:(id)sender {

    self.buyButton.enabled = NO;
    [self.purchaseIndicator startAnimating];
    [[VTAInAppPurchases sharedInstance] purchaseProduct:self.product];
    
    if ( self.product.hosted ) {
        self.progressView.hidden = NO;
        self.statusLabel.alpha = 1.0f;
        self.statusLabel.text = @"Downloading";
    }
}


#pragma mark - Notifications

-(void)updateStatus:(NSNotification *)note {
    
}

-(void)updateDownload:(NSNotification *)note {
    VTAProduct *product = [[note.userInfo objectForKey:VTAInAppPurchasesProductsAffectedUserInfoKey] firstObject];
    
    self.progressView.progress = product.progress;

    if ( !product.purchaseInProgress ) {
        if ( [note.userInfo objectForKey:VTAInAppPurchasesNotificationErrorUserInfoKey] ) {
            self.statusLabel.text = @"Error downloading";
        } else {
            self.statusLabel.text = @"Purchased";
        }
        self.progressView.hidden = YES;
        [self completePurchase];
    }
}


#pragma mark - VTAInAppPurchases Delegate

-(void)updatePurchase:(NSNotification *)note {
    VTAProduct *product = [[note.userInfo objectForKey:VTAInAppPurchasesProductsAffectedUserInfoKey] firstObject];
    NSError *error = [note.userInfo objectForKey:VTAInAppPurchasesNotificationErrorUserInfoKey];
    
    if ( error ) {
        self.statusLabel.text = @"Purchase failed";
        
        [self completePurchase];
        
    } else if ( product ) {
        
        self.statusLabel.text = @"Purchased";
        
        [self completePurchase];
        
    }
}



@end
