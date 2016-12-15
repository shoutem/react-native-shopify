
#import "RCTBridgeModule.h"
#import "Buy.h"

@interface RNShopify : UIViewController <RCTBridgeModule, BUYPaymentProviderDelegate>

@property (nonatomic, strong) BUYClient *client;

@end
  
