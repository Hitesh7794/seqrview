<template>
  <div>
    <div class="flex justify-between items-center mb-6">
      <h1 class="text-2xl font-bold text-gray-800">Assignments</h1>
      <div class="space-x-2" v-if="canManage">
        <button class="bg-green-600 text-white px-4 py-2 rounded hover:bg-green-700">
          Bulk Upload
        </button>
        <button class="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700">
          + Add Single
        </button>
      </div>
    </div>

    <div class="bg-white rounded-lg shadow overflow-hidden">
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Operator</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Role</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Exam / Shift</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Center</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
          </tr>
        </thead>
        <tbody class="bg-white divide-y divide-gray-200">
          <tr v-for="assign in assignments" :key="assign.uid">
            <td class="px-6 py-4 whitespace-nowrap">
              <div class="text-sm font-medium text-gray-900">{{ assign.operator_name || 'Hitesh' }}</div> <!-- Placeholder logic if name not expanded -->
              <div class="text-xs text-gray-500">{{ assign.assignment_type }}</div>
            </td>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{{ assign.role_name || assign.role }}</td>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                <div>{{ assign.shift_name }}</div>
                <div class="text-xs">{{ new Date(assign.assigned_at).toLocaleDateString() }}</div>
            </td>
             <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{{ assign.center_name }}</td>
            <td class="px-6 py-4 whitespace-nowrap">
              <span class="px-2 inline-flex text-xs leading-5 font-semibold rounded-full"
                :class="{
                  'bg-green-100 text-green-800': assign.status === 'COMPLETED' || assign.status === 'CONFIRMED',
                  'bg-blue-100 text-blue-800': assign.status === 'CHECK_IN',
                  'bg-yellow-100 text-yellow-800': assign.status === 'PENDING',
                  'bg-red-100 text-red-800': assign.status === 'NO_SHOW' || assign.status === 'CANCELLED',
                }">
                {{ assign.status }}
              </span>
            </td>
            <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
              <a href="#" v-if="canManage" class="text-indigo-600 hover:text-indigo-900">Edit</a>
            </td>
          </tr>
           <tr v-if="assignments.length === 0">
             <td colspan="6" class="px-6 py-4 text-center text-gray-500">No assignments found.</td>
          </tr>
        </tbody>
      </table>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, computed } from 'vue';
import { useAuthStore } from '../../stores/auth';
import api from '../../api/axios';

const assignments = ref([]);
const authStore = useAuthStore();
const canManage = computed(() => {
    const type = authStore.user?.user_type;
    return type === 'INTERNAL_ADMIN' || authStore.user?.is_superuser; 
});

onMounted(async () => {
  try {
    const res = await api.get('/assignments/'); // Base path for assignments
    assignments.value = res.data.results || res.data;
  } catch (e) {
    console.error("Failed to load assignments", e);
  }
});
</script>
