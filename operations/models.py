from django.db import models
from django.conf import settings
from common.models import TimeStampedUUIDModel

class Exam(TimeStampedUUIDModel):
   
    exam_code = models.CharField(max_length=50, unique=True, db_index=True)
    name = models.CharField(max_length=255)
    
    
    client = models.ForeignKey('masters.Client', on_delete=models.PROTECT, related_name='exams')
    
    
    exam_type = models.CharField(max_length=50, null=True, blank=True)
    
    exam_start_date = models.DateField(null=True, blank=True)
    exam_end_date = models.DateField(null=True, blank=True)
    
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
    
   
    description = models.TextField(null=True, blank=True)
    attachments_url = models.TextField(null=True, blank=True)
    
   
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


class Shift(TimeStampedUUIDModel):
    
    exam = models.ForeignKey('Exam', on_delete=models.CASCADE, related_name='shifts')
    
    
    shift_code = models.CharField(max_length=100)
    name = models.CharField(max_length=150, null=True, blank=True)
    session_number = models.IntegerField(null=True, blank=True)
    
    work_date = models.DateField()
    start_time = models.TimeField()
    end_time = models.TimeField()
    reporting_time = models.TimeField(null=True, blank=True)
    gate_close_time = models.TimeField(null=True, blank=True)
    exam_duration_minutes = models.IntegerField(null=True, blank=True)


    SHIFT_TYPE_CHOICES = (
        ('MOCK', 'Mock'),
        ('MAIN', 'Main'),
    )
    shift_type = models.CharField(max_length=20, choices=SHIFT_TYPE_CHOICES, default='MAIN')
    

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


class ExamCenter(TimeStampedUUIDModel):
    # Links
    exam = models.ForeignKey('Exam', on_delete=models.CASCADE, related_name='exam_centers')
    master_center = models.ForeignKey(
        'masters.CenterMaster',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='exam_centers'
    )
    
    
    client_center_code = models.CharField(max_length=50, db_index=True)
    client_center_name = models.CharField(max_length=255)
    
    
    latitude = models.DecimalField(max_digits=10, decimal_places=6, null=True, blank=True)
    longitude = models.DecimalField(max_digits=10, decimal_places=6, null=True, blank=True)
    geofence_radius_meters = models.IntegerField(default=200)
    
    
    active_capacity = models.IntegerField(null=True, blank=True)
    expected_candidates = models.IntegerField(default=0)
    
    
    incharge_name = models.CharField(max_length=150, null=True, blank=True)
    incharge_phone = models.CharField(max_length=20, null=True, blank=True)
    
    
    lab_room_info = models.CharField(max_length=255, null=True, blank=True)
    client_specific_instructions = models.TextField(null=True, blank=True)
    
    
    STATUS_CHOICES = (
        ('ACTIVE', 'Active'),
        ('INACTIVE', 'Inactive'),
        ('BLACKLISTED', 'Blacklisted'),
    )
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='ACTIVE')
    remarks = models.TextField(null=True, blank=True)
    
    class Meta:
        db_table = 'exam_center'
        unique_together = [['exam', 'client_center_code']]
        indexes = [
            models.Index(fields=['exam']),
            models.Index(fields=['master_center']),
            models.Index(fields=['client_center_code']),
            models.Index(fields=['status']),
        ]
    
    def __str__(self):
        return f"{self.exam.name} - {self.client_center_name} ({self.client_center_code})"

    def save(self, *args, **kwargs):
        # --- ROBUST AUTOMATION START ---
        
        # 1. AUTO-LINKING Logic (On Creation or if missing)
        if not self.master_center:
            from masters.models import CenterMaster  # Local import to avoid circular dep
            
            # Clean the code to handle edge cases (whitespace, case sensitivity)
            clean_code = self.client_center_code.strip().upper()
            
            try:
                # A. Try Exact Match
                master = CenterMaster.objects.get(center_code=clean_code)
                self.master_center = master
            except CenterMaster.DoesNotExist:
                # B. Try Geo-Matching (Proximity Search)
                # If code is different but location is same (within 50m), link to existing.
                candidates = []
                if self.latitude and self.longitude:
                    # Bounding box filter (approx +/- 0.001 deg is ~111m)
                    lat_min = self.latitude - 0.001
                    lat_max = self.latitude + 0.001
                    lon_min = self.longitude - 0.001
                    lon_max = self.longitude + 0.001
                    
                    possible_matches = CenterMaster.objects.filter(
                        latitude__gte=lat_min, latitude__lte=lat_max,
                        longitude__gte=lon_min, longitude__lte=lon_max
                    )
                    
                    # Refine with Haversine
                    import math
                    def calc_dist(lat1, lon1, lat2, lon2):
                        R = 6371000
                        phi1, phi2 = math.radians(lat1), math.radians(lat2)
                        dphi = math.radians(lat2 - lat1)
                        dlambda = math.radians(lon2 - lon1)
                        a = math.sin(dphi/2)**2 + math.cos(phi1)*math.cos(phi2)*math.sin(dlambda/2)**2
                        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
                        return R * c

                    for pm in possible_matches:
                        dist = calc_dist(float(self.latitude), float(self.longitude), float(pm.latitude), float(pm.longitude))
                        if dist <= 50: # Match if within 50 meters
                            candidates.append(pm)
                            break # Take the first close match
                
                if candidates:
                    self.master_center = candidates[0]
                else:
                    # C. EDGE CASE: New Center (Auto-Create)
                    # If it doesn't exist, we create it to satisfy "No Manual Interaction"
                    # We flag it as 'UNDER_REVIEW' so it can be audited if needed.
                    master = CenterMaster.objects.create(
                        center_code=clean_code,
                        name=self.client_center_name,
                        # Populate initial data from ExamCenter
                        incharge_name=self.incharge_name,
                        incharge_phone=self.incharge_phone,
                        latitude=self.latitude,
                        longitude=self.longitude,
                        max_candidates_overall=self.active_capacity or 0,
                        status='UNDER_REVIEW' # Mark for review vs 'ACTIVE'
                    )
                    self.master_center = master

        # 2. AUTO-SYNC Logic (Existing)
        # Now that we guaranteed a master_center exists (except partial failure), sync updates
        if self.master_center:
            mc = self.master_center
            updated = False
            
            # Location Sync
            if self.latitude and self.longitude:
                if mc.latitude != self.latitude or mc.longitude != self.longitude:
                    mc.latitude = self.latitude
                    mc.longitude = self.longitude
                    updated = True

            # Contact Info Sync
            if self.incharge_name and mc.incharge_name != self.incharge_name:
                mc.incharge_name = self.incharge_name
                updated = True
            
            if self.incharge_phone and mc.incharge_phone != self.incharge_phone:
                mc.incharge_phone = self.incharge_phone
                updated = True
                
            # Capacity Sync
            if self.active_capacity and mc.max_candidates_overall != self.active_capacity:
                mc.max_candidates_overall = self.active_capacity
                updated = True

            if updated:
                mc.save()
        
        super().save(*args, **kwargs)


