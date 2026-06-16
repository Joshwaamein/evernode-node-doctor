#!/usr/bin/env node
/*
 * gp-probe.js - protocol-level probes for Evernode Node Doctor.
 *
 * Performs checks that cannot be done honestly in bash: a real TLS
 * handshake against the host's own user port (the path reputationd uses
 * each moment), and, when the Evernode client library is available, the
 * GP / HotPocket peer handshake "for real" rather than faking it.
 *
 * Design rules:
 *   - READ ONLY. Never starts/stops/mutates an instance. Never spins up
 *     a HotPocket contract (that risks the zombie-slot failure mode that
 *     collapses reputation).
 *   - NEVER fakes a pass. If a real check cannot run (missing library or
 *     cert), it returns {status:"skip", reason:...}, not "pass".
 *   - Output: a single JSON object on stdout. Diagnostics to stderr.
 *   - Exit codes: 0 pass, 1 fail, 3 skip/unavailable, 2 usage.
 *
 * Usage:
 *   node gp-probe.js userport --host <ip|domain> --port <p> [--timeout <ms>]
 *   node gp-probe.js gp       --host <ip|domain> --port <p> [--timeout <ms>]
 */

'use strict';

const tls = require('tls');
const net = require('net');

function out(obj) {
  process.stdout.write(JSON.stringify(obj) + '\n');
}

function parseArgs(argv) {
  const args = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith('--')) {
      const key = a.slice(2);
      const val = argv[i + 1] && !argv[i + 1].startsWith('--') ? argv[++i] : 'true';
      args[key] = val;
    } else {
      args._.push(a);
    }
  }
  return args;
}

/*
 * userport: open a TLS connection to <host>:<port> and confirm the TLS
 * handshake completes. Mirrors reputationd's step-3 path, which connects
 * to wss://<own-WAN-IP>:26205 with rejectUnauthorized:false (the listener
 * uses the private Sashimono appliance cert, not the public LE cert). We
 * do NOT verify the chain; we only assert the listener answers a TLS
 * handshake. A plain TCP connect runs first to tell "port closed/filtered"
 * apart from "TCP open but TLS refused".
 */
function probeUserPort(host, port, timeout) {
  return new Promise((resolve) => {
    const result = { check: 'userport', host, port };
    const tcp = net.connect({ host, port, timeout });
    let tcpDone = false;
    tcp.once('connect', () => {
      tcpDone = true;
      tcp.destroy();
      const socket = tls.connect(
        { host, port, timeout, rejectUnauthorized: false, servername: host },
        () => {
          const cert = socket.getPeerCertificate();
          result.status = 'pass';
          result.detail = 'TLS handshake completed on user port';
          if (cert && cert.valid_to) {
            result.peer_cert_valid_to = cert.valid_to;
            result.peer_cert_subject = (cert.subject && cert.subject.CN) || null;
          }
          socket.destroy();
          resolve(result);
        }
      );
      socket.setTimeout(timeout, () => {
        result.status = 'fail';
        result.detail = 'TCP open but TLS handshake timed out';
        socket.destroy();
        resolve(result);
      });
      socket.once('error', (err) => {
        result.status = 'fail';
        result.detail = 'TCP open but TLS handshake failed: ' + err.message;
        resolve(result);
      });
    });
    tcp.once('timeout', () => {
      if (!tcpDone) {
        result.status = 'fail';
        result.detail = 'TCP connect timed out (port closed, filtered, or hairpin unavailable)';
        tcp.destroy();
        resolve(result);
      }
    });
    tcp.once('error', (err) => {
      if (!tcpDone) {
        result.status = 'fail';
        result.detail = 'TCP connect failed: ' + err.message;
        resolve(result);
      }
    });
  });
}


/*
 * gp: the real GP / HotPocket peer handshake. Requires the Evernode
 * client library (the same one reputationd uses). We try common
 * Sashimono install locations. If unavailable, SKIP honestly.
 */
async function probeGp(host, port, timeout) {
  const result = { check: 'gp', host, port };
  const candidates = [
    'hotpocket-js-client',
    'evernode-js-client',
    '/usr/bin/sashimono/reputationd/node_modules/hotpocket-js-client',
    '/usr/bin/sashimono/mb-xrpl/node_modules/hotpocket-js-client',
  ];

  let HotPocket = null;
  let loadedFrom = null;
  for (const c of candidates) {
    try {
      // eslint-disable-next-line global-require
      const mod = require(c);
      HotPocket = mod.default || mod.HotPocket || mod;
      loadedFrom = c;
      break;
    } catch (_) {
      /* try next */
    }
  }

  if (!HotPocket || typeof HotPocket.generateKeys !== 'function') {
    result.status = 'skip';
    result.reason =
      'HotPocket client library not found. The real GP handshake needs ' +
      'the Evernode client lib (present on a registered host). Use the ' +
      'external onledger.net host-test for an authoritative cluster / ' +
      'peer-visa check.';
    return result;
  }

  try {
    const keys = await HotPocket.generateKeys();
    const client = await HotPocket.createClient(
      [`wss://${host}:${port}`],
      keys,
      { connectionTimeoutMs: timeout }
    );
    const connected = await client.connect();
    if (connected) {
      result.status = 'pass';
      result.detail = `HotPocket handshake succeeded (lib: ${loadedFrom})`;
      await client.close();
    } else {
      result.status = 'fail';
      result.detail = 'HotPocket client could not connect to user port';
    }
  } catch (err) {
    result.status = 'fail';
    result.detail = 'HotPocket handshake error: ' + err.message;
  }
  return result;
}

async function main() {
  const argv = process.argv.slice(2);
  const mode = argv[0];
  const args = parseArgs(argv.slice(1));
  const host = args.host;
  const port = parseInt(args.port, 10);
  const timeout = parseInt(args.timeout || '10000', 10);

  if (!mode || !host || !port) {
    out({ status: 'usage', detail: 'mode --host <h> --port <p> required' });
    process.exit(2);
  }

  let res;
  if (mode === 'userport') {
    res = await probeUserPort(host, port, timeout);
  } else if (mode === 'gp') {
    res = await probeGp(host, port, timeout);
  } else {
    out({ status: 'usage', detail: 'unknown mode: ' + mode });
    process.exit(2);
  }

  out(res);
  if (res.status === 'pass') process.exit(0);
  if (res.status === 'skip') process.exit(3);
  process.exit(1);
}

main().catch((err) => {
  out({ status: 'fail', detail: 'unexpected error: ' + (err && err.message) });
  process.exit(1);
});
