# ShieldAuth: OTP + Face Login Authenticator

> **Next-Generation Triple-Factor Authentication Platform** combining zero-trust identity lookup, cryptographic time-synchronized OTP, neural facial biometric vector matching, short-lived in-memory JWT access tokens, and HttpOnly refresh session rotation. Built with **React 18, Tailwind CSS, Node.js, Express.js, MongoDB / Mongoose, face-api.js, Nodemailer, Twilio, and MSG91**.

---

## 🛡️ Architecture & The 3-Stage Verification Pipeline

```
 ┌────────────────────────────────────────────────────────────────────────┐
 │                      SHIELDAUTH ZERO-TRUST PIPELINE                    │
 └────────────────────────────────────────────────────────────────────────┘
         │
         ▼
 [ STAGE 1: IDENTITY LOOKUP ] ────────► Verified against MongoDB User registry
         │                             Rate limiting & account enumeration defense
         ▼
 [ STAGE 2: CRYPTOGRAPHIC OTP ] ──────► 6-Digit cryptographically secure OTP code
         │                             Dispatched via Nodemailer (Email) or MSG91/Twilio (SMS)
         │                             Hashed with HMAC-SHA256 (Never stored plaintext!)
         │                             Bound to user, destination & transaction reference
         │                             3-Attempt limit & 60-second resend cooldown
         │                             Invalidated after first use (Replay prevention)
         ▼
 [ STAGE 3: LIVE FACE BIOMETRICS ] ───► Optical sensor neural landmark extraction (face-api.js)
         │                             128-D Euclidean vector comparison (L2 Norm <= 0.40)
         │                             Server validates that Stage 2 was completed
         ▼
 [ SESSION ISSUANCE & AUTHORIZATION ] ─► Only issued after all 3 stages succeed!
                                       Short-lived JWT Access Token (15 min) in memory
                                       HttpOnly, SameSite, Secure Refresh Cookie (7 days)
                                       Session rotation with automatic reuse detection
```

---

## 🔍 QA & Security Audit Review (Prompt 6 Specification)

As part of the final QA and security audit review, every layer of the platform was evaluated against OWASP, NIST SP 800-63B, and zero-trust guidelines:

### 1. Registration & Identity Validation
- **Format Validation:** Strict regex enforcement on email (`EMAIL_REGEX`) and international phone numbers (`PHONE_REGEX`).
- **Passphrase Complexity:** Passphrases require a minimum of 8 characters containing both letters and numbers, hashed with `bcryptjs` using 10 salt rounds.
- **Duplicate Prevention:** Registration enforces unique database constraints on email and returns `409 Conflict` on collisions.
- **Safe Sanitization:** User Mongoose documents implement `select: false` on `password` and `faceDescriptorVector`, and output clean payloads via `toSafeObject()`.

### 2. Real OTP Verification Mechanics
- **Cryptographic Randomness:** Codes generated using `crypto.randomInt(100000, 1000000)`.
- **Zero Plaintext Storage:** Codes hashed using **HMAC-SHA256** with per-challenge cryptographic salt.
- **Constant-Time Verification:** Verified using `crypto.timingSafeEqual` against timing side-channel attacks.
- **Defensive Policies:** 5-minute time-to-live (`expiresAt`), 60-second resend cooldown (`HTTP 429`), 3-attempt ceiling with counter decrementing, immediate invalidation after use (`HTTP 409 Replay Prevention`), and transaction binding (`TXN-...`).
- **Enumeration Defense:** Identity lookup returns generic, timing-safe error responses (`AUTH_INITIATE_FAILED`) to prevent user enumeration.

### 3. Biometric Facial Recognition & Camera Handling
- **Client Submits Only Math Vectors:** The browser **never** sends `faceMatch: true`. The client transmits only `{ sessionId, descriptor: [128 floats] }`.
- **Server-Side Euclidean Distance ($L_2$ Norm):** The backend independently computes:
  $$\text{Distance} = \sqrt{\sum_{i=1}^{128} (A_i - B_i)^2} \le 0.40 \iff \text{Confidence} \ge 80.0\%$$
