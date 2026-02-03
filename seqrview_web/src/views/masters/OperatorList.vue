<template>
  <div class="space-y-6">
    <div class="flex justify-between items-center bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
      <div>
        <h1 class="text-2xl font-black text-gray-900 tracking-tight">Operator Workforce</h1>
        <p class="text-sm text-gray-500 mt-1">Manage all field operators and verification requests.</p>
      </div>
      <div class="flex items-center gap-3">
          <div class="relative">
              <input 
                v-model="search" 
                type="text" 
                placeholder="Search mobile or name..." 
                class="pl-10 pr-4 py-2 bg-gray-50 border-none rounded-xl text-sm focus:ring-2 focus:ring-blue-500 w-64"
              >
              <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 absolute left-3 top-2.5 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
              </svg>
          </div>
      </div>
    </div>

    <div class="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
      <table class="min-w-full divide-y divide-gray-100">
        <thead class="bg-gray-50/50">
          <tr>
            <th class="px-6 py-4 text-left text-[10px] font-black uppercase tracking-widest text-gray-500">Operator Details</th>
            <th class="px-6 py-4 text-left text-[10px] font-black uppercase tracking-widest text-gray-500">Profile Status</th>
            <th class="px-6 py-4 text-left text-[10px] font-black uppercase tracking-widest text-gray-500">KYC Status</th>
            <th class="px-6 py-4 text-left text-[10px] font-black uppercase tracking-widest text-gray-500">Last Active</th>
            <th class="px-6 py-4 text-right text-[10px] font-black uppercase tracking-widest text-gray-500">Actions</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-100 bg-white">
          <tr v-for="user in filteredOperators" :key="user.uid" class="hover:bg-blue-50/20 transition-colors group">
            <td class="px-6 py-4">
              <div class="flex items-center gap-3">
                <div class="h-10 w-10 rounded-full bg-blue-100 border-2 border-white shadow-sm flex items-center justify-center text-blue-600 font-bold">
                    {{ (user.full_name || user.username || 'U').charAt(0).toUpperCase() }}
                </div>
                <div>
                  <div class="text-sm font-bold text-gray-900 group-hover:text-blue-600 transition-colors">{{ user.full_name || 'Anonymous Operator' }}</div>
                  <div class="text-xs text-gray-400 font-mono">{{ user.mobile_primary || user.username }}</div>
                </div>
              </div>
            </td>
            <td class="px-6 py-4">
              <span class="px-2.5 py-1 rounded-full text-[10px] font-black uppercase tracking-widest border border-gray-100 shadow-sm"
                :class="statusClass(user.operator_profile?.profile_status)">
                {{ user.operator_profile?.profile_status || 'DRAFT' }}
              </span>
            </td>
            <td class="px-6 py-4 text-sm">
                <div class="flex items-center gap-2">
                    <span class="h-1.5 w-1.5 rounded-full" :class="kycDotClass(user.operator_profile?.kyc_status)"></span>
                    <span class="text-xs font-medium text-gray-600 uppercase">{{ user.operator_profile?.kyc_status?.replace('_', ' ') || 'NOT STARTED' }}</span>
                </div>
                <div v-if="user.operator_profile?.verification_method" class="text-[10px] text-gray-400 mt-0.5">via {{ user.operator_profile.verification_method }}</div>
            </td>
            <td class="px-6 py-4 text-xs text-gray-400 tabular-nums">
              {{ new Date(user.created_at).toLocaleDateString() }}
            </td>
            <td class="px-6 py-4 text-right">
              <div class="flex items-center justify-end gap-2">
                 <button 
                  @click="openViewModal(user)"
                  class="p-2 text-gray-400 hover:text-purple-600 hover:bg-purple-50 rounded-lg transition-all"
                  title="View Details"
                >
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                  </svg>
                </button>
                <button 
                  @click="blockUser(user)"
                  class="p-2 text-gray-400 hover:text-orange-600 hover:bg-orange-50 rounded-lg transition-all"
                  :title="user.status === 'BLACKLIST' ? 'Unblock' : 'Block Operator'"
                >
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636" />
                  </svg>
                </button>
                <button 
                  @click="deleteUser(user)"
                  class="p-2 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-all"
                  title="Delete Operator"
                >
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                  </svg>
                </button>
              </div>
            </td>
          </tr>
          <tr v-if="loading">
             <td colspan="5" class="px-6 py-20 text-center">
                 <div class="inline-flex items-center gap-2 text-blue-500 font-bold animate-pulse">
                     <svg class="animate-spin h-5 w-5" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>
                     Scanning Workforce...
                 </div>
             </td>
          </tr>
          <tr v-else-if="filteredOperators.length === 0">
             <td colspan="5" class="px-6 py-20 text-center text-gray-400 italic">No operators found matching your criteria.</td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- View Operator Modal -->
    <BaseModal :isOpen="isViewModalOpen" :title="'Operator Details'" @close="closeViewModal">
        <div v-if="selectedOperator" class="space-y-6">
            <!-- Header Section (Always Visible) -->
            <div class="flex items-center space-x-4 pb-4 border-b border-gray-100">
                <div class="h-16 w-16 rounded-full bg-gradient-to-br from-blue-500 to-purple-600 flex items-center justify-center text-white text-2xl font-bold shadow-lg overflow-hidden border-2 border-white ring-2 ring-gray-100">
                    <img v-if="selectedOperator.photo" :src="selectedOperator.photo" class="h-full w-full object-cover" alt="Profile">
                    <span v-else>{{ (selectedOperator.full_name || selectedOperator.username).charAt(0).toUpperCase() }}</span>
                </div>
                <div>
                    <h3 class="text-xl font-bold text-gray-900">{{ selectedOperator.full_name || 'No Name Provided' }}</h3>
                    <p class="text-sm text-gray-500">@{{ selectedOperator.username }}</p>
                    <div class="flex gap-2 mt-2">
                         <span class="px-2 py-0.5 rounded text-[10px] font-bold uppercase tracking-wide" 
                              :class="selectedOperator.status === 'ACTIVE' ? 'bg-green-100 text-green-700 border border-green-200' : 'bg-red-100 text-red-700 border border-red-200'">
                            {{ selectedOperator.status }}
                        </span>
                    </div>
                </div>
            </div>

            <!-- Tabs Navigation -->
            <div class="flex space-x-1 rounded-xl bg-gray-100/80 p-1 border border-gray-200">
                <button 
                    @click="activeTab = 'profile'"
                    :class="[
                        'w-full rounded-lg py-2.5 text-xs font-bold uppercase tracking-wide leading-5 transition-all outline-none',
                        activeTab === 'profile'
                        ? 'bg-white text-blue-700 shadow ring-1 ring-black/5'
                        : 'text-gray-500 hover:bg-white/[0.12] hover:text-gray-600'
                    ]"
                >
                    Profile & Details
                </button>
                <button 
                    @click="activeTab = 'duties'"
                    :class="[
                        'w-full rounded-lg py-2.5 text-xs font-bold uppercase tracking-wide leading-5 transition-all outline-none',
                        activeTab === 'duties'
                        ? 'bg-white text-blue-700 shadow ring-1 ring-black/5'
                        : 'text-gray-500 hover:bg-white/[0.12] hover:text-gray-600'
                    ]"
                >
                    Duties & Assignments <span class="ml-1 bg-gray-200 px-1.5 py-0.5 rounded-full text-[10px] text-gray-600">{{ duties.length }}</span>
                </button>
            </div>

            <!-- Tab Content: Profile -->
            <div v-if="activeTab === 'profile'" class="space-y-6 animate-fadeIn">
                 <!-- Profile & KYC Status Grid -->
                <div class="grid grid-cols-2 gap-4">
                    <div class="p-3 bg-gray-50 rounded-xl border border-gray-100">
                        <p class="text-xs text-gray-500 uppercase font-bold tracking-wider mb-1">Profile Status</p>
                        <span class="inline-flex items-center px-2 py-1 rounded text-xs font-medium"
                            :class="statusClass(selectedOperator.operator_profile?.profile_status)">
                            <span class="h-2 w-2 rounded-full mr-1.5" :class="kycDotClass(selectedOperator.operator_profile?.profile_status === 'VERIFIED' ? 'VERIFIED' : 'PENDING')"></span>
                            {{ selectedOperator.operator_profile?.profile_status || 'N/A' }}
                        </span>
                        <div v-if="selectedOperator.operator_profile?.date_of_birth" class="mt-2 text-xs text-gray-500">
                             Dob: {{ selectedOperator.operator_profile.date_of_birth }} ({{ selectedOperator.operator_profile.gender }})
                        </div>
                    </div>
                    <div class="p-3 bg-gray-50 rounded-xl border border-gray-100">
                        <p class="text-xs text-gray-500 uppercase font-bold tracking-wider mb-1">KYC Status</p>
                        <div class="flex flex-col">
                             <span class="text-sm font-semibold text-gray-900 flex items-center gap-1">
                                 {{ (selectedOperator.operator_profile?.kyc_status || 'N/A').replace('_', ' ') }}
                                 <svg v-if="selectedOperator.operator_profile?.kyc_status === 'VERIFIED'" xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-green-500" viewBox="0 0 20 20" fill="currentColor">
                                    <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                                 </svg>
                             </span>
                             <span v-if="selectedOperator.operator_profile?.verification_method" class="text-xs text-gray-400">
                                 via {{ selectedOperator.operator_profile.verification_method }}
                             </span>
                             <span v-if="selectedOperator.operator_profile?.kyc_verified_at" class="text-[10px] text-green-600 mt-1">
                                 Verified on {{ new Date(selectedOperator.operator_profile.kyc_verified_at).toLocaleDateString() }}
                             </span>
                        </div>
                    </div>
                </div>

                 <!-- Contact Details -->
                <div>
                    <h4 class="text-xs font-black text-gray-400 uppercase tracking-widest mb-3">Contact Information</h4>
                    <div class="grid grid-cols-2 gap-y-4 text-sm">
                        <div>
                            <p class="text-gray-500 text-xs mb-0.5">Mobile Number</p>
                            <p class="font-medium text-gray-900">{{ selectedOperator.mobile_primary || 'Not provided' }}</p>
                        </div>
                        <div>
                            <p class="text-gray-500 text-xs mb-0.5">Email Address</p>
                            <p class="font-medium text-gray-900">{{ selectedOperator.email || 'Not provided' }}</p>
                        </div>
                    </div>
                </div>

                <!-- Address Details -->
                <div v-if="selectedOperator.operator_profile">
                    <h4 class="text-xs font-black text-gray-400 uppercase tracking-widest mb-3">Location & Device</h4>
                     <div class="space-y-3 text-sm">
                        <div v-if="selectedOperator.operator_profile.current_address">
                            <p class="text-gray-500 text-xs mb-0.5">Current Address</p>
                            <p class="font-medium text-gray-900">{{ selectedOperator.operator_profile.current_address }}</p>
                             <div class="flex gap-2 text-xs text-gray-500 mt-1">
                                <span v-if="selectedOperator.operator_profile.current_district">{{ selectedOperator.operator_profile.current_district }}</span>
                                <span v-if="selectedOperator.operator_profile.current_state">• {{ selectedOperator.operator_profile.current_state }}</span>
                            </div>
                             <div v-if="selectedOperator.operator_profile.current_lat && selectedOperator.operator_profile.current_lng" class="mt-1 text-[10px] text-blue-500 font-mono">
                                 GPS: {{ selectedOperator.operator_profile.current_lat }}, {{ selectedOperator.operator_profile.current_lng }}
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <!-- Tab Content: Duties -->
            <div v-if="activeTab === 'duties'" class="space-y-4 animate-fadeIn">
                <div v-if="loadingDuties" class="text-center py-10">
                    <svg class="animate-spin h-6 w-6 text-blue-500 mx-auto" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>
                    <p class="text-xs text-gray-400 mt-2">Loading assignments...</p>
                </div>
                <div v-else-if="duties.length === 0" class="text-center py-12 rounded-xl border-2 border-dashed border-gray-100 bg-gray-50/50">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-10 w-10 text-gray-300 mx-auto mb-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 0 00-2 2v12a2 0 002 2h10a2 0 002-2V7a2 0 00-2-2h-2M9 5a2 0 002 2h2a2 0 002-2M9 5a2 0 012-2h2a2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01" />
                    </svg>
                    <p class="text-sm text-gray-500 font-medium">No duties assigned yet.</p>
                </div>
                <div v-else class="space-y-3 max-h-[400px] overflow-y-auto pr-2">
                    <div v-for="duty in duties" :key="duty.uid" class="p-3 bg-white border border-gray-100 rounded-xl hover:border-blue-200 transition-colors shadow-sm">
                        <div class="flex justify-between items-start mb-2">
                            <div>
                                <h5 class="text-sm font-bold text-gray-900">{{ duty.shift_center.exam.name }}</h5>
                                <p class="text-xs text-gray-500">{{ duty.shift_center.center.name }}</p>
                            </div>
                            <span class="px-2 py-0.5 rounded text-[10px] font-black uppercase tracking-wider"
                                :class="{
                                    'bg-green-50 text-green-700': duty.status === 'CONFIRMED',
                                    'bg-yellow-50 text-yellow-700': duty.status === 'PENDING',
                                    'bg-red-50 text-red-700': duty.status === 'CANCELLED',
                                    'bg-blue-50 text-blue-700': duty.status === 'CHECK_IN'
                                }">
                                {{ duty.status }}
                            </span>
                        </div>
                        <div class="grid grid-cols-2 gap-2 text-xs border-t border-gray-50 pt-2 mt-2">
                            <div>
                                <p class="text-gray-400 uppercase text-[9px] font-bold tracking-wider">Role</p>
                                <p class="font-medium text-gray-700">{{ duty.role.name }}</p>
                            </div>
                            <div>
                                <p class="text-gray-400 uppercase text-[9px] font-bold tracking-wider">Date</p>
                                <p class="font-medium text-gray-700">{{ new Date(duty.shift_center.shift.date).toLocaleDateString() }}</p>
                            </div>
                             <div class="col-span-2">
                                <p class="text-gray-400 uppercase text-[9px] font-bold tracking-wider">Time</p>
                                <p class="font-medium text-gray-700">{{ duty.shift_center.shift.start_time }} - {{ duty.shift_center.shift.end_time }}</p>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

             <!-- System Meta -->
             <div class="pt-4 border-t border-gray-100 flex justify-between text-xs text-gray-400">
                 <span>UID: {{ selectedOperator.uid }}</span>
                 <span>Joined: {{ new Date(selectedOperator.created_at).toLocaleDateString() }}</span>
             </div>
        </div>
    </BaseModal>
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue';
import api from '../../api/axios';
import BaseModal from '../../components/BaseModal.vue';

