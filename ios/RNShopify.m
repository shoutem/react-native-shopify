#import "RNShopify.h"
#import "Buy.h"

@implementation RNShopify {
    RCTPromiseResolveBlock _resolve;
    RCTPromiseRejectBlock _reject;
}

+ (BOOL)requiresMainQueueSetup
{
    return YES;
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
        if (error) {
            return reject([NSString stringWithFormat: @"%lu", (long)error.code], error.localizedDescription, error);
        }

        resolve([shop JSONDictionary]);
    }];
}

RCT_EXPORT_METHOD(getCollections:(NSUInteger)page resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    [self.client getCollectionsPage:page completion:^(NSArray<BUYCollection *> *collections, NSUInteger page, BOOL reachedEnd, NSError *error) {
        if (error) {
            return reject([NSString stringWithFormat: @"%lu", (long)error.code], error.localizedDescription, error);
        }

        resolve([self getDictionariesForCollections:collections]);
    }];
}

RCT_EXPORT_METHOD(getProductTags:(NSUInteger)page resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    [self.client getProductTagsPage:page completion:^(NSArray<NSString *> *tags, NSUInteger page, BOOL reachedEnd, NSError *error) {
        if (error) {
            return reject([NSString stringWithFormat: @"%lu", (long)error.code], error.localizedDescription, error);
        }

        resolve(tags);
    }];
}

RCT_EXPORT_METHOD(getProductsPage:(NSUInteger)page resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    [self.client getProductsPage:page completion:^(NSArray<BUYProduct *> *products, NSUInteger page, BOOL reachedEnd, NSError *error) {
        if (error) {
            return reject([NSString stringWithFormat: @"%lu", (long)error.code], error.localizedDescription, error);
        }

        resolve([self getDictionariesForProducts:products]);
    }];
}

RCT_EXPORT_METHOD(getProductsWithTags:(NSUInteger)page tags:(NSArray<NSString *> *)tags resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    [self.client getProductsByTags:tags page:page completion:^(NSArray<BUYProduct *> *products, NSError *error) {
        if (error) {
            return reject([NSString stringWithFormat: @"%lu", (long)error.code], error.localizedDescription, error);
        }

        resolve([self getDictionariesForProducts:products]);
    }];
}

RCT_EXPORT_METHOD(getProductsWithTagsForCollection:(NSUInteger)page collectionId:(nonnull NSNumber *)collectionId tags:(NSArray<NSString *> *)tags resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    [self.client getProductsPage:page inCollection:collectionId withTags:tags sortOrder:BUYCollectionSortCollectionDefault completion:^(NSArray<BUYProduct *> *products, NSUInteger page, BOOL reachedEnd, NSError *error) {
        if (error) {
            return reject([NSString stringWithFormat: @"%lu", (long)error.code], error.localizedDescription, error);
        }

        resolve([self getDictionariesForProducts:products]);
    }];
}

RCT_EXPORT_METHOD(webCheckout:(NSArray *)cart resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    _resolve = resolve;
    _reject = reject;

    BUYCheckout *checkout = [self createCheckoutFromCart:cart];

    [self.client createCheckout:checkout completion:^(BUYCheckout *checkout, NSError *error) {
        if (error) {
            return reject([NSString stringWithFormat: @"%lu", (long)error.code], error.localizedDescription, error);
        }

        BUYWebCheckoutPaymentProvider *webPaymentProvider = [[BUYWebCheckoutPaymentProvider alloc] initWithClient:self.client];
        webPaymentProvider.delegate = self;

        [webPaymentProvider startCheckout:checkout];
    }];
}

