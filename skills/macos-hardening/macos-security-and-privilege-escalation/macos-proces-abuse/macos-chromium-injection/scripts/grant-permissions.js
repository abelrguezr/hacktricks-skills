#!/usr/bin/env node
/**
 * macOS Chromium Injection - Grant Permissions via CDP
 * Usage: node grant-permissions.js [host] [port] [origin]
 *
 * Only use on systems you own or have explicit authorization to test.
 */

import CDP from 'chrome-remote-interface';

const HOST = process.argv[2] || '127.0.0.1';
const PORT = parseInt(process.argv[3]) || 9222;
const ORIGIN = process.argv[4] || '*';

const PERMISSIONS = ['camera', 'microphone', 'geolocation', 'notifications'];

console.log(`[+] Connecting to CDP at ${HOST}:${PORT}`);
console.log(`[+] Granting permissions for origin: ${ORIGIN}`);

(async () => {
  try {
    const client = await CDP({ host: HOST, port: PORT });
    const { Browser } = client;

    // Grant all permissions
    await Browser.grantPermissions({
      origin: ORIGIN,
      permissions: PERMISSIONS
    });

    console.log(`[+] Granted permissions: ${PERMISSIONS.join(', ')}`);

    // Set geolocation override (optional)
    const { Emulation } = client;
    await Emulation.setGeolocationOverride({
      latitude: 37.7749,
      longitude: -122.4194,
      accuracy: 100
    });

    console.log(`[+] Geolocation overridden to San Francisco`);

    await client.close();
    console.log('[+] Done');
  } catch (error) {
    console.error(`[!] Error: ${error.message}`);
    process.exit(1);
  }
})();
