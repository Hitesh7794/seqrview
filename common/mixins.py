import csv
import io
from django.http import StreamingHttpResponse
from rest_framework.decorators import action
from rest_framework.response import Response

class ExportMixin:
    """
    Mixin to add CSV export functionality to a ViewSet.
    """
    
    @action(detail=False, methods=['get'])
    def export(self, request, *args, **kwargs):
        # Apply filters
        queryset = self.filter_queryset(self.get_queryset())
        
        # Use serializer to define columns/data if available, else models values
        serializer_class = self.get_serializer_class()
        
        # Generator for streaming
        def csv_generator():
            # Create a memory buffer
            buffer = io.StringIO()
            writer = csv.writer(buffer)
            
            # Write Header
            # We try to infer fields from serializer
            serializer = serializer_class()
            field_names = list(serializer.fields.keys())
            
            # Only include fields that are readable
            readable_fields = [
                f for f in field_names 
                if not serializer.fields[f].write_only
            ]
            
            writer.writerow([f.replace('_', ' ').title() for f in readable_fields])
            yield buffer.getvalue()
            buffer.seek(0)
            buffer.truncate(0)
            
            # Write Data
            # For performance, we might want to iterate queryset directly
            # But utilizing serializer ensures formatted data (e.g. choice labels, nested fields)
            # Trade-off: Serializer is slower but correct presentation.
            # Optimization: Use iterator() on queryset
            
            for instance in queryset.iterator():
                data = serializer.to_representation(instance)
                row = []
                for field in readable_fields:
                    val = data.get(field, "")
                    if val is None:
                        val = ""
                    row.append(str(val))
                
                writer.writerow(row)
                yield buffer.getvalue()
                buffer.seek(0)
                buffer.truncate(0)

        filename = f"{self.basename}_export.csv"
        response = StreamingHttpResponse(
            csv_generator(), 
            content_type="text/csv"
        )
        response['Content-Disposition'] = f'attachment; filename="{filename}"'
        return response
