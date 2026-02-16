<template>
  <BaseModal :isOpen="visible" :title="`Bulk Task Configuration - ${shiftName || 'Shift'}`" @close="$emit('close')" size="3xl" :showCancel="false">
    <div class="space-y-6">
      
      <div class="bg-indigo-50 p-4 rounded-xl border border-indigo-100 mb-4">
        <p class="text-[11px] text-indigo-800">
            <strong>Note:</strong> Set tasks for either <strong>ALL centers</strong> or a <strong>specific subset</strong> via CSV.
        </p>
      </div>

      <form @submit.prevent="submitBulkConfig" class="space-y-6">
        
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <!-- 1. Select Role -->
            <div>
               <label class="block text-[9px] font-black text-gray-400 uppercase tracking-widest mb-2">1. Target Role <span class="text-red-500">*</span></label>
               <select v-model="selectedRole" required class="w-full rounded-xl border-gray-200 text-xs focus:ring-indigo-500 focus:border-indigo-500 bg-gray-50/50">
                 <option value="" disabled>Select Role</option>
                 <option v-for="role in roles" :key="role.uid" :value="role.uid">{{ role.name }}</option>
               </select>
            </div>

            <!-- 2. Target Scope (CSV) -->
            <div>
                 <div class="flex items-center justify-between mb-2">
                    <label class="block text-[9px] font-black text-gray-400 uppercase tracking-widest">2. Center Scope (Optional CSV)</label>
                    <button type="button" @click="downloadTemplate" class="text-[8px] font-bold text-indigo-600 hover:text-indigo-800 flex items-center gap-1">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-3 w-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a2 2 0 002 2h12a2 2 0 002-2v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                        </svg>
                        Download Template
                    </button>
                 </div>
                 <div class="flex items-center gap-2">
                     <div class="relative flex-1">
                        <input 
                            type="file" 
                            ref="csvInput"
                            accept=".csv"
                            @change="handleCsvChange"
                            class="hidden"
                            id="scope-csv"
                        >
                        <label for="scope-csv" class="flex items-center justify-between px-3 py-1.5 bg-gray-50 border border-gray-200 rounded-lg text-[11px] cursor-pointer hover:bg-gray-100 transition-colors">
                            <span class="text-gray-500 truncate">{{ selectedCsvName || 'All Centers (Default)' }}</span>
                            <svg xmlns="http://www.w3.org/2000/svg" class="h-3.5 w-3.5 text-indigo-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a2 2 0 002 2h12a2 2 0 002-2v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                            </svg>
                        </label>
                     </div>
                     <button v-if="selectedCsvFile" @click="clearCsv" type="button" class="p-1.5 text-red-500 hover:bg-red-50 rounded-lg">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                        </svg>
                     </button>
                 </div>
                 <p class="text-[8px] text-gray-400 mt-1 italic">Upload CSV with 'center_code' to target specific centers.</p>
            </div>
        </div>

        <!-- 3. Configure Tasks -->
        <div>
            <div class="flex items-center justify-between mb-3">
                <label class="block text-[9px] font-black text-gray-400 uppercase tracking-widest font-bold">3. Tasks Configuration</label>
                <div class="flex gap-2">
                    <!-- Task Library Dropdown -->
                    <div class="relative inline-block text-left">
                        <button type="button" @click="showLibrary = !showLibrary" class="text-[10px] font-bold text-indigo-600 bg-indigo-50 px-3 py-1.5 rounded-lg hover:bg-indigo-100 flex items-center gap-1 transition-all border border-indigo-100">
                             <svg xmlns="http://www.w3.org/2000/svg" class="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" />
                            </svg>
                            Fetch from Library
                        </button>
                        
                        <!-- Library List Overlay -->
                        <div v-if="showLibrary" class="absolute right-0 mt-2 w-64 bg-white rounded-2xl shadow-xl border border-gray-100 z-50 py-2 max-h-64 overflow-y-auto overflow-x-hidden">
                             <div class="px-3 pb-1.5 border-b border-gray-50 mb-1">
                                <input v-model="libSearch" type="text" placeholder="Search tasks..." class="w-full text-xs border-none bg-gray-50 rounded-lg p-2 focus:ring-0">
                             </div>
                             <div v-for="lib in filteredLibrary" :key="lib.uid" @click="addFromLibrary(lib)" class="px-4 py-2 hover:bg-indigo-50 cursor-pointer transition-colors border-b border-gray-50 last:border-0 group">
                                <div class="font-bold text-[11px] text-gray-900 group-hover:text-indigo-600 text-left">{{ lib.name }}</div>
                                <div class="text-[8px] text-gray-400 uppercase tracking-widest mt-0.5 text-left">{{ lib.task_type }}</div>
                             </div>
                             <div v-if="filteredLibrary.length === 0" class="px-4 py-4 text-center text-gray-400 text-xs italic">
                                No matching tasks.
                             </div>
                        </div>
                    </div>

                    <button type="button" @click="addTaskRow" class="text-[10px] font-bold text-gray-600 bg-gray-100 px-3 py-1.5 rounded-lg hover:bg-gray-200 flex items-center gap-1 transition-all border border-gray-200">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
                        </svg>
                        Add Row
                    </button>
                </div>
            </div>
            
            <div class="space-y-3 max-h-[400px] overflow-y-auto pr-1">
                <div v-for="(task, index) in tasks" :key="index" class="flex items-start gap-3 p-4 bg-white rounded-2xl border border-gray-100 shadow-sm hover:border-indigo-100 transition-all relative group">
                    <div class="flex-1">
                         <div class="flex gap-2 items-center mb-2">
                            <input 
                                v-model="task.task_name" 
                                type="text" 
                                required
                                placeholder="Task Name (e.g. Verify ID)"
                                class="flex-1 rounded-xl border-gray-100 text-xs focus:ring-indigo-500 focus:border-indigo-500 bg-gray-50/30 py-1.5"
                            >
                            <span class="text-[9px] font-black text-gray-300">#{{ index + 1 }}</span>
                         </div>
                        <div class="flex gap-3">
                             <div class="w-1/2 text-left">
                                <label class="block text-[8px] font-bold text-gray-400 uppercase tracking-widest mb-1 ml-1">Type</label>
                                <select v-model="task.task_type" class="w-full rounded-lg border-gray-100 text-[10px] focus:ring-indigo-500 focus:border-indigo-500 py-1 bg-gray-50/30">
                                    <option value="CHECKLIST">Checklist</option>
                                    <option value="PHOTO">Photo</option>
                                    <option value="VIDEO">Video</option>
                                </select>
                             </div>
                             <div class="w-1/2 text-left">
                                <label class="block text-[8px] font-bold text-gray-400 uppercase tracking-widest mb-1 ml-1">Requirement</label>
                                <div class="flex items-center gap-2 h-[28px] px-3 bg-gray-50/30 rounded-lg border border-gray-100">
                                    <input :id="`mandatory-${index}`" v-model="task.is_mandatory" type="checkbox" class="rounded border-gray-300 text-indigo-600 focus:ring-indigo-500 h-3.5 w-3.5">
                                    <label :for="`mandatory-${index}`" class="text-[10px] text-gray-600 font-bold cursor-pointer">Mandatory</label>
                                </div>
                             </div>
                        </div>
                    </div>
                    
                    <button 
                        type="button"
                        @click="removeTaskRow(index)"
                        class="text-gray-300 hover:text-red-500 p-2 rounded-xl hover:bg-red-50 transition-all mt-1 opacity-0 group-hover:opacity-100"
                        :disabled="tasks.length === 1"
                        title="Remove"
                    >
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                        </svg>
                    </button>
                </div>
            </div>
        </div>

        <!-- Footer -->
        <div class="pt-6 border-t border-gray-100 flex justify-end items-center gap-4">
            <p v-if="selectedCsvFile" class="text-[9px] text-green-600 font-bold italic animate-pulse">
                Scope: CSV Filtered
            </p>
            <p v-else class="text-[9px] text-gray-400 font-bold italic">
                Scope: All Centers
            </p>

            <button type="button" @click="$emit('close')" class="px-4 py-2 text-gray-400 text-[10px] font-bold uppercase tracking-widest hover:bg-gray-50 rounded-lg transition-all">
                Cancel
            </button>
             <button 
                type="submit" 
                :disabled="submitting"
                class="px-6 py-2.5 bg-indigo-600 text-white text-[10px] font-bold uppercase tracking-widest rounded-xl hover:bg-indigo-700 disabled:opacity-50 transition-all shadow-lg shadow-indigo-100 flex items-center gap-2"
            >
                <div v-if="submitting" class="h-3.5 w-3.5 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
                <span>{{ submitting ? 'Configuring...' : 'Apply Config' }}</span>
            </button>
        </div>

      </form>
    </div>
  </BaseModal>
