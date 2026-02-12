<template>
  <div>
    <div class="flex justify-between items-center mb-4 px-1">
      <!-- <h1 class="text-2xl font-bold text-gray-800">Exams</h1> -->
      <!-- Top Bar: Search & Actions -->
      <div class="flex-1 flex items-center justify-between gap-4">
        <!-- Search Bar -->
        <div class="relative w-64 md:w-96">
            <input 
                v-model="searchQuery" 
                type="text" 
                placeholder="Search exams, codes..." 
                class="w-full pl-10 pr-4 py-2 border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 transition-all bg-white shadow-sm"
                @input="handleSearch"
            >
            <div class="absolute left-3 top-2.5 text-gray-400">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                </svg>
            </div>
            <div v-if="loading" class="absolute right-3 top-2.5">
                <svg class="animate-spin h-4 w-4 text-blue-500" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>
            </div>
        </div>

        <!-- Action Buttons & Filter -->
        <div class="flex gap-3 items-center">
            <!-- Status Filter -->
            <div class="relative w-40">
                <div class="absolute left-3 top-2.5 text-gray-400 pointer-events-none">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 4a1 1 0 011-1h16a1 1 0 011 1v2.586a1 1 0 01-.293.707l-6.414 6.414a1 1 0 00-.293.707V17l-4 4v-6.586a1 1 0 00-.293-.707L3.293 7.293A1 1 0 013 6.586V4z" />
                    </svg>
                </div>
                <select 
                    v-model="statusFilter" 
                    @change="handleStatusFilter"
                    class="w-full appearance-none bg-white border border-gray-200 text-gray-700 py-2 pl-10 pr-8 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 shadow-sm cursor-pointer"
                >
                    <option value="">All Status</option>
                    <option v-for="opt in statusOptions" :key="opt" :value="opt">
                        {{ formatStatus(opt) }}
                    </option>
                </select>
                <div class="pointer-events-none absolute inset-y-0 right-0 flex items-center px-2 text-gray-500">
                    <svg class="fill-current h-4 w-4" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20"><path d="M9.293 12.95l.707.707L15.657 8l-1.414-1.414L10 10.828 5.757 6.586 4.343 8z"/></svg>
                </div>
            </div>

            <ExportButton endpoint="/operations/exams/export/" filename="exams.csv" />
            <button v-if="canManageExams" @click="openCreateModal" class="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 text-sm font-bold shadow-sm transition-colors flex items-center gap-2">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
            </svg>
            Create Exam
            </button>
        </div>
      </div>
    </div>

    <div class="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
      <table class="min-w-full divide-y divide-gray-100">
        <thead class="bg-gray-50/50">
          <tr>
            <th class="px-6 py-4 text-left text-[10px] font-black uppercase tracking-widest text-gray-500">Exam Name</th>
            <th class="px-6 py-4 text-left text-[10px] font-black uppercase tracking-widest text-gray-500">Start Date</th>
            <th class="px-6 py-4 text-left text-[10px] font-black uppercase tracking-widest text-gray-500">End Date</th>
            <th class="px-6 py-4 text-left text-[10px] font-black uppercase tracking-widest text-gray-500">Client</th>
            <th class="px-6 py-4 text-left text-[10px] font-black uppercase tracking-widest text-purple-600">Admin User</th>
            <th class="px-6 py-4 text-left text-[10px] font-black uppercase tracking-widest text-purple-600">Password</th>
            <th class="px-6 py-4 text-left text-[10px] font-black uppercase tracking-widest text-gray-500">Status</th>
            <th v-if="canManageExams" class="px-6 py-4 text-left text-[10px] font-black uppercase tracking-widest text-gray-500">Actions</th>
          </tr>
        </thead>
        <tbody class="bg-white divide-y divide-gray-100">
          <tr v-for="exam in exams" :key="exam.uid" class="hover:bg-gray-50/50 transition-colors group">
            <td class="px-6 py-4 whitespace-nowrap cursor-pointer" @click="$router.push(`/operations/exams/${exam.uid}/shifts`)">
              <div class="text-sm font-bold text-gray-900 group-hover:text-blue-600 transition-colors">{{ exam.name }}</div>
              <div class="text-xs text-gray-400 font-mono mt-0.5">{{ exam.exam_code }}</div>
            </td>
            <td class="px-6 py-4 whitespace-nowrap text-xs text-gray-600 font-medium">
                {{ formatDate(exam.exam_start_date) }}
            </td>
            <td class="px-6 py-4 whitespace-nowrap text-xs text-gray-600 font-medium">
                {{ formatDate(exam.exam_end_date) }}
            </td>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{{ exam.client_name }}</td>
            <td class="px-6 py-4 whitespace-nowrap">
                <div class="flex items-center space-x-1">
                   <span class="text-xs font-mono text-purple-700 bg-purple-50 px-2 py-1 rounded border border-purple-100/50 select-all">{{ exam.admin_username || 'N/A' }}</span>
                </div>
            </td>
            <td class="px-6 py-4 whitespace-nowrap">
                <div class="flex items-center space-x-1">
                   <span class="text-xs font-mono text-purple-700 bg-purple-50 px-2 py-1 rounded border border-purple-100/50 select-all">{{ exam.admin_password || 'N/A' }}</span>
                </div>
            </td>
            <td class="px-6 py-4 whitespace-nowrap">
               <div v-if="canManageExams && !exam.is_locked">
                <select
                    @change="updateStatus(exam, $event)"
                    class="block w-full text-[10px] font-bold uppercase tracking-wide rounded-lg border-none bg-gray-50 py-1.5 pl-3 pr-8 focus:ring-2 focus:ring-blue-500 cursor-pointer"
                    :class="{
                        'text-green-700 bg-green-50': exam.status === 'LIVE',
                        'text-blue-700 bg-blue-50': exam.status === 'READY',
                        'text-orange-700 bg-orange-50': exam.status === 'CONFIGURING',
                        'text-gray-600 bg-gray-100': ['DRAFT', 'COMPLETED', 'ARCHIVED', 'CANCELLED'].includes(exam.status)
                    }"
                    :value="exam.status"
                    @click.stop
                >
                    <option v-for="opt in statusOptions" :key="opt" :value="opt">
                        {{ formatStatus(opt) }}
                    </option>
                </select>
              </div>
              <span v-else class="px-2.5 py-1 inline-flex text-[10px] font-bold uppercase tracking-wide rounded-full border border-gray-100"
                :class="{
                   'bg-gray-100 text-gray-600': exam.is_locked,
                   'bg-green-50 text-green-700': !exam.is_locked && exam.status === 'LIVE',
                   'bg-blue-50 text-blue-700': !exam.is_locked && exam.status === 'READY',
                   'bg-orange-50 text-orange-700': !exam.is_locked && exam.status === 'CONFIGURING',
                   'bg-gray-50 text-gray-600': !exam.is_locked && ['DRAFT', 'COMPLETED', 'ARCHIVED', 'CANCELLED'].includes(exam.status)
               }">
                {{ exam.is_locked ? 'COMPLETED' : formatStatus(exam.status) }}
              </span>
            </td>
            <td v-if="canManageExams" class="px-6 py-4 whitespace-nowrap text-sm font-medium">
              <div class="flex items-center gap-2">
                 <button 
                    @click="openEditModal(exam)" 
                    :disabled="exam.is_locked"
                    class="p-1.5 text-gray-400 hover:text-blue-600 hover:bg-blue-50 rounded-lg transition-all disabled:opacity-30 disabled:cursor-not-allowed disabled:hover:bg-transparent disabled:hover:text-gray-400" 
                    title="Edit"
                 >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                    </svg>
                 </button>
                 <button 
                    @click="deleteExam(exam.uid)" 
                    :disabled="exam.is_locked"
                    class="p-1.5 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-all disabled:opacity-30 disabled:cursor-not-allowed disabled:hover:bg-transparent disabled:hover:text-gray-400" 
                    title="Delete"
                 >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                    </svg>
                 </button>
              </div>
            </td>
          </tr>
          <tr v-if="loading && exams.length === 0">
              <td colspan="6" class="px-6 py-20 text-center text-gray-400">
                  <div class="flex flex-col items-center justify-center">
                    <svg class="animate-spin h-6 w-6 text-blue-500 mb-2" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>
                    <span class="text-sm font-medium">Loading exams...</span>
                  </div>
              </td>
          </tr>
          <tr v-else-if="exams.length === 0">
              <td colspan="6" class="px-6 py-20 text-center">
                  <div class="flex flex-col items-center justify-center text-gray-400">
                      <svg xmlns="http://www.w3.org/2000/svg" class="h-10 w-10 mb-3 text-gray-200" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 0 002 2h2a2 0 002-2M9 5a2 0 012-2h2a2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01" />
                      </svg>
                      <p class="text-sm font-medium text-gray-500">No exams found</p>
                      <p class="text-xs mt-1">Try adjusting your search or create a new exam.</p>
                  </div>
              </td>
          </tr>
        </tbody>
      </table>
      
      <!-- Pagination Footer -->
      <div class="bg-gray-50 px-6 py-4 border-t border-gray-100 flex items-center justify-between" v-if="totalExams > 0">
          <div class="flex items-center gap-4">
              <div class="text-xs text-gray-500 font-medium">
                  Showing <span class="text-gray-900 font-bold">{{ showingStart }}</span> to <span class="text-gray-900 font-bold">{{ showingEnd }}</span> of <span class="text-gray-900 font-bold">{{ totalExams }}</span> results
              </div>
              <div class="flex items-center gap-2">
                  <span class="text-xs text-gray-500">Rows per page:</span>
                  <select v-model="pageSize" @change="loadExams(1)" class="bg-white border border-gray-200 text-gray-700 text-xs rounded-lg focus:ring-blue-500 focus:border-blue-500 py-1 px-2">
                      <option :value="10">10</option>
                      <option :value="25">25</option>
                      <option :value="50">50</option>
                      <option :value="300">300</option>
                  </select>
              </div>
          </div>
          <div class="flex gap-2">
              <button 
                  @click="prevPage" 
                  :disabled="currentPage === 1"
                  class="px-3 py-1.5 border border-gray-200 rounded-lg text-xs font-bold text-gray-600 bg-white hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed transition-all shadow-sm"
              >
                  Previous
              </button>
              <button 
                  @click="nextPage" 
                  :disabled="currentPage * pageSize >= totalExams"
                  class="px-3 py-1.5 border border-gray-200 rounded-lg text-xs font-bold text-gray-600 bg-white hover:bg-gray-50 disabled:opacity-50 disabled:cursor-not-allowed transition-all shadow-sm"
              >
                  Next
              </button>
          </div>
      </div>
    </div>
    
    <CreateExamModal :isOpen="isCreateModalOpen" :examData="editingExam" @close="closeCreateModal" @success="handleExamCreated" />
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue';
import api from '../../api/axios';
import { useAuthStore } from '../../stores/auth';
import CreateExamModal from './CreateExamModal.vue';
import ExportButton from '../../components/ExportButton.vue';

