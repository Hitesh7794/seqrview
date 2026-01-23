import os
import django
import datetime

# Fix: Set Django Settings before imports
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.utils import timezone
from accounts.models import AppUser
from masters.models import Client, CenterMaster, RoleMaster
from operations.models import Exam, Shift, ExamCenter, ShiftCenter
from assignments.models import OperatorAssignment

def run():
    print("Starting seeder...")
    # 1. Get User
    mobile = '6363636363'
    try:
        user = AppUser.objects.get(mobile_primary=mobile)
        print(f"Found user: {user.username}")
    except AppUser.DoesNotExist:
        user = AppUser.objects.create_user(username='demo_user', mobile_primary=mobile, first_name='Demo', last_name='Operator', user_type='OPERATOR')
        user.set_password('demo123')
        user.save()
        print(f"Created user: {user.username}")

    # 2. Master Data
    client, _ = Client.objects.get_or_create(client_code='NTA', defaults={'name': 'National Testing Agency', 'slug': 'nta'})
    center_master, _ = CenterMaster.objects.get_or_create(center_code='DPS01', defaults={'name': 'Delhi Public School', 'city': 'New Delhi', 'state': 'Delhi'})
    # Update coordinates for existing or new center
    center_master.latitude = 28.602427
    center_master.longitude = 77.255936
    center_master.save()
    role, _ = RoleMaster.objects.get_or_create(code='INV', defaults={'name': 'Invigilator'})

    # 3. Exam
    exam, _ = Exam.objects.get_or_create(exam_code='JEE2026', defaults={'name': 'JEE Mains 2026', 'client': client, 'status': 'LIVE'})

    # 4. Shifts & Centers
    today = timezone.now().date()
    yesterday = today - datetime.timedelta(days=1)
    tomorrow = today + datetime.timedelta(days=1)

    # Shift 1: Today (Morning) - CONFIRMED
    shift_today, _ = Shift.objects.get_or_create(
        exam=exam, shift_code='S_TODAY', 
        defaults={
            'name': 'Morning Shift', 'work_date': today, 
            'start_time': '09:00:00', 'end_time': '12:00:00', 'status': 'LIVE'
        }
    )

    # Shift 2: Tomorrow (Afternoon) - PENDING
    shift_tmrw, _ = Shift.objects.get_or_create(
        exam=exam, shift_code='S_TMRW', 
        defaults={
            'name': 'Afternoon Shift', 'work_date': tomorrow, 
            'start_time': '14:00:00', 'end_time': '17:00:00', 'status': 'READY'
        }
    )

    # Shift 3: Yesterday (History) - COMPLETED
    shift_yest, _ = Shift.objects.get_or_create(
        exam=exam, shift_code='S_YEST', 
        defaults={
            'name': 'Mock Test', 'work_date': yesterday, 
            'start_time': '09:00:00', 'end_time': '12:00:00', 'status': 'COMPLETED'
        }
    )

    # Exam Center
    exam_center, _ = ExamCenter.objects.get_or_create(
        exam=exam, client_center_code='DPS01_JEE',
        defaults={'client_center_name': 'DPS Mathura Road', 'master_center': center_master}
    )

    # Shift Centers
    sc_today, _ = ShiftCenter.objects.get_or_create(exam=exam, shift=shift_today, exam_center=exam_center, defaults={'status': 'CONFIRMED'})
    sc_tmrw, _ = ShiftCenter.objects.get_or_create(exam=exam, shift=shift_tmrw, exam_center=exam_center, defaults={'status': 'PLANNED'})
    sc_yest, _ = ShiftCenter.objects.get_or_create(exam=exam, shift=shift_yest, exam_center=exam_center, defaults={'status': 'COMPLETED'})

    # 5. Assignments

    # A. Today: CONFIRMED
    OperatorAssignment.objects.update_or_create(
        operator=user, shift_center=sc_today,
        defaults={'role': role, 'status': 'CONFIRMED', 'assignment_type': 'PRIMARY'}
    )

    # B. Tomorrow: PENDING
    OperatorAssignment.objects.update_or_create(
        operator=user, shift_center=sc_tmrw,
        defaults={'role': role, 'status': 'PENDING', 'assignment_type': 'PRIMARY'}
    )

    # C. Yesterday: COMPLETED
    OperatorAssignment.objects.update_or_create(
        operator=user, shift_center=sc_yest,
        defaults={'role': role, 'status': 'COMPLETED', 'assignment_type': 'PRIMARY'}
    )

    print("Dummy duties created/updated successfully!")

if __name__ == '__main__':
    run()
