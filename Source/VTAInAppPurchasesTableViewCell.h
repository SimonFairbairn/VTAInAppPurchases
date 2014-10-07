//
//  IAPESTableViewCell.h
//  IAP Example Suite
//
//  Created by Simon Fairbairn on 18/05/2014.
//  Copyright (c) 2014 Voyage Travel Apps. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface VTAInAppPurchasesTableViewCell : UITableViewCell

@property (nonatomic, weak) IBOutlet UILabel *titleLabel;
@property (nonatomic, weak) IBOutlet UILabel *priceLabel;
@property (nonatomic, weak) IBOutlet UILabel *statusLabel;
@property (nonatomic, weak) IBOutlet UIProgressView *progressView;

@property (nonatomic, getter = isNonConsumable) BOOL nonConsumable;


-(void)addThumbnailImage:(UIImage *)image animated:(BOOL)animated;

@end
