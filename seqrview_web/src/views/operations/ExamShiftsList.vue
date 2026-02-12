<template>
  <div class="space-y-6">
    <!-- Header -->
    <div class="flex items-center justify-between bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
      <div class="flex items-center gap-4">
        <button @click="$router.back()" class="text-gray-400 hover:text-gray-600 transition-colors">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
            </svg>
        </button>
        <div>
            <h1 class="text-2xl font-black text-gray-900 tracking-tight" v-if="exam">{{ exam.name }} - Shifts</h1>
            <div v-else class="h-8 w-48 bg-gray-200 rounded animate-pulse"></div>
            <p class="text-sm text-gray-500 mt-1">Manage exam shifts and timings.</p>
        </div>
      </div>
      
      <div class="flex gap-2">
        <ExportButton 
            endpoint="/operations/shifts/export/" 
            filename="shifts.csv"
            :filters="{ exam: examUid }"
        />
        <button 
            @click="openModal()"
            :disabled="exam?.is_locked"
            class="flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white rounded-xl text-sm font-bold hover:bg-indigo-700 transition-all shadow-sm disabled:opacity-50 disabled:cursor-not-allowed"
        >
            <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
            </svg>
            Add Shift
        </button>
      </div>
    </div>

    <!-- Shifts List -->
    <div v-if="loading" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <div v-for="n in 3" :key="n" class="bg-white rounded-2xl p-6 shadow-sm border border-gray-100 animate-pulse h-48"></div>
    </div>
    
    <div v-else-if="shifts.length === 0" class="bg-white rounded-2xl p-12 text-center shadow-sm border border-gray-100">
        <div class="inline-flex items-center justify-center w-16 h-16 rounded-full bg-indigo-50 mb-4">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-8 w-8 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
        </div>
        <h3 class="text-lg font-bold text-gray-900 mb-1">No Shifts Configured</h3>
        <p class="text-gray-500 mb-6">Create the first shift to get started.</p>
        <button 
            @click="openModal()"
            :disabled="exam?.is_locked"
            class="px-4 py-2 bg-indigo-600 text-white rounded-xl text-sm font-bold hover:bg-indigo-700 transition-all shadow-sm disabled:opacity-50 disabled:cursor-not-allowed"
        >
            Add Shift
        </button>
    </div>

    <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <div v-for="shift in shifts" :key="shift.uid" class="bg-white rounded-2xl p-6 shadow-sm border border-gray-100 hover:shadow-md transition-shadow group relative overflow-hidden">
            <div class="absolute top-0 right-0 w-24 h-24 bg-indigo-50 rounded-bl-full -mr-12 -mt-12 transition-transform group-hover:scale-110"></div>
            
            <div class="relative z-10">
                <div class="flex justify-between items-start mb-4">
                    <div>
                         <h3 class="text-lg font-black text-gray-900 line-clamp-1" :title="shift.name">{{ shift.name }}</h3>
                        <p class="text-xs font-bold text-gray-400 uppercase tracking-wider mt-1">
                            {{ shift.shift_code || 'No Code' }}
                            <span v-if="shift.is_locked" class="ml-2 px-1.5 py-0.5 rounded text-[10px] bg-red-100 text-red-700">LOCKED</span>
                        </p>
                    </div>
                     <span class="inline-flex items-center justify-center w-8 h-8 rounded-full bg-indigo-100 text-indigo-700 font-bold text-xs" title="Centers Count">
                        {{ shift.centers_count || 0 }}
                    </span>
                </div>
                
                <div class="space-y-3 mb-6">
                    <div class="flex items-center text-sm text-gray-600">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 mr-2 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                        </svg>
                        <span class="font-medium">{{ new Date(shift.work_date).toLocaleDateString(undefined, { weekday: 'short', year: 'numeric', month: 'short', day: 'numeric' }) }}</span>
                    </div>
                    <div class="flex items-center text-sm text-gray-600">
                         <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 mr-2 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                        </svg>
                        <span class="font-mono bg-gray-50 px-2 py-0.5 rounded text-xs">{{ shift.start_time }} - {{ shift.end_time }}</span>
                    </div>
                </div>

                <div class="flex items-center gap-2 pt-4 border-t border-gray-100">
                    <button 
                        @click="$router.push(`/operations/shifts/${shift.uid}/centers`)"
                        class="flex-1 py-2 px-3 bg-indigo-50 text-indigo-700 rounded-lg text-sm font-bold hover:bg-indigo-100 transition-colors text-center"
                    >
                        Manage Centers
                    </button>
                    <button 
                        @click="deleteShift(shift)"
                        :disabled="shift.is_locked || exam?.is_locked"
                        class="p-2 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors disabled:opacity-30 disabled:cursor-not-allowed disabled:hover:bg-transparent disabled:hover:text-gray-400"
                        title="Delete Shift"
                    >
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                        </svg>
                    </button>
                </div>
            </div>
        </div>
    </div>

    <!-- Create Shift Modal -->
    <BaseModal :isOpen="isModalOpen" title="Add Shift" @close="closeModal">
        <form @submit.prevent="saveShift" class="space-y-4">
            <div>
                <label class="block text-xs font-black text-gray-400 uppercase tracking-widest mb-1">Shift Name</label>
                <input v-model="form.name" type="text" required class="w-full px-4 py-2 bg-gray-50 border-none rounded-xl text-sm focus:ring-2 focus:ring-indigo-500" placeholder="e.g. Morning Shift">
            </div>
            <div>
                <label class="block text-xs font-black text-gray-400 uppercase tracking-widest mb-1">Shift Code</label>
                <input v-model="form.shift_code" type="text" required class="w-full px-4 py-2 bg-gray-50 border-none rounded-xl text-sm focus:ring-2 focus:ring-indigo-500" placeholder="e.g. S1">
            </div>
             <div>
                <label class="block text-xs font-black text-gray-400 uppercase tracking-widest mb-1">Date</label>
                <input 
                    v-model="form.work_date" 
                    type="date" 
                    required 
                    :min="exam?.exam_start_date" 
                    :max="exam?.exam_end_date"
                    class="w-full px-4 py-2 bg-gray-50 border-none rounded-xl text-sm focus:ring-2 focus:ring-indigo-500"
                >
            </div>
             <div class="grid grid-cols-2 gap-4">
                <div>
                    <label class="block text-xs font-black text-gray-400 uppercase tracking-widest mb-1">Start Time</label>
                    <input v-model="form.start_time" type="time" required class="w-full px-4 py-2 bg-gray-50 border-none rounded-xl text-sm focus:ring-2 focus:ring-indigo-500">
                </div>
                <div>
                    <label class="block text-xs font-black text-gray-400 uppercase tracking-widest mb-1">End Time</label>
                    <input v-model="form.end_time" type="time" required class="w-full px-4 py-2 bg-gray-50 border-none rounded-xl text-sm focus:ring-2 focus:ring-indigo-500">
                </div>
            </div>

            <div v-if="error" class="p-3 bg-red-50 text-red-600 text-xs rounded-lg border border-red-100">
                {{ error }}
            </div>

            <div class="flex justify-end gap-3 pt-4">
                <button type="button" @click="closeModal" class="px-4 py-2 text-gray-500 text-sm font-bold hover:bg-gray-100 rounded-lg transition-colors">Cancel</button>
                <button type="submit" :disabled="saving" class="px-6 py-2 bg-indigo-600 text-white text-sm font-bold rounded-lg hover:bg-indigo-700 transition-colors disabled:opacity-50">
                    {{ saving ? 'Saving...' : 'Add Shift' }}
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
import ExportButton from '../../components/ExportButton.vue';