</template>

<script setup>
import { ref, watch, onMounted, computed } from 'vue';
import BaseModal from './BaseModal.vue';
import api from '../api/axios';

const props = defineProps({
    visible: Boolean,
    shiftId: String,
    shiftName: String
});

const emit = defineEmits(['close', 'success']);

const roles = ref([]);
const library = ref([]);
const selectedRole = ref('');
const tasks = ref([{ task_name: '', task_type: 'CHECKLIST', is_mandatory: true }]);
const submitting = ref(false);

const showLibrary = ref(false);
const libSearch = ref('');

const selectedCsvFile = ref(null);
const selectedCsvName = ref('');
const csvInput = ref(null);

const loadMasters = async () => {
    try {
        const [rolesRes, libRes] = await Promise.all([
            api.get('/masters/roles/'),
            api.get('/masters/task-library/')
        ]);
        roles.value = rolesRes.data.results || rolesRes.data;
        library.value = libRes.data.results || libRes.data;
    } catch (e) {
        console.error("Failed to load masters", e);
    }
};

onMounted(() => {
    loadMasters();
});

const addTaskRow = () => {
    tasks.value.push({ task_name: '', task_type: 'CHECKLIST', is_mandatory: true });
};

const removeTaskRow = (index) => {
    if (tasks.value.length > 1) {
        tasks.value.splice(index, 1);
    }
};

