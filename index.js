
import { NativeModules } from 'react-native';

const { RNShopify } = NativeModules;

export default {
  ...RNShopify,
  getProducts: (page, collectionId, tags) => {
    if (collectionId) {
      return RNShopify.getProductsWithTagsForCollection(page, collectionId, tags);
    } else {
      return tags && RNShopify.getProductsWithTags(page, tags) || RNShopify.getProductsPage(page);
    }
  }
}