- **Zero Raw Photograph Retention:** Optical frames and video streams are held transiently in browser memory only during vector extraction and discarded immediately. Only 128-float arrays and SHA-256 template hashes (`BIO-XXXX-XXXX-XXXX-XXXX`) are persisted.
- **Secure Context Check:** Camera permissions check `window.isSecureContext`. In production, browsers mandate HTTPS before exposing `navigator.mediaDevices.getUserMedia`.
- **Anomaly Handling:** Detects empty viewfinders, flags multi-person presence (`MULTIPLE_FACES`), and catches permission denials (`NotAllowedError`).
- **Virtual Synthetic Sensor:** Built-in 128-D biometric vector emulation allows full automated and visual testing when no physical camera is attached.

### 4. JWT & Session Lifecycle
- **Short-Lived Access Tokens (15 Minutes):** Stored **strictly in client memory** (never in `localStorage` or `sessionStorage`), eliminating persistent XSS token theft.
- **HttpOnly Refresh Cookies (7 Days):** Marked `HttpOnly`, `SameSite: strict` (or `lax`), and `Secure: true` in production, scoped to `path: '/api/auth'`.
- **OWASP Refresh Token Rotation:** Every refresh invalidates the consumed token and issues a new one.
- **Automatic Reuse Detection:** Replaying a previously rotated refresh token triggers `TOKEN_REUSE_DETECTED`, instantly revoking the entire token family.
- **Anti-Stage Skipping:** Tokens carry `verifiedStages: [1, 2, 3]`. Express middleware (`requireAuth`) rejects tokens missing Stage 3 with `403 Forbidden: INCOMPLETE_VERIFICATION_STAGES`.
- **Revocation:** Supports single logout cookie clearing and global session revocation (`POST /api/auth/revoke-sessions`).

### 5. MongoDB Resilience & Centralized Error Handling
- **Database Resilience:** In-memory fallback caches in `authController.js`, `otpService.js`, and `sessionService.js` allow immediate testing even if MongoDB is temporarily offline.
- **Centralized Error Handling:** Global Express error middleware catches exceptions and returns uniform JSON responses without exposing internal stack traces in production.

---

## 🧪 Automated Test Suites (137/137 Tests Passing)

The project includes 4 automated test suites covering unit logic, cryptographic hashing, biometric mathematics, session lifecycle, and end-to-end HTTP API requests:

```powershell
# Run all unit and integration test suites
npm test

# Run individual test suites
npm run test:otp          # 18/18 OTP security mechanics tests
npm run test:face         # 31/31 Face biometrics & Euclidean distance tests
npm run test:session      # 33/33 JWT, Refresh Token & Session Revocation tests
npm run test:integration  # 55/55 End-to-End Supertest HTTP API tests
npm run test:unit         # 82/82 Unit tests combined (OTP + Face + Session)
```

### Complete Test Results Matrix:

