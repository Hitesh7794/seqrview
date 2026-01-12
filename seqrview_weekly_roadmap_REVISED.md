# SeqrView - Weekly Development Roadmap (Revised)
## Phase 3: Exam Operations Engine

---

## **Week 1: Stabilize Onboarding + KYC (Aadhaar/DL) + Resume**

**Focus / Goal:** Complete KYC flow with resume capability after app reinstall

**Backend (Django) - Key Tasks:**
- Fix mobile normalization + prevent duplicate users
- Add `active_kyc_session_uid` in `/api/operators/profile/` response
- Add KYC restart/resume behavior + accurate error messages
- Vendor error mapping (429 vs 502) + cooldown/idempotency
- Clear sensitive data (id_card_image_b64) after verification completes

**Flutter (Android) - Key Tasks:**
- Finish OTP login + profile fill + Aadhaar start/OTP UI polish
- Add cooldown UI patterns (Aadhaar start + OTP request)
- Implement resume routing after reinstall (bootstrap stores active KYC session)
- Handle network failures gracefully with retry logic

**Deliverable / Demo:** 
- Demo: login via OTP → profile fill → Aadhaar OTP flow → resume after app reinstall (no stuck state)
- All KYC states properly handled (OTP_SENT, OTP_VERIFIED, DETAILS_VERIFIED, FACE_PENDING, VERIFIED, FAILED)

**Dependencies / Risks:**
- Surepass rate limits (429) - handled with cooldown
- SMS gateway not integrated yet (using console print)
- Missing active session field if backend not updated

**Status:** Planned  
**Progress %:** 0%

---

## **Week 2: Camera Integration v1 (Liveness + Face Match) to Reach Home**

**Focus / Goal:** Complete face verification pipeline to reach verified state

**Backend (Django) - Key Tasks:**
- Ensure FaceLiveness/FaceMatch endpoints accept expected multipart keys (`selfie`, `kyc_session_uid`)
- Improve error responses (face_not_found → 422 with friendly code)
- Save liveness + match results to UserVerification model
- Store operator selfie in AppUser.photo after successful face match
- Update OperatorProfile.kyc_status to VERIFIED on success

**Flutter (Android) - Key Tasks:**
- Integrate `image_picker` (camera only, front camera for selfie)
- Liveness screen: capture selfie → upload → retry on fail (max 3 attempts)
- Face match screen: capture selfie → upload → show confidence score
- Handle image orientation issues (EXIF data)
- Show progress indicators during upload

**Deliverable / Demo:** 
- Demo: Aadhaar OTP → liveness pass → face match pass → verified → Home screen
- Operator can see their verified status and photo in profile

**Dependencies / Risks:**
- Camera permissions (Android 13+)
- Image orientation issues
- Bandwidth for image uploads
- face_not_found if selfie not clear
- Multipart key mismatch between Flutter and Django

**Status:** Planned  
**Progress %:** 0%

---

## **Week 3: Master Data v1 + Operational Center Architecture**

**Focus / Goal:** Build foundation for centers with "Snapshot" architecture for immediate exam activation

### **Backend (Django) - Key Tasks:**

#### **A. Master Data Models (`masters` app):**
- Create `Client` model (client_code, name, logo, contacts, address, status)
- Create `GlobalCenter` model (center_code, name, address, GPS, capacity, incharge, status, rating)
- Create `RoleMaster` model (code, name, description, instruction, training_video_url, dress_code, is_active)
- Create `TaskTemplate` model (code, title, description, is_mandatory)
- Add indexes on client_code, center_code, city, state

#### **B. Operational Center Models (`operations` app):**
- **CRITICAL:** Create `ExamCenter` model (operational snapshot):
  - Links to `Exam` + `GlobalCenter` (nullable FK - allows immediate activation)
  - Stores client-provided data: `client_center_code`, `client_center_name`
  - Exam-specific fields: `active_capacity`, `lab_room_info`, `client_instructions`
  - Status: ACTIVE / READY / LIVE / COMPLETED
