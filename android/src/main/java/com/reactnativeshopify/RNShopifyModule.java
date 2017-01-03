
package com.reactnativeshopify;

import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.Iterator;

import org.json.*;

import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReadableArray;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.ReadableMapKeySetIterator;
import com.facebook.react.bridge.ReadableType;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.bridge.WritableNativeMap;
import com.facebook.react.bridge.WritableArray;
import com.facebook.react.bridge.WritableNativeArray;
import com.facebook.react.bridge.Arguments;

import com.shopify.buy.dataprovider.*;
import com.shopify.buy.model.*;

public class RNShopifyModule extends ReactContextBaseJavaModule {

  private final ReactApplicationContext reactContext;
  private BuyClient buyClient;

  public RNShopifyModule(ReactApplicationContext reactContext) {
    super(reactContext);
    this.reactContext = reactContext;
  }

  @Override
  public String getName() {
    return "RNShopify";
  }

  @ReactMethod
  public void initialize(String domain, String key) {

    //Application ID is always 8, as stated in official documentation from Shopify
    buyClient = new BuyClientBuilder()
    .shopDomain(domain)
    .apiKey(key)
    .appId("8")
    .applicationName("com.reactnativeshopify")
    .build();
  }

  @ReactMethod
  public void getShop(final Promise promise) {

    buyClient.getShop(new Callback<Shop>() {
      @Override
      public void success(Shop shop) {
        try {
          promise.resolve(convertJsonToMap(new JSONObject(shop.toJsonString())));
        } catch (JSONException e) {
          promise.reject("", e);
        }
      }

      @Override
      public void failure(BuyClientError error) {
        promise.reject("", error.getRetrofitErrorBody());
      }
    });
  }

  @ReactMethod
  public void getCollections(int page, final Promise promise) {
    buyClient.getCollections(page, new Callback<List<Collection>>() {

      @Override
      public void success(List<Collection> collections) {
        try {
          WritableArray array = new WritableNativeArray();

          for(Collection collection : collections) {
            WritableMap collectionDictionary = convertJsonToMap(new JSONObject(collection.toJsonString()));
            collectionDictionary.putInt("id", collectionDictionary.getInt("collection_id"));
            array.pushMap(collectionDictionary);
          }

          promise.resolve(array);
        } catch (JSONException e) {
          promise.reject("", e);
        }
      }

      @Override
      public void failure(BuyClientError error) {
        promise.reject("", error.getRetrofitErrorBody());
      }
    });
  }

  @ReactMethod
  public void getProductTags(int page, final Promise promise) {
    buyClient.getProductTags(page, new Callback<List<String>>() {

      @Override
      public void success(List<String> tags) {
        WritableArray array = new WritableNativeArray();

        for(String tag : tags) {
          array.pushString(tag);
        }

        promise.resolve(array);
      }

      @Override
      public void failure(BuyClientError error) {
        promise.reject("", error.getRetrofitErrorBody());
      }
    });
  }

  @ReactMethod
  public void getProductsPage(int page, final Promise promise) {
    buyClient.getProducts(page, new Callback<List<Product>>() {

      @Override
      public void success(List<Product> products) {
        try {
          promise.resolve(getProductsAsWritableArray(products));
        } catch (JSONException e) {
          promise.reject("", e);
        }
      }

      @Override
      public void failure(BuyClientError error) {
        promise.reject("", error.getRetrofitErrorBody());
      }
    });
  }

  @ReactMethod
  public void getProductsWithTags(int page, ReadableArray tags, final Promise promise) {
    buyClient.getProducts(page, convertReadableArrayToSet(tags), new Callback<List<Product>>() {

      @Override
      public void success(List<Product> products) {
        try {
          promise.resolve(getProductsAsWritableArray(products));
        } catch (JSONException e) {
          promise.reject("", e);
        }
      }

      @Override
      public void failure(BuyClientError error) {
        promise.reject("", error.getRetrofitErrorBody());
      }
    });
  }

  @ReactMethod
  public void getProductsWithTagsForCollection(int page, int collectionId, ReadableArray tags,
      final Promise promise) {
    buyClient.getProducts(page, Long.valueOf(collectionId), convertReadableArrayToSet(tags), null,
        new Callback<List<Product>>() {

      @Override
      public void success(List<Product> products) {
        try {
          promise.resolve(getProductsAsWritableArray(products));
        } catch (JSONException e) {
          promise.reject("", e);
        }
      }

      @Override
      public void failure(BuyClientError error) {
        promise.reject("", error.getRetrofitErrorBody());
      }
    });
  }

