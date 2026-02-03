<template>
  <div class="space-y-6">
    <!-- Header Section -->


    <!-- EduManager Stats Grid (Dynamic) -->
    <div class="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
      <!-- DRAFT EXAMS -->
      <div class="bg-white rounded-xl p-6 shadow-sm border border-gray-100 flex items-start justify-between">
         <div>
            <div class="text-xs font-bold text-gray-400 uppercase tracking-wider mb-2">DRAFT EXAMS</div>
            <div class="flex items-baseline space-x-3">
                <span class="text-3xl font-bold text-gray-800">{{ examStats.draft }}</span>
                <span v-if="examStats.total > 0" class="text-xs font-medium text-gray-500 bg-gray-100 px-1.5 py-0.5 rounded">{{ examStats.draftPct }}%</span>
            </div>
            <div class="text-xs text-gray-400 mt-2">Exams in preparation</div>
         </div>
         <div class="p-3 bg-gray-50 rounded-lg text-gray-400">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" /></svg>
         </div>
      </div>

      <!-- LIVE EXAMS -->
      <div class="bg-white rounded-xl p-6 shadow-sm border border-gray-100 flex items-start justify-between">
         <div>
            <div class="text-xs font-bold text-gray-400 uppercase tracking-wider mb-2">LIVE EXAMS</div>
            <div class="flex items-baseline space-x-3">
                <span class="text-3xl font-bold text-gray-800">{{ examStats.live }}</span>
                <span v-if="examStats.total > 0" class="text-xs font-medium text-green-600 bg-green-50 px-1.5 py-0.5 rounded">{{ examStats.livePct }}%</span>
            </div>
            <div class="text-xs text-gray-400 mt-2">Currently in progress</div>
         </div>
         <div class="p-3 bg-green-50 rounded-lg text-green-500">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5.636 18.364a9 9 0 010-12.728m12.728 0a9 9 0 010 12.728m-9.9-2.829a5 5 0 010-7.07m7.072 0a5 5 0 010 7.07M13 12a1 1 0 11-2 0 1 1 0 012 0z" /></svg>
         </div>
      </div>

      <!-- COMPLETED -->
      <div class="bg-white rounded-xl p-6 shadow-sm border border-gray-100 flex items-start justify-between">
         <div>
            <div class="text-xs font-bold text-gray-400 uppercase tracking-wider mb-2">COMPLETED</div>
            <div class="flex items-baseline space-x-3">
                <span class="text-3xl font-bold text-gray-800">{{ examStats.completed }}</span>
                <span v-if="examStats.total > 0" class="text-xs font-medium text-blue-600 bg-blue-50 px-1.5 py-0.5 rounded">{{ examStats.completedPct }}%</span>
            </div>
            <div class="text-xs text-gray-400 mt-2">Total finalized exams</div>
         </div>
         <div class="p-3 bg-blue-50 rounded-lg text-blue-500">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
         </div>
      </div>
    </div>

    <!-- Main Content Area -->
    <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
      
      <!-- Left Column: Recent Exams Table -->
      <div class="lg:col-span-2">
        <div class="flex items-center justify-between mb-6">
           <h2 class="text-xl font-bold text-gray-800">Recent Exams</h2>
           <button v-if="canManageExams" @click="$router.push('/operations/exams')" class="px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white text-sm font-semibold rounded-lg shadow-sm shadow-blue-200 transition-all flex items-center">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" /></svg>
              Create Exam
           </button>
        </div>

        <div class="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
           <table class="min-w-full divide-y divide-gray-100">
               <thead class="bg-gray-50/50 text-gray-500">
                  <tr>
                      <th class="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider">Exam Name (Code)</th>
                      <th class="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider">Client</th>
                      <th class="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider">Date Range</th>
                      <th class="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider">Status</th>
                      <th class="px-6 py-4 text-left text-xs font-bold uppercase tracking-wider">Created By</th>
                  </tr>
               </thead>
               <tbody class="divide-y divide-gray-50">
                  <tr v-for="exam in exams.slice(0, 5)" :key="exam.uid" class="hover:bg-blue-50/30 transition-colors cursor-pointer group">
                      <!-- Exam Name & Description -->
                      <td class="px-6 py-4">
                          <div class="text-sm font-bold text-gray-800 group-hover:text-blue-600">{{ exam.name }}</div>
                          <div class="text-xs text-gray-400 font-mono mt-0.5 uppercase tracking-wide">({{ exam.exam_code }})</div>
                          <div class="text-[10px] text-gray-400 mt-1 truncate max-w-[150px]">{{ exam.description || 'No description' }}</div>
                      </td>
                      
                      <!-- Client -->
                      <td class="px-6 py-4 text-sm text-gray-700 font-medium">
                          {{ exam.client_name || 'No Client' }}
                      </td>

                      <!-- Date Range -->
                      <td class="px-6 py-4 text-sm text-gray-500">
                         {{ formatDateRange(exam.exam_start_date, exam.exam_end_date) }}
                      </td>

                      <!-- Status Badge -->
                      <td class="px-6 py-4">
                          <span class="px-2.5 py-1 rounded text-[10px] font-bold uppercase border min-w-[80px] text-center inline-block" :class="{
                               'bg-green-100 text-green-700 border-green-200': exam.status === 'LIVE',
                               'bg-blue-100 text-blue-700 border-blue-200': exam.status === 'READY',
                               'bg-orange-100 text-orange-700 border-orange-200': exam.status === 'CONFIGURING',
                               'bg-gray-100 text-gray-600 border-gray-200': exam.status === 'DRAFT' || exam.status === 'COMPLETED'
                           }">{{ formatStatus(exam.status) }}</span>
                      </td>

                      <!-- Created By -->
                      <td class="px-6 py-4 flex items-center">
                          <div class="h-8 w-8 rounded-full bg-orange-100 text-orange-600 text-xs font-bold flex items-center justify-center mr-3 border border-orange-200">
                             {{ (exam.created_by_name || exam.created_by_username || 'A').charAt(0).toUpperCase() }}
                          </div>
                          <div>
                              <div class="text-sm font-medium text-gray-900">{{ exam.created_by_name || exam.created_by_username || 'Admin' }}</div>
                              <div class="text-[10px] text-gray-400 capitalize">{{ (exam.created_by_role || 'Creator').toLowerCase() }}</div>
                          </div>
                      </td>
                  </tr>
                  <!-- Empty State -->
                  <tr v-if="!exams.length && !isExamsLoading">
                      <td colspan="5" class="px-6 py-12 text-center text-gray-400 text-sm">No recent exams found. Create one to get started.</td>
                  </tr>
                  <tr v-if="isExamsLoading">
                      <td colspan="5" class="px-6 py-12 text-center text-indigo-500 text-sm">Loading exams data...</td>
                  </tr>
               </tbody>
           </table>
           <div class="p-4 border-t border-gray-50 bg-gray-50/30 flex justify-between items-center text-xs text-gray-500">
               <span>Showing {{ Math.min(exams.length, 5) }} of {{ exams.length }} exams</span>
               <div class="flex space-x-2">
                   <button class="w-8 h-8 rounded border border-gray-200 flex items-center justify-center bg-white hover:border-blue-300 hover:text-blue-600 transition-colors"><</button>
                   <button class="w-8 h-8 rounded border border-gray-200 flex items-center justify-center bg-white hover:border-blue-300 hover:text-blue-600 transition-colors">></button>
               </div>
           </div>
        </div>
      </div>

      <!-- Right Column: Stats & Insights -->
      <div class="lg:col-span-1 space-y-6">
          
          <!-- Status Distribution Donut -->
          <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
              <h3 class="text-base font-bold text-gray-800 mb-6">Status Distribution</h3>
              <div class="relative h-48 flex items-center justify-center">
                  <!-- Custom Donut CSS (Simulated via SVG for dynamic) -->
                  <svg width="160" height="160" viewBox="0 0 40 40" class="transform -rotate-90">
                      <!-- Background Circle -->
                      <circle cx="20" cy="20" r="15.9155" fill="none" stroke="#e5e7eb" stroke-width="3.5" />
                      
                      <!-- Completed Segment (Blue) - Base -->
                      <circle cx="20" cy="20" r="15.9155" fill="none" stroke="#3b82f6" stroke-width="3.5" 
                              :stroke-dasharray="`${examStats.completedPct} ${100 - examStats.completedPct}`" 
                              stroke-dashoffset="0" />
                      
                      <!-- Live Segment (Green) - Offset by Completed -->
                      <circle cx="20" cy="20" r="15.9155" fill="none" stroke="#10b981" stroke-width="3.5" 
                              :stroke-dasharray="`${examStats.livePct} ${100 - examStats.livePct}`" 
                              :stroke-dashoffset="`-${examStats.completedPct}`" />
                      
                      <!-- Configuring/Draft (Orange) - Offset by Completed + Live -->
                      <circle cx="20" cy="20" r="15.9155" fill="none" stroke="#f97316" stroke-width="3.5" 
                              :stroke-dasharray="`${examStats.configuringPct + examStats.draftPct} ${100 - (examStats.configuringPct + examStats.draftPct)}`" 
                              :stroke-dashoffset="`-${examStats.completedPct + examStats.livePct}`" />
                  </svg>
                  
                  <div class="absolute inset-0 flex flex-col items-center justify-center">
                      <span class="text-3xl font-bold text-gray-800">{{ examStats.total }}</span>
                      <span class="text-[10px] text-gray-400 uppercase tracking-widest">TOTAL</span>
                  </div>
              </div>
              <div class="mt-6 space-y-3">
                  <div class="flex items-center justify-between text-sm">
                      <div class="flex items-center"><span class="w-2 h-2 rounded-full bg-blue-500 mr-2"></span> Completed</div>
                      <span class="font-bold text-gray-700">{{ examStats.completed }} ({{ examStats.completedPct }}%)</span>
                  </div>
                  <div class="flex items-center justify-between text-sm">
                      <div class="flex items-center"><span class="w-2 h-2 rounded-full bg-green-500 mr-2"></span> Live</div>
                      <span class="font-bold text-gray-700">{{ examStats.live }} ({{ examStats.livePct }}%)</span>
                  </div>
                   <div class="flex items-center justify-between text-sm">
                      <div class="flex items-center"><span class="w-2 h-2 rounded-full bg-orange-400 mr-2"></span> Configuring</div>
                      <span class="font-bold text-gray-700">{{ examStats.configuring }} ({{ examStats.configuringPct }}%)</span>
                  </div>
              </div>
          </div>

          <!-- Quick Insights -->
          <div class="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
              <h3 class="text-base font-bold text-gray-800 mb-4">Quick Insights</h3>
              
              <!-- <div class="p-3 bg-blue-50 rounded-lg border-l-4 border-blue-500 mb-3">
                  <h4 class="text-xs font-bold text-blue-700 mb-1">Peak Volume Detected</h4>
                  <p class="text-xs text-blue-600/80 leading-relaxed">Exam concurrency reached 89% capacity between 10am - 12pm.</p>
              </div>

              <div class="p-3 bg-green-50 rounded-lg border-l-4 border-green-500">
                  <h4 class="text-xs font-bold text-green-700 mb-1">Pass Rate Improved</h4>
                  <p class="text-xs text-green-600/80 leading-relaxed">Average math scores are up by 14% compared to last semester.</p>
              </div> -->
          </div>

      </div>

    </div>

    <!-- Slide-out Drawer (Exams) -->
    <div class="relative z-50 pointer-events-none" aria-labelledby="slide-over-title" role="dialog" aria-modal="true">
      <!-- Background backdrop, show/hide based on slide-over state. -->
      <div v-if="isDrawerOpen" class="fixed inset-0 bg-gray-900/50 backdrop-blur-sm transition-opacity pointer-events-auto" @click="closeDrawer"></div>

      <div class="fixed inset-0 overflow-hidden pointer-events-none" :class="{ 'pointer-events-auto': isDrawerOpen }">
        <div class="absolute inset-0 overflow-hidden">
          <div class="pointer-events-none fixed inset-y-0 right-0 flex max-w-full pl-10">
            <!-- Slide-over panel, show/hide based on slide-over state. -->
            <div 
              class="pointer-events-auto w-screen max-w-md transform transition ease-in-out duration-500 sm:duration-700 bg-white shadow-2xl flex flex-col h-full"
              :class="isDrawerOpen ? 'translate-x-0' : 'translate-x-full'"
            >
              <!-- Drawer Header -->
              <div class="flex h-20 items-center justify-between bg-purple-700 px-6 py-4 text-white shadow-lg">
                <div class="flex flex-col">
                     <h2 class="text-xl font-bold leading-6" id="slide-over-title">All Exams</h2>
                     <p class="text-purple-100 text-sm mt-1">Manage and view active examinations.</p>
                </div>
                <div class="flex h-7 items-center">
                  <button type="button" class="relative rounded-md text-purple-200 hover:text-white focus:outline-none" @click="closeDrawer">
                    <span class="absolute -inset-2.5"></span>
                    <span class="sr-only">Close panel</span>
                    <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" aria-hidden="true">
                      <title>Close</title>
                      <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  </button>
                </div>
              </div>

              <!-- Drawer Body -->
              <div class="flex-1 overflow-y-auto px-6 py-6 custom-scrollbar bg-gray-50">
                   <!-- Loading State -->
                   <div v-if="isExamsLoading" class="flex flex-col items-center justify-center h-48 space-y-4">
                      <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-purple-700"></div>
                      <p class="text-gray-500 text-sm">Loading exams...</p>
                   </div>

                   <!-- Empty State -->
                   <div v-else-if="exams.length === 0" class="flex flex-col items-center justify-center h-48 text-center">
                       <div class="p-3 bg-gray-100 rounded-full mb-3">
                           <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" /></svg>
                       </div>
                       <p class="text-gray-500 font-medium">No exams found</p>
                       <p class="text-xs text-gray-400 mt-1">Create a new exam to see it here.</p>
                   </div>

                   <!-- Exams List -->
                   <div v-else class="space-y-4">
                       <div v-for="exam in exams" :key="exam.uid" class="bg-white rounded-xl p-4 shadow-sm border border-gray-100 hover:shadow-md transition-shadow group relative overflow-hidden">
                           <div class="absolute left-0 top-0 bottom-0 w-1" :class="{
                               'bg-green-500': exam.status === 'LIVE',
                               'bg-blue-500': exam.status === 'READY',
                               'bg-yellow-500': exam.status === 'CONFIGURING',
                               'bg-gray-300': exam.status === 'DRAFT' || exam.status === 'COMPLETED'
                           }"></div>
                           
                           <div class="flex justify-between items-start mb-2 pl-2">
                               <div>
                                   <div class="text-xs font-bold text-gray-400 uppercase tracking-widest mb-0.5">{{ exam.exam_code }}</div>
                                   <h3 class="text-base font-bold text-gray-800 group-hover:text-purple-700 transition-colors">{{ exam.name }}</h3>
                               </div>
                               <span class="px-2 py-0.5 rounded text-[10px] font-bold uppercase border" :class="{
                                   'bg-green-50 text-green-700 border-green-100': exam.status === 'LIVE',
                                   'bg-blue-50 text-blue-700 border-blue-100': exam.status === 'READY',
                                   'bg-yellow-50 text-yellow-700 border-yellow-100': exam.status === 'CONFIGURING',
                                   'bg-gray-100 text-gray-600 border-gray-200': exam.status === 'DRAFT' || exam.status === 'COMPLETED'
                               }">{{ formatStatus(exam.status) }}</span>
                           </div>
                           
                           <div class="pl-2 space-y-1 mt-3">
                               <div class="flex items-center text-xs text-gray-500">
                                   <svg class="w-3 h-3 mr-2 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"></path></svg>
                                   <span v-if="exam.exam_start_date">{{ exam.exam_start_date }} <span v-if="exam.exam_end_date"> - {{ exam.exam_end_date }}</span></span>
                                   <span v-else class="italic text-gray-400">Date not set</span>
                               </div>
                               <div class="flex items-center text-xs text-gray-500">
                                    <svg class="w-3 h-3 mr-2 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" /></svg>
                                    {{ exam.client ? 'Client: ' + exam.client.name : 'No Client' }}
                               </div>
                           </div>

                           <div class="mt-4 pl-2 flex items-center justify-end">
                              <button class="text-xs font-semibold text-purple-600 hover:text-purple-800 flex items-center transition-colors">
                                  View Details
                                  <svg class="w-3 h-3 ml-1" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path></svg>
                              </button>
                           </div>
                       </div>
                   </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue';