class ShiftCenter(TimeStampedUUIDModel):

    exam = models.ForeignKey('Exam', on_delete=models.CASCADE, related_name='shift_centers')
    shift = models.ForeignKey('Shift', on_delete=models.CASCADE, related_name='shift_centers')
    exam_center = models.ForeignKey('ExamCenter', on_delete=models.CASCADE, related_name='shift_centers')
    
    notes = models.TextField(null=True, blank=True)
    
    STATUS_CHOICES = (
        ('PLANNED', 'Planned'),
        ('CONFIRMED', 'Confirmed'),
        ('CANCELLED', 'Cancelled'),
    )
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='PLANNED')
    
    class Meta:
        db_table = 'shift_center'
        unique_together = [['exam', 'shift', 'exam_center']]
        indexes = [
            models.Index(fields=['shift', 'exam_center']),
            models.Index(fields=['status']),
        ]
        ordering = ['-created_at']
    
    def __str__(self):
        return f"{self.shift.shift_code} - {self.exam_center.client_center_name}"


class ShiftCenterRole(TimeStampedUUIDModel):
    shift_center = models.ForeignKey('ShiftCenter', on_delete=models.CASCADE, related_name='role_requirements')
    role = models.ForeignKey('masters.RoleMaster', on_delete=models.PROTECT, related_name='shift_center_assignments')
    
    headcount = models.IntegerField()
    buffer_headcount = models.IntegerField(default=0)
    
    male_count = models.IntegerField(null=True, blank=True)
    female_count = models.IntegerField(null=True, blank=True)
    
    remarks = models.TextField(null=True, blank=True)
    
    class Meta:
        db_table = 'shift_center_role'
        unique_together = [['shift_center', 'role']]
        indexes = [
            models.Index(fields=['shift_center', 'role']),
        ]
    
    def __str__(self):
        return f"{self.shift_center} - {self.role.name} (Need: {self.headcount})"