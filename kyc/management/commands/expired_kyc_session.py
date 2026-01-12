from django.core.management.base import BaseCommand
from django.utils import timezone
from kyc.models import KycSession


class Command(BaseCommand):
    help = "Delete expired KYC sessions (removes temporary sensitive data)"

    def handle(self, *args, **options):
        now = timezone.now()
        qs = KycSession.objects.filter(expires_at__lt=now)
        count = qs.count()
        qs.delete()
        self.stdout.write(self.style.SUCCESS(f"Deleted {count} expired sessions"))
