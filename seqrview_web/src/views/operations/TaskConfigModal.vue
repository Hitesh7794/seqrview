<template>
  <div v-if="visible" class="relative z-50" aria-labelledby="modal-title" role="dialog" aria-modal="true">
    <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"></div>

    <div class="fixed inset-0 z-10 w-screen overflow-y-auto">
      <div class="flex min-h-full items-end justify-center p-4 text-center sm:items-center sm:p-0">
        <div class="relative transform overflow-hidden rounded-lg bg-white text-left shadow-xl transition-all sm:my-8 sm:w-full sm:max-w-xl">
          
          <!-- Header -->
          <div class="bg-indigo-600 px-4 py-3 sm:px-6">
            <h3 class="text-base font-semibold leading-6 text-white" id="modal-title">
              Task Configuration - {{ shiftCenterName }}
            </h3>
          </div>

          <div class="px-4 py-5 sm:p-6">
            
            <!-- Loading State -->
            <div v-if="loading" class="flex justify-center py-4">
              <svg class="animate-spin h-8 w-8 text-indigo-600" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
            </div>

            <div v-else>
              <!-- Add New Task Form -->
              <div class="mb-6 bg-gray-50 p-4 rounded-lg border border-gray-200">
                <h4 class="text-sm font-medium text-gray-900 mb-3">Add New Task</h4>
                <div class="grid grid-cols-1 gap-y-3 gap-x-4 sm:grid-cols-6">
                  
                  <div class="sm:col-span-3">
                    <label for="role" class="block text-xs font-medium text-gray-700">Role</label>
                    <select v-model="newTask.role" id="role" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm">
                      <option v-for="role in roles" :key="role.uid" :value="role.uid">{{ role.name }}</option>
                    </select>
                  </div>

                  <div class="sm:col-span-3">
                    <label for="taskName" class="block text-xs font-medium text-gray-700">Task Name</label>
                    <input 
                      type="text" 
                      list="libraryTasks"
                      v-model="newTask.task_name" 
                      id="taskName" 
                      class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm" 
                      placeholder="Select or type..."
                    >
                    <datalist id="libraryTasks">
                        <option v-for="task in libraryTasks" :key="task.uid" :value="task.name"></option>
                    </datalist>
                  </div>
                  
                  <div class="sm:col-span-3 mt-4">
                    <label for="taskType" class="block text-xs font-medium text-gray-700">Task Type</label>
                    <select v-model="newTask.task_type" id="taskType" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm">
                        <option value="CHECKLIST">Checklist (Simple Tick)</option>
                        <option value="PHOTO">Take Photo</option>
                        <option value="VIDEO">Record Video</option>
                    </select>
                  </div>
                </div>
                <div class="mt-3 flex justify-end">
                   <button 
                      type="button" 
                      @click="addTask"
                      :disabled="!newTask.role || !newTask.task_name"
                      class="inline-flex justify-center rounded-md border border-transparent bg-indigo-600 py-1.5 px-3 text-xs font-medium text-white shadow-sm hover:bg-indigo-700 disabled:opacity-50"
                    >
                      Add Task
                    </button>
                </div>
              </div>

              <!-- Existing Tasks List -->
              <h4 class="text-sm font-medium text-gray-900 mb-2">Configured Tasks</h4>
              
              <div v-if="tasks.length === 0" class="text-center py-8 text-gray-500 text-sm italic">
                No tasks configured yet.
              </div>

              <ul v-else class="divide-y divide-gray-100 border rounded-md overflow-hidden">
                <li v-for="task in tasks" :key="task.uid" class="flex items-center justify-between py-3 px-4 bg-white hover:bg-gray-50">
                  <div class="flex items-center">
                    <span class="inline-flex items-center rounded-md bg-purple-50 px-2 py-1 text-xs font-medium text-purple-700 ring-1 ring-inset ring-purple-700/10 mr-3">
                      {{ getRoleName(task.role) }}
                    </span>
                    <span class="text-sm font-medium text-gray-900">{{ task.task_name }}</span>
                    <span v-if="task.is_mandatory" class="ml-2 inline-flex items-center rounded-md bg-red-50 px-1.5 py-0.5 text-[10px] font-medium text-red-700 ring-1 ring-inset ring-red-600/10">Mandatory</span>
                  </div>
                  <button @click="deleteTask(task.uid)" class="text-gray-400 hover:text-red-500">
                    <span class="sr-only">Delete</span>
                    <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0" />
                    </svg>
                  </button>
                </li>
              </ul>
            </div>
          </div>

          <div class="bg-gray-50 px-4 py-3 sm:flex sm:flex-row-reverse sm:px-6">
            <button type="button" class="mt-3 inline-flex w-full justify-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50 sm:mt-0 sm:w-auto" @click="$emit('close')">
              Close
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, watch, onMounted } from 'vue';
import api from '../../api/axios';

