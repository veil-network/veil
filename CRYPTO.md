Veil Cryptography Specification v1.3.1
Date: 13.07.2026
Version: 1.3.1 (stable)
Purpose: Formal cryptographic architecture description for audit and research.
________________________________________
Table of Contents
1.	Cryptographic Architecture Overview
2.	Key Management
3.	Connection Protocol
4.	MARKER — Pre-Authentication Check
5.	Authentication (D-019 v2)
6.	FGN — Stream Cipher
7.	Key Update
8.	Seed Generation
9.	Cryptographic Primitives
10.	Logging Audit
11.	Known Limitations
12.	Duress Cryptography
13.	Binary Obfuscation
14.	Cryptographic Evolution
________________________________________
1. Cryptographic Architecture Overview
text
┌─────────────────────────────────────────────────────────┐
│                    PSK (32 bytes, []byte)                │
│                 base64, from VEIL_PSK                    │
│                 Wiped after HKDF (memclr)                │
└────────────────────────┬────────────────────────────────┘
                         │
         ┌───────────────┴───────────────┐
         │       HKDF (RFC 5869)         │
         │   SHA-256, public salt        │
         └───────────────┬───────────────┘
                         │
         ┌───────────────┼───────────────┐
         ▼               ▼               ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│ marker_key   │ │  auth_key    │ │duressMarkerKey│
│ (32 bytes)   │ │ (32 bytes)   │ │ (32 bytes)   │
└──────┬──────┘ └──────┬──────┘ └──────┬──────┘
       │               │               │
       ▼               ▼               ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│   MARKER     │ │Authentication│ │   Duress     │
│ SHA-256      │ │ D-019 v2     │ │  constant-   │
│ ekm ||       │ │ HMAC-SHA256  │ │  time check  │
│ timeSlot[:2] │ │ ekm[:16]     │ │              │
└─────────────┘ └─────────────┘ └─────────────┘

┌─────────────────────────────────────────────────────────┐
│              ExportKeyingMaterial (RFC 5705)              │
│         tlsConn.ExportKeyingMaterial("veil-auth",         │
│                        nil, 32)                          │
│           32 bytes, identical on client and server        │
└────────────────────────┬────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│                 Seed (32 bytes, crypto/rand)             │
│              Independent of PSK and all keys              │
└────────────────────────┬────────────────────────────────┘
                         │
         ┌───────────────┴───────────────┐
         ▼                               ▼
┌─────────────────┐           ┌─────────────────┐
│  FGN ChaCha20    │           │  lengthChacha    │
│  key = seed      │           │  key = SHA256    │
│  nonce = 24B     │           │  (seed ||        │
│                  │           │  "veil-length")  │
│  Structured      │           │  nonce = 24B     │
│  content 70/20/10│           │  (XChaCha20)     │
│                  │           │  tx/rx separated │
└─────────────────┘           └─────────────────┘
Core principle: compromise of one key does not reveal others. HKDF with different salts guarantees cryptographic independence of marker_key and auth_key. Seed is independent of PSK. Duress key is isolated. ExportKeyingMaterial provides symmetric parameters for both MARKER and HMAC.
________________________________________
2. Key Management
2.1. Pre-Shared Key (PSK)
Parameter	Value
Length	32 bytes (256 bits)
Type	[]byte (not string)
Encoding	Base64 (RFC 4648) for environment variable
Generation	openssl rand -base64 32
Storage	VEIL_PSK environment variable or /etc/veil/psk (chmod 600)
Transmission	Never. Not in code, logs, or network
Memory clearing	memclr() after HKDF, intermediate values wiped
2.2. HKDF Derivation (ADR-131)
Algorithm: HKDF-Extract (RFC 5869)
•	Hash: SHA-256
•	IKM: PSK (32 bytes, decoded from base64)
•	Salt: Public string
•	Info: nil
•	Output length: 32 bytes (256 bits)
Key	Salt	Purpose
marker_key	"veil-v1.1-marker-key"	MARKER (pre-authentication)
auth_key	"veil-v1.1-auth-key"	Authentication (HMAC)
duressMarkerKey	"veil-v1.1-marker-key" (from duress PSK)	Duress MARKER
2.3. Duress Keys
•	Duress PSK: VEIL_DURESS_PSK environment variable
•	Dummy key: Generated on every server start (32 bytes, crypto/rand)
•	Constant time: Both normal and duress computations always performed
2.4. In-Memory Key Clearing
go
//go:noinline
func MemClr(data []byte) {
    for i := range data {
        data[i] = 0
    }
    runtime.KeepAlive(data)
}
PSK wiped after HKDF. //go:noinline prevents compiler optimization.
2.5. Protocol Version Compatibility
Version	Key Derivation	MARKER/HMAC Source
0x01 (v1.0)	Raw PSK	SessionID / TLSUnique
0x02 (v1.1)	HKDF	ServerRandom||ClientRandom / SessionID
0x03 (v1.1)	HKDF	ServerRandom||ClientRandom / SessionID
0x04 (v1.3+)	HKDF + duressKey	ekm (RFC 5705)
________________________________________
3. Connection Protocol
Cryptographic Sequence
text
1. TCP handshake → VPS:443

