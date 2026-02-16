<template>
  <div v-if="loading" class="text-center py-12">
    <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600 mx-auto mb-4"></div>
    <p class="text-gray-500 font-medium">Loading exam dashboard...</p>
  </div>
  <div v-else-if="error" class="text-center py-12">
     <div class="bg-red-50 text-red-600 p-4 rounded-xl inline-block">
        <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 inline mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
        {{ error }}
     </div>
  </div>
  <div v-else class="space-y-8 animate-in fade-in duration-500">
    <!-- Header Section -->
    <div class="bg-white p-6 rounded-2xl shadow-sm border border-gray-100 flex flex-col md:flex-row md:items-center justify-between gap-6">
        <div>
            <div class="flex items-center gap-3">
                <h1 class="text-3xl font-black text-gray-900 tracking-tight">{{ exam.name }}</h1>
                  <span class="px-3 py-1 text-[10px] font-black uppercase tracking-widest rounded-full border shadow-sm"
                      :class="{
                          'bg-green-50 text-green-700 border-green-200': !exam.is_locked && exam.status === 'LIVE',
                          'bg-orange-50 text-orange-700 border-orange-200': !exam.is_locked && (exam.status === 'CONFIGURING' || exam.status === 'DRAFT'),
                          'bg-blue-50 text-blue-700 border-blue-200': !exam.is_locked && exam.status === 'READY',
                          'bg-gray-100 text-gray-600 border-gray-200': exam.is_locked || ['COMPLETED', 'ARCHIVED', 'CANCELLED'].includes(exam.status)
                      }">
                      {{ exam.is_locked ? 'Completed' : exam.status }}
                </span>
            </div>
            <div class="flex items-center gap-2 mt-2 text-gray-400 font-medium">
                <span class="bg-gray-100 px-2 py-0.5 rounded text-xs text-gray-600 font-mono font-bold">{{ exam.exam_code }}</span>
                <span class="text-gray-300">•</span>
                <span class="text-sm font-semibold text-gray-500">{{ exam.client_name }}</span>
            </div>
        </div>
        
        <div class="flex gap-8 items-center bg-gray-50 p-4 rounded-xl border border-gray-100">
            <div class="text-center">
                <p class="text-[10px] text-gray-400 font-black uppercase tracking-tighter">Start Date</p>
                <p class="text-sm font-bold text-gray-900">{{ exam.exam_start_date || 'TBD' }}</p>
            </div>
            <div class="w-px h-8 bg-gray-200"></div>
            <div class="text-center">
                <p class="text-[10px] text-gray-400 font-black uppercase tracking-tighter">End Date</p>
                <p class="text-sm font-bold text-gray-900">{{ exam.exam_end_date || 'TBD' }}</p>
            </div>
        </div>
    </div>

    <!-- Stats Grid -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <!-- Shifts Card -->
        <div class="bg-white p-6 rounded-2xl shadow-sm border border-gray-100 hover:shadow-md transition-all group">
            <div class="flex items-center justify-between mb-4">
                <div class="p-3 bg-blue-50 text-blue-600 rounded-xl group-hover:scale-110 transition-transform">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                </div>
                <!-- <span class="text-xs font-bold text-gray-400 uppercase tracking-widest">Shifts</span> -->
            </div>
            <div class="space-y-1">
                <h3 class="text-3xl font-black text-gray-900">{{ stats.shifts?.total || 0 }}</h3>
                <p class="text-sm font-medium text-gray-500">Total Shifts</p>
            </div>
            <div class="mt-4 pt-4 border-t border-gray-50 flex items-center justify-between text-xs">
                 <span class="text-gray-400 font-medium">Today</span>
                 <span class="font-bold text-gray-900 px-2 py-0.5 bg-gray-100 rounded">{{ stats.shifts?.today || 0 }} Active</span>
            </div>
        </div>

        <!-- Centers Card -->
         <div class="bg-white p-6 rounded-2xl shadow-sm border border-gray-100 hover:shadow-md transition-all group">
            <div class="flex items-center justify-between mb-4">
                <div class="p-3 bg-indigo-50 text-indigo-600 rounded-xl group-hover:scale-110 transition-transform">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
                    </svg>
                </div>
            </div>
             <div class="space-y-1">
                <h3 class="text-3xl font-black text-gray-900">{{ stats.centers?.total || 0 }}</h3>
                <p class="text-sm font-medium text-gray-500">Exam Centers</p>
            </div>
             <div class="mt-4 pt-4 border-t border-gray-50 flex items-center justify-between text-xs">
                 <span class="text-gray-400 font-medium">Status</span>
                 <span class="font-bold text-green-600 px-2 py-0.5 bg-green-50 rounded">{{ stats.centers?.active || 0 }} Active</span>
            </div>
        </div>

        <!-- Operators Card -->
         <div class="bg-white p-6 rounded-2xl shadow-sm border border-gray-100 hover:shadow-md transition-all group">
            <div class="flex items-center justify-between mb-4">
                <div class="p-3 bg-purple-50 text-purple-600 rounded-xl group-hover:scale-110 transition-transform">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
                    </svg>
                </div>
            </div>
             <div class="space-y-1">
                <h3 class="text-3xl font-black text-gray-900">{{ stats.operators?.total || 0 }}</h3>
                <p class="text-sm font-medium text-gray-500">Total Operators</p>
            </div>
             <div class="mt-4 pt-4 border-t border-gray-50 flex items-center justify-between text-xs">
                 <span class="text-gray-400 font-medium">On Duty Today</span>
                 <span class="font-bold text-purple-600 px-2 py-0.5 bg-purple-50 rounded">{{ stats.operators?.active_today || 0 }}</span>
            </div>
        </div>

        <!-- Candidates Card -->
         <div class="bg-white p-6 rounded-2xl shadow-sm border border-gray-100 hover:shadow-md transition-all group">
            <div class="flex items-center justify-between mb-4">
                <div class="p-3 bg-orange-50 text-orange-600 rounded-xl group-hover:scale-110 transition-transform">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                    </svg>
                </div>
            </div>
             <div class="space-y-1">
                <h3 class="text-3xl font-black text-gray-900">{{ stats.candidates?.total || 0 }}</h3>
                <p class="text-sm font-medium text-gray-500">Exp. Candidates</p>
            </div>
            <div class="mt-4 pt-4 border-t border-gray-50 flex items-center justify-between text-xs">
                 <span class="text-gray-400 font-medium">Attendance</span>
                 <span class="font-bold text-gray-400 px-2 py-0.5 bg-gray-100 rounded">Coming Soon</span>
            </div>
        </div>
    </div>

    <!-- Quick Actions -->
    <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
        <button 
            @click="$router.push(`/exam/${exam.exam_code}/shifts`)"
            class="flex items-center justify-center gap-2 p-4 bg-white border border-gray-200 rounded-xl hover:border-blue-300 hover:bg-blue-50 hover:text-blue-700 text-gray-600 font-bold transition-all"
        >
            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            Manage Shifts
        </button>
        <button 
            @click="$router.push(`/exam/${exam.exam_code}/centers`)"
            class="flex items-center justify-center gap-2 p-4 bg-white border border-gray-200 rounded-xl hover:border-indigo-300 hover:bg-indigo-50 hover:text-indigo-700 text-gray-600 font-bold transition-all"
        >
            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" />
            </svg>
            Manage Centers
        </button>
         <button 
            @click="$router.push(`/exam/${exam.exam_code}/operators`)"
            class="flex items-center justify-center gap-2 p-4 bg-white border border-gray-200 rounded-xl hover:border-purple-300 hover:bg-purple-50 hover:text-purple-700 text-gray-600 font-bold transition-all"
        >
             <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
            </svg>
            View Operators
        </button>
         <button 
            @click="$router.push(`/exam/${exam.exam_code}/reports`)"
            class="flex items-center justify-center gap-2 p-4 bg-white border border-gray-200 rounded-xl hover:border-orange-300 hover:bg-orange-50 hover:text-orange-700 text-gray-600 font-bold transition-all"
        >
            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                 <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
            </svg>
            Live Reports
        </button>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import api from '../../api/axios';

const route = useRoute();
const exam = ref({});
const stats = ref({});
const loading = ref(true);
const error = ref(null);

const loadExamData = async () => {
    loading.value = true;
    try {
        const code = route.params.code;
        if (!code) {
            error.value = "No exam specified.";
            return;
        }
        
        // 1. Load Exam Details
        const res = await api.get(`/operations/exams/${code}/`);
        exam.value = res.data;

        // 2. Load Statistics (using the new uuid from the loaded exam to be safe, or just reuse code if backend supports it. The viewset lookup supports both, but detail action usually needs ID if router not set up for slugs? Actually viewset lookup applies to action URL too. Let's try with UID from first call to be safe)
        if (exam.value.uid) {
             const statsRes = await api.get(`/operations/exams/${exam.value.uid}/statistics/`);
             stats.value = statsRes.data;
        }

    } catch (e) {
        console.error("Failed to load exam data", e);
        error.value = "Failed to load exam data. Unauthorized or not found.";
    } finally {
        loading.value = false;
    }
};

onMounted(() => {
    loadExamData();
});
</script>
