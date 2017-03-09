// import RCTBridgeModule
#if __has_include(<React/RCTBridgeModule.h>)
#import <React/RCTBridgeModule.h>
#elif __has_include("RCTBridgeModule.h")
#import "RCTBridgeModule.h"
#else
#import "React/RCTBridgeModule.h"   // Required when used as a Pod in a Swift project
#endif

#import "Buy.h"

@interface RNShopify : UIViewController <RCTBridgeModule, BUYPaymentProviderDelegate>

@property (nonatomic, strong) BUYClient *client;
@property (nonatomic, strong) BUYCheckout *checkout;
@property (nonatomic, strong) UIViewController *rootViewController;
@property (nonatomic, strong) NSArray *availableShippingRates;

@end

