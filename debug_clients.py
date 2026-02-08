
import os
import sys
import django

# Add the project root to sys.path
sys.path.append(os.getcwd())

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from masters.models import Client
from django.contrib.auth import get_user_model

User = get_user_model()
try:
    u = User.objects.get(username='admin_refactor')
    print(f"User: {u.username}, Superuser: {u.is_superuser}, Type: {u.user_type}")
except User.DoesNotExist:
    print("User admin_refactor not found!")

print("\n--- Clients ---")
for c in Client.objects.all():
    print(f"Name: {c.name}, UID: {c.uid}, PK: {c.pk}")
