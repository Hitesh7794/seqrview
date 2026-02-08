import os
import django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')
django.setup()

from operations.models import ShiftCenterTask, ShiftCenter
from assignments.models import OperatorAssignment

def check_data():
    assignments = OperatorAssignment.objects.all()
    print(f"Total Assignments: {assignments.count()}")
    
    for a in assignments:
        print(f"\nChecking Assignment: {a.uid} | Status: {a.status} | Role: {a.role.name}")
        tasks = ShiftCenterTask.objects.filter(shift_center=a.shift_center, role=a.role)
        print(f"Found {tasks.count()} ShiftCenterTask templates matching this assignment.")
        for t in tasks:
            print(f"- {t.task_name}")

        actual_tasks = a.tasks.all()
        print(f"Actual Assigned Tasks: {actual_tasks.count()}")

if __name__ == "__main__":
    check_data()
