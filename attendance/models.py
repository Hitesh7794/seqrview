from django.db import models
from common.models import TimeStampedUUIDModel

class AttendanceLog(TimeStampedUUIDModel):
    TYPES = (
        ("CHECK_IN", "Check In"),
        ("CHECK_OUT", "Check Out"),
    )

    # Link to the specific Duty (which links to Operator + Shift + Center)
    assignment = models.ForeignKey(
        "assignments.OperatorAssignment", 
        on_delete=models.CASCADE, 
        related_name="attendance_logs"
    )
    
    activity_type = models.CharField(max_length=20, choices=TYPES)
    timestamp = models.DateTimeField(auto_now_add=True)
    
    # Location Proof
    latitude = models.DecimalField(max_digits=12, decimal_places=9)   # High precision
    longitude = models.DecimalField(max_digits=12, decimal_places=9)
    distance_from_center = models.IntegerField(help_text="Distance in meters")
    
    is_verified = models.BooleanField(default=False, help_text="True if within geofence")
    selfie = models.ImageField(upload_to='attendance_selfies/', null=True, blank=True)
    
    def __str__(self):
        return f"{self.assignment.operator.username} - {self.activity_type}"