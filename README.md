VTAInAppPurchases
=================

Using VTAInAppPurchases

1) Set up your In App Purchases in iTunesConnect. Make a note of the identifiers.

2) Pull in the source from the `VTAInAppPurchases` repo (`VTAInAppPurchases` and `VTAProduct`).

3) Create a Singleton Subclass:

	+(instancetype)sharedInstance {
		static YOURAPPInAppPurchases *sharedInstance;
		static dispatch_once_t onceToken;
		dispatch_once(&onceToken, ^{
			sharedInstance = [[self alloc] init];
		});
		return sharedInstance;
	}

4) In the `init` method of this subclass, point to either a remote or local plist file. 

	-(id)init {
		if ( self = [super init] ) {
			self.localURL = [[NSBundle mainBundle] URLForResource:@"ExampleProductList" withExtension:@"plist"];  
			// OR: self.remoteURL = [NSURL URLWithString:@"http://yourwebsite.com/ExampleProductList.plist"];
		}
    
		return self;
	}

Valid plist keys are:

	productIdentifier		(required) The identifier as set up in iTC
	consumable				(required) A BOOL indicating whether or not this is a consumable product
	localContentPath		(optional) the last path component of a local path where unlockable assets are stored, or where hosted content will be moved to (in this case, it indicates a subdirectory of `Documents`)
	productIcon				(optional) A local or remote URL of the product's icon image
	featuredImage			(optional) A local or remote URL pointing to a large product image
	hosted					(optional) A BOOL indicating whether the additional content is hosted by Apple or is contained within the bundle.
	storageKey				(optional) This storage key indicates the `NSUserDefaults` key where the value of the content will be stored.
	productValue			(optional) The value of the content being unlocked.

5) In your app delegate (or wherever you want to start loading products), call `[[DCInAppPurchases sharedInstance] loadProducts];` on the shared instance. This will load the product plist file and get the relevant details from the App Store. You can subscribe to a number of notifications to be informed about which point the loading has reached.
6) In your list view controller, set up a NSNumberFormatter (as a property is recommended) with the following attributes:

	NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
	formatter.formatterBehavior = NSNumberFormatterBehavior10_4;
	[formatter setNumberStyle:NSNumberFormatterCurrencyStyle];