const exams = ref([]);
const isCreateModalOpen = ref(false);
const editingExam = ref(null);

const authStore = useAuthStore();
const canManageExams = computed(() => authStore.user?.user_type !== 'CLIENT_ADMIN');

const openCreateModal = () => {
    if (!canManageExams.value) return;
    editingExam.value = null;
    isCreateModalOpen.value = true;
};

const openEditModal = (exam) => {
    if (!canManageExams.value) return;
    editingExam.value = exam; 
    isCreateModalOpen.value = true;
};

const closeCreateModal = () => {
    isCreateModalOpen.value = false;
    editingExam.value = null;
};

const deleteExam = async (uid) => {
    if (!canManageExams.value) return;
    if(!confirm("Are you sure you want to delete this exam? This action cannot be undone.")) return;
    try {
        await api.delete(`/operations/exams/${uid}/`);
        await loadExams();
    } catch(e) {
        console.error("Failed to delete exam", e);
        alert("Failed to delete exam.");
    }
};

const handleExamCreated = async () => {
    closeCreateModal();
    await loadExams();
};

const searchQuery = ref('');
const statusFilter = ref('');
const currentPage = ref(1);
const pageSize = ref(10);
const totalExams = ref(0);
const loading = ref(false);

const loadExams = async (page = 1) => {
    loading.value = true;
    try {
        let url = `/operations/exams/?page=${page}&page_size=${pageSize.value}&search=${searchQuery.value}`;
        if (statusFilter.value) {
            url += `&status=${statusFilter.value}`;
        }
        const res = await api.get(url);
        exams.value = res.data.results || [];
        totalExams.value = res.data.count || 0;
        currentPage.value = page;
    } catch (e) {
        console.error("Failed to load exams", e);
        exams.value = [];
        totalExams.value = 0;
    } finally {
        loading.value = false;
    }
};

