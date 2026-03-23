// macOS EndpointSecurity Detection Client
// Monitors for thread injection and task port abuse events
// Run with: swift es-detection-client.swift

import EndpointSecurity
import Foundation

// Event types to monitor for thread injection detection
let subscriptions: [ESSubscription] = [
    .authGetTask,           // Task port requests
    .notifyRemoteThreadCreate,  // Remote thread creation
    .notifyThreadSetState      // Thread register manipulation (macOS 14+)
]

func createESClient() throws -> ESClient {
    return try ESClient(subscriptions: subscriptions) { _, message in
        handleESMessage(message)
    }
}

func handleESMessage(_ message: ESMessage) {
    switch message {
    case .authGetTask(let event):
        print("[AUTH_GET_TASK] pid: \(event.target.pid) requested by pid: \(event.source.pid)")
        print("  Target: \(event.target.path)")
        print("  Source: \(event.source.path)")
        
    case .remoteThreadCreate(let event):
        print("[REMOTE_THREAD_CREATE] pid: \(event.target.pid) by pid: \(event.thread.pid)")
        print("  Target: \(event.target.path)")
        print("  Thread creator: \(event.thread.path)")
        
    case .threadSetState(let event):
        print("[THREAD_SET_STATE] pid: \(event.target.pid) by pid: \(event.source.pid)")
        print("  Target: \(event.target.path)")
        print("  Source: \(event.source.path)")
        
    default:
        break
    }
}

// Main execution
print("Starting EndpointSecurity monitoring...")
print("Monitoring for thread injection events")
print("Press Ctrl+C to stop\n")

do {
    let client = try createESClient()
    RunLoop.main.run()
} catch {
    print("Error creating ES client: \(error)")
    print("Make sure you have appropriate permissions")
    exit(1)
}
