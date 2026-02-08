<template>
  <div class="space-y-6">
    <!-- Header & Actions -->
    <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
      <div>
        <h1 class="text-2xl font-bold text-gray-800">Client Management</h1>
        <p class="text-sm text-gray-500">Manage your organization clients and their details.</p>
      </div>
      <div class="flex items-center gap-3">
        <div class="relative">
          <input 
            v-model="searchQuery" 
            type="text" 
            placeholder="Search clients..." 
            class="pl-10 pr-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 w-full sm:w-64 text-sm"
          >
          <span class="absolute left-3 top-2.5 text-gray-400">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
            </svg>
          </span>
        </div>
        <button @click="openModal()" class="flex items-center px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg shadow transition-colors text-sm font-medium">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
          </svg>
          Add Client
        </button>
      </div>
    </div>

    <!-- Client Table -->
    <div class="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Client Name</th>
              <th class="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Code</th>
              <th class="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Contact</th>
              <th class="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Username</th>
              <th class="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Password</th>
              <th class="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Status</th>
              <th class="px-6 py-3 text-right text-xs font-semibold text-gray-500 uppercase tracking-wider">Actions</th>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <tr v-for="client in filteredClients" :key="client.uid" class="hover:bg-gray-50 transition-colors">
              <td class="px-6 py-4 whitespace-nowrap">
                <div class="flex items-center">
                  <div class="h-10 w-10 flex-shrink-0 bg-indigo-100 rounded-lg flex items-center justify-center text-indigo-600 font-bold border border-indigo-200">
                    {{ client.name.charAt(0).toUpperCase() }}
                  </div>
                  <div class="ml-4">
                    <div class="text-sm font-medium text-gray-900">{{ client.name }}</div>
                    <div class="text-sm text-gray-500 truncate max-w-xs">{{ client.address_line1 || client.city }}</div>
                  </div>
                </div>
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <span class="px-2.5 py-0.5 inline-flex text-xs leading-5 font-semibold rounded-md bg-gray-100 text-gray-800 border border-gray-200">
                  {{ client.client_code }}
                </span>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                <div class="flex items-center">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 mr-1 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" /></svg>
                  {{ client.primary_contact_email }}
                </div>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                <span class="font-mono text-xs bg-gray-50 px-2 py-1 rounded border">{{ client.admin_username || '-' }}</span>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                <span class="font-mono text-xs text-indigo-600 font-bold bg-indigo-50 px-2 py-1 rounded border border-indigo-100 select-all">{{ client.admin_password || '-' }}</span>
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full bg-green-100 text-green-800">
                  Active
                </span>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                <button @click="$router.push(`/masters/clients/${client.uid}/exams`)" class="text-blue-600 hover:text-blue-900 mr-3 font-bold">Exams</button>
                <button @click="openModal(client)" class="text-indigo-600 hover:text-indigo-900 mr-3">Edit</button>
                <button @click="deleteClient(client.uid)" class="text-red-600 hover:text-red-900">Delete</button>
              </td>
            </tr>
            <tr v-if="filteredClients.length === 0">
              <td colspan="5" class="px-6 py-10 text-center text-gray-500">
                No clients found matching your search.
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Add/Edit Modal -->
    <BaseModal :isOpen="isModalOpen" :title="isEditing ? 'Edit Client' : 'Add New Client'" @close="closeModal">
      <form @submit.prevent="saveClient" class="space-y-4">
        <div>
          <label class="block text-sm font-medium text-gray-700">Client Name</label>
          <input v-model="form.name" type="text" required class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm border p-2">
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700">Client Code</label>
          <input v-model="form.client_code" type="text" required class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm border p-2">
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700">Email Address</label>
          <input v-model="form.primary_contact_email" type="email" required class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm border p-2">
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700">Address</label>
          <textarea v-model="form.address_line1" rows="3" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm border p-2"></textarea>
        </div>
        
        <div class="flex justify-end pt-4">
          <button type="submit" class="inline-flex justify-center rounded-lg border border-transparent bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700 focus:outline-none focus-visible:ring-2 focus-visible:ring-indigo-500 focus-visible:ring-offset-2">
            {{ isEditing ? 'Update Client' : 'Create Client' }}
          </button>
        </div>
      </form>
    </BaseModal>

    <!-- Credentials Modal -->
    <BaseModal :isOpen="showCredentialsModal" title="Client Created Successfully" @close="closeCredentialsModal">
        <div class="space-y-4">
            <div class="bg-green-50 p-4 rounded-lg border border-green-100">
                <p class="text-sm text-green-800 mb-2">A Client Admin user has been automatically created.</p>
                <div class="space-y-2">
                    <div class="flex justify-between items-center bg-white p-2 rounded border border-green-200">
                        <span class="text-xs font-semibold text-gray-500 uppercase">Username</span>
                        <code class="text-sm font-bold text-gray-800">{{ createdCredentials.username }}</code>
                    </div>
                    <div class="flex justify-between items-center bg-white p-2 rounded border border-green-200">
                        <span class="text-xs font-semibold text-gray-500 uppercase">Password</span>
                        <code class="text-sm font-bold text-indigo-600">{{ createdCredentials.password }}</code>
                    </div>
                </div>
                <p class="text-xs text-green-600 mt-2">Please copy these credentials now. The password cannot be viewed again.</p>
            </div>
            
            <div class="flex justify-end pt-2">
                <button type="button" class="inline-flex justify-center rounded-lg bg-indigo-600 px-4 py-2 text-sm font-medium text-white hover:bg-indigo-700" @click="closeCredentialsModal">
                   Done
                </button>
            </div>
        </div>
    </BaseModal>
  </div>
