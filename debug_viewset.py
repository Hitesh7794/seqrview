
import os
import sys
import django
from django.test import RequestFactory
from rest_framework.request import Request

sys.path.append(os.getcwd())
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from masters.views import ClientViewSet
from masters.models import Client
from django.contrib.auth import get_user_model

User = get_user_model()
u = User.objects.get(username='admin_refactor')
print(f"Debug User: {u.username}, Type: {getattr(u, 'user_type', 'N/A')}")

# Setup ViewSet
factory = RequestFactory()
wsgi_request = factory.get('/')
wsgi_request.user = u

drf_request = Request(wsgi_request)
drf_request.user = u # Explicitly set user on DRF request to bypass authenticators

view = ClientViewSet()
view.request = drf_request
view.format_kwarg = None
view.action = 'retrieve' # Simulate retrieve action

print("--- Testing get_queryset ---")
try:
    qs = view.get_queryset()
    print(f"QuerySet Count for {u.username}: {qs.count()}")
    exists = qs.filter(uid='cb9afc34-d718-43ea-911c-d277ef1d85cf').exists()
    print(f"Contains target client? {exists}")
except Exception as e:
    print(f"Error in get_queryset: {e}")
    import traceback
    traceback.print_exc()

print("\n--- Testing object retrieval ---")
view.lookup_field = 'uid'
view.kwargs = {'uid': 'cb9afc34-d718-43ea-911c-d277ef1d85cf'}
try:
    obj = view.get_object()
    print(f"Successfully retrieved object: {obj}")
except Exception as e:
    print(f"Failed to retrieve object: {e}")
