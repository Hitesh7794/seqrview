import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from assignments.models import OperatorAssignment, AssignmentTask
from operations.models import ShiftCenterTask
from django.contrib.auth import get_user_model

User = get_user_model()

def verify():
    # Find the operator
    try:
        # Assuming the user is the one from the seed script or similar
        user = User.objects.get(username__startswith='op_') 
        print(f"Checking for user: {user.username}")
    except User.MultipleObjectsReturned:
        user = User.objects.filter(username__startswith='op_').first()
        print(f"Multiple operators found, checking for first: {user.username}")
    except User.DoesNotExist:
        print("No operator user found.")
        return

    # Find assignments
    assignments = OperatorAssignment.objects.filter(operator=user)
    print(f"Found {assignments.count()} assignments.")

    for asm in assignments:
        print(f"\nAssignment: {asm.uid} | Role: {asm.role.name} | Status: {asm.status}")
        print(f"Shift Center: {asm.shift_center.exam_center.client_center_name}")
        
        # Check for Templates
        templates = ShiftCenterTask.objects.filter(
            shift_center=asm.shift_center,
            role=asm.role
        )
        print(f"Matching Template Tasks (ShiftCenterTask): {templates.count()}")
        for t in templates:
            print(f" - Template: {t.task_name} (Role: {t.role.name})")

        # Check for Created Tasks
        tasks = AssignmentTask.objects.filter(assignment=asm)
        print(f"Created Operator Tasks (AssignmentTask): {tasks.count()}")
        for t in tasks:
            print(f" - Task: {t.shift_center_task.task_name} status={t.status}")

if __name__ == '__main__':
    verify()
