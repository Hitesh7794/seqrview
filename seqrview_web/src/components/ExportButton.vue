<template>
  <button 
    @click="downloadCSV" 
    :disabled="loading"
    class="flex items-center px-4 py-2 text-sm font-medium text-white bg-indigo-600 rounded-md hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500 disabled:opacity-50 transition-colors"
  >
    <svg v-if="loading" class="w-4 h-4 mr-2 animate-spin" viewBox="0 0 24 24">
       <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" fill="none"></circle>
       <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
    </svg>
    <svg v-else class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"></path>
    </svg>
    {{ loading ? 'Exporting...' : label }}
  </button>
</template>

<script setup>
import { ref } from 'vue';
import api from '../api/axios';

const props = defineProps({
  endpoint: {
    type: String,
    required: true
  },
  filters: {
    type: Object,
    default: () => ({})
  },
  label: {
    type: String,
    default: 'Export CSV'
  },
  filename: {
    type: String, // fallback filename
    default: 'export.csv'
  }
});

const loading = ref(false);

const downloadCSV = async () => {
    loading.value = true;
    try {
        const response = await api.get(props.endpoint, {
            params: props.filters,
            responseType: 'blob' // Important for file handling
        });
        
        // Create download link
        const url = window.URL.createObjectURL(new Blob([response.data]));
        const link = document.createElement('a');
        link.href = url;
        
        // Try to get filename from headers
        let downloadFilename = props.filename;
        const disposition = response.headers['content-disposition'];
        if (disposition && disposition.indexOf('attachment') !== -1) {
             const filenameRegex = /filename[^;=\n]*=((['"]).*?\2|[^;\n]*)/;
             const matches = filenameRegex.exec(disposition);
             if (matches != null && matches[1]) { 
               downloadFilename = matches[1].replace(/['"]/g, '');
             }
        }
        
        link.setAttribute('download', downloadFilename); 
        document.body.appendChild(link);
        link.click();
        
        // Cleanup
        document.body.removeChild(link);
        window.URL.revokeObjectURL(url);
        
    } catch (error) {
        console.error("Export failed", error);
        // Simple error feedback
        const msg = error.response ? `Error: ${error.response.status}` : "Export failed. Please try again.";
        alert(msg);
    } finally {
        loading.value = false;
    }
};
</script>