let searchTimeout;
const handleSearch = () => {
    clearTimeout(searchTimeout);
    searchTimeout = setTimeout(() => {
        loadExams(1);
    }, 300);
};

const handleStatusFilter = () => {
    loadExams(1);
};

const nextPage = () => {
    if (currentPage.value * pageSize.value < totalExams.value) {
        loadExams(currentPage.value + 1);
    }
};

const prevPage = () => {
    if (currentPage.value > 1) {
        loadExams(currentPage.value - 1);
    }
};

const showingStart = computed(() => totalExams.value === 0 ? 0 : (currentPage.value - 1) * pageSize.value + 1);
const showingEnd = computed(() => Math.min(currentPage.value * pageSize.value, totalExams.value));


const statusOptions = [
    'DRAFT', 'CONFIGURING', 'READY', 'LIVE', 'COMPLETED', 'CANCELLED', 'ARCHIVED'
];

const updateStatus = async (exam, event) => {
    const newStatus = event.target.value;
    const oldStatus = exam.status;
    
    // Immediate UI feedback
    exam.status = newStatus;

    try {
        await api.patch(`/operations/exams/${exam.uid}/`, { status: newStatus });
    } catch (e) {
        console.error("Failed to update status", e);
        alert("Failed to update status.");
        exam.status = oldStatus; // Revert on failure
        event.target.value = oldStatus;
    }
};

const formatStatus = (status) => {
    return status ? status.toLowerCase().replace('_', ' ').replace(/\b\w/g, l => l.toUpperCase()) : '';
};

const formatDate = (dateString) => {
    if (!dateString) return '-';
    return new Date(dateString).toLocaleDateString(undefined, {
        day: '2-digit',
        month: 'short',
        year: 'numeric'
    });
};

onMounted(loadExams);
</script>
