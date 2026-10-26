#import "storekit_plugin.h"
#import <StoreKit/StoreKit.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include <string>

void emit_purchase_updated(const char *product_id);
void emit_purchase_failed(const char *message);
void emit_entitlements_updated(bool unlocked);
void emit_products_loaded(const char *price);
void emit_products_failed(const char *message);

static NSString *g_product_id = @"com.orehruoy.taptico.lifetime";
static NSString *g_price = @"";
static std::string g_price_utf8;
static BOOL g_price_ready = NO;
static BOOL g_lifetime = NO;

static void on_main(dispatch_block_t block) {
    if (block == nil) {
        return;
    }
    if ([NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(dispatch_get_main_queue(), block);
    }
}

static const char *TapticoUTF8(NSString *text) {
    const char *utf8 = text.UTF8String;
    return utf8 != nullptr ? utf8 : "";
}

static void TapticoSetPrice(NSString *price) {
    NSString *value = price ?: @"";
    g_price = value;
    const char *utf8 = value.UTF8String;
    if (utf8 == nullptr || value.length == 0) {
        g_price_utf8.clear();
        g_price_ready = NO;
        return;
    }
    g_price_utf8.assign(utf8);
    g_price_ready = YES;
}

static void TapticoMarkPriceUnavailable(void) {
    g_price_ready = NO;
}

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
@property(nonatomic, strong) SKProductsRequest *currentRequest;
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
    self.currentRequest.delegate = nil;
    [self.currentRequest cancel];
    self.currentRequest = nil;
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}

- (void)initialize:(NSString *)productId {
    NSString *sku = productId.length > 0 ? productId : g_product_id;
    on_main(^{
        self.productId = sku;
        self.pendingPurchase = NO;
        [self fetchProducts];
        [self syncLocalEntitlements];
    });
}

- (void)fetchProducts {
    NSString *sku = self.productId.length > 0 ? self.productId : g_product_id;
    on_main(^{
        SKProductsRequest *previous = self.currentRequest;
        self.currentRequest = nil;
        previous.delegate = nil;
        [previous cancel];
        SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:[NSSet setWithObject:sku]];
        request.delegate = self;
        self.currentRequest = request;
        [request start];
    });
}

- (void)purchase:(NSString *)productId {
    NSString *sku = productId.length > 0 ? productId : (self.productId ?: g_product_id);
    on_main(^{
        if (![SKPaymentQueue canMakePayments]) {
            NSString *message = @"Purchases are not allowed on this device.";
            emit_purchase_failed(TapticoUTF8(message));
            return;
        }
        self.productId = sku;
        if (self.cachedProduct != nil && [self.cachedProduct.productIdentifier isEqualToString:sku]) {
            SKPayment *payment = [SKPayment paymentWithProduct:self.cachedProduct];
            [[SKPaymentQueue defaultQueue] addPayment:payment];
            return;
        }
        self.pendingPurchase = YES;
        [self fetchProducts];
    });
}

- (void)restore {
    // Only called from the Restore Purchases button.
    on_main(^{
        [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
    });
}

- (void)syncLocalEntitlements {
    // Inspect unfinished / current queue without prompting Apple ID.
    on_main(^{
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
    });
}

- (BOOL)has_lifetime { return g_lifetime; }
- (NSString *)get_price { return g_price ?: @""; }
- (BOOL)is_price_ready { return g_price_ready; }

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    SKProduct *product = response.products.firstObject;
    NSString *localized = @"";
    if (product != nil) {
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        formatter.numberStyle = NSNumberFormatterCurrencyStyle;
        formatter.locale = product.priceLocale;
        localized = [formatter stringFromNumber:product.price] ?: @"";
    }
    NSString *missing = @"This product is not available in your App Store region.";
    NSString *loadFailed = @"Could not load App Store products. Check your connection.";
    on_main(^{
        if (request != self.currentRequest) {
            return;
        }
        self.currentRequest = nil;
        if (product == nil) {
            TapticoSetPrice(@"");
            BOOL wasPurchase = self.pendingPurchase;
            self.pendingPurchase = NO;
            if (wasPurchase) {
                emit_purchase_failed(TapticoUTF8(missing));
            } else {
                emit_products_failed(TapticoUTF8(loadFailed));
            }
            return;
        }
        self.cachedProduct = product;
        TapticoSetPrice(localized);
        if (g_price_ready) {
            emit_products_loaded(g_price_utf8.c_str());
        }
        if (self.pendingPurchase) {
            self.pendingPurchase = NO;
            SKPayment *payment = [SKPayment paymentWithProduct:product];
            [[SKPaymentQueue defaultQueue] addPayment:payment];
        }
    });
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    NSString *message = TapticoStoreErrorMessage(error);
    on_main(^{
        if (request != self.currentRequest) {
            return;
        }
        self.currentRequest = nil;
        BOOL wasPurchase = self.pendingPurchase;
        self.pendingPurchase = NO;
        TapticoMarkPriceUnavailable();
        if (wasPurchase) {
            emit_purchase_failed(TapticoUTF8(message));
        } else {
            emit_products_failed(TapticoUTF8(message));
        }
    });
}

