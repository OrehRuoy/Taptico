#import "haptics_plugin.h"
#import <UIKit/UIKit.h>
#import <CoreHaptics/CoreHaptics.h>
#import <AVFoundation/AVFoundation.h>
#import <MetricKit/MetricKit.h>
#import <objc/runtime.h>
#include <string>

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
@property(atomic, strong) CHHapticEngine *engine;
@property(nonatomic, assign) BOOL coreHapticsAvailable;
@property(nonatomic, assign) BOOL engineNeedsStart;
@property(nonatomic, assign) BOOL feedbackAvailable;
@property(nonatomic, strong) UIImpactFeedbackGenerator *lightGen;
@property(nonatomic, strong) UIImpactFeedbackGenerator *mediumGen;
@property(nonatomic, strong) UIImpactFeedbackGenerator *heavyGen;
@property(nonatomic, strong) UIImpactFeedbackGenerator *softGen;
@property(nonatomic, strong) UIImpactFeedbackGenerator *rigidGen;
@property(nonatomic, strong) UISelectionFeedbackGenerator *selectionGen;
@end

static NSObject *TapticoDiagnosticsLock(void) {
    static NSObject *lock = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        lock = [[NSObject alloc] init];
    });
    return lock;
}

static long long TapticoCrashStamp(NSString *name) {
    if (name.length < 8 || ![name hasPrefix:@"mx_"] || ![name hasSuffix:@".json"]) {
        return -1;
    }
    NSString *stem = [name substringWithRange:NSMakeRange(3, name.length - 8)];
    if (stem.length == 0) {
        return -1;
    }
    NSCharacterSet *digits = [NSCharacterSet decimalDigitCharacterSet];
    if ([stem rangeOfCharacterFromSet:digits.invertedSet].location != NSNotFound) {
        return -1;
    }
    return stem.longLongValue;
}

static NSString *TapticoDiagnosticsDirectory(BOOL create) {
    NSArray<NSString *> *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docs = paths.firstObject;
    if (docs.length == 0) {
        return nil;
    }
    NSString *directory = [docs stringByAppendingPathComponent:@"diagnostics"];
    if (create) {
        [[NSFileManager defaultManager] createDirectoryAtPath:directory
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];
    }
    return directory;
}

static NSArray<NSString *> *TapticoCrashReportNames(NSString *directory) {
    if (directory.length == 0) {
        return @[];
    }
    NSArray<NSString *> *names = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:nil];
    NSMutableArray<NSString *> *reports = [NSMutableArray array];
    for (NSString *name in names) {
        if (TapticoCrashStamp(name) >= 0) {
            [reports addObject:name];
        }
    }
    [reports sortUsingComparator:^NSComparisonResult(NSString *lhs, NSString *rhs) {
        long long left = TapticoCrashStamp(lhs);
        long long right = TapticoCrashStamp(rhs);
        if (left < right) {
            return NSOrderedAscending;
        }
        if (left > right) {
            return NSOrderedDescending;
        }
        return [lhs compare:rhs];
    }];
    return reports;
}

static void TapticoWriteDiagnosticJSON(NSData *json) {
    if (json.length == 0) {
        return;
    }
    @synchronized(TapticoDiagnosticsLock()) {
        NSString *directory = TapticoDiagnosticsDirectory(YES);
        if (directory.length == 0) {
            return;
        }
        NSFileManager *files = [NSFileManager defaultManager];
        long long stamp = (long long)([NSDate date].timeIntervalSince1970 * 1000.0);
        NSString *path = [directory stringByAppendingPathComponent:[NSString stringWithFormat:@"mx_%lld.json", stamp]];
        while ([files fileExistsAtPath:path]) {
            stamp += 1;
            path = [directory stringByAppendingPathComponent:[NSString stringWithFormat:@"mx_%lld.json", stamp]];
        }
        NSError *error = nil;
        if (![json writeToFile:path options:NSDataWritingAtomic error:&error]) {
            return;
        }
        NSMutableArray<NSString *> *reports = [TapticoCrashReportNames(directory) mutableCopy];
        while (reports.count > 5) {
            NSString *oldest = reports.firstObject;
            [files removeItemAtPath:[directory stringByAppendingPathComponent:oldest] error:nil];
            [reports removeObjectAtIndex:0];
        }
    }
}

static BOOL TapticoHasCrashReports(void) {
    @synchronized(TapticoDiagnosticsLock()) {
        NSString *directory = TapticoDiagnosticsDirectory(NO);
        return TapticoCrashReportNames(directory).count > 0;
    }
}

