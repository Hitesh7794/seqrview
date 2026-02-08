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
            class="flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white rounded-xl text-sm font-bold hover:bg-indigo-700 transition-all shadow-sm"
        >
            <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
            </svg>
            Add Shift
        </button>
      </div>
    </div>

    <!-- Shifts List -->
    <div class="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
        <div v-if="loading" class="p-8 text-center text-gray-500 animate-pulse">
            Loading shifts...
        </div>
        <table v-else class="min-w-full divide-y divide-gray-100">
            <thead class="bg-gray-50/50">
                <tr>
                    <th class="px-6 py-4 text-left text-[10px] font-black uppercase tracking-widest text-gray-500">Shift Name</th>
                    <th class="px-6 py-4 text-left text-[10px] font-black uppercase tracking-widest text-gray-500">Date</th>
                    <th class="px-6 py-4 text-left text-[10px] font-black uppercase tracking-widest text-gray-500">Time</th>
                    <th class="px-6 py-4 text-left text-[10px] font-black uppercase tracking-widest text-gray-500">Centers</th>
                    <th class="px-6 py-4 text-right text-[10px] font-black uppercase tracking-widest text-gray-500">Actions</th>
                </tr>
            </thead>
            <tbody class="divide-y divide-gray-100 bg-white">
                <tr v-for="shift in shifts" :key="shift.uid" class="hover:bg-indigo-50/20 transition-colors group">
                    <td class="px-6 py-4">
                        <div class="font-bold text-gray-900">{{ shift.name }}</div>
                    </td>
                     <td class="px-6 py-4 text-sm text-gray-700">
                        {{ new Date(shift.work_date).toLocaleDateString() }}
                    </td>
                     <td class="px-6 py-4 text-sm text-gray-700 font-mono">
                        {{ shift.start_time }} - {{ shift.end_time }}
                    </td>
                    <td class="px-6 py-4">
                        <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                           {{ shift.centers_count || 0 }} Centers
                        </span>
                    </td>
                    <td class="px-6 py-4 text-right">
                         <button 
                            @click="$router.push(`/operations/shifts/${shift.uid}/centers`)"
                            class="text-indigo-600 hover:text-indigo-800 text-sm font-bold mr-4"
                        >
                            Manage Centers
                        </button>
                        <button 
                            @click="deleteShift(shift)"
                            class="text-red-500 hover:text-red-700 text-sm font-bold"
                        >
                            Delete
                        </button>
                    </td>
                </tr>
                <tr v-if="shifts.length === 0">
                    <td colspan="5" class="px-6 py-12 text-center text-gray-400 italic">
                        No shifts configured for this exam.
                    </td>
                </tr>
            </tbody>
        </table>
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
                <input v-model="form.work_date" type="date" required class="w-full px-4 py-2 bg-gray-50 border-none rounded-xl text-sm focus:ring-2 focus:ring-indigo-500">
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
