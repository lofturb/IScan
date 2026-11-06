#import "SCTheme.h"

@implementation SCTheme

+ (UIColor *)colorWithHex:(NSUInteger)hex alpha:(CGFloat)alpha {
    return [UIColor colorWithRed:((hex >> 16) & 0xFF) / 255.0
                           green:((hex >> 8) & 0xFF) / 255.0
                            blue:(hex & 0xFF) / 255.0
                           alpha:alpha];
}

+ (UIColor *)background { return [self colorWithHex:0x0B0D10 alpha:1.0]; }
+ (UIColor *)surface { return [self colorWithHex:0x141821 alpha:1.0]; }
+ (UIColor *)surfaceAlt { return [self colorWithHex:0x1B2230 alpha:1.0]; }
+ (UIColor *)stroke { return [self colorWithHex:0xFFFFFF alpha:0.10]; }
+ (UIColor *)textPrimary { return [self colorWithHex:0xF2F5F9 alpha:1.0]; }
+ (UIColor *)textSecondary { return [self colorWithHex:0x9AA6B8 alpha:1.0]; }
+ (UIColor *)textTertiary { return [self colorWithHex:0x6B7688 alpha:1.0]; }
+ (UIColor *)accent { return [self colorWithHex:0x3B82F6 alpha:1.0]; }
+ (UIColor *)accentSoft { return [self colorWithHex:0x3B82F6 alpha:0.16]; }
+ (UIColor *)success { return [self colorWithHex:0x34D399 alpha:1.0]; }
+ (UIColor *)successSoft { return [self colorWithHex:0x34D399 alpha:0.16]; }
+ (UIColor *)warning { return [self colorWithHex:0xFBBF24 alpha:1.0]; }
+ (UIColor *)danger { return [self colorWithHex:0xF87171 alpha:1.0]; }

+ (UIFont *)titleFont { return [UIFont systemFontOfSize:24.0 weight:UIFontWeightSemibold]; }
+ (UIFont *)headlineFont { return [UIFont systemFontOfSize:18.0 weight:UIFontWeightSemibold]; }
+ (UIFont *)bodyFont { return [UIFont systemFontOfSize:16.0]; }
+ (UIFont *)subheadFont { return [UIFont systemFontOfSize:14.0]; }
+ (UIFont *)captionFont { return [UIFont systemFontOfSize:12.0]; }
+ (UIFont *)tinyFont { return [UIFont systemFontOfSize:11.0]; }
+ (UIFont *)monoFont:(CGFloat)size { return [UIFont fontWithName:@"Menlo" size:size] ?: [UIFont systemFontOfSize:size]; }

+ (UIView *)cardView {
    UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
    view.backgroundColor = [self surface];
    view.layer.cornerRadius = 16.0;
    view.layer.borderWidth = 1.0;
    view.layer.borderColor = [self stroke].CGColor;
    return view;
}

+ (UIView *)tileWithColor:(UIColor *)color size:(CGFloat)size radius:(CGFloat)radius {
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, size, size)];
    view.backgroundColor = color;
    view.layer.cornerRadius = radius;
    return view;
}

+ (UIButton *)buttonWithTitle:(NSString *)title
                   background:(UIColor *)background
                   foreground:(UIColor *)foreground
                         icon:(UIImage *)icon {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.backgroundColor = background;
    button.layer.cornerRadius = 13.0;
    button.titleLabel.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightSemibold];
    button.contentEdgeInsets = UIEdgeInsetsMake(15.0, 18.0, 15.0, 18.0);
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:foreground forState:UIControlStateNormal];
    [button setTitleColor:[foreground colorWithAlphaComponent:0.55]
                 forState:UIControlStateHighlighted];
    [button setTitleColor:[foreground colorWithAlphaComponent:0.4]
                 forState:UIControlStateDisabled];
    button.adjustsImageWhenHighlighted = NO;

    if (icon) {
        [button setImage:icon forState:UIControlStateNormal];
        button.tintColor = foreground;
        button.imageEdgeInsets = UIEdgeInsetsMake(0, -5, 0, 7);
        button.titleEdgeInsets = UIEdgeInsetsMake(0, 5, 0, -7);
    }
    return button;
}

+ (void)toast:(NSString *)message inView:(UIView *)view {
    if (!view || !message.length) { return; }

    const NSInteger kToastTag = 0x5C0FFEE;
    [[view viewWithTag:kToastTag] removeFromSuperview];

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.tag = kToastTag;
    label.text = message;
    label.font = [UIFont systemFontOfSize:14.0 weight:UIFontWeightMedium];
    label.textColor = [self textPrimary];
    label.backgroundColor = [self colorWithHex:0x1F2633 alpha:0.97];
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 2;
    label.layer.cornerRadius = 12.0;
    label.layer.masksToBounds = YES;
    label.layer.borderWidth = 1.0;
    label.layer.borderColor = [self stroke].CGColor;
    label.alpha = 0.0;

    CGSize maxSize = CGSizeMake(view.bounds.size.width - 64.0, 200.0);
    CGSize size = [label sizeThatFits:maxSize];
    CGFloat width = MIN(maxSize.width, MAX(120.0, size.width + 32.0));
    CGFloat height = MAX(44.0, size.height + 20.0);
    label.frame = CGRectMake(roundf((view.bounds.size.width - width) / 2.0),
                             view.bounds.size.height - height - 40.0,
                             width, height);
    label.autoresizingMask = UIViewAutoresizingFlexibleTopMargin |
                             UIViewAutoresizingFlexibleLeftMargin |
                             UIViewAutoresizingFlexibleRightMargin;
    [view addSubview:label];

    label.transform = CGAffineTransformMakeTranslation(0, 10.0);
    [UIView animateWithDuration:0.18
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        label.alpha = 1.0;
        label.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        [UIView animateWithDuration:0.30
                              delay:2.10
                            options:UIViewAnimationOptionCurveEaseIn
                         animations:^{
            label.alpha = 0.0;
            label.transform = CGAffineTransformMakeTranslation(0, 8.0);
        } completion:^(BOOL done) {
            [label removeFromSuperview];
        }];
    }];
}

+ (UILabel *)labelWithText:(NSString *)text
                      font:(UIFont *)font
                     color:(UIColor *)color {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.text = text;
    label.font = font ?: [self bodyFont];
    label.textColor = color ?: [self textPrimary];
    label.numberOfLines = 0;
    label.backgroundColor = [UIColor clearColor];
    return label;
}

+ (void)applyAppearance {
    UINavigationBar *bar = [UINavigationBar appearance];
    bar.barTintColor = [self surface];
    bar.translucent = NO;
    bar.tintColor = [self accent];
    bar.titleTextAttributes = @{
        NSForegroundColorAttributeName: [self textPrimary],
        NSFontAttributeName: [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold]
    };
    if ([bar respondsToSelector:@selector(setBarStyle:)]) {
        bar.barStyle = UIBarStyleBlack;
    }

    UIBarButtonItem *item = [UIBarButtonItem appearance];
    [item setTitleTextAttributes:@{
        NSForegroundColorAttributeName: [self accent],
        NSFontAttributeName: [UIFont systemFontOfSize:16.0]
    } forState:UIControlStateNormal];
}

@end