RCT_EXPORT_METHOD(checkout:(NSArray *)cart resolver:(RCTPromiseResolveBlock)resolve
                rejecter:(RCTPromiseRejectBlock)reject)
{
    BUYCheckout *checkout = [self createCheckoutFromCart:cart];

    [self.client createCheckout:checkout completion:^(BUYCheckout *checkout, NSError *error) {
        if (error) {
            return reject([NSString stringWithFormat: @"%lu", (long)error.code],
                [self getJsonFromError:error], error);
        }

        self.checkout = checkout;
        resolve(@YES);
    }];
}

RCT_EXPORT_METHOD(setCustomerInformation:(NSString *)email address:(NSDictionary *)addressDictionary
                resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    BUYAddress *address = [self.client.modelManager insertAddressWithJSONDictionary:addressDictionary];
    self.checkout.shippingAddress = address;
    self.checkout.billingAddress = address;
    self.checkout.email = email;

    [self.client updateCheckout:self.checkout completion:^(BUYCheckout *checkout, NSError *error) {
        if (error) {
            return reject([NSString stringWithFormat: @"%lu", (long)error.code],
                [self getJsonFromError:error], error);
        }

        self.checkout = checkout;
        resolve(@YES);
    }];
}

RCT_EXPORT_METHOD(getShippingRates:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    [self.client getShippingRatesForCheckoutWithToken:self.checkout.token completion:^(NSArray<BUYShippingRate *> *shippingRates, BUYStatus status, NSError *error) {
        if (error) {
            return reject([NSString stringWithFormat: @"%lu", (long)error.code], error.localizedDescription, error);
        }

        self.availableShippingRates = shippingRates;

        NSMutableArray *result = [NSMutableArray array];

        for (BUYShippingRate *shippingRate in shippingRates) {
            NSMutableDictionary *shippingRateDictionary = [[shippingRate JSONDictionary] mutableCopy];

            if ([shippingRate.deliveryRange count]) {
                double firstDateInMiliseconds = [shippingRate.deliveryRange[0] timeIntervalSince1970] * 1000;
                double secondDateInMiliseconds = [[shippingRate.deliveryRange lastObject] timeIntervalSince1970] * 1000;

                NSMutableArray *deliveryRange = [NSMutableArray array];
                [deliveryRange addObject:[NSNumber numberWithDouble:firstDateInMiliseconds]];
                [deliveryRange addObject:[NSNumber numberWithDouble:secondDateInMiliseconds]];

                shippingRateDictionary[@"deliveryRange"] = deliveryRange;
            }
            [result addObject: shippingRateDictionary];
        }
        resolve(result);
    }];
}

RCT_EXPORT_METHOD(selectShippingRate:(NSUInteger)shippingRateIndex resolver:(RCTPromiseResolveBlock)resolve
                rejecter:(RCTPromiseRejectBlock)reject)
{
    self.checkout.shippingRate = self.availableShippingRates[shippingRateIndex];

    [self.client updateCheckout:self.checkout completion:^(BUYCheckout *checkout, NSError *error) {
        if (error) {
            return reject([NSString stringWithFormat: @"%lu", (long)error.code], error.localizedDescription, error);
        }

        self.checkout = checkout;
        resolve(@YES);
    }];
}

RCT_EXPORT_METHOD(completeCheckout:(NSDictionary *)cardDictionary resolver:(RCTPromiseResolveBlock)resolve
                rejecter:(RCTPromiseRejectBlock)reject)
{
    BUYCreditCard *creditCard = [[BUYCreditCard alloc] init];
    creditCard.number = cardDictionary[@"number"];
    creditCard.expiryMonth = cardDictionary[@"expiryMonth"];
    creditCard.expiryYear = cardDictionary[@"expiryYear"];
    creditCard.cvv = cardDictionary[@"cvv"];
    creditCard.nameOnCard = [NSString stringWithFormat:@"%@ %@", cardDictionary[@"firstName"], cardDictionary[@"lastName"]];

    [self.client storeCreditCard:creditCard checkout:self.checkout completion:^(id<BUYPaymentToken> token, NSError *error) {
        if (error) {
            return reject(@"", [self getJsonFromError:error], error);
        }

        [self.client completeCheckoutWithToken:self.checkout.token paymentToken:token completion:^(BUYCheckout *returnedCheckout, NSError *error) {
            if (error) {
                return reject(@"", [self getJsonFromError:error], error);
            }

            self.checkout = returnedCheckout;
            resolve([self.checkout.order JSONDictionary]);
        }];
    }];
}

