import os
import django
import datetime

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from django.utils import timezone
from accounts.models import AppUser
from operators.models import OperatorProfile
from masters.models import Client, CenterMaster, RoleMaster
from operations.models import Exam, Shift, ExamCenter, ShiftCenter, ShiftCenterTask
from assignments.models import OperatorAssignment, AssignmentTask

def run():
    print("Starting specific operator seeder...")
    
    # 1. Get or Create User
    mobile = '7737886504'
    user, created = AppUser.objects.get_or_create(
        mobile_primary=mobile,
        defaults={
            'username': f'op_{mobile}',
            'first_name': 'Test',
            'last_name': 'Operator',
            'user_type': 'OPERATOR',
            'email': 'test.operator@example.com'
        }
    )
    if created:
        user.set_password('pass1234')
        user.save()
        print(f"Created User: {user.username}")
    else:
        print(f"Found User: {user.username}")

    # 2. Ensure Operator Profile
    profile, p_created = OperatorProfile.objects.get_or_create(
        user=user,
        defaults={
            'profile_status': 'VERIFIED',
            'kyc_status': 'VERIFIED',
            'current_address': '123 Test St',
            'current_state': 'Delhi'
        }
    )
    if p_created:
        print("Created Operator Profile")
    else:
        if profile.profile_status != 'VERIFIED':
            profile.profile_status = 'VERIFIED'
            profile.kyc_status = 'VERIFIED'
            profile.save()
            print("Updated Operator Profile to VERIFIED")

    # 3. Setup Duties Context
    client, _ = Client.objects.get_or_create(client_code='NTA_TEST', defaults={'name': 'National Testing Agency (Test)', 'slug': 'nta-test'})
    role, _ = RoleMaster.objects.get_or_create(code='INV', defaults={'name': 'Invigilator'})
    
    # EXAM: Disable Geofencing
    exam, _ = Exam.objects.get_or_create(
        exam_code='TEST_EXAM_2026', 
        defaults={'name': 'Test Exam 2026', 'client': client, 'status': 'LIVE'}
    )
    # Ensure geofencing is DISABLED
    if exam.is_geofencing_enabled:
        exam.is_geofencing_enabled = False
        exam.save()
        print("Disabled Geofencing for Exam")
    
    today = timezone.now().date()
    # Shift Today
    shift, _ = Shift.objects.get_or_create(
        exam=exam, shift_code='SHIFT_TEST_TODAY',
        defaults={
            'name': 'Test Shift Today', 'work_date': today,
            'start_time': '09:00:00', 'end_time': '12:00:00', 'status': 'LIVE'
        }
    )

    # Center
    center_master, _ = CenterMaster.objects.get_or_create(center_code='TEST_CTR_01', defaults={'name': 'Test Center 01', 'city': 'Delhi', 'state': 'Delhi', 'latitude': 28.6139, 'longitude': 77.2090})
    exam_center, _ = ExamCenter.objects.get_or_create(
        exam=exam, client_center_code='TC01',
        defaults={'client_center_name': 'Test Center Delhi', 'master_center': center_master, 'active_capacity': 100}
    )

    shift_center, _ = ShiftCenter.objects.get_or_create(
        exam=exam, shift=shift, exam_center=exam_center,
        defaults={'status': 'CONFIRMED'}
    )

    # 4. Create Assignment
    assignment, a_created = OperatorAssignment.objects.get_or_create(
        operator=user, shift_center=shift_center,
        defaults={
            'role': role,
            'status': 'CONFIRMED', # Auto confirm for testing
            'assignment_type': 'PRIMARY',
            'assigned_at': timezone.now()
        }
    )
    print(f"Assignment {'Created' if a_created else 'Found'}: {assignment.uid}")

    # 5. Create Tasks
    task_names = [
        "Report to Center In-charge",
        "Collect Exam Material",
        "Verify Candidate IDs",
        "Monitor Exam Hall",
        "Collect Answer Sheets",
        "Submit Material"
    ]

    for t_name in task_names:
        # First, ensure the task exists in ShiftCenterTask (Configuration)
        sc_task, _ = ShiftCenterTask.objects.get_or_create(
            shift_center=shift_center,
            role=role,
            task_name=t_name,
            defaults={'is_mandatory': True}
        )

        # Then assign it to the operator
        AssignmentTask.objects.get_or_create(
            assignment=assignment,
            shift_center_task=sc_task,
            defaults={'status': 'PENDING'}
        )
    
    print("Seeded Tasks for assignment successfully.")
    print("Done.")

if __name__ == '__main__':
    run()
