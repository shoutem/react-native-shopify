
#import "RNShopify.h"
#import "Buy.h"

@implementation RNShopify {
  RCTPromiseResolveBlock _resolve;
  RCTPromiseRejectBlock _reject;
}

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}
RCT_EXPORT_MODULE()

RCT_EXPORT_METHOD(initialize:(NSString *)domain key:(NSString *)key)
{

  self.client = [[BUYClient alloc] initWithShopDomain:domain
                                                     apiKey:key
                                                      appId:@"8"];
}

RCT_EXPORT_METHOD(getShop:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{

  [self.client getShop:^(BUYShop *shop, NSError *error) {
    if (shop && !error) {
      resolve(shop.domain);
    }
    else {
      reject(@"no_shop", @"There was no shop", error);
    }
  }]; 
}

RCT_EXPORT_METHOD(getProducts:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{

   [self.client getProductsPage:1 completion:^(NSArray *products, NSUInteger page, BOOL reachedEnd, NSError *error) {
      if (error == nil && products) {
        NSMutableArray *result = [NSMutableArray array];
        for (BUYProduct *product in products) {
          NSMutableDictionary *dictionary = [product JSONDictionary];

          NSMutableArray *variants = [NSMutableArray array];

          for (BUYProductVariant *variant in product.variants) {
            NSMutableDictionary *variantDictionary = [variant JSONDictionary];

            NSMutableArray *options = [NSMutableArray array];

            for (BUYOptionValue *option in variant.options) {
              [options addObject: [option JSONDictionary]]; 
            }

            variantDictionary[@"options"] = options; 

            [variants addObject: variantDictionary]; 
          }   

          dictionary[@"variants"] = variants; 

          [result addObject: dictionary];
        }
        
        resolve(result);
      }
      else {
        reject(@"no_products", @"There were no products", error);
      }
  }];
}

RCT_EXPORT_METHOD(checkout:(NSArray *)variants resolver:(RCTPromiseResolveBlock)resolve 
  rejecter:(RCTPromiseRejectBlock)reject)
{
  _resolve = resolve;
  _reject = reject;

  BUYModelManager *modelManager = self.client.modelManager;
	BUYCart *cart = [modelManager insertCartWithJSONDictionary:nil];

  for (NSDictionary *dictionary in variants) {
      BUYProductVariant *variant = [[BUYProductVariant alloc] initWithModelManager:modelManager 
        JSONDictionary:dictionary];
     	[cart addVariant:variant];
  }

	BUYCheckout *checkout = [modelManager checkoutWithCart:cart];

  BUYWebCheckoutPaymentProvider *webPaymentProvider = [[BUYWebCheckoutPaymentProvider alloc] initWithClient:self.client];
	webPaymentProvider.delegate = self;
	
  [webPaymentProvider startCheckout:checkout];
}

- (void)paymentProvider:(id<BUYPaymentProvider>)provider wantsControllerPresented:(UIViewController *)controller
{
   UIViewController *rootViewController = [[
      [UIApplication sharedApplication] keyWindow] rootViewController];
	[rootViewController presentViewController:controller animated:YES completion:nil];
}

- (void)paymentProviderWantsControllerDismissed:(id <BUYPaymentProvider>)provider
{
  UIViewController *rootViewController = [[
      [UIApplication sharedApplication] keyWindow] rootViewController];
 [rootViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)paymentProvider:(id<BUYPaymentProvider>)provider didFailCheckoutWithError:(NSError *)error
{
	_reject(@"checkout failed", @"", error);
}

- (void)paymentProviderDidDismissCheckout:(id<BUYPaymentProvider>)provider
{
	_resolve(@"Checkout dismissed");
}

- (void)paymentProvider:(id <BUYPaymentProvider>)provider didCompleteCheckout:(BUYCheckout *)checkout withStatus:(BUYStatus)status
{
    if (status == BUYStatusComplete) {
      _resolve(@"Done!");
    }
    else {
      _resolve(@"Completed checkout with unknown status");
    }
}

@end
  