static NSString *TapticoLatestCrashJSON(void) {
    @synchronized(TapticoDiagnosticsLock()) {
        NSString *directory = TapticoDiagnosticsDirectory(NO);
        NSArray<NSString *> *reports = TapticoCrashReportNames(directory);
        NSString *newest = reports.lastObject;
        if (newest.length == 0 || directory.length == 0) {
            return @"";
        }
        NSString *path = [directory stringByAppendingPathComponent:newest];
        NSData *data = [NSData dataWithContentsOfFile:path];
        if (data.length == 0) {
            return @"";
        }
        NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return text ?: @"";
    }
}

API_AVAILABLE(ios(14.0))
@interface TapticoMetricSubscriber : NSObject <MXMetricManagerSubscriber>
@end

API_AVAILABLE(ios(14.0))
@implementation TapticoMetricSubscriber

- (void)didReceiveDiagnosticPayloads:(NSArray<MXDiagnosticPayload *> *)payloads API_AVAILABLE(ios(14.0)) {
    for (MXDiagnosticPayload *payload in payloads) {
        if (payload.crashDiagnostics.count == 0 && payload.hangDiagnostics.count == 0) {
            continue;
        }
        NSData *json = payload.JSONRepresentation;
        if (json.length == 0) {
            continue;
        }
        TapticoWriteDiagnosticJSON(json);
    }
}

@end

static id g_metric_subscriber = nil;

@implementation TapticoHaptics {
    CFAbsoluteTime _lastImpactTime;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _lastImpactTime = -1.0;
        self.coreHapticsAvailable = NO;
        self.engineNeedsStart = NO;
        self.feedbackAvailable = NO;
        [self setupHaptics];
        [self registerLifecycleObservers];
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
        [self configurePlaybackAudioSession];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)registerLifecycleObservers {
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self
               selector:@selector(applicationDidBecomeActive:)
                   name:UIApplicationDidBecomeActiveNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(applicationDidEnterBackground:)
                   name:UIApplicationDidEnterBackgroundNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(audioSessionInterrupted:)
                   name:AVAudioSessionInterruptionNotification
                 object:nil];
}

- (void)setupHaptics {
    if (@available(iOS 13.0, *)) {
        BOOL supports = [CHHapticEngine capabilitiesForHardware].supportsHaptics;
        if (supports) {
            NSError *error = nil;
            CHHapticEngine *engine = [[CHHapticEngine alloc] initAndReturnError:&error];
            if (engine != nil && error == nil) {
                // Set before the first start. They stay set across later stop/start cycles.
                engine.playsHapticsOnly = YES;
                engine.autoShutdownEnabled = YES;
                __weak TapticoHaptics *weakSelf = self;
                // Handlers are not the main thread. Only flag a restart; never nil the engine here.
                engine.resetHandler = ^{
                    dispatch_async(dispatch_get_main_queue(), ^{
                        weakSelf.engineNeedsStart = YES;
                    });
                };
                engine.stoppedHandler = ^(CHHapticEngineStoppedReason reason) {
                    (void)reason;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        weakSelf.engineNeedsStart = YES;
                    });
                };
                self.engine = engine;
                self.coreHapticsAvailable = YES;
                self.engineNeedsStart = YES;
                [self ensureEngineStarted];
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

- (BOOL)ensureEngineStarted {
    if (![NSThread isMainThread]) {
        return NO;
    }
    if (@available(iOS 13.0, *)) {
        CHHapticEngine *engine = self.engine;
        if (engine == nil) {
            return NO;
        }
        if (!self.engineNeedsStart) {
            return self.coreHapticsAvailable;
        }
        @try {
            engine.playsHapticsOnly = YES;
            engine.autoShutdownEnabled = YES;
            NSError *error = nil;
            BOOL started = [engine startAndReturnError:&error];
            if (!started || error != nil) {
                return NO;
            }
        } @catch (__unused NSException *exception) {
            // A live engine rejects those setters. Leave it running and use UIKit this once.
            self.engineNeedsStart = NO;
            return NO;
        }
        self.engineNeedsStart = NO;
        self.coreHapticsAvailable = YES;
        return YES;
    }
    return NO;
}

- (void)applicationDidBecomeActive:(NSNotification *)notification {
    (void)notification;
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self applicationDidBecomeActive:notification];
        });
        return;
    }
    self.engineNeedsStart = YES;
}

