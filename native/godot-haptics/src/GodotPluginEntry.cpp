// Godot 4.6 plugin glue is C++ (void haptics_init();) without extern "C".
// Same W4D / Spectrum Sync pattern: C++ Engine singleton wrapping ObjC impl.

#include "core/config/engine.h"
#include "core/object/class_db.h"
#include "core/object/object.h"
#include "core/os/memory.h"
#include "core/string/ustring.h"

extern "C" {
void haptics_init_impl(void);
void haptics_deinit_impl(void);
void haptics_light(void);
void haptics_medium(void);
void haptics_heavy(void);
void haptics_soft(void);
void haptics_rigid(void);
void haptics_selection(void);
void haptics_impact(float intensity);
void haptics_double_pulse(void);
bool haptics_is_supported(void);
bool haptics_is_charging(void);
void haptics_configure_playback(void);
bool haptics_has_crash_reports(void);
const char *haptics_get_latest_crash_report(void);
}

class HapticsBridge : public Object {
	GDCLASS(HapticsBridge, Object);

protected:
	static void _bind_methods() {
		ClassDB::bind_method(D_METHOD("light"), &HapticsBridge::light);
		ClassDB::bind_method(D_METHOD("medium"), &HapticsBridge::medium);
		ClassDB::bind_method(D_METHOD("heavy"), &HapticsBridge::heavy);
		ClassDB::bind_method(D_METHOD("soft"), &HapticsBridge::soft);
		ClassDB::bind_method(D_METHOD("rigid"), &HapticsBridge::rigid);
		ClassDB::bind_method(D_METHOD("selection"), &HapticsBridge::selection);
		ClassDB::bind_method(D_METHOD("impact", "intensity"), &HapticsBridge::impact);
		ClassDB::bind_method(D_METHOD("double_pulse"), &HapticsBridge::double_pulse);
		ClassDB::bind_method(D_METHOD("is_supported"), &HapticsBridge::is_supported);
		ClassDB::bind_method(D_METHOD("is_charging"), &HapticsBridge::is_charging);
		ClassDB::bind_method(D_METHOD("configurePlaybackAudioSession"), &HapticsBridge::configure_playback);
		ClassDB::bind_method(D_METHOD("has_crash_reports"), &HapticsBridge::has_crash_reports);
		ClassDB::bind_method(D_METHOD("get_latest_crash_report"), &HapticsBridge::get_latest_crash_report);
	}

public:
	void light() { haptics_light(); }
	void medium() { haptics_medium(); }
	void heavy() { haptics_heavy(); }
	void soft() { haptics_soft(); }
	void rigid() { haptics_rigid(); }
	void selection() { haptics_selection(); }
	void impact(float intensity) { haptics_impact(intensity); }
	void double_pulse() { haptics_double_pulse(); }
	bool is_supported() { return haptics_is_supported(); }
	bool is_charging() { return haptics_is_charging(); }
	void configure_playback() { haptics_configure_playback(); }
	bool has_crash_reports() { return haptics_has_crash_reports(); }
	String get_latest_crash_report() {
		const char *report = haptics_get_latest_crash_report();
		if (report == nullptr || report[0] == '\0') {
			return String();
		}
		return String::utf8(report);
	}
};

static HapticsBridge *haptics_singleton = nullptr;

void haptics_init() {
	haptics_init_impl();
	GDREGISTER_CLASS(HapticsBridge);
	haptics_singleton = memnew(HapticsBridge);
	Engine::get_singleton()->add_singleton(Engine::Singleton("Haptics", haptics_singleton));
}

void haptics_deinit() {
	haptics_deinit_impl();
	if (haptics_singleton != nullptr) {
		if (Engine::get_singleton() != nullptr) {
			Engine::get_singleton()->remove_singleton("Haptics");
		}
		memdelete(haptics_singleton);
		haptics_singleton = nullptr;
	}
}
