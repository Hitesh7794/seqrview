<template>
  <div class="space-y-6">
    <!-- Metrics Row -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <div class="bg-white p-4 rounded-2xl shadow-sm border border-gray-100 flex items-center gap-4">
            <div class="h-12 w-12 rounded-xl bg-blue-50 text-blue-600 flex items-center justify-center">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
                </svg>
            </div>
            <div>
                <div class="text-2xl font-black text-gray-900">{{ totalOperatorsCount }}</div>
                <div class="text-[10px] font-bold text-gray-400 uppercase tracking-wider">Total Operators</div>
            </div>
        </div>
        <div class="bg-white p-4 rounded-2xl shadow-sm border border-gray-100 flex items-center gap-4">
            <div class="h-12 w-12 rounded-xl bg-green-50 text-green-600 flex items-center justify-center">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
            </div>
            <div>
                <div class="text-2xl font-black text-gray-900">{{ verifiedCount }}</div>
                <div class="text-[10px] font-bold text-gray-400 uppercase tracking-wider">Verified KYC</div>
            </div>
        </div>
        <div class="bg-white p-4 rounded-2xl shadow-sm border border-gray-100 flex items-center gap-4">
            <div class="h-12 w-12 rounded-xl bg-orange-50 text-orange-600 flex items-center justify-center">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
            </div>
            <div>
                <div class="text-2xl font-black text-gray-900">{{ pendingCount }}</div>
                <div class="text-[10px] font-bold text-gray-400 uppercase tracking-wider">Pending Requests</div>
            </div>
        </div>
        <div class="bg-white p-4 rounded-2xl shadow-sm border border-gray-100 flex items-center gap-4">
            <div class="h-12 w-12 rounded-xl bg-purple-50 text-purple-600 flex items-center justify-center">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
            </div>
            <div>
                <div class="text-2xl font-black text-gray-900">{{ activeToday }}</div>
                <div class="text-[10px] font-bold text-gray-400 uppercase tracking-wider">Active Today</div>
            </div>
        </div>
    </div>

    <!-- Controls Header -->
    <div class="bg-white p-6 rounded-2xl shadow-sm border border-gray-100 space-y-6">
      <div class="flex flex-col md:flex-row justify-between items-start md:items-center gap-4">
          <div>
            <h1 class="text-2xl font-black text-gray-900 tracking-tight">Operator Workforce</h1>
            <p class="text-sm text-gray-500 mt-1">Manage all field operators and verification requests from one central hub.</p>
          </div>
          
          <div class="flex flex-wrap items-center gap-3">
             <!-- Filters -->
             <div class="flex gap-2">
                <select v-model="profileStatusFilter" @change="handleFilterChange" class="bg-gray-50 border-none rounded-xl text-sm focus:ring-2 focus:ring-blue-500 py-2.5 px-3 text-gray-600 font-medium">
                    <option value="">Profile: All</option>
                    <option v-for="s in profileStatusOptions" :key="s" :value="s">{{ s.replace('_', ' ') }}</option>
                </select>
                <select v-model="kycStatusFilter" @change="handleFilterChange" class="bg-gray-50 border-none rounded-xl text-sm focus:ring-2 focus:ring-blue-500 py-2.5 px-3 text-gray-600 font-medium">
                    <option value="">KYC: All</option>
                    <option v-for="s in kycStatusOptions" :key="s" :value="s">{{ s.replace('_', ' ') }}</option>
                </select>
              </div>

             <div class="h-8 w-px bg-gray-200 mx-1"></div>

             <button 
                @click="openBulkRequestModal"
                class="flex items-center gap-2 px-4 py-2.5 border border-indigo-100 text-indigo-600 bg-indigo-50 rounded-xl text-sm font-bold hover:bg-indigo-100 transition-all"
             >
                <svg xmlns="http://www.w3.org/2000/xl" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-8l-4-4m0 0L8 8m4-4v12" />
                </svg>
                Bulk Request
             </button>
             <button 
                @click="openRequestModal"
                class="flex items-center gap-2 px-4 py-2.5 bg-blue-600 text-white rounded-xl text-sm font-bold hover:bg-blue-700 transition-all shadow-sm shadow-blue-200"
              >
                <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18 9v3m0 0v3m0-3h3m-3 0h-3m-2-5a4 4 0 11-8 0 4 4 0 018 0z" />
                </svg>
                Request Operator
             </button>
          </div>
      </div>

      <div class="relative">
          <input 
            v-model="search" 
            @input="handleSearch"
            type="text" 
            placeholder="Search mobile, name, or ID..." 
            class="pl-11 pr-4 py-3 bg-gray-50 border-none rounded-xl text-sm focus:ring-2 focus:ring-blue-500 w-full md:w-96 transition-all"
          >
          <svg v-if="loading" class="animate-spin h-5 w-5 absolute right-3 top-3 text-blue-500" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>
          <svg v-else xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 absolute left-4 top-3 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
          </svg>
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
          <tr v-for="user in operators" :key="user.uid" class="hover:bg-blue-50/20 transition-colors group">
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
              {{ new Date(user.updated_at).toLocaleDateString() }}
            </td>
             <td class="px-6 py-4 text-right">
              <div class="flex items-center justify-end gap-3">
                 <button 
                  @click="openViewModal(user)"
                  class="text-gray-400 hover:text-blue-600 transition-colors"
                  title="View Details"
                >
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
                  </svg>
                </button>
                <button 
                  @click="blockUser(user)"
                  class="text-gray-400 hover:text-orange-600 transition-colors"
                  :title="user.status === 'BLACKLIST' ? 'Unblock' : 'Block Operator'"
                >
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 015.636 5.636m12.728 12.728L5.636 5.636" />
                  </svg>
                </button>
                <button 
                  @click="deleteUser(user)"
                  class="text-gray-400 hover:text-red-600 transition-colors"
                  title="Delete Operator"
                >
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                  </svg>
                </button>
              </div>
            </td>
          </tr>
           <tr v-if="loading && operators.length === 0">
              <td colspan="5" class="px-6 py-20 text-center text-gray-400">
                  <div class="flex flex-col items-center justify-center">
                    <svg class="animate-spin h-6 w-6 text-blue-500 mb-2" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>
                    <span class="text-sm font-medium">Loading operators...</span>
                  </div>
              </td>
          </tr>
          <tr v-else-if="operators.length === 0">
              <td colspan="5" class="px-6 py-20 text-center">
                  <div class="flex flex-col items-center justify-center text-gray-400">
                      <svg xmlns="http://www.w3.org/2000/svg" class="h-10 w-10 mb-3 text-gray-200" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
                      </svg>
                      <p class="text-sm font-medium text-gray-500">No operators found</p>
                      <p class="text-xs mt-1">Try adjusting your filters or add a new operator.</p>
                  </div>
              </td>
          </tr>
        </tbody>
      </table>

      <!-- Pagination Footer -->
      <div class="bg-white px-6 py-4 border-t border-gray-100 flex items-center justify-between" v-if="totalOperators > 0">
          <div class="text-xs text-gray-500 font-medium">
              Showing <span class="text-gray-900 font-bold">{{ showingStart }}</span> to <span class="text-gray-900 font-bold">{{ showingEnd }}</span> of <span class="text-gray-900 font-bold">{{ totalOperators }}</span> results
          </div>
          
          <div class="flex items-center gap-4">
              <div class="flex items-center gap-2">
                  <span class="text-xs text-gray-500">Rows per page:</span>
                  <select v-model="pageSize" @change="loadOperators(1)" class="bg-white border border-gray-200 text-gray-700 text-xs rounded-lg focus:ring-blue-500 focus:border-blue-500 py-1 px-2 cursor-pointer hover:border-blue-500 transition-colors">
                      <option :value="10">10</option>
                      <option :value="25">25</option>
                      <option :value="50">50</option>
                      <option :value="300">300</option>
                  </select>
              </div>

              <div class="flex gap-2">
                  <button 
                      @click="prevPage" 
                      :disabled="currentPage === 1"
                      class="px-3 py-1.5 border border-gray-200 rounded-lg text-xs font-bold text-gray-600 bg-white hover:bg-gray-50 hover:text-gray-900 disabled:opacity-50 disabled:cursor-not-allowed transition-all shadow-sm"
                  >
                      Previous
                  </button>
                  <button 
                      @click="nextPage" 
                      :disabled="currentPage * pageSize >= totalOperators"
                      class="px-3 py-1.5 border border-gray-200 rounded-lg text-xs font-bold text-gray-600 bg-white hover:bg-gray-50 hover:text-gray-900 disabled:opacity-50 disabled:cursor-not-allowed transition-all shadow-sm"
                  >
                      Next
                  </button>
              </div>
          </div>
      </div>
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
            <div class="flex space-x-1 rounded-xl bg-gray-100/80 p-1 border border-gray-200 relative z-10">
                <button 
                    type="button"
                    @click="switchTab('profile')"
                    class="w-full rounded-lg py-2.5 text-xs font-bold uppercase tracking-wide leading-5 transition-all outline-none cursor-pointer"
                    :class="[
                        activeTab === 'profile'
                        ? 'bg-white text-blue-700 shadow ring-1 ring-black/5'
                        : 'text-gray-500 hover:bg-white hover:text-gray-700 hover:shadow-sm'
                    ]"
                >
                    Profile & Details
                </button>
                <button 
                    type="button"
                    @click="switchTab('duties')"
                    class="w-full rounded-lg py-2.5 text-xs font-bold uppercase tracking-wide leading-5 transition-all outline-none cursor-pointer"
                    :class="[
                        activeTab === 'duties'
                        ? 'bg-white text-blue-700 shadow ring-1 ring-black/5'
                        : 'text-gray-500 hover:bg-white hover:text-gray-700 hover:shadow-sm'
                    ]"
                >
                    Duties & Assignments <span class="ml-1 bg-gray-200 px-1.5 py-0.5 rounded-full text-[10px] text-gray-600">{{ duties.length || 0 }}</span>
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
                                <h5 class="text-sm font-bold text-gray-900">{{ duty.shift_center?.exam?.exam_code || 'Unknown Exam' }}</h5>
                                <p class="text-xs text-gray-500">{{ duty.shift_center?.exam_center?.client_center_name || duty.shift_center?.center?.name || 'Unknown Center' }}</p>
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
                                <p class="font-medium text-gray-700">{{ formatDate(duty.shift_center?.shift?.work_date) }}</p>
                            </div>
                             <div class="col-span-2">
                                <p class="text-gray-400 uppercase text-[9px] font-bold tracking-wider">Time</p>
                                <p class="font-medium text-gray-700">{{ duty.shift_center?.shift?.start_time }} - {{ duty.shift_center?.shift?.end_time }}</p>
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

    <!-- Request Operator Modal -->
    <BaseModal :isOpen="isRequestModalOpen" :title="'Request New Operator'" @close="closeRequestModal">
        <div class="space-y-4">
            <p class="text-sm text-gray-500">Enter the primary mobile number of the operator. We will create a placeholder account and trigger an onboarding request.</p>
            <div>
                <label class="block text-xs font-black text-gray-400 uppercase tracking-widest mb-1">Operator Name (Optional)</label>
                <input 
                    v-model="newOperatorName"
                    type="text"
                    placeholder="e.g. Hitesh Sharma"
                    class="w-full px-4 py-2 bg-gray-50 border-none rounded-xl text-sm focus:ring-2 focus:ring-blue-500 mb-3"
                >
                <label class="block text-xs font-black text-gray-400 uppercase tracking-widest mb-1">Mobile Number</label>
                <input 
                    v-model="newOperatorMobile"
                    type="tel"
                    maxlength="10"
                    @input="newOperatorMobile = newOperatorMobile.replace(/\D/g, '')"
                    placeholder="e.g. 9876543210"
                    class="w-full px-4 py-2 bg-gray-50 border-none rounded-xl text-sm focus:ring-2 focus:ring-blue-500"
                    @keyup.enter="submitOperatorRequest"
                >
            </div>
            <div v-if="requestError" class="p-3 bg-red-50 rounded-lg text-xs text-red-600 border border-red-100 italic">
                {{ requestError }}
            </div>
        </div>
        <template #footer>
            <button 
                @click="submitOperatorRequest"
                :disabled="requesting || !newOperatorMobile"
                class="inline-flex justify-center rounded-lg bg-blue-600 px-4 py-2 text-sm font-bold text-white hover:bg-blue-700 focus:outline-none disabled:opacity-50 disabled:cursor-not-allowed transition-all"
            >
                <svg v-if="requesting" class="animate-spin -ml-1 mr-2 h-4 w-4 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24"><circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle><path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path></svg>
                {{ requesting ? 'Sending Request...' : 'Send Onboarding Request' }}
            </button>
        </template>
    </BaseModal>

    <!-- Bulk Request Modal -->
    <BaseModal :isOpen="isBulkModalOpen" title="Bulk Request Operators" @close="closeBulkModal">
        <div class="relative min-h-[300px]">
            <!-- Processing Overlay -->
            <div v-if="bulkRequesting" class="absolute inset-0 bg-white/80 backdrop-blur-sm z-10 flex flex-col items-center justify-center rounded-2xl">
                <div class="relative">
                    <div class="h-16 w-16 border-4 border-indigo-100 border-t-indigo-600 rounded-full animate-spin"></div>
                    <div class="absolute inset-0 flex items-center justify-center">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 text-indigo-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18 9v3m0 0v3m0-3h3m-3 0h-3m-2-5a4 4 0 11-8 0 4 4 0 018 0zM3 20a6 6 0 0112 0v1H3v-1z" />
                        </svg>
                    </div>
                </div>
                <p class="mt-4 text-sm font-bold text-gray-900 tracking-tight">Requesting Operators...</p>
                <p class="text-[10px] text-gray-500 mt-1 uppercase tracking-widest">Broadcasting onboarding requests</p>
            </div>

            <div class="space-y-6" :class="{ 'opacity-50 pointer-events-none': bulkRequesting }">
                <div class="p-4 bg-indigo-50 rounded-2xl border border-indigo-100">
                    <p class="text-sm font-bold text-indigo-900 mb-1">Step 1: Download Template</p>
                    <p class="text-xs text-indigo-700 mb-3">Download the template, fill it in Excel, and **save as CSV**.</p>
                    <button 
                        @click="downloadOperatorTemplate"
                        class="flex items-center gap-2 px-4 py-2 bg-white text-indigo-600 rounded-xl text-xs font-bold border border-indigo-200 hover:bg-indigo-100 transition-all shadow-sm"
                    >
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a2 2 0 002 2h12a2 2 0 002-2v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                        </svg>
                        Download Template (CSV)
                    </button>
                </div>

                <div class="p-4 bg-gray-50 rounded-2xl border border-gray-100">
                    <p class="text-sm font-bold text-gray-900 mb-1">Step 2: Upload Filled File</p>
                    <p class="text-xs text-gray-500 mb-3">Please upload the saved CSV file here.</p>
                    <input 
                        type="file" 
                        ref="operatorFileInput"
                        accept=".csv"
                        @change="handleOperatorFileChange"
                        class="block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-full file:border-0 file:text-xs file:font-semibold file:bg-indigo-50 file:text-indigo-700 hover:file:bg-indigo-100"
                    />
                </div>
                
                <div v-if="bulkError" class="p-3 bg-red-50 text-red-600 text-[10px] rounded-lg border border-red-100 italic">
                    {{ bulkError }}
                </div>

                <div v-if="bulkResult" class="space-y-3">
                    <div class="p-3 bg-indigo-50 text-indigo-700 text-xs rounded-lg border border-indigo-100 overflow-hidden relative">
                        <!-- Tiny success decorative pattern -->
                        <div class="absolute -right-2 -top-2 opacity-10">
                            <svg class="w-12 h-12" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path></svg>
                        </div>

                        <div class="grid grid-cols-3 gap-2 text-center relative z-10">
                            <div class="p-2 bg-white/50 rounded-xl border border-indigo-200/50">
                                <div class="text-lg font-black text-indigo-900 leading-tight">{{ bulkResult.created.length }}</div>
                                <div class="text-[9px] uppercase font-bold tracking-tighter opacity-60">Created</div>
                            </div>
                            <div class="p-2 bg-white/50 rounded-xl border border-yellow-200/50">
                                <div class="text-lg font-black text-yellow-700 leading-tight">{{ bulkResult.skipped.length }}</div>
                                <div class="text-[9px] uppercase font-bold tracking-tighter opacity-60">Existing</div>
                            </div>
                            <div class="p-2 bg-white/50 rounded-xl border border-red-200/50">
                                <div class="text-lg font-black text-red-600 leading-tight">{{ bulkResult.errors.length }}</div>
                                <div class="text-[9px] uppercase font-bold tracking-tighter opacity-60">Failed</div>
                            </div>
                        </div>
                    </div>

                    <!-- Detailed Erroneous Mobile Numbers -->
                    <div v-if="bulkResult.errors.length > 0" class="max-h-48 overflow-y-auto space-y-2 rounded-xl border border-gray-100 p-2 bg-gray-50">
                        <div v-for="(err, idx) in bulkResult.errors" :key="idx" class="p-2 bg-white rounded-lg border border-red-50 text-[10px] flex items-center justify-between">
                            <div class="flex items-center gap-2">
                                <span class="w-2 h-2 rounded-full bg-red-400"></span>
                                <span class="font-bold text-gray-700">{{ err.mobile }}</span>
                            </div>
                            <span class="text-red-500 italic">{{ err.reason }}</span>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        <template #footer>
            <button 
                @click="submitBulkRequest"
                :disabled="bulkRequesting || !selectedOperatorFile"
                class="inline-flex justify-center rounded-lg bg-indigo-600 px-6 py-2.5 text-sm font-bold text-white hover:bg-indigo-700 focus:outline-none disabled:opacity-50 disabled:cursor-not-allowed transition-all shadow-md shadow-indigo-100"
            >
                {{ bulkRequesting ? 'Requesting...' : 'Submit Bulk Request' }}
            </button>
        </template>
    </BaseModal>

    <!-- Confirmation Modal -->
    <BaseModal :isOpen="isConfirmModalOpen" :title="confirmTitle" :showCancel="false" @close="closeConfirmModal">
        <div class="space-y-4">
            <p class="text-sm text-gray-500">{{ confirmMessage }}</p>
        </div>
        <template #footer>
            <button 
                @click="handleConfirm"
                :disabled="isConfirming"
                :class="confirmButtonClass"
                class="inline-flex justify-center rounded-lg px-4 py-2 text-sm font-bold shadow-sm focus:outline-none disabled:opacity-50 disabled:cursor-not-allowed transition-all"
            >
                <div v-if="isConfirming" class="mr-2 h-4 w-4 animate-spin rounded-full border-2 border-white border-t-transparent"></div>
                {{ isConfirming ? 'Processing...' : confirmButtonText }}
            </button>
        </template>
    </BaseModal>

    <!-- Success Modal -->
    <BaseModal :isOpen="isSuccessModalOpen" :title="successTitle" :showCancel="false" @close="closeSuccessModal">
        <div class="space-y-4">
            <div class="flex items-center gap-3 text-green-600 bg-green-50 p-3 rounded-xl border border-green-100">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
                <p class="text-sm font-bold">{{ successMessage }}</p>
            </div>
        </div>
        <template #footer>
            <button 
                @click="closeSuccessModal"
                class="inline-flex justify-center rounded-lg bg-gray-100 px-4 py-2 text-sm font-bold text-gray-900 hover:bg-gray-200 focus:outline-none transition-all"
            >
                Close
            </button>
        </template>
    </BaseModal>
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue';
import api from '../../api/axios';
import BaseModal from '../../components/BaseModal.vue';