- (void)applicationDidEnterBackground:(NSNotification *)notification {
    (void)notification;
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self applicationDidEnterBackground:notification];
        });
        return;
    }
    if (@available(iOS 13.0, *)) {
        CHHapticEngine *engine = self.engine;
        if (engine != nil) {
            [engine stopWithCompletionHandler:^(NSError *error) {
                (void)error;
            }];
        }
    }
    self.engineNeedsStart = YES;
}

- (void)audioSessionInterrupted:(NSNotification *)notification {
    NSNumber *typeNumber = notification.userInfo[AVAudioSessionInterruptionTypeKey];
    if (typeNumber.unsignedIntegerValue != AVAudioSessionInterruptionTypeEnded) {
        return;
    }
    dispatch_block_t resume = ^{
        NSError *error = nil;
        [[AVAudioSession sharedInstance] setActive:YES error:&error];
        (void)error;
        self.engineNeedsStart = YES;
    };
    if ([NSThread isMainThread]) {
        resume();
    } else {
        dispatch_async(dispatch_get_main_queue(), resume);
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
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self impact:intensity];
        });
        return;
    }
    BOOL engineReady = [self ensureEngineStarted];
    intensity = fmaxf(0.0f, fminf(1.0f, intensity));
    if (intensity <= 0.001f) {
        return;
    }
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (_lastImpactTime >= 0.0 && (now - _lastImpactTime) < 0.015) {
        return;
    }
    _lastImpactTime = now;
    if (engineReady && self.engine != nil) {
        if (@available(iOS 13.0, *)) {
            @try {
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
                    self.engineNeedsStart = YES;
                    [self fallbackImpact:intensity];
                    return;
                }
                NSError *startError = nil;
                BOOL started = [player startAtTime:0 error:&startError];
                if (!started || startError != nil) {
                    self.engineNeedsStart = YES;
                    [self fallbackImpact:intensity];
                    return;
                }
                return;
            } @catch (__unused NSException *exception) {
                self.engineNeedsStart = YES;
                [self fallbackImpact:intensity];
                return;
            }
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
static std::string g_latest_crash_utf8;

extern "C" {

static void haptics_start_on_main(void) {
    if (g_haptics == nil) {
        g_haptics = [[TapticoHaptics alloc] init];
    }
    if (@available(iOS 14.0, *)) {
        if (g_metric_subscriber == nil) {
            TapticoMetricSubscriber *subscriber = [[TapticoMetricSubscriber alloc] init];
            [[MXMetricManager sharedManager] addSubscriber:subscriber];
            g_metric_subscriber = subscriber;
        }
    }
}

static void haptics_stop_on_main(void) {
    if (@available(iOS 14.0, *)) {
        if (g_metric_subscriber != nil) {
            [[MXMetricManager sharedManager] removeSubscriber:(id<MXMetricManagerSubscriber>)g_metric_subscriber];
            g_metric_subscriber = nil;
        }
    }
    g_haptics = nil;
}

void haptics_init_impl() {
    if ([NSThread isMainThread]) {
        haptics_start_on_main();
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            haptics_start_on_main();
        });
    }
}

void haptics_deinit_impl() {
    if ([NSThread isMainThread]) {
        haptics_stop_on_main();
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            haptics_stop_on_main();
        });
    }
}

void haptics_light() { [g_haptics light]; }
void haptics_medium() { [g_haptics medium]; }
void haptics_heavy() { [g_haptics heavy]; }
void haptics_soft() { [g_haptics soft]; }
void haptics_rigid() { [g_haptics rigid]; }
void haptics_selection() { [g_haptics selection]; }
void haptics_impact(float intensity) { [g_haptics impact:intensity]; }
void haptics_double_pulse() { [g_haptics doublePulse]; }
bool haptics_is_supported() { return [g_haptics isSupported]; }
bool haptics_is_charging() { return [g_haptics isCharging]; }
void haptics_configure_playback() { [g_haptics configurePlaybackAudioSession]; }

bool haptics_has_crash_reports(void) {
    return TapticoHasCrashReports() ? true : false;
}

const char *haptics_get_latest_crash_report(void) {
    NSString *text = TapticoLatestCrashJSON();
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    if (data == nil || data.length == 0) {
        g_latest_crash_utf8.clear();
        return g_latest_crash_utf8.c_str();
    }
    g_latest_crash_utf8.assign(static_cast<const char *>(data.bytes), static_cast<size_t>(data.length));
    return g_latest_crash_utf8.c_str();
}

}
