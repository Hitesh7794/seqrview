<template>
  <div class="flex h-screen bg-gray-50 font-inter text-inter">
    <ExamSidebar />
    <div class="flex-1 flex flex-col overflow-hidden">
      <!-- Top Bar Section -->
      <div class="px-2 pt-3 pb-4 bg-gray-50 z-10 shrink-0">
        <div class="bg-white rounded-xl p-3.5 shadow-sm border border-gray-100 flex items-center justify-between">
           <div class="flex items-center space-x-3">
              <h2 class="text-2xl font-bold text-gray-800">{{ currentRouteName }}</h2>
              <span class="px-2 py-0.5 rounded-full bg-indigo-50 text-indigo-600 text-[10px] font-bold uppercase tracking-wider border border-indigo-100">Exam Console</span>
           </div>
           
           <div class="flex items-center space-x-4">
             <div class="flex items-center space-x-3 pl-4">
                <div class="text-right hidden md:block">
                   <div class="text-sm font-bold text-gray-800">{{ authStore.user?.username || 'User' }}</div>
                   <div class="text-xs text-gray-500">{{ authStore.user?.user_type?.replace('_', ' ') }}</div>
                </div>
                <div class="h-10 w-10 rounded-full bg-indigo-100 border-2 border-white shadow-sm overflow-hidden flex items-center justify-center text-indigo-600 font-bold">
                    {{ authStore.user?.username?.charAt(0).toUpperCase() || 'U' }}
                </div>
                <!-- Logout Button -->
                <button @click="handleLogout" class="p-2 text-gray-400 hover:text-red-500 transition-colors border-l border-gray-100 pl-4 ml-2" title="Logout">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
                    </svg>
                </button>
             </div>
           </div>
        </div>
      </div>

      <main class="flex-1 overflow-x-hidden overflow-y-auto bg-gray-50 px-8 pb-8 pt-2">
        <router-view :key="$route.fullPath"></router-view>
      </main>
    </div>
  </div>
</template>

<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import { useAuthStore } from '../stores/auth';
import ExamSidebar from '../components/ExamSidebar.vue';

const route = useRoute();
const authStore = useAuthStore();
const currentRouteName = computed(() => route.meta.title || 'Exam Dashboard');

const handleLogout = () => {
    authStore.logout();
};
</script>

<style scoped>
.text-inter {
    font-family: 'Inter', sans-serif;
}
</style>
