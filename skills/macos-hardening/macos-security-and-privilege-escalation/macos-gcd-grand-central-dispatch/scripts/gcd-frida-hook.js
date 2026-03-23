/**
 * Frida script for hooking Grand Central Dispatch functions
 * Based on: https://github.com/seemoo-lab/frida-scripts/blob/main/scripts/libdispatch.js
 * 
 * Usage: frida -U <prog_name> -l gcd-frida-hook.js
 */

const libdispatch = Process.getModuleByName("libdispatch.dylib");

if (!libdispatch) {
    console.log("[!] libdispatch.dylib not found");
    return;
}

// Hook dispatch_async
const dispatch_async = libdispatch.getExportByName("dispatch_async");
if (dispatch_async) {
    Interceptor.attach(dispatch_async, {
        onEnter: function(args) {
            const queue = args[0];
            const block = args[1];
            
            // Try to get queue label
            let queueLabel = "unknown";
            try {
                const queueLabelPtr = Memory.readPointer(queue.add(0x10)); // Approximate offset
                if (queueLabelPtr) {
                    queueLabel = Memory.readUtf8String(queueLabelPtr);
                }
            } catch (e) {
                queueLabel = "(could not read)";
            }
            
            console.log("[+] dispatch_async called:");
            console.log("    Queue: " + queueLabel);
            console.log("    Block: " + block);
            console.log("    Backtrace:");
            console.log(Backtrace.formatBacktrace(Backtrace.get()));
        }
    });
}

// Hook dispatch_sync
const dispatch_sync = libdispatch.getExportByName("dispatch_sync");
if (dispatch_sync) {
    Interceptor.attach(dispatch_sync, {
        onEnter: function(args) {
            const queue = args[0];
            const block = args[1];
            
            let queueLabel = "unknown";
            try {
                const queueLabelPtr = Memory.readPointer(queue.add(0x10));
                if (queueLabelPtr) {
                    queueLabel = Memory.readUtf8String(queueLabelPtr);
                }
            } catch (e) {
                queueLabel = "(could not read)";
            }
            
            console.log("[+] dispatch_sync called:");
            console.log("    Queue: " + queueLabel);
            console.log("    Block: " + block);
            console.log("    Backtrace:");
            console.log(Backtrace.formatBacktrace(Backtrace.get()));
        }
    });
}

// Hook dispatch_once
const dispatch_once = libdispatch.getExportByName("dispatch_once");
if (dispatch_once) {
    Interceptor.attach(dispatch_once, {
        onEnter: function(args) {
            const predicate = args[0];
            const block = args[1];
            
            console.log("[+] dispatch_once called:");
            console.log("    Predicate: " + predicate);
            console.log("    Block: " + block);
            console.log("    Backtrace:");
            console.log(Backtrace.formatBacktrace(Backtrace.get()));
        }
    });
}

// Hook dispatch_queue_create
const dispatch_queue_create = libdispatch.getExportByName("dispatch_queue_create");
if (dispatch_queue_create) {
    Interceptor.attach(dispatch_queue_create, {
        onEnter: function(args) {
            const label = Memory.readUtf8String(args[0]);
            const attr = args[1];
            
            console.log("[+] dispatch_queue_create called:");
            console.log("    Label: " + label);
            console.log("    Attributes: " + attr);
        },
        onLeave: function(retval) {
            console.log("    Created queue: " + retval);
        }
    });
}

console.log("[*] GCD hooks installed");
console.log("[*] Hooked: dispatch_async, dispatch_sync, dispatch_once, dispatch_queue_create");
