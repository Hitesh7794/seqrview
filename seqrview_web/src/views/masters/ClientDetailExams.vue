<template>
  <div class="space-y-6">
    <!-- Header -->
    <div class="flex items-center justify-between bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
      <div class="flex items-center gap-4">
        <button @click="$router.push('/masters/clients')" class="text-gray-400 hover:text-gray-600 transition-colors">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
            </svg>
        </button>
        <div>
            <h1 class="text-2xl font-black text-gray-900 tracking-tight" v-if="client">{{ client.name }} - Exams</h1>
            <div v-else class="h-8 w-48 bg-gray-200 rounded animate-pulse"></div>
            <p class="text-sm text-gray-500 mt-1">Manage exams and shifts for this client.</p>
        </div>
      </div>
      
      <button 
        @click="openModal()"
        class="flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white rounded-xl text-sm font-bold hover:bg-indigo-700 transition-all shadow-sm"
      >
        <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
        </svg>
        Create New Exam
      </button>
    </div>

    <!-- Exams Grid -->
    <div v-if="loading" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <div v-for="i in 3" :key="i" class="bg-white rounded-2xl p-6 shadow-sm border border-gray-100 h-48 animate-pulse">
            <div class="h-6 bg-gray-200 rounded w-3/4 mb-4"></div>
            <div class="h-4 bg-gray-100 rounded w-1/2 mb-2"></div>
            <div class="h-4 bg-gray-100 rounded w-1/3"></div>
        </div>
    </div>

    <div v-else-if="exams.length === 0" class="text-center py-20 bg-white rounded-2xl border border-gray-100 border-dashed">
        <div class="inline-flex items-center justify-center w-16 h-16 rounded-full bg-indigo-50 text-indigo-200 mb-4">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-8 w-8" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 0 00-2 2v12a2 0 002 2h10a2 0 002-2V7a2 0 00-2-2h-2M9 5a2 0 002 2h2a2 0 002-2M9 5a2 0 012-2h2a2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01" />
            </svg>
        </div>
        <h3 class="text-lg font-bold text-gray-900">No Exams Found</h3>
        <p class="text-gray-500 text-sm mt-1">Create an exam to start scheduling shifts.</p>
    </div>

    <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <div v-for="exam in exams" :key="exam.uid" class="contact-card group relative bg-white p-6 rounded-2xl shadow-sm border border-gray-100 hover:shadow-md transition-all">
            <div class="flex justify-between items-start mb-4">
                <div class="h-12 w-12 rounded-xl bg-gradient-to-br from-indigo-500 to-purple-600 text-white flex items-center justify-center text-xl font-bold shadow-indigo-200 shadow-lg">
                    {{ exam.name.charAt(0).toUpperCase() }}
                </div>
                <div class="flex items-center gap-2">
                     <span class="px-2 py-0.5 rounded text-[10px] font-black uppercase tracking-wider" 
                        :class="exam.is_active ? 'bg-green-50 text-green-700' : 'bg-gray-100 text-gray-500'">
                        {{ exam.is_active ? 'Active' : 'Archived' }}
                    </span>
                    <button class="text-gray-300 hover:text-gray-600 transition-colors">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                            <path d="M10 6a2 2 0 110-4 2 2 0 010 4zM10 12a2 2 0 110-4 2 2 0 010 4zM10 18a2 2 0 110-4 2 2 0 010 4z" />
                        </svg>
                    </button>
                </div>
            </div>

            <h3 class="text-lg font-bold text-gray-900 mb-1 group-hover:text-indigo-600 transition-colors">{{ exam.name }}</h3>
            <p class="text-xs text-gray-400 font-mono mb-4">{{ exam.exam_code }}</p>

            <div class="flex items-center gap-4 text-xs text-gray-500 mb-6">
                <div class="flex items-center gap-1">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                    </svg>
                    {{ new Date(exam.start_date).toLocaleDateString() }}
                </div>
                <div class="flex items-center gap-1">
                     <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                    {{  exam.shifts ? exam.shifts.length : 0 }} Shifts
                </div>
            </div>

            <button 
                @click="$router.push(`/operations/exams/${exam.uid}/shifts`)"
                class="w-full py-2.5 rounded-xl bg-gray-50 text-gray-600 text-sm font-bold hover:bg-indigo-50 hover:text-indigo-600 transition-all border border-transparent hover:border-indigo-100 flex items-center justify-center gap-2"
            >
                Manage Shifts
                <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 8l4 4m0 0l-4 4m4-4H3" />
                </svg>
            </button>
        </div>
    </div>

    <!-- Create Exam Modal -->
    <BaseModal :isOpen="isModalOpen" title="Create New Exam" @close="closeModal">
        <form @submit.prevent="saveExam" class="space-y-4">
             <div>
                <label class="block text-xs font-black text-gray-400 uppercase tracking-widest mb-1">Exam Name</label>
                <input v-model="form.name" type="text" required class="w-full px-4 py-2 bg-gray-50 border-none rounded-xl text-sm focus:ring-2 focus:ring-indigo-500" placeholder="e.g. JEE Mains 2026">
            </div>
             <div>
                <label class="block text-xs font-black text-gray-400 uppercase tracking-widest mb-1">Exam Code</label>
                <input v-model="form.exam_code" type="text" required class="w-full px-4 py-2 bg-gray-50 border-none rounded-xl text-sm focus:ring-2 focus:ring-indigo-500" placeholder="e.g. JEE-2026-PH1">
            </div>
            <div class="grid grid-cols-2 gap-4">
                <div>
                    <label class="block text-xs font-black text-gray-400 uppercase tracking-widest mb-1">Start Date</label>
                    <input v-model="form.start_date" type="date" required class="w-full px-4 py-2 bg-gray-50 border-none rounded-xl text-sm focus:ring-2 focus:ring-indigo-500">
                </div>
                <div>
                    <label class="block text-xs font-black text-gray-400 uppercase tracking-widest mb-1">End Date</label>
                    <input v-model="form.end_date" type="date" required class="w-full px-4 py-2 bg-gray-50 border-none rounded-xl text-sm focus:ring-2 focus:ring-indigo-500">
                </div>
            </div>

             <div v-if="error" class="p-3 bg-red-50 text-red-600 text-xs rounded-lg border border-red-100">
                {{ error }}
            </div>

            <div class="flex justify-end gap-3 pt-4">
                <button type="button" @click="closeModal" class="px-4 py-2 text-gray-500 text-sm font-bold hover:bg-gray-100 rounded-lg transition-colors">Cancel</button>
                <button type="submit" :disabled="saving" class="px-6 py-2 bg-indigo-600 text-white text-sm font-bold rounded-lg hover:bg-indigo-700 transition-colors disabled:opacity-50">
                    {{ saving ? 'Creating...' : 'Create Exam' }}
                </button>
            </div>
        </form>
    </BaseModal>

  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import api from '../../api/axios';
