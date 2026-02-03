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
              <th class="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Location</th>
              <th class="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Type</th>
              <th class="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Capacity</th>
              <th class="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Coordinates</th>
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
                <div class="text-sm text-gray-900">{{ center.city }}</div>
                <div class="text-sm text-gray-500">{{ center.state }}</div>
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-indigo-50 text-indigo-700 border border-indigo-100">
                  {{ center.center_type || 'N/A' }}
                </span>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                <div class="flex items-center">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 mr-1 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" /></svg>
                  {{ center.max_candidates_overall || 0 }}
                </div>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-blue-600">
                <a v-if="center.latitude && center.longitude" 
                   :href="`https://www.google.com/maps?q=${center.latitude},${center.longitude}`" 
                   target="_blank"
                   class="flex items-center hover:underline">
                   <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" /><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" /></svg>
                   Map
                </a>
                <span v-else class="text-gray-400 text-xs italic">No coords</span>
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
                <label class="block text-sm font-medium text-gray-700">Type</label>
                <select v-model="form.center_type" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm border p-2">
                    <option value="">Select Type</option>
                    <option value="SCHOOL">School</option>
                    <option value="COLLEGE">College</option>
                    <option value="UNIVERSITY">University</option>
                    <option value="OTHER">Other</option>
                </select>
            </div>
            <div>
                <label class="block text-sm font-medium text-gray-700">Capacity</label>
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
  </div>
</template>

<script setup>
import { ref, onMounted, computed, reactive } from 'vue';
import api from '../../api/axios';
import BaseModal from '../../components/BaseModal.vue';

const centers = ref([]);
const searchQuery = ref('');
const isModalOpen = ref(false);
const isEditing = ref(false);
const editingId = ref(null);

const form = reactive({
  name: '',
  center_code: '',
  address: '',
  city: '',
  state: '',
  center_type: '',
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
    const res = await api.get('/centers/');
    centers.value = res.data.results || res.data;
  } catch (e) {
    console.error("Failed to load centers", e);
  }
};

onMounted(loadCenters);

const openModal = (center = null) => {
  if (center) {
    isEditing.value = true;
    editingId.value = center.uid;
    Object.assign(form, center);
    // Ensure nulls are handled for controlled inputs
    form.max_candidates_overall = form.max_candidates_overall || 0;
    form.latitude = form.latitude || 0;
    form.longitude = form.longitude || 0;
  } else {
    isEditing.value = false;
    editingId.value = null;
    form.name = '';
    form.center_code = '';
    form.address = '';
    form.city = '';
    form.state = '';
    form.center_type = '';
    form.max_candidates_overall = 0;
    form.latitude = 0;
    form.longitude = 0;
  }
  isModalOpen.value = true;
};

const closeModal = () => {
  isModalOpen.value = false;
};

const saveCenter = async () => {
    try {
        if (isEditing.value) {
            await api.patch(`/centers/${editingId.value}/`, form);
        } else {
            await api.post('/centers/', form);
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
        await api.delete(`/centers/${uid}/`);
        await loadCenters();
    } catch (e) {
        console.error("Failed to delete center", e);
        alert("Failed to delete center.");
    }
};
</script>
