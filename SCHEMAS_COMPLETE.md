# Complete Database Schemas for Masters, Operations & Assignments Apps

## 📋 Table of Contents
1. [Masters App Schemas](#1-masters-app-schemas)
2. [Operations App Schemas](#2-operations-app-schemas)
3. [Assignments App Schemas](#3-assignments-app-schemas)
4. [Relationships Diagram](#relationships-diagram)

---

## 1. Masters App Schemas

### 1.1 Client Model
**Purpose:** Global master list of all clients (NTA, UPSC, etc.)

```python
class Client(TimeStampedUUIDModel):
    # Identity
    client_code = models.CharField(max_length=50, unique=True, db_index=True)
    name = models.CharField(max_length=255)
    slug = models.SlugField(max_length=100, unique=True, null=True, blank=True)  # For URLs
    logo = models.ImageField(upload_to='client_logos/', null=True, blank=True)
    
    # Primary Contact
    primary_contact_name = models.CharField(max_length=150, null=True, blank=True)
    primary_contact_email = models.EmailField(null=True, blank=True)
    primary_contact_phone = models.CharField(max_length=20, null=True, blank=True)
    
    # Secondary Contact
    secondary_contact_name = models.CharField(max_length=150, null=True, blank=True)
    secondary_contact_email = models.EmailField(null=True, blank=True)
    secondary_contact_phone = models.CharField(max_length=20, null=True, blank=True)
    
    # Address
    address_line1 = models.CharField(max_length=255, null=True, blank=True)
    address_line2 = models.CharField(max_length=255, null=True, blank=True)
    city = models.CharField(max_length=100, null=True, blank=True)
    state = models.CharField(max_length=100, null=True, blank=True)
    pincode = models.CharField(max_length=20, null=True, blank=True)
    country = models.CharField(max_length=100, default="India")
    
    # Status & Analytics (Denormalized - updated via signals)
    STATUS_CHOICES = (
        ('ACTIVE', 'Active'),
        ('INACTIVE', 'Inactive'),
        ('PROSPECT', 'Prospect'),
    )
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='ACTIVE')
    exam_count = models.IntegerField(default=0)  # Total exams ever created
    exam_active_count = models.IntegerField(default=0)  # Currently active exams
    
    # Contract dates (for access control)
    contract_start_date = models.DateField(null=True, blank=True)
    contract_end_date = models.DateField(null=True, blank=True)
    
    class Meta:
        db_table = 'client'
        indexes = [
            models.Index(fields=['client_code']),
            models.Index(fields=['status']),
        ]
    
    def __str__(self):
        return f"{self.name} ({self.client_code})"
```

---

### 1.2 CenterMaster Model
**Purpose:** Global master list of all physical centers (for analysis)

```python
class CenterMaster(TimeStampedUUIDModel):
    # Identity
    center_code = models.CharField(max_length=50, unique=True, db_index=True)
    name = models.CharField(max_length=255)
    
    # Classification
    CENTER_VARIETY_CHOICES = (
        ('EXAM', 'Exam Center'),
        ('MARKFED', 'Markfed'),
        ('DEMO', 'Demo'),
    )
    center_variety = models.CharField(max_length=20, choices=CENTER_VARIETY_CHOICES, null=True, blank=True)
    
    CENTER_TYPE_CHOICES = (
        ('SCHOOL', 'School'),
        ('COLLEGE', 'College'),
        ('UNIVERSITY', 'University'),
        ('PRIVATE_LAB', 'Private Lab'),
        ('COACHING', 'Coaching Center'),
        ('OTHER', 'Other'),
    )
    center_type = models.CharField(max_length=50, choices=CENTER_TYPE_CHOICES, null=True, blank=True)
    
    OWNERSHIP_CHOICES = (
        ('GOVT', 'Government'),
        ('PRIVATE', 'Private'),
        ('AIDED', 'Aided'),
        ('OTHER', 'Other'),
    )
    ownership_type = models.CharField(max_length=50, choices=OWNERSHIP_CHOICES, null=True, blank=True)
    
    # Address
    address = models.CharField(max_length=255, null=True, blank=True)
    area = models.CharField(max_length=150, null=True, blank=True)
    city = models.CharField(max_length=100, null=True, blank=True)
    district = models.CharField(max_length=100, null=True, blank=True)
    state = models.CharField(max_length=100, null=True, blank=True)
    pincode = models.CharField(max_length=20, null=True, blank=True)
    country = models.CharField(max_length=100, default="India")
    
    # Geo (Critical for Check-In validation)
    latitude = models.DecimalField(max_digits=10, decimal_places=6, null=True, blank=True)
    longitude = models.DecimalField(max_digits=10, decimal_places=6, null=True, blank=True)
    geofence_radius_meters = models.IntegerField(default=200)  # Default 200m for check-in
    
    # Capacity (Permanent infrastructure)
    total_rooms = models.IntegerField(null=True, blank=True)
    total_labs = models.IntegerField(null=True, blank=True)
    max_candidates_overall = models.IntegerField(null=True, blank=True)
    max_computers = models.IntegerField(null=True, blank=True)
    buffer_candidates_count = models.IntegerField(default=0)  # Extra seats for emergencies
    
    # Infrastructure (for digital exams)
    internet_speed_mbps = models.DecimalField(max_digits=5, decimal_places=2, null=True, blank=True)
    has_generator_backup = models.BooleanField(default=False)
    total_computers_functional = models.IntegerField(null=True, blank=True)
    
    # Contact (Permanent in-charge)
    incharge_name = models.CharField(max_length=150, null=True, blank=True)
    incharge_phone = models.CharField(max_length=20, null=True, blank=True)
    incharge_email = models.EmailField(null=True, blank=True)
    alt_contact_name = models.CharField(max_length=150, null=True, blank=True)
    alt_contact_phone = models.CharField(max_length=20, null=True, blank=True)
    
    # Status & Quality
    STATUS_CHOICES = (
        ('ACTIVE', 'Active'),
        ('INACTIVE', 'Inactive'),
        ('BLACKLISTED', 'Blacklisted'),
        ('UNDER_REVIEW', 'Under Review'),
    )
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='ACTIVE')
    rating = models.FloatField(null=True, blank=True)  # Average rating from past exams
    remarks = models.TextField(null=True, blank=True)
    
    # Analytics (Denormalized)
    total_exams_conducted = models.IntegerField(default=0)
    last_exam_date = models.DateField(null=True, blank=True)
    
    class Meta:
        db_table = 'center_master'
        indexes = [
            models.Index(fields=['center_code']),
            models.Index(fields=['city', 'state']),
            models.Index(fields=['status']),
            models.Index(fields=['latitude', 'longitude']),  # For geo queries
        ]
    
    def __str__(self):
        return f"{self.name} ({self.center_code})"
```

---

### 1.3 RoleMaster Model
**Purpose:** Global master list of all job roles (Invigilator, Frisking, etc.)

```python
class RoleMaster(TimeStampedUUIDModel):
    # Identity
    code = models.CharField(max_length=50, unique=True, db_index=True)
    name = models.CharField(max_length=100)
    description = models.TextField(null=True, blank=True)
    instruction = models.TextField(null=True, blank=True)  # What to do on exam day
    
    # Training
    training_video_url = models.URLField(max_length=500, null=True, blank=True)
    requires_training_completion = models.BooleanField(default=False)  # Must watch video before check-in
    
    # Requirements
    dress_code = models.CharField(max_length=255, null=True, blank=True)
    age_min = models.IntegerField(null=True, blank=True)
    age_max = models.IntegerField(null=True, blank=True)
    
    GENDER_CHOICES = (
        ('MALE', 'Male'),
        ('FEMALE', 'Female'),
        ('ALL', 'All'),
    )
    gender_requirement = models.CharField(max_length=20, choices=GENDER_CHOICES, default='ALL')
    
    # Visual
    tag_color = models.CharField(max_length=50, null=True, blank=True)  # For ID cards/badges
    
    # Financial (for payroll)
    default_pay_rate = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    
    # Status
    is_active = models.BooleanField(default=True)
    
    class Meta:
        db_table = 'role'
        indexes = [
            models.Index(fields=['code']),
            models.Index(fields=['is_active']),
        ]
    
    def __str__(self):
        return f"{self.name} ({self.code})"
```

---

## 2. Operations App Schemas

### 2.1 Exam Model
**Purpose:** Specific exam event (JEE 2026, UPSC 2026, etc.)

```python
class Exam(TimeStampedUUIDModel):
    # Identity
    exam_code = models.CharField(max_length=50, unique=True, db_index=True)
    name = models.CharField(max_length=255)
    
    # Client Link
    client = models.ForeignKey('masters.Client', on_delete=models.PROTECT, related_name='exams')
    
    # Type
    exam_type = models.CharField(max_length=50, null=True, blank=True)  # e.g., "Engineering", "Medical"
    
    # Date Window
    exam_start_date = models.DateField(null=True, blank=True)
    exam_end_date = models.DateField(null=True, blank=True)
    
    # Status Lifecycle
    STATUS_CHOICES = (
        ('DRAFT', 'Draft'),
        ('CONFIGURING', 'Configuring'),
        ('READY', 'Ready'),
        ('LIVE', 'Live'),
        ('COMPLETED', 'Completed'),
        ('CANCELLED', 'Cancelled'),
        ('ARCHIVED', 'Archived'),
    )
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='DRAFT')
    
    # Additional Info
    description = models.TextField(null=True, blank=True)
    attachments_url = models.TextField(null=True, blank=True)  # JSON or comma-separated URLs
    
    # Audit
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name='exams_created'
    )
    updated_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name='exams_updated'
    )
    
    class Meta:
        db_table = 'exam'
        indexes = [
            models.Index(fields=['exam_code']),
            models.Index(fields=['client']),
            models.Index(fields=['status']),
            models.Index(fields=['exam_start_date', 'exam_end_date']),
        ]
    
    def __str__(self):
        return f"{self.name} ({self.exam_code})"
```

---

### 2.2 Shift Model
**Purpose:** Specific shift within an exam (Morning, Afternoon, etc.)

```python
class Shift(TimeStampedUUIDModel):
    # Link to Exam
    exam = models.ForeignKey('Exam', on_delete=models.CASCADE, related_name='shifts')
    
    # Identity
    shift_code = models.CharField(max_length=100)
    name = models.CharField(max_length=150, null=True, blank=True)  # "Morning Shift", "Afternoon Shift"
    session_number = models.IntegerField(null=True, blank=True)  # 1, 2, 3...
    
    # Date & Time
    work_date = models.DateField()
    start_time = models.TimeField()
    end_time = models.TimeField()
    reporting_time = models.TimeField(null=True, blank=True)  # When staff should arrive
    gate_close_time = models.TimeField(null=True, blank=True)  # When gate closes for candidates
    exam_duration_minutes = models.IntegerField(null=True, blank=True)
    
    # Type
    SHIFT_TYPE_CHOICES = (
        ('DEMO', 'Demo'),
        ('MAIN', 'Main'),
    )
    shift_type = models.CharField(max_length=20, choices=SHIFT_TYPE_CHOICES, default='MAIN')
    
    # Status
    STATUS_CHOICES = (
        ('DRAFT', 'Draft'),
        ('CONFIGURING', 'Configuring'),
        ('READY', 'Ready'),
        ('LIVE', 'Live'),
        ('COMPLETED', 'Completed'),
        ('CANCELLED', 'Cancelled'),
    )
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='DRAFT')
    
    # Notes
    instructions = models.TextField(null=True, blank=True)
    remarks = models.TextField(null=True, blank=True)
    
    # Audit
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name='shifts_created'
    )
    updated_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name='shifts_updated'
    )
    
    class Meta:
        db_table = 'shift'
        unique_together = [['exam', 'shift_code']]
        indexes = [
            models.Index(fields=['exam', 'work_date']),
            models.Index(fields=['status']),
        ]
    
    def __str__(self):
        return f"{self.exam.name} - {self.shift_code} ({self.work_date})"
```

---

### 2.3 ExamCenter Model
**Purpose:** Center activated for a specific exam (links Exam + CenterMaster, nullable)

```python
class ExamCenter(TimeStampedUUIDModel):
    # Links
    exam = models.ForeignKey('Exam', on_delete=models.CASCADE, related_name='exam_centers')
    master_center = models.ForeignKey(
        'masters.CenterMaster',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='exam_centers'
    )  # NULLABLE - can be linked later for analysis
    
    # Client-provided data (Snapshot - what client sent)
    client_center_code = models.CharField(max_length=50, db_index=True)  # Client's code (101, 501, etc.)
    client_center_name = models.CharField(max_length=255)  # Client's name (may differ from master)
    
    # Exam-specific GPS (may differ from master if gate location)
    latitude = models.DecimalField(max_digits=10, decimal_places=6, null=True, blank=True)
    longitude = models.DecimalField(max_digits=10, decimal_places=6, null=True, blank=True)
    geofence_radius_meters = models.IntegerField(default=200)
    
    # Exam-specific capacity (may be less than master capacity)
    active_capacity = models.IntegerField(null=True, blank=True)  # How many seats available for this exam
    expected_candidates = models.IntegerField(default=0)
    
    # Exam-specific contact (may differ from master)
    incharge_name = models.CharField(max_length=150, null=True, blank=True)
    incharge_phone = models.CharField(max_length=20, null=True, blank=True)
    
    # Exam-specific location details
    lab_room_info = models.CharField(max_length=255, null=True, blank=True)  # "Block A, 2nd Floor"
    client_specific_instructions = models.TextField(null=True, blank=True)
    
    # Status
    STATUS_CHOICES = (
        ('ACTIVE', 'Active'),
        ('INACTIVE', 'Inactive'),
        ('BLACKLISTED', 'Blacklisted'),
    )
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='ACTIVE')
    
    # Notes
    remarks = models.TextField(null=True, blank=True)
    
    class Meta:
        db_table = 'exam_center'
        unique_together = [['exam', 'client_center_code']]  # One center code per exam
        indexes = [
            models.Index(fields=['exam']),
            models.Index(fields=['master_center']),
            models.Index(fields=['client_center_code']),
            models.Index(fields=['status']),
        ]
    
    def __str__(self):
        return f"{self.exam.name} - {self.client_center_name} ({self.client_center_code})"
```

---

### 2.4 ShiftCenter Model
**Purpose:** Links Shift to ExamCenter (creates "Job Site")

```python
class ShiftCenter(TimeStampedUUIDModel):
    # Links
    exam = models.ForeignKey('Exam', on_delete=models.CASCADE, related_name='shift_centers')
    shift = models.ForeignKey('Shift', on_delete=models.CASCADE, related_name='shift_centers')
    exam_center = models.ForeignKey('ExamCenter', on_delete=models.CASCADE, related_name='shift_centers')
    
    # Notes
    notes = models.TextField(null=True, blank=True)
    
    # Status
    STATUS_CHOICES = (
        ('PLANNED', 'Planned'),
        ('CONFIRMED', 'Confirmed'),
        ('CANCELLED', 'Cancelled'),
    )
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='PLANNED')
    
    class Meta:
        db_table = 'shift_center'
        unique_together = [['exam', 'shift', 'exam_center']]  # One shift-center combo per exam
        indexes = [
            models.Index(fields=['shift', 'exam_center']),
            models.Index(fields=['status']),
        ]
    
    def __str__(self):
        return f"{self.shift.shift_code} - {self.exam_center.client_center_name}"
```

---

### 2.5 ShiftCenterRole Model
**Purpose:** Headcount requirement per role at a shift-center

```python
class ShiftCenterRole(TimeStampedUUIDModel):
    # Links
    shift_center = models.ForeignKey('ShiftCenter', on_delete=models.CASCADE, related_name='role_requirements')
    role = models.ForeignKey('masters.RoleMaster', on_delete=models.PROTECT, related_name='shift_center_assignments')
    
    # Headcount
    headcount = models.IntegerField()  # Required staff count
    buffer_headcount = models.IntegerField(default=0)  # Standby staff
    
    # Gender split (for roles requiring specific gender)
    male_count = models.IntegerField(null=True, blank=True)
    female_count = models.IntegerField(null=True, blank=True)
    
    # Notes
    remarks = models.TextField(null=True, blank=True)
    
    class Meta:
        db_table = 'shift_center_role'
        unique_together = [['shift_center', 'role']]  # One headcount per role per shift-center
        indexes = [
            models.Index(fields=['shift_center', 'role']),
        ]
    
    def __str__(self):
        return f"{self.shift_center} - {self.role.name} (Need: {self.headcount})"
```

---

## 3. Assignments App Schemas

### 3.1 OperatorAssignment Model
**Purpose:** Links verified operator to a specific job (Shift + Center + Role)

```python
class OperatorAssignment(TimeStampedUUIDModel):
    # Links
    shift_center = models.ForeignKey('operations.ShiftCenter', on_delete=models.CASCADE, related_name='assignments')
    operator = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='assignments',
        limit_choices_to={'user_type': 'OPERATOR'}
    )
    role = models.ForeignKey('masters.RoleMaster', on_delete=models.PROTECT, related_name='assignments')
    
    # Status Lifecycle
    STATUS_CHOICES = (
        ('PENDING', 'Pending'),  # Assigned but not confirmed
        ('CONFIRMED', 'Confirmed'),  # Operator confirmed
        ('CANCELLED', 'Cancelled'),  # Cancelled by admin or operator
        ('NO_SHOW', 'No Show'),  # Operator didn't show up
        ('COMPLETED', 'Completed'),  # Successfully completed duty
    )
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='PENDING')
    
    # Assignment Type
    ASSIGNMENT_TYPE_CHOICES = (
        ('PRIMARY', 'Primary'),
        ('BUFFER', 'Buffer/Standby'),
    )
    assignment_type = models.CharField(max_length=20, choices=ASSIGNMENT_TYPE_CHOICES, default='PRIMARY')
    
    # Financials
    payout_amount = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    is_paid = models.BooleanField(default=False)
    paid_at = models.DateTimeField(null=True, blank=True)
    
    # Timestamps
    assigned_at = models.DateTimeField(auto_now_add=True)
    confirmed_at = models.DateTimeField(null=True, blank=True)
    cancelled_at = models.DateTimeField(null=True, blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    
    # Notes
    cancellation_reason = models.TextField(null=True, blank=True)
    remarks = models.TextField(null=True, blank=True)
    
    class Meta:
        db_table = 'operator_assignment'
        indexes = [
            models.Index(fields=['operator', 'status']),
            models.Index(fields=['shift_center']),
            models.Index(fields=['status', 'assigned_at']),
        ]
    
    def __str__(self):
        return f"{self.operator.full_name} - {self.shift_center} ({self.role.name})"
```

---

## Relationships Diagram

```
┌─────────────────┐
│   Client        │
│  (masters)      │
└────────┬────────┘
         │
         │ 1:N
         │
┌────────▼────────┐
│   Exam          │
│  (operations)   │
└────────┬────────┘
         │
         │ 1:N
         │
┌────────▼────────┐
│   Shift         │
│  (operations)   │
└────────┬────────┘
         │
         │ 1:N
         │
┌────────▼──────────────────┐
│   ShiftCenter             │
│  (operations)             │
└───────┬───────────┬────────┘
        │           │
        │ N:1        │ N:1
        │            │
┌───────▼──────┐    ┌▼──────────────┐
│ ExamCenter   │    │ CenterMaster  │
│(operations)  │───▶│  (masters)    │
│              │    │  (nullable)    │
└──────────────┘    └───────────────┘
        │
        │ N:1
        │
┌───────▼──────────────────┐
│   ShiftCenterRole         │
│  (operations)             │
└───────┬───────────────────┘
        │
        │ N:1
        │
┌───────▼──────────────┐
│ OperatorAssignment    │
│  (assignments)        │
└───────┬───────────────┘
        │
        │ N:1 (operator)
        │
┌───────▼──────────────┐
│   AppUser            │
│  (accounts)          │
│  (KYC Verified)       │
└──────────────────────┘
```

---

## Key Design Decisions

1. **Nullable `master_center` in `ExamCenter`**: Allows immediate exam creation without waiting for master data matching
2. **Separate GPS in `ExamCenter`**: Exam-specific gate location may differ from master building location
3. **`client_center_code` in `ExamCenter`**: Stores client's own code (101, 501) for their reference
4. **`ShiftCenterRole` with buffer**: Allows standby staff planning
5. **Status fields everywhere**: Enables workflow tracking (DRAFT → LIVE → COMPLETED)
6. **Denormalized counts**: `exam_count`, `total_exams_conducted` updated via signals for performance

---

## Next Steps

1. Review these schemas
2. Confirm any changes needed
3. Start implementing Step 1: Create `masters` app with these models