import BaseModal from '../../components/BaseModal.vue';

const route = useRoute();
const clientUid = route.params.uid;

const client = ref(null);
const exams = ref([]);
const loading = ref(false);
const isModalOpen = ref(false);
const saving = ref(false);
const error = ref('');

const form = ref({
    name: '',
    exam_code: '',
    start_date: '',
    end_date: '',
    client: clientUid
});

const loadData = async () => {
    loading.value = true;
    try {
        const [clientRes, examsRes] = await Promise.all([
            api.get(`/masters/clients/${clientUid}/`),
            api.get(`/operations/exams/?client=${clientUid}`)
        ]);
        client.value = clientRes.data;
        exams.value = examsRes.data.results || examsRes.data;
    } catch (e) {
        console.error("Failed to load data", e);
    } finally {
        loading.value = false;
    }
};

const openModal = () => {
    error.value = '';
    form.value = {
        name: '',
        exam_code: '',
        start_date: '',
        end_date: '',
        client: clientUid
    };
    isModalOpen.value = true;
};

const closeModal = () => {
    isModalOpen.value = false;
};

const saveExam = async () => {
    saving.value = true;
    error.value = '';
    try {
        await api.post('/operations/exams/', form.value);
        await loadData();
        closeModal();
    } catch (e) {
        error.value = e.response?.data?.detail || "Failed to create exam.";
    } finally {
        saving.value = false;
    }
};

onMounted(loadData);
</script>
