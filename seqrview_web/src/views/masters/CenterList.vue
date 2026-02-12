<template>
  <div class="space-y-6">
    <!-- Header & Actions -->
    <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
      <div>
        <h1 class="text-2xl font-bold text-gray-800">Center Management</h1>
        <p class="text-sm text-gray-500">Manage exam centers, their capacity and locations.</p>
      </div>
      <div class="flex items-center gap-3">
        <div class="relative">
          <input 
            v-model="searchQuery" 
            type="text" 
            placeholder="Search centers..." 
            class="pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 w-full sm:w-64 text-sm"
          >
          <span class="absolute left-3 top-2.5 text-gray-400">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
            </svg>
          </span>
        </div>
        <ExportButton 
            endpoint="/masters/centers/export/" 
            filename="master_centers.csv"
            :filters="{}"
            class="mr-0"
        />
        <button @click="openBulkModal" class="flex items-center px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg shadow transition-colors text-sm font-medium">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
          </svg>
          Bulk Add
        </button>
        <button @click="openModal()" class="flex items-center px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg shadow transition-colors text-sm font-medium">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
          </svg>
          Add Center
        </button>
      </div>
    </div>

    <!-- Center Table -->
    <div class="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Center Name</th>
              <th class="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Client</th>
              <th class="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Location</th>
              <th class="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Capacity</th>
              <th class="px-6 py-3 text-right text-xs font-semibold text-gray-500 uppercase tracking-wider">Actions</th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <tr v-for="center in filteredCenters" :key="center.uid" class="hover:bg-gray-50 transition-colors">
              <td class="px-6 py-4 whitespace-nowrap">
                <div class="flex items-center">
                  <div class="h-10 w-10 flex-shrink-0 bg-blue-100 rounded-lg flex items-center justify-center text-blue-600 font-bold border border-blue-200">
                    {{ center.name.charAt(0).toUpperCase() }}
                  </div>
                  <div class="ml-4">
                    <div class="text-sm font-medium text-gray-900">{{ center.name }}</div>
                    <div class="text-xs text-gray-500 bg-gray-100 px-1.5 py-0.5 rounded border inline-block mt-0.5">{{ center.center_code }}</div>
                  </div>
                </div>
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <span class="px-2.5 py-1 text-[10px] font-bold uppercase tracking-wider rounded-md bg-purple-50 text-purple-700 border border-purple-100 shadow-sm">
                  {{ center.client_code || 'No Client' }}
                </span>
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <div class="text-sm text-gray-900 font-medium">{{ center.city }}</div>
                <div class="text-xs text-gray-500">{{ center.state }}</div>
                <div class="mt-1">
                   <a v-if="center.latitude && center.longitude" 
                    :href="`https://www.google.com/maps?q=${center.latitude},${center.longitude}`" 
                    target="_blank"
                    class="text-[10px] text-blue-600 hover:text-blue-800 flex items-center gap-0.5 hover:underline decoration-blue-300">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-3 w-3" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" /><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" /></svg>
                    View Map
                  </a>
                  <span v-else class="text-[9px] text-gray-400 italic">No GPS data</span>
                </div>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                <div class="flex items-center">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 mr-1 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" /></svg>
                  {{ center.max_candidates_overall || 0 }}
                </div>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                <button @click="openModal(center)" class="text-indigo-600 hover:text-indigo-900 mr-3">Edit</button>
                <button @click="deleteCenter(center.uid)" class="text-red-600 hover:text-red-900">Delete</button>
              </td>
            </tr>
             <tr v-if="filteredCenters.length === 0">
              <td colspan="6" class="px-6 py-10 text-center text-gray-500">
                No centers found matching your search.
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Modal -->
    <BaseModal :isOpen="isModalOpen" :title="isEditing ? 'Edit Center' : 'Add New Center'" @close="closeModal">
      <form @submit.prevent="saveCenter" class="space-y-4">
        <div class="grid grid-cols-2 gap-4">
            <div>
                <label class="block text-sm font-medium text-gray-700">Name</label>
                <input v-model="form.name" type="text" required class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm border p-2">
            </div>
            <div>
                <label class="block text-sm font-medium text-gray-700">Code</label>
                <input v-model="form.center_code" type="text" required class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm border p-2">
            </div>
        </div>

        <div>
            <label class="block text-sm font-medium text-gray-700">Address</label>
            <input v-model="form.address" type="text" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm border p-2">
        </div>

        <div class="grid grid-cols-2 gap-4">
            <div>
                <label class="block text-sm font-medium text-gray-700">City</label>
                <input v-model="form.city" type="text" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm border p-2">
            </div>
            <div>
                <label class="block text-sm font-medium text-gray-700">State</label>
                <input v-model="form.state" type="text" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm border p-2">
            </div>
        </div>

         <div class="grid grid-cols-2 gap-4">
            <div>
                <label class="block text-sm font-medium text-gray-700">Associate Client</label>
                <select v-model="form.client" required class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm border p-2">
                    <option :value="null">Select Client</option>
                    <option v-for="client in clients" :key="client.uid" :value="client.uid">
                        {{ client.name }} ({{ client.client_code }})
                    </option>
                </select>
            </div>
            <div>
                <label class="block text-sm font-medium text-gray-700">Overall Capacity</label>
                <input v-model.number="form.max_candidates_overall" type="number" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm border p-2">
            </div>
        </div>

        <div class="grid grid-cols-2 gap-4">
            <div>
                <label class="block text-sm font-medium text-gray-700">Latitude</label>
                <input v-model.number="form.latitude" type="number" step="any" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm border p-2">
            </div>
            <div>
                <label class="block text-sm font-medium text-gray-700">Longitude</label>
                <input v-model.number="form.longitude" type="number" step="any" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm border p-2">
            </div>
        </div>

        <div class="flex justify-end pt-4">
          <button type="submit" class="inline-flex justify-center rounded-lg border border-transparent bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 focus:outline-none focus:visible:ring-2 focus:visible:ring-blue-500 focus:visible:ring-offset-2">
            {{ isEditing ? 'Update Center' : 'Create Center' }}
          </button>
        </div>
      </form>
    </BaseModal>

    <!-- Bulk Add Modal -->
    <BaseModal :isOpen="isBulkModalOpen" title="Bulk Add Centers" @close="closeBulkModal">
        <div class="relative min-h-[300px]">
            <!-- Processing Overlay -->
            <div v-if="bulkRequesting" class="absolute inset-0 bg-white/80 backdrop-blur-sm z-10 flex flex-col items-center justify-center rounded-2xl">
                <div class="relative">
                    <div class="h-16 w-16 border-4 border-indigo-100 border-t-indigo-600 rounded-full animate-spin"></div>
                    <div class="absolute inset-0 flex items-center justify-center">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a2 2 0 002 2h12a2 2 0 002-2v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                        </svg>
                    </div>
                </div>
                <p class="mt-4 text-sm font-bold text-gray-900 tracking-tight">Processing Centers...</p>
                <p class="text-[10px] text-gray-500 mt-1 uppercase tracking-widest">Integrating with master database</p>
            </div>

            <div class="space-y-6" :class="{ 'opacity-50 pointer-events-none': bulkRequesting }">
                <div class="p-4 bg-indigo-50 rounded-2xl border border-indigo-100">
                    <p class="text-sm font-bold text-indigo-900 mb-1">Step 1: Download Template</p>
                    <p class="text-xs text-indigo-700 mb-3">Download the template, fill it in Excel, and **save as CSV**.</p>
                    <button 
                        @click="downloadTemplate"
                        class="flex items-center gap-2 px-4 py-2 bg-white text-indigo-600 rounded-xl text-xs font-bold border border-indigo-200 hover:bg-indigo-100 transition-all shadow-sm"
                    >
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a2 2 0 002 2h12a2 2 0 002-2v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                        </svg>
                        Download Template (CSV)
                    </button>
                </div>

                <div class="p-4 bg-gray-50 rounded-2xl border border-gray-100">
                    <p class="text-sm font-bold text-gray-900 mb-1">Step 2: Select Associate Client</p>
                    <p class="text-xs text-gray-500 mb-3">All centers in this file will be linked to this client.</p>
                    <select v-model="selectedBulkClient" class="block w-full text-sm text-gray-700 bg-white border border-gray-300 rounded-xl p-2.5 focus:ring-indigo-500 focus:border-indigo-500 shadow-sm">
                        <option :value="null">Select Client (Optional)</option>
                        <option v-for="client in clients" :key="client.uid" :value="client.uid">
                            {{ client.name }} ({{ client.client_code }})
                        </option>
                    </select>
                </div>

                <div class="p-4 bg-gray-50 rounded-2xl border border-gray-100">
                    <p class="text-sm font-bold text-gray-900 mb-1">Step 3: Upload Filled CSV</p>
                    <p class="text-xs text-gray-500 mb-3">Please upload the saved CSV file here.</p>
                    <input 
                        type="file" 
                        ref="fileInput"
                        accept=".csv"
                        @change="handleFileChange"
                        class="block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-full file:border-0 file:text-xs file:font-semibold file:bg-indigo-50 file:text-indigo-700 hover:file:bg-indigo-100"
                    />
                </div>
                
                <div v-if="bulkError" class="p-3 bg-red-50 text-red-600 text-[10px] rounded-lg border border-red-100 italic">
                    {{ bulkError }}
                </div>

                <div v-if="bulkResult" class="space-y-3">
                    <div class="p-3 bg-indigo-50 text-indigo-700 text-xs rounded-lg border border-indigo-100">
                        <div class="flex justify-between items-center">
                            <span class="font-medium">Total Created: <span class="font-bold text-indigo-900 text-lg ml-1">{{ bulkResult.created.length }}</span></span>
                            <span v-if="bulkResult.errors.length > 0" class="text-red-600 font-medium">Failed: <span class="font-bold text-lg ml-1">{{ bulkResult.errors.length }}</span></span>
                        </div>
                    </div>

                    <!-- Detailed Errors -->
                    <div v-if="bulkResult.errors.length > 0" class="max-h-48 overflow-y-auto space-y-2 rounded-xl border border-gray-100 p-2 bg-gray-50">
                        <div v-for="(err, idx) in bulkResult.errors" :key="idx" class="p-2 bg-white rounded-lg border border-red-50 text-[10px]">
                            <div class="flex items-start gap-2">
                                <span class="px-1.5 py-0.5 bg-red-100 text-red-700 rounded font-bold">Error</span>
                                <div class="flex-1">
                                    <p class="font-bold text-gray-900 truncate">Center: {{ err.row?.name || 'Unknown' }} ({{ err.row?.center_code || 'No Code' }})</p>
                                    <ul class="mt-1 list-disc list-inside text-red-500 italic">
                                        <li v-for="(msg, field) in err.errors" :key="field">
                                            {{ field }}: {{ msg.join(', ') }}
                                        </li>
                                    </ul>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        <template #footer>
            <button 
                @click="submitBulkCenters"
                :disabled="bulkRequesting || !selectedFile"
                class="inline-flex justify-center rounded-lg bg-indigo-600 px-6 py-2.5 text-sm font-bold text-white hover:bg-indigo-700 focus:outline-none disabled:opacity-50 disabled:cursor-not-allowed transition-all shadow-md shadow-indigo-100"
            >
                {{ bulkRequesting ? 'Processing Import...' : 'Import Centers' }}
            </button>
        </template>
    </BaseModal>
  </div>
