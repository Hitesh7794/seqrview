from django.db import models
from django.conf import settings
from common.models import TimeStampedUUIDModel

class OperatorAssignment(TimeStampedUUIDModel):
    
    shift_center = models.ForeignKey('operations.ShiftCenter', on_delete=models.CASCADE, related_name='assignments')
    operator = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='assignments',
        limit_choices_to={'user_type': 'OPERATOR'}
    )
    role = models.ForeignKey('masters.RoleMaster', on_delete=models.PROTECT, related_name='assignments')
    
 
    STATUS_CHOICES = (
        ('PENDING', 'Pending'),        
        ('CONFIRMED', 'Confirmed'),    
        ('CHECK_IN', 'Checked In'),
        ('CANCELLED', 'Cancelled'),    
        ('NO_SHOW', 'No Show'),        
        ('COMPLETED', 'Completed'),    
    )
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='PENDING')
    

    ASSIGNMENT_TYPE_CHOICES = (
        ('PRIMARY', 'Primary'),
        ('BUFFER', 'Buffer/Standby'),
    )
    assignment_type = models.CharField(max_length=20, choices=ASSIGNMENT_TYPE_CHOICES, default='PRIMARY')
    

    payout_amount = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    is_paid = models.BooleanField(default=False)
    paid_at = models.DateTimeField(null=True, blank=True)
    

    assigned_at = models.DateTimeField(auto_now_add=True)
    confirmed_at = models.DateTimeField(null=True, blank=True)
    cancelled_at = models.DateTimeField(null=True, blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    

    cancellation_reason = models.TextField(null=True, blank=True)
    remarks = models.TextField(null=True, blank=True)
    
    class Meta:
        db_table = 'operator_assignment'
        indexes = [
            models.Index(fields=['operator', 'status']),
            models.Index(fields=['shift_center']),
            models.Index(fields=['status', 'assigned_at']),
        ]
        ordering = ['-assigned_at']
    
    def __str__(self):
        return f"{self.operator.username} - {self.shift_center} ({self.role.name})"