<template>
  <div class="space-y-6">
    <!-- Header -->
    <ToastNotification ref="toast" />
    <div class="bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
        <div class="flex items-center gap-4 mb-4">
             <button @click="$router.back()" class="text-gray-400 hover:text-gray-600 transition-colors">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
                </svg>
            </button>
            <div>
                <h1 class="text-2xl font-black text-gray-900 tracking-tight" v-if="shift">{{ shift.name }} - Centers</h1>
                <div v-else class="h-8 w-64 bg-gray-200 rounded animate-pulse"></div>
                <div class="flex items-center gap-3 mt-1 text-sm text-gray-500" v-if="shift">
                    <span>{{ new Date(shift.work_date).toLocaleDateString() }}</span>
                    <span>•</span>
                    <span>{{ shift.start_time }} - {{ shift.end_time }}</span>
                    <span v-if="shift.is_locked" class="ml-2 px-2 py-0.5 rounded text-[10px] font-black uppercase tracking-wider bg-red-100 text-red-700">
                        LOCKED
                    </span>
                </div>
            </div>
        </div>
        
        <div class="flex justify-between items-center pt-4 border-t border-gray-100">
             <div class="relative">
                <input 
                    v-model="search" 
                    type="text" 
                    placeholder="Search centers..." 
                    class="pl-10 pr-4 py-2 bg-gray-50 border-none rounded-xl text-sm focus:ring-2 focus:ring-indigo-500 w-64"
                >
                <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 absolute left-3 top-2.5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                </svg>
            </div>
            <div class="flex items-center gap-3">
                 <button 
                    v-if="canManage"
                    @click="openBulkTaskModal"
                    :disabled="shift?.is_locked"
                    class="flex items-center gap-2 px-4 py-2 bg-white text-indigo-600 rounded-xl text-sm font-bold border border-indigo-200 hover:bg-indigo-50 transition-all shadow-sm disabled:opacity-50 disabled:cursor-not-allowed"
                >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                    </svg>
                    Bulk Task Config
                </button>
                <ExportButton 
                    endpoint="/operations/shift-centers/export/" 
                    filename="shift_centers.csv"
                    :filters="{ shift: shiftUid }"
                />
                <button 
                    v-if="canManage"
                    @click="openImportModal"
                    :disabled="shift?.is_locked"
                    class="flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white rounded-xl text-sm font-bold hover:bg-indigo-700 transition-all shadow-sm disabled:opacity-50 disabled:cursor-not-allowed"
                >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a2 2 0 002 2h12a2 2 0 002-2v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                    </svg>
                    Import Centers
                </button>
                 <button 
                    v-if="canManage"
                    @click="openAddCenterModal"
                    :disabled="shift?.is_locked"
                    class="flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white rounded-xl text-sm font-bold hover:bg-indigo-700 transition-all shadow-sm disabled:opacity-50 disabled:cursor-not-allowed"
                >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
                    </svg>
                    Add Center
                </button>
            </div>
        </div>
    </div>

    <!-- Stats Grid -->
    <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
         <div class="bg-white p-4 rounded-xl border border-gray-100 shadow-sm">
            <p class="text-xs font-bold text-gray-400 uppercase tracking-widest">Total Centers</p>
            <p class="text-2xl font-black text-gray-900 mt-1">{{ stats.total_centers }}</p>
        </div>
        <div class="bg-white p-4 rounded-xl border border-gray-100 shadow-sm">
            <p class="text-xs font-bold text-gray-400 uppercase tracking-widest">Operators Assigned</p>
            <p class="text-2xl font-black text-indigo-600 mt-1">{{ stats.operators_assigned }}</p>
        </div>
         <div class="bg-white p-4 rounded-xl border border-gray-100 shadow-sm">
            <p class="text-xs font-bold text-gray-400 uppercase tracking-widest">Task Exceptions</p>
            <p class="text-2xl font-black text-orange-500 mt-1">{{ stats.task_exceptions }}</p>
        </div>
    </div>

    <!-- Center List -->
    <div class="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
        <table class="min-w-full divide-y divide-gray-100">
            <thead class="bg-gray-50/50">
                <tr>
                    <th class="px-6 py-4 text-left text-[10px] font-black uppercase tracking-widest text-gray-500">Center Details</th>
                    <th class="px-6 py-4 text-left text-[10px] font-black uppercase tracking-widest text-gray-500">City</th>
                    <th class="px-6 py-4 text-left text-[10px] font-black uppercase tracking-widest text-gray-500">Required</th>
                    <th class="px-6 py-4 text-left text-[10px] font-black uppercase tracking-widest text-gray-500">Assigned Tasks</th>
                     <th class="px-6 py-4 text-left text-[10px] font-black uppercase tracking-widest text-gray-500">Task Config</th>
                    <th class="px-6 py-4 text-right text-[10px] font-black uppercase tracking-widest text-gray-500">Actions</th>
                </tr>
            </thead>
            <tbody class="divide-y divide-gray-100 bg-white">
            <tr v-for="center in centers" :key="center.uid" class="hover:bg-indigo-50/20 transition-colors group">
                     <td class="px-6 py-4">
                        <div class="font-bold text-gray-900">{{ center.center_name || center.exam_center_details.client_center_name }}</div>
                        <div class="text-xs text-gray-400 mt-0.5 font-mono">{{ center.exam_center_details.client_center_code }}</div>
                    </td>
                    <td class="px-6 py-4 text-sm text-gray-600">
                        {{ center.city || center.exam_center_details.city || '-' }}
                    </td>
                    <td class="px-6 py-4 text-sm text-gray-700 font-medium font-mono">
                        {{ center.operators_required || center.exam_center_details.operators_required || 0 }}
                    </td>
                    <td class="px-6 py-4 text-sm font-black text-indigo-600">
                        {{ center.tasks_count || 0 }}
                    </td>
                    <td class="px-6 py-4">
                         <span class="inline-flex items-center px-2 py-1 rounded text-xs font-medium bg-gray-100 text-gray-600">
                            Default
                        </span>
                    </td>
                    <td class="px-6 py-4 text-right">
                         <button 
                            @click="navigateToAssignments(center)"
                            class="text-indigo-600 hover:text-indigo-800 text-sm font-bold mr-4"
                        >
                            {{ canManage ? 'Assign Operators' : 'Assignments' }}
                        </button>
                        <button 
                            v-if="canManage"
                            @click="openTaskModal(center)"
                            :disabled="shift?.is_locked"
                            class="text-gray-400 hover:text-gray-600 text-sm font-bold disabled:opacity-30 disabled:cursor-not-allowed"
                        >
                            Tasks
                        </button>
                    </td>
                </tr>
                 <tr v-if="loading">
                    <td colspan="5" class="px-6 py-12 text-center text-gray-400 animate-pulse">
                        Loading centers...
                    </td>
                </tr>
                 <tr v-else-if="centers.length === 0">
                    <td colspan="5" class="px-6 py-12 text-center text-gray-400 italic">
                        No centers found for this shift. Import CSV to get started.
                    </td>
                </tr>
            </tbody>
        </table>
        
        <!-- Pagination Controls -->
        <div class="px-6 py-4 border-t border-gray-100 flex items-center justify-between bg-gray-50/50" v-if="totalCenters > 0">
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
                    Showing <span class="font-bold">{{ showingStart }}</span> - <span class="font-bold">{{ showingEnd }}</span> of <span class="font-bold">{{ totalCenters }}</span>
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

    <!-- Import Modal (Placeholder) -->
    <!-- Bulk Add Modal -->
    <BaseModal :isOpen="isImportModalOpen" title="Bulk Add Centers" @close="closeImportModal">
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
                <p class="mt-4 text-sm font-bold text-gray-900 tracking-tight">Processing Centers...</p>
                <p class="text-[10px] text-gray-500 mt-1 uppercase tracking-widest">Validating and Assigning</p>
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
                            <span class="font-medium">Total Created/Linked: <span class="font-bold text-indigo-900 text-lg ml-1">{{ bulkResult.created.length }}</span></span>
                            <span v-if="bulkResult.errors.length > 0" class="text-red-600 font-medium">Failed: <span class="font-bold text-lg ml-1">{{ bulkResult.errors.length }}</span></span>
                        </div>
                    </div>

                    <!-- Detailed Errors -->
                    <div v-if="bulkResult.errors.length > 0" class="max-h-48 overflow-y-auto space-y-2 rounded-xl border border-gray-100 p-2 bg-gray-50">
                        <div v-for="(err, idx) in bulkResult.errors" :key="idx" class="p-2 bg-white rounded-lg border border-red-50 text-[10px]">
                            <div class="flex items-start gap-2">
                                <span class="px-1.5 py-0.5 bg-red-100 text-red-700 rounded font-bold">Error</span>
                                <div class="flex-1">
                                    <p class="font-bold text-gray-900 truncate">Row: {{ err.row?.client_center_code || 'Unknown' }}</p>
                                    <p class="text-red-500 italic">{{ err.errors }}</p>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        <template #footer>
            <button 
                @click="submitBulkCenters"
                :disabled="bulkRequesting || !selectedFile"
                class="inline-flex justify-center rounded-lg bg-indigo-600 px-6 py-2.5 text-sm font-bold text-white hover:bg-indigo-700 focus:outline-none disabled:opacity-50 disabled:cursor-not-allowed transition-all shadow-md shadow-indigo-100"
            >
                {{ bulkRequesting ? 'Processing Import...' : 'Import Centers' }}
            </button>
        </template>
    </BaseModal>

    <TaskConfigModal 
        :visible="isTaskModalOpen" 
        :shiftCenterId="selectedTaskCenter?.uid"
        :shiftCenterName="selectedTaskCenter?.exam_center_details?.client_center_name"
        @close="isTaskModalOpen = false"
    />

    <BulkTaskConfigModal 
        :visible="isBulkTaskModalOpen" 
        :shiftId="shiftUid"
        :shiftName="shift?.name"
        @close="isBulkTaskModalOpen = false"
        @success="(msg) => toast.trigger(msg, 'success')"
    />

    <!-- Single Center Add Modal -->
    <BaseModal :isOpen="isAddModalOpen" title="Add Single Center" @close="closeAddCenterModal">
        <div class="space-y-4">
             <div class="p-4 bg-indigo-50 rounded-2xl border border-indigo-100 mb-4">
                <p class="text-xs text-indigo-800">
                    If the center code already exists for this exam, it will be linked. Otherwise, a new center will be created.
                </p>
            </div>

            <div>
                <label class="block text-xs font-bold text-gray-700 uppercase tracking-wide mb-1">Client Center Code <span class="text-red-500">*</span></label>
                <input v-model="addCenterForm.client_center_code" type="text" class="w-full rounded-xl border-gray-200 focus:border-indigo-500 focus:ring-indigo-500 text-sm" placeholder="e.g. DEL-001">
            </div>

            <div class="grid grid-cols-2 gap-4">
                <div>
                     <label class="block text-xs font-bold text-gray-700 uppercase tracking-wide mb-1">Center Name <span class="text-red-500">*</span></label>
                     <input v-model="addCenterForm.client_center_name" type="text" class="w-full rounded-xl border-gray-200 focus:border-indigo-500 focus:ring-indigo-500 text-sm" placeholder="e.g. Delhi Public School">
                </div>
                <div>
                     <label class="block text-xs font-bold text-gray-700 uppercase tracking-wide mb-1">City <span class="text-red-500">*</span></label>
                     <input v-model="addCenterForm.city" type="text" class="w-full rounded-xl border-gray-200 focus:border-indigo-500 focus:ring-indigo-500 text-sm" placeholder="e.g. New Delhi">
                </div>
            </div>

            <div class="grid grid-cols-2 gap-4">
                <div>
                     <label class="block text-xs font-bold text-gray-700 uppercase tracking-wide mb-1">Required Operators <span class="text-red-500">*</span></label>
                     <input v-model="addCenterForm.operators_required" type="number" class="w-full rounded-xl border-gray-200 focus:border-indigo-500 focus:ring-indigo-500 text-sm" placeholder="e.g. 2">
                </div>
                 <div>
                     <label class="block text-xs font-bold text-gray-700 uppercase tracking-wide mb-1">Incharge Name <span class="text-red-500">*</span></label>
                     <input v-model="addCenterForm.incharge_name" type="text" class="w-full rounded-xl border-gray-200 focus:border-indigo-500 focus:ring-indigo-500 text-sm" placeholder="Required">
                </div>
            </div>

            <div class="grid grid-cols-2 gap-4">
                <div>
                     <label class="block text-xs font-bold text-gray-700 uppercase tracking-wide mb-1">Latitude <span class="text-red-500">*</span></label>
                     <input v-model="addCenterForm.latitude" type="text" class="w-full rounded-xl border-gray-200 focus:border-indigo-500 focus:ring-indigo-500 text-sm" placeholder="e.g. 28.6139">
                </div>
                 <div>
                     <label class="block text-xs font-bold text-gray-700 uppercase tracking-wide mb-1">Longitude <span class="text-red-500">*</span></label>
                     <input v-model="addCenterForm.longitude" type="text" class="w-full rounded-xl border-gray-200 focus:border-indigo-500 focus:ring-indigo-500 text-sm" placeholder="e.g. 77.2090">
                </div>
            </div>
             
             <div class="grid grid-cols-1 gap-4">
                 <div>
                     <label class="block text-xs font-bold text-gray-700 uppercase tracking-wide mb-1">Address / Instructions <span class="text-red-500">*</span></label>
                     <textarea v-model="addCenterForm.address" rows="2" class="w-full rounded-xl border-gray-200 focus:border-indigo-500 focus:ring-indigo-500 text-sm" placeholder="Full address or specific instructions"></textarea>
                </div>
            </div>

        </div>
        <template #footer>
             <button 
                @click="submitAddCenter"
                :disabled="addingCenter || !addCenterForm.client_center_code"
                class="inline-flex justify-center rounded-lg bg-indigo-600 px-6 py-2.5 text-sm font-bold text-white hover:bg-indigo-700 focus:outline-none disabled:opacity-50 disabled:cursor-not-allowed transition-all shadow-md shadow-indigo-100"
            >
                {{ addingCenter ? 'Adding...' : 'Add Center' }}
            </button>
        </template>
    </BaseModal>

  </div>
