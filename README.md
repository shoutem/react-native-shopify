
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
  - Add `import com.reactlibrary.RNShopifyPackage;` to the imports at the top of the file
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

#### Windows
[Read it! :D](https://github.com/ReactWindows/react-native)

1. In Visual Studio add the `RNShopify.sln` in `node_modules/react-native-shopify/windows/RNShopify.sln` folder to their solution, reference from their app.
2. Open up your `MainPage.cs` app
  - Add `using Cl.Json.RNShopify;` to the usings at the top of the file
  - Add `new RNShopifyPackage()` to the `List<IReactPackage>` returned by the `Packages` method


## Usage
```javascript
import RNShopify from 'react-native-shopify';

RNShopify.initialize('yourshopifystore.myshopify.com', 'YOUR API KEY');

Shopify.getProducts().then(products => {
	const variants = products.map(product => product.variants[0]);
	return Shopify.checkout(variants);
}).then(message => {
	console.log(message);
}).catch(error => {
	console.log(error);
});
```
  