</template>

<script setup>
import { ref, onMounted, computed, reactive } from 'vue';
import api from '../../api/axios';
import BaseModal from '../../components/BaseModal.vue';

const clients = ref([]);
const searchQuery = ref('');
const isModalOpen = ref(false);
const isEditing = ref(false);
const editingId = ref(null);
const showCredentialsModal = ref(false);
const createdCredentials = ref({ username: '', password: '' });

const form = reactive({
  name: '',
  client_code: '',
  primary_contact_email: '',
  address_line1: ''
});

const filteredClients = computed(() => {
  if (!searchQuery.value) return clients.value;
  const q = searchQuery.value.toLowerCase();
  return clients.value.filter(c => 
    c.name.toLowerCase().includes(q) || 
    c.client_code?.toLowerCase().includes(q) ||
    c.primary_contact_email?.toLowerCase().includes(q)
  );
});

const loadClients = async () => {
    try {
        const res = await api.get('/masters/clients/');
        clients.value = res.data.results || res.data;
    } catch (e) {
        console.error("Failed to load clients", e);
    }
};

onMounted(loadClients);

const openModal = (client = null) => {
  if (client) {
    isEditing.value = true;
    editingId.value = client.uid;
    form.name = client.name;
    form.client_code = client.client_code;
    form.primary_contact_email = client.primary_contact_email;
    form.address_line1 = client.address_line1 || client.address; // Handle potential legacy or mapped data
  } else {
    isEditing.value = false;
    editingId.value = null;
    form.name = '';
    form.client_code = '';
    form.primary_contact_email = '';
    form.address_line1 = '';
  }
  isModalOpen.value = true;
};

const closeModal = () => {
  isModalOpen.value = false;
};

const closeCredentialsModal = () => {
    showCredentialsModal.value = false;
    createdCredentials.value = { username: '', password: '' };
};

const saveClient = async () => {
    try {
        if (isEditing.value) {
            await api.patch(`/masters/clients/${editingId.value}/`, form);
            closeModal();
        } else {
            const res = await api.post('/masters/clients/', form);
            closeModal();
            // Show credentials if returned
            if (res.data.generated_credentials) {
                createdCredentials.value = res.data.generated_credentials;
                showCredentialsModal.value = true;
            }
        }
        await loadClients();
    } catch (e) {
        console.error("Failed to save client", e);
        alert("Failed to save client. Please check the inputs.");
    }
};

const deleteClient = async (uid) => {
    if (!confirm('Are you sure you want to delete this client?')) return;
    try {
        await api.delete(`/masters/clients/${uid}/`);
        await loadClients();
    } catch (e) {
        console.error("Failed to delete client", e);
        alert("Failed to delete client.");
    }
};
</script>
