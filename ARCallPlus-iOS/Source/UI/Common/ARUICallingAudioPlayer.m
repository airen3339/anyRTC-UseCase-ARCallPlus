//
//  ARUICallingAudioPlayer.m
//  ARUICalling
//
//  Created by 余生丶 on 2022/2/15.
//

#import "ARUICallingAudioPlayer.h"
#import <AVFoundation/AVFoundation.h>
#import "ARUICommonUtil.h"

NS_ASSUME_NONNULL_BEGIN

@interface ARUICallingAudioParam : NSObject

/// default is 0
@property (nonatomic, assign) NSTimeInterval startTime;

/// default is 10000
@property (nonatomic, assign) NSTimeInterval endTime;

/// default is NO
@property (nonatomic, assign) BOOL loop;

@end

@interface ARUICallingAudioPlayer : NSObject <AVAudioPlayerDelegate>

+ (instancetype)sharedInstance;

- (BOOL)playAudio:(NSURL *)url;

- (BOOL)playAudio:(NSURL *)url params:(ARUICallingAudioParam * _Nullable)param;

- (void)stopAudio;

#pragma mark - Private
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, assign) NSTimeInterval startTime;
@property (nonatomic, assign) NSTimeInterval endTime;
@property (nonatomic, assign) BOOL loop;
@property (nonatomic, strong) AVAudioPlayer *player;
@end

NS_ASSUME_NONNULL_END

BOOL playAudioWithFilePath(NSString *filePath) {
    ARUICallingAudioParam *param = [[ARUICallingAudioParam alloc] init];
    NSURL *url = [NSURL fileURLWithPath:filePath];
    if (!url) {
        return NO;
    }
    param.startTime = 1.5;
    param.loop = YES;
    return [[ARUICallingAudioPlayer sharedInstance] playAudio:url params:param];
}

BOOL playAudio(CallingAudioType type) {
    NSBundle *bundle = [ARUICommonUtil callingBundle];
    ARUICallingAudioParam *param = [[ARUICallingAudioParam alloc] init];
    switch (type) {
        case CallingAudioTypeHangup: {
            NSString *path = [[[bundle bundlePath] stringByAppendingPathComponent:@"AudioFile"] stringByAppendingPathComponent:@"hangup.mp3"];
            NSURL *url = [NSURL fileURLWithPath:path];
            if (!url) {
                return NO;
            }
            param.endTime = 2;
            return [[ARUICallingAudioPlayer sharedInstance] playAudio:url params:param];
        } break;
        case CallingAudioTypeCalled: {
            NSString *path = [[[bundle bundlePath] stringByAppendingPathComponent:@"AudioFile"] stringByAppendingPathComponent:@"ringing.wav"];
            NSURL *url = [NSURL fileURLWithPath:path];
            if (!url) {
                return NO;
            }
            param.startTime = 1.5;
            param.loop = YES;
            return [[ARUICallingAudioPlayer sharedInstance] playAudio:url params:param];
        } break;
        case CallingAudioTypeDial: {
            NSString *path = [[[bundle bundlePath] stringByAppendingPathComponent:@"AudioFile"] stringByAppendingPathComponent:@"dialing.mp3"];
            NSURL *url = [NSURL fileURLWithPath:path];
            if (!url) {
                return NO;
            }
            param.startTime = 2;
            param.loop = YES;
            return [[ARUICallingAudioPlayer sharedInstance] playAudio:url params:param];
        } break;
        default:
            break;
    }
    return NO;
}

void stopAudio(void) {
    [[ARUICallingAudioPlayer sharedInstance] stopAudio];
}


@implementation ARUICallingAudioParam
- (instancetype)init {
    if (self = [super init]) {
        self.endTime = 10000;
        self.startTime = 0;
        self.loop = NO;
    }
    return self;
}
@end

@implementation ARUICallingAudioPlayer

- (BOOL)playAudio:(NSURL *)url {
    return [self playAudio:url params:nil];
}

- (BOOL)playAudio:(NSURL *)url params:(ARUICallingAudioParam *)param {
    if (self.player != nil) {
        [self stopAudio];
    }
    NSError *error = nil;
    self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
    if (error) {
        return NO;
    }
    if (![self.player prepareToPlay]) {
        return NO;
    }
    if (param != nil) {
        self.startTime = param.startTime;
        self.endTime = param.endTime;
        self.loop = param.loop;
    }
    else {
        self.startTime = 0;
        self.endTime = 10000;
        self.loop = NO;
    }
    self.player.currentTime = self.startTime;
    self.player.delegate = self;
    BOOL res = [self.player play];
    if (self.endTime != 0 && res && self.endTime <= self.player.duration) {
        [self startDisplayLink];
    }
    return res;
}

- (void)resetStatus {
    self.loop = NO;
    self.startTime = 0;
    self.endTime = 10000;
    [self invalidateDisplayLink];
}

- (void)stopAudio {
    if (self.player == nil) {
        return;
    }
    [self.player stop];
    [self resetStatus];
    self.player = nil;
}

- (void)startDisplayLink {
    if (self.displayLink != nil) {
        [self invalidateDisplayLink];
    }
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkCallback:)];
    [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)invalidateDisplayLink {
    if (self.displayLink == nil) {
        return;
    }
    [self.displayLink invalidate];
    self.displayLink = nil;
}

- (void)displayLinkCallback:(CADisplayLink *)displayLink {
    if (self.player == nil || self.endTime <= 0 || !self.player.isPlaying) {
        return;
    }
    if (self.player.currentTime >= self.endTime) {
        if (self.loop) {
            [self.player pause];
            self.player.currentTime = self.startTime;
            [self.player play];
        }
        else {
            [self stopAudio];
        }
    }
}

#pragma mark - AVAudioPlayerDelegate
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    if (self.loop) {
        player.currentTime = self.startTime;
        [player play];
    }
    else {
        [self stopAudio];
    }
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error {
    if (error) {
        [self stopAudio];
    }
}

#pragma mark - initialize
+ (instancetype)sharedInstance {
    static ARUICallingAudioPlayer *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

@end
