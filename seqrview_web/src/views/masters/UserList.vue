<template>
  <div class="space-y-6">
    <!-- Header & Actions -->
    <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
      <div>
        <h1 class="text-2xl font-bold text-gray-800">User Management</h1>
        <p class="text-sm text-gray-500">Manage system users, operators, and administrators.</p>
      </div>
      <div class="flex items-center gap-3">
        <div class="relative">
          <input 
            v-model="searchQuery" 
            type="text" 
            placeholder="Search users..." 
            class="pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500 w-full sm:w-64 text-sm"
          >
          <span class="absolute left-3 top-2.5 text-gray-400">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
            </svg>
          </span>
        </div>
        <button @click="openModal()" class="flex items-center px-4 py-2 bg-purple-600 hover:bg-purple-700 text-white rounded-lg shadow transition-colors text-sm font-medium">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
          </svg>
          Add User
        </button>
      </div>
    </div>

    <!-- Stats Grid -->
    <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
      <div class="bg-white rounded-xl shadow-sm p-6 border border-gray-100 relative overflow-hidden">
        <div class="absolute right-0 top-0 h-24 w-24 bg-purple-50 rounded-bl-full -mr-4 -mt-4 transition-transform hover:scale-110"></div>
        <div class="relative z-10">
          <div class="text-gray-500 text-sm font-medium uppercase tracking-wider mb-1">Total Users</div>
          <div class="text-3xl font-bold text-gray-800">{{ users.length }}</div>
          <div class="mt-2 flex items-center text-xs text-green-600 font-medium">
            <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6"></path></svg>
            <span>Updated just now</span>
          </div>
        </div>
      </div>

      <div class="bg-white rounded-xl shadow-sm p-6 border border-gray-100 relative overflow-hidden">
        <div class="absolute right-0 top-0 h-24 w-24 bg-blue-50 rounded-bl-full -mr-4 -mt-4 transition-transform hover:scale-110"></div>
        <div class="relative z-10">
          <div class="text-gray-500 text-sm font-medium uppercase tracking-wider mb-1">Operators</div>
          <div class="text-3xl font-bold text-gray-800">{{ users.filter(u => u.user_type === 'OPERATOR').length }}</div>
          <div class="mt-2 text-xs text-blue-600 font-medium bg-blue-50 inline-block px-2 py-0.5 rounded-full">
            Field Staff
          </div>
        </div>
      </div>
      
      <div class="bg-white rounded-xl shadow-sm p-6 border border-gray-100 relative overflow-hidden">
        <div class="absolute right-0 top-0 h-24 w-24 bg-green-50 rounded-bl-full -mr-4 -mt-4 transition-transform hover:scale-110"></div>
        <div class="relative z-10">
          <div class="text-gray-500 text-sm font-medium uppercase tracking-wider mb-1">Active Accounts</div>
          <div class="text-3xl font-bold text-gray-800">{{ users.filter(u => u.status === 'ACTIVE').length }}</div>
          <div class="mt-2 text-xs text-gray-400">
             {{ users.length > 0 ? Math.round((users.filter(u => u.status === 'ACTIVE').length / users.length) * 100) : 0 }}% of total
          </div>
        </div>
      </div>

       <div class="bg-white rounded-xl shadow-sm p-6 border border-gray-100 relative overflow-hidden">
        <div class="absolute right-0 top-0 h-24 w-24 bg-orange-50 rounded-bl-full -mr-4 -mt-4 transition-transform hover:scale-110"></div>
        <div class="relative z-10">
          <div class="text-gray-500 text-sm font-medium uppercase tracking-wider mb-1">Pending Approval</div>
          <div class="text-3xl font-bold text-gray-800">{{ users.filter(u => u.status === 'PENDING_APPROVAL' || u.status === 'ONBOARDING').length }}</div>
          <div class="mt-2 text-xs text-orange-600 font-medium">
             Requires Action
          </div>
        </div>
      </div>
    </div>

    <!-- Users Table Card -->
    <div class="bg-white rounded-xl shadow-lg border border-gray-100 overflow-hidden">
      <!-- Table Filter Header -->
      <div class="p-5 border-b border-gray-100 bg-gray-50/50 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div class="flex items-center gap-2">
               <div class="bg-white border border-gray-300 rounded-lg px-3 py-2 flex items-center shadow-sm focus-within:ring-2 focus-within:ring-purple-500 focus-within:border-purple-500 transition-all">
                  <svg class="h-4 w-4 text-gray-400 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" /></svg>
                  <input v-model="searchQuery" type="text" placeholder="Search by name, email..." class="text-sm border-none focus:ring-0 w-48 sm:w-64">
               </div>
               
               <select class="bg-white border border-gray-300 text-gray-700 text-sm rounded-lg focus:ring-purple-500 focus:border-purple-500 block p-2 shadow-sm">
                   <option>All Roles</option>
                   <option>Operator</option>
                   <option>Admin</option>
               </select>
          </div>
          
          <button @click="openModal()" class="flex items-center justify-center px-4 py-2 bg-gray-900 hover:bg-black text-white rounded-lg shadow-md transition-all transform hover:-translate-y-0.5 text-sm font-medium">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
              </svg>
              Add New User
          </button>
      </div>

      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-100">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left">
                  <input type="checkbox" class="rounded border-gray-300 text-purple-600 shadow-sm focus:border-purple-300 focus:ring focus:ring-purple-200 focus:ring-opacity-50">
              </th>
              <th class="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">User Details</th>
              <th class="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Role</th>
              <th class="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Contact Info</th>
              <th class="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Status</th>
              <th class="px-6 py-3 text-right text-xs font-semibold text-gray-500 uppercase tracking-wider">Actions</th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-50">
            <tr v-for="user in filteredUsers" :key="user.uid" class="hover:bg-purple-50/30 transition-colors group">
              <td class="px-6 py-4 whitespace-nowrap">
                   <input type="checkbox" class="rounded border-gray-300 text-purple-600 shadow-sm focus:border-purple-300 focus:ring focus:ring-purple-200 focus:ring-opacity-50">
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <div class="flex items-center">
                  <div class="h-9 w-9 flex-shrink-0">
                      <div class="h-9 w-9 rounded-full bg-gradient-to-tr from-purple-400 to-indigo-500 flex items-center justify-center text-white text-sm font-bold shadow-sm">
                          <img v-if="user.photo" :src="user.photo" class="h-full w-full rounded-full object-cover border-2 border-white">
                          <span v-else>{{ user.username.charAt(0).toUpperCase() }}</span>
                      </div>
                  </div>
                  <div class="ml-4">
                    <div class="text-sm font-semibold text-gray-900 group-hover:text-purple-700 transition-colors">{{ user.full_name || user.username }} <span v-if="!user.full_name" class="text-xs text-gray-400 font-normal">(No Name)</span></div>
                    <div class="text-xs text-gray-500">@{{ user.username }}</div>
                  </div>
                </div>
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <span class="px-2.5 py-1 inline-flex text-[10px] leading-tight font-bold uppercase tracking-wide rounded-full border"
                  :class="{
                    'bg-indigo-50 text-indigo-700 border-indigo-100': user.user_type === 'INTERNAL_ADMIN',
                    'bg-gray-100 text-gray-600 border-gray-200': user.user_type === 'OPERATOR',
                    'bg-teal-50 text-teal-700 border-teal-100': user.user_type === 'CLIENT_ADMIN',
                    'bg-pink-50 text-pink-700 border-pink-100': user.user_type === 'CLIENT_VIEWER'
                  }">
                  {{ formatUserType(user.user_type) }}
                </span>
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <div class="flex flex-col space-y-1">
                    <div v-if="user.email" class="flex items-center text-xs text-gray-600">
                        <svg class="w-3 h-3 mr-1.5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"></path></svg>
                        {{ user.email }}
                    </div>
                    <div v-if="user.mobile_primary" class="flex items-center text-xs text-gray-600">
                        <svg class="w-3 h-3 mr-1.5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 18h.01M8 21h8a2 2 0 002-2V5a2 2 0 00-2-2H8a2 2 0 00-2 2v16a2 2 0 002 2z"></path></svg>
                        {{ user.mobile_primary }}
                    </div>
                    <span v-if="!user.email && !user.mobile_primary" class="text-xs text-gray-400 italic">No contact info</span>
                </div>
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <div class="flex items-center">
                    <span class="h-2.5 w-2.5 rounded-full mr-2"
                        :class="{
                            'bg-green-500': user.status === 'ACTIVE',
                            'bg-red-500': user.status === 'BLACKLIST' || user.status === 'REJECTED',
                            'bg-yellow-400': user.status === 'PENDING_APPROVAL' || user.status === 'ONBOARDING',
                            'bg-gray-400': user.status === 'INACTIVE'
                        }"></span>
                    <span class="text-xs font-medium text-gray-700">{{ formatStatus(user.status) }}</span>
                </div>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                <div class="flex items-center justify-end space-x-2">
                    <button @click="openModal(user)" class="p-1.5 text-gray-500 hover:text-indigo-600 hover:bg-indigo-50 rounded-md transition-colors" title="Edit">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"></path></svg>
                    </button>
                    <button @click="deleteUser(user.uid)" class="p-1.5 text-gray-500 hover:text-red-600 hover:bg-red-50 rounded-md transition-colors" title="Delete">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path></svg>
                    </button>
                </div>
              </td>
            </tr>
            <tr v-if="filteredUsers.length === 0">
              <td colspan="6" class="px-6 py-12 text-center">
                 <div class="flex flex-col items-center justify-center text-gray-400">
                    <svg class="w-12 h-12 mb-3 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"></path></svg>
                    <span class="text-base font-medium text-gray-500">No users found</span>
                    <span class="text-sm mt-1">Try adjusting your search terms</span>
                 </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Add/Edit Modal -->
    <BaseModal :isOpen="isModalOpen" :title="isEditing ? 'Edit User' : 'Add New User'" @close="closeModal">
      <form @submit.prevent="saveUser" class="space-y-4">
        <div class="grid grid-cols-2 gap-4">
            <div>
                <label class="block text-sm font-medium text-gray-700">Username <span class="text-red-500">*</span></label>
                <input v-model="form.username" type="text" required :disabled="isEditing" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-purple-500 focus:ring-purple-500 sm:text-sm border p-2 bg-white disabled:bg-gray-100">
            </div>
            <div>
                <label class="block text-sm font-medium text-gray-700">Password <span v-if="!isEditing" class="text-red-500">*</span></label>
                <input v-model="form.password" type="password" :required="!isEditing" placeholder="Leave blank to keep unchanged" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-purple-500 focus:ring-purple-500 sm:text-sm border p-2">
            </div>
        </div>

        <div class="grid grid-cols-2 gap-4">
             <div>
                <label class="block text-sm font-medium text-gray-700">First Name</label>
                <input v-model="form.first_name" type="text" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-purple-500 focus:ring-purple-500 sm:text-sm border p-2">
            </div>
            <div>
                <label class="block text-sm font-medium text-gray-700">Last Name</label>
                <input v-model="form.last_name" type="text" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-purple-500 focus:ring-purple-500 sm:text-sm border p-2">
            </div>
        </div>

        <div class="grid grid-cols-2 gap-4">
            <div>
                <label class="block text-sm font-medium text-gray-700">Email</label>
                <input v-model="form.email" type="email" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-purple-500 focus:ring-purple-500 sm:text-sm border p-2">
            </div>
             <div>
                <label class="block text-sm font-medium text-gray-700">Mobile</label>
                <input v-model="form.mobile_primary" type="text" maxlength="10" @input="form.mobile_primary = form.mobile_primary.replace(/\D/g, '')" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-purple-500 focus:ring-purple-500 sm:text-sm border p-2">
            </div>
        </div>

         <div class="grid grid-cols-2 gap-4">
            <div>
                <label class="block text-sm font-medium text-gray-700">User Type <span class="text-red-500">*</span></label>
                <select v-model="form.user_type" required class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-purple-500 focus:ring-purple-500 sm:text-sm border p-2">
                    <option value="OPERATOR">Operator</option>
                    <option value="INTERNAL_ADMIN">Internal Admin</option>
                    <option value="CLIENT_ADMIN">Client Admin</option>
                    <option value="CLIENT_VIEWER">Client Viewer</option>
                </select>
            </div>
            <div>
                <label class="block text-sm font-medium text-gray-700">Status</label>
                <select v-model="form.status" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-purple-500 focus:ring-purple-500 sm:text-sm border p-2">
                    <option value="ACTIVE">Active</option>
                    <option value="INACTIVE">Inactive</option>
                    <option value="BLACKLIST">Blacklist</option>
                    <option value="ONBOARDING">Onboarding</option>
                    <option value="PENDING_APPROVAL">Pending Approval</option>
                </select>
            </div>
        </div>

        <div class="flex justify-end pt-4">
          <button type="submit" class="inline-flex justify-center rounded-lg border border-transparent bg-purple-600 px-4 py-2 text-sm font-medium text-white hover:bg-purple-700 focus:outline-none focus:visible:ring-2 focus:visible:ring-purple-500 focus:visible:ring-offset-2">
            {{ isEditing ? 'Update User' : 'Create User' }}
          </button>
        </div>
      </form>
    </BaseModal>
  </div>