2. TLS 1.3 handshake (crypto/tls, Chrome-compatible parameters)
   - ECH stub (pending Go 1.28+)
   - Session Resumption
   - Certificate pinning (optional)

3. ExportKeyingMaterial:
   ekm = tlsConn.ExportKeyingMaterial("veil-auth", nil, 32)
   (32 bytes, identical on both sides)

4. MARKER v2 + Duress:
   Client: SHA256(ekm || timeSlotStr)[:2]
   Server: const-time verification, all 5 slots, duress first
   Window: ±60 seconds

5. PROTOCOL_VERSION: 0x04

6. Seed: 2 bytes length + 32 bytes seed (crypto/rand)

7. LengthNonce: 24 bytes XChaCha20 nonce

8. Target Address: validated (ports 80/443, domains only, no private IPs)

9. HTTP/2 preface: 24 bytes

10. GME dialog with HMAC:
    HMAC-SHA256(auth_key, ekm)[:16]
    5 dialog models, 500ms timeout

11. Data Stream with FGN padding:
    WINDOW_UPDATE (client + server)
    Half-close semantics
    Per-stream FGN isolation via Fork(streamID)

12. Key Update: Poisson(λ=5min)
________________________________________
4. MARKER — Pre-Authentication Check
4.1. MARKER v2 with ExportKeyingMaterial
text
normal_marker = SHA256(ekm || timeSlotStr)[:2]
duress_marker = SHA256(ekm || timeSlotStr)[:2]  // via duressMarkerKey
Parameter	Description
ekm	32 bytes from ExportKeyingMaterial("veil-auth", nil, 32)
timeSlotStr	String representation of floor(unix_time / 30)
Output length	2 bytes (16 bits)
Verification window	±2 slots (±60 seconds)
Security:
•	Value space: 2^16 = 65536
•	At 100 attempts per slot: P(success) ≈ 0.15%
•	Sufficient for filtering mass scanning
•	Full authentication via HMAC (16 bytes) in GME dialog
4.2. Constant-Time Verification
go
func validateMarkerV3(ekm []byte, received []byte,
    markerKey, duressMarkerKey []byte) (isDuress bool, ok bool) {

    var validV2, validDuress, validReal bool
    baseSlot := time.Now().Unix() / 30

    for slot := int64(-2); slot <= 2; slot++ {
        timeSlotStr := strconv.FormatInt(baseSlot+slot, 10)
        input := append(ekm, []byte(timeSlotStr)...)

        // V2 marker (backward compat)
        h := sha256.New()
        h.Write(input)
        v2Expected := h.Sum(nil)[:2]

        // Duress marker
        macDuress := hmac.New(sha256.New, duressMarkerKey)
        macDuress.Write(input)
        duressExpected := macDuress.Sum(nil)[:2]

        // Normal marker
        macReal := hmac.New(sha256.New, markerKey)
        macReal.Write(input)
        realExpected := macReal.Sum(nil)[:2]

        if subtle.ConstantTimeCompare(v2Expected, received) == 1 { validV2 = true }
        if subtle.ConstantTimeCompare(duressExpected, received) == 1 { validDuress = true }
        if subtle.ConstantTimeCompare(realExpected, received) == 1 { validReal = true }
    }

    if validDuress { return true, true }
    if validV2 || validReal { return false, true }
    return false, false
}
All 5 slots checked without early returns. Both markers computed for every slot. strconv.FormatInt used instead of fmt.Sprintf to eliminate timing channel. baseSlot computed once before the loop.
________________________________________
5. Authentication (D-019 v2)
5.1. HMAC with ExportKeyingMaterial
text
normal_hmac = HMAC-SHA256(auth_key, ekm)[:16]
duress_hmac = HMAC-SHA256(auth_key, ekm || ":duress:" || duressCode)[:16]
Parameter	Description
auth_key	32 bytes (HKDF from PSK)
ekm	32 bytes (ExportKeyingMaterial)
duressCode	Non-empty string, --duress-code flag
Output length	16 bytes (128 bits, NIST SP 800-107)
Embedding	SETTINGS GREASE ×2 (4+4) + PING opaque (8)
5.2. Constant-Time Verification
go
func verifyHMAC(clientHMAC []byte, authKey, ekm []byte,
    duressCode string) (bool, bool) {

    codeForHMAC := duressCode
    if codeForHMAC == "" {
        codeForHMAC = "dummy"
    }

    expectedNormal := computeHMAC(authKey, ekm)
    expectedDuress := computeHMAC(authKey,
        append(ekm, []byte(":duress:"+codeForHMAC)...))

    duressMatch := hmac.Equal(clientHMAC, expectedDuress[:16])
    normalMatch := hmac.Equal(clientHMAC, expectedNormal[:16])

    if duressMatch { return true, true }
    if normalMatch { return true, false }
    return false, false
}
Both HMACs computed always. Comparison via hmac.Equal → crypto/subtle.ConstantTimeCompare.
________________________________________
6. FGN — Stream Cipher
6.1. Algorithm
text
Main ChaCha20:
  key   = seed (32 bytes, crypto/rand)
  nonce = 24 bytes (XChaCha20)