</template>
<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAuthStore } from '../../stores/auth';
import api from '../../api/axios';
import BaseModal from '../../components/BaseModal.vue';
import ExportButton from '../../components/ExportButton.vue';
import ToastNotification from '../../components/ToastNotification.vue';
import TaskConfigModal from '../../components/TaskConfigModal.vue';
import BulkTaskConfigModal from '../../components/BulkTaskConfigModal.vue';

const route = useRoute();
const router = useRouter();
const shiftUid = route.params.shiftId; // Assuming route is configured as /operations/shifts/:shiftId/centers

const authStore = useAuthStore();
const canManage = computed(() => {
    const type = authStore.user?.user_type;
    return type === 'INTERNAL_ADMIN' || authStore.user?.is_superuser; 
});

const shift = ref(null);
const centers = ref([]);
const loading = ref(false);
const search = ref('');
const stats = ref({
    total_centers: 0,
    operators_assigned: '-',
    task_exceptions: '-'
});

// Pagination
const currentPage = ref(1);
const pageSize = ref(10);
const totalCenters = ref(0);
const paramsNext = ref(null);

const isImportModalOpen = ref(false);
const bulkRequesting = ref(false);
const bulkError = ref('');
const bulkResult = ref(null);
const selectedFile = ref(null);
const fileInput = ref(null);

