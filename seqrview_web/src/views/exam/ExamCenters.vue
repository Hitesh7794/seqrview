<template>
  <div class="space-y-6 animate-in fade-in duration-500">
    <!-- Header -->
    <div class="flex items-center justify-between bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
      <div class="flex items-center gap-4">
        <button @click="$router.push(`/exam/${examCode}`)" class="text-gray-400 hover:text-gray-600 transition-colors">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
            </svg>
        </button>
        <div>
            <h1 class="text-2xl font-black text-gray-900 tracking-tight" v-if="exam">{{ exam.name }} - Centers</h1>
            <div v-else class="h-8 w-48 bg-gray-200 rounded animate-pulse"></div>
            <p class="text-sm text-gray-500 mt-1">View mapped centers for this exam.</p>
        </div>
      </div>
      
      <div class="flex gap-2">
        <ExportButton 
            endpoint="/operations/exam-centers/export/" 
            filename="exam_centers.csv"
            :filters="{ exam: exam?.uid }"
            v-if="exam"
        />
      </div>
    </div>

    <!-- Stats Row -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-6" v-if="exam">
        <div class="bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
            <p class="text-xs font-bold text-gray-400 uppercase tracking-wider">Total Centers</p>
            <p class="text-3xl font-black text-gray-900 mt-1">{{ centers.length }}</p>
        </div>
         <div class="bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
            <p class="text-xs font-bold text-gray-400 uppercase tracking-wider">Total Capacity</p>
            <p class="text-3xl font-black text-indigo-600 mt-1">{{ totalCapacity }}</p>
        </div>
         <div class="bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
            <p class="text-xs font-bold text-gray-400 uppercase tracking-wider">Geofence Enabled</p>
            <p class="text-3xl font-black text-green-600 mt-1">{{ exam.is_geofencing_enabled ? 'Yes' : 'No' }}</p>
        </div>
    </div>

    <!-- Centers List -->
    <div v-if="loading" class="bg-white rounded-2xl p-12 shadow-sm border border-gray-100 text-center">
         <div class="inline-block h-8 w-8 animate-spin rounded-full border-4 border-solid border-indigo-600 border-r-transparent align-[-0.125em] motion-reduce:animate-[spin_1.5s_linear_infinite]" role="status"></div>
         <p class="mt-2 text-gray-500">Loading centers...</p>
    </div>
    
    <div v-else-if="centers.length === 0" class="bg-white rounded-2xl p-12 text-center shadow-sm border border-gray-100">
        <div class="inline-flex items-center justify-center w-16 h-16 rounded-full bg-indigo-50 mb-4">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-8 w-8 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
            </svg>
        </div>
        <h3 class="text-lg font-bold text-gray-900 mb-1">No Centers Found</h3>
        <p class="text-gray-500 mb-6">There are no centers mapped to this exam yet.</p>
    </div>

    <div v-else class="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
        <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-100">
                <thead class="bg-gray-50/50">
                    <tr>
                        <th class="px-6 py-4 text-left text-[10px] font-black uppercase tracking-widest text-gray-500">Center Name</th>
                        <th class="px-6 py-4 text-left text-[10px] font-black uppercase tracking-widest text-gray-500">Location</th>
                        <th class="px-6 py-4 text-left text-[10px] font-black uppercase tracking-widest text-gray-500">Capacity</th>
                        <th class="px-6 py-4 text-left text-[10px] font-black uppercase tracking-widest text-gray-500">Status</th>
                    </tr>
                </thead>
                <tbody class="divide-y divide-gray-100 bg-white">
                    <tr v-for="center in centers" :key="center.uid" class="hover:bg-gray-50/20 transition-colors">
                        <td class="px-6 py-4">
                            <div class="flex items-center">
                                <div class="h-10 w-10 flex-shrink-0 bg-indigo-50 rounded-lg flex items-center justify-center text-indigo-600 font-bold border border-indigo-100 text-sm">
                                    {{ center.client_center_name.charAt(0).toUpperCase() }}
                                </div>
                                <div class="ml-4">
                                    <div class="text-sm font-bold text-gray-900">{{ center.client_center_name }}</div>
                                    <div class="text-xs text-gray-500 font-mono mt-0.5">{{ center.client_center_code }}</div>
                                </div>
                            </div>
                        </td>
                        <td class="px-6 py-4">
                             <div class="text-sm font-medium text-gray-700">{{ center.city || '-' }}</div>
                             <div class="mt-1">
                                <a v-if="center.latitude && center.longitude" 
                                    :href="`https://www.google.com/maps?q=${center.latitude},${center.longitude}`" 
                                    target="_blank"
                                    class="text-[10px] text-blue-600 hover:text-blue-800 flex items-center gap-0.5 hover:underline decoration-blue-300 font-medium">
                                    <svg xmlns="http://www.w3.org/2000/svg" class="h-3 w-3" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" /><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" /></svg>
                                    View Map
                                </a>
                                <span v-else class="text-[9px] text-gray-400 italic">No GPS</span>
                            </div>
                        </td>
                        <td class="px-6 py-4">
                            <span class="inline-flex items-center px-2.5 py-0.5 rounded-md text-xs font-bold bg-indigo-50 text-indigo-700">
                                {{ center.active_capacity || '-' }}
                            </span>
                        </td>
                        <td class="px-6 py-4">
                             <span class="inline-flex items-center px-2 py-0.5 rounded text-[10px] font-black uppercase tracking-wider"
                                :class="{
                                    'bg-green-50 text-green-700': center.status === 'ACTIVE',
                                    'bg-gray-100 text-gray-600': center.status === 'INACTIVE',
                                    'bg-red-50 text-red-700': center.status === 'BLACKLISTED'
                                }">
                                {{ center.status }}
                            </span>
                        </td>
                    </tr>
                </tbody>
            </table>
        </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue';
import { useRoute } from 'vue-router';
import api from '../../api/axios';
import ExportButton from '../../components/ExportButton.vue';

const route = useRoute();
const examCode = route.params.code;

const exam = ref(null);
const centers = ref([]);
const loading = ref(false);

const totalCapacity = computed(() => {
    return centers.value.reduce((sum, center) => sum + (center.active_capacity || 0), 0);
});

const loadData = async () => {
    loading.value = true;
    try {
        // Fetch exam details first
        const examRes = await api.get(`/operations/exams/${examCode}/`);
        exam.value = examRes.data;

        // Fetch centers (Exam Admin role handles context automatically, but we can filter by exam UID for clarity)
        const centersRes = await api.get(`/operations/exam-centers/?exam=${exam.value.uid}`);
        centers.value = centersRes.data.results || centersRes.data;
    } catch (e) {
        console.error("Failed to load details", e);
    } finally {
        loading.value = false;
    }
};

onMounted(loadData);
</script>
