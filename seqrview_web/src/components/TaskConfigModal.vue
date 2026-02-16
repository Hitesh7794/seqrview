<template>
  <BaseModal :isOpen="visible" :title="`Task Configuration - ${shiftCenterName || 'Center'}`" @close="$emit('close')" size="2xl">
    <div class="space-y-6">
      <!-- Status Message Card -->
      <transition enter-active-class="transition duration-300 ease-out" enter-from-class="transform scale-95 opacity-0" enter-to-class="transform scale-100 opacity-100" leave-active-class="transition duration-200 ease-in" leave-from-class="transform scale-100 opacity-100" leave-to-class="transform scale-95 opacity-0">
        <div v-if="statusMessage" :class="statusMessage.type === 'success' ? 'bg-green-50 border-green-200' : 'bg-red-50 border-red-200'" class="p-4 rounded-xl border flex items-center justify-between gap-3 shadow-sm">
          <div class="flex items-center gap-3">
              <div :class="statusMessage.type === 'success' ? 'bg-green-500' : 'bg-red-500'" class="p-1.5 rounded-lg text-white">
                  <svg v-if="statusMessage.type === 'success'" xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                  </svg>
                  <svg v-else xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                  </svg>
              </div>
              <p :class="statusMessage.type === 'success' ? 'text-green-800' : 'text-red-800'" class="text-xs font-bold">{{ statusMessage.text }}</p>
          </div>
          <button @click="statusMessage = null" class="text-gray-400 hover:text-gray-600">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
              </svg>
          </button>
        </div>
      </transition>

      <!-- Add Task Form -->
      <div class="bg-indigo-50 p-4 rounded-xl border border-indigo-100">
        <h3 class="text-sm font-bold text-indigo-900 mb-3 uppercase tracking-wide">Add New Task</h3>
        <form @submit.prevent="addTask" class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div class="col-span-2">
            <label class="block text-xs font-bold text-gray-500 uppercase tracking-widest mb-1">Task Name <span class="text-red-500">*</span></label>
            <input 
              v-model="newTask.task_name" 
              type="text" 
              required
              placeholder="e.g. Verify CCTV status"
              class="w-full rounded-lg border-gray-200 text-sm focus:ring-indigo-500 focus:border-indigo-500"
            >
          </div>
          
          <div>
             <label class="block text-xs font-bold text-gray-500 uppercase tracking-widest mb-1">Role <span class="text-red-500">*</span></label>
             <select v-model="newTask.role" required class="w-full rounded-lg border-gray-200 text-sm focus:ring-indigo-500 focus:border-indigo-500">
               <option v-for="role in roles" :key="role.uid" :value="role.uid">{{ role.name }}</option>
             </select>
          </div>

          <div>
             <label class="block text-xs font-bold text-gray-500 uppercase tracking-widest mb-1">Task Type <span class="text-red-500">*</span></label>
             <select v-model="newTask.task_type" required class="w-full rounded-lg border-gray-200 text-sm focus:ring-indigo-500 focus:border-indigo-500">
               <option value="CHECKLIST">Checklist (Yes/No)</option>
               <option value="PHOTO">Photo Upload</option>
               <option value="VIDEO">Video Upload</option>
             </select>
          </div>

          <div class="col-span-2 flex items-center gap-2">
            <input 
              id="is_mandatory" 
              v-model="newTask.is_mandatory" 
              type="checkbox" 
              class="rounded border-gray-300 text-indigo-600 focus:ring-indigo-500"
            >
            <label for="is_mandatory" class="text-sm text-gray-700 font-medium">Mark as Mandatory</label>
          </div>

          <div class="col-span-2 flex justify-end">
            <button 
              type="submit" 
              :disabled="adding"
              class="px-4 py-2 bg-indigo-600 text-white text-sm font-bold rounded-lg hover:bg-indigo-700 disabled:opacity-50 transition-colors shadow-sm"
            >
              {{ adding ? 'Adding...' : 'Add Task' }}
            </button>
          </div>
        </form>
      </div>

      <!-- Task List -->
      <div>
        <div class="flex items-center justify-between mb-2">
           <h3 class="text-sm font-bold text-gray-900 uppercase tracking-wide">Configuration List</h3>
           <span class="text-xs text-gray-500 font-medium bg-gray-100 px-2 py-1 rounded-full">{{ tasks.length }} Tasks</span>
        </div>
        
        <div v-if="loading" class="py-8 text-center text-gray-400">
           <div class="inline-block h-6 w-6 animate-spin rounded-full border-2 border-solid border-indigo-600 border-r-transparent align-[-0.125em] mr-2"></div>
           Loading tasks...
        </div>
        
        <div v-else-if="tasks.length === 0" class="py-12 bg-gray-50 rounded-xl border border-dashed border-gray-200 text-center">
            <p class="text-gray-400 italic text-sm">No tasks configured for this center yet.</p>
        </div>

        <div v-else class="space-y-3 max-h-[400px] overflow-y-auto pr-1">
           <div v-for="task in tasks" :key="task.uid" class="flex items-center justify-between p-3 bg-white border border-gray-100 rounded-xl shadow-sm hover:border-indigo-100 transition-colors group">
              <div>
                  <div class="flex items-center gap-2">
                      <span class="font-bold text-gray-800 text-sm">{{ task.task_name }}</span>
                      <span v-if="task.is_mandatory" class="text-[10px] font-black text-red-600 bg-red-50 px-1.5 py-0.5 rounded uppercase tracking-wider">Required</span>
                  </div>
                  <div class="flex items-center gap-3 mt-1">
                      <span class="text-xs text-indigo-600 font-medium bg-indigo-50 px-2 py-0.5 rounded flex items-center gap-1">
                          <svg xmlns="http://www.w3.org/2000/svg" class="h-3 w-3" viewBox="0 0 20 20" fill="currentColor">
                              <path fill-rule="evenodd" d="M10 9a3 3 0 100-6 3 3 0 000 6zm-7 9a7 7 0 1114 0H3z" clip-rule="evenodd" />
                          </svg>
                          {{ getRoleName(task.role) }}
                      </span>
                      <span class="text-[10px] text-gray-500 font-mono uppercase border border-gray-200 px-1.5 py-0.5 rounded">{{ task.task_type }}</span>
                  </div>
              </div>
              <button 
                  @click="deleteTask(task)"
                  class="text-gray-400 hover:text-red-500 p-2 rounded-lg hover:bg-red-50 transition-colors"
                  title="Delete Task"
              >
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                  </svg>
              </button>
           </div>
        </div>
      </div>
    </div>
  </BaseModal>
