package com.godot.game;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.media.AudioAttributes;
import android.os.BatteryManager;
import android.os.Build;
import android.os.VibrationAttributes;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.os.VibratorManager;
import android.provider.Settings;
import android.util.Log;

/**
 * Haptic patterns for Taptico. Numbers are named so they can be tuned per device.
 * Called from GDScript through JavaClassWrapper.
 */
public final class TapticoHapticsBridge {
	private static final String TAG = "TapticoHaptics";

	private static final float SELECTION_SCALE = 0.6f;
	private static final float SOFT_LOW_TICK_SCALE = 0.7f;
	private static final float SOFT_TICK_SCALE = 0.5f;
	private static final float LIGHT_SCALE = 0.4f;
	private static final float MEDIUM_SCALE = 0.7f;
	private static final float RIGID_SCALE = 0.9f;
	private static final float HEAVY_THUD_SCALE = 0.9f;
	private static final float HEAVY_CLICK_SCALE = 1.0f;
	private static final float DOUBLE_FIRST_SCALE = 0.7f;
	private static final float DOUBLE_SECOND_SCALE = 0.35f;
	private static final int DOUBLE_GAP_MS = 50;

	private static final int SELECTION_MS = 8;
	private static final int SELECTION_AMP = 60;
	private static final int SELECTION_ONOFF_MS = 6;
	private static final float SELECTION_ONOFF_MIN = 0.3f;

	private static final int SOFT_MS = 12;
	private static final int SOFT_AMP = 70;
	private static final int SOFT_ONOFF_MS = 8;

	private static final int LIGHT_MS = 12;
	private static final int LIGHT_AMP = 100;
	private static final int LIGHT_ONOFF_MS = 10;

	private static final int MEDIUM_MS = 18;
	private static final int MEDIUM_AMP = 160;
	private static final int MEDIUM_ONOFF_MS = 14;

	private static final int RIGID_MS = 10;
	private static final int RIGID_AMP = 230;
	private static final int RIGID_ONOFF_MS = 10;

	private static final int HEAVY_MS = 25;
	private static final int HEAVY_AMP = 255;
	private static final int HEAVY_ONOFF_MS = 22;

	private static final float IMPACT_T3_TICK = 0.33f;
	private static final float IMPACT_T3_CLICK = 0.66f;
	private static final float IMPACT_T1_MIN = 0.2f;
	private static final int IMPACT_T2_BASE_MS = 8;
	private static final int IMPACT_T2_SPAN_MS = 17;
	private static final int IMPACT_T2_BASE_AMP = 40;
	private static final int IMPACT_T2_SPAN_AMP = 215;
	private static final int IMPACT_T1_BASE_MS = 8;
	private static final int IMPACT_T1_SPAN_MS = 14;

	private static Activity activity;
	private static Vibrator vibrator;
	private static int tier;

	private TapticoHapticsBridge() {
	}

	public static void init(Activity a) {
		try {
			activity = a;
			vibrator = resolveVibrator(a);
			tier = computeTier();
			Log.i(TAG, "tier=" + tier);
		} catch (Exception e) {
			tier = 0;
			Log.w(TAG, "init failed", e);
		}
	}

	public static int getTier() {
		return tier;
	}

	public static boolean isCharging() {
		try {
			if (activity == null) {
				return false;
			}
			Intent sticky = activity.registerReceiver(null, new IntentFilter(Intent.ACTION_BATTERY_CHANGED));
			if (sticky == null) {
				return false;
			}
			int status = sticky.getIntExtra(BatteryManager.EXTRA_STATUS, -1);
			return status == BatteryManager.BATTERY_STATUS_CHARGING || status == BatteryManager.BATTERY_STATUS_FULL;
		} catch (Exception e) {
			Log.w(TAG, "isCharging failed", e);
			return false;
		}
	}

	public static boolean isTouchFeedbackEnabled() {
		try {
			if (activity == null) {
				return true;
			}
			int enabled = Settings.System.getInt(
					activity.getContentResolver(),
					Settings.System.HAPTIC_FEEDBACK_ENABLED,
					1);
			return enabled != 0;
		} catch (Exception e) {
			Log.w(TAG, "isTouchFeedbackEnabled failed", e);
			return true;
		}
	}

	public static void play(String kind, float s) {
		try {
			if (vibrator == null || tier <= 0 || kind == null) {
				return;
			}
			float scale = clamp01(s);
			switch (kind) {
				case "selection":
					playSelection(scale);
					break;
				case "soft":
					playSoft(scale);
					break;
				case "light":
					playLight(scale);
					break;
				case "medium":
					playMedium(scale);
					break;
				case "rigid":
					playRigid(scale);
					break;
				case "heavy":
					playHeavy(scale);
					break;
				case "impact":
					playImpact(scale);
					break;
				case "double":
					playDouble(scale);
					break;
				default:
					Log.w(TAG, "unknown kind " + kind);
					break;
			}
		} catch (Exception e) {
			Log.w(TAG, "play failed", e);
		}
	}

