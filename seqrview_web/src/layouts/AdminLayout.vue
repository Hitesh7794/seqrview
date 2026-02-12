<template>
  <div class="flex h-screen bg-gray-50 font-inter">
    <Sidebar />
    <div class="flex-1 flex flex-col overflow-hidden">
      <!-- Static Header Section -->
      <div class="px-2 pt-3 pb-4 bg-gray-50 z-10 shrink-0">
        
        <!-- Top Bar (Title & Profile) -->
        <div class="bg-white rounded-xl p-3.5 shadow-sm border border-gray-100 flex items-center justify-between">
           <div class="relative w-96">
              <h2 class="text-2xl font-bold text-gray-800 ">{{ currentRouteName }}</h2>
            </div>
           
           <div class="flex items-center space-x-4">
             <!-- <button class="relative p-2 text-gray-400 hover:text-blue-600 transition-colors">
               <span class="absolute top-1 right-1 h-2 w-2 bg-red-500 rounded-full border-2 border-white"></span>
               <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                 <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
               </svg>
             </button> -->
             <div class="flex items-center space-x-3 pl-4 border-l border-gray-100">
                <div class="text-right hidden md:block">
                   <div class="text-sm font-bold text-gray-800">{{ authStore.user?.username || 'Admin' }}</div>
                   <div class="text-xs text-gray-500">Administrator</div>
                </div>
                <div class="h-10 w-10 rounded-full bg-blue-100 border-2 border-white shadow-sm overflow-hidden flex items-center justify-center text-blue-600 font-bold">
                    {{ authStore.user?.username?.charAt(0).toUpperCase() || 'A' }}
                </div>
                <!-- Logout Button -->
                <button @click="authStore.logout()" class="p-2 text-gray-400 hover:text-red-500 transition-colors border-l border-gray-100 pl-4 ml-2" title="Logout">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
                    </svg>
                </button>
             </div>
           </div>
        </div>
      </div>

      <main class="flex-1 overflow-x-hidden overflow-y-auto bg-gray-50 px-8 pb-8 pt-2">
        <router-view></router-view>
      </main>
    </div>
  </div>
</template>

<script setup>
import Sidebar from '../components/Sidebar.vue';
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import { useAuthStore } from '../stores/auth';

const route = useRoute();
const authStore = useAuthStore();
const currentRouteName = computed(() => route.meta.title || 'Dashboard');
</script>
