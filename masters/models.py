from dataclasses import fields
from django.utils.http import MAX_URL_LENGTH
from django.db import models

from common.models import TimeStampedUUIDModel

class Client(TimeStampedUUIDModel):
    client_code = models.CharField(max_length=50, unique=True, db_index=True)
    name = models.CharField(max_length=255)
    slug = models.SlugField(max_length=255, unique=True, blank=True)
    logo = models.ImageField(upload_to='client_logos/', null=True, blank=True)



    primary_contact_name = models.CharField(max_length=150, null=True, blank=True)
    primary_contact_email = models.EmailField(null=True, blank=True)
    primary_contact_phone = models.CharField(max_length=15, null=True, blank=True)

    secondary_contact_name = models.CharField(max_length=150, null=True, blank=True)
    secondary_contact_email = models.EmailField(null=True, blank=True)
    secondary_contact_phone = models.CharField(max_length=15, null=True, blank=True)


    address_line1 = models.CharField(max_length=255, null=True, blank=True)
    address_line2 = models.CharField(max_length=255, null=True, blank=True)
    city = models.CharField(max_length=100, null=True, blank=True)
    state = models.CharField(max_length=100, null=True, blank=True)
    country = models.CharField(max_length=100, null=True, blank=True)
    pincode = models.CharField(max_length=10, null=True, blank=True)



    STATUS_CHOICES=(
        ('ACTIVE','Active'),
        ('INACTIVE','Inactive'),
        ('PROSPECT','Prospect')
    )
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='ACTIVE')
    exam_count = models.IntegerField(default=0)
    exam_active_count = models.IntegerField(default=0)

    contract_start_date = models.DateField(null=True, blank=True)
    contract_end_date = models.DateField(null=True, blank=True)


    class Meta:
        db_table = "client"
        indexes = [
            models.Index(fields=['client_code']),
            models.Index(fields=['status']),

        ]
    
    def __str__(self):
        return f"{self.name} {self.client_code}"


class CenterMaster(TimeStampedUUIDModel):
    center_code = models.CharField(max_length=50, unique=True, db_index=True)
    name = models.CharField(max_length=255)

    CENTER_VARIETY_CHOICES = (
        ('EXAM',"Exam Center"),
        ('MARKFED',"Markfed "),
        ('DEMO',"Demo"),
    )

    center_variety = models.CharField(max_length=50, choices=CENTER_VARIETY_CHOICES, null=True, blank=True)

    CENTER_TYPE_CHOICES = (
        ('SCHOOL','School'),
        ('COLLEGE','College'),
        ('UNIVERSITY','University'),
        ('WORKSHOP','Workshop'),
        ('PRIVATE_LAB','Private Lab'),
        ('COACHING','Coaching'),
        ('OTHER','Other')
    )

    center_type = models.CharField(max_length=50, choices=CENTER_TYPE_CHOICES, null=True, blank=True)


    OWNERSHIP_CHOICES = (
        ('GOVT', 'Government'),
        ('PRIVATE', 'Private'),
        ('AIDED', 'Aided'),
        ('OTHER', 'Other'),
    )
    
    ownership_type = models.CharField(max_length=50, choices=OWNERSHIP_CHOICES, null=True, blank=True)


    address = models.CharField(max_length=255, null=True, blank=True)
    area = models.CharField(max_length=150, null=True, blank=True)
    city = models.CharField(max_length=100, null=True, blank=True)
    district = models.CharField(max_length=100, null=True, blank=True)
    state = models.CharField(max_length=100, null=True, blank=True)
    pincode = models.CharField(max_length=20, null=True, blank=True)
    country = models.CharField(max_length=100, default="India")


    latitude = models.DecimalField(max_digits=10, decimal_places=6, null=True, blank=True)
    longitude = models.DecimalField(max_digits=10, decimal_places=6, null=True, blank=True)
    geofence_radius_meters = models.IntegerField(default=200)
    

    total_rooms = models.IntegerField(null=True, blank=True)
    total_labs = models.IntegerField(null=True, blank=True)
    max_candidates_overall = models.IntegerField(null=True, blank=True)
    max_computers = models.IntegerField(null=True, blank=True)
    buffer_candidates_count = models.IntegerField(default=0)
    

    internet_speed_mbps = models.DecimalField(max_digits=5, decimal_places=2, null=True, blank=True)
    has_generator_backup = models.BooleanField(default=False)
    total_computers_functional = models.IntegerField(null=True, blank=True)


    incharge_name = models.CharField(max_length=150, null=True, blank=True)
    incharge_phone = models.CharField(max_length=20, null=True, blank=True)
    incharge_email = models.EmailField(null=True, blank=True)
    alt_contact_name = models.CharField(max_length=150, null=True, blank=True)
    alt_contact_phone = models.CharField(max_length=20, null=True, blank=True)


    STATUS_CHOICES = (
        ('ACTIVE', 'Active'),
        ('INACTIVE', 'Inactive'),
        ('BLACKLISTED', 'Blacklisted'),
        ('UNDER_REVIEW', 'Under Review'),
    )
    status = models.CharField(max_length=30, choices=STATUS_CHOICES, default='ACTIVE')
    rating = models.FloatField(null=True, blank=True)
    remarks = models.TextField(null=True, blank=True)
    

    total_exams_conducted = models.IntegerField(default=0)
    last_exam_date = models.DateField(null=True, blank=True)
    
    class Meta:
        db_table = 'center_master'
        indexes = [
            models.Index(fields=['center_code']),
            models.Index(fields=['city', 'state']),
            models.Index(fields=['status']),
            models.Index(fields=['latitude', 'longitude']),
        ]
    
    def __str__(self):
        return f"{self.name} ({self.center_code})"