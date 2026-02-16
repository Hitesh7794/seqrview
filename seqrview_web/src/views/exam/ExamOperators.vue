<template>
  <div class="space-y-6 animate-in fade-in duration-500">
    <!-- Header -->
    <div class="bg-white p-6 rounded-2xl shadow-sm border border-gray-100 flex items-center justify-between">
      <div>
        <h1 class="text-2xl font-black text-gray-900 tracking-tight">Exam Operators</h1>
        <p class="text-sm text-gray-500 mt-1">View all operators available for this exam.</p>
      </div>
      
      <div class="flex items-center gap-3">
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
      </div>
    </div>

    <!-- Operators List -->
    <div class="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
        <table class="min-w-full divide-y divide-gray-100">
            <thead class="bg-gray-50/50">
                <tr>
                    <th class="px-6 py-4 text-left text-[10px] font-black uppercase tracking-widest text-gray-500">Operator Details</th>
                    <th class="px-6 py-4 text-left text-[10px] font-black uppercase tracking-widest text-gray-500">Status</th>
                    <th class="px-6 py-4 text-left text-[10px] font-black uppercase tracking-widest text-gray-500">Contact</th>
                    <th class="px-6 py-4 text-right text-[10px] font-black uppercase tracking-widest text-gray-500">Actions</th>
                </tr>
            </thead>
            <tbody class="divide-y divide-gray-100 bg-white">
                <tr v-for="op in operators" :key="op.uid" class="hover:bg-indigo-50/20 transition-colors">
                    <td class="px-6 py-4">
                         <div class="flex items-center gap-3">
                            <div class="h-10 w-10 rounded-full bg-indigo-100 flex items-center justify-center text-indigo-600 font-bold border-2 border-white shadow-sm">
                                {{ (op.full_name || op.username).charAt(0).toUpperCase() }}
                            </div>
                            <div>
                                <div class="text-sm font-bold text-gray-900">{{ op.full_name || 'No Name' }}</div>
                                <div class="text-xs text-gray-500 font-mono">@{{ op.username }}</div>
                            </div>
                        </div>
                    </td>
                    <td class="px-6 py-4">
                        <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wide bg-green-50 text-green-700 border border-green-100">
                            Active
                        </span>
                    </td>
                    <td class="px-6 py-4">
                        <div class="text-sm text-gray-700 font-medium">{{ op.mobile_primary }}</div>
                        <div class="text-xs text-gray-400" v-if="op.email">{{ op.email }}</div>
                    </td>
                    <td class="px-6 py-4 text-right">
                         <button 
                            @click="viewDetails(op)"
                            class="text-indigo-600 hover:text-indigo-800 text-xs font-bold bg-indigo-50 px-3 py-1.5 rounded-lg hover:bg-indigo-100 transition-colors"
                        >
                            View Details
                        </button>
                    </td>
                </tr>
                 <tr v-if="loading">
                    <td colspan="4" class="px-6 py-12 text-center text-gray-400 animate-pulse">
                        Loading operators...
                    </td>
                </tr>
                 <tr v-else-if="operators.length === 0">
                    <td colspan="4" class="px-6 py-12 text-center text-gray-400 italic">
                        No operators found for this exam.
                    </td>
                </tr>
            </tbody>
        </table>

        <!-- Pagination -->
        <div class="px-6 py-4 border-t border-gray-100 flex items-center justify-between" v-if="totalOperators > 0">
             <span class="text-xs text-gray-500">
                Showing <span class="font-bold">{{ showingStart }}</span> - <span class="font-bold">{{ showingEnd }}</span> of <span class="font-bold">{{ totalOperators }}</span>
            </span>
            <div class="flex gap-2">
                <button 
                    @click="loadOperators(currentPage - 1)" 
                    :disabled="currentPage === 1"
                    class="p-2 rounded-lg hover:bg-gray-50 disabled:opacity-30 disabled:hover:bg-transparent transition-colors text-gray-500"
                >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
                    </svg>
                </button>
                <button 
                    @click="loadOperators(currentPage + 1)" 
                    :disabled="!paramsNext"
                    class="p-2 rounded-lg hover:bg-gray-50 disabled:opacity-30 disabled:hover:bg-transparent transition-colors text-gray-500"
                >
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
                    </svg>
                </button>
            </div>
        </div>
    </div>

    <!-- Operator Detail Modal -->
    <BaseModal :isOpen="isDetailModalOpen" title="Operator Profile" @close="closeDetailModal">
        <div v-if="selectedOperator" class="space-y-6">
             <div class="flex items-center space-x-4 border-b border-gray-100 pb-4">
                <div class="h-16 w-16 rounded-full bg-indigo-100 flex items-center justify-center text-indigo-600 text-2xl font-bold border-4 border-white shadow-sm">
                    {{ (selectedOperator.full_name || selectedOperator.username).charAt(0).toUpperCase() }}
                </div>
                <div>
                    <h3 class="text-xl font-bold text-gray-900">{{ selectedOperator.full_name }}</h3>
                    <p class="text-sm text-gray-500">@{{ selectedOperator.username }}</p>
                </div>
            </div>

            <div class="grid grid-cols-2 gap-4 text-sm">
                <div>
                    <p class="text-xs font-bold text-gray-400 uppercase tracking-widest mb-1">Mobile</p>
                    <p class="font-medium text-gray-900">{{ selectedOperator.mobile_primary }}</p>
                </div>
                <div>
                     <p class="text-xs font-bold text-gray-400 uppercase tracking-widest mb-1">Email</p>
                    <p class="font-medium text-gray-900">{{ selectedOperator.email || '-' }}</p>
                </div>
                 <div>
                     <p class="text-xs font-bold text-gray-400 uppercase tracking-widest mb-1">Joined</p>
                    <p class="font-medium text-gray-900">{{ new Date(selectedOperator.created_at).toLocaleDateString() }}</p>
                </div>
                 <div>
                     <p class="text-xs font-bold text-gray-400 uppercase tracking-widest mb-1">User Type</p>
                    <p class="font-medium text-gray-900">{{ selectedOperator.user_type }}</p>
                </div>
            </div>

            <div v-if="selectedOperator.operator_profile" class="p-4 bg-gray-50 rounded-xl border border-gray-100 text-sm space-y-3">
                 <h4 class="text-xs font-black text-gray-400 uppercase tracking-widest mb-2">Profile Details</h4>
                 <div>
                    <span class="text-gray-500">KYC Status:</span> 
                    <span class="ml-2 font-bold" :class="selectedOperator.operator_profile.kyc_status === 'VERIFIED' ? 'text-green-600' : 'text-orange-600'">
                        {{ selectedOperator.operator_profile.kyc_status?.replace('_', ' ') }}
                    </span>
                 </div>
                 <div v-if="selectedOperator.operator_profile.current_address">
                     <span class="text-gray-500 block mb-1">Address:</span>
                     <p class="font-medium text-gray-900">{{ selectedOperator.operator_profile.current_address }}</p>
                 </div>
            </div>
        </div>
        <template #footer>
            <button @click="closeDetailModal" class="w-full py-2 bg-gray-100 text-gray-700 font-bold rounded-lg hover:bg-gray-200 transition-colors">Close</button>
        </template>
    </BaseModal>
  </div>
