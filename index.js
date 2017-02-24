import { NativeModules } from 'react-native';
import _ from 'lodash';

const { RNShopify } = NativeModules;

const UNKNOWN_ERROR = 'There was an unknown error. Please contact our customer support.';

export default {
  ...RNShopify,
  getProducts: (page = 1, collectionId, tags) => {
    if (collectionId) {
      return RNShopify.getProductsWithTagsForCollection(page, collectionId, tags);
    }
    return tags ? RNShopify.getProductsWithTags(page, tags) : RNShopify.getProductsPage(page);
  },
  checkout: (cart) => {
    return RNShopify.checkout(cart)
      .catch((error) => {
        throw new Error(getCheckoutError(error.message, cart));
      });
  },
  setCustomerInformation: (email, customer) => {
    return RNShopify.setCustomerInformation(email, customer)
      .catch((error) => {
        throw new Error(getCheckoutError(error.message));
      });
  },
  completeCheckout: (creditCard) => {
    return RNShopify.completeCheckout(creditCard)
      .catch((error) => {
        throw new Error(getCheckoutError(error.message));
      });
  },
};

/**
 * Converts checkout errors to a user friendly message. Shopify doesn't have a standard error format.
 * It replicates the structure that was sent in the request so we need to parse it manually.
 * This issue was reported here: https://github.com/Shopify/mobile-buy-sdk-ios/issues/22
 * Here is an example:
 *
 * {"errors":{"checkout":{"email":[{"code":"invalid","message":"is invalid","options":{}}],
 *  "shipping_address":{"country_code":[{"code":"not_supported","message":"is not supported",
 *  "options":{}}]},"billing_address":{"country_code":[{"code":"not_supported",
 *  "message":"is not supported","options":{}}]}}}}
 *
 * Although Shopify has started to build helper methods for error parsing, there is still work
 * to be done there. Also, they are different for iOS and Android SDK.
 *
 * This JavaScript method gives you a complete solution for catching all checkout errors for
 * both iOS and Android. It also transforms keys into user friendly labels, for example 'last_name'
 * to 'Last name'.
 *
 * If the checkout error is a network or other non standard error, this method will return an
 * unknown error message.
 */
const getCheckoutError = (errorBody, cart) => {
  if (!errorBody) {
    return UNKNOWN_ERROR;
  }

  const errorObject = JSON.parse(errorBody);

  const checkoutErrors = errorObject.errors.checkout;
  // This method is only used for checkout erorrs
  if (!checkoutErrors) {
    return UNKNOWN_ERROR;
  }

  // We first check for line item errors, which can happen only when trying to checkout the cart
  if (checkoutErrors.line_items) {
    return getLineItemsErrorMessage(checkoutErrors.line_items, cart);
  }

  return getErrorMessageFromCheckoutObject(checkoutErrors);
};

/**
 * Converts line item errors to a user friendly message. If some of the items are unavailable,
 * Shopify will send an array of these errors, in the same order as the cart items used to start
 * the checkout. For each error, the message will describe how many units of the selected variant
 * are remaining in the store. Those items that can be bought are represented with a null in the array.
 * Here is an example:
 *
 * {"errors":{"checkout":{"line_items":[null,{"quantity":[{"message":"Not enough items available.
 *  Only 2 left.","options":{"remaining":2},"code":"not_enough_in_stock"}]}]}}}
 *
 * Since this array matches the cart in order, we can display how many items for a product
 * and variant are remaining for each cart item that is unavailable. For example, let's say we
 * tried to buy a Small Navy sweater and 3 Grey Medium Sweaters. Suppose that only 2 Grey Sweaters
 * are available. We'll get null for the Navy sweater and an error message for Grey ones. The resulting
 * message will be: "Sweater - Grey Medium: Not enough items available. Only 2 left."
 *
 * We only handle quantity errors since these are known and documented.
 *
 * Available inventory is considered sensitive data and is only available through the admin API on Shopify,
 * and not through the SDK. This is explained by the Shopify's team here:
 * https://ecommerce.shopify.com/c/shopify-apis-and-technology/t/mobile-buy-sdk-how-can-i-obtain-the-quantity-of-a-product-279864
 *
 * The checkout error is the only way to tell the user how many items are available, otherwise app
 * developers could implement a limit in the cart interface.
 *
 */
const getLineItemsErrorMessage = (lineItemErrors, cart) => {
  let errorMessage = 'Some of the items are unavailable. \n\n';

  _.forEach(cart, (cartItem, index) => {
    const lineItemError = lineItemErrors[index];
    const { item, variant } = cartItem;

    if (lineItemError && lineItemError.quantity) {
      const quantityError = lineItemError.quantity[0];
      errorMessage += `${item.title} - ${variant.title}: ${quantityError.message} \n\n`;
    }
  });
  return errorMessage;
};

/**
 * Converts checkout errors to a user friendly message. Some checkout errors have 1 level,
 * such as an email error, and some have 2, such as credit card errors for number, cvv or other fields.
 * This method calls itself recursively to collect all of these errors and prefix them with parent keys.
 */
const getErrorMessageFromCheckoutObject = (errorObject, prefix) => {
  let errorMessage = '';
  _.forOwn(errorObject, (value, key) => {
    const keyLabel = getLabelForErrorKey(key);

    if (_.isArray(value) && _.size(value)) {
      errorMessage += `${prefix ? `${prefix} ` : ''}${keyLabel} ${value[0].message}. \n\n`;
    } else {
      errorMessage += getErrorMessageFromCheckoutObject(value, keyLabel);
    }
  });
  return errorMessage;
};

/**
 * Since Shopify errors have keys not meant for end users, we convert them to a
 * readable format. For example, if we have an error in this format: {"credit_card":
 * {"verification_value": [{"message": "is invalid."}]}}, we want to show it as:
 * "Credit card verification value is invalid."
 */
const getLabelForErrorKey = (key) => {
  const dictionary = {
    billing_address: 'Billing address',
    email: 'Email',
    credit_card: 'Credit card',
    country_code: 'country code',
    last_name: 'last name',
    payment_gateway: 'Payment gateway:',
    shipping_address: 'Shipping address',
    verification_value: 'verification value',
  };

  return dictionary[key] || key;
};
