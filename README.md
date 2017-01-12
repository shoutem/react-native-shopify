
# react-native-shopify

## Getting started

`$ npm install react-native-shopify --save`

### Including Mobile-BUY-SDK

Include the Shopify Mobile Buy SDK in your project to make it available to the bridge.
Follow the instructions on their Github page to get started. For example,
the recommended and easiest way for iOS is to install it as a Pod. This project will look
for headers in the Pods directory.

### Mostly automatic installation

`$ react-native link react-native-shopify`

### Manual installation


#### iOS

1. In XCode, in the project navigator, right click `Libraries` ➜ `Add Files to [your project's name]`
2. Go to `node_modules` ➜ `react-native-shopify` and add `RNShopify.xcodeproj`
3. In XCode, in the project navigator, select your project. Add `libRNShopify.a` to your project's `Build Phases` ➜ `Link Binary With Libraries`
4. Run your project (`Cmd+R`)<

#### Android

1. Open up `android/app/src/main/java/[...]/MainActivity.java`
  - Add `import com.reactnativeshopify.RNShopifyPackage;` to the imports at the top of the file
  - Add `new RNShopifyPackage()` to the list returned by the `getPackages()` method
2. Append the following lines to `android/settings.gradle`:
  	```
  	include ':react-native-shopify'
  	project(':react-native-shopify').projectDir = new File(rootProject.projectDir, 	'../node_modules/react-native-shopify/android')
  	```
3. Insert the following lines inside the dependencies block in `android/app/build.gradle`:
  	```
      compile project(':react-native-shopify')
  	```


## Usage
```javascript
import Shopify from 'react-native-shopify';

Shopify.initialize('yourshopifystore.myshopify.com', 'YOUR API KEY');

Shopify.getProducts().then(products => {
	const cart = [{item, variant, quantity}];
	return Shopify.checkout(cart);
}).then(message => {
	console.log(message);
}).catch(error => {
	console.log(error.message);
});
```

### What can you do with it?

You can browse through all products or filter them by collection and tag. You can call native checkout
methods for both iOS and Android. We support web checkout for iOS but we have yet to implement the
handlers for order completion so you can clear the cart or redirect the user to another page.

We implemented custom parsing for checkout errors to give your users
friendly messages on what went wrong. You can find out which line items are unavailable due to
not enough quantity and how many are remaining. You can also get feedback about which fields are invalid
when entering customer and payment information. Feedback messages are available through
the `message` property on the error object in checkout methods.

All contributions are welcome!
