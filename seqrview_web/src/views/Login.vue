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

        <div v-if="localError" class="text-red-500 text-sm font-bold text-center bg-red-50 p-2 rounded-lg">
             {{ localError }}
        </div>

        <!-- Button Row -->
        <div class="flex justify-end pt-4">
          <button 
            type="submit" 
            :disabled="loading"
            class="bg-[#333333] hover:bg-black text-white text-sm font-bold py-2 px-8 rounded-full shadow-md transition-colors disabled:opacity-50"
          >
            {{ loading ? 'Logging in...' : 'Login' }}
          </button>
        </div>
      </form>
    </div>

    <!-- Error Modal for Exam Expiry -->
    <div v-if="showErrorModal" class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm animate-in fade-in duration-200">
        <div class="bg-white rounded-2xl shadow-2xl p-6 max-w-md w-full mx-4 border border-gray-200 transform scale-100 transition-transform">
            <div class="flex items-start gap-4">
                <div class="bg-red-100 rounded-full p-2 flex-shrink-0">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6 text-red-600" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                    </svg>
                </div>
                <div>
                    <h3 class="text-lg font-bold text-gray-900 mb-2">Login Failed</h3>
                    <p class="text-sm text-gray-600 font-medium leading-relaxed">
                        {{ modalMessage }}
                    </p>
                </div>
            </div>
            <div class="mt-6 flex justify-end">
                <button 
                    @click="showErrorModal = false"
                    class="px-4 py-2 bg-gray-100 hover:bg-gray-200 text-gray-800 font-bold rounded-lg text-sm transition-colors"
                >
                    Dismiss
                </button>
            </div>
        </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue';
import { useAuthStore } from '../stores/auth';

const username = ref('');
const password = ref('');
const auth = useAuthStore();
const localError = ref(null);
const loading = ref(false);

const showErrorModal = ref(false);
const modalMessage = ref('');

const handleLogin = async () => {
  localError.value = null;
  loading.value = true;
  try {
    await auth.login(username.value, password.value);
  } catch (e) {
    console.error("Login Error:", e);
    // Parse error
    let msg = "Invalid Credentials";
    if (e.response && e.response.data && e.response.data.detail) {
        msg = e.response.data.detail;
    }
    
    // Check for Exam Expiry message specifically or general authentication failure
    if (msg.includes("exam has concluded") || msg.includes("Access is now closed")) {
         modalMessage.value = msg;
         showErrorModal.value = true;
    } else {
         localError.value = msg;
    }
  } finally {
      loading.value = false;
  }
};
</script>
