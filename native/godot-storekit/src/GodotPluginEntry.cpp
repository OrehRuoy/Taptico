// Godot 4.6 plugin glue is C++ (void storekit_init();) without extern "C".
// Same W4D / Spectrum Sync pattern: C++ Engine singleton wrapping ObjC StoreKit.

#include "core/config/engine.h"
#include "core/object/class_db.h"
#include "core/object/object.h"
#include "core/os/memory.h"
#include "core/string/ustring.h"
#include "core/variant/variant.h"

extern "C" {
void storekit_init_impl(void);
void storekit_deinit_impl(void);
void storekit_initialize(const char *product_id);
void storekit_purchase(const char *product_id);
void storekit_restore(void);
void storekit_request_review(void);
const char *storekit_get_price(void);
bool storekit_is_price_ready(void);
bool storekit_has_lifetime(void);
}

class StoreKitBridge : public Object {
	GDCLASS(StoreKitBridge, Object);

protected:
	static void _bind_methods() {
		ClassDB::bind_method(D_METHOD("initialize", "product_id"), &StoreKitBridge::initialize);
		ClassDB::bind_method(D_METHOD("purchase", "product_id"), &StoreKitBridge::purchase);
		ClassDB::bind_method(D_METHOD("restore"), &StoreKitBridge::restore);
		ClassDB::bind_method(D_METHOD("request_review"), &StoreKitBridge::request_review);
		ClassDB::bind_method(D_METHOD("get_price"), &StoreKitBridge::get_price);
		ClassDB::bind_method(D_METHOD("is_price_ready"), &StoreKitBridge::is_price_ready);
		ClassDB::bind_method(D_METHOD("has_lifetime"), &StoreKitBridge::has_lifetime);
		ADD_SIGNAL(MethodInfo("purchase_updated", PropertyInfo(Variant::STRING, "product_id")));
		ADD_SIGNAL(MethodInfo("purchase_failed", PropertyInfo(Variant::STRING, "message")));
		ADD_SIGNAL(MethodInfo("entitlements_updated", PropertyInfo(Variant::BOOL, "unlocked")));
		ADD_SIGNAL(MethodInfo("products_loaded", PropertyInfo(Variant::STRING, "price")));
		ADD_SIGNAL(MethodInfo("products_failed", PropertyInfo(Variant::STRING, "message")));
	}

public:
	void initialize(const String &product_id) { storekit_initialize(product_id.utf8().get_data()); }
	void purchase(const String &product_id) { storekit_purchase(product_id.utf8().get_data()); }
	void restore() { storekit_restore(); }
	void request_review() { storekit_request_review(); }
	String get_price() { return String::utf8(storekit_get_price()); }
	bool is_price_ready() { return storekit_is_price_ready(); }
	bool has_lifetime() { return storekit_has_lifetime(); }
};

static StoreKitBridge *storekit_singleton = nullptr;

void emit_purchase_updated(const char *product_id) {
	if (storekit_singleton) {
		storekit_singleton->emit_signal("purchase_updated", String::utf8(product_id));
	}
}

void emit_purchase_failed(const char *message) {
	if (storekit_singleton) {
		storekit_singleton->emit_signal("purchase_failed", String::utf8(message));
	}
}

void emit_entitlements_updated(bool unlocked) {
	if (storekit_singleton) {
		storekit_singleton->emit_signal("entitlements_updated", unlocked);
	}
}

void emit_products_loaded(const char *price) {
	if (storekit_singleton) {
		storekit_singleton->emit_signal("products_loaded", String::utf8(price));
	}
}

void emit_products_failed(const char *message) {
	if (storekit_singleton) {
		storekit_singleton->emit_signal("products_failed", String::utf8(message));
	}
}

void storekit_init() {
	storekit_init_impl();
	GDREGISTER_CLASS(StoreKitBridge);
	storekit_singleton = memnew(StoreKitBridge);
	Engine::get_singleton()->add_singleton(Engine::Singleton("StoreKit", storekit_singleton));
}

void storekit_deinit() {
	storekit_deinit_impl();
	if (storekit_singleton != nullptr) {
		if (Engine::get_singleton() != nullptr) {
			Engine::get_singleton()->remove_singleton("StoreKit");
		}
		memdelete(storekit_singleton);
		storekit_singleton = nullptr;
	}
}
