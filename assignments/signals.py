from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import OperatorAssignment, AssignmentTask
from operations.models import ShiftCenterTask

@receiver(post_save, sender=OperatorAssignment)
def create_assignment_tasks(sender, instance, created, **kwargs):
    """
    Auto-create AssignmentTasks when an assignment is confirmed or checked-in.
    """
    # Trigger if status is relevant (CONFIRMED, CHECK_IN)
    # We also want to do it on creation if created as confirmed (bulk import)
    if instance.status in ['CONFIRMED', 'CHECK_IN', 'ACTIVE']:
        # Find templates for this Role in this ShiftCenter
        templates = ShiftCenterTask.objects.filter(
            shift_center=instance.shift_center,
            role=instance.role
        )
        
        for template in templates:
            # Create if not exists
            AssignmentTask.objects.get_or_create(
                assignment=instance,
                shift_center_task=template,
                defaults={
                    'status': 'PENDING'
                }
            )
@receiver(post_save, sender=ShiftCenterTask)
def sync_new_task_to_assignments(sender, instance, created, **kwargs):
    """
    When a new ShiftCenterTask is created, add it to all active assignments
    that match the shift_center and role.
    """
    if created:
        active_assignments = OperatorAssignment.objects.filter(
            shift_center=instance.shift_center,
            role=instance.role,
            status__in=['CONFIRMED', 'CHECK_IN']
        )
        
        tasks_to_create = []
        for assignment in active_assignments:
            tasks_to_create.append(
                AssignmentTask(
                    assignment=assignment,
                    shift_center_task=instance,
                    status='PENDING'
                )
            )
        
        if tasks_to_create:
            AssignmentTask.objects.bulk_create(tasks_to_create)