</template>

<script setup>
import { ref, onMounted, computed, reactive } from 'vue';
import api from '../../api/axios';
import BaseModal from '../../components/BaseModal.vue';
import ExportButton from '../../components/ExportButton.vue';

const centers = ref([]);
const clients = ref([]);
const searchQuery = ref('');
const isModalOpen = ref(false);
const isEditing = ref(false);
const editingId = ref(null);

const isBulkModalOpen = ref(false);
const bulkRequesting = ref(false);
const bulkError = ref('');
const bulkResult = ref(null);
const selectedFile = ref(null);
const fileInput = ref(null);
const selectedBulkClient = ref(null);

const form = reactive({
  client: null,
  name: '',
  center_code: '',
  address: '',
  city: '',
  state: '',
  max_candidates_overall: 0,
  latitude: 0,
  longitude: 0
});

const filteredCenters = computed(() => {
  if (!searchQuery.value) return centers.value;
  const q = searchQuery.value.toLowerCase();
  return centers.value.filter(c => 
    c.name.toLowerCase().includes(q) || 
    c.center_code?.toLowerCase().includes(q) ||
    c.city?.toLowerCase().includes(q)
  );
});

const loadCenters = async () => {
  try {
    const res = await api.get('/masters/centers/');
    centers.value = res.data.results || res.data;
  } catch (e) {
    console.error("Failed to load centers", e);
  }
};

