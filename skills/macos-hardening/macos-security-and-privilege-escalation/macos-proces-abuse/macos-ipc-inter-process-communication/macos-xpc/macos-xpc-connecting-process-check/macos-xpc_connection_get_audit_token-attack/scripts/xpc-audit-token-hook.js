/**
 * Frida hook for detecting xpc_connection_get_audit_token calls
 * outside of XPC event handlers (potential audit token spoofing vulnerability)
 * 
 * Usage:
 *   frida -U -f <process-name> -l xpc-audit-token-hook.js --no-pause
 *   frida -p <PID> -l xpc-audit-token-hook.js
 * 
 * This hook flags invocations where the user stack does not include
 * the event-delivery path (_xpc_connection_mach_event), indicating
 * the audit token is being fetched outside the message handler.
 */

Interceptor.attach(
  Module.getExportByName(null, 'xpc_connection_get_audit_token'),
  {
    onEnter(args) {
      const connection = args[0];
      const auditTokenPtr = args[1];
      
      // Capture backtrace
      const bt = Thread.backtrace(this.context, Backtracer.ACCURATE)
        .map(DebugSymbol.fromAddress)
        .join('\n');
      
      // Check if we're in the event handler path
      const isInEventHandler = bt.includes('_xpc_connection_mach_event');
      
      if (!isInEventHandler) {
        console.log('\n[!] xpc_connection_get_audit_token called OUTSIDE event handler');
        console.log('    Connection: ' + connection);
        console.log('    Audit token buffer: ' + auditTokenPtr);
        console.log('\n    Backtrace:');
        console.log(bt);
        console.log('\n    This may indicate a vulnerable pattern where the audit token');
        console.log('    can be overwritten by messages from other senders.');
        console.log('    Consider using xpc_dictionary_get_audit_token instead.\n');
      }
    },
    onLeave(retval) {
      // Optional: log successful calls
      // console.log('xpc_connection_get_audit_token returned: ' + retval);
    }
  }
);

// Optional: Also hook xpc_connection_get_pid to detect mixed per-connection/per-message patterns
Interceptor.attach(
  Module.getExportByName(null, 'xpc_connection_get_pid'),
  {
    onEnter(args) {
      const connection = args[0];
      const pidPtr = args[1];
      
      const bt = Thread.backtrace(this.context, Backtracer.ACCURATE)
        .map(DebugSymbol.fromAddress)
        .join('\n');
      
      const isInEventHandler = bt.includes('_xpc_connection_mach_event');
      
      if (!isInEventHandler) {
        console.log('\n[!] xpc_connection_get_pid called OUTSIDE event handler');
        console.log('    Connection: ' + connection);
        console.log('    PID buffer: ' + pidPtr);
        console.log('\n    Backtrace:');
        console.log(bt);
        console.log('\n    If this is used alongside xpc_connection_get_audit_token,');
        console.log('    it may indicate a mixed per-connection/per-message pattern.\n');
      }
    }
  }
);

console.log('\n[*] XPC audit token hook installed');
console.log('    Monitoring xpc_connection_get_audit_token and xpc_connection_get_pid');
console.log('    for calls outside event handlers.\n');