- Create `ClientCenterMapping` model (handles aliases):
  - Links `Client` + `GlobalCenter` + client's code/name for that center
  - Prevents duplicate master entries when same building has different codes

#### **C. APIs:**
- CRUD APIs for Client (admin only)
- CRUD APIs for GlobalCenter (admin only)
- **Bulk CSV Import Endpoint:** `/api/centers/bulk-import/`
  - Accepts CSV with: client_center_code, name, address, GPS, capacity
  - **Immediately creates ExamCenter records** (no blocking on Master)
  - Background job: Auto-links to GlobalCenter via fuzzy matching (GPS + pincode)
- List/filter/pagination for centers
- Admin permissions: INTERNAL_ADMIN & CLIENT_ADMIN scopes

#### **D. Background Processing:**
- Management command: `link_exam_centers_to_master`
  - Fuzzy matches ExamCenter → GlobalCenter (GPS distance < 100m + same pincode)
  - Creates ClientCenterMapping if client code differs
  - Flags conflicts for manual review

### **Flutter (Android) - Key Tasks:**
- Read-only screens for operators: Center details (from assignment later)
- Basic admin-only (optional) or skip on app; keep admin web first
- Center list view (if operator has assignment)

**Deliverable / Demo:** 
- Demo: Admin uploads 2000 centers via CSV → ExamCenter records created immediately → Exam can proceed
- Background job links to Master → Admin dashboard shows "Unlinked Centers" for review
- Same building (JNU) with different client codes (NTA:101, UPSC:501) → Both point to same GlobalCenter

**Dependencies / Risks:**
- Data volume (thousands of centers) - CSV parsing performance
- Need bulk import - memory usage for large files
- RBAC correctness (client admins see only their centers)
- GPS accuracy for fuzzy matching

**Status:** Planned  
**Progress %:** 0%

---

## **Week 4: Exam + Shift Setup v1 (Planning Layer)**

**Focus / Goal:** Create exam scheduling system with center allocation

### **Backend (Django) - Key Tasks:**

#### **A. Exam Models (`exams` app):**
- Create `Exam` model:
  - exam_code (unique), name, client FK
  - exam_start_date, exam_end_date (window)
  - status: DRAFT / CONFIGURING / READY / LIVE / COMPLETED / CANCELLED
  - description, attachments_url
  - Audit: created_by, updated_by
- Create `Shift` model:
  - exam FK, shift_code, name, session_number
  - work_date, start_time, end_time, reporting_time, gate_close_time
  - shift_type: DEMO / MAIN
  - status: DRAFT / CONFIGURING / READY / LIVE / COMPLETED
  - instructions, remarks
  - Unique constraint: (exam_id, shift_code)

#### **B. Center Allocation Models (`operations` app):**
- Create `ShiftCenter` model:
  - Links: exam + shift + center (ExamCenter FK)
  - Status: PLANNED / CONFIRMED / CANCELLED
  - Notes field
  - Unique constraint: (exam_id, shift_id, center_id)
- Create `ShiftCenterRole` model (headcount planning):
  - Links: ShiftCenter + RoleMaster
  - headcount (required staff count for this role)
  - buffer_headcount (standby staff)
  - Remarks
  - Unique constraint: (shift_center_id, role_id)

#### **C. APIs:**
- Create exam endpoint (with validation)
- Create shift endpoint (validate time windows, no overlaps)
- **Bulk center allocation:** `/api/exams/{exam_id}/allocate-centers/`
  - Accepts list of center_ids + shift_ids
  - Creates ShiftCenter records in bulk
- List exams (filter by client, status, date range)
- List shifts for exam
- List centers for shift
- Update exam/shift status

#### **D. Validation Logic:**
- Prevent over-allocation: Check ExamCenter.active_capacity vs total candidates
- Validate shift times don't overlap for same center
- Ensure reporting_time < start_time

### **Flutter (Android) - Key Tasks:**
- Add shared UI components (forms, lists, date pickers)
- Operator app: show "Upcoming exams" (read-only list)
- Basic timeline UI component (shows exam dates)
- Exam details screen (name, dates, shifts)
- Keep routing stable (no breaking changes)

