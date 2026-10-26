package com.godot.game;

import android.app.Activity;
import android.util.Log;

import com.google.android.play.core.review.ReviewInfo;
import com.google.android.play.core.review.ReviewManager;
import com.google.android.play.core.review.ReviewManagerFactory;

/**
 * Play In-App Review fallback when the InappReview plugin singleton is missing.
 * Does not open a browser.
 */
public final class InAppReviewBridge {
	private static final String TAG = "InAppReviewBridge";

	private InAppReviewBridge() {
	}

	public static void requestReview(Activity activity) {
		if (activity == null) {
			Log.w(TAG, "Activity unavailable; cannot request in-app review.");
			return;
		}
		activity.runOnUiThread(() -> launchReviewFlow(activity));
	}

	private static void launchReviewFlow(Activity activity) {
		try {
			ReviewManager reviewManager = ReviewManagerFactory.create(activity);
			reviewManager.requestReviewFlow().addOnCompleteListener(task -> {
				if (!task.isSuccessful()) {
					Log.w(TAG, "In-app review flow request failed.", task.getException());
					return;
				}
				ReviewInfo reviewInfo = task.getResult();
				reviewManager.launchReviewFlow(activity, reviewInfo).addOnCompleteListener(flowTask -> {
					if (flowTask.isSuccessful()) {
						Log.i(TAG, "In-app review flow finished.");
					} else {
						Log.w(TAG, "In-app review flow launch failed.", flowTask.getException());
					}
				});
			});
		} catch (Exception e) {
			Log.w(TAG, "In-app review unavailable: " + e.getMessage());
		}
	}
}
