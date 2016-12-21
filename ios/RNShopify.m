
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
    //Application ID is always 8, as stated in official documentation from Shopify
    self.client = [[BUYClient alloc] initWithShopDomain:domain
                                                 apiKey:key
                                                  appId:@"8"];
}

RCT_EXPORT_METHOD(getShop:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    
    [self.client getShop:^(BUYShop *shop, NSError *error) {
        if (shop && !error) {
            resolve(shop);
        } else {
            reject([NSString stringWithFormat: @"%lu", (long)error.code], error.localizedDescription, error);
        }
    }];
}

RCT_EXPORT_METHOD(getCollections:(NSUInteger)page resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    
    [self.client getCollectionsPage:page completion:^(NSArray<BUYCollection *> *collections, NSUInteger page, BOOL reachedEnd, NSError *error) {
        if (collections && !error) {
            NSMutableArray *collectionDictionaries = [NSMutableArray array];
            
            for (BUYCollection *collection in collections) {
                [collectionDictionaries addObject: @{@"title":collection.title,@"id":collection.identifier}];
            }
            resolve(collectionDictionaries);
        } else {
            reject([NSString stringWithFormat: @"%lu", (long)error.code], error.localizedDescription, error);
        }
    }];
}

RCT_EXPORT_METHOD(getProductTags:(NSUInteger)page resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    
    [self.client getProductTagsPage:page completion:^(NSArray<NSString *> *tags, NSUInteger page, BOOL reachedEnd, NSError *error) {
        if (tags && !error) {
            resolve(tags);
        } else {
            reject([NSString stringWithFormat: @"%lu", (long)error.code], error.localizedDescription, error);
        }
    }];
}


RCT_EXPORT_METHOD(getProducts:(NSUInteger)page resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    
    [self.client getProductsPage:page completion:^(NSArray<BUYProduct *> *products, NSUInteger page, BOOL reachedEnd, NSError *error) {
        if (products && !error) {
            resolve([self getDictionariesForProducts:products]);
        } else {
            reject([NSString stringWithFormat: @"%lu", (long)error.code], error.localizedDescription, error);
        }
    }];
}

RCT_EXPORT_METHOD(getProductsWithTags:(NSUInteger)page tags:(NSArray<NSString *> *)tags resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    
    [self.client getProductsByTags:tags page:page completion:^(NSArray<BUYProduct *> *products, NSError *error) {
        if (products && !error) {
            resolve([self getDictionariesForProducts:products]);
        } else {
            reject([NSString stringWithFormat: @"%lu", (long)error.code], error.localizedDescription, error);
        }
    }];
}

RCT_EXPORT_METHOD(getProductsWithTagsForCollection:(NSUInteger)page collectionId:(nonnull NSNumber *)collectionId tags:(NSArray<NSString *> *)tags resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    
    [self.client getProductsPage:page inCollection:collectionId withTags:tags sortOrder:BUYCollectionSortCollectionDefault completion:^(NSArray<BUYProduct *> *products, NSUInteger page, BOOL reachedEnd, NSError *error) {
        
        if (products && !error) {
            resolve([self getDictionariesForProducts:products]);
        } else {
            reject([NSString stringWithFormat: @"%lu", (long)error.code], error.localizedDescription, error);
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
    
    [self.client createCheckout:checkout completion:^(BUYCheckout *checkout, NSError *error) {
        if (error == nil && checkout) {
            BUYWebCheckoutPaymentProvider *webPaymentProvider = [[BUYWebCheckoutPaymentProvider alloc] initWithClient:self.client];
            webPaymentProvider.delegate = self;
            
            [webPaymentProvider startCheckout:checkout];
        } else {
            reject([NSString stringWithFormat: @"%lu", (long)error.code], error.localizedDescription, error);
        }
    }];
}

#pragma mark - BUYPaymentProvider delegate implementation -

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

#pragma mark - Helpers -

- (NSArray *) getDictionariesForProducts:(NSArray<BUYProduct *> *)products {
    NSMutableArray *result = [NSMutableArray array];
    for (BUYProduct *product in products) {
        NSMutableDictionary *productDictionary = [[product JSONDictionary] mutableCopy];
        
        NSMutableArray *variants = [NSMutableArray array];
        
        for (BUYProductVariant *variant in product.variants) {
            NSMutableDictionary *variantDictionary = [[variant JSONDictionary] mutableCopy];
            
            NSMutableArray *options = [NSMutableArray array];
            
            for (BUYOptionValue *option in variant.options) {
                [options addObject: [option JSONDictionary]];
            }
            
            variantDictionary[@"options"] = options;
            
            [variants addObject: variantDictionary];
        }
        
        productDictionary[@"variants"] = variants;
        
        [result addObject: productDictionary];
    }
    
    return result;
}

@end
