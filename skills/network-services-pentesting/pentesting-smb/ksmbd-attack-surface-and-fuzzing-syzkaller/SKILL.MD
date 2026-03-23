---
name: ksmbd-syzkaller-fuzzing
description: Use this skill whenever you need to fuzz the Linux in-kernel SMB server (ksmbd) with syzkaller, set up SMB2/SMB3 protocol fuzzing, configure ksmbd for maximum attack surface, or build stateful fuzzing harnesses for SMB protocol testing. Make sure to use this skill when the user mentions ksmbd, SMB fuzzing, syzkaller kernel fuzzing, SMB2/SMB3 protocol testing, or wants to find vulnerabilities in the Linux SMB server implementation.
---

# ksmbd Attack Surface & SMB2/SMB3 Protocol Fuzzing (syzkaller)

A skill for fuzzing the Linux in-kernel SMB server (ksmbd) using syzkaller. This covers expanding the protocol attack surface, building stateful harnesses, generating grammar-valid PDUs, and leveraging syzkaller features like focus_areas and ANYBLOB.

**Target scope**: SMB2/SMB3 over TCP. Kerberos and RDMA are intentionally out-of-scope to keep the harness simple.

---

## Quick Start

1. **Configure ksmbd** for maximum attack surface (see [Expand Attack Surface](#expand-ksmbd-attack-surface-via-configuration))
2. **Set up authentication** for fuzzing (see [Authentication Setup](#authentication-and-rate-limiting-adjustments-for-fuzzing))
3. **Build a stateful harness** that chains SMB2 operations (see [Stateful Harness](#stateful-harness-extract-resources-and-chain-requests))
4. **Generate grammar-valid PDUs** using the SMB2 grammar (see [Grammar-Driven Generation](#grammar-driven-smb2-generation-valid-pdus))
5. **Configure focus_areas** to target weakly-covered code (see [Directed Fuzzing](#directed-fuzzing-with-focus_areas))
6. **Seed with ANYBLOB** from real pcaps to break plateaus (see [ANYBLOB Seeding](#breaking-coverage-plateaus-with-anyblob))

---

## Expand ksmbd Attack Surface via Configuration

By default, a minimal ksmbd setup leaves large parts of the server untested. Enable these features to drive the server through additional parsers/handlers and reach deeper code paths:

### Global-level settings
- **Durable handles** - Alters state machines and lifetimes, often surfacing UAF/refcount/OOB bugs under concurrency
- **Server multi-channel** - Increases complexity in connection handling
- **SMB2 leases** - Exercises lease negotiation and break paths

### Per-share-level settings
- **Oplocks** (on by default) - Request/break handling in oplock.c
- **VFS objects** - VFS operations and lookup cache

### Modules affected
Enabling these increases execution in:
- `smb2pdu.c` (command parsing/dispatch)
- `ndr.c` (NDR encode/decode)
- `oplock.c` (oplock request/break)
- `smbacl.c` (ACL parsing/enforcement)
- `vfs.c` (VFS ops)
- `vfs_cache.c` (lookup cache)

### Configuration steps
1. Review `/etc/ksmbd/ksmbd.conf` and per-share sections
2. Enable durable handles, leases, oplocks and VFS objects
3. Use the helper script: `./scripts/ksmbd_fuzz_config.sh`

**Note**: Exact options depend on your distro's ksmbd userspace (ksmbd-tools).

---

## Authentication and Rate-Limiting Adjustments for Fuzzing

SMB3 needs a valid session. Implementing Kerberos in harnesses adds complexity, so prefer NTLM/guest for fuzzing:

### Recommended settings
- **Allow guest access** and set `map to guest = bad user` so unknown users fall back to GUEST
- **Accept NTLMv2** (patch policy if disabled) - keeps the handshake simple while exercising SMB3 code paths
- **Patch out strict credit checks** when experimenting (post-hardening for CVE-2024-50285 made simultaneous-op crediting stricter). Otherwise, rate-limits can reject fuzzed sequences too early
- **Increase max connections** (e.g., to 65536) to avoid early rejections during high-throughput fuzzing

### ⚠️ Caution
These relaxations are to facilitate fuzzing only. **Do not deploy with these settings in production.**

---

## Stateful Harness: Extract Resources and Chain Requests

SMB is stateful: many requests depend on identifiers returned by prior responses (SessionId, TreeID, FileID pairs). Your harness must parse responses and reuse IDs within the same program to reach deep handlers (e.g., `smb2_create → smb2_ioctl → smb2_close`).

### Response processing pattern

```c
// process response. does not contain +4B PDU length
void process_buffer(int msg_no, const char *buffer, size_t received) {
  uint16_t cmd_rsp = u16((const uint8_t *)(buffer + CMD_OFFSET));
  switch (cmd_rsp) {
    case SMB2_TREE_CONNECT:
      if (received >= TREE_ID_OFFSET + sizeof(uint32_t))
        tree_id = u32((const uint8_t *)(buffer + TREE_ID_OFFSET));
      break;
    case SMB2_SESS_SETUP:
      // first session setup response carries session_id
      if (msg_no == 0x01 && received >= SESSION_ID_OFFSET + sizeof(uint64_t))
        session_id = u64((const uint8_t *)(buffer + SESSION_ID_OFFSET));
      break;
    case SMB2_CREATE:
      if (received >= CREATE_VFID_OFFSET + sizeof(uint64_t)) {
        persistent_file_id = u64((const uint8_t *)(buffer + CREATE_PFID_OFFSET));
        volatile_file_id   = u64((const uint8_t *)(buffer + CREATE_VFID_OFFSET));
      }
      break;
    default:
      break;
  }
}
```

### Key tips
- **Keep one fuzzer process** sharing authentication/state: better stability and coverage with ksmbd's global/session tables. syzkaller still injects concurrency by marking ops async, rerun internally.
- **Sykzaller's experimental reset_acc_state** can reset global state but may introduce heavy slowdown. Prefer stability and focus fuzzing instead.

---

## Grammar-Driven SMB2 Generation (Valid PDUs)

Translate the Microsoft Open Specifications SMB2 structures into a fuzzer grammar so your generator produces structurally valid PDUs, which systematically reach dispatchers and IOCTL handlers.

### Example: SMB2 IOCTL request grammar

```
smb2_ioctl_req {
  Header_Prefix           SMB2Header_Prefix
  Command                 const[0xb, int16]
  Header_Suffix           SMB2Header_Suffix
  StructureSize           const[57, int16]
  Reserved                const[0, int16]
  CtlCode                 union_control_codes
  PersistentFileId        const[0x4, int64]
  VolatileFileId          const[0x0, int64]
  InputOffset             offsetof[Input, int32]
  InputCount              bytesize[Input, int32]
  MaxInputResponse        const[65536, int32]
  OutputOffset            offsetof[Output, int32]
  OutputCount             len[Output, int32]
  MaxOutputResponse       const[65536, int32]
  Flags                   int32[0:1]
  Reserved2               const[0, int32]
  Input                   array[int8]
  Output                  array[int8]
} [packed]
```

This style forces correct structure sizes/offsets and dramatically improves coverage versus blind mutation.

---

## Directed Fuzzing With focus_areas

Use syzkaller's experimental focus_areas to overweight specific functions/files that currently have weak coverage.

### Example focus_areas.json

```json
{
  "focus_areas": [
    {"filter": {"functions": ["smb_check_perm_dacl"]}, "weight": 20.0},
    {"filter": {"files": ["^fs/smb/server/"]}, "weight": 2.0},
    {"weight": 1.0}
  ]
}
```

This helps construct valid ACLs that hit arithmetic/overflow paths in smbacl.c. For instance, a malicious Security Descriptor with an oversized dacloffset reproduces an integer-overflow.

### Reproducing ACL bugs

Use the helper script to build malicious Security Descriptors:

```bash
python scripts/build_security_descriptor.py --dacloffset 0x10000 --output sd.bin
```

---

## Breaking Coverage Plateaus With ANYBLOB

syzkaller's anyTypes (ANYBLOB/ANYRES) allow collapsing complex structures into blobs that mutate generically. Seed a new corpus from public SMB pcaps and convert payloads into syzkaller programs calling your pseudo-syscall (e.g., `syz_ksmbd_send_req`).

### Convert pcap to corpus

```bash
# Extract SMB payloads to JSON
tshark -r smb2_dac_sample.pcap -Y "smb || smb2" -T json -e tcp.payload > packets.json

# Convert to syzkaller corpus
python scripts/convert_pcap_to_corpus.py packets.json corpus/
```

This jump-starts exploration and can immediately trigger UAFs (e.g., in ksmbd_sessions_deregister) while lifting coverage a few percent.

---

## Sanitizers: Beyond KASAN

- **KASAN** remains the primary detector for heap bugs (UAF/OOB)
- **KCSAN** often yields false positives or low-severity data races in this target
- **UBSAN/KUBSAN** can catch declared-bounds mistakes that KASAN misses due to array-index semantics

### Example: UBSAN catches in-struct OOB

```c
id = le32_to_cpu(psid->sub_auth[psid->num_subauth - 1]);
struct smb_sid {
  __u8 revision; __u8 num_subauth; __u8 authority[NUM_AUTHS];
  __le32 sub_auth[SID_MAX_SUB_AUTHORITIES]; /* sub_auth[num_subauth] */
} __attribute__((packed));
```

Setting `num_subauth = 0` triggers an in-struct OOB read of `sub_auth[-1]`, caught by UBSAN's declared-bounds checks.

**Recommendation**: Run with KASAN + UBSAN; triage UBSAN declared-bounds reports carefully.

---

## Throughput and Parallelism Notes

- **A single fuzzer process** (shared auth/state) tends to be significantly more stable for ksmbd and still surfaces races/UAFs thanks to syzkaller's internal async executor
- **With multiple VMs**, you can still hit hundreds of SMB commands/second overall
- **Function-level coverage** around ~60% of fs/smb/server and ~70% of smb2pdu.c is attainable, though state-transition coverage is under-represented by such metrics

---

## Practical Checklist

- [ ] Enable durable handles, leases, multi-channel, oplocks, and VFS objects in ksmbd
- [ ] Allow guest and map-to-guest; accept NTLMv2
- [ ] Patch out credit limits and raise max connections for fuzzer stability
- [ ] Build a stateful harness that caches SessionId/TreeID/FileIDs and chains create → ioctl → close
- [ ] Use a grammar for SMB2 PDUs to maintain structural validity
- [ ] Use focus_areas to overweight weakly-covered functions (e.g., smbacl.c paths like smb_check_perm_dacl)
- [ ] Seed with ANYBLOB from real pcaps to break plateaus; pack seeds with syz-db for reuse
- [ ] Run with KASAN + UBSAN; triage UBSAN declared-bounds reports carefully

---

## References

- Doyensec – ksmbd Fuzzing (Part 2): https://blog.doyensec.com/2025/09/02/ksmbd-2.html
- syzkaller: https://github.com/google/syzkaller
- ANYBLOB/anyTypes: https://github.com/google/syzkaller/commit/9fe8aa4
- Async executor: https://github.com/google/syzkaller/commit/fd8caa5
- syz-db: https://github.com/google/syzkaller/tree/master/tools/syz-db
- KASAN: https://docs.kernel.org/dev-tools/kasan.html
- UBSAN/KUBSAN: https://docs.kernel.org/dev-tools/ubsan.html
- Microsoft Open Specifications (SMB): https://learn.microsoft.com/openspecs/
- Wireshark Sample Captures: https://wiki.wireshark.org/SampleCaptures