const loadClients = async () => {
  try {
    const res = await api.get('/masters/clients/');
    clients.value = res.data.results || res.data;
  } catch (e) {
    console.error("Failed to load clients", e);
  }
};

onMounted(() => {
    loadCenters();
    loadClients();
});

const openModal = (center = null) => {
  if (center) {
    isEditing.value = true;
    editingId.value = center.uid;
    Object.assign(form, center);
    // Handle the nested client UID if it comes from the API differently
    if (center.client && typeof center.client === 'object') {
        form.client = center.client.uid;
    }
    // Ensure nulls are handled for controlled inputs
    form.max_candidates_overall = form.max_candidates_overall || 0;
    form.latitude = form.latitude || 0;
    form.longitude = form.longitude || 0;
  } else {
    isEditing.value = false;
    editingId.value = null;
    form.client = null;
    form.name = '';
    form.center_code = '';
    form.address = '';
    form.city = '';
    form.state = '';
    form.max_candidates_overall = 0;
    form.latitude = 0;
    form.longitude = 0;
  }
  isModalOpen.value = true;
};

const closeModal = () => {
  isModalOpen.value = false;
};

const openBulkModal = () => {
    isBulkModalOpen.value = true;
    selectedFile.value = null;
    selectedBulkClient.value = null;
    bulkError.value = '';
    bulkResult.value = null;
    if (fileInput.value) fileInput.value.value = '';
};