const profileStatusOptions = ['DRAFT', 'PROFILE_FILLED', 'VERIFIED', 'REJECTED', 'BLACKLIST'];
const kycStatusOptions = ['NOT_STARTED', 'OTP_SENT', 'OTP_VERIFIED', 'FACE_PENDING', 'VERIFIED', 'FAILED'];

const operators = ref([]);
const loading = ref(false);
const search = ref('');
const activeTab = ref('profile'); // 'profile' | 'duties'
const duties = ref([]);
const loadingDuties = ref(false);
const selectedOperator = ref(null);
const isViewModalOpen = ref(false);

// Metrics
const totalOperatorsCount = ref(0);
const verifiedCount = ref(0);
const pendingCount = ref(0);
const activeToday = ref(0);

// Pagination & Filtering
const currentPage = ref(1);
const pageSize = ref(10);
const totalOperators = ref(0);
const profileStatusFilter = ref('');
const kycStatusFilter = ref('');

const showingStart = computed(() => totalOperators.value === 0 ? 0 : (currentPage.value - 1) * pageSize.value + 1);
const showingEnd = computed(() => Math.min(currentPage.value * pageSize.value, totalOperators.value));

const loadMetrics = async () => {
    try {
        // Parallel requests for metrics
        const [totalRes, verifiedRes, pendingRes] = await Promise.all([
            api.get('/identity/users/?user_type=OPERATOR&page_size=1'),
            api.get('/identity/users/?user_type=OPERATOR&operator_profile__kyc_status=VERIFIED&page_size=1'),
            api.get('/identity/users/?user_type=OPERATOR&operator_profile__kyc_status=FACE_PENDING&page_size=1')
        ]);
        
        totalOperatorsCount.value = totalRes.data.count || 0;
        verifiedCount.value = verifiedRes.data.count || 0; 
        pendingCount.value = pendingRes.data.count || 0;
        
        // For 'Active Today', we'll leave it as 0 for now as backend support is pending.
        activeToday.value = 0; 

    } catch (e) {
        console.error("Failed to load metrics", e);
    }
};