import api from '../api/axios';
import { useAuthStore } from '../stores/auth';

const authStore = useAuthStore();
const canManageExams = computed(() => authStore.user?.user_type !== 'CLIENT_ADMIN');

const stats = ref({});
const currentDate = new Date().toLocaleDateString('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' });

// Drawer State
const isDrawerOpen = ref(false);
const exams = ref([]);
const isExamsLoading = ref(false);

const openExamsDrawer = async () => {
    isDrawerOpen.value = true;
    if (exams.value.length === 0) {
        await loadExams();
    }
};

const closeDrawer = () => {
    isDrawerOpen.value = false;
};

const loadExams = async () => {
    isExamsLoading.value = true;
    try {
        const res = await api.get('/operations/exams/');
        exams.value = res.data.results || res.data;
    } catch (e) {
        console.error("Failed to load exams", e);
    } finally {
        isExamsLoading.value = false;
    }
};

// Computed Stats from Exams
const examStats = computed(() => {
    const total = exams.value.length || 0;
    const baseStats = {
        draft: 0, live: 0, completed: 0, configuring: 0, total: 0,
        draftPct: 0, livePct: 0, completedPct: 0, configuringPct: 0
    };

    if (total === 0) return baseStats;

    const draft = exams.value.filter(e => e.status === 'DRAFT').length;
    const live = exams.value.filter(e => e.status === 'LIVE').length;
    const completed = exams.value.filter(e => e.status === 'COMPLETED').length;
    const configuring = exams.value.filter(e => e.status === 'CONFIGURING').length;

    return {
        draft,
        live,
        completed,
        configuring,
        total,
        draftPct: Math.round((draft / total) * 100),
        livePct: Math.round((live / total) * 100),
        completedPct: Math.round((completed / total) * 100),
        configuringPct: Math.round((configuring / total) * 100),
    };
});

