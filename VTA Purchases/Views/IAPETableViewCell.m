//
//  IAPESTableViewCell.m
//  IAP Example Suite
//
//  Created by Simon Fairbairn on 18/05/2014.
//  Copyright (c) 2014 Voyage Travel Apps. All rights reserved.
//

#import "IAPETableViewCell.h"

@interface IAPETableViewCell ()

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *imageWidth;
@property (nonatomic, weak) IBOutlet UIImageView *thumbnailContainer;

@end

@implementation IAPETableViewCell {
    CGFloat _originalWidth;
}

#pragma mark - Properties 


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
