VTAInAppPurchases
=================

This is designed to make dealing with In App Purchases easier but in order to do that it assumes a bunch of things.

1. Information about consumable content is stored in NSUserDefaults, using the key as set in the `localStorageKey` of the plist file.
1. Non-consumable purchases without content also use the NSUserDefaults. Currently, these keys are not synchronised with iCloud (although I may add this in future), so users will have to restore to unlock on different devices.
1. Non-consumable downloadable content (currently only Apple-hosted content is supported) is stored in `Documents` (but the `NSURLIsExcludedFromBackupKey` is set so that the content doesn't get backed up, as per the App Store guidelines).
1. For local non-consumable content, drag the content into Xcode and make sure that the `Create folder references...` radio button is set when adding. Then make sure that the `localContentPath` in your products plist file is the exact name of the folder you just added.

It also includes receipt validation but this is provided as a convenience. It includes a copy of Apple's Root Certificate and a copy of OpenSSL as a pre-built static library. However, you probably shouldn't trust me and I recommend that you grab your own copy of Apple's certificate and compile your own OpenSSL and drop them into the project instead of the ones included here.

USE AT YOUR OWN RISK. Although I hope it helps you get up and running with In App Purchases quickly and easily, I can accept no responsibility for any loss of revenue resulting from the use of this code.

### A Four-and-a-bit Step Guide to Getting Set Up

1) Set up your In App Purchases in iTunesConnect. Make a note of the identifiers.

2) Add this repository as a submodule. Pull in the `source` folder into Xcode (uncheck `copy items`). You should have the `VTAProduct` and `VTAInAppPurchases` classes, along with the `productListExample.plist` file)

3) Import `"VTAInAppPurchases.h"` somewhere useful (e.g. your app delegate) then set either the remote or local URL pointing to your plist file:

    [VTAInAppPurchases sharedInstance].localURL = [[NSBundle mainBundle] URLForResource:@"ExampleProductList" withExtension:@"plist"];  
    // OR: [VTAInAppPurchases sharedInstance].remoteURL = [NSURL URLWithString:@"http://yourwebsite.com/ExampleProductList.plist"];

Valid plist keys are (currently not enforced, but may be in future):

	productIdentifier		(required) The identifier as set up in iTC
	consumable				(required) A BOOL indicating whether or not this is a consumable product
	storageKey				(required for consumables) This storage key indicates the `NSUserDefaults` key where the value of the content will be stored.
	productValue			(required for consumables) The value of the content being unlocked.
	localContentPath		(optional) the last path component of a local path where unlockable assets are stored, or where hosted content will be moved to (in this case, it indicates a subdirectory of `Documents`)
	productIcon				(optional) A local or remote URL of the product's icon image
	featuredImage			(optional) A local or remote URL pointing to a large product image
	hosted					(optional) A BOOL indicating whether the additional content is hosted by Apple or is contained within the bundle.
    childProducts           (optional) An array of non-consumable product identifiers that will be automatically unlocked when this one is. Good for multipacks or "buy all" IAPs.

4) In your app delegate (or wherever you want to start loading products), call `[[VTAInAppPurchases sharedInstance] loadProducts];` on the shared instance. 

4.b) If you want to use receipt validation, use this instead:

    [[VTAInAppPurchases sharedInstance] validateReceiptWithCompletionHandler:^(BOOL receiptIsValid) {
        [[VTAInAppPurchases sharedInstance] loadProducts];
    }];

This will begin loading the product plist file and will then pull the relevant details from the App Store. You can subscribe to a number of notifications to be informed about the loading status of this list. It'll go through three stages:

1. Neither the list nor the products have been loaded (`VTAInAppPurchaseStatusProductsLoading` or `VTAInAppPurchaseStatusProductListLoadFailed`)
1. The product list has been loaded and the `VTAProduct` objects have been initialised. (`VTAInAppPurchaseStatusProductListLoaded`)
1. The products have been loaded in from the App Store, and the `VTAProduct` objects have been updated (`VTAInAppPurchaseStatusProductsLoaded`)

Once this is complete, users can start making purchases. An example implementation of how you might set up a TableViewController to show the products and use the notifications to update the list (e.g. for a hosted product download) is included.

### Other Notes

* There is also a notification available for the VTAProduct objects as well, `VTAProductStatusDidChangeNotification`, which is sent out when a property is changed. Useful especially when a product's purchased status changes. 
* Products can be instantly unlocked in code and there's an `originalPurchasedVersion` property on the singleton that tells you when the user first downloaded the app. This can be useful for grandfathering in previous paid users into a freemium model. The product identifiers are stored in user defaults which is read on each launch. s
