<template>
  <div class="space-y-6">
    <!-- Header -->
    <div class="bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
        <div class="flex items-center gap-4 mb-4">
             <button @click="$router.back()" class="text-gray-400 hover:text-gray-600 transition-colors">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
                </svg>
            </button>
            <div>
                <h1 class="text-2xl font-black text-center text-gray-900 tracking-tight" v-if="shiftCenter">
                    {{ shiftCenter.exam_center_details.client_center_name }} <span class="text-gray-400 font-normal text-lg">({{ shiftCenter.exam_center_details.client_center_code }})</span>
                </h1>
                <div v-else class="h-8 w-64 bg-gray-200 rounded animate-pulse"></div>
                <p class="text-sm text-gray-500 mt-1" v-if="shiftCenter">
                    Shift: {{ shiftCenter.shift_details.name }} ({{ shiftCenter.shift_details.start_time }} - {{ shiftCenter.shift_details.end_time }})
                    <span v-if="shiftCenter.shift_details.is_locked" class="ml-2 px-2 py-0.5 rounded text-[10px] font-black uppercase tracking-wider bg-red-100 text-red-700">
                        LOCKED
                    </span>
                </p>
            </div>
        </div>
        
        <div class="flex justify-between items-center pt-4 border-t border-gray-100">
             <div class="relative">
                <input 
                    v-model="search" 
                    type="text" 
                    placeholder="Search operators..." 
                    class="pl-10 pr-4 py-2 bg-gray-50 border-none rounded-xl text-sm focus:ring-2 focus:ring-indigo-500 w-64"
                >
                <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 absolute left-3 top-2.5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                </svg>
            </div>
            <div class="flex items-center gap-3">
                 <ExportButton 
                    endpoint="/assignments/operator-assignments/export/" 
                    filename="assignments.csv"
                    :filters="{ shift_center: shiftCenterUid }"
                />
                <button 
                    v-if="canManage"
                    @click="openImportModal"
                    :disabled="shiftCenter?.shift_details?.is_locked"
                    class="flex items-center gap-2 px-4 py-2 bg-white text-indigo-600 rounded-xl text-sm font-bold border border-indigo-200 hover:bg-indigo-50 transition-all shadow-sm disabled:opacity-50 disabled:cursor-not-allowed"
                >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a2 2 0 002 2h12a2 2 0 002-2v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                    </svg>
                    Bulk Assign
                </button>
                <button 
                    v-if="canManage"
                    @click="openAddOperatorModal"
                    :disabled="shiftCenter?.shift_details?.is_locked"
                    class="flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white rounded-xl text-sm font-bold hover:bg-indigo-700 transition-all shadow-sm disabled:opacity-50 disabled:cursor-not-allowed"
                >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
                    </svg>
                    Assign Operator
                </button>
            </div>
        </div>
    </div>

    <!-- Assignments List -->
    <div class="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
        <table class="min-w-full divide-y divide-gray-100">
            <thead class="bg-gray-50/50">
                <tr>
                    <th class="px-6 py-4 text-left text-[10px] font-black uppercase tracking-widest text-gray-500">Operator</th>
                    <th class="px-6 py-4 text-left text-[10px] font-black uppercase tracking-widest text-gray-500">Role</th>
                    <th class="px-6 py-4 text-left text-[10px] font-black uppercase tracking-widest text-gray-500">Status</th>
                    <th class="px-6 py-4 text-left text-[10px] font-black uppercase tracking-widest text-gray-500">Check-in</th>
                    <th class="px-6 py-4 text-left text-[10px] font-black uppercase tracking-widest text-gray-500">Check-out</th>
                    <th class="px-6 py-4 text-right text-[10px] font-black uppercase tracking-widest text-gray-500">Actions</th>
                </tr>
            </thead>
            <tbody class="divide-y divide-gray-100 bg-white">
                <tr v-for="assignment in assignments" :key="assignment.uid" class="hover:bg-indigo-50/20 transition-colors group">
                    <td class="px-6 py-4">
                         <div class="flex items-center">
                            <div class="h-8 w-8 rounded-full bg-indigo-100 text-indigo-600 flex items-center justify-center font-bold text-xs mr-3">
                                {{ assignment.operator.username.charAt(0).toUpperCase() }}
                            </div>
                            <div>
                                <div class="font-bold text-gray-900">{{ assignment.operator.full_name || assignment.operator.username }}</div>
                                <div class="text-xs text-gray-400 mt-0.5">{{ assignment.operator.mobile_primary || 'No Mobile' }}</div>
                            </div>
                        </div>
                    </td>
                    <td class="px-6 py-4">
                         <span class="inline-flex items-center px-2 py-1 rounded text-xs font-medium bg-gray-100 text-gray-700">
                            {{ assignment.role.name }}
                        </span>
                    </td>
                     <td class="px-6 py-4">
                         <span class="inline-flex items-center px-2 py-0.5 rounded text-[10px] font-black uppercase tracking-wider"
                            :class="{
                                'bg-green-50 text-green-700': assignment.status === 'CONFIRMED',
                                'bg-yellow-50 text-yellow-700': assignment.status === 'PENDING',
                                'bg-red-50 text-red-700': assignment.status === 'CANCELLED'
                            }">
                            {{ assignment.status }}
                        </span>
                    </td>
                    <td class="px-6 py-4 text-xs text-gray-500">
                        {{ formatTime(assignment.check_in_at) }}
                    </td>
                    <td class="px-6 py-4 text-xs text-gray-500">
                        {{ formatTime(assignment.check_out_at) }}
                    </td>
                    <td class="px-6 py-4 text-right">
                         <button 
                            @click="openTaskModal(assignment)"
                            class="text-indigo-600 hover:text-indigo-800 text-sm font-bold mr-4 inline-flex items-center gap-1"
                            title="View Tasks"
                        >
                            <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                            </svg>
                            View
                        </button>
                        <button 
                            v-if="canManage"
                            @click="removeAssignment(assignment)"
                            class="text-red-500 hover:text-red-700 text-sm font-bold"
                            title="Remove"
                        >
                            <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                            </svg>
                        </button>
                    </td>
                </tr>
                 <tr v-if="loading">
                    <td colspan="5" class="px-6 py-12 text-center text-gray-400 animate-pulse">
                        Loading assignments...
                    </td>
                </tr>
                 <tr v-else-if="assignments.length === 0">
                    <td colspan="5" class="px-6 py-12 text-center text-gray-400 italic">
                        No operators assigned to this center yet.
                    </td>
                </tr>
            </tbody>
        </table>

        <!-- Pagination Controls -->
        <div class="px-6 py-4 border-t border-gray-100 flex items-center justify-between bg-gray-50/50" v-if="totalAssignments > 0">
            <div class="flex items-center gap-4">
                <span class="text-xs text-gray-500">Rows per page:</span>
                <select 
                    v-model="pageSize" 
                    @change="loadData(1)"
                    class="bg-white border border-gray-200 text-gray-700 text-xs rounded-lg focus:ring-indigo-500 focus:border-indigo-500 block p-1.5"
                >
                    <option :value="10">10</option>
                    <option :value="25">25</option>
                    <option :value="50">50</option>
                    <option :value="100">100</option>
                </select>
                <span class="text-xs text-gray-500">
                    Showing <span class="font-bold">{{ showingStart }}</span> - <span class="font-bold">{{ showingEnd }}</span> of <span class="font-bold">{{ totalAssignments }}</span>
                </span>
            </div>
            <div class="flex items-center gap-2">
                <button 
                    @click="loadData(currentPage - 1)" 
                    :disabled="currentPage === 1"
                    class="p-2 rounded-lg hover:bg-white disabled:opacity-30 disabled:hover:bg-transparent transition-colors text-gray-500"
                >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
                    </svg>
                </button>
                <span class="text-xs font-bold text-gray-700">Page {{ currentPage }}</span>
                <button 
                    @click="loadData(currentPage + 1)" 
                    :disabled="!paramsNext"
                    class="p-2 rounded-lg hover:bg-white disabled:opacity-30 disabled:hover:bg-transparent transition-colors text-gray-500"
                >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
                    </svg>
                </button>
            </div>
        </div>
    </div>

    <!-- Task View Modal -->
    <BaseModal :isOpen="isTaskModalOpen" :title="`Tasks for ${selectedAssignment?.operator?.full_name || 'Operator'}`" @close="closeTaskModal" size="2xl">
        <div class="space-y-6">
            <div v-if="loadingTasks" class="flex justify-center py-8">
                <div class="h-8 w-8 border-4 border-indigo-100 border-t-indigo-600 rounded-full animate-spin"></div>
            </div>
            <div v-else-if="assignmentTasks.length === 0" class="text-center py-8 text-gray-500 italic">
                No tasks found for this operator.
            </div>
            <div v-else class="space-y-4">
                <div v-for="task in assignmentTasks" :key="task.uid" class="bg-gray-50 rounded-xl p-4 border border-gray-100">
                    <div class="flex justify-between items-start mb-2">
                        <div>
                            <h3 class="font-bold text-gray-900 text-sm">{{ task.task_name }}</h3>
                            <p class="text-xs text-gray-500">{{ task.description }}</p>
                        </div>
                         <span class="inline-flex items-center px-2 py-0.5 rounded text-[10px] font-black uppercase tracking-wider"
                            :class="{
                                'bg-green-100 text-green-700': task.status === 'COMPLETED',
                                'bg-gray-200 text-gray-600': task.status === 'PENDING',
                            }">
                            {{ task.status }}
                        </span>
                    </div>

                    <div v-if="task.completed_at" class="text-[10px] text-gray-400 mb-2">
                        Completed at: {{ new Date(task.completed_at).toLocaleString() }}
                    </div>

                    <!-- Response Data -->
                    <div v-if="task.response_data && Object.keys(task.response_data).length > 0" class="mb-3">
                         <p class="text-[10px] font-bold text-gray-500 uppercase tracking-widest mb-1">Response Data:</p>
                         <div class="bg-white p-2 rounded border border-gray-200 text-xs font-mono text-gray-700">
                            {{ task.response_data }}
                         </div>
                    </div>

                    <!-- Evidence Media -->
                    <div v-if="task.evidence_files && task.evidence_files.length > 0">
                        <p class="text-[10px] font-bold text-gray-500 uppercase tracking-widest mb-2">Evidence:</p>
                        <div class="grid grid-cols-2 sm:grid-cols-3 gap-2">
                            <div v-for="file in task.evidence_files" :key="file.uid" class="relative group aspect-square rounded-lg overflow-hidden bg-gray-200 border border-gray-200">
                                <img 
                                    v-if="file.media_type === 'PHOTO'" 
                                    :src="file.file" 
                                    class="w-full h-full object-cover" 
                                    alt="Task Evidence"
                                >
                                <video 
                                    v-else-if="file.media_type === 'VIDEO'" 
                                    :src="file.file" 
                                    class="w-full h-full object-cover" 
                                    controls
                                ></video>
                                <a 
                                    :href="file.file" 
                                    target="_blank"
                                    class="absolute inset-0 bg-black/50 opacity-0 group-hover:opacity-100 flex items-center justify-center transition-opacity"
                                >
                                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                                    </svg>
                                </a>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </BaseModal>

    <!-- Add Assignment Modal -->
    <BaseModal :isOpen="isModalOpen" title="Assign Operator" @close="closeModal">
        <form @submit.prevent="assignOperator" class="space-y-4">
            <div>
                <label class="block text-xs font-black text-gray-400 uppercase tracking-widest mb-1">Select Role</label>
                <select v-model="form.role" required class="w-full px-4 py-2 bg-gray-50 border-none rounded-xl text-sm focus:ring-2 focus:ring-indigo-500">
                    <option v-for="role in roles" :key="role.uid" :value="role.uid">{{ role.name }}</option>
                </select>
            </div>
             <div>
                <label class="block text-xs font-black text-gray-400 uppercase tracking-widest mb-1">Select Operator</label>
                 <select v-model="form.operator" required class="w-full px-4 py-2 bg-gray-50 border-none rounded-xl text-sm focus:ring-2 focus:ring-indigo-500">
                    <option v-for="op in availableOperators" :key="op.uid" :value="op.uid">
                        {{ op.full_name || op.username }} ({{ op.mobile_primary || 'No Mobile' }})
                    </option>
                </select>
             </div>

            <div v-if="error" class="p-3 bg-red-50 text-red-600 text-xs rounded-lg border border-red-100">
                {{ error }}
            </div>

            <div class="flex justify-end gap-3 pt-4">
                <button type="submit" :disabled="saving" class="px-6 py-2 bg-indigo-600 text-white text-sm font-bold rounded-lg hover:bg-indigo-700 transition-colors disabled:opacity-50">
                    {{ saving ? 'Assigning...' : 'Assign Operator' }}
                </button>
            </div>
        </form>
    </BaseModal>

    <!-- Bulk Import Modal -->
    <BaseModal :isOpen="isImportModalOpen" title="Bulk Assign Operators" @close="closeImportModal">
        <div class="relative min-h-[300px]">
            <!-- Processing Overlay -->
            <div v-if="bulkRequesting" class="absolute inset-0 bg-white/80 backdrop-blur-sm z-10 flex flex-col items-center justify-center rounded-2xl">
                <div class="relative">
                    <div class="h-16 w-16 border-4 border-indigo-100 border-t-indigo-600 rounded-full animate-spin"></div>
                    <div class="absolute inset-0 flex items-center justify-center">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a2 2 0 002 2h12a2 2 0 002-2v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                        </svg>
                    </div>
                </div>
                <p class="mt-4 text-sm font-bold text-gray-900 tracking-tight">Processing Assignments...</p>
                <p class="text-[10px] text-gray-500 mt-1 uppercase tracking-widest">Validating Data</p>
            </div>

            <div class="space-y-6" :class="{ 'opacity-50 pointer-events-none': bulkRequesting }">
                <div class="p-4 bg-indigo-50 rounded-2xl border border-indigo-100">
                    <p class="text-sm font-bold text-indigo-900 mb-1">Step 1: Download Template</p>
                    <p class="text-xs text-indigo-700 mb-3">Download the template, fill it in Excel, and **save as CSV**.</p>
                    <button 
                        @click="downloadTemplate"
                        class="flex items-center gap-2 px-4 py-2 bg-white text-indigo-600 rounded-xl text-xs font-bold border border-indigo-200 hover:bg-indigo-100 transition-all shadow-sm"
                    >
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a2 2 0 002 2h12a2 2 0 002-2v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                        </svg>
                        Download Template (CSV)
                    </button>
                </div>

                <div class="p-4 bg-gray-50 rounded-2xl border border-gray-100">
                    <p class="text-sm font-bold text-gray-900 mb-1">Step 2: Upload Filled CSV</p>
                    <p class="text-xs text-gray-500 mb-3">Please upload the saved CSV file here.</p>
                    <input 
                        type="file" 
                        ref="fileInput"
                        accept=".csv"
                        @change="handleFileChange"
                        class="block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-full file:border-0 file:text-xs file:font-semibold file:bg-indigo-50 file:text-indigo-700 hover:file:bg-indigo-100"
                    />
                </div>
                
                <div v-if="bulkError" class="p-3 bg-red-50 text-red-600 text-[10px] rounded-lg border border-red-100 italic">
                    {{ bulkError }}
                </div>

                <div v-if="bulkResult" class="space-y-3">
                    <div class="p-3 bg-indigo-50 text-indigo-700 text-xs rounded-lg border border-indigo-100">
                        <div class="flex justify-between items-center">
                            <span class="font-medium">Total Created/Updated: <span class="font-bold text-indigo-900 text-lg ml-1">{{ (bulkResult.created.length || 0) + (bulkResult.updated.length || 0) }}</span></span>
                            <span v-if="bulkResult.errors.length > 0" class="text-red-600 font-medium">Failed: <span class="font-bold text-lg ml-1">{{ bulkResult.errors.length }}</span></span>
                        </div>
                    </div>

                    <!-- Detailed Errors -->
                    <div v-if="bulkResult.errors.length > 0" class="max-h-48 overflow-y-auto space-y-2 rounded-xl border border-gray-100 p-2 bg-gray-50">
                        <div v-for="(err, idx) in bulkResult.errors" :key="idx" class="p-2 bg-white rounded-lg border border-red-50 text-[10px]">
                            <div class="flex items-start gap-2">
                                <span class="px-1.5 py-0.5 bg-red-100 text-red-700 rounded font-bold">Error</span>
                                <div class="flex-1">
                                    <p class="font-bold text-gray-900 truncate">Row: {{ err.row?.operator_username || 'Unknown' }}</p>
                                    <p class="text-red-500 italic">{{ err.error }}</p>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        <template #footer>
            <button 
                @click="submitBulkAssignments"
                :disabled="bulkRequesting || !selectedFile"
                class="inline-flex justify-center rounded-lg bg-indigo-600 px-6 py-2.5 text-sm font-bold text-white hover:bg-indigo-700 focus:outline-none disabled:opacity-50 disabled:cursor-not-allowed transition-all shadow-md shadow-indigo-100"
            >
                {{ bulkRequesting ? 'Processing...' : 'Bulk Assign' }}
            </button>
        </template>
    </BaseModal>

  </div>
