<template>
  <div class="bg-white text-gray-900 w-64 min-h-screen flex flex-col font-inter border-r border-gray-100">
    <!-- Logo Section -->
    <div class="h-20 flex items-center px-6 border-b border-gray-100">
      <div class="flex items-center gap-3">
        <div class="h-20 w-25 rounded-lg flex items-center justify-center overflow-hidden">
           <img src="/logo.png" alt="SEQRView Logo" class="h-full w-full object-contain">
        </div>
      </div>
    </div>

    <!-- Navigation -->
    <nav class="flex-1 px-1 py-6 space-y-1 overflow-y-auto custom-scrollbar">
      <router-link 
        v-for="item in navItems" 
        :key="item.name" 
        :to="item.path"
        class="nav-item group"
        active-class="active-nav"
      >
        <component :is="item.icon" class="h-5 w-5 mr-3 transition-colors duration-200" />
        <span>{{ item.name }}</span>
      </router-link>
    </nav>

    <!-- Context Footer (Exam Details) -->
    <div v-if="examCode" class="p-4 bg-gray-50 border-t border-gray-100 mx-2 mb-4 rounded-xl">
        <div class="text-[10px] uppercase text-gray-400 font-bold mb-1">Active Exam</div>
        <div class="text-xs font-bold text-blue-600 truncate uppercase">{{ examCode }}</div>
    </div>
  </div>
</template>

<script setup>
import { 
  Squares2X2Icon, 
  ClockIcon, 
  MapPinIcon,
  DocumentChartBarIcon,
  ChevronLeftIcon
} from '@heroicons/vue/24/outline';

import { useRoute } from 'vue-router';
import { computed } from 'vue';

const route = useRoute();
const examCode = computed(() => route.params.code);

const navItems = computed(() => {
    const code = examCode.value;
    if (!code) return [];

    return [
        { name: 'Exam Dashboard', path: `/exam/${code}`, icon: Squares2X2Icon },
        { name: 'Manage Shifts', path: `/exam/${code}/shifts`, icon: ClockIcon },
        { name: 'Exam Centers', path: `/exam/${code}/centers`, icon: MapPinIcon },
        { name: 'Live Reports', path: `/exam/${code}/reports`, icon: DocumentChartBarIcon },
        { name: 'Back to Admin', path: '/operations/exams', icon: ChevronLeftIcon, roles: ['INTERNAL_ADMIN', 'CLIENT_ADMIN'] }
    ].filter(item => {
        if (item.name === 'Back to Admin') {
            // Only show if user is actually an admin/client
            // Actually let's keep it simple for now and just show it if they have access
            return true; 
        }
        return true;
    });
});
</script>

<style scoped>
.font-inter {
    font-family: 'Inter', sans-serif;
}

.nav-item {
  @apply flex items-center px-4 py-3 text-sm font-medium text-gray-500 rounded-lg transition-all duration-200 mb-2 mx-1;
}

.nav-item:hover {
  @apply text-gray-900 bg-gray-50;
}

.nav-item svg {
    @apply text-gray-400 group-hover:text-gray-600;
}

.active-nav {
  @apply bg-blue-50 text-blue-700 font-bold !important;
}

.active-nav svg {
    @apply text-blue-600 !important;
}
</style>
