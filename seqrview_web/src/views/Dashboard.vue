<template>
    <div class="flex justify-between items-center mb-6">
      <h1 class="text-2xl font-bold text-gray-800">Dashboard</h1>
      <button @click="exportAttendance" class="bg-gray-800 text-white px-4 py-2 rounded hover:bg-gray-900 flex items-center">
        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
        </svg>
        Export Attendance CSV
      </button>
    </div>

    <!-- Stat Cards -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
    <div class="bg-white rounded-lg shadow p-6 border-l-4 border-blue-500">
      <div class="text-gray-500 text-sm font-semibold uppercase">Total Duties</div>
      <div class="text-3xl font-bold mt-2">{{ stats.overview?.total_duties || 0 }}</div>
    </div>
    
    <div class="bg-white rounded-lg shadow p-6 border-l-4 border-green-500">
      <div class="text-gray-500 text-sm font-semibold uppercase">Present</div>
      <div class="text-3xl font-bold mt-2">{{ stats.overview?.present || 0 }}</div>
    </div>
    
    <div class="bg-white rounded-lg shadow p-6 border-l-4 border-yellow-500">
      <div class="text-gray-500 text-sm font-semibold uppercase">Pending</div>
      <div class="text-3xl font-bold mt-2">{{ stats.overview?.pending || 0 }}</div>
    </div>
    
    <div class="bg-white rounded-lg shadow p-6 border-l-4 border-red-500">
      <div class="text-gray-500 text-sm font-semibold uppercase">Open Incidents</div>
      <div class="text-3xl font-bold mt-2">{{ stats.incidents?.open || 0 }}</div>
      <div class="text-xs text-red-600 mt-1" v-if="stats.incidents?.critical_pending > 0">
        {{ stats.incidents.critical_pending }} Critical!
      </div>
    </div>
  </div>

  <div class="bg-white rounded-lg shadow overflow-hidden">
    <div class="px-6 py-4 border-b border-gray-200">
      <h3 class="text-lg font-semibold text-gray-800">Recent Incidents</h3>
    </div>
    <div class="overflow-x-auto">
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Category</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Priority</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Reported By</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Time</th>
          </tr>
        </thead>
        <tbody class="bg-white divide-y divide-gray-200">
          <tr v-for="inc in stats.recent_incidents" :key="inc.uid">
            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">{{ inc.category__name }}</td>
            <td class="px-6 py-4 whitespace-nowrap text-sm">
              <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full"
                :class="{
                  'bg-red-100 text-red-800': inc.priority === 'CRITICAL' || inc.priority === 'HIGH',
                  'bg-yellow-100 text-yellow-800': inc.priority === 'MEDIUM',
                  'bg-green-100 text-green-800': inc.priority === 'LOW'
                }">
                {{ inc.priority }}
              </span>
            </td>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{{ inc.status }}</td>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{{ inc.assignment__operator__username }}</td>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{{ new Date(inc.created_at).toLocaleString() }}</td>
          </tr>
          <tr v-if="!stats.recent_incidents?.length">
             <td colspan="5" class="px-6 py-4 text-center text-gray-500">No recent incidents.</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import api from '../api/axios';

const stats = ref({});

onMounted(async () => {
  try {
    const res = await api.get('/reports/summary/');
    stats.value = res.data;
  } catch (e) {
    console.error("Failed to load dashboard stats", e);
  }
});

const exportAttendance = async () => {
    try {
        const response = await api.get('/reports/export/attendance/', { responseType: 'blob' });
        const url = window.URL.createObjectURL(new Blob([response.data]));
        const link = document.createElement('a');
        link.href = url;
        link.setAttribute('download', `attendance_logs_${new Date().toISOString().split('T')[0]}.csv`);
        document.body.appendChild(link);
        link.click();
        link.remove();
    } catch (e) {
        console.error("Export failed", e);
        alert("Failed to export CSV.");
    }
};
</script>
