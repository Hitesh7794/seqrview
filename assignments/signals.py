from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import OperatorAssignment, AssignmentTask
from operations.models import ShiftCenterTask
import threading
from accounts.utils import send_assignment_notification_whatsapp
from notifications.models import Notification

@receiver(post_save, sender=OperatorAssignment)
def notify_operator(sender, instance, created, **kwargs):
    """
    Notify the operator via WhatsApp and In-App notification when assigned to a duty.
    """
    if created:
        # 1. WhatsApp (Background Thread)
        if instance.operator.mobile_primary:
            thread = threading.Thread(
                target=send_assignment_notification_whatsapp,
                kwargs={
                    'mobile': instance.operator.mobile_primary,
                    'role': instance.role.name
                }
            )
            thread.start()
        
        # 2. In-App Notification
        Notification.objects.create(
            user=instance.operator,
            title="New Duty Assigned",
            message=f"You have been assigned to {instance.shift_center.exam.name} as {instance.role.name}.",
            notification_type='ASSIGNMENT'
        )

@receiver(post_save, sender=OperatorAssignment)
def create_assignment_tasks(sender, instance, created, **kwargs):
    """
    Auto-create AssignmentTasks when an assignment is confirmed or checked-in.
    """
    # Trigger if status is relevant (PENDING, CONFIRMED, CHECK_IN, ACTIVE)
    # PENDING is included so operators see tasks immediately upon assignment
    if instance.status in ['PENDING', 'CONFIRMED', 'CHECK_IN', 'ACTIVE']:
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
            status__in=['PENDING', 'CONFIRMED', 'CHECK_IN']
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
