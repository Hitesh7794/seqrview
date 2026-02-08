<template>
  <div class="bg-white text-gray-900 w-64 min-h-screen flex flex-col font-inter border-r border-gray-100 relative z-20">
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
  </div>
</template>

<script setup>
import { 
  Squares2X2Icon, 
  UsersIcon, 
  BuildingOfficeIcon, 
  ClipboardDocumentCheckIcon,
  ChartBarIcon,
  BriefcaseIcon,
  ClipboardDocumentListIcon
} from '@heroicons/vue/24/outline';

import { useAuthStore } from '../stores/auth';
import { computed } from 'vue';

const authStore = useAuthStore();

const allNavItems = [
  { name: 'Dashboard', path: '/', icon: Squares2X2Icon, roles: ['INTERNAL_ADMIN', 'CLIENT_ADMIN'] },
  { name: 'Exams', path: '/operations/exams', icon: ChartBarIcon, roles: ['INTERNAL_ADMIN', 'CLIENT_ADMIN'] },
  { name: 'Operators', path: '/masters/operators', icon: ClipboardDocumentCheckIcon, roles: ['INTERNAL_ADMIN'] },
  { name: 'Clients', path: '/masters/clients', icon: UsersIcon, roles: ['INTERNAL_ADMIN'] },
  { name: 'Roles', path: '/masters/roles', icon: BriefcaseIcon, roles: ['INTERNAL_ADMIN'] },
  { name: 'Task Library', path: '/masters/task-library', icon: ClipboardDocumentListIcon, roles: ['INTERNAL_ADMIN'] },
];

const navItems = computed(() => {
    const userRole = authStore.user?.user_type;
    return allNavItems.filter(item => !item.roles || item.roles.includes(userRole));
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

/* Active State: Blue Background Accent for Light Theme */
.active-nav {
  @apply bg-blue-50 text-blue-700 font-bold !important;
}

.active-nav svg {
    @apply text-blue-600 !important;
}
</style>
