<template>
  <div>
    <div class="flex justify-between items-center mb-6">
      <h1 class="text-2xl font-bold text-gray-800">Centers</h1>
      <button class="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700">
        + Add Center
      </button>
    </div>

    <div class="bg-white rounded-lg shadow overflow-hidden">
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Name</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Address</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Capacity</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Location</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
          </tr>
        </thead>
        <tbody class="bg-white divide-y divide-gray-200">
          <tr v-for="center in centers" :key="center.uid">
            <td class="px-6 py-4 whitespace-nowrap">
              <div class="text-sm font-medium text-gray-900">{{ center.name }}</div>
            </td>
             <td class="px-6 py-4 text-sm text-gray-500">
               {{ center.address }}, {{ center.city }}
            </td>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{{ center.capacity }}</td>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-blue-600">
              <a v-if="center.latitude" :href="`https://www.google.com/maps?q=${center.latitude},${center.longitude}`" target="_blank">View Map</a>
              <span v-else class="text-gray-400">N/A</span>
            </td>
            <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
              <a href="#" class="text-indigo-600 hover:text-indigo-900">Edit</a>
            </td>
          </tr>
           <tr v-if="centers.length === 0">
             <td colspan="5" class="px-6 py-4 text-center text-gray-500">No centers found.</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import api from '../../api/axios';

const centers = ref([]);

onMounted(async () => {
  try {
    const res = await api.get('/masters/centers/');
    centers.value = res.data.results || res.data;
  } catch (e) {
    console.error("Failed to load centers", e);
  }
});
</script>