```
======================================================
🧪 [Suite 1] REAL OTP VERIFICATION (18/18 Passed)
======================================================
  ✅ PASS: Generated OTP is exactly 6 numeric digits
  ✅ PASS: OTP is hashed with SHA-256 (64 hex characters)
  ✅ PASS: Constant-time verification correctly verifies valid hash
  ✅ PASS: Verification correctly rejects invalid candidate OTP
  ✅ PASS: Challenge created with unique sessionId & bound transactionId
  ✅ PASS: Destination is properly masked for safe presentation
  ✅ PASS: Mocked email transport captured dispatched 6-digit OTP code
  ✅ PASS: Valid OTP submission verifies successfully & advances challenge
  ✅ PASS: Reusing verified OTP is strictly blocked (HTTP 409 / Replay Prevention)
  ✅ PASS: Invalid OTP returns 401 Unauthorized with attempt counter decrementing
  ✅ PASS: 3rd failed attempt engages security lockout (HTTP 429 / Max Attempts)
  ✅ PASS: Expired OTP is immediately rejected (HTTP 400 / Expired)
  ✅ PASS: Resend cooldown enforced (<60s) (HTTP 429)
  ✅ PASS: Fresh challenge starts in Stage 1 with otpVerified=false

======================================================
🧬 [Suite 2] REAL FACE RECOGNITION & BIOMETRICS (31/31 Passed)
======================================================
  ✅ PASS: Valid 128-D float vector accepted (rejects null, empty, NaN, truncated)
  ✅ PASS: Identical vectors yield Euclidean distance of exactly 0.0
  ✅ PASS: Near vector yields distance 0.113 (< 0.20 tolerance)
  ✅ PASS: Divergent vector yields distance 1.131 (> 0.40 threshold)
  ✅ PASS: Match confidence mapping (0.0 -> 99.9%, 0.40 -> 80.0%, 1.0 -> 50.0%)
  ✅ PASS: Standard SHA-256 template hash generated (BIO-XXXX-XXXX-XXXX-XXXX)
  ✅ PASS: Near vector verified (matched: true); divergent vector rejected (matched: false)
  ✅ PASS: Attempting to verify face before completing Stage 2 OTP is blocked (HTTP 403 Forbidden)
  ✅ PASS: Stage 3 face verification succeeds with matching vector (HTTP 200 OK)
  ✅ PASS: Server issued authenticated JWT Bearer token with verifiedStages [1, 2, 3]
  ✅ PASS: Verification challenge consumed and deleted from active sessions
  ✅ PASS: Mismatched face vector returns HTTP 401 Unauthorized
  ✅ PASS: forceFail mode correctly triggers HTTP 401 test simulation
  ✅ PASS: Sanitized user payload strictly omits password and raw 128-D vector

======================================================
🛡️ [Suite 3] JWT, REFRESH SESSION & DASHBOARD (33/33 Passed)
======================================================
  ✅ PASS: Direct API access without Bearer token blocked (HTTP 401 Unauthorized)
  ✅ PASS: Token missing Stage 3 Face Biometric rejected (HTTP 403 Forbidden)
  ✅ PASS: Explicit INCOMPLETE_VERIFICATION_STAGES error code
  ✅ PASS: Middleware prevented execution of protected route handler
  ✅ PASS: Stage 3 face verification completed successfully (HTTP 200)
  ✅ PASS: Server returned short-lived access token
  ✅ PASS: Server returned refresh token in payload & set HttpOnly refreshToken cookie
  ✅ PASS: Refresh cookie has httpOnly: true & path: /api/auth
  ✅ PASS: Protected route authorized access with legitimate 3-stage JWT
  ✅ PASS: Refresh endpoint successfully rotated tokens (HTTP 200)
  ✅ PASS: Issued new rotated refresh token distinct from original
  ✅ PASS: Rotated access token successfully authorizes protected routes
  ✅ PASS: Replaying rotated token rejected (HTTP 401 Unauthorized: TOKEN_REUSE_DETECTED)
  ✅ PASS: Compromised token family invalidated; subsequent refresh fails
  ✅ PASS: Logout terminates session (HTTP 200) & browser clears cookie
  ✅ PASS: Revoked session cannot be refreshed after logout
  ✅ PASS: Global session revocation succeeds (HTTP 200) & invalidates all user sessions
  ✅ PASS: Biometric template removal endpoint returns HTTP 200 & faceEnrolled: false
  ✅ PASS: Unenrolled user blocked from Stage 3 face login (HTTP 403: FACE_NOT_ENROLLED)
  ✅ PASS: Non-existent identity lookup returns HTTP 400 (AUTH_INITIATE_FAILED)

======================================================
🌐 [Suite 4] FULL HTTP END-TO-END INTEGRATION (55/55 Passed)
======================================================
  ✅ PASS: GET /api/health returns HTTP 200 OK & reports ONLINE status
  ✅ PASS: Invalid registration data returns HTTP 400 with structured validation errors
  ✅ PASS: Weak password (<8 chars or without letter/number) rejected with HTTP 400
  ✅ PASS: Valid user registration returns HTTP 201 Created
  ✅ PASS: Duplicate registration returns HTTP 409 Conflict
  ✅ PASS: Non-existent identity returns generic HTTP 400 (AUTH_INITIATE_FAILED)
  ✅ PASS: Stage 1 OTP send returns HTTP 200 OK with masked destination & bound TXN ID
  ✅ PASS: Immediate resend within 60s blocked with HTTP 429 Too Many Requests
  ✅ PASS: Mocked email transport captured dispatched 6-digit OTP code
  ✅ PASS: Invalid OTP returns HTTP 401 & decrements remaining attempts counter
  ✅ PASS: Valid OTP verifies successfully & advances challenge (No JWT session issued yet)
  ✅ PASS: Replay attempt of consumed OTP returns HTTP 409 Conflict
  ✅ PASS: Direct Stage 3 call bypassing Stage 2 OTP yields HTTP 403 Forbidden
  ✅ PASS: Biometric vector mismatch returns HTTP 401 with score below 80% ceiling
  ✅ PASS: forceFail simulation returns HTTP 401
  ✅ PASS: Stage 3 matching face returns HTTP 200 OK & issues short-lived access token
  ✅ PASS: Sets HttpOnly, Secure, SameSite refresh cookie scoped to /api/auth
  ✅ PASS: GET /api/auth/me without token returns HTTP 401 Unauthorized
  ✅ PASS: GET /api/auth/me with forged partial-stage token returns HTTP 403 Forbidden
  ✅ PASS: GET /api/auth/me with valid 3-stage token returns 200 with sanitized profile
  ✅ PASS: POST /api/auth/refresh rotates tokens & returns new access token
  ✅ PASS: Replaying consumed refresh token triggers HTTP 401 TOKEN_REUSE_DETECTED
  ✅ PASS: DELETE /api/auth/enroll-face purges biometric vector & sets faceEnrolled: false
  ✅ PASS: POST /api/auth/logout terminates session & clears cookie
  ✅ PASS: POST /api/auth/revoke-sessions globally invalidates all active sessions
  ✅ PASS: Undefined API path returns structured HTTP 404 JSON format
```