const operators = ref([]);
const loading = ref(false);
const search = ref('');
const activeTab = ref('profile'); // 'profile' | 'duties'
const duties = ref([]);
const loadingDuties = ref(false);
const selectedOperator = ref(null);
const isViewModalOpen = ref(false);

const loadDuties = async (operatorId) => {
    loadingDuties.value = true;
    try {
        const res = await api.get(`/assignments/?operator=${operatorId}`);
        duties.value = res.data.results || res.data;
    } catch (e) {
        console.error("Failed to load duties", e);
    } finally {
        loadingDuties.value = false;
    }
};

const openViewModal = (operator) => {
    selectedOperator.value = operator;
    activeTab.value = 'profile'; // Reset to profile
    isViewModalOpen.value = true;
    loadDuties(operator.uid); // Fetch duties in background
};

const loadOperators = async () => {
    loading.value = true;
    try {
        const res = await api.get('/identity/users/?user_type=OPERATOR');
        const data = res.data.results || res.data;
        operators.value = Array.isArray(data) ? data : [];
    } catch (e) {
        console.error("Failed to load operators", e);
    } finally {
        loading.value = false;
    }
};

const filteredOperators = computed(() => {
    if (!search.value) return operators.value;
    const s = search.value.toLowerCase();
    return operators.value.filter(o => 
        o.username.toLowerCase().includes(s) || 
        o.mobile_primary?.includes(s) || 
        o.full_name?.toLowerCase().includes(s)
    );
});

