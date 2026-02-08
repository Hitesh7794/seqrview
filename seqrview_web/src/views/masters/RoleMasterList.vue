<template>
  <div class="space-y-6">
    <div class="flex justify-between items-center bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
      <div>
        <h1 class="text-2xl font-black text-gray-900 tracking-tight">Role Management</h1>
        <p class="text-sm text-gray-500 mt-1">Define roles and responsibilities for exam workforce.</p>
      </div>
      <button 
        @click="openModal()"
        class="flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white rounded-xl text-sm font-bold hover:bg-indigo-700 transition-all shadow-sm"
      >
        <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
        </svg>
        Add New Role
      </button>
    </div>

    <div class="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
        <div v-if="loading" class="p-8 text-center text-gray-500 animate-pulse">
            Loading roles...
        </div>
        <table v-else class="min-w-full divide-y divide-gray-100">
            <thead class="bg-gray-50/50">
                <tr>
                    <th class="px-6 py-4 text-left text-[10px] font-black uppercase tracking-widest text-gray-500">Role Name</th>
                    <th class="px-6 py-4 text-left text-[10px] font-black uppercase tracking-widest text-gray-500">Code</th>
                    <th class="px-6 py-4 text-left text-[10px] font-black uppercase tracking-widest text-gray-500">Gender Req</th>
                    <th class="px-6 py-4 text-left text-[10px] font-black uppercase tracking-widest text-gray-500">Default Pay</th>
                    <th class="px-6 py-4 text-right text-[10px] font-black uppercase tracking-widest text-gray-500">Actions</th>
                </tr>
            </thead>
            <tbody class="divide-y divide-gray-100 bg-white">
                <tr v-for="role in roles" :key="role.uid" class="hover:bg-indigo-50/20 transition-colors group">
                    <td class="px-6 py-4">
                        <div class="font-bold text-gray-900">{{ role.name }}</div>
                        <div class="text-xs text-gray-400 mt-0.5">{{ role.description || 'No description' }}</div>
                    </td>
                    <td class="px-6 py-4 text-sm font-mono text-gray-600 bg-gray-50 rounded-md py-1 px-2 inline-block my-3 mx-6 w-fit">
                        {{ role.code }}
                    </td>
                    <td class="px-6 py-4 text-sm font-medium text-gray-600">
                        {{ role.gender_requirement }}
                    </td>
                    <td class="px-6 py-4 text-sm font-medium text-gray-900">
                        ₹{{ role.default_pay_rate || '0.00' }}
                    </td>
                    <td class="px-6 py-4 text-right">
                        <button 
                            @click="openModal(role)"
                            class="text-indigo-600 hover:text-indigo-800 text-sm font-bold mr-3"
                        >
                            Edit
                        </button>
                    </td>
                </tr>
                <tr v-if="roles.length === 0">
                    <td colspan="5" class="px-6 py-12 text-center text-gray-400 italic">
                        No roles defined yet. Create one to get started.
                    </td>
                </tr>
            </tbody>
        </table>
    </div>

    <!-- Add/Edit Modal -->
    <BaseModal :isOpen="isModalOpen" :title="editingRole ? 'Edit Role' : 'Create New Role'" @close="closeModal">
        <form @submit.prevent="saveRole" class="space-y-4">
            <div>
                <label class="block text-xs font-black text-gray-400 uppercase tracking-widest mb-1">Role Name</label>
                <input v-model="form.name" type="text" required class="w-full px-4 py-2 bg-gray-50 border-none rounded-xl text-sm focus:ring-2 focus:ring-indigo-500" placeholder="e.g. Invigilator">
            </div>
            
            <div>
                <label class="block text-xs font-black text-gray-400 uppercase tracking-widest mb-1">Role Code (Unique)</label>
                <input v-model="form.code" type="text" required class="w-full px-4 py-2 bg-gray-50 border-none rounded-xl text-sm focus:ring-2 focus:ring-indigo-500" placeholder="e.g. INVIGILATOR">
                <p class="text-[10px] text-gray-400 mt-1">Used for system logic. Cannot be duplicates.</p>
            </div>

            <div>
                <label class="block text-xs font-black text-gray-400 uppercase tracking-widest mb-1">Description</label>
                <textarea v-model="form.description" rows="2" class="w-full px-4 py-2 bg-gray-50 border-none rounded-xl text-sm focus:ring-2 focus:ring-indigo-500" placeholder="Brief description of responsibilities..."></textarea>
            </div>

            <div class="grid grid-cols-2 gap-4">
                <div>
                     <label class="block text-xs font-black text-gray-400 uppercase tracking-widest mb-1">Gender Req</label>
                     <select v-model="form.gender_requirement" class="w-full px-4 py-2 bg-gray-50 border-none rounded-xl text-sm focus:ring-2 focus:ring-indigo-500">
                         <option value="ALL">All / Any</option>
                         <option value="MALE">Male Only</option>
                         <option value="FEMALE">Female Only</option>
                     </select>
                </div>
                <div>
                     <label class="block text-xs font-black text-gray-400 uppercase tracking-widest mb-1">Default Pay (₹)</label>
                     <input v-model="form.default_pay_rate" type="number" step="0.01" class="w-full px-4 py-2 bg-gray-50 border-none rounded-xl text-sm focus:ring-2 focus:ring-indigo-500" placeholder="0.00">
                </div>
            </div>

            <div v-if="error" class="p-3 bg-red-50 text-red-600 text-xs rounded-lg border border-red-100">
                {{ error }}
            </div>

            <div class="flex justify-end gap-3 pt-4">
                <button type="button" @click="closeModal" class="px-4 py-2 text-gray-500 text-sm font-bold hover:bg-gray-100 rounded-lg transition-colors">Cancel</button>
                <button type="submit" :disabled="saving" class="px-6 py-2 bg-indigo-600 text-white text-sm font-bold rounded-lg hover:bg-indigo-700 transition-colors disabled:opacity-50">
                    {{ saving ? 'Saving...' : (editingRole ? 'Update Role' : 'Create Role') }}
                </button>
            </div>
        </form>
    </BaseModal>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import api from '../../api/axios';
import BaseModal from '../../components/BaseModal.vue';

const roles = ref([]);
const loading = ref(false);
const isModalOpen = ref(false);
const editingRole = ref(null);
const saving = ref(false);
const error = ref('');

const form = ref({
    name: '',
    code: '',
    description: '',
    gender_requirement: 'ALL',
    default_pay_rate: ''
});

const loadRoles = async () => {
    loading.value = true;
    try {
        const res = await api.get('/masters/roles/');
        roles.value = res.data.results || res.data;
    } catch (e) {
        console.error("Failed to load roles", e);
    } finally {
        loading.value = false;
    }
};

const openModal = (role = null) => {
    error.value = '';
    if (role) {
        editingRole.value = role;
        form.value = { ...role };
    } else {
        editingRole.value = null;
        form.value = {
            name: '',
            code: '',
            description: '',
            gender_requirement: 'ALL',
            default_pay_rate: ''
        };
    }
    isModalOpen.value = true;
};

const closeModal = () => {
    isModalOpen.value = false;
    editingRole.value = null;
};

const saveRole = async () => {
    saving.value = true;
    error.value = '';
    try {
        if (editingRole.value) {
            await api.patch(`/masters/roles/${editingRole.value.uid}/`, form.value);
        } else {
            await api.post('/masters/roles/', form.value);
        }
        await loadRoles();
        closeModal();
    } catch (e) {
        error.value = e.response?.data?.detail || "Failed to save role. Ensure code is unique.";
    } finally {
        saving.value = false;
    }
};

onMounted(loadRoles);
</script>