const loadOperators = async (page = 1) => {
    loading.value = true;
    try {
        let url = `/identity/users/?user_type=OPERATOR&page=${page}&page_size=${pageSize.value}`;
        
        if (search.value) {
            url += `&search=${search.value}`;
        }
        if (profileStatusFilter.value) {
            url += `&operator_profile__profile_status=${profileStatusFilter.value}`;
        }
        if (kycStatusFilter.value) {
            url += `&operator_profile__kyc_status=${kycStatusFilter.value}`;
        }

        const res = await api.get(url);
        operators.value = res.data.results || [];
        totalOperators.value = res.data.count || 0;
        currentPage.value = page;
    } catch (e) {
        console.error("Failed to load operators", e);
        operators.value = [];
        totalOperators.value = 0;
    } finally {
        loading.value = false;
    }
};

onMounted(() => {
    loadOperators();
    loadMetrics();
});

let searchTimeout;
const handleSearch = () => {
    clearTimeout(searchTimeout);
    searchTimeout = setTimeout(() => {
        loadOperators(1);
    }, 300);
};

const handleFilterChange = () => {
    loadOperators(1);
};

const nextPage = () => {
    if (currentPage.value * pageSize.value < totalOperators.value) {
        loadOperators(currentPage.value + 1);
    }
};

