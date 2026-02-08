<template>
  <BaseModal :isOpen="isOpen" :title="examData ? 'Edit Exam' : 'Create New Exam'" @close="$emit('close')">
    <form id="exam-form" @submit.prevent="saveExam" class="space-y-4">
      <!-- Exam Name -->
      <div>
        <label class="block text-sm font-medium text-gray-700">Exam Name</label>
        <input 
          v-model="form.name" 
          type="text" 
          required 
          placeholder="e.g. JEE Mains 2026"
          class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm border p-2"
        >
      </div>

      <!-- Exam Code -->
      <div>
        <label class="block text-sm font-medium text-gray-700">Exam Code</label>
        <input 
          v-model="form.exam_code" 
          type="text" 
          required 
          placeholder="e.g. JEE2026"
          class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm border p-2"
        >
      </div>

      <!-- Client Dropdown -->
      <div>
        <label class="block text-sm font-medium text-gray-700">Client</label>
        <select 
          v-model="form.client" 
          required 
          class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm border p-2"
        >
          <option value="" disabled>Select a client</option>
          <option v-for="client in clients" :key="client.uid" :value="client.uid">
            {{ client.name }} ({{ client.client_code }})
          </option>
        </select>
      </div>

      <!-- Date Range -->
      <div class="grid grid-cols-2 gap-4">
        <div>
          <label class="block text-sm font-medium text-gray-700">Start Date</label>
          <input 
            v-model="form.exam_start_date" 
            type="date" 
            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm border p-2"
          >
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700">End Date</label>
          <input 
            v-model="form.exam_end_date" 
            type="date" 
            class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm border p-2"
          >
        </div>
      </div>

      <!-- Description -->
      <div>
        <label class="block text-sm font-medium text-gray-700">Description</label>
        <textarea 
          v-model="form.description" 
          rows="3" 
          class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm border p-2"
        ></textarea>
      </div>
      
      <!-- Geofencing Toggle -->
      <div class="flex items-center py-2">
        <input 
          v-model="form.is_geofencing_enabled" 
          id="geofencing-toggle" 
          type="checkbox" 
          class="h-4 w-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-500"
        >
        <label for="geofencing-toggle" class="ml-2 block text-sm text-gray-900">
          Enable Geofencing restriction for this exam
        </label>
      </div>

      <!-- Selfie Toggle -->
      <div class="flex items-center py-2">
        <input 
          v-model="form.is_selfie_enabled" 
          id="selfie-toggle" 
          type="checkbox" 
          class="h-4 w-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-500"
        >
        <label for="selfie-toggle" class="ml-2 block text-sm text-gray-900">
          Enable Selfie requirement during Check-in/Check-out
        </label>
      </div>

    </form>
    
    <template #footer>
        <button 
          type="submit" 
          form="exam-form"
          :disabled="isSubmitting"
          class="inline-flex justify-center rounded-lg border border-transparent bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700 focus:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500 focus-visible:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed"
        >
          <span v-if="isSubmitting">{{ examData ? 'Using...' : 'Creating...' }}</span>
          <span v-else>{{ examData ? 'Update Exam' : 'Create Exam' }}</span>
        </button>
    </template>
  </BaseModal>
</template>

<script setup>
import { ref, reactive, onMounted, watch } from 'vue';
import api from '../../api/axios';
import BaseModal from '../../components/BaseModal.vue';

const props = defineProps({
    isOpen: Boolean,
    examData: {
        type: Object,
        default: null
    }
});

const emit = defineEmits(['close', 'success']);

const clients = ref([]);
const isSubmitting = ref(false);

const form = reactive({
  name: '',
  exam_code: '',
  client: '',
  exam_start_date: '',
  exam_end_date: '',
  description: '',
  is_geofencing_enabled: true,
  is_selfie_enabled: true
});

const loadClients = async () => {
    try {
        const res = await api.get('/masters/clients/');
        clients.value = res.data.results || res.data;
    } catch (e) {
        console.error("Failed to load clients", e);
    }
};

const resetForm = () => {
    form.name = '';
    form.exam_code = '';
    form.client = '';
    form.exam_start_date = '';
    form.exam_end_date = '';
    form.description = '';
    form.is_geofencing_enabled = true;
    form.is_selfie_enabled = true;
};

// Watch for changes in examData to populate form
watch(() => props.examData, (newVal) => {
    if (newVal) {
        form.name = newVal.name;
        form.exam_code = newVal.exam_code;
        form.client = newVal.client; // Ensure this maps to the UID
        form.exam_start_date = newVal.exam_start_date || '';
        form.exam_end_date = newVal.exam_end_date || '';
        form.description = newVal.description || '';
        form.is_geofencing_enabled = newVal.is_geofencing_enabled ?? true;
        form.is_selfie_enabled = newVal.is_selfie_enabled ?? true;
    } else {
        resetForm();
    }
}, { immediate: true });

const saveExam = async () => {
    isSubmitting.value = true;
    try {
        const payload = { ...form };
        // Convert empty strings to null for DateFields to avoid 400 Bad Request
        if (!payload.exam_start_date) payload.exam_start_date = null;
        if (!payload.exam_end_date) payload.exam_end_date = null;

        if (props.examData) {
            // Edit Mode
            await api.patch(`/operations/exams/${props.examData.uid}/`, payload);
        } else {
            // Create Mode
            await api.post('/operations/exams/', payload);
        }
        emit('success');
        resetForm();
    } catch (e) {
        console.error("Failed to save exam", e);
        alert(e.response?.data?.detail || "Failed to save exam.");
    } finally {
        isSubmitting.value = false;
    }
};

onMounted(() => {
    loadClients();
});
</script>