	private static void playSelection(float s) {
		if (tier >= 4) {
			primitive(VibrationEffect.Composition.PRIMITIVE_TICK, SELECTION_SCALE * s, 0);
		} else if (tier == 3) {
			predefined(VibrationEffect.EFFECT_TICK);
		} else if (tier == 2) {
			oneShot(SELECTION_MS, amp(SELECTION_AMP, s));
		} else if (s >= SELECTION_ONOFF_MIN) {
			onOff(SELECTION_ONOFF_MS);
		}
	}

	private static void playSoft(float s) {
		if (tier >= 4) {
			if (Build.VERSION.SDK_INT >= 31) {
				primitive(VibrationEffect.Composition.PRIMITIVE_LOW_TICK, SOFT_LOW_TICK_SCALE * s, 0);
			} else {
				primitive(VibrationEffect.Composition.PRIMITIVE_TICK, SOFT_TICK_SCALE * s, 0);
			}
		} else if (tier == 3) {
			predefined(VibrationEffect.EFFECT_TICK);
		} else if (tier == 2) {
			oneShot(SOFT_MS, amp(SOFT_AMP, s));
		} else {
			onOff(SOFT_ONOFF_MS);
		}
	}

	private static void playLight(float s) {
		if (tier >= 4) {
			primitive(VibrationEffect.Composition.PRIMITIVE_CLICK, LIGHT_SCALE * s, 0);
		} else if (tier == 3) {
			predefined(VibrationEffect.EFFECT_TICK);
		} else if (tier == 2) {
			oneShot(LIGHT_MS, amp(LIGHT_AMP, s));
		} else {
			onOff(LIGHT_ONOFF_MS);
		}
	}

	private static void playMedium(float s) {
		if (tier >= 4) {
			primitive(VibrationEffect.Composition.PRIMITIVE_CLICK, MEDIUM_SCALE * s, 0);
		} else if (tier == 3) {
			predefined(VibrationEffect.EFFECT_CLICK);
		} else if (tier == 2) {
			oneShot(MEDIUM_MS, amp(MEDIUM_AMP, s));
		} else {
			onOff(MEDIUM_ONOFF_MS);
		}
	}

	private static void playRigid(float s) {
		if (tier >= 4) {
			primitive(VibrationEffect.Composition.PRIMITIVE_CLICK, RIGID_SCALE * s, 0);
		} else if (tier == 3) {
			predefined(VibrationEffect.EFFECT_CLICK);
		} else if (tier == 2) {
			oneShot(RIGID_MS, amp(RIGID_AMP, s));
		} else {
			onOff(RIGID_ONOFF_MS);
		}
	}

	private static void playHeavy(float s) {
		if (tier >= 4) {
			if (Build.VERSION.SDK_INT >= 31) {
				primitive(VibrationEffect.Composition.PRIMITIVE_THUD, HEAVY_THUD_SCALE * s, 0);
			} else {
				primitive(VibrationEffect.Composition.PRIMITIVE_CLICK, HEAVY_CLICK_SCALE * s, 0);
			}
		} else if (tier == 3) {
			predefined(VibrationEffect.EFFECT_HEAVY_CLICK);
		} else if (tier == 2) {
			oneShot(HEAVY_MS, amp(HEAVY_AMP, s));
		} else {
			onOff(HEAVY_ONOFF_MS);
		}
	}

	private static void playImpact(float i) {
		if (tier >= 4) {
			primitive(VibrationEffect.Composition.PRIMITIVE_CLICK, i, 0);
		} else if (tier == 3) {
			if (i < IMPACT_T3_TICK) {
				predefined(VibrationEffect.EFFECT_TICK);
			} else if (i < IMPACT_T3_CLICK) {
				predefined(VibrationEffect.EFFECT_CLICK);
			} else {
				predefined(VibrationEffect.EFFECT_HEAVY_CLICK);
			}
		} else if (tier == 2) {
			int ms = IMPACT_T2_BASE_MS + Math.round(IMPACT_T2_SPAN_MS * i);
			int amplitude = IMPACT_T2_BASE_AMP + Math.round(IMPACT_T2_SPAN_AMP * i);
			oneShot(ms, clampAmp(amplitude));
		} else if (i >= IMPACT_T1_MIN) {
			onOff(IMPACT_T1_BASE_MS + Math.round(IMPACT_T1_SPAN_MS * i));
		}
	}

