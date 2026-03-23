---
name: macos-gcd-analysis
description: Analyze Grand Central Dispatch (GCD) usage in macOS/iOS applications for security research and reverse engineering. Use this skill whenever the user needs to understand GCD queues, blocks, or parallelism in Objective-C/Swift code, hook GCD functions with Frida, or reverse engineer GCD structures in Ghidra. Trigger on mentions of dispatch_async, dispatch_sync, DispatchQueue, libdispatch, GCD queues, or any macOS/iOS concurrency analysis.
---

# macOS GCD Analysis Skill

This skill helps you analyze Grand Central Dispatch (GCD) usage in macOS and iOS applications for security research, reverse engineering, and understanding concurrent execution patterns.

## What is GCD?

**Grand Central Dispatch (GCD)**, also known as **libdispatch** (`libdispatch.dylib`), is Apple's technology for managing concurrent (multithreaded) execution on multicore hardware. Key concepts:

- **FIFO Queues**: GCD provides and manages queues to which applications submit tasks as **block objects**
- **Thread Pool Management**: GCD automatically creates and manages threads for executing tasks
- **No Manual Thread Creation**: Processes don't create new threads; GCD executes code with its own thread pool

### Why GCD Matters for Security Research

1. **Parallelism for attacks**: GCD is ideal for tasks requiring great parallelism (e.g., brute-forcing)
2. **Non-blocking operations**: Background tasks (network, file I/O, searches) run on GCD queues to avoid blocking the main thread
3. **Race conditions**: Concurrent queues can introduce race conditions that may be exploitable
4. **Hidden execution paths**: GCD blocks can contain logic that's harder to trace in static analysis

## Block Structure

Blocks are self-contained sections of code (like functions with arguments returning values). At the compiler level, blocks are `os_object`s formed by two structures:

### Block Literal Structure

```c
struct Block {
   void *isa;           // Points to block's class
   int flags;           // Indicates fields present in block descriptor
   int reserved;
   void *invoke;        // Function pointer to call
   struct BlockDescriptor *descriptor;
   // captured variables go here
};
```

**Block Classes (isa field):**
- `NSConcreteGlobalBlock` - Blocks from `__DATA.__const`
- `NSConcreteMallocBlock` - Blocks in the heap
- `NSConcreteStackBlock` - Blocks in the stack

### Block Descriptor

The descriptor size depends on data present (indicated by flags):
- Reserved bytes
- Size of the descriptor
- Pointer to Objective-C style signature (if `BLOCK_HAS_SIGNATURE` flag is set)
- Copy helper pointer (if variables are referenced)
- Dispose helper pointer (for freeing variables)

## Dispatch Queues

A dispatch queue is a named object providing FIFO ordering of blocks for execution.

### Queue Types

| Type | Description | Race Conditions |
|------|-------------|----------------|
| `DISPATCH_QUEUE_SERIAL` | Blocks execute one at a time | No |
| `DISPATCH_QUEUE_CONCURRENT` | Multiple blocks can execute simultaneously | Yes |

### Default Queues

| Queue | Function/Constant | Priority |
|-------|-------------------|----------|
| `.main-thread` | `dispatch_get_main_queue()` | Main thread |
| `.root.user-interactive-qos` | `DISPATCH_QUEUE_PRIORITY_HIGH` | Highest |
| `.root.default-qos` | `DISPATCH_QUEUE_PRIORITY_DEFAULT` | Default |
| `.root.utility-qos` | `DISPATCH_QUEUE_PRIORITY_NON_INTERACTIVE` | Utility |
| `.root.background-qos` | `DISPATCH_QUEUE_PRIORITY_BACKGROUND` | Background |
| `.root.maintenance-qos` | - | Lowest |

**Note**: The system decides which threads handle which queues at each time. Multiple threads might work in the same queue, or the same thread might work in different queues.

### Queue Attributes

When creating a queue with `dispatch_queue_create`, the third argument is `dispatch_queue_attr_t`:
- `DISPATCH_QUEUE_SERIAL` (actually NULL)
- `DISPATCH_QUEUE_CONCURRENT` (pointer to `dispatch_queue_attr_t` struct)

## Dispatch Objects

Libdispatch uses several object types, creatable with `dispatch_object_create`:

- `block` - Code blocks
- `data` - Data blocks
- `group` - Group of blocks
- `io` - Async I/O requests
- `mach` - Mach ports
- `mach_msg` - Mach messages
- `pthread_root_queue` - Queue with pthread thread pool
- `queue` - Dispatch queues
- `semaphore` - Semaphores
- `source` - Event sources

## Objective-C GCD Functions

### Core Functions

| Function | Behavior | Returns |
|----------|----------|----------|
| `dispatch_async(queue, block)` | Submits block for async execution | Immediately |
| `dispatch_sync(queue, block)` | Submits block, waits for completion | After block finishes |
| `dispatch_once(token, block)` | Executes block only once | After block finishes |
| `dispatch_async_and_wait(queue, block)` | Submits work item, waits for completion | After block finishes |

All functions expect: `dispatch_queue_t queue, dispatch_block_t block`

### Example: Parallel Execution

