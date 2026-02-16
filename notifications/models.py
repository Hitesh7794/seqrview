from django.db import models
from common.models import TimeStampedUUIDModel
from django.conf import settings

class Notification(TimeStampedUUIDModel):
    NOTIFICATION_TYPES = (
        ('ASSIGNMENT', 'Duty Assignment'),
        ('SYSTEM', 'System Alert'),
        ('ALERT', 'Important Announcement'),
    )

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='notifications'
    )
    title = models.CharField(max_length=200)
    message = models.TextField()
    notification_type = models.CharField(
        max_length=20,
        choices=NOTIFICATION_TYPES,
        default='SYSTEM'
    )
    is_read = models.BooleanField(default=False)
    
    # Optional: Link to a specific object if needed (e.g., specific assignment)
    # Using GenericForeignKey would be more flexible, but for now let's keep it simple.
    
    class Meta:
        db_table = 'notification'
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.user.username} - {self.title} ({'Read' if self.is_read else 'Unread'})"