</template>

<script setup>
import { ref, onMounted, watch, computed } from 'vue';
import api from '../../api/axios';
import BaseModal from '../../components/BaseModal.vue';

const operators = ref([]);
const loading = ref(false);
const search = ref('');
const totalOperators = ref(0);
const currentPage = ref(1);
const pageSize = ref(10);
const paramsNext = ref(null);

const selectedOperator = ref(null);
const isDetailModalOpen = ref(false);

const showingStart = computed(() => totalOperators.value === 0 ? 0 : (currentPage.value - 1) * pageSize.value + 1);
const showingEnd = computed(() => Math.min(currentPage.value * pageSize.value, totalOperators.value));

const loadOperators = async (page = 1) => {
    loading.value = true;
    try {
        let url = `/identity/users/?user_type=OPERATOR&page=${page}&page_size=${pageSize.value}`;
        // We rely on backend filtering by 'client' based on user.exam.client
        if (search.value) {
            url += `&search=${search.value}`;
        }
        const res = await api.get(url);
        if (res.data.results) {
            operators.value = res.data.results;
            totalOperators.value = res.data.count;
            paramsNext.value = res.data.next;
            currentPage.value = page;
        } else {
             operators.value = res.data; // Fallback if no pagination
             totalOperators.value = res.data.length || 0;
        }
    } catch (e) {
        console.error("Failed to load operators", e);
    } finally {
        loading.value = false;
    }
};

let searchTimeout;
watch(search, () => {
    clearTimeout(searchTimeout);
    searchTimeout = setTimeout(() => {
        loadOperators(1);
    }, 300);
});

const viewDetails = (op) => {
    selectedOperator.value = op;
    isDetailModalOpen.value = true;
};

const closeDetailModal = () => {
    isDetailModalOpen.value = false;
    selectedOperator.value = null;
};

onMounted(() => {
    loadOperators();
});
</script>