const props = defineProps({
  visible: Boolean,
  shiftCenterId: String,
  shiftCenterName: String
});

const emit = defineEmits(['close']);

const loading = ref(false);
const tasks = ref([]);
const roles = ref([]);
const newTask = ref({
  role: '',
  task_name: '',
  task_type: 'CHECKLIST',
  is_mandatory: true
});

const libraryTasks = ref([]);

const fetchLibraryTasks = async () => {
    try {
        const response = await api.get('/masters/task-library/');
        libraryTasks.value = response.data.results || response.data;
    } catch (e) {
        console.error("Failed to fetch task library", e);
    }
};

const fetchRoles = async () => {
    try {
        const response = await api.get('/masters/roles/');
        roles.value = response.data.results || response.data;
        if (roles.value.length > 0) {
            newTask.value.role = roles.value[0].uid;
        }
    } catch (e) {
        console.error("Failed to fetch roles", e);
    }
};

const fetchTasks = async () => {
  if (!props.shiftCenterId) return;
  
  loading.value = true;
  try {
    const response = await api.get('/operations/shift-center-tasks/', {
      params: { shift_center: props.shiftCenterId }
    });
    tasks.value = response.data.results || response.data;
  } catch (error) {
    console.error('Error fetching tasks:', error);
  } finally {
    loading.value = false;
  }
};

const addTask = async () => {
    try {
        await api.post('/operations/shift-center-tasks/', {
            shift_center: props.shiftCenterId,
            role: newTask.value.role,
            task_name: newTask.value.task_name,
            task_type: newTask.value.task_type,
            is_mandatory: newTask.value.is_mandatory
        });
        newTask.value.task_name = ''; // Clear input
        fetchTasks(); // Refresh list
    } catch (e) {
        alert("Failed to add task: " + (e.response?.data?.detail || e.message));
    }
};

const deleteTask = async (uid) => {
    if(!confirm("Are you sure?")) return;
    try {
        await api.delete(`/operations/shift-center-tasks/${uid}/`);
        fetchTasks();
    } catch (e) {
        alert("Failed to delete task");
    }
}

// Watch for modal opening
watch(() => props.visible, (newVal) => {
  if (newVal) {
    fetchTasks();
    if(roles.value.length === 0) fetchRoles();
    if(libraryTasks.value.length === 0) fetchLibraryTasks();
  }
});

// Auto-select type when library task is chosen
watch(() => newTask.value.task_name, (newName) => {
    const match = libraryTasks.value.find(t => t.name === newName);
    if (match && match.task_type) {
        newTask.value.task_type = match.task_type;
    }
});

const getRoleName = (roleId) => {
    const r = roles.value.find(x => x.uid === roleId);
    return r ? r.name : 'Unknown';
}

// Watch for modal opening
watch(() => props.visible, (newVal) => {
  if (newVal) {
    fetchTasks();
    if(roles.value.length === 0) fetchRoles();
  }
});

</script>
