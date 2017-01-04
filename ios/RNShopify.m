
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

        NSMutableArray *collectionDictionaries = [NSMutableArray array];

        for (BUYCollection *collection in collections) {
            [collectionDictionaries addObject: @{@"title":collection.title,@"id":collection.identifier}];
        }

        resolve(collectionDictionaries);
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

RCT_EXPORT_METHOD(webCheckout:(NSArray *)variants resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    _resolve = resolve;
    _reject = reject;

    BUYCheckout *checkout = [self createCheckoutFromVariants:variants];

    [self.client createCheckout:checkout completion:^(BUYCheckout *checkout, NSError *error) {
        if (error) {
            return reject([NSString stringWithFormat: @"%lu", (long)error.code], error.localizedDescription, error);
        }

        BUYWebCheckoutPaymentProvider *webPaymentProvider = [[BUYWebCheckoutPaymentProvider alloc] initWithClient:self.client];
        webPaymentProvider.delegate = self;

        [webPaymentProvider startCheckout:checkout];
    }];
}

RCT_EXPORT_METHOD(checkout:(NSArray *)variants resolver:(RCTPromiseResolveBlock)resolve
                rejecter:(RCTPromiseRejectBlock)reject)
{
    BUYCheckout *checkout = [self createCheckoutFromVariants:variants];

    [self.client createCheckout:checkout completion:^(BUYCheckout *checkout, NSError *error) {
        if (error) {
            return reject([NSString stringWithFormat: @"%lu", (long)error.code], error.localizedDescription, error);
        }

        self.checkout = checkout;
        resolve(@"Success");
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
            NSString *errorText = [self getCheckoutError:error];
            return reject([NSString stringWithFormat: @"%lu", (long)error.code], errorText, error);
        }

        self.checkout = checkout;
        resolve(@"Success");
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
                NSInteger daysInBetweenFirst = 1 + [NSDate daysBetweenDate:[NSDate date] andDate:shippingRate.deliveryRange[0]];
                NSInteger daysInBetweenLast = 1 + [NSDate daysBetweenDate:[NSDate date] andDate:[shippingRate.deliveryRange lastObject]];

                NSMutableArray *deliveryRange = [NSMutableArray array];
                [deliveryRange addObject:[NSNumber numberWithInteger:daysInBetweenFirst]];
                [deliveryRange addObject:[NSNumber numberWithInteger:daysInBetweenLast]];

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
        resolve(@"Success");
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
    creditCard.nameOnCard = cardDictionary[@"nameOnCard"];

    [self.client storeCreditCard:creditCard checkout:self.checkout completion:^(id<BUYPaymentToken> token, NSError *error) {
        if (error) {
            NSString *errorText = [self getCheckoutError:error];
            return reject(@"", errorText, error);
        }

        [self.client completeCheckoutWithToken:self.checkout.token paymentToken:token completion:^(BUYCheckout *returnedCheckout, NSError *error) {
            if (error) {
                NSString *errorText = [self getCheckoutError:error];
                return reject(@"", errorText, error);
            }

            self.checkout = returnedCheckout;
            resolve(@"Success");
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

- (BUYCheckout *) createCheckoutFromVariants:(NSArray *)variants
{
    BUYModelManager *modelManager = self.client.modelManager;
    BUYCart *cart = [modelManager insertCartWithJSONDictionary:nil];

    for (NSDictionary *dictionary in variants) {
        BUYProductVariant *variant = [[BUYProductVariant alloc] initWithModelManager:modelManager                                                                  JSONDictionary:dictionary];
        [cart addVariant:variant];
    }

    BUYCheckout *checkout = [modelManager checkoutWithCart:cart];
    return checkout;
}

/**
 * Parses checkout errors. Shopify doesn't have a standard error format.
 * It replicates the structure that was sent in the request so one needs to manually parse it.
 * This issue was reported here: https://github.com/Shopify/mobile-buy-sdk-ios/issues/22
 * This function was taken from a comment on this issue.
 * Although Shopify has helper methods for error parsing, they only support error with line items.
 * This method also transforms keys into user friendly labels, for example 'last_name' to 'Last name'
 */
- (NSString *) getCheckoutError: (NSError *) error
{
    __block NSString *errorText = @"";
    NSDictionary *checkout = error.userInfo[@"errors"][@"checkout"];
    [checkout enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if([obj isKindOfClass: [NSArray class]] && [obj count] > 0) {
            NSString *keyLabel = [self getLabelForErrorKey: key];
            errorText = [errorText stringByAppendingFormat:@"%@ %@\n", keyLabel,  obj[0][@"message"]];
        } else if([obj isKindOfClass: [NSDictionary class]]){
            [obj enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key2, id  _Nonnull obj2, BOOL * _Nonnull stop) {
                NSString *keyLabel = [self getLabelForErrorKey: key];
                NSString *key2Label = [self getLabelForErrorKey: key2];
                if([obj2 isKindOfClass: [NSArray class]] && [obj2 count] > 0) {
                    errorText = [errorText stringByAppendingFormat:@"%@ %@ %@\n", keyLabel, key2Label,  obj2[0][@"message"]];
                }
            }];
        }
    }];

    return errorText;
}

- (NSString *) getLabelForErrorKey: (NSString *) key
{
    NSDictionary *dictionary = @{
        @"billing_address": @"Billing address",
        @"email": @"Email",
        @"credit_card": @"Credit card",
        @"last_name": @"last name",
        @"payment_gateway": @"Payment gateway:",
        @"shipping_address": @"Shipping address",
        @"verification_value": @"verification value",
    };

   return dictionary[key] ? dictionary[key]: key;
}

@end
