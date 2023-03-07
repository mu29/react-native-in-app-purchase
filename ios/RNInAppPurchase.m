#import "RNInAppPurchase.h"

#import <StoreKit/StoreKit.h>

@interface RNInAppPurchase() <SKRequestDelegate> {
    BOOL hasListeners;
    NSMutableDictionary* productsMap;
    NSMutableDictionary* transactionsMap;
}

@end

@implementation RNInAppPurchase

- (instancetype) init {
    if (self = [super init]) {
        [[SKPaymentQueue defaultQueue] addTransactionObserver: self];
    }
    productsMap = [[NSMutableDictionary alloc] init];
    transactionsMap = [[NSMutableDictionary alloc] init];

    return self;
}

- (void) dealloc {
    [[SKPaymentQueue defaultQueue] removeTransactionObserver: self];
}

+ (BOOL) requiresMainQueueSetup {
    return YES;
}

RCT_EXPORT_MODULE();

RCT_EXPORT_METHOD(configure: (RCTPromiseResolveBlock) resolve
                  rejector: (RCTPromiseRejectBlock) reject) {
    resolve(@([SKPaymentQueue canMakePayments]));
}

RCT_EXPORT_METHOD(fetchProducts: (NSArray*) products) {
    NSSet* identifiers = [NSSet setWithArray: [products valueForKey: @"id"]];
    SKProductsRequest* productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers: identifiers];
    productsRequest.delegate = self;
    [productsRequest start];
}

RCT_EXPORT_METHOD(purchase: (NSString*) productId
                  offerId: (NSString*) offerId
                  userId: (NSString*) userId
                  keyIdentifier: (NSString*) keyIdentifier
                  nonce: (NSString*) nonceString
                  signature: (NSString*) signature
                  timestamp: (NSNumber*) timestamp) {
    SKProduct* product = productsMap[productId];

    if (!product) {
        [self sendEvent: @"iap:onPurchaseFailure" body: @{ @"message": @"Invalid product id" }];
        return;
    }

    SKMutablePayment* payment = [SKMutablePayment paymentWithProduct: product];
    payment.applicationUsername = userId;
    
    if (@available(iOS 12.2, *)) {
        NSUUID* nonce = nil;
        if (nonceString != nil) {
            nonce = [[NSUUID new] initWithUUIDString:nonceString];
        }
        
        if (offerId != nil && keyIdentifier != nil && nonce != nil && signature != nil && timestamp != nil) {
            SKPaymentDiscount* paymentDiscount = [[SKPaymentDiscount new] initWithIdentifier:offerId keyIdentifier:keyIdentifier nonce:nonce signature:signature timestamp:timestamp];
            payment.paymentDiscount = paymentDiscount;
        }
    }
    
    [[SKPaymentQueue defaultQueue] addPayment: payment];
}

RCT_EXPORT_METHOD(finalize: (NSDictionary*) purchase
                  resolver: (RCTPromiseResolveBlock) resolve
                  rejector: (RCTPromiseRejectBlock) reject) {
    NSString* transactionId = purchase[@"transactionId"];
    SKPaymentTransaction* transaction = transactionsMap[transactionId];
    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
    resolve(@{ @"message": @"Finalize success" });
}

RCT_EXPORT_METHOD(flush: (RCTPromiseResolveBlock) resolve
                  rejector: (RCTPromiseRejectBlock) reject) {
    NSArray<SKPaymentTransaction*>* transactions = [[SKPaymentQueue defaultQueue] transactions];
    NSMutableArray* items = [NSMutableArray array];

    for (SKPaymentTransaction* transaction in transactions) {
        NSURL* receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
        NSData* receipt = [[NSData alloc] initWithContentsOfURL: receiptURL];

        if (!receipt) {
            [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
            continue;
        }

        if (!transaction.transactionIdentifier) {
            continue;
        }

        NSArray* productIds = @[transaction.payment.productIdentifier];
        NSDictionary* item = @{
                               @"productIds": productIds,
                               @"transactionId": transaction.transactionIdentifier,
                               @"transactionDate": @(transaction.transactionDate.timeIntervalSince1970 * 1000),
                               @"receipt": [receipt base64EncodedStringWithOptions: 0]
                               };

        [transactionsMap setObject: transaction forKey: transaction.transactionIdentifier];
        [items addObject: item];
    }

    resolve(items);
}

RCT_EXPORT_METHOD(fetchReceipt: (RCTPromiseResolveBlock) resolve
                  rejector: (RCTPromiseRejectBlock) reject) {
    NSURL* receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData* receipt = [[NSData alloc] initWithContentsOfURL: receiptURL];
    
    if (receipt == nil) {
        resolve(nil);
        return;
    }
    
    NSString* encodedReceipt = [receipt base64EncodedStringWithOptions: 0];
    resolve(encodedReceipt);
}

- (void) startObserving {
    hasListeners = true;
}

- (void) stopObserving {
    hasListeners = false;
}

- (void) sendEvent: (NSString*) eventName body: (id) body {
    if (hasListeners) {
        [self sendEventWithName: eventName body: body];
    }
}

- (NSArray<NSString*>*) supportedEvents {
    return @[
             @"iap:onFetchProductsSuccess",
             @"iap:onFetchProductsFailure",
             @"iap:onPurchaseSuccess",
             @"iap:onPurchaseFailure"
             ];
}

- (void) productsRequest: (SKProductsRequest*) request didReceiveResponse: (SKProductsResponse*) response {
    NSMutableArray* items = [NSMutableArray array];

    for (SKProduct* product in response.products) {
        NSString* title = product.localizedTitle ? product.localizedTitle : @"";
        NSString* description = product.localizedDescription ? product.localizedDescription : @"";
        NSString* currency = @"";

        if (@available(iOS 10.0, *)) {
            currency = product.priceLocale.currencyCode;
        }

        NSDictionary* item = @{
                               @"productId": product.productIdentifier,
                               @"price": [product.price stringValue],
                               @"currency": currency,
                               @"title": title,
                               @"description": description
                               };
        [items addObject: item];
        [productsMap setObject: product forKey: product.productIdentifier];
    }

    [self sendEvent: @"iap:onFetchProductsSuccess" body: items];
}

- (void) paymentQueue: (SKPaymentQueue*) queue updatedTransactions: (NSArray<SKPaymentTransaction*>*) transactions {
    for (SKPaymentTransaction* transaction in transactions) {
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchased: {
                NSURL* receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
                NSData* receipt = [[NSData alloc] initWithContentsOfURL: receiptURL];

                if (!receipt) {
                    [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
                    return;
                }

                NSArray* productIds = @[transaction.payment.productIdentifier];
                NSDictionary* item = @{
                                       @"productIds": productIds,
                                       @"transactionId": transaction.transactionIdentifier,
                                       @"transactionDate": @(transaction.transactionDate.timeIntervalSince1970 * 1000),
                                       @"receipt": [receipt base64EncodedStringWithOptions: 0]
                                       };

                [transactionsMap setObject: transaction forKey: transaction.transactionIdentifier];
                [self sendEvent: @"iap:onPurchaseSuccess" body: item];
                break;
            }
            case SKPaymentTransactionStateFailed: {
                [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
                NSDictionary* error = @{
                                        @"code": [@(transaction.error.code) stringValue],
                                        @"message": transaction.error.localizedDescription
                                        };
                [self sendEvent: @"iap:onPurchaseFailure" body: error];
                break;
            }
            case SKPaymentTransactionStateRestored:
                [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
                break;
            case SKPaymentTransactionStateDeferred:
                break;
            case SKPaymentTransactionStatePurchasing:
                break;
        }
    }
}

@end
