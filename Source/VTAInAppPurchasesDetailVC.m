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

@property (nonatomic, strong) NSNumberFormatter *priceFormatter;

@end

@implementation VTAInAppPurchasesDetailViewController {
    BOOL _isSecondProduct;
}

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
    
    if ( self.product.longDescription ) {
        self.descriptionField.text = self.product.longDescription;
    } else {
        self.descriptionField.text = self.product.product.localizedDescription;
    }

    if ( self.secondProduct ) {
        self.secondTitleLabel.text = self.secondProduct.product.localizedTitle;
        self.secondPriceLabel.text = [self.priceFormatter stringFromNumber:self.secondProduct.product.price];
        if ( self.secondProduct.longDescription ) {
            self.secondDescriptionField.text = self.secondProduct.longDescription;
        } else {
            self.secondDescriptionField.text = self.secondProduct.product.localizedDescription;
        }
    } else {
        self.secondTitleLabel.text = nil;
        self.secondPriceLabel.text = nil;
        self.secondDescriptionField.text = nil;
        self.secondBuyButton.hidden = YES;
    }
    
    if ( self.delegate && [self.delegate respondsToSelector:@selector(configureVTAInAppPurchasesDetailViewController:)] ) {
        [self.delegate configureVTAInAppPurchasesDetailViewController:self];
    }
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updatePurchase:) name:VTAInAppPurchasesPurchasesDidCompleteNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateDownload:) name:VTAInAppPurchasesProductDownloadStatusDidChangeNotification object:nil];
}

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if ( self.product.purchased ) {
        self.buyButton.enabled = NO;
    }
    
    if ( self.product.purchaseInProgress ) {
        self.buyButton.enabled = NO;
        [self.purchaseIndicator startAnimating];
    }
    
    if ( !self.product.consumable && self.product.purchased ) {
        self.buyButton.enabled = NO;
        self.statusLabel.text = NSLocalizedString(@"Purchased", nil);
        self.statusLabel.hidden = NO;
    }
    
    if ( self.product.productFeaturedImage ) {
        self.imageHeight.constant = 150.0f;
        self.featuredImage.image = self.product.productFeaturedImage;
    }
    
    [self refresh];
    [self resizeDescriptionField];
}

-(void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Methods

-(void)resizeDescriptionField {
    [self.descriptionField sizeToFit];
    [self.descriptionField layoutIfNeeded];
    [self.secondDescriptionField sizeToFit];
    [self.descriptionField layoutIfNeeded];
}

-(void)refresh {

}

-(void)completePurchase {
    
    VTAProduct *product = ( _isSecondProduct ) ? self.secondProduct : self.product;
    UIActivityIndicatorView *indicator = ( _isSecondProduct ) ? self.secondPurchaseIndicator : self.purchaseIndicator;
    UILabel *label = ( _isSecondProduct ) ? nil : self.statusLabel;
    UIProgressView *progresView = ( _isSecondProduct ) ? self.secondProgressView : self.progressView;
    
    if ( self.product.consumable || !self.product.purchased ) {
        self.buyButton.enabled = YES;
    }
    if ( self.secondProduct.consumable || !self.secondProduct.purchased ) {
        self.secondBuyButton.enabled = YES;
    }

    [indicator stopAnimating];
    label.hidden = NO;
    progresView.hidden = YES;
    
    if ( self.delegate && [self.delegate respondsToSelector:@selector(vtaInAppPurchasesDetailViewController:productWasPurchased:)] ) {
        if ( self.product.purchased ) {
            [self.delegate vtaInAppPurchasesDetailViewController:self productWasPurchased:product];
        }
    }
    
    if ( product.consumable ) {
        [UIView animateWithDuration:0.5 delay:1.0 options:0 animations:^{
            label.alpha = 0.0f;
        } completion:^(BOOL finished) {
            label.alpha = 1.0f;
            label.hidden = YES;
        }];
    }
}

#pragma mark - Actions

-(IBAction)buyProduct:(id)sender {
    self.buyButton.enabled = NO;
    self.secondBuyButton.enabled = NO;

    _isSecondProduct = NO;
    if ( sender == self.secondBuyButton) {
        _isSecondProduct = YES;
    }
    
    UIActivityIndicatorView *indicator = ( _isSecondProduct ) ? self.secondPurchaseIndicator : self.purchaseIndicator;
    VTAProduct *product = ( _isSecondProduct ) ? self.secondProduct : self.product;
    UIProgressView *progressView = (_isSecondProduct ) ? self.secondProgressView : self.progressView;
    UILabel *statusLabel = (_isSecondProduct ) ? nil : self.statusLabel;
    
    [indicator startAnimating];
    [[VTAInAppPurchases sharedInstance] purchaseProduct:product];
    
    if ( product.hosted ) {
        progressView.hidden = NO;
        statusLabel.alpha = 1.0f;
        statusLabel.text = NSLocalizedString(@"Downloading", nil);
    }
}


#pragma mark - Notifications

-(void)updateStatus:(NSNotification *)note {
    
}

-(void)updateDownload:(NSNotification *)note {
    VTAProduct *product = [[note.userInfo objectForKey:VTAInAppPurchasesProductsAffectedUserInfoKey] firstObject];
    
    UIProgressView *progressView = (_isSecondProduct ) ? self.secondProgressView : self.progressView;
    UILabel *statusLabel = ( _isSecondProduct ) ? nil : self.statusLabel;
    
    progressView.progress = product.progress;

    if ( !product.purchaseInProgress ) {
        if ( [note.userInfo objectForKey:VTAInAppPurchasesNotificationErrorUserInfoKey] ) {
            statusLabel.text = NSLocalizedString(@"Error downloading", nil);
        } else {
            statusLabel.text = NSLocalizedString(@"Purchased", nil);
        }
        progressView.hidden = YES;
        [self completePurchase];
    }
}

#pragma mark - VTAInAppPurchases Delegate

-(void)updatePurchase:(NSNotification *)note {
    VTAProduct *product = [[note.userInfo objectForKey:VTAInAppPurchasesProductsAffectedUserInfoKey] firstObject];
    NSError *error = [note.userInfo objectForKey:VTAInAppPurchasesNotificationErrorUserInfoKey];
    
    UILabel *statusLabel =  ( _isSecondProduct ) ? nil : self.statusLabel;
    
    if ( error ) {
        
        if ( [error.domain isEqualToString:VTAInAppPurchasesErrorDomain] && error.code == VTAInAppPurchasesErrorCodeCannotMakePayments ) {
            [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Cannot make payments", nil) message:NSLocalizedString(@"This Apple ID is unable to make payments to the App Store. Please check your payment information.", nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", nil) otherButtonTitles: nil] show];
        }
        
        statusLabel.text = NSLocalizedString(@"Purchase failed", nil);
        [self completePurchase];
    } else if ( product ) {
        statusLabel.text = NSLocalizedString(@"Purchased", nil);
        [self completePurchase];
    }
}

@end
