//
//  IAPESDetailVC.h
//  IAP Example Suite
//
//  Created by Simon Fairbairn on 18/05/2014.
//  Copyright (c) 2014 Voyage Travel Apps. All rights reserved.
//

#import <UIKit/UIKit.h>

@class VTAProduct;

@interface VTAInAppPurchasesDetailViewController : UIViewController

@property (nonatomic, strong) VTAProduct *product;
@property (nonatomic, strong) VTAProduct *secondProduct;

@property (nonatomic, weak) IBOutlet UILabel *titleLabel;
@property (nonatomic, weak) IBOutlet UILabel *priceLabel;
@property (nonatomic, weak) IBOutlet UITextView *descriptionField;
@property (nonatomic, weak) IBOutlet UIButton *buyButton;
@property (nonatomic, weak) IBOutlet UIImageView *featuredImage;

@property (nonatomic, weak) IBOutlet UIProgressView *progressView;
@property (nonatomic, weak) IBOutlet UILabel *statusLabel;

@property (nonatomic, weak) IBOutlet UIButton *pauseButton;
@property (nonatomic, weak) IBOutlet UIButton *resumeButton;
@property (nonatomic, weak) IBOutlet UIButton *cancelButton;

@property (nonatomic, weak) IBOutlet NSLayoutConstraint *imageHeight;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *textviewHeight;
@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *purchaseIndicator;

// Secondary product

@property (nonatomic, weak) IBOutlet UILabel *secondTitleLabel;
@property (nonatomic, weak) IBOutlet UILabel *secondPriceLabel;
@property (nonatomic, weak) IBOutlet UITextView *secondDescriptionField;
@property (nonatomic, weak) IBOutlet UIButton *secondBuyButton;
@property (nonatomic, weak) IBOutlet UIImageView *secondFeaturedImage;

@property (nonatomic, weak) IBOutlet UIProgressView *secondProgressView;
@property (nonatomic, weak) IBOutlet UILabel *secondStatusLabel;

@property (nonatomic, weak) IBOutlet NSLayoutConstraint *secondImageHeight;
@property (nonatomic, weak) IBOutlet NSLayoutConstraint *secondTextviewHeight;
@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *secondPurchaseIndicator;

-(void)resizeDescriptionField;

@end