Split lengthChacha:
  lengthKey = SHA256(seed || "veil-length")
  lengthNonce = 24 bytes (XChaCha20)
  txLengthChacha = ChaCha20(lengthKey, lengthNonce)
  rxLengthChacha = ChaCha20(lengthKey, lengthNonce)
6.2. Per-Stream Isolation (Fork)
go
func (f *FGNGenerator) Fork(streamID uint32) *FGNGenerator {
    h := sha256.New()
    h.Write(f.lengthKey)
    h.Write([]byte{byte(streamID >> 24), byte(streamID >> 16),
        byte(streamID >> 8), byte(streamID)})
    forkKey := h.Sum(nil)

    forkNonce := make([]byte, len(f.lengthNonce))
    copy(forkNonce, f.lengthNonce)

    fork := &FGNGenerator{lengthKey: forkKey, lengthNonce: forkNonce}
    fork.txLengthChacha, _ = chacha20.NewUnauthenticatedCipher(forkKey, forkNonce)
    fork.rxLengthChacha, _ = chacha20.NewUnauthenticatedCipher(forkKey, forkNonce)
    return fork
}
Each stream gets independent keystream. Different streams don't affect each other. Client and server Fork identically → keystream matches.
6.3. Structured Content
•	70% compressed (gzip-like: normal distribution μ=128 σ=80)
•	20% text (ASCII printable 0x20-0x7E)
•	10% headers (HPACK codes)
6.4. Adaptive Padding
Content-Type	Padding Range
HTML, CSS, JS	200-800 bytes
Image	50-200 bytes
Font	100-400 bytes
JSON	50-150 bytes
6.5. DATA Frame Format
text
[data_len (4 bytes, Big Endian)]
[data (N bytes)]
[encrypted_pad_len (4 bytes, XOR with txLengthChacha)]
[padding (M bytes)]
________________________________________
7. Key Update
text
First: uniform 2-15 minutes
Subsequent: Poisson(λ=5min) = -λ * ln(1 - crypto/rand)
•	Protocol: TLS 1.3 KeyUpdate (RFC 8446 Section 4.6.3)
•	Direction: client → server (request_update)
________________________________________
8. Seed Generation
Parameter	Requirement
Source	crypto/rand.Read()
Length	32 bytes (256 bits)
Independence	Not derived from PSK or keys
Uniqueness	New seed per connection
Generator	Client
________________________________________
9. Cryptographic Primitives
Primitive	Standard	Implementation	Key Length	Security
HKDF	RFC 5869	x/crypto/hkdf	—	256-bit
HMAC-SHA256	FIPS 198-1	crypto/hmac	256-bit	256-bit
ChaCha20	RFC 8439	x/crypto/chacha20	256-bit	256-bit
XChaCha20 Nonce	—	chacha20.NonceSizeX	192-bit	—
TLS 1.3	RFC 8446	crypto/tls	—	128+ bit
ExportKeyingMaterial	RFC 5705	crypto/tls	—	256-bit
SHA-256	FIPS 180-4	crypto/sha256	—	128-bit (collision)
CSPRNG	—	crypto/rand	—	OS entropy
Constant-time	—	hmac.Equal → crypto/subtle	—	Timing-safe
Base64	RFC 4648	encoding/base64	—	—
________________________________________
10. Logging Audit
Strictly Forbidden to Log:
•	marker_key, auth_key, PSK, VEIL_PSK, VEIL_DURESS_PSK
•	expectedMAC, receivedMAC, assembledHMAC, expectedHMAC
•	ekm, seed, FGN keys, LengthNonce
•	duressCode
•	Passwords, tokens, API keys
Allowed to Log:
•	Success/failure facts: "client authentication successful"
•	Failure reasons (without values): "TIMESYNC_ERROR"
•	Metadata: connection_id, stream_id
•	Duress events: "DUPRESS_CONNECTION" (without code)
________________________________________
11. Known Limitations
#	Limitation	Plan
1	ECH not implemented	Go 1.28+
2	No forward secrecy for PSK	Accepted for Phase 1
3	TCP options without eBPF	eBPF optional
4	JA3 = Go/Chrome-like	Accepted
5	No periodic FGN key rotation	Backlog 2027
6	MaxFramePayload = 65535	Accepted
7	No client-side fragmentation	Accepted
________________________________________
12. Duress Cryptography
Principles
1.	Constant time: MARKER and HMAC always computed for both variants
2.	Domain separation: ":duress:" prefix in HMAC
3.	Per-connection: Duress doesn't block normal clients
4.	Indistinguishable: Login form always present in facade
5.	Dummy key always generated
Verification Order
1.	validateMarkerV3 — duress first, then normal (all 5 slots const-time)
2.	Both HMACs always computed
3.	duress marker OR duress HMAC → isDuress = true
4.	On duress: fake panel, 30-60s padding traffic, no proxying
________________________________________
13. Binary Obfuscation
bash
garble -literals -tiny -seed=random build -o veil.exe -trimpath -ldflags="-s -w" ./cmd/veil/
Flag	Purpose
-literals	Obfuscate string literals
-tiny	Obfuscate function names
-seed=random	Different binary per user
In-memory PSK: []byte, wiped via memclr with //go:noinline. runtime.KeepAlive prevents optimization.
________________________________________
14. Cryptographic Evolution
Version	Date	Key Changes
v1.0-beta	27.05.2026	ChaCha20 FGN, HMAC-SHA256, PSK-based MARKER
v1.0-stable	11.06.2026	D-019 v2, Seed via crypto/rand
v1.1	18.06.2026	HKDF key separation, MARKER v2, structured FGN
v1.2	19.06.2026	tx/rx lengthChacha, Duress, garble, Poisson KeyUpdate
v1.3	23.06.2026	ExportKeyingMaterial, Certificate pinning, const-time MARKER, Rate limiter
v1.3.1	13.07.2026	Half-close, WINDOW_UPDATE, MaxFramePayload 65535, Fork paddingFGN

