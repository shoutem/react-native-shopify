#import <React/RCTBridgeModule.h>
#import "Buy.h"

@interface RNShopify : UIViewController <RCTBridgeModule, BUYPaymentProviderDelegate>

@property (nonatomic, strong) BUYClient *client;
@property (nonatomic, strong) BUYCheckout *checkout;
@property (nonatomic, strong) UIViewController *rootViewController;
@property (nonatomic, strong) NSArray *availableShippingRates;

@end

