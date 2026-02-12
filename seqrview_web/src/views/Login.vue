<template>
  <div class="min-h-screen flex items-center justify-center bg-gray-50 font-sans">
    <div class="bg-white rounded-2xl shadow-xl w-full max-w-lg p-8 border border-gray-100">
      <div class="flex justify-between items-center space-x-2 mb-3">
        <!-- Logo -->
        <img src="../assets/logo.png" alt="Logo" class="h-24 w-auto" />
        
        <h1 class="text-2xl  font-bold text-[#0f172a]">Login here</h1>
      </div>
      
      <!-- Divider -->
      <div class="border-t border-gray-100 mb-8 w-full"></div>

      <form @submit.prevent="handleLogin" class="space-y-6">
        <!-- Username Row -->
        <div class="flex items-center space-x-4">
          <label class="w-24 text-sm font-bold text-gray-700">Username</label>
          <input 
            v-model="username" 
            type="text" 
            placeholder="Hitesh77"
            class="flex-1 border border-gray-200 rounded px-3 py-2 text-sm text-gray-700 focus:outline-none focus:border-gray-400 focus:ring-0 placeholder-gray-300 bg-white shadow-sm"
            required 
          />
        </div>

        <!-- Password Row -->
        <div class="flex items-center space-x-4">
          <label class="w-24 text-sm font-bold text-gray-700">Password</label>
          <input 
            v-model="password" 
            type="password" 
            placeholder="password@123"
            class="flex-1 border border-gray-200 rounded px-3 py-2 text-sm text-gray-700 focus:outline-none focus:border-gray-400 focus:ring-0 placeholder-gray-300 bg-white shadow-sm"
            required 
          />
        </div>

        <!-- Button Row -->
        <div class="flex justify-end pt-4">
          <button 
            type="submit" 
            class="bg-[#333333] hover:bg-black text-white text-sm font-bold py-2 px-8 rounded-full shadow-md transition-colors"
          >
            Login
          </button>
        </div>
      </form>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue';
import { useAuthStore } from '../stores/auth';

const username = ref('');
const password = ref('');
const auth = useAuthStore();

const handleLogin = async () => {
  try {
    await auth.login(username.value, password.value);
  } catch (e) {
    alert("Invalid Credentials " + e);
  }
};
</script>