```objectivec
#import <Foundation/Foundation.h>

// Define a block
void (^backgroundTask)(void) = ^{
    for (int i = 0; i < 10; i++) {
        NSLog(@"Background task %d", i);
        sleep(1);
    }
};

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // Create a serial dispatch queue
        dispatch_queue_t backgroundQueue = dispatch_queue_create(
            "com.example.backgroundQueue", NULL);

        // Submit the block for asynchronous execution
        dispatch_async(backgroundQueue, backgroundTask);

        // Continue with other work on the main queue
        for (int i = 0; i < 10; i++) {
            NSLog(@"Main task %d", i);
            sleep(1);
        }
    }
    return 0;
}
```

## Swift GCD Usage

**`libswiftDispatch`** provides Swift bindings to GCD, wrapping C GCD APIs in a Swift-friendly interface.

### Swift Syntax

| Pattern | Description |
|---------|-------------|
| `DispatchQueue.global().sync { ... }` | Synchronous execution on global queue |
| `DispatchQueue.global().async { ... }` | Asynchronous execution on global queue |
| `let onceToken = DispatchOnce(); onceToken.perform { ... }` | Execute once |
| `async await` | Modern async/await pattern |

### Example: Swift Parallel Execution

```swift
import Foundation

// Define a closure (Swift equivalent of a block)
let backgroundTask: () -> Void = {
    for i in 0..<10 {
        print("Background task \(i)")
        sleep(1)
    }
}

// Entry point
autoreleasepool {
    // Create a dispatch queue
    let backgroundQueue = DispatchQueue(label: "com.example.backgroundQueue")

    // Submit the closure for asynchronous execution
    backgroundQueue.async(execute: backgroundTask)

    // Continue with other work on the main queue
    for i in 0..<10 {
        print("Main task \(i)")
        sleep(1)
    }
}
```

## Frida Hooking for GCD

Use Frida to hook into dispatch functions and extract queue names, backtraces, and blocks.

### Hooking Script

Use the [libdispatch.js script](https://github.com/seemoo-lab/frida-scripts/blob/main/scripts/libdispatch.js) to hook dispatch functions.

### Usage

```bash
frida -U <prog_name> -l libdispatch.js
```

### Example Output

```
dispatch_sync
Calling queue: com.apple.UIKit._UIReusePool.reuseSetAccess
Callback function: 0x19e3a6488 UIKitCore!__26-[_UIReusePool addObject:]_block_invoke
Backtrace:
0x19e3a6460 UIKitCore!-[_UIReusePool addObject:]
0x19e3a5db8 UIKitCore!-[UIGraphicsRenderer _enqueueContextForReuse:]
0x19e3a57fc UIKitCore!+[UIGraphicsRenderer _destroyCGContext:withRenderer:]
```

### What to Look For

1. **Queue names**: Identify which system or custom queues are being used
2. **Callback functions**: Find the actual block code being executed
3. **Backtraces**: Understand the call chain leading to GCD execution
4. **Timing**: When blocks are submitted vs. when they execute

## Ghidra Reverse Engineering

Ghidra doesn't natively understand `dispatch_block_t` or `swift_dispatch_block` structures. You need to declare them manually.

### Step 1: Declare Block Structures

Create the block structure in Ghidra:

```c
struct Block {
   void *isa;
   int flags;
   int reserved;
   void *invoke;
   struct BlockDescriptor *descriptor;
};

struct BlockDescriptor {
   int reserved;
   int size;
   void *copy_helper;
   void *dispose_helper;
   void *signature;  // if BLOCK_HAS_SIGNATURE
};
```

### Step 2: Find Block Usage

Look for references to "block" in the code to understand how the structure is being used.

### Step 3: Retype Variables

1. Right-click on the variable
2. Select "Retype Variable"
3. Choose `swift_dispatch_block` or `dispatch_block_t`

Ghidra will automatically rewrite the decompilation to use the correct structure.

### What to Look For

- **Block creation**: Where blocks are allocated/created
- **Block submission**: Where blocks are submitted to queues
- **Captured variables**: What data blocks capture from their environment
- **Queue types**: Serial vs. concurrent queue usage

## Security Analysis Checklist

When analyzing GCD usage for security:

- [ ] Identify all dispatch queues used (serial vs. concurrent)
- [ ] Map block execution paths and dependencies
- [ ] Look for race conditions in concurrent queues
- [ ] Check for sensitive data in captured block variables
- [ ] Analyze queue priorities and potential DoS vectors
- [ ] Hook GCD functions with Frida to trace execution
- [ ] Verify block lifecycle (copy/dispose helpers)
- [ ] Check for `dispatch_once` misuse (initialization races)

## Common Patterns to Investigate

1. **Brute-force operations**: GCD is often used for parallel password cracking or enumeration
2. **Background network requests**: API calls, data fetching hidden in background queues
3. **File operations**: Reading/writing sensitive files asynchronously
4. **UI updates**: Main queue blocks that update UI based on background results
5. **Initialization code**: `dispatch_once` blocks that set up critical state

## References

- [OS Internals, Volume I: User Mode by Jonathan Levin](https://www.amazon.com/MacOS-iOS-Internals-User-Mode/dp/099105556X)
- [Frida libdispatch.js script](https://github.com/seemoo-lab/frida-scripts/blob/main/scripts/libdispatch.js)
- [Apple GCD Documentation](https://developer.apple.com/documentation/dispatch)
