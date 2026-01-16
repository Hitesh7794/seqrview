from django.core.management.base import BaseCommand
from operations.models import ExamCenter
from masters.models import CenterMaster

class Command(BaseCommand):
    help = 'Links ExamCenters to CenterMasters based on matching codes'

    def handle(self, *args, **options):
        self.stdout.write("--- Step 1: Link Unlinked Centers ---")
        # 1. Get all ExamCenters without a MasterCenter
        unlinked = ExamCenter.objects.filter(master_center__isnull=True)
        count = unlinked.count()
        self.stdout.write(f"Found {count} unlinked Exam Centers.")

        linked_count = 0
        for ec in unlinked:
            # simply calling save() now triggers the robust Auto-Link + Geo-Search logic
            ec.save() 
            if ec.master_center:
                linked_count += 1
                self.stdout.write(self.style.SUCCESS(f"Linked {ec.client_center_code} -> {ec.master_center.center_code}"))
            else:
                self.stdout.write(self.style.WARNING(f"Could not link {ec.client_center_code}"))
        
        self.stdout.write(self.style.SUCCESS(f"Successfully linked {linked_count} centers."))

        # --- Step 2: Deduplicate Existing Masters ---
        self.stdout.write("\n--- Step 2: Deduplicate Master Centers (Geo-Merge) ---")
        masters = list(CenterMaster.objects.filter(latitude__isnull=False, longitude__isnull=False).order_by('created_at'))
        
        # Simple clustering
        import math
        def calc_dist(lat1, lon1, lat2, lon2):
            R = 6371000
            phi1, phi2 = math.radians(lat1), math.radians(lat2)
            dphi = math.radians(lat2 - lat1)
            dlambda = math.radians(lon2 - lon1)
            a = math.sin(dphi/2)**2 + math.cos(phi1)*math.cos(phi2)*math.sin(dlambda/2)**2
            c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
            return R * c

        processed_ids = set()
        merged_count = 0

        for m1 in masters:
            if m1.uid in processed_ids:
                continue
            
            processed_ids.add(m1.uid)
            
            # Find duplicates for m1
            duplicates = []
            for m2 in masters:
                if m2.uid in processed_ids:
                    continue
                
                dist = calc_dist(float(m1.latitude), float(m1.longitude), float(m2.latitude), float(m2.longitude))
                if dist <= 50: # 50 meters
                    duplicates.append(m2)
            
            if duplicates:
                # We have a cluster: [m1] + duplicates
                cluster = [m1] + duplicates
                
                # Pick Winner: Prefer ACTIVE, then oldest
                # Sort: Status ('ACTIVE' first?), then Created At
                # easy hack: if status='ACTIVE' give sore 0 else 1.
                cluster.sort(key=lambda x: (0 if x.status == 'ACTIVE' else 1, x.created_at))
                
                primary = cluster[0]
                to_merge = cluster[1:]
                
                self.stdout.write(f"Found Cluster at {primary.city}: Primary={primary.center_code}, Merging={len(to_merge)}")

                for dup in to_merge:
                    # 1. Move Links
                    ExamCenter.objects.filter(master_center=dup).update(master_center=primary)
                    self.stdout.write(f"  - Moved links from {dup.center_code} to {primary.center_code}")
                    
                    # 2. Mark processed
                    processed_ids.add(dup.uid)
                    
                    # 3. Delete Duplicate (or soft delete)
                    # Since user wants 'no manual work', deleting essentially "cleans" the view.
                    # But we only delete if it was auto-created or under_review to be safe?
                    # User implied aggressive fix.
                    dup_code = dup.center_code
                    dup.delete()
                    self.stdout.write(self.style.WARNING(f"  - Deleted duplicate master: {dup_code}"))
                    merged_count += 1

        self.stdout.write(self.style.SUCCESS(f"Deduplication Complete. Merged/Deleted {merged_count} duplicates."))
