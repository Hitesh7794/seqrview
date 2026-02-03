<template>
  <div v-if="loading" class="text-center py-10">
    <p class="text-gray-500">Loading exam data...</p>
  </div>
  <div v-else-if="error" class="text-center py-10">
    <p class="text-red-500">{{ error }}</p>
  </div>
  <div v-else class="space-y-8 animate-in fade-in duration-500">
    <!-- Exam Status Header (Simplified) -->
    <div class="flex flex-col md:flex-row md:items-end justify-between gap-4">
        <div>
            <div class="flex items-center gap-3">
                <h1 class="text-3xl font-black text-gray-900 tracking-tight">{{ exam.name }}</h1>
                <span class="px-3 py-1 text-[10px] font-black uppercase tracking-widest rounded-full border shadow-sm"
                      :class="{
                          'bg-green-50 text-green-700 border-green-200': exam.status === 'LIVE',
                          'bg-orange-50 text-orange-700 border-orange-200': exam.status === 'CONFIGURING' || exam.status === 'DRAFT',
                          'bg-blue-50 text-blue-700 border-blue-200': exam.status === 'READY'
                      }">
                      {{ exam.status }}
                </span>
            </div>
            <div class="flex items-center gap-2 mt-2 text-gray-400 font-medium">
                <span class="bg-gray-100 px-2 py-0.5 rounded text-xs text-gray-500 font-mono">{{ exam.exam_code }}</span>
                <span class="text-gray-300">•</span>
                <span class="text-sm">{{ exam.client_name }}</span>
            </div>
        </div>
        
        <div class="flex gap-6 items-center bg-white p-4 rounded-2xl shadow-sm border border-gray-100">
            <div class="text-center">
                <p class="text-[10px] text-gray-400 font-black uppercase tracking-tighter">Start Date</p>
                <p class="text-sm font-bold text-gray-700">{{ exam.exam_start_date || 'TBD' }}</p>
            </div>
            <div class="w-px h-8 bg-gray-100"></div>
            <div class="text-center">
                <p class="text-[10px] text-gray-400 font-black uppercase tracking-tighter">End Date</p>
                <p class="text-sm font-bold text-gray-700">{{ exam.exam_end_date || 'TBD' }}</p>
            </div>
        </div>
    </div>

    <!-- Actions / Shortcuts -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <!-- Manage Shifts -->
        <div class="bg-white shadow rounded-lg p-6 hover:shadow-md transition-shadow cursor-pointer border-l-4 border-blue-500" @click="$router.push(`/exam/${exam.exam_code}/shifts`)">
            <h3 class="text-lg font-medium text-gray-900 flex items-center">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mr-2 text-blue-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                Manage Shifts
            </h3>
            <p class="mt-2 text-gray-500 text-sm">Configure exam sessions, timings, and details.</p>
        </div>

        <!-- Manage Centers -->
         <div class="bg-white shadow rounded-lg p-6 hover:shadow-md transition-shadow cursor-pointer border-l-4 border-indigo-500" @click="$router.push(`/exam/${exam.exam_code}/centers`)">
            <h3 class="text-lg font-medium text-gray-900 flex items-center">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mr-2 text-indigo-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
                </svg>
                Exam Centers
            </h3>
            <p class="mt-2 text-gray-500 text-sm">Map and manage centers for this exam.</p>
        </div>

         <!-- Statistics (Placeholder) -->
         <div class="bg-white shadow rounded-lg p-6 opacity-75">
            <h3 class="text-lg font-medium text-gray-900 flex items-center">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 mr-2 text-green-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
                </svg>
                Live Stats (Coming Soon)
            </h3>
            <p class="mt-2 text-gray-500 text-sm">Real-time attendance and issue tracking.</p>
        </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import api from '../../api/axios';

const route = useRoute();
const exam = ref({});
const loading = ref(true);
const error = ref(null);

const loadExam = async () => {
    loading.value = true;
    try {
        // The code is in the route param :code
        const code = route.params.code;
        if (!code) {
            error.value = "No exam specified.";
            return;
        }
        
        // Detail endpoint: /operations/exams/:exam_code/ (since lookup_field='exam_code')
        const res = await api.get(`/operations/exams/${code}/`);
        exam.value = res.data;
    } catch (e) {
        console.error("Failed to load exam", e);
        error.value = "Failed to load exam data. Unauthorized or not found.";
    } finally {
        loading.value = false;
    }
};

onMounted(() => {
    loadExam();
});
</script>