#pragma mark - BUYPaymentProvider delegate implementation -

- (void)paymentProvider:(id<BUYPaymentProvider>)provider wantsControllerPresented:(UIViewController *)controller
{
    self.rootViewController = [[[UIApplication sharedApplication] keyWindow] rootViewController];
    [self.rootViewController presentViewController:controller animated:YES completion:nil];
}

// TODO: This method is never called.
// The issue has been reported to Shopify: https://github.com/Shopify/mobile-buy-sdk-ios/issues/480
- (void)paymentProviderWantsControllerDismissed:(id <BUYPaymentProvider>)provider
{
    [self.rootViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)paymentProvider:(id<BUYPaymentProvider>)provider didFailCheckoutWithError:(NSError *)error
{
    _reject(@"checkout failed", @"", error);
}

- (void)paymentProviderDidDismissCheckout:(id<BUYPaymentProvider>)provider
{
    _reject(@"checkout dismissed", @"", nil);
}

// TODO: This method is never called.
// The issue has been reported to Shopify: https://github.com/Shopify/mobile-buy-sdk-ios/issues/428
- (void)paymentProvider:(id <BUYPaymentProvider>)provider didCompleteCheckout:(BUYCheckout *)checkout withStatus:(BUYStatus)status
{
    if (status == BUYStatusComplete) {
        _resolve(@"Done!");
    }
    else {
        // TODO: How to handle this case? The prerequisite to think about it is that the method is actually called
        _resolve(@"Completed checkout with unknown status");
    }
}

#pragma mark - Helpers -

/**
 *  We need this method to generate collection dictionaries manually because the JSONDictionary method
 *  from the SDK crashes in certain cases. The issue has been reported and closed. It won't be resolved
 *  in the near future. Check this link for details:  https://github.com/Shopify/mobile-buy-sdk-ios/issues/351
 */
- (NSArray *) getDictionariesForCollections:(NSArray<BUYCollection *> *)collections
{
    NSMutableArray *result = [NSMutableArray array];
    for (BUYCollection *collection in collections) {
        [result addObject: @{@"title":collection.title, @"id":collection.identifier}];
    }
    return result;
}

/**
 *  We need this method to add options for variants manually since the SDK's JSONDictionary method
 *  doesn't return them
 */
- (NSArray *) getDictionariesForProducts:(NSArray<BUYProduct *> *)products
{
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

- (BUYCheckout *) createCheckoutFromCart:(NSArray *)cartItems
{
    BUYModelManager *modelManager = self.client.modelManager;
    BUYCart *cart = [modelManager insertCartWithJSONDictionary:nil];

    for (NSDictionary *cartItem in cartItems) {
        BUYProductVariant *variant = [[BUYProductVariant alloc] initWithModelManager:modelManager JSONDictionary:cartItem[@"variant"]];
        for(int i = 0; i < [cartItem[@"quantity"] integerValue]; i++) {
            [cart addVariant:variant];
        }
    }

    BUYCheckout *checkout = [modelManager checkoutWithCart:cart];
    return checkout;
}

- (NSString *) getJsonFromError:(NSError *)error
{
    // If user info can't be parsed to JSON the dataWithJSONObject will throw an exception
    // In this case, we default to localized description
    if(![NSJSONSerialization isValidJSONObject:error.userInfo]){
      return error.localizedDescription;
    }

    NSError * err;
    NSData * jsonData = [NSJSONSerialization dataWithJSONObject:error.userInfo options:0 error:&err];
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

@end
