from django.db.models.signals import post_save
from django.dispatch import receiver
from accounts.models import AppUser
from .models import OperatorProfile


@receiver(post_save, sender=AppUser)
def create_operator_profile(sender, instance: AppUser, created: bool, **kwargs):
    if created and instance.user_type == "OPERATOR":
        OperatorProfile.objects.create(user=instance)