</template>

<script setup>
import { ref, watch, onMounted } from 'vue';
import BaseModal from './BaseModal.vue';
import api from '../api/axios';

const props = defineProps({
    visible: Boolean,
    shiftCenterId: String,
    shiftCenterName: String
});

const emit = defineEmits(['close']);

const tasks = ref([]);
const roles = ref([]);
const loading = ref(false);
const adding = ref(false);
const statusMessage = ref(null);

const triggerStatus = (text, type = 'success') => {
    statusMessage.value = { text, type };
    if (type === 'success') {
        setTimeout(() => {
            if (statusMessage.value?.text === text) {
                statusMessage.value = null;
            }
        }, 3000);
    }
};

const newTask = ref({
    task_name: '',
    role: '',
    task_type: 'CHECKLIST',
    is_mandatory: true
});

const loadRoles = async () => {
    try {
        const res = await api.get('/masters/roles/'); // Adjust endpoint if needed
        roles.value = res.data.results || res.data;
    } catch (e) {
        console.error("Failed to load roles", e);
    }
};

const loadTasks = async () => {
    if (!props.shiftCenterId) return;
    loading.value = true;
    try {
        const res = await api.get(`/operations/shift-center-tasks/?shift_center=${props.shiftCenterId}`);
        tasks.value = res.data.results || res.data;
    } catch (e) {
        console.error("Failed to load tasks", e);
    } finally {
        loading.value = false;
    }
};

const getRoleName = (roleId) => {
    const role = roles.value.find(r => r.uid === roleId);
    return role ? role.name : 'Unknown Role';
};

const addTask = async () => {
    if (!props.shiftCenterId) return;
    adding.value = true;
    try {
        const payload = {
            shift_center: props.shiftCenterId,
            ...newTask.value
        };
        await api.post('/operations/shift-center-tasks/', payload);
        
        // Reset form
        newTask.value = {
            task_name: '',
            role: roles.value.length > 0 ? roles.value[0].uid : '',
            task_type: 'CHECKLIST',
            is_mandatory: true
        };
        
        // Reload list
        await loadTasks();
    } catch (e) {
        console.error("Failed to add task", e);
        triggerStatus(e.response?.data?.detail || "Failed to add task. Please check inputs.", "error");
    } finally {
        adding.value = false;
    }
};

const deleteTask = async (task) => {
    try {
        await api.delete(`/operations/shift-center-tasks/${task.uid}/`);
        triggerStatus(`Task "${task.task_name}" deleted successfully.`);
        await loadTasks();
    } catch (e) {
        console.error("Failed to delete task", e);
        const errorMsg = e.response?.data?.detail || "Failed to delete task.";
        triggerStatus(errorMsg, "error");
    }
};

// Initial load of roles (once)
onMounted(() => {
    loadRoles();
});

// Watch visibility to load tasks
watch(() => props.visible, (val) => {
    if (val) {
        loadTasks();
        // Set default role if available and not set
        if (!newTask.value.role && roles.value.length > 0) {
            newTask.value.role = roles.value[0].uid;
        }
    }
});

// Watch roles to set default when they load
watch(roles, (val) => {
    if (val.length > 0 && !newTask.value.role) {
        newTask.value.role = val[0].uid;
    }
});
</script>