</template>

<script setup>
import { ref, onMounted, computed, reactive } from 'vue';
import api from '../../api/axios';
import BaseModal from '../../components/BaseModal.vue';

const users = ref([]);
const searchQuery = ref('');
const isModalOpen = ref(false);
const isEditing = ref(false);
const editingId = ref(null);

const form = reactive({
  username: '',
  password: '',
  first_name: '',
  last_name: '',
  email: '',
  mobile_primary: '',
  user_type: 'OPERATOR',
  status: 'ACTIVE'
});

const filteredUsers = computed(() => {
  if (!searchQuery.value) return users.value;
  const q = searchQuery.value.toLowerCase();
  return users.value.filter(u => 
    u.username.toLowerCase().includes(q) || 
    (u.full_name && u.full_name.toLowerCase().includes(q)) ||
    (u.email && u.email.toLowerCase().includes(q))
  );
});

const loadUsers = async () => {
  try {
    const res = await api.get('/identity/users/'); // Assuming this endpoint exists, or I need to create it.
    users.value = res.data.results || res.data;
  } catch (e) {
    console.error("Failed to load users", e);
    // If endpoint doesn't exist, we might get 404.
    // For now assuming the standard ViewSet is wired up.
  }
};

onMounted(loadUsers);

const formatUserType = (type) => {
    return type ? type.replace('_', ' ') : '';
};