  @ReactMethod
  public void checkout(ReadableArray variants, final Promise promise) {
    Cart cart;

    try {
      cart = new Cart();
      JSONArray variantsArray = convertArrayToJson(variants);

      for (int i = 0; i < variantsArray.length(); i++) {
        JSONObject value = variantsArray.getJSONObject(i);
        cart.addVariant(fromVariantJson(value.toString()));
      }
    } catch (JSONException e) {
      promise.reject("", e);
      return;
    }

    Checkout checkout = new Checkout(cart);

    // Sync the checkout with Shopify
    buyClient.createCheckout(checkout, new Callback<Checkout>() {
      @Override
      public void success(Checkout checkout) {
        //TODO: Implement native or web checkout
      }

      @Override
      public void failure(BuyClientError error) {
        promise.reject("", error.getRetrofitErrorBody());
      }
    });
  }

  private WritableArray getProductsAsWritableArray(List<Product> products) throws JSONException {
    WritableArray array = new WritableNativeArray();

    for(Product product : products) {
      WritableMap productMap = convertJsonToMap(new JSONObject(product.toJsonString()));
      productMap.putString("minimum_price", product.getMinimumPrice());
      array.pushMap(productMap);
    }

    return array;
  }

  private Set<String> convertReadableArrayToSet(ReadableArray array) {
    Set<String> set = new HashSet<String>();

    for (int i = 0; i < array.size(); i++) {
      set.add(array.getString(i));
    }

    return set;
  }

  private WritableMap convertJsonToMap(JSONObject jsonObject) throws JSONException {
    WritableMap map = new WritableNativeMap();

    Iterator<String> iterator = jsonObject.keys();
    while (iterator.hasNext()) {
      String key = iterator.next();
      Object value = jsonObject.get(key);
      if (value instanceof JSONObject) {
        map.putMap(key, convertJsonToMap((JSONObject) value));
      } else if (value instanceof JSONArray) {
        map.putArray(key, convertJsonToArray((JSONArray) value));
        if(("option_values").equals(key)) {
          map.putArray("options", convertJsonToArray((JSONArray) value));
        }
      } else if (value instanceof Boolean) {
        map.putBoolean(key, (Boolean) value);
      } else if (value instanceof Integer) {
        map.putInt(key, (Integer) value);
      } else if (value instanceof Double) {
        map.putDouble(key, (Double) value);
      } else if (value instanceof String)  {
        map.putString(key, (String) value);
      } else {
        map.putString(key, value.toString());
      }
    }
    return map;
  }

  private WritableArray convertJsonToArray(JSONArray jsonArray) throws JSONException {
    WritableArray array = new WritableNativeArray();

    for (int i = 0; i < jsonArray.length(); i++) {
      Object value = jsonArray.get(i);
      if (value instanceof JSONObject) {
        array.pushMap(convertJsonToMap((JSONObject) value));
      } else if (value instanceof JSONArray) {
        array.pushArray(convertJsonToArray((JSONArray) value));
      } else if (value instanceof Boolean) {
        array.pushBoolean((Boolean) value);
      } else if (value instanceof Integer) {
        array.pushInt((Integer) value);
      } else if (value instanceof Double) {
        array.pushDouble((Double) value);
      } else if (value instanceof String)  {
        array.pushString((String) value);
      } else {
        array.pushString(value.toString());
      }
    }
    return array;
  }

  private JSONObject convertMapToJson(ReadableMap readableMap) throws JSONException {
    JSONObject object = new JSONObject();
    ReadableMapKeySetIterator iterator = readableMap.keySetIterator();
    while (iterator.hasNextKey()) {
      String key = iterator.nextKey();
      switch (readableMap.getType(key)) {
        case Null:
          object.put(key, JSONObject.NULL);
          break;
        case Boolean:
          object.put(key, readableMap.getBoolean(key));
          break;
        case Number:
          object.put(key, readableMap.getDouble(key));
          break;
        case String:
          object.put(key, readableMap.getString(key));
          break;
        case Map:
          object.put(key, convertMapToJson(readableMap.getMap(key)));
          break;
        case Array:
          object.put(key, convertArrayToJson(readableMap.getArray(key)));
          break;
        }
    }
    return object;
}

  private JSONArray convertArrayToJson(ReadableArray readableArray) throws JSONException {

    JSONArray array = new JSONArray();

    for (int i = 0; i < readableArray.size(); i++) {
      switch (readableArray.getType(i)) {
        case Null:
          break;
        case Boolean:
          array.put(readableArray.getBoolean(i));
          break;
        case Number:
          array.put(readableArray.getDouble(i));
          break;
        case String:
          array.put(readableArray.getString(i));
          break;
        case Map:
          array.put(convertMapToJson(readableArray.getMap(i)));
          break;
        case Array:
          array.put(convertArrayToJson(readableArray.getArray(i)));
          break;
      }
    }
    return array;
  }

  private ProductVariant fromVariantJson(String json) {
    return BuyClientUtils.createDefaultGson().fromJson(json, ProductVariant.class);
  }
}
