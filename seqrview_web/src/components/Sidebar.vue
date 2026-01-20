<template>
  <div class="bg-gray-800 text-white w-64 min-h-screen flex flex-col">
    <div class="p-4 text-xl font-bold border-b border-gray-700">SEQR View Admin</div>
    <nav class="flex-1 p-4 space-y-2">
      <router-link to="/" class="block py-2 px-4 rounded hover:bg-gray-700" active-class="bg-gray-700">
        Dashboard
      </router-link>
      
      <div class="text-xs text-gray-500 uppercase mt-4 mb-2">Masters</div>
      <router-link to="/masters/clients" class="block py-2 px-4 rounded hover:bg-gray-700" active-class="bg-gray-700">
        Clients
      </router-link>
      <router-link to="/masters/centers" class="block py-2 px-4 rounded hover:bg-gray-700" active-class="bg-gray-700">
        Centers
      </router-link>
      
      <div class="text-xs text-gray-500 uppercase mt-4 mb-2">Operations</div>
      <router-link to="/operations/exams" class="block py-2 px-4 rounded hover:bg-gray-700" active-class="bg-gray-700">
        Exams & Shifts
      </router-link>
      <router-link to="/operations/assignments" class="block py-2 px-4 rounded hover:bg-gray-700" active-class="bg-gray-700">
        Assignments
      </router-link>
      
      <div class="text-xs text-gray-500 uppercase mt-4 mb-2">Support</div>
      <router-link to="/support/incidents" class="block py-2 px-4 rounded hover:bg-gray-700" active-class="bg-gray-700">
        Incidents
      </router-link>
    </nav>
    <div class="p-4 border-t border-gray-700">
      <button @click="logout" class="w-full text-left py-2 px-4 text-red-400 hover:text-red-300">
        Logout
      </button>
    </div>
  </div>
</template>

<script setup>
import { useAuthStore } from '../stores/auth';
const auth = useAuthStore();
const logout = () => auth.logout();
</script>
