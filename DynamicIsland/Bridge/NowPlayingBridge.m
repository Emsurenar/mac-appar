// NowPlayingBridge
//
// Since macOS 15.4 MediaRemote only answers processes signed by Apple, so this
// library is loaded into /usr/bin/perl (an Apple platform binary) and talks to
// the app over stdio:
//   stdout: one JSON object per line describing the current Now Playing state
//   stdin:  commands — toggle | play | pause | next | prev | seek <seconds>
// The process exits when stdin closes, so it never outlives the app.

#import <Foundation/Foundation.h>
#include <dlfcn.h>
#include <stdio.h>

typedef void (*MRGetInfoFn)(dispatch_queue_t, void (^)(CFDictionaryRef));
typedef void (*MRGetIsPlayingFn)(dispatch_queue_t, void (^)(Boolean));
typedef void (*MRGetClientFn)(dispatch_queue_t, void (^)(id));
typedef CFStringRef (*MRClientStringFn)(id);
typedef Boolean (*MRSendCommandFn)(int, CFDictionaryRef);
typedef void (*MRSetElapsedFn)(double);
typedef void (*MRRegisterFn)(dispatch_queue_t);

enum { kCmdPlay = 0, kCmdPause = 1, kCmdToggle = 2, kCmdNext = 4, kCmdPrevious = 5 };

static MRGetInfoFn MRGetInfo;
static MRGetIsPlayingFn MRGetIsPlaying;
static MRGetClientFn MRGetClient;
static MRClientStringFn MRClientBundleID;
static MRClientStringFn MRClientParentBundleID;
static MRSendCommandFn MRSendCommand;
static MRSetElapsedFn MRSetElapsed;

static dispatch_queue_t gQueue;
static NSData *gLastArtwork;
static NSString *gLastLine;
static BOOL gRefreshPending;

static void emit(NSDictionary *payload) {
    NSData *json = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    if (!json) return;
    NSString *line = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
    if ([line isEqualToString:gLastLine]) return;
    gLastLine = line;
    fprintf(stdout, "%s\n", line.UTF8String);
    fflush(stdout);
}

static id jsonSafe(id value) {
    if ([value isKindOfClass:[NSString class]] || [value isKindOfClass:[NSNumber class]]) return value;
    if ([value isKindOfClass:[NSDate class]]) return @([(NSDate *)value timeIntervalSince1970]);
    return nil;
}

static void refresh(void) {
    // Coalesce bursts of notifications into one fetch.
    if (gRefreshPending) return;
    gRefreshPending = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_MSEC), gQueue, ^{
        gRefreshPending = NO;
        MRGetClient(gQueue, ^(id client) {
            NSString *bundle = nil;
            if (client) {
                if (MRClientParentBundleID) bundle = (__bridge NSString *)MRClientParentBundleID(client);
                if (!bundle.length && MRClientBundleID) bundle = (__bridge NSString *)MRClientBundleID(client);
            }
            MRGetIsPlaying(gQueue, ^(Boolean playing) {
                MRGetInfo(gQueue, ^(CFDictionaryRef raw) {
                    NSDictionary *info = (__bridge NSDictionary *)raw;
                    if (!info.count) {
                        gLastArtwork = nil;
                        emit(@{ @"empty": @YES });
                        return;
                    }
                    NSMutableDictionary *out = [NSMutableDictionary dictionary];
                    out[@"playing"] = playing ? @YES : @NO;
                    if (bundle.length) out[@"bundle"] = bundle;
                    NSDictionary *keys = @{
                        @"title": @"kMRMediaRemoteNowPlayingInfoTitle",
                        @"artist": @"kMRMediaRemoteNowPlayingInfoArtist",
                        @"album": @"kMRMediaRemoteNowPlayingInfoAlbum",
                        @"duration": @"kMRMediaRemoteNowPlayingInfoDuration",
                        @"elapsed": @"kMRMediaRemoteNowPlayingInfoElapsedTime",
                        @"rate": @"kMRMediaRemoteNowPlayingInfoPlaybackRate",
                        @"timestamp": @"kMRMediaRemoteNowPlayingInfoTimestamp",
                    };
                    for (NSString *key in keys) {
                        id value = jsonSafe(info[keys[key]]);
                        if (value) out[key] = value;
                    }
                    // Artwork is large, so it is only sent when it changes.
                    NSData *artwork = info[@"kMRMediaRemoteNowPlayingInfoArtworkData"];
                    if (![artwork isKindOfClass:[NSData class]]) artwork = nil;
                    if (!(artwork == gLastArtwork || [artwork isEqualToData:gLastArtwork])) {
                        out[@"artwork"] = artwork ? [artwork base64EncodedStringWithOptions:0] : @"";
                        gLastArtwork = artwork;
                    }
                    emit(out);
                });
            });
        });
    });
}