**Deliverable / Demo:** 
- Demo: Admin creates exam "JEE 2026" → Creates 3 shifts (Morning, Afternoon, Evening)
- Allocates 500 centers to Morning shift → System validates capacity
- Operator sees "Upcoming: JEE 2026 (May 10-15)" in app

**Dependencies / Risks:**
- Bulk operations performance (500+ centers)
- Permissions (client scoped - client admin can't see other clients' exams)
- Timezone handling (work_date + start_time)
- Concurrent allocation (race conditions)

**Status:** Planned  
**Progress %:** 0%

---

## **Week 5: Assignments v1 (Core Operations Engine)**

**Focus / Goal:** Assign verified operators to exam centers with roles

### **Backend (Django) - Key Tasks:**

#### **A. Assignment Models (`operations` app):**
- Create `OperatorAssignment` model:
  - Links: operator (AppUser FK) + ShiftCenter + RoleMaster
  - Status: PENDING / ASSIGNED / CONFIRMED / CANCELLED / NO_SHOW / COMPLETED
  - assignment_type: PRIMARY / BUFFER
  - payout_amount, is_paid
  - assigned_at, confirmed_at, completed_at
  - Indexes: (operator_id, status), (shift_center_id, role_id)

#### **B. Assignment Logic:**
- **Auto-assignment rules:**
  - Only assign VERIFIED operators (OperatorProfile.kyc_status = VERIFIED)
  - Check role requirements (gender, age_min if specified)
  - Prevent double-booking (operator can't have 2 assignments at same time)
  - Respect headcount limits (ShiftCenterRole.headcount)
- **Manual assignment override:**
  - Admin can manually assign specific operator
  - Admin can bulk assign from list of operators

#### **C. APIs:**
- **Admin endpoints:**
  - `POST /api/assignments/bulk-create/` (auto-assign based on rules)
  - `POST /api/assignments/manual/` (manual assignment)
  - `GET /api/assignments/` (list with filters: exam, shift, center, operator, status)
  - `PATCH /api/assignments/{id}/status/` (update status)
- **Operator endpoints:**
  - `GET /api/assignments/my-duties/` (operator's assignments)
  - `POST /api/assignments/{id}/confirm/` (operator confirms)
  - `POST /api/assignments/{id}/decline/` (operator declines - if allowed)

#### **D. Notifications (Optional - Week 5 or later):**
- Send notification when operator is assigned
- Send reminder 24h before shift

### **Flutter (Android) - Key Tasks:**
- **"My Duties" screen:**
  - List of assignments (upcoming, today, past)
  - Filter by status (pending, confirmed, completed)
  - Card shows: Exam name, Center name, Shift time, Role
- **Duty details screen:**
  - Full center info (address, GPS, incharge contact)
  - Shift details (reporting time, start time, instructions)
  - Role-specific instructions (from RoleMaster)
  - Confirm/Decline buttons (if status allows)
  - "Navigate to Center" button (opens Google Maps)
- **Assignment status updates:**
  - Pull-to-refresh
  - Real-time status changes

**Deliverable / Demo:** 
- Demo: Admin bulk assigns 100 operators to 50 centers → Operators receive assignments
- Operator opens app → Sees "My Duties: 2 assignments" → Confirms one → Status updates
- Operator can see center address, GPS, and navigate

**Dependencies / Risks:**
- Need center+shift ready (Week 4 dependency)
- High load on listing endpoints (N+1 queries - use select_related/prefetch_related)
- Assignment conflicts (same operator, same time)
- Operator availability (optional: OperatorAvailability model for future)

**Status:** Planned  
**Progress %:** 0%

---

## **Week 6: Attendance v1 (Check-In/Out + Geo)**

**Focus / Goal:** Track operator presence at center with GPS validation

### **Backend (Django) - Key Tasks:**

#### **A. Attendance Models (`attendance` app):**
- Create `CheckIn` model:
  - Links: OperatorAssignment FK
  - check_in_time (timestamp)
  - latitude, longitude (GPS at check-in)
  - distance_from_center (calculated)
  - device_info (optional: device_id, OS version)
  - selfie_photo (optional - for audit)
  - status: ON_TIME / LATE / EARLY
- Create `CheckOut` model:
  - Links: OperatorAssignment FK
  - check_out_time (timestamp)
  - latitude, longitude
  - total_duty_hours (calculated)
  - notes (optional)

#### **B. Geo-Validation Logic:**
- **Geo-fencing rules:**
  - Get center GPS from ExamCenter (or GlobalCenter if linked)
  - Calculate distance using Haversine formula
  - **Allow check-in if distance < geofence_radius** (default 200m, configurable per center)
  - Return error with distance if outside radius
- **Time validation:**
  - Check-in allowed: reporting_time - 30min to start_time + 15min
  - Check-out allowed: after end_time

#### **C. APIs:**
- `POST /api/attendance/check-in/`:
  - Accepts: assignment_id, latitude, longitude, selfie (optional)
  - Validates GPS distance
  - Creates CheckIn record
  - Returns: status (ON_TIME/LATE), distance, center_info
- `POST /api/attendance/check-out/`:
  - Accepts: assignment_id, latitude, longitude, notes
  - Creates CheckOut record
  - Calculates duty hours
- `GET /api/attendance/my-history/` (operator view)
- **Admin endpoints:**
  - `GET /api/attendance/live/` (real-time attendance for shift)
  - `GET /api/attendance/summary/` (aggregated by center, shift, date)

#### **D. Background Jobs:**
- Auto-checkout if operator forgets (after end_time + 2 hours)
- Calculate attendance statistics

### **Flutter (Android) - Key Tasks:**
- **Check-in UI:**
  - Show assignment details (center name, shift time)
  - Request location permission
  - Capture current GPS
  - Show distance to center (before submitting)
  - Optional: Capture selfie for audit
  - Submit check-in → Show success/error
- **Check-out UI:**
  - Similar to check-in
  - Show total duty hours
  - Optional notes field
- **Attendance history:**
  - List of past check-ins/outs
  - Show status (ON_TIME, LATE)
- **Offline-friendly:**
  - Queue check-in/out if network fails
  - Retry when network available
  - Show "Pending sync" indicator

**Deliverable / Demo:** 
- Demo: Operator reaches center → Opens app → Checks in → GPS validated (within 200m) → Success
- Operator too far (500m away) → Error: "You are 500m away from center. Please move closer."
- Admin dashboard shows: "Live Attendance: 45/50 operators checked in"

**Dependencies / Risks:**
- GPS accuracy (indoor vs outdoor, device quality)
- Location permission prompts (Android 12+)
- Offline networks (center in remote area)
- Device time skew (server time vs device time)
- Battery drain from constant GPS

**Status:** Planned  
**Progress %:** 0%

---

## **Week 7: Incident / Support v1 + Media Upload**

**Focus / Goal:** Allow operators to report issues at center with photo evidence

### **Backend (Django) - Key Tasks:**

#### **A. Incident Models (`incidents` app):**
- Create `Incident` model:
  - Links: OperatorAssignment FK (or ShiftCenter if reported by admin)
  - category: TECHNICAL / SECURITY / CANDIDATE_ISSUE / INFRASTRUCTURE / OTHER
  - severity: LOW / MEDIUM / HIGH / CRITICAL
  - title, description (text)
  - status: REPORTED / ACKNOWLEDGED / IN_PROGRESS / RESOLVED / CLOSED
  - reported_by (operator FK)
  - assigned_to (admin FK - optional)
  - resolution_notes
  - reported_at, resolved_at
  - Indexes: (assignment_id), (status), (category)

#### **B. Media Upload:**
- Create `IncidentAttachment` model:
  - Links: Incident FK
  - file_url (stores path to S3/local storage)
  - file_type: IMAGE / VIDEO / DOCUMENT
  - uploaded_at
- **Upload endpoint:**
  - `POST /api/incidents/{id}/upload/` (multipart/form-data)
  - Validate file size (max 10MB for images, 50MB for videos)
  - Validate file type (jpg, png, mp4, pdf)
  - Store in media/incidents/{incident_id}/
  - Return file URL

#### **C. APIs:**
- `POST /api/incidents/` (operator reports incident)
- `GET /api/incidents/my-reports/` (operator view)
- `GET /api/incidents/{id}/` (details with attachments)
- **Admin endpoints:**
  - `GET /api/incidents/` (list with filters: status, category, center, date)
  - `PATCH /api/incidents/{id}/status/` (update status, assign, add resolution)
  - `GET /api/incidents/dashboard/` (summary: open incidents, by category, by center)

#### **D. Notifications (Optional):**
- Notify admin when critical incident reported
- Notify operator when incident resolved

### **Flutter (Android) - Key Tasks:**
- **Raise incident screen:**
  - Category dropdown
  - Severity selector
  - Title and description fields
  - Attach photo button (camera or gallery)
  - Preview attached images
  - Submit → Show success
- **My incidents screen:**
  - List of reported incidents
  - Filter by status
  - Show status badge (REPORTED, IN_PROGRESS, RESOLVED)
- **Incident details screen:**
  - Full incident info
  - View attached photos
  - Status timeline
  - Resolution notes (if resolved)

**Deliverable / Demo:** 
- Demo: Operator reports "Internet down" at center → Attaches photo of router → Admin sees in dashboard
- Admin updates status to "RESOLVED" → Operator sees resolution in app

**Dependencies / Risks:**
- Storage choice (S3 vs local - S3 recommended for production)
- File size limits (network upload time)
- Network reliability (large video files)
- Image compression (reduce file size before upload)

**Status:** Planned  
**Progress %:** 0%

---

## **Week 8: Reporting + Exports + Operational Dashboards**

**Focus / Goal:** Provide insights and data exports for management

### **Backend (Django) - Key Tasks:**

#### **A. Reporting Endpoints:**
- **Assignments report:**
  - `GET /api/reports/assignments/`
  - Filters: exam, shift, center, date range, status
  - Aggregations: total assigned, confirmed, cancelled, no-show
  - Group by: center, shift, role
- **Attendance report:**
  - `GET /api/reports/attendance/`
  - Filters: exam, shift, center, date
  - Metrics: check-in rate, on-time rate, average check-in time
  - Group by: center, shift, operator
- **Incidents report:**
  - `GET /api/reports/incidents/`
  - Filters: category, severity, status, date range
  - Aggregations: total incidents, by category, resolution time
- **Operator performance:**
  - `GET /api/reports/operators/`
  - Metrics: assignments completed, attendance rate, incidents reported
  - Rankings: top performers, frequent no-shows

#### **B. CSV Export:**
- `GET /api/reports/assignments/export/` (returns CSV)
- `GET /api/reports/attendance/export/`
- `GET /api/reports/incidents/export/`
- Use Django's CSVResponse or pandas for large datasets

#### **C. Dashboard Aggregations:**
- `GET /api/dashboard/overview/`:
  - Today's active exams
  - Live attendance count
  - Open incidents count
  - Upcoming assignments (next 7 days)
- `GET /api/dashboard/exam/{exam_id}/`:
  - Exam-specific metrics
  - Center-wise breakdown
  - Shift-wise attendance

#### **D. Performance Optimization:**
- Add database indexes on frequently queried fields
- Use select_related/prefetch_related to avoid N+1 queries
- Cache dashboard data (Redis optional, or simple in-memory cache)
- Pagination for large result sets

### **Flutter (Android) - Key Tasks:**
- **Simple dashboard tiles:**
  - My duties count (upcoming, today, completed)
  - My attendance status (on-time rate)
  - My incidents reported
- **Basic charts (optional):**
  - Attendance trend (last 7 days)
  - Duty completion rate
- **Note:** Full reporting/export kept on web/admin panel (not in mobile app)

**Deliverable / Demo:** 
- Demo: Manager opens dashboard → Sees "JEE 2026: 450/500 operators checked in, 3 critical incidents"
- Exports attendance CSV → Opens in Excel → Analyzes center-wise performance

**Dependencies / Risks:**
- Query performance with large datasets (10k+ assignments)
- Permissions leakage (client admin seeing other clients' data)
- CSV file size (memory usage for large exports)
- Real-time updates (websockets optional for live dashboard)

**Status:** Planned  
**Progress %:** 0%

---

## **Week 9: Hardening: RBAC, Security, Throttling, Cleanup**

**Focus / Goal:** Secure the system and clean up sensitive data

### **Backend (Django) - Key Tasks:**

#### **A. RBAC (Role-Based Access Control):**
- **Permission classes:**
  - `IsInternalAdmin` (already exists)
  - `IsClientAdmin` (can only access their client's data)
  - `IsOperator` (can only access own data)
  - `IsClientAdminOrInternal` (for shared resources)
- **Client scoping:**
  - All queries filtered by `request.user.client` (if CLIENT_ADMIN)
  - Prevent cross-client data access
  - Test with multiple clients in same database
- **Endpoint protection:**
  - Review all endpoints for proper permission classes
  - Add client filtering where needed

#### **B. Rate Limiting:**
- **OTP endpoints:**
  - `/api/identity/operator/otp/request/`: 3 requests per mobile per hour
  - `/api/identity/operator/otp/verify/`: 5 attempts per session
- **KYC endpoints:**
  - `/api/kyc/aadhaar/start/`: 5 requests per user per day (cooldown already exists)
  - `/api/kyc/face/liveness/`: 3 attempts per session
  - `/api/kyc/face/match/`: 3 attempts per session
- **Check-in endpoint:**
  - `/api/attendance/check-in/`: 1 per assignment (idempotent)
- Use Django's `django-ratelimit` or DRF throttling

#### **C. Sensitive Data Cleanup:**
- **KYC data:**
  - Clear `id_card_image_b64` after verification completes (already in code)
  - Management command: `cleanup_expired_kyc_sessions`
    - Delete sessions older than 30 days
    - Clear sensitive fields from completed sessions
- **OTP data:**
  - Management command: `cleanup_expired_otp_sessions`
    - Delete verified OTPs older than 7 days
    - Delete expired unverified OTPs
- **Incident attachments:**
  - Optional: Auto-delete attachments older than 1 year (legal compliance)

#### **D. Security Headers:**
- Add CORS whitelist (remove CORS_ALLOW_ALL_ORIGINS in production)
- Add security headers (X-Frame-Options, X-Content-Type-Options)
- Enable HTTPS only (SECURE_SSL_REDIRECT)
- Add CSRF protection for admin endpoints

#### **E. Audit Logging:**
- Create `AuditLog` model (optional):
  - Track: who, what, when, IP address
  - Log critical actions: assignment changes, incident status updates, center blacklisting
- Or use Django's `django-auditlog` package

### **Flutter (Android) - Key Tasks:**
- **Session handling:**
  - Logout on 401 (token expired/invalid)
  - Clear secure storage on logout
  - Handle token refresh failures gracefully
- **Error screens:**
  - User-friendly error messages
  - Retry patterns for network failures
  - "Contact support" option for persistent errors
- **Secure storage hygiene:**
  - Encrypt sensitive data (already using flutter_secure_storage)
  - Clear tokens on app uninstall (automatic)
  - No sensitive data in logs

**Deliverable / Demo:** 
- Demo: Client Admin tries to access another client's centers → 403 Forbidden
- OTP request rate limited → User sees "Too many requests. Try again in 1 hour."
- Cleanup command runs → Expired KYC sessions cleared
- Security audit: All endpoints have proper permissions

**Dependencies / Risks:**
- Policy decisions (what data to store, retention period)
- Vendor/legal constraints (Aadhaar data retention rules)
- Performance impact of client filtering on every query

**Status:** Planned  
**Progress %:** 0%

---

## **Week 10: Performance + Reliability**

**Focus / Goal:** Optimize for scale and handle edge cases

### **Backend (Django) - Key Tasks:**

#### **A. Load Testing:**
- **Key endpoints to test:**
  - `/api/identity/operator/otp/request/` (high volume)
  - `/api/assignments/my-duties/` (operator listing)
  - `/api/attendance/check-in/` (exam day spike)
  - `/api/centers/bulk-import/` (large CSV)
- Use `locust` or `JMeter` for load testing
- Target: 100 concurrent users, 1000 requests/minute

#### **B. Database Optimization:**
- **Add indexes:**
  - `app_user.mobile_primary` (for OTP lookup)
  - `operator_assignment(operator_id, status)` (for my-duties)
  - `check_in(assignment_id, check_in_time)` (for attendance queries)
  - `incident(status, reported_at)` (for dashboard)
- **Query optimization:**
  - Use `select_related()` for FK relationships
  - Use `prefetch_related()` for reverse FK/M2M
  - Avoid N+1 queries in list endpoints
  - Add `only()` / `defer()` for large text fields

#### **C. Caching:**
- **Cache frequently accessed data:**
  - Role Master list (rarely changes)
  - Client list (for admin dropdowns)
  - Exam details (during exam day)
- Use Django's cache framework (Redis recommended, or in-memory for small scale)
- Cache TTL: 1 hour for master data, 5 minutes for exam data

#### **D. Background Jobs (Optional):**
- Use `celery` + `redis` for heavy tasks:
  - Bulk center import processing
  - Auto-linking ExamCenter → GlobalCenter
  - Sending notifications
  - Generating large CSV exports
- Or use Django's `management commands` + cron for simpler setup

#### **E. Error Handling:**
- Comprehensive error logging (use `sentry` or similar)
- Graceful degradation (if Surepass API down, show friendly error)
- Retry logic for external API calls
- Database connection pooling

### **Flutter (Android) - Key Tasks:**
- **App performance:**
  - Image upload progress indicators
  - Lazy loading for long lists
  - Image caching (reduce network calls)
  - Reduce app size (remove unused assets)
- **Crash handling:**
  - Reduce crashes (handle null safety)
  - Handle low memory scenarios
  - Graceful handling of camera failures
- **Analytics (Optional):**
  - Log key events (check-in, incident report)
  - Track app performance metrics
  - Use `firebase_analytics` or similar

**Deliverable / Demo:** 
- Demo: Load test results → 100 concurrent users handled successfully
- Before/after query performance (N+1 fixed, indexes added)
- App memory usage reduced by 20%

**Dependencies / Risks:**
- Emulator vs real device differences (test on real devices)
- Infrastructure scaling (database, server resources)
- Third-party API reliability (Surepass)

**Status:** Planned  
**Progress %:** 0%

---

## **Week 11: UAT & Bug-Fix Sprint**

**Focus / Goal:** End-to-end testing and bug fixes

### **Backend (Django) - Key Tasks:**
- **End-to-end UAT scenarios:**
  - Full operator journey: Register → KYC → Assignment → Check-in → Duty → Check-out
  - Admin journey: Create exam → Allocate centers → Assign operators → View reports
  - Edge cases: App reinstall, network drop, GPS failure, expired sessions
- **Test scripts:**
  - Automated tests for critical flows (Django TestCase)
  - Manual test checklist
  - Performance regression tests
- **Bug fixes:**
  - Fix edge cases discovered in UAT
  - Regression tests for auth/KYC/attendance
  - Fix data inconsistencies

### **Flutter (Android) - Key Tasks:**
- **UAT build:**
  - Release candidate build
  - Test on multiple devices (Android 10, 11, 12, 13+)
  - Test on different screen sizes
- **UI polish:**
  - Fix UX rough edges
  - Improve error messages
  - Add loading states everywhere
  - Improve navigation flow
- **Stabilize navigation:**
  - Fix routing state machine
  - Handle deep links (if needed)
  - Handle app state restoration

**Deliverable / Demo:** 
- Demo: Full UAT walk-through with stakeholders
- UAT checklist signed off
- All critical bugs fixed
- Performance benchmarks met

**Dependencies / Risks:**
- Stakeholder feedback may shift scope
- Time pressure (may need to defer non-critical bugs)
- Device-specific issues (only discovered in UAT)

**Status:** Planned  
**Progress %:** 0%

---

## **Week 12: Release Prep (Deployment + Monitoring)**

**Focus / Goal:** Production deployment and monitoring setup

### **Backend (Django) - Key Tasks:**

#### **A. Production Configuration:**
- **uWSGI config:**
  - Workers, threads, timeout settings
  - Static file serving
  - Log file locations
- **Nginx configuration:**
  - Reverse proxy setup
  - Static/media file serving
  - SSL certificate setup
  - Rate limiting at Nginx level
- **Production settings:**
  - `DEBUG = False`
  - `ALLOWED_HOSTS` configured
  - Database connection pooling
  - Secure secret key (environment variable)
  - Media files on S3 or separate storage

#### **B. Logging & Monitoring:**
- **Application logging:**
  - Structured logging (JSON format)
  - Log levels (INFO, WARNING, ERROR)
  - Log rotation
- **Monitoring:**
  - Server health checks (`/api/health/`)
  - Database connection monitoring
  - API response time tracking
  - Error rate tracking
  - Use `sentry` for error tracking
  - Optional: `prometheus` + `grafana` for metrics

#### **C. Backup & Restore:**
- **Database backups:**
  - Daily automated backups
  - Backup retention (7 days daily, 4 weeks weekly)
  - Test restore procedure
- **Media file backups:**
  - S3 versioning or separate backup
- **Disaster recovery plan:**
  - Document recovery steps
  - Test recovery procedure

#### **D. Rollout Plan:**
- **Staging deployment:**
  - Deploy to staging environment
  - Run smoke tests
  - Get stakeholder approval
- **Production rollout:**
  - Blue-green deployment (if possible)
  - Or gradual rollout (10% → 50% → 100%)
  - Rollback plan documented
- **Runbooks:**
  - Common issues and solutions
  - Escalation procedures
  - On-call rotation

### **Flutter (Android) - Key Tasks:**
- **Release build:**
  - Release signing key configured
  - Version code and version name set
  - ProGuard/R8 rules (if using)
  - App bundle created (AAB for Play Store)
- **Versioning strategy:**
  - Semantic versioning (1.0.0)
  - Version code increments
  - Update strategy (force update vs optional)
- **Crash reporting:**
  - Integrate `firebase_crashlytics` or `sentry_flutter`
  - Test crash reporting
- **App Store preparation:**
  - Screenshots, descriptions
  - Privacy policy URL
  - Play Store listing

**Deliverable / Demo:** 
- Demo: Staging deployment successful
- Health check endpoint working
- Monitoring dashboard showing metrics
- Release checklist completed
- Rollout plan approved

**Dependencies / Risks:**
- Infrastructure access (server, database, S3)
- Secrets management (API keys, database passwords)
- SSL certificates (Let's Encrypt or purchased)
- App store review process (Play Store approval time)

**Status:** Planned  
**Progress %:** 0%

---

## **Summary of Critical Architecture Decisions:**

1. **Master vs Operational Separation:** GlobalCenter (analysis) vs ExamCenter (immediate activation)
2. **Alias Handling:** ClientCenterMapping (same building, different client codes)
3. **Snapshot Logic:** ExamCenter created immediately from CSV, linked to Master in background
4. **Geo-Fencing:** GPS validation for check-in (200m radius, configurable)
5. **Role-Based Operations:** RoleMaster → ShiftCenterRole (headcount) → OperatorAssignment (execution)

---

## **Risk Mitigation:**

- **High Volume:** Bulk import with background processing
- **Data Conflicts:** Fuzzy matching + manual review dashboard
- **Performance:** Indexes, caching, query optimization
- **Security:** RBAC, rate limiting, data cleanup
- **Reliability:** Error handling, retry logic, monitoring

---

**Total Duration:** 12 Weeks  
**Start Date:** Week 1 (TBD)  
**Target Completion:** Week 12 (TBD)