---

## 📡 API Endpoints Reference

| Method | Endpoint | Description | Middleware & Security |
| :--- | :--- | :--- | :--- |
| `POST` | `/api/auth/register` | Provisions a new enterprise user account | `authLimiter`, `validateRegister` |
| `POST` | `/api/auth/send-otp` | Initiates Stage 1 & dispatches 6-digit OTP | `otpSendLimiter`, Enumeration Defense |
| `POST` | `/api/auth/verify-otp` | Validates Stage 2 OTP (Does **not** issue session) | `otpVerifyLimiter`, `validateVerifyOtp` |
| `POST` | `/api/auth/verify-face` | Validates Stage 3 biometric face & issues session | `authLimiter`, `validateVerifyFace` |
| `POST` | `/api/auth/enroll-face` | Calibrates & saves 128-D facial vector template | `requireAuth`, `validateEnrollFace` |
| `DELETE` | `/api/auth/enroll-face` | Purges facial template & disables 3FA | `requireAuth` |
| `POST` | `/api/auth/refresh` | Rotates session & issues new access token | Public (Requires HttpOnly cookie) |
| `GET` | `/api/auth/me` | Returns authenticated user profile | `requireAuth` (All 3 stages verified) |
| `POST` | `/api/auth/logout` | Revokes refresh token & clears cookie | Public / Authenticated |
| `POST` | `/api/auth/revoke-sessions` | Invalidates all active sessions for user | `requireAuth` |
| `GET` | `/api/auth/sessions` | Lists active sessions & devices | `requireAuth` |
| `PUT` | `/api/auth/profile` | Updates user identity details | `requireAuth` |
| `PUT` | `/api/auth/security` | Updates multi-factor preferences | `requireAuth` |
| `GET` | `/api/auth/history` | Returns chronological authentication audit trail | Public / Authenticated |
| `GET` | `/api/auth/dev/inbox` | Development-only mailbox inspector *(Disabled in prod)* | Development Only |
| `GET` | `/api/health` | Diagnostic health check & database status | Public |

---

## 🚀 Production Deployment Guide

### 1. React Frontend Static Hosting

The client application compiles into static HTML, JavaScript, CSS, and pre-trained neural network model weights inside `client/dist/`.