// Mock Chart Data (Replacing with Dynamic if possible, but keeping consistent for now)
const chartSeries = ref([
    { name: 'Scheduled', data: [40, 50, 45, 60, 55, 65, 50] },
    { name: 'Present', data: [35, 48, 42, 58, 52, 63, 48] }
]);

const chartOptions = ref({
    chart: {
        type: 'area',
        toolbar: { show: false },
        fontFamily: 'Inter, sans-serif'
    },
    colors: ['#7e22ce', '#10b981'],
    dataLabels: { enabled: false },
    stroke: { curve: 'smooth', width: 2 },
    xaxis: {
        categories: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
        axisBorder: { show: false },
        axisTicks: { show: false }
    },
    yaxis: { show: false },
    grid: { show: false, padding: { left: 0, right: 0 } },
    legend: { position: 'top', horizontalAlign: 'right' },
    fill: {
        type: 'gradient',
        gradient: {
            shadeIntensity: 1,
            opacityFrom: 0.4,
            opacityTo: 0.05,
            stops: [0, 100]
        }
    }
});

const formatStatus = (status) => {
    return status ? status.toLowerCase().replace('_', ' ').replace(/\b\w/g, l => l.toUpperCase()) : '';
};

// Date Formatter for "Oct 1 - Oct 15" style
const formatDateRange = (start, end) => {
    if (!start) return 'Date not set';
    
    const options = { month: 'short', day: 'numeric' };
    const s = new Date(start).toLocaleDateString('en-US', options);
    
    if (!end) return s;
    const e = new Date(end).toLocaleDateString('en-US', options);
    return `${s} - ${e}`;
};

onMounted(async () => {
    // Load Stats
    try {
        const statsRes = await api.get('/reports/summary/');
        stats.value = statsRes.data;
    } catch (e) {
        console.error("Failed to load dashboard stats", e);
        // Fallback to zeros if stats fail
        stats.value = { draft: 0, live: 0, completed: 0, configuring: 0, total: 0 };
    }

    // Load Exams
    try {
        const examsRes = await api.get('/operations/exams/');
        const data = examsRes.data.results || examsRes.data;
        exams.value = Array.isArray(data) ? data : [];
    } catch (e) {
        console.error("Failed to load dashboard exams", e);
        exams.value = [];
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
        alert("Failed to export CSV. Please try again.");
    }
};
</script>