	private static void playDouble(float s) {
		if (tier >= 4) {
			vibrate(VibrationEffect.startComposition()
					.addPrimitive(VibrationEffect.Composition.PRIMITIVE_CLICK, clamp01(DOUBLE_FIRST_SCALE * s), 0)
					.addPrimitive(VibrationEffect.Composition.PRIMITIVE_CLICK, clamp01(DOUBLE_SECOND_SCALE * s), DOUBLE_GAP_MS)
					.compose());
		} else if (tier == 3) {
			predefined(VibrationEffect.EFFECT_DOUBLE_CLICK);
		} else if (tier == 2) {
			waveform(new long[] {0, 15, 50, 10}, new int[] {0, amp(180, s), 0, amp(90, s)});
		} else {
			waveform(new long[] {0, 14, 50, 8}, null);
		}
	}

	private static void primitive(int primitiveId, float primitiveScale, int delayMs) {
		vibrate(VibrationEffect.startComposition()
				.addPrimitive(primitiveId, clamp01(primitiveScale), delayMs)
				.compose());
	}

	private static void predefined(int effectId) {
		vibrate(VibrationEffect.createPredefined(effectId));
	}

	private static void oneShot(int ms, int amplitude) {
		vibrate(VibrationEffect.createOneShot(Math.max(1, ms), clampAmp(amplitude)));
	}

	private static void onOff(int ms) {
		if (Build.VERSION.SDK_INT >= 26) {
			vibrate(VibrationEffect.createOneShot(Math.max(1, ms), VibrationEffect.DEFAULT_AMPLITUDE));
		} else if (vibrator != null) {
			vibrator.vibrate(Math.max(1, ms));
		}
	}

	private static void waveform(long[] timings, int[] amplitudes) {
		if (Build.VERSION.SDK_INT >= 26) {
			if (amplitudes == null) {
				vibrate(VibrationEffect.createWaveform(timings, -1));
			} else {
				vibrate(VibrationEffect.createWaveform(timings, amplitudes, -1));
			}
		} else if (vibrator != null) {
			vibrator.vibrate(timings, -1);
		}
	}

	private static void vibrate(VibrationEffect effect) {
		if (vibrator == null || effect == null) {
			return;
		}
		if (Build.VERSION.SDK_INT >= 33) {
			VibrationAttributes attrs = VibrationAttributes.createForUsage(VibrationAttributes.USAGE_MEDIA);
			vibrator.vibrate(effect, attrs);
		} else {
			AudioAttributes attrs = new AudioAttributes.Builder()
					.setUsage(AudioAttributes.USAGE_GAME)
					.build();
			vibrator.vibrate(effect, attrs);
		}
	}

	private static Vibrator resolveVibrator(Activity a) {
		if (Build.VERSION.SDK_INT >= 31) {
			VibratorManager manager = (VibratorManager) a.getSystemService(Context.VIBRATOR_MANAGER_SERVICE);
			if (manager != null) {
				return manager.getDefaultVibrator();
			}
		}
		return (Vibrator) a.getSystemService(Context.VIBRATOR_SERVICE);
	}

	private static int computeTier() {
		if (vibrator == null || !vibrator.hasVibrator()) {
			return 0;
		}
		if (Build.VERSION.SDK_INT >= 31 && vibrator.areAllPrimitivesSupported(
				VibrationEffect.Composition.PRIMITIVE_CLICK,
				VibrationEffect.Composition.PRIMITIVE_TICK)) {
			return 4;
		}
		if (Build.VERSION.SDK_INT == 30) {
			boolean[] supported = vibrator.arePrimitivesSupported(
					VibrationEffect.Composition.PRIMITIVE_CLICK,
					VibrationEffect.Composition.PRIMITIVE_TICK);
			if (supported.length >= 2 && supported[0] && supported[1]) {
				return 4;
			}
		}
		if (Build.VERSION.SDK_INT >= 29) {
			boolean effects = Build.VERSION.SDK_INT < 30;
			if (!effects) {
				effects = vibrator.areAllEffectsSupported(
						VibrationEffect.EFFECT_TICK,
						VibrationEffect.EFFECT_CLICK,
						VibrationEffect.EFFECT_HEAVY_CLICK) == Vibrator.VIBRATION_EFFECT_SUPPORT_YES;
			}
			if (effects) {
				return 3;
			}
		}
		if (Build.VERSION.SDK_INT >= 26 && vibrator.hasAmplitudeControl()) {
			return 2;
		}
		return 1;
	}

	private static int amp(int base, float s) {
		return clampAmp(Math.round(base * clamp01(s)));
	}

	private static int clampAmp(int value) {
		return Math.max(1, Math.min(255, value));
	}

	private static float clamp01(float value) {
		if (value < 0f) {
			return 0f;
		}
		if (value > 1f) {
			return 1f;
		}
		return value;
	}
}