const toast = ref(null); // Reference for ToastNotification

const showingStart = computed(() => totalCenters.value === 0 ? 0 : (currentPage.value - 1) * pageSize.value + 1);
const showingEnd = computed(() => Math.min(currentPage.value * pageSize.value, totalCenters.value));

const loadData = async (page = 1) => {
    loading.value = true;
    try {
        // Fetch Shift Details & Stats only on first load or if needed (can optimize)
        if (!shift.value) {
            const [shiftRes, statsRes] = await Promise.all([
                api.get(`/operations/shifts/${shiftUid}/`),
                api.get(`/operations/shifts/${shiftUid}/statistics/`)
            ]);
           shift.value = shiftRes.data;
           stats.value = statsRes.data;
        }

        // Fetch Centers with Pagination
        let url = `/operations/shift-centers/?shift=${shiftUid}&page=${page}&page_size=${pageSize.value}`;
        if (search.value) {
            url += `&search=${search.value}`;
        }

        const centersRes = await api.get(url);
        
        if (centersRes.data.results) {
            centers.value = centersRes.data.results;
            totalCenters.value = centersRes.data.count;
            paramsNext.value = centersRes.data.next;
            currentPage.value = page;
        } else {
             centers.value = centersRes.data;
             totalCenters.value = centersRes.data.length || 0;
        }

    } catch (e) {
        console.error("Failed to load shift data", e);
        if (toast.value) toast.value.trigger("Failed to load shift data", "error");
    } finally {
        loading.value = false;
    }
};

