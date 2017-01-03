
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
            resolve([shop JSONDictionary]);
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

RCT_EXPORT_METHOD(getProductsPage:(NSUInteger)page resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
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

RCT_EXPORT_METHOD(webCheckout:(NSArray *)variants resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
    _resolve = resolve;
    _reject = reject;

    BUYCheckout *checkout = [self createCheckoutFromVariants:variants];

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

RCT_EXPORT_METHOD(checkout:(NSArray *)variants resolver:(RCTPromiseResolveBlock)resolve
                rejecter:(RCTPromiseRejectBlock)reject)
{
    BUYCheckout *checkout = [self createCheckoutFromVariants:variants];

    [self.client createCheckout:checkout completion:^(BUYCheckout *checkout, NSError *error) {
        if (error == nil && checkout) {
            self.checkout = checkout;
            resolve(@"Success");
        } else {
            reject([NSString stringWithFormat: @"%lu", (long)error.code], error.localizedDescription, error);
        }
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
        if (error == nil) {
            self.checkout = checkout;
            resolve(@"Success");
        } else {
            NSString *errorText = [self getCheckoutError:error];
            reject([NSString stringWithFormat: @"%lu", (long)error.code], errorText, error);
        }
    }];
}

RCT_EXPORT_METHOD(getShippingRates:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
    [self.client getShippingRatesForCheckoutWithToken:self.checkout.token completion:^(NSArray<BUYShippingRate *> *shippingRates, BUYStatus status, NSError *error) {
        self.availableShippingRates = shippingRates;
        if (shippingRates && !error) {
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
        } else {
            reject([NSString stringWithFormat: @"%lu", (long)error.code], error.localizedDescription, error);
        }
    }];
}

RCT_EXPORT_METHOD(selectShippingRate:(NSUInteger)shippingRateIndex resolver:(RCTPromiseResolveBlock)resolve
                rejecter:(RCTPromiseRejectBlock)reject)
{
    self.checkout.shippingRate = self.availableShippingRates[shippingRateIndex];

    [self.client updateCheckout:self.checkout completion:^(BUYCheckout *checkout, NSError *error) {
        if (error == nil) {
            self.checkout = checkout;
            resolve(@"Success");
        } else {
            reject([NSString stringWithFormat: @"%lu", (long)error.code], error.localizedDescription, error);
        }
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
        if (error || !token) {
            NSString *errorText = [self getCheckoutError:error];
            return reject(@"", errorText, error);
        }
        [self.client completeCheckoutWithToken:self.checkout.token paymentToken:token completion:^(BUYCheckout *returnedCheckout, NSError *error) {
            if (error == nil) {
                self.checkout = returnedCheckout;
                resolve(@"Success");
            } else {
                NSString *errorText = [self getCheckoutError:error];
                return reject(@"", errorText, error);
            }
      }];
    }];
}

#pragma mark - BUYPaymentProvider delegate implementation -

- (void)paymentProvider:(id<BUYPaymentProvider>)provider wantsControllerPresented:(UIViewController *)controller
{
    self.rootViewController = [[
                                             [UIApplication sharedApplication] keyWindow] rootViewController];
    [self.rootViewController presentViewController:controller animated:YES completion:nil];
}

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

- (NSArray *) createCheckoutFromVariants:(NSArray *)variants {
    BUYModelManager *modelManager = self.client.modelManager;
    BUYCart *cart = [modelManager insertCartWithJSONDictionary:nil];

    for (NSDictionary *dictionary in variants) {
        BUYProductVariant *variant = [[BUYProductVariant alloc] initWithModelManager:modelManager                                                                  JSONDictionary:dictionary];
        [cart addVariant:variant];
    }

    BUYCheckout *checkout = [modelManager checkoutWithCart:cart];
    return checkout;
}

/*
 * Parses checkout errors. Shopify doesn't have a standard error format.
 * It replicates the structure that was sent in the request so one needs to manually parse it.
 * This issue was reported here: https://github.com/Shopify/mobile-buy-sdk-ios/issues/22
 * This function was taken from a comment on this issue.
 * Although Shopify has helper methods for error parsing, they only support error with line items.
 * TODO: Create a mapping for all error keys with user friendly labels. For example, when there is
 * a card number error, we create an error message in the following format: 'card_number is invalid'
 */
- (NSString*) getCheckoutError: (NSError *) error {
    __block NSString *errorText = @"";
    NSDictionary *checkout = error.userInfo[@"errors"][@"checkout"];
    [checkout enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if([obj isKindOfClass: [NSArray class]] && [obj count] > 0) {
            errorText = [errorText stringByAppendingFormat:@"%@ %@\n", key,  obj[0][@"message"]];
        } else if([obj isKindOfClass: [NSDictionary class]]){
            [obj enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key2, id  _Nonnull obj2, BOOL * _Nonnull stop) {
                if([obj2 isKindOfClass: [NSArray class]] && [obj2 count] > 0) {
                    errorText = [errorText stringByAppendingFormat:@"%@ %@ %@\n", key, key2,  obj2[0][@"message"]];
                }
            }];
        }
    }];
    return errorText;
}

@end
