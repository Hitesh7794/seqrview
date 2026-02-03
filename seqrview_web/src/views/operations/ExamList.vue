<template>
  <div>
    <div class="flex justify-between items-center mb-6">
      <h1 class="text-2xl font-bold text-gray-800">Exams</h1>
      <button v-if="canManageExams" @click="openCreateModal" class="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700">
        + Create Exam
      </button>
    </div>

    <div class="bg-white rounded-lg shadow overflow-hidden">
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Exam Name</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Client</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider text-purple-600">Admin User</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider text-purple-600">Password</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
            <th v-if="canManageExams" class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
          </tr>
        </thead>
        <tbody class="bg-white divide-y divide-gray-200">
          <tr v-for="exam in exams" :key="exam.uid">
            <td class="px-6 py-4 whitespace-nowrap">
              <div class="text-sm font-medium text-gray-900">{{ exam.name }}</div>
              <div class="text-xs text-gray-500">{{ exam.exam_code }}</div>
            </td>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{{ exam.client_name }}</td>
            <td class="px-6 py-4 whitespace-nowrap">
                <div class="flex items-center space-x-1">
                   <span class="text-sm font-mono text-indigo-600 bg-indigo-50 px-2 py-0.5 rounded border border-indigo-100">{{ exam.admin_username || 'N/A' }}</span>
                </div>
            </td>
            <td class="px-6 py-4 whitespace-nowrap">
                <div class="flex items-center space-x-1">
                   <span class="text-sm font-mono text-purple-600 bg-purple-50 px-2 py-0.5 rounded border border-purple-100">{{ exam.admin_password || 'N/A' }}</span>
                </div>
            </td>
            <td class="px-6 py-4 whitespace-nowrap">
              <span class="px-2.5 py-1 inline-flex text-xs leading-5 font-semibold rounded-full border"
                :class="{
                   'bg-green-100 text-green-700 border-green-200': exam.status === 'LIVE',
                   'bg-blue-100 text-blue-700 border-blue-200': exam.status === 'READY',
                   'bg-orange-100 text-orange-700 border-orange-200': exam.status === 'CONFIGURING',
                   'bg-gray-100 text-gray-600 border-gray-200': exam.status === 'DRAFT' || exam.status === 'COMPLETED' || exam.status === 'ARCHIVED'
               }">
                {{ formatStatus(exam.status) }}
              </span>
            </td>
            <td v-if="canManageExams" class="px-6 py-4 whitespace-nowrap text-sm font-medium">
              <div class="flex items-center space-x-3">
                 <button @click="openEditModal(exam)" class="text-indigo-600 hover:text-indigo-900 transition-colors" title="Edit">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
                    </svg>
                 </button>
                 <button @click="$router.push(`/operations/exams/${exam.exam_code}/shifts`)" class="text-gray-500 hover:text-blue-600 transition-colors" title="Manage Shifts">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                    </svg>
                 </button>
                 <button @click="deleteExam(exam.uid)" class="text-red-600 hover:text-red-900 transition-colors" title="Delete">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                    </svg>
                 </button>
              </div>
            </td>
          </tr>
          <tr v-if="loading">
              <td colspan="6" class="px-6 py-12 text-center text-blue-500 font-medium">Loading exams data...</td>
          </tr>
          <tr v-else-if="exams.length === 0">
              <td colspan="6" class="px-6 py-12 text-center text-gray-500">No exams found.</td>
          </tr>
        </tbody>
      </table>
    </div>
    
    <CreateExamModal :isOpen="isCreateModalOpen" :examData="editingExam" @close="closeCreateModal" @success="handleExamCreated" />
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue';
import api from '../../api/axios';
import { useAuthStore } from '../../stores/auth';
import CreateExamModal from './CreateExamModal.vue';

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

const loading = ref(false);

const loadExams = async () => {
    loading.value = true;
    try {
        const res = await api.get('/operations/exams/');
        exams.value = res.data.results || res.data;
    } catch (e) {
        console.error("Failed to load exams", e);
    } finally {
        loading.value = false;
    }
};


const formatStatus = (status) => {
    return status ? status.toLowerCase().replace('_', ' ').replace(/\b\w/g, l => l.toUpperCase()) : '';
};

onMounted(loadExams);
</script>