// Debounce helper
const debounce = (fn, delay) => {
    let timeoutId;
    return (...args) => {
        clearTimeout(timeoutId);
        timeoutId = setTimeout(() => fn(...args), delay);
    };
};

// Debounce search
const debouncedSearch = debounce(() => {
    loadData(1);
}, 300);

watch(search, () => {
    debouncedSearch();
});

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

// Single Center Add Logic
const isAddModalOpen = ref(false);
const addingCenter = ref(false);
const addCenterForm = ref({
    client_center_code: '',
    client_center_name: '',
    city: '',
    operators_required: '',
    address: '',
    latitude: '',
    longitude: '',
    incharge_name: '',
    incharge_phone: ''
});

const openAddCenterModal = () => {
    if (!canManage.value) return;
    isAddModalOpen.value = true;
    addCenterForm.value = {
        client_center_code: '',
        client_center_name: '',
        city: '',
        operators_required: '',
        address: '',
        latitude: '',
        longitude: '',
        incharge_name: '',
        incharge_phone: ''
    };
};

const closeAddCenterModal = () => {
    isAddModalOpen.value = false;
};

const submitAddCenter = async () => {
    if (!canManage.value) return;
    const form = addCenterForm.value;
    if (!form.client_center_code) {
        if (toast.value) toast.value.trigger("Client Center Code is required", "error");
        return;
    }
    // ... (rest of validation logic same as before) ...
    if (!form.client_center_name) {
        if (toast.value) toast.value.trigger("Center Name is required", "error");
        return;
    }
    if (!form.city) {
        if (toast.value) toast.value.trigger("City is required", "error");
        return;
    }
    if (!form.operators_required) {
        if (toast.value) toast.value.trigger("Required Operators count is required", "error");
        return;
    }
    if (!form.incharge_name) {
        if (toast.value) toast.value.trigger("Incharge Name is required", "error");
        return;
    }
    if (!form.latitude) {
        if (toast.value) toast.value.trigger("Latitude is required", "error");
        return;
    }
    if (!form.longitude) {
        if (toast.value) toast.value.trigger("Longitude is required", "error");
        return;
    }
    if (!form.address) {
        if (toast.value) toast.value.trigger("Address / Instructions is required", "error");
        return;
    }

    addingCenter.value = true;
    try {
        const payload = {
            shift: shiftUid,
            ...addCenterForm.value,
            latitude: addCenterForm.value.latitude,
            longitude: addCenterForm.value.longitude,
            active_capacity: addCenterForm.value.operators_required,
            operators_required: addCenterForm.value.operators_required,
        };

        await api.post('/operations/shift-centers/add-center/', payload);
        await loadData(currentPage.value);
        closeAddCenterModal();
        if (search.value) search.value = ''; 
        if (toast.value) toast.value.trigger("Center added successfully", "success");
    } catch (e) {
        console.error("Failed to add center", e);
        let errorMsg = "Failed to add center";
        if (e.response?.data) {
            if (typeof e.response.data === 'object') {
                 if (e.response.data.detail) {
                     errorMsg = e.response.data.detail;
                 } else {
                     const messages = Object.values(e.response.data).flat();
                     errorMsg = messages.join(', ');
                 }
            } else {
                 errorMsg = e.response.data;
            }
        }
        if (toast.value) toast.value.trigger(errorMsg, "error");
    } finally {
        addingCenter.value = false;
    }
};