static void handleCommand(NSString *line) {
    NSArray<NSString *> *parts = [line componentsSeparatedByString:@" "];
    NSString *cmd = parts.firstObject;
    if ([cmd isEqualToString:@"toggle"]) MRSendCommand(kCmdToggle, NULL);
    else if ([cmd isEqualToString:@"play"]) MRSendCommand(kCmdPlay, NULL);
    else if ([cmd isEqualToString:@"pause"]) MRSendCommand(kCmdPause, NULL);
    else if ([cmd isEqualToString:@"next"]) MRSendCommand(kCmdNext, NULL);
    else if ([cmd isEqualToString:@"prev"]) MRSendCommand(kCmdPrevious, NULL);
    else if ([cmd isEqualToString:@"seek"] && parts.count > 1) MRSetElapsed(parts[1].doubleValue);
    else if ([cmd isEqualToString:@"refresh"]) gLastLine = nil;
    refresh();
}

static void *load(void *lib, const char *name) {
    void *sym = dlsym(lib, name);
    if (!sym) fprintf(stderr, "NowPlayingBridge: missing %s\n", name);
    return sym;
}

__attribute__((visibility("default")))
void bridge_main(void *interpreter, void *cv) {
    (void)interpreter; (void)cv;
    @autoreleasepool {
        void *lib = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW);
        if (!lib) { fprintf(stderr, "NowPlayingBridge: MediaRemote unavailable\n"); exit(1); }
        MRGetInfo = load(lib, "MRMediaRemoteGetNowPlayingInfo");
        MRGetIsPlaying = load(lib, "MRMediaRemoteGetNowPlayingApplicationIsPlaying");
        MRGetClient = load(lib, "MRMediaRemoteGetNowPlayingClient");
        MRClientBundleID = load(lib, "MRNowPlayingClientGetBundleIdentifier");
        MRClientParentBundleID = load(lib, "MRNowPlayingClientGetParentAppBundleIdentifier");
        MRSendCommand = load(lib, "MRMediaRemoteSendCommand");
        MRSetElapsed = load(lib, "MRMediaRemoteSetElapsedTime");
        MRRegisterFn registerForNotifications = load(lib, "MRMediaRemoteRegisterForNowPlayingNotifications");
        if (!MRGetInfo || !MRGetIsPlaying || !MRGetClient || !MRSendCommand || !MRSetElapsed || !registerForNotifications) exit(1);

        setvbuf(stdout, NULL, _IOLBF, 0);
        gQueue = dispatch_queue_create("nowplaying.bridge", DISPATCH_QUEUE_SERIAL);
        registerForNotifications(gQueue);

        for (NSString *name in @[ @"kMRMediaRemoteNowPlayingInfoDidChangeNotification",
                                  @"kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification",
                                  @"kMRMediaRemoteNowPlayingApplicationDidChangeNotification",
                                  @"kMRMediaRemoteNowPlayingApplicationClientStateDidChange" ]) {
            [[NSNotificationCenter defaultCenter] addObserverForName:name object:nil queue:nil usingBlock:^(NSNotification *note) {
                dispatch_async(gQueue, ^{ refresh(); });
            }];
        }

        // Safety net for players that update silently.
        dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, gQueue);
        dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, 0), 2 * NSEC_PER_SEC, NSEC_PER_SEC / 4);
        dispatch_source_set_event_handler(timer, ^{ refresh(); });
        dispatch_resume(timer);

        [NSThread detachNewThreadWithBlock:^{
            char buffer[256];
            while (fgets(buffer, sizeof buffer, stdin)) {
                NSString *line = [[NSString stringWithUTF8String:buffer]
                    stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
                if (line.length) dispatch_async(gQueue, ^{ handleCommand(line); });
            }
            exit(0);
        }];

        CFRunLoopRun();
    }
}