const formatStatus = (status) => {
    return status ? status.toLowerCase().replace('_', ' ').replace(/\b\w/g, l => l.toUpperCase()) : '';
};

const openModal = (user = null) => {
  if (user) {
    isEditing.value = true;
    editingId.value = user.uid;
    form.username = user.username;
    form.password = ''; // Don't show password
    form.first_name = user.first_name;
    form.last_name = user.last_name;
    form.email = user.email;
    form.mobile_primary = user.mobile_primary;
    form.user_type = user.user_type;
    form.status = user.status;
  } else {
    isEditing.value = false;
    editingId.value = null;
    form.username = '';
    form.password = '';
    form.first_name = '';
    form.last_name = '';
    form.email = '';
    form.mobile_primary = '';
    form.user_type = 'OPERATOR';
    form.status = 'ACTIVE';
  }
  isModalOpen.value = true;
};

const closeModal = () => {
  isModalOpen.value = false;
};

const saveUser = async () => {
    try {
        const payload = { ...form };
        if (!payload.password) delete payload.password; // Don't send empty password on edit

        if (isEditing.value) {
            await api.patch(`/identity/users/${editingId.value}/`, payload);
        } else {
            await api.post('/identity/users/', payload);
        }
        await loadUsers();
        closeModal();
    } catch (e) {
        console.error("Failed to save user", e);
        alert("Failed to save user. Check validation errors.");
    }
};

const deleteUser = async (uid) => {
    if (!confirm('Are you sure you want to delete this user? This action cannot be undone.')) return;
    try {
        await api.delete(`/identity/users/${uid}/`);
        await loadUsers();
    } catch (e) {
        console.error("Failed to delete user", e);
        alert("Failed to delete user.");
    }
};
</script>