const statusClass = (status) => {
    if (status === 'VERIFIED') return 'bg-green-50 text-green-700 border-green-200';
    if (status === 'REJECTED') return 'bg-red-50 text-red-700 border-red-200';
    if (status === 'PROFILE_FILLED') return 'bg-blue-50 text-blue-700 border-blue-200';
    return 'bg-gray-50 text-gray-500 border-gray-200';
};

const kycDotClass = (status) => {
    if (status === 'VERIFIED') return 'bg-green-500';
    if (status === 'FAILED') return 'bg-red-500';
    if (status === 'NOT_STARTED') return 'bg-gray-300';
    return 'bg-blue-500';
};



const closeViewModal = () => {
    isViewModalOpen.value = false;
    selectedOperator.value = null;
};

const blockUser = async (user) => {
    const isBlocked = user.status === 'BLACKLIST';
    const action = isBlocked ? 'Unblock' : 'Block';
    if (!confirm(`Are you sure you want to ${action.toLowerCase()} this operator?`)) return;

    try {
        const newStatus = isBlocked ? 'ACTIVE' : 'BLACKLIST';
        await api.patch(`/identity/users/${user.uid}/`, { status: newStatus });
        await loadOperators();
    } catch (e) {
        console.error("Failed to update status", e);
        alert(`Failed to ${action.toLowerCase()} operator.`);
    }
};

const deleteUser = async (user) => {
    if (!confirm(`Are you sure you want to PERMANENTLY delete ${user.username}? This cannot be undone.`)) return;
    try {
        await api.delete(`/identity/users/${user.uid}/`);
        await loadOperators();
    } catch (e) {
         console.error("Failed to delete user", e);
         alert("Failed to delete user.");
    }
};

onMounted(loadOperators);
</script>