const route = useRoute();
const examUid = route.params.examId;

const exam = ref(null);
const shifts = ref([]);
const loading = ref(false);
const isModalOpen = ref(false);
const saving = ref(false);
const error = ref('');

const form = ref({
    name: '',
    shift_code: '',
    work_date: '',
    start_time: '',
    end_time: '',
    exam: examUid
});

const loadData = async () => {
    loading.value = true;
    try {
        const [examRes, shiftsRes] = await Promise.all([
            api.get(`/operations/exams/${examUid}/`),
            api.get(`/operations/shifts/?exam=${examUid}`)
        ]);
        exam.value = examRes.data;
        shifts.value = shiftsRes.data.results || shiftsRes.data;
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
        shift_code: '',
        work_date: '',
        start_time: '',
        end_time: '',
        exam: examUid
    };
    isModalOpen.value = true;
};

const closeModal = () => {
    isModalOpen.value = false;
};

const saveShift = async () => {
    if (form.value.end_time <= form.value.start_time) {
        error.value = "End time must be after start time";
        return;
    }

    if (exam.value) {
        if (exam.value.exam_start_date && form.value.work_date < exam.value.exam_start_date) {
             error.value = `Date cannot be before Exam Start Date (${exam.value.exam_start_date})`;
             return;
        }
        if (exam.value.exam_end_date && form.value.work_date > exam.value.exam_end_date) {
             error.value = `Date cannot be after Exam End Date (${exam.value.exam_end_date})`;
             return;
        }
    }

    saving.value = true;
    error.value = '';
    try {
        await api.post('/operations/shifts/', form.value);
        await loadData();
        closeModal();
    } catch (e) {
        error.value = e.response?.data?.detail || "Failed to create shift. Ensure code is unique.";
    } finally {
        saving.value = false;
    }
};

const deleteShift = async (shift) => {
    if (!confirm(`Are you sure you want to delete '${shift.name}'?`)) return;
    try {
        await api.delete(`/operations/shifts/${shift.uid}/`);
        await loadData();
    } catch (e) {
        alert("Failed to delete shift.");
    }
};

onMounted(loadData);
</script>
