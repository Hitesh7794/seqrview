import uuid
from django.db import models


class TimeStampedUUIDModel(models.Model):
    uid = models.UUIDField(default=uuid.uuid4, unique=True, editable=False, db_index=True)
    created_at = models.DateTimeField(auto_now_add=True)  
    updated_at = models.DateTimeField(auto_now=True)  

    class Meta:
        abstract = True
