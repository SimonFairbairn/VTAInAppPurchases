//
//  IAPESTableViewCell.m
//  IAP Example Suite
//
//  Created by Simon Fairbairn on 18/05/2014.
//  Copyright (c) 2014 Voyage Travel Apps. All rights reserved.
//

#import "VTAInAppPurchasesTableViewCell.h"

#ifdef DEBUG
#define debugCells 1
#endif

NSString * const VTAInAppPurchasesTableViewCellIdentifier = @"VTAInAppPurchasesTableViewCellIdentifier";

@interface VTAInAppPurchasesTableViewCell ()

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *progressBarMargin;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *imageWidth;
@property (nonatomic, weak) IBOutlet UIImageView *thumbnailContainer;

@end

@implementation VTAInAppPurchasesTableViewCell {
    CGFloat _originalWidth;
}

#pragma mark - Properties 

-(void)setHideProgressBar:(BOOL)hideProgressBar {
    _hideProgressBar = hideProgressBar;
    self.progressBarMargin.constant = (_hideProgressBar) ? 0.0f : 10.0f;
    [self layoutIfNeeded];
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)awakeFromNib
{
    // Initialization code
    [self setup];
}

-(void)setup {
    _originalWidth = self.imageWidth.constant;
    self.imageWidth.constant = 0.0f;
    self.progressView.progress = 0.0f;
    
#if debugCells
    _statusLabel.backgroundColor = [UIColor redColor];
    _priceLabel.backgroundColor = [UIColor lightGrayColor];
    _titleLabel.backgroundColor = [UIColor greenColor];
#endif
}

-(void)addThumbnailImage:(UIImage *)image animated:(BOOL)animated {
    
    NSTimeInterval time = (animated) ? 0.5 : 0.0f;
    
    if ( !self.thumbnailContainer.image ) {
        self.thumbnailContainer.image = image;
    }
    
    [UIView animateWithDuration:time animations:^{
        self.imageWidth.constant = (image) ? _originalWidth : 0.0f;
        [self layoutIfNeeded];
    } completion:^(BOOL finished) {
        self.thumbnailContainer.image = image;
    }];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
