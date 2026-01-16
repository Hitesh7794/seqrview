from django.db import models
from common.models import TimeStampedUUIDModel

class IncidentCategory(TimeStampedUUIDModel):
    name = models.CharField(max_length=100, unique=True)
    description = models.TextField(null=True, blank=True)
    is_active = models.BooleanField(default=True)
    
    class Meta:
        verbose_name_plural = "Incident Categories"
        ordering = ['name']

    def __str__(self):
        return self.name


class Incident(TimeStampedUUIDModel):
    # Context
    assignment = models.ForeignKey(
        'assignments.OperatorAssignment', 
        on_delete=models.CASCADE, 
        related_name='incidents'
    )
    category = models.ForeignKey(
        IncidentCategory, 
        on_delete=models.PROTECT, # Don't delete incidents if category is gone
        related_name='incidents'
    )
    
    # Details
    PRIORITY_CHOICES = (
        ('LOW', 'Low'),
        ('MEDIUM', 'Medium'),
        ('HIGH', 'High'),
        ('CRITICAL', 'Critical'),
    )
    priority = models.CharField(max_length=20, choices=PRIORITY_CHOICES, default='MEDIUM')
    
    STATUS_CHOICES = (
        ('OPEN', 'Open'),
        ('IN_PROGRESS', 'In Progress'),
        ('RESOLVED', 'Resolved'),
        ('CLOSED', 'Closed'),
        ('REJECTED', 'Rejected'),
    )
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='OPEN')
    
    description = models.TextField()
    
    # Resolution
    resolved_at = models.DateTimeField(null=True, blank=True)
    resolution_notes = models.TextField(null=True, blank=True)
    resolved_by = models.ForeignKey(
        'accounts.AppUser', 
        on_delete=models.SET_NULL, 
        null=True, 
        blank=True,
        related_name='resolved_incidents'
    )

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['status']),
            models.Index(fields=['priority']),
        ]

    def __str__(self):
        return f"{self.assignment.operator.username} - {self.category.name} ({self.status})"


class IncidentAttachment(TimeStampedUUIDModel):
    incident = models.ForeignKey(
        Incident, 
        on_delete=models.CASCADE, 
        related_name='attachments'
    )
    file = models.FileField(upload_to='incident_attachments/%Y/%m/%d/')
    caption = models.CharField(max_length=255, null=True, blank=True)
    
    def __str__(self):
        return f"Attachment for {self.incident.uid}"
