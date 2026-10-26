extends Node
## Cross-platform helpers. Branch new code here; leave existing OS checks alone.

const STORE_PLAY := "play"
const STORE_APP_STORE := "app_store"

const _OS_ANDROID := "Android"
const _OS_IOS := "iOS"


func is_android() -> bool:
	return OS.get_name() == _OS_ANDROID


func is_ios() -> bool:
	return OS.get_name() == _OS_IOS


func is_mobile() -> bool:
	return is_android() or is_ios()


func store_name() -> String:
	if is_ios():
		return STORE_APP_STORE
	if is_android():
		return STORE_PLAY
	return ""


func supports_billing() -> bool:
	return is_android() or is_ios()


func supports_in_app_review() -> bool:
	return is_android() or is_ios()


## Settings / paywall disclaimer for the current store.
## Lifetime unlock is a one-time purchase, not a subscription.
## Same insets as the carousel: left, top, right, bottom in viewport pixels.
func safe_margins(control: Control) -> Vector4:
	var win := Vector2(DisplayServer.window_get_size())
	var vis := control.get_viewport_rect().size
	if win.x < 8.0 or win.y < 8.0:
		return Vector4(8, 10, 8, 8)
	var safe := DisplayServer.get_display_safe_area()
	var sx := vis.x / win.x
	var sy := vis.y / win.y
	var left := maxf(8.0, float(safe.position.x) * sx)
	var top := maxf(8.0, float(safe.position.y) * sy)
	var right := maxf(8.0, float(win.x - safe.end.x) * sx)
	var bottom := maxf(8.0, float(win.y - safe.end.y) * sy)
	return Vector4(left, top, right, bottom)


func billing_disclaimer_text() -> String:
	if is_ios():
		return "Lifetime unlock is a one-time purchase through the App Store. Restore it on any device signed into the same Apple ID."
	if is_android():
		return "Lifetime unlock is a one-time purchase through Google Play. Restore it on any device signed into the same Google account."
	return "Lifetime unlock is a one-time purchase through Google Play / the App Store."