- (void)requestDidFinish:(SKRequest *)request {
    on_main(^{
        if (self.currentRequest == request) {
            self.currentRequest = nil;
        }
    });
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
    (void)queue;
    for (SKPaymentTransaction *transaction in transactions) {
        NSString *sku = transaction.payment.productIdentifier ?: @"";
        NSString *expected = self.productId ?: g_product_id;
        if (![sku isEqualToString:expected]) {
            continue;
        }
        SKPaymentTransactionState state = transaction.transactionState;
        if (state == SKPaymentTransactionStatePurchased || state == SKPaymentTransactionStateRestored) {
            NSString *productId = [sku copy];
            on_main(^{
                g_lifetime = YES;
                emit_purchase_updated(TapticoUTF8(productId));
                emit_entitlements_updated(YES);
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
            });
            continue;
        }
        if (state == SKPaymentTransactionStateFailed) {
            NSError *error = transaction.error;
            BOOL cancelled = error != nil && [error.domain isEqualToString:SKErrorDomain] && error.code == SKErrorPaymentCancelled;
            NSString *message = cancelled ? @"Purchase cancelled." : TapticoStoreErrorMessage(error);
            on_main(^{
                emit_purchase_failed(TapticoUTF8(message));
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
            });
        }
    }
}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
    (void)queue;
    [self syncLocalEntitlements];
    on_main(^{
        emit_entitlements_updated(g_lifetime);
    });
}

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
    (void)queue;
    NSString *message = TapticoStoreErrorMessage(error);
    on_main(^{
        emit_purchase_failed(TapticoUTF8(message));
        emit_entitlements_updated(g_lifetime);
    });
}

@end

static TapticoStoreKit *g_storekit = nil;

extern "C" {

void storekit_init_impl() {
    if (g_storekit == nil) {
        g_storekit = [[TapticoStoreKit alloc] init];
    }
}

void storekit_deinit_impl() {
    g_storekit = nil;
}

void storekit_initialize(const char *product_id) {
    NSString *sku = product_id ? [NSString stringWithUTF8String:product_id] : @"";
    [g_storekit initialize:sku];
}

void storekit_purchase(const char *product_id) {
    NSString *sku = product_id ? [NSString stringWithUTF8String:product_id] : @"";
    [g_storekit purchase:sku];
}

void storekit_restore() {
    [g_storekit restore];
}

void storekit_request_review() {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (@available(iOS 16.0, *)) {
            UIWindowScene *scene = nil;
            for (UIScene *candidate in UIApplication.sharedApplication.connectedScenes) {
                if (candidate.activationState == UISceneActivationStateForegroundActive &&
                    [candidate isKindOfClass:[UIWindowScene class]]) {
                    scene = (UIWindowScene *)candidate;
                    break;
                }
            }
            if (scene == nil) {
                for (UIScene *candidate in UIApplication.sharedApplication.connectedScenes) {
                    if ([candidate isKindOfClass:[UIWindowScene class]]) {
                        scene = (UIWindowScene *)candidate;
                        break;
                    }
                }
            }
            if (scene != nil) {
                [SKStoreReviewController requestReviewInScene:scene];
            }
        }
    });
}

const char *storekit_get_price() {
    return g_price_utf8.c_str();
}

bool storekit_is_price_ready() {
    return [g_storekit is_price_ready];
}

bool storekit_has_lifetime() {
    return [g_storekit has_lifetime];
}

}