const closeBulkModal = () => {
    isBulkModalOpen.value = false;
};

const handleFileChange = (e) => {
    selectedFile.value = e.target.files[0];
};

const downloadTemplate = async () => {
    try {
        const response = await api.get('/masters/centers/download-template/', {
            responseType: 'blob'
        });
        const url = window.URL.createObjectURL(new Blob([response.data]));
        const link = document.createElement('a');
        link.href = url;
        link.setAttribute('download', 'center_bulk_template.csv');
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        window.URL.revokeObjectURL(url);
    } catch (e) {
        console.error("Failed to download template", e);
        alert("Failed to download template. Please check your connection.");
    }
};

const submitBulkCenters = async () => {
    if (!selectedFile.value) return;
    
    const formData = new FormData();
    formData.append('file', selectedFile.value);
    if (selectedBulkClient.value) {
        formData.append('client_id', selectedBulkClient.value);
    }

    bulkRequesting.value = true;
    bulkError.value = '';
    bulkResult.value = null;
    try {
        const res = await api.post('/masters/centers/bulk-import/', formData, {
            headers: {
                'Content-Type': 'multipart/form-data'
            }
        });
        bulkResult.value = res.data;
        await loadCenters();
        if (res.data.errors.length === 0) {
            setTimeout(() => {
                closeBulkModal();
                alert(`Successfully imported ${res.data.created.length} centers.`);
            }, 1000);
        }
    } catch (e) {
        bulkError.value = e.response?.data?.detail || "Failed to process bulk import. Ensure it is a valid CSV.";
    } finally {
        bulkRequesting.value = false;
    }
};

const saveCenter = async () => {
    try {
        if (isEditing.value) {
            await api.patch(`/masters/centers/${editingId.value}/`, form);
        } else {
            await api.post('/masters/centers/', form);
        }
        await loadCenters();
        closeModal();
    } catch (e) {
        console.error("Failed to save center", e);
        alert("Failed to save center.");
    }
};

const deleteCenter = async (uid) => {
    if (!confirm('Are you sure you want to delete this center?')) return;
    try {
        await api.delete(`/masters/centers/${uid}/`);
        await loadCenters();
    } catch (e) {
        console.error("Failed to delete center", e);
        alert("Failed to delete center.");
    }
};
</script>