const handleCsvChange = (e) => {
    const file = e.target.files[0];
    if (file) {
        selectedCsvFile.value = file;
        selectedCsvName.value = file.name;
    }
};

const clearCsv = () => {
    selectedCsvFile.value = null;
    selectedCsvName.value = '';
    if (csvInput.value) csvInput.value.value = '';
};

const downloadTemplate = async () => {
    try {
        const res = await api.get('/operations/shifts/bulk-tasks-template/', {
            responseType: 'blob'
        });
        const url = window.URL.createObjectURL(new Blob([res.data]));
        const link = document.createElement('a');
        link.href = url;
        link.setAttribute('download', 'bulk_task_centers_template.csv');
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        window.URL.revokeObjectURL(url);
    } catch (e) {
        console.error("Failed to download template", e);
        alert("Failed to download template.");
    }
};

const addFromLibrary = (lib) => {
    // Check if task with same name/type already in list
    const exists = tasks.value.find(t => t.task_name === lib.name);
    if (!exists) {
        // Replace empty row if it's the only one
        if (tasks.value.length === 1 && !tasks.value[0].task_name) {
            tasks.value[0] = { task_name: lib.name, task_type: lib.task_type, is_mandatory: true };
        } else {
            tasks.value.push({ task_name: lib.name, task_type: lib.task_type, is_mandatory: true });
        }
    }
    showLibrary.value = false;
    libSearch.value = '';
};

const filteredLibrary = computed(() => {
    if (!libSearch.value) return library.value;
    return library.value.filter(l => l.name.toLowerCase().includes(libSearch.value.toLowerCase()));
});

const submitBulkConfig = async () => {
    if (!props.shiftId || !selectedRole.value) return;
    
    // Validate tasks
    const validTasks = tasks.value.filter(t => t.task_name.trim() !== '');
    if (validTasks.length === 0) {
        alert("Please add at least one valid task.");
        return;
    }

    submitting.value = true;
    try {
        const formData = new FormData();
        formData.append('role', selectedRole.value);
        formData.append('tasks', JSON.stringify(validTasks));
        
        if (selectedCsvFile.value) {
            formData.append('file', selectedCsvFile.value);
        }
        
        const res = await api.post(`/operations/shifts/${props.shiftId}/bulk-tasks/`, formData, {
            headers: { 'Content-Type': 'multipart/form-data' }
        });
        
        emit('success', `Applied tasks to ${res.data.centers_count} centers.`);
        emit('close');
        
        // Reset
        selectedRole.value = '';
        tasks.value = [{ task_name: '', task_type: 'CHECKLIST', is_mandatory: true }];
        clearCsv();
        
    } catch (e) {
        console.error("Bulk config failed", e);
        alert(e.response?.data?.detail || "Failed to apply configuration.");
    } finally {
        submitting.value = false;
    }
};

watch(() => props.visible, (val) => {
    if (val) {
        if (tasks.value.length === 0) addTaskRow();
        showLibrary.value = false;
    }
});
</script>