const handleFileChange = (e) => {
    selectedFile.value = e.target.files[0];
};

const downloadTemplate = async () => {
    try {
        const response = await api.get('/operations/shift-centers/download-template/', {
            responseType: 'blob'
        });
        const url = window.URL.createObjectURL(new Blob([response.data]));
        const link = document.createElement('a');
        link.href = url;
        link.setAttribute('download', 'shift_center_import_template.csv');
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        window.URL.revokeObjectURL(url);
    } catch (e) {
        console.error("Failed to download template", e);
        if (toast.value) toast.value.trigger("Failed to download template. Please check your connection.", "error");
    }
};

const submitBulkCenters = async () => {
    if (!canManage.value) return;
    if (!selectedFile.value) return;
    
    const formData = new FormData();
    formData.append('file', selectedFile.value);
    formData.append('shift', shiftUid);

    bulkRequesting.value = true;
    bulkError.value = '';
    bulkResult.value = null;
    try {
        const res = await api.post('/operations/shift-centers/bulk-import/', formData, {
            headers: {
                'Content-Type': 'multipart/form-data'
            }
        });
        bulkResult.value = res.data;
        await loadData(currentPage.value);
        
        // Also refresh stats
        const statsRes = await api.get(`/operations/shifts/${shiftUid}/statistics/`);
        stats.value = statsRes.data;

        if (res.data.errors.length === 0) {
            if (toast.value) toast.value.trigger(`Successfully imported ${res.data.created.length} centers.`, "success");
            setTimeout(() => {
                closeImportModal();
            }, 1000);
        } else {
             if (toast.value) toast.value.trigger("Some rows failed to import. Please check errors.", "error");
        }
    } catch (e) {
        bulkError.value = e.response?.data?.detail || "Failed to process bulk import. Ensure it is a valid CSV.";
        if (toast.value) toast.value.trigger(bulkError.value, "error");
    } finally {
        bulkRequesting.value = false;
    }
};

const isTaskModalOpen = ref(false);
const selectedTaskCenter = ref(null);

const openTaskModal = (center) => {
    if (!canManage.value) return;
    selectedTaskCenter.value = center;
    isTaskModalOpen.value = true;
};

const isBulkTaskModalOpen = ref(false);

const openBulkTaskModal = () => {
    if (!canManage.value) return;
    isBulkTaskModalOpen.value = true;
};


const navigateToAssignments = (center) => {
    // Check if we are in Exam Console mode (URL starts with /exam/)
    if (route.path.startsWith('/exam/')) {
        // We need to extract the exam code from the current route params
        // Since we are at /exam/:code/shifts/:shiftId/centers
        // route.params should have `code` available
        const code = route.params.code;
        if (code) {
             router.push(`/exam/${code}/shift-centers/${center.uid}/assignments`);
             return;
        }
    }
    // Default fallback
    router.push(`/operations/shift-centers/${center.uid}/assignments`);
};

onMounted(() => loadData(1));
</script>
