#import "storekit_plugin.h"
#import <StoreKit/StoreKit.h>
#import <objc/runtime.h>

void register_godot_singleton(const char *name, void *instance) __attribute__((weak));
void unregister_godot_singleton(const char *name) __attribute__((weak));

static NSString *g_product_id = @"com.orehruoy.taptico.lifetime";
static NSString *g_price = @"";
static BOOL g_price_ready = NO;
static BOOL g_lifetime = NO;

void emit_purchase_updated(const char *product_id) __attribute__((weak));
void emit_purchase_failed(const char *message) __attribute__((weak));
void emit_entitlements_updated(BOOL unlocked) __attribute__((weak));
void emit_products_loaded(const char *price) __attribute__((weak));
void emit_products_failed(const char *message) __attribute__((weak));

static NSString *TapticoStoreErrorMessage(NSError *error) {
    if (error == nil) {
        return @"Purchase could not be completed.";
    }
    if ([error.domain isEqualToString:SKErrorDomain]) {
        switch (error.code) {
            case SKErrorPaymentCancelled:
                return @"Purchase cancelled.";
            case SKErrorPaymentNotAllowed:
                return @"Purchases are not allowed on this device.";
            case SKErrorStoreProductNotAvailable:
                return @"This product is not available in your App Store region.";
            default:
                break;
        }
    }
    if ([error.domain isEqualToString:NSURLErrorDomain]) {
        return @"No connection to the App Store. Check your network and try again.";
    }
    return error.localizedDescription ?: @"Purchase could not be completed.";
}

@interface TapticoStoreKit : NSObject <SKProductsRequestDelegate, SKPaymentTransactionObserver>
@property(nonatomic, copy) NSString *productId;
@property(nonatomic, strong) SKProduct *cachedProduct;
@property(nonatomic, assign) BOOL pendingPurchase;
@end

@implementation TapticoStoreKit

- (instancetype)init {
    self = [super init];
    if (self) {
        self.productId = g_product_id;
        self.pendingPurchase = NO;
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    }
    return self;
}

- (void)dealloc {
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}

- (void)initialize:(NSString *)productId {
    self.productId = productId.length > 0 ? productId : g_product_id;
    self.pendingPurchase = NO;
    [self fetchProducts];
    [self syncLocalEntitlements];
}

- (void)fetchProducts {
    NSString *sku = self.productId ?: g_product_id;
    SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:[NSSet setWithObject:sku]];
    request.delegate = self;
    [request start];
}

- (void)purchase:(NSString *)productId {
    if (![SKPaymentQueue canMakePayments]) {
        if (emit_purchase_failed) {
            emit_purchase_failed("Purchases are not allowed on this device.");
        }
        return;
    }
    NSString *sku = productId.length > 0 ? productId : (self.productId ?: g_product_id);
    self.productId = sku;
    if (self.cachedProduct && [self.cachedProduct.productIdentifier isEqualToString:sku]) {
        SKPayment *payment = [SKPayment paymentWithProduct:self.cachedProduct];
        [[SKPaymentQueue defaultQueue] addPayment:payment];
        return;
    }
    self.pendingPurchase = YES;
    [self fetchProducts];
}

- (void)restore {
    // Only called from the Restore Purchases button.
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

- (void)syncLocalEntitlements {
    // Inspect unfinished / current queue without prompting Apple ID.
    for (SKPaymentTransaction *transaction in [SKPaymentQueue defaultQueue].transactions) {
        BOOL matches = [transaction.payment.productIdentifier isEqualToString:(self.productId ?: g_product_id)];
        if (!matches) {
            continue;
        }
        if (transaction.transactionState == SKPaymentTransactionStatePurchased ||
            transaction.transactionState == SKPaymentTransactionStateRestored) {
            g_lifetime = YES;
        }
    }
}

- (BOOL)has_lifetime { return g_lifetime; }
- (NSString *)get_price { return g_price ?: @""; }
- (BOOL)is_price_ready { return g_price_ready; }

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    if (response.products.count == 0) {
        g_price_ready = NO;
        g_price = @"";
        if (self.pendingPurchase) {
            self.pendingPurchase = NO;
            if (emit_purchase_failed) {
                emit_purchase_failed("This product is not available in your App Store region.");
            }
        } else if (emit_products_failed) {
            emit_products_failed("Could not load App Store products. Check your connection.");
        }
        return;
    }
    SKProduct *product = response.products.firstObject;
    self.cachedProduct = product;
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterCurrencyStyle;
    formatter.locale = product.priceLocale;
    NSString *localized = [formatter stringFromNumber:product.price];
    g_price = localized ?: @"";
    g_price_ready = g_price.length > 0;
    if (g_price_ready && emit_products_loaded) {
        emit_products_loaded([g_price UTF8String]);
    }
    if (self.pendingPurchase) {
        self.pendingPurchase = NO;
        SKPayment *payment = [SKPayment paymentWithProduct:product];
        [[SKPaymentQueue defaultQueue] addPayment:payment];
    }
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    g_price_ready = NO;
    BOOL wasPurchase = self.pendingPurchase;
    self.pendingPurchase = NO;
    const char *msg = [TapticoStoreErrorMessage(error) UTF8String];
    if (wasPurchase && emit_purchase_failed) {
        emit_purchase_failed(msg);
    } else if (emit_products_failed) {
        emit_products_failed(msg);
    }
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
    for (SKPaymentTransaction *transaction in transactions) {
        if (![transaction.payment.productIdentifier isEqualToString:(self.productId ?: g_product_id)]) {
            continue;
        }
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchased:
            case SKPaymentTransactionStateRestored:
                g_lifetime = YES;
                if (emit_purchase_updated) {
                    emit_purchase_updated([transaction.payment.productIdentifier UTF8String]);
                }
                if (emit_entitlements_updated) {
                    emit_entitlements_updated(YES);
                }
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                break;
            case SKPaymentTransactionStateFailed: {
                NSError *error = transaction.error;
                BOOL cancelled = error && [error.domain isEqualToString:SKErrorDomain] && error.code == SKErrorPaymentCancelled;
                if (emit_purchase_failed) {
                    emit_purchase_failed(cancelled ? "Purchase cancelled." : [TapticoStoreErrorMessage(error) UTF8String]);
                }
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                break;
            }
            default:
                break;
        }
    }
}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
    [self syncLocalEntitlements];
    if (emit_entitlements_updated) {
        emit_entitlements_updated(g_lifetime);
    }
}

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
    if (emit_purchase_failed) {
        emit_purchase_failed([TapticoStoreErrorMessage(error) UTF8String]);
    }
    if (emit_entitlements_updated) {
        emit_entitlements_updated(g_lifetime);
    }
}

@end

static TapticoStoreKit *g_storekit = nil;

void storekit_init() {
    g_storekit = [[TapticoStoreKit alloc] init];
    if (register_godot_singleton) {
        register_godot_singleton("StoreKit", (__bridge void *)g_storekit);
    }
}

void storekit_deinit() {
    if (unregister_godot_singleton) {
        unregister_godot_singleton("StoreKit");
    }
    g_storekit = nil;
}