</template>

<script setup>
import { ref, computed, watch, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import { useAuthStore } from '../../stores/auth';
import api from '../../api/axios';
import BaseModal from '../../components/BaseModal.vue';
import ExportButton from '../../components/ExportButton.vue';

const route = useRoute();
const shiftCenterUid = route.params.centerId; // Route: /operations/shift-centers/:centerId/assignments

const authStore = useAuthStore();
const canManage = computed(() => {
    const type = authStore.user?.user_type;
    return type === 'INTERNAL_ADMIN' || authStore.user?.is_superuser; 
});

const shiftCenter = ref(null);
const assignments = ref([]);
const roles = ref([]);
const availableOperators = ref([]);
const loading = ref(false);
const search = ref('');
const isModalOpen = ref(false);
const saving = ref(false);
const error = ref('');

// Pagination
const currentPage = ref(1);
const pageSize = ref(10);
const totalAssignments = ref(0);
const paramsNext = ref(null);

const showingStart = computed(() => totalAssignments.value === 0 ? 0 : (currentPage.value - 1) * pageSize.value + 1);
const showingEnd = computed(() => Math.min(currentPage.value * pageSize.value, totalAssignments.value));

const form = ref({
    shift_center: shiftCenterUid,
    operator: '',
    role: '',
    status: 'PENDING'
});


const loadData = async (page = 1) => {
    loading.value = true;
    try {
        if (!shiftCenter.value) {
            const centerRes = await api.get(`/operations/shift-centers/${shiftCenterUid}/`);
            shiftCenter.value = centerRes.data;
        }

        let url = `/assignments/?shift_center=${shiftCenterUid}&page=${page}&page_size=${pageSize.value}`;
        if (search.value) {
            url += `&search=${search.value}`;
        }
        
        const assignRes = await api.get(url);
        
        if (assignRes.data.results) {
            assignments.value = assignRes.data.results;
            totalAssignments.value = assignRes.data.count;
            paramsNext.value = assignRes.data.next;
            currentPage.value = page;
        } else {
             assignments.value = assignRes.data;
             totalAssignments.value = assignRes.data.length || 0;
        }
    } catch (e) {
        console.error("Failed to load assignments", e);
    } finally {
        loading.value = false;
    }
};

// Debounce helper
const debounceLocal = (fn, delay) => {
    let timeoutId;
    return (...args) => {
        clearTimeout(timeoutId);
        timeoutId = setTimeout(() => fn(...args), delay);
    };
};

const debouncedSearch = debounceLocal(() => {
    loadData(1);
}, 300);

watch(search, () => {
    debouncedSearch();
});

const openAddOperatorModal = async () => {
    if (!canManage.value) return;
    isModalOpen.value = true;
    // Load roles and operators if not loaded
    if (roles.value.length === 0) {
        try {
            const [rolesRes, opsRes] = await Promise.all([
                 api.get('/masters/roles/'),
                 api.get('/identity/users/?user_type=OPERATOR') // Removed status=ACTIVE to show all operators (Draft/Requested etc)
            ]);
            roles.value = rolesRes.data.results || rolesRes.data;
            availableOperators.value = opsRes.data.results || opsRes.data;
        } catch (e) {
            console.error("Failed to load options", e);
        }
    }
};

const closeModal = () => {
    isModalOpen.value = false;
    error.value = '';
};

const assignOperator = async () => {
    if (!canManage.value) return;
    saving.value = true;
    error.value = '';
    console.log("Submitting Assignment Form:", form.value);
    try {
        await api.post('/assignments/', form.value);
        await loadData(currentPage.value);
        closeModal();
    } catch (e) {
        console.error("Assignment Failed:", e.response?.data);
        const errorData = e.response?.data;
        if (errorData && typeof errorData === 'object') {
             // Handle field-specific errors
             const msg = Object.entries(errorData).map(([k, v]) => `${k}: ${v}`).join(', ');
             error.value = msg || "Failed to assign operator.";
        } else {
             error.value = errorData?.detail || "Failed to assign operator.";
        }
    } finally {
        saving.value = false;
    }
};

const removeAssignment = async (assignment) => {
    if (!canManage.value) return;
    if (!confirm('Remove this operator assignment?')) return;
    try {
        await api.delete(`/assignments/${assignment.uid}/`);
        await loadData(currentPage.value);
    } catch (e) {
        alert("Failed to remove assignment.");
    }
};

// Task View Logic
const isTaskModalOpen = ref(false);
const selectedAssignment = ref(null);
const assignmentTasks = ref([]);
const loadingTasks = ref(false);

const openTaskModal = async (assignment) => {
    selectedAssignment.value = assignment;
    isTaskModalOpen.value = true;
    assignmentTasks.value = [];
    loadingTasks.value = true;
    
    try {
        const res = await api.get(`/assignments/tasks/?assignment=${assignment.uid}`);
        assignmentTasks.value = res.data.results || res.data;
    } catch (e) {
        console.error("Failed to load tasks", e);
    } finally {
        loadingTasks.value = false;
    }
};

const closeTaskModal = () => {
    isTaskModalOpen.value = false;
    selectedAssignment.value = null;
    assignmentTasks.value = [];
};

// Bulk Import Logic
const isImportModalOpen = ref(false);
const bulkRequesting = ref(false);
const bulkError = ref('');
const bulkResult = ref(null);
const selectedFile = ref(null);
const fileInput = ref(null);

const openImportModal = () => {
    if (!canManage.value) return;
    isImportModalOpen.value = true;
    selectedFile.value = null;
    bulkError.value = '';
    bulkResult.value = null;
    if (fileInput.value) fileInput.value.value = '';
};

const closeImportModal = () => {
    isImportModalOpen.value = false;
};

const handleFileChange = (e) => {
    selectedFile.value = e.target.files[0];
};

const downloadTemplate = async () => {
    try {
        const response = await api.get('/assignments/download_template/', {
            responseType: 'blob'
        });
        const url = window.URL.createObjectURL(new Blob([response.data]));
        const link = document.createElement('a');
        link.href = url;
        link.setAttribute('download', 'operator_assignment_template.csv');
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        window.URL.revokeObjectURL(url);
    } catch (e) {
        console.error("Failed to download template", e);
        alert("Failed to download template. Please check your connection.");
    }
};

const formatDate = (dateString, fallback = 'N/A') => {
    if (!dateString) return fallback;
    const date = new Date(dateString);
    if (isNaN(date.getTime())) return fallback;
    return date.toLocaleDateString();
};

const formatTime = (dateString, fallback = '-') => {
    if (!dateString) return fallback;
    const date = new Date(dateString);
    if (isNaN(date.getTime())) return fallback;
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
};

const getTaskTime = (assignment, taskNamePart) => {
    if (!assignment.tasks) return '-';
    // Find task that matches name partially (case-insensitive)
    const task = assignment.tasks.find(t => 
        t.task_name?.toLowerCase().includes(taskNamePart.toLowerCase()) && 
        t.status === 'COMPLETED'
    );
    
    if (task && task.completed_at) {
        return new Date(task.completed_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    }
    return '-';
};

const submitBulkAssignments = async () => {
    if (!canManage.value) return;
    if (!selectedFile.value) return;
    
    const formData = new FormData();
    formData.append('file', selectedFile.value);
    formData.append('shift_center', shiftCenterUid);

    bulkRequesting.value = true;
    bulkError.value = '';
    bulkResult.value = null;
    try {
        const res = await api.post('/assignments/bulk-import/', formData, {
            headers: {
                'Content-Type': 'multipart/form-data'
            }
        });
        bulkResult.value = res.data;
        await loadData(currentPage.value);
        if (res.data.errors.length === 0) {
            // Success - keep modal open to show result card
            // Reset file selection optionally?
            selectedFile.value = null;
            if (fileInput.value) fileInput.value.value = '';
        }
    } catch (e) {
        bulkError.value = e.response?.data?.detail || "Failed to process bulk import. Ensure it is a valid CSV.";
    } finally {
        bulkRequesting.value = false;
    }
};

onMounted(() => loadData(1));
</script>
