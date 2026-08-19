#import "haptics_plugin.h"
#import <UIKit/UIKit.h>
#import <CoreHaptics/CoreHaptics.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

@protocol HapticsBridge <NSObject>
- (void)light;
- (void)medium;
- (void)heavy;
- (void)soft;
- (void)rigid;
- (void)selection;
- (void)impact:(float)intensity;
- (void)doublePulse;
- (BOOL)isSupported;
- (BOOL)isCharging;
- (void)configurePlaybackAudioSession;
@end

@interface TapticoHaptics : NSObject <HapticsBridge>
@property(nonatomic, strong) CHHapticEngine *engine;
@property(nonatomic, assign) BOOL coreHapticsAvailable;
@property(nonatomic, assign) BOOL feedbackAvailable;
@property(nonatomic, strong) UIImpactFeedbackGenerator *lightGen;
@property(nonatomic, strong) UIImpactFeedbackGenerator *mediumGen;
@property(nonatomic, strong) UIImpactFeedbackGenerator *heavyGen;
@property(nonatomic, strong) UIImpactFeedbackGenerator *softGen;
@property(nonatomic, strong) UIImpactFeedbackGenerator *rigidGen;
@property(nonatomic, strong) UISelectionFeedbackGenerator *selectionGen;
@end

@implementation TapticoHaptics

- (instancetype)init {
    self = [super init];
    if (self) {
        self.coreHapticsAvailable = NO;
        self.feedbackAvailable = NO;
        [self setupHaptics];
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
        [self configurePlaybackAudioSession];
    }
    return self;
}

- (void)setupHaptics {
    if (@available(iOS 13.0, *)) {
        BOOL supports = [CHHapticEngine capabilitiesForHardware].supportsHaptics;
        if (supports) {
            NSError *error = nil;
            CHHapticEngine *engine = [[CHHapticEngine alloc] initAndReturnError:&error];
            if (engine != nil && error == nil) {
                NSError *startError = nil;
                [engine startAndReturnError:&startError];
                if (startError == nil) {
                    self.engine = engine;
                    self.coreHapticsAvailable = YES;
                    __weak TapticoHaptics *weakSelf = self;
                    engine.resetHandler = ^{
                        NSError *restartError = nil;
                        [weakSelf.engine startAndReturnError:&restartError];
                        if (restartError != nil) {
                            weakSelf.engine = nil;
                            weakSelf.coreHapticsAvailable = NO;
                        }
                    };
                    engine.stoppedHandler = ^(CHHapticEngineStoppedReason reason) {
                        (void)reason;
                    };
                }
            }
        }
    }

    // Always install UIKit generators as fallback (older iPhones, iPod touch, some iPads).
    @try {
        self.lightGen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
        self.mediumGen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        self.heavyGen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
        if (@available(iOS 13.0, *)) {
            self.softGen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleSoft];
            self.rigidGen = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleRigid];
        } else {
            self.softGen = self.lightGen;
            self.rigidGen = self.heavyGen;
        }
        self.selectionGen = [[UISelectionFeedbackGenerator alloc] init];
        [self.lightGen prepare];
        [self.mediumGen prepare];
        [self.heavyGen prepare];
        self.feedbackAvailable = YES;
    } @catch (__unused NSException *exception) {
        self.feedbackAvailable = NO;
    }
}

- (void)configurePlaybackAudioSession {
    // Theremin / brown noise is an instrument: keep playing when the Ring/Silent switch is on.
    NSError *error = nil;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback
                    mode:AVAudioSessionModeDefault
                 options:0
                   error:&error];
    if (error == nil) {
        [session setActive:YES error:&error];
    }
}

- (void)fireImpact:(UIImpactFeedbackGenerator *)generator {
    if (!self.feedbackAvailable || generator == nil) {
        return;
    }
    [generator impactOccurred];
}

- (void)light { [self fireImpact:self.lightGen]; }
- (void)medium { [self fireImpact:self.mediumGen]; }
- (void)heavy { [self fireImpact:self.heavyGen]; }
- (void)soft { [self fireImpact:self.softGen ?: self.lightGen]; }
- (void)rigid { [self fireImpact:self.rigidGen ?: self.heavyGen]; }

- (void)selection {
    if (!self.feedbackAvailable || self.selectionGen == nil) {
        return;
    }
    [self.selectionGen selectionChanged];
}

- (void)impact:(float)intensity {
    intensity = fmaxf(0.0f, fminf(1.0f, intensity));
    if (intensity <= 0.001f) {
        return;
    }
    if (self.coreHapticsAvailable && self.engine != nil) {
        if (@available(iOS 13.0, *)) {
            CHHapticEventParameter *amp = [[CHHapticEventParameter alloc]
                initWithParameterID:CHHapticEventParameterIDHapticIntensity value:intensity];
            CHHapticEventParameter *sharp = [[CHHapticEventParameter alloc]
                initWithParameterID:CHHapticEventParameterIDHapticSharpness value:0.5f];
            CHHapticEvent *event = [[CHHapticEvent alloc]
                initWithEventType:CHHapticEventTypeHapticTransient
                parameters:@[amp, sharp]
                relativeTime:0];
            NSError *patternError = nil;
            CHHapticPattern *pattern = [[CHHapticPattern alloc]
                initWithEvents:@[event] parameters:@[] error:&patternError];
            if (patternError != nil || pattern == nil) {
                [self fallbackImpact:intensity];
                return;
            }
            NSError *playerError = nil;
            id<CHHapticPatternPlayer> player = [self.engine createPlayerWithPattern:pattern error:&playerError];
            if (playerError != nil || player == nil) {
                [self fallbackImpact:intensity];
                return;
            }
            [player startAtTime:0 error:nil];
            return;
        }
    }
    [self fallbackImpact:intensity];
}

- (void)fallbackImpact:(float)intensity {
    if (!self.feedbackAvailable) {
        return;
    }
    if (@available(iOS 13.0, *)) {
        UIImpactFeedbackGenerator *gen = intensity > 0.66f ? self.heavyGen : (intensity > 0.33f ? self.mediumGen : self.lightGen);
        [gen impactOccurredWithIntensity:intensity];
        return;
    }
    [self fireImpact:self.mediumGen];
}

- (void)doublePulse {
    if (self.coreHapticsAvailable && self.engine != nil) {
        [self impact:0.7f];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self impact:0.35f];
        });
        return;
    }
    [self fireImpact:self.mediumGen];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self fireImpact:self.lightGen];
    });
}

- (BOOL)isSupported {
    return self.coreHapticsAvailable || self.feedbackAvailable;
}

- (BOOL)isCharging {
    UIDeviceBatteryState state = [UIDevice currentDevice].batteryState;
    return state == UIDeviceBatteryStateCharging || state == UIDeviceBatteryStateFull;
}

@end

static TapticoHaptics *g_haptics = nil;

void register_godot_singleton(const char *name, void *instance) __attribute__((weak));
void unregister_godot_singleton(const char *name) __attribute__((weak));

void haptics_init() {
    g_haptics = [[TapticoHaptics alloc] init];
    if (register_godot_singleton) {
        register_godot_singleton("Haptics", (__bridge void *)g_haptics);
    }
}

void haptics_deinit() {
    if (unregister_godot_singleton) {
        unregister_godot_singleton("Haptics");
    }
    g_haptics = nil;
}