const prevPage = () => {
    if (currentPage.value > 1) {
        loadOperators(currentPage.value - 1);
    }
};



const switchTab = (tab) => {
    console.log("Switching tab to:", tab);
    activeTab.value = tab;
};

const isRequestModalOpen = ref(false);
const newOperatorMobile = ref('');
const newOperatorName = ref('');
const requesting = ref(false);
const requestError = ref('');

const isBulkModalOpen = ref(false);
const bulkRequesting = ref(false);
const bulkError = ref('');
const bulkResult = ref(null);
const selectedOperatorFile = ref(null);
const operatorFileInput = ref(null);

const loadDuties = async (operatorId) => {
    loadingDuties.value = true;
    try {
        const res = await api.get(`/assignments/?operator=${operatorId}`);
        const data = res.data.results || res.data;
        duties.value = Array.isArray(data) ? data : [];
    } catch (e) {
        console.error("Failed to load duties", e);
        duties.value = [];
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


onMounted(() => {
    loadOperators();
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

const formatDate = (dateString, fallback = 'N/A') => {
    if (!dateString) return fallback;
    const date = new Date(dateString);
    if (isNaN(date.getTime())) return fallback;
    return date.toLocaleDateString();
};

const closeViewModal = () => {
    isViewModalOpen.value = false;
    selectedOperator.value = null;
};

const openRequestModal = () => {
    isRequestModalOpen.value = true;
    newOperatorMobile.value = '';
    newOperatorName.value = '';
    requestError.value = '';
};

const closeRequestModal = () => {
    isRequestModalOpen.value = false;
};

const openBulkRequestModal = () => {
    isBulkModalOpen.value = true;
    selectedOperatorFile.value = null;
    bulkError.value = '';
    bulkResult.value = null;
    if (operatorFileInput.value) operatorFileInput.value.value = '';
};

const closeBulkModal = () => {
    isBulkModalOpen.value = false;
};

const handleOperatorFileChange = (e) => {
    selectedOperatorFile.value = e.target.files[0];
};

const downloadOperatorTemplate = async () => {
    try {
        const response = await api.get('/identity/users/download-operator-template/', {
            responseType: 'blob'
        });
        const url = window.URL.createObjectURL(new Blob([response.data]));
        const link = document.createElement('a');
        link.href = url;
        link.setAttribute('download', 'operator_bulk_template.csv');
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        window.URL.revokeObjectURL(url);
    } catch (e) {
        console.error("Failed to download template", e);
        alert("Failed to download template. Please check your connection.");
    }
};

const submitBulkRequest = async () => {
    if (!selectedOperatorFile.value) return;
    
    const formData = new FormData();
    formData.append('file', selectedOperatorFile.value);

    bulkRequesting.value = true;
    bulkError.value = '';
    bulkResult.value = null;
    try {
        const res = await api.post('/identity/users/bulk_request_operator/', formData, {
            headers: {
                'Content-Type': 'multipart/form-data'
            }
        });
        bulkResult.value = res.data;
        await loadOperators();
        if (res.data.errors.length === 0 && res.data.skipped.length === 0) {
            setTimeout(() => {
                closeBulkModal();
                openSuccessModal('Bulk Request Sent', `Successfully requested ${res.data.created.length} operators.`);
            }, 1000);
        }
    } catch (e) {
        bulkError.value = e.response?.data?.detail || "Failed to process bulk request. Ensure it is a valid CSV.";
    } finally {
        bulkRequesting.value = false;
    }
};

const submitOperatorRequest = async () => {
    if (!newOperatorMobile.value) return;
    
    // Indian mobile regex: 10 digits starting with 6-9
    const mobileRegex = /^[6789]\d{9}$/;
    const normalizedMobile = newOperatorMobile.value.replace(/\D/g, '').slice(-10);
    
    if (!mobileRegex.test(normalizedMobile)) {
        requestError.value = "Please enter a valid 10-digit Indian mobile number starting with 6-9.";
        return;
    }

    requesting.value = true;
    requestError.value = '';
    try {
        await api.post('/identity/users/request_operator/', { 
            mobile: normalizedMobile,
            name: newOperatorName.value 
        });
        closeRequestModal();
        await loadOperators();
        openSuccessModal('Request Sent', "Operator request sent successfully!");
    } catch (e) {
        requestError.value = e.response?.data?.detail || "Failed to send request. Please check the mobile number.";
    } finally {
        requesting.value = false;
    }
};

const isConfirmModalOpen = ref(false);
const confirmTitle = ref('');
const confirmMessage = ref('');
const confirmButtonText = ref('Confirm');
const confirmButtonClass = ref('');
const isConfirming = ref(false);
let onConfirm = null;

const closeConfirmModal = () => {
    isConfirmModalOpen.value = false;
    onConfirm = null;
};

const handleConfirm = async () => {
    if (!onConfirm) return;
    
    isConfirming.value = true;
    try {
        await onConfirm();
        closeConfirmModal();
    } catch (e) {
        console.error("Confirmation action failed", e);
        // Optional: show error toast or keep modal open with error
    } finally {
        isConfirming.value = false;
    }
};

const openConfirmModal = ({ title, message, buttonText, buttonClass, action }) => {
    confirmTitle.value = title;
    confirmMessage.value = message;
    confirmButtonText.value = buttonText || 'Confirm';
    confirmButtonClass.value = buttonClass || 'bg-blue-600 text-white hover:bg-blue-700';
    onConfirm = action;
    isConfirmModalOpen.value = true;
};

const blockUser = (user) => {
    const isBlocked = user.status === 'BLACKLIST';
    const action = isBlocked ? 'Unblock' : 'Block';
    const newStatus = isBlocked ? 'ACTIVE' : 'BLACKLIST';
    
    openConfirmModal({
        title: `${action} Operator`,
        message: `Are you sure you want to ${action.toLowerCase()} ${user.full_name || user.username}?`,
        buttonText: action,
        buttonClass: isBlocked ? 'bg-green-600 text-white hover:bg-green-700' : 'bg-orange-600 text-white hover:bg-orange-700',
        action: async () => {
            await api.patch(`/identity/users/${user.uid}/`, { status: newStatus });
            await loadOperators();
        }
    });
};

const isSuccessModalOpen = ref(false);
const successTitle = ref('');
const successMessage = ref('');

const closeSuccessModal = () => {
    isSuccessModalOpen.value = false;
};

const openSuccessModal = (title, message) => {
    successTitle.value = title;
    successMessage.value = message;
    isSuccessModalOpen.value = true;
};

const deleteUser = (user) => {
    openConfirmModal({
        title: 'Delete Operator',
        message: `Are you sure you want to PERMANENTLY delete ${user.full_name || user.username}? This cannot be undone.`,
        buttonText: 'Delete Operator',
        buttonClass: 'bg-red-600 text-white hover:bg-red-700',
        action: async () => {
            await api.delete(`/identity/users/${user.uid}/`);
            await loadOperators();
        }
    });
};

onMounted(loadOperators);
</script>
