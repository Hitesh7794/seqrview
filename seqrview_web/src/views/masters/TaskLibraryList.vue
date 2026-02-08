<template>
  <div class="space-y-6">
    <div class="flex justify-between items-center bg-white p-6 rounded-2xl shadow-sm border border-gray-100">
      <div>
        <h1 class="text-2xl font-black text-gray-900 tracking-tight">Task Library</h1>
        <p class="text-sm text-gray-500 mt-1">Manage global reusable tasks for standard operating procedures.</p>
      </div>
      <button 
        @click="openModal()"
        class="flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white rounded-xl text-sm font-bold hover:bg-indigo-700 transition-all shadow-sm"
      >
        <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
        </svg>
        Add New Task
      </button>
    </div>

    <div class="bg-white rounded-2xl shadow-sm border border-gray-100 overflow-hidden">
        <div v-if="loading" class="p-8 text-center text-gray-500 animate-pulse">
            Loading tasks...
        </div>
        <table v-else class="min-w-full divide-y divide-gray-100">
            <thead class="bg-gray-50/50">
                <tr>
                    <th class="px-6 py-4 text-left text-[10px] font-black uppercase tracking-widest text-gray-500">Task Name</th>
                    <th class="px-6 py-4 text-left text-[10px] font-black uppercase tracking-widest text-gray-500">Description</th>
                    <th class="px-6 py-4 text-left text-[10px] font-black uppercase tracking-widest text-gray-500">Created At</th>
                    <th class="px-6 py-4 text-right text-[10px] font-black uppercase tracking-widest text-gray-500">Actions</th>
                </tr>
            </thead>
            <tbody class="divide-y divide-gray-100 bg-white">
                <tr v-for="task in tasks" :key="task.uid" class="hover:bg-indigo-50/20 transition-colors group">
                    <td class="px-6 py-4">
                        <div class="font-bold text-gray-900">{{ task.name }}</div>
                        <span class="inline-flex items-center rounded-md bg-gray-50 px-2 py-1 text-xs font-medium text-gray-600 ring-1 ring-inset ring-gray-500/10 mt-1">
                            {{ task.task_type }}
                        </span>
                    </td>
                    <td class="px-6 py-4 text-sm text-gray-600">
                        {{ task.description || '-' }}
                    </td>
                    <td class="px-6 py-4 text-xs text-gray-400 tabular-nums">
                        {{ new Date(task.created_at).toLocaleDateString() }}
                    </td>
                    <td class="px-6 py-4 text-right">
                        <button 
                            @click="openModal(task)"
                            class="text-indigo-600 hover:text-indigo-800 text-sm font-bold mr-3"
                        >
                            Edit
                        </button>
                         <button 
                            @click="deleteTask(task)"
                            class="text-red-500 hover:text-red-700 text-sm font-bold"
                        >
                            Delete
                        </button>
                    </td>
                </tr>
                <tr v-if="tasks.length === 0">
                    <td colspan="4" class="px-6 py-12 text-center text-gray-400 italic">
                        No tasks in the library. Create one to be used in exam configuration.
                    </td>
                </tr>
            </tbody>
        </table>
    </div>

    <!-- Add/Edit Modal -->
    <BaseModal :isOpen="isModalOpen" :title="editingTask ? 'Edit Task' : 'Create New Task'" @close="closeModal">
        <form @submit.prevent="saveTask" class="space-y-4">
            <div>
                <label class="block text-xs font-black text-gray-400 uppercase tracking-widest mb-1">Task Name</label>
                <input v-model="form.name" type="text" required class="w-full px-4 py-2 bg-gray-50 border-none rounded-xl text-sm focus:ring-2 focus:ring-indigo-500" placeholder="e.g. Verify Admit Card">
                <p class="text-[10px] text-gray-400 mt-1">Must be unique across the system.</p>
            </div>

            <div>
                <label class="block text-xs font-black text-gray-400 uppercase tracking-widest mb-1">Task Type</label>
                <select v-model="form.task_type" class="w-full px-4 py-2 bg-gray-50 border-none rounded-xl text-sm focus:ring-2 focus:ring-indigo-500">
                    <option value="CHECKLIST">Checklist</option>
                    <option value="PHOTO">Photo</option>
                    <option value="VIDEO">Video</option>
                </select>
            </div>

            <div>
                <label class="block text-xs font-black text-gray-400 uppercase tracking-widest mb-1">Description</label>
                <textarea v-model="form.description" rows="3" class="w-full px-4 py-2 bg-gray-50 border-none rounded-xl text-sm focus:ring-2 focus:ring-indigo-500" placeholder="Detailed instructions for this task..."></textarea>
            </div>

            <div v-if="error" class="p-3 bg-red-50 text-red-600 text-xs rounded-lg border border-red-100">
                {{ error }}
            </div>

            <div class="flex justify-end gap-3 pt-4">
                <button type="button" @click="closeModal" class="px-4 py-2 text-gray-500 text-sm font-bold hover:bg-gray-100 rounded-lg transition-colors">Cancel</button>
                <button type="submit" :disabled="saving" class="px-6 py-2 bg-indigo-600 text-white text-sm font-bold rounded-lg hover:bg-indigo-700 transition-colors disabled:opacity-50">
                    {{ saving ? 'Saving...' : (editingTask ? 'Update Task' : 'Create Task') }}
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

const tasks = ref([]);
const loading = ref(false);
const isModalOpen = ref(false);
const editingTask = ref(null);
const saving = ref(false);
const error = ref('');

const form = ref({
    name: '',
    description: ''
});

const loadTasks = async () => {
    loading.value = true;
    try {
        const res = await api.get('/masters/task-library/');
        tasks.value = res.data.results || res.data;
    } catch (e) {
        console.error("Failed to load tasks", e);
    } finally {
        loading.value = false;
    }
};

const openModal = (task = null) => {
    error.value = '';
    if (task) {
        editingTask.value = task;
        form.value = { ...task };
    } else {
        editingTask.value = null;
        form.value = {
            name: '',
            description: '',
            task_type: 'CHECKLIST'
        };
    }
    isModalOpen.value = true;
};

const closeModal = () => {
    isModalOpen.value = false;
    editingTask.value = null;
};

const saveTask = async () => {
    saving.value = true;
    error.value = '';
    try {
        if (editingTask.value) {
            await api.patch(`/masters/task-library/${editingTask.value.uid}/`, form.value);
        } else {
            await api.post('/masters/task-library/', form.value);
        }
        await loadTasks();
        closeModal();
    } catch (e) {
        error.value = e.response?.data?.detail || "Failed to save task. Ensure name is unique.";
    } finally {
        saving.value = false;
    }
};

const deleteTask = async (task) => {
    if (!confirm(`Are you sure you want to delete '${task.name}'?`)) return;
    try {
        await api.delete(`/masters/task-library/${task.uid}/`);
        await loadTasks();
    } catch (e) {
        alert("Failed to delete task. It may be in use.");
    }
};

onMounted(loadTasks);
</script>