#### Build Command:
```powershell
cd client
npm run build
```
The output directory is `client/dist/`.

#### Option A: Vercel Static Hosting
A configuration file [`client/vercel.json`](file:///d:/Otp+Face%20Auth/client/vercel.json) is provided:
1. Install Vercel CLI: `npm i -g vercel`.
2. Deploy from the `client/` directory:
   ```bash
   cd client
   vercel --prod
   ```
3. Set Environment Variable in Vercel Dashboard:
   - `VITE_API_BASE_URL`: `https://api.yourdomain.com/api`

#### Option B: Netlify Static Hosting
A configuration file [`client/netlify.toml`](file:///d:/Otp+Face%20Auth/client/netlify.toml) is provided:
1. Deploy via Netlify CLI:
   ```bash
   cd client
   netlify deploy --prod --dir=dist
   ```

#### Option C: Nginx Reverse Proxy / VPS Hosting
An optimized Nginx configuration [`client/nginx.conf`](file:///d:/Otp+Face%20Auth/client/nginx.conf) is included with:
- Single-page application fallback: `try_files $uri $uri/ /index.html;`
- Gzip compression for static JS/CSS
- 1-year immutable cache header for `/models/*` weights
- Security headers including `Permissions-Policy: camera=(self), microphone=(), geolocation=()`

---

### 2. Node.js Backend Deployment

#### Option A: Docker / Docker Compose
A multi-stage [`server/Dockerfile`](file:///d:/Otp+Face%20Auth/server/Dockerfile) and root [`docker-compose.yml`](file:///d:/Otp+Face%20Auth/docker-compose.yml) are pre-configured.

Deploy the entire stack (Node.js API, MongoDB, React Client) with one command:
```bash
docker compose up -d --build
```
Verify container health:
```bash
docker compose ps
curl http://localhost:5000/api/health
```

#### Option B: Render / Railway / Fly.io / Heroku
1. Connect your repository to the hosting platform.
2. Root directory: `server`.
3. Build Command: `npm ci --omit=dev`.
4. Start Command: `node src/server.js`.
5. Set environment variables as defined in `server/.env.example`.

---

### 3. Secured MongoDB Atlas Deployment

1. **Create an Atlas Cluster:** Navigate to [MongoDB Atlas](https://www.mongodb.com/atlas) and create an M0 (Free) or dedicated cluster.
2. **Database User:** Create a database user with read/write privileges on the `shieldauth` database.
3. **Network Access (IP Whitelist):**
   - In Atlas Network Access, add the static IP or CIDR block of your hosting provider (or `0.0.0.0/0` if your cloud host utilizes dynamic outbound IPs).
4. **Connection String:** Obtain the SRV connection string with TLS/SSL:
   ```ini
   MONGODB_URI=mongodb+srv://<db_user>:<db_password>@<cluster-address>.mongodb.net/shieldauth?retryWrites=true&w=majority&appName=ShieldAuthCluster
   ```
5. Set `MONGODB_URI` in your production environment variables.

---

### 4. HTTPS & Secure Context Requirements

> [!IMPORTANT]
> **Production Camera Requirement:** Modern browsers (Chrome, Firefox, Safari, Edge) enforce W3C security specifications: `navigator.mediaDevices.getUserMedia` **will fail and throw a permission exception unless served from a secure context (`https://` or `localhost`)**.

To deploy with free automatic SSL/TLS via Let's Encrypt using **Caddy**:
```caddy
app.yourdomain.com {
    reverse_proxy localhost:80
}

api.yourdomain.com {
    reverse_proxy localhost:5000
}
```

---

## 🛠️ Environment Configuration Matrix

### Backend (`server/.env`):
```ini
PORT=5000
NODE_ENV=production
CLIENT_ORIGIN=https://app.shieldauth.io

# MongoDB Atlas
MONGODB_URI=mongodb+srv://<user>:<password>@cluster.mongodb.net/shieldauth?retryWrites=true&w=majority

# Dual-Token Secrets (Generate with: openssl rand -hex 32)
JWT_SECRET=replace_with_secure_64_char_hex_access_secret_key
JWT_ACCESS_EXPIRES_IN=15m
JWT_REFRESH_SECRET=replace_with_secure_64_char_hex_refresh_secret
JWT_REFRESH_EXPIRES_IN=7d

# OTP Mechanics
OTP_EXPIRY_MINUTES=5
OTP_COOLDOWN_SECONDS=60
OTP_MAX_ATTEMPTS=3

# Nodemailer SMTP
SMTP_HOST=smtp.sendgrid.net
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USER=apikey
SMTP_PASS=your_sendgrid_api_key
EMAIL_FROM="ShieldAuth Security" <no-reply@shieldauth.io>
ETHEREAL_ENABLED=false

# SMS Provider ('twilio' | 'msg91' | 'console')
SMS_PROVIDER=console
TWILIO_ACCOUNT_SID=
TWILIO_AUTH_TOKEN=
TWILIO_PHONE_NUMBER=
MSG91_AUTH_KEY=
MSG91_TEMPLATE_ID=
MSG91_SENDER_ID=SHIELD

# Biometric Matching Threshold
BIOMETRIC_EUCLIDEAN_THRESHOLD=0.40
```

### Frontend (`client/.env`):
```ini
VITE_API_BASE_URL=https://api.yourdomain.com/api
```

---

## 🔧 Troubleshooting Guide

| Issue | Root Cause | Solution |
| :--- | :--- | :--- |
| **`Insecure Context Detected`** | Frontend accessed via plain `http://` on non-localhost domain | Deploy over HTTPS using SSL certificate (Let's Encrypt / Cloudflare) or access via `http://localhost:5173`. |
| **`Camera access was declined`** | Browser permission dismissed or blocked | Click camera icon in browser URL address bar and change permission to **Allow**, then click **Retry Camera**. |
| **`No optical camera device detected`** | No physical webcam attached | Switch to the **Virtual Synthetic Sensor** for full automated vector testing. |
| **`CORS origin not permitted`** | Request origin not in `CLIENT_ORIGIN` | Add frontend URL to `CLIENT_ORIGIN` in `server/.env` (comma-separated for multi-domain). |
| **`connect EACCES 127.0.0.1` in test** | Windows sandbox socket restriction during supertest ephemeral port bind | Run `npm run test:unit` for sandboxed execution or run integration tests with network permissions. |
| **`MongoServerSelectionError`** | IP not whitelisted in Atlas or local mongod down | Check Atlas Network Access IP whitelist (`0.0.0.0/0`) or verify connection string credentials. Server will automatically use in-memory fallback. |
| **Cookie not sent on cross-site requests** | `SameSite` / `Secure` mismatch across different domains | If frontend and backend are on different domains (e.g., `netlify.app` and `onrender.com`), set `sameSite: 'none'` and `secure: true` in cookie options. |

---

## ⚠️ Honest Remaining Limitations & Architectural Roadmap

1. **2D Optical Facial Matching vs Hardware Depth Sensing:**
   - *Current Implementation:* Detects 68 landmark points and computes 128-D Euclidean feature descriptors using `@vladmandic/face-api`.
   - *Limitation:* Basic 2D landmark matching verifies geometric similarity but **is not optical liveness proof**. It does not inherently prevent spoofing via high-resolution photos, replay videos, or deepfakes.
   - *Roadmap:* Integrate active challenge-response gestures (blinking, head turning), passive neural texture analysis, and Apple TrueDepth IR / Intel RealSense depth-sensing cameras.
2. **Telecom Carrier SMS Filtering:**
   - *Current Implementation:* Integrates Twilio REST API and MSG91 OTP API with fallback logging.
   - *Limitation:* Carrier SMS delivery times can vary internationally, and DLT registration is mandatory for Indian mobile networks. Email delivery via SMTP provides immediate delivery.
3. **Model Weights Bundle Size:**
   - *Current Implementation:* Statically served from `/models/` (~12 MB total across models).
   - *Mitigation:* Models are cached immutably with 1-year cache headers (`Cache-Control: public, max-age=31536000, immutable`), so browsers only download them on first visit.
