<template>
  <div class="min-h-screen flex items-center justify-center bg-gray-100">
    <div class="bg-white p-8 rounded shadow-md w-96">
      <h1 class="text-2xl mb-6 font-bold text-center">Admin Console</h1>
      <form @submit.prevent="handleLogin">
        <div class="mb-4">
          <label class="block mb-2 text-sm font-bold">Username</label>
          <input v-model="username" type="text" class="w-full border p-2 rounded" required />
        </div>
        <div class="mb-6">
          <label class="block mb-2 text-sm font-bold">Password</label>
          <input v-model="password" type="password" class="w-full border p-2 rounded" required />
        </div>
        <button type="submit" class="w-full bg-blue-600 text-white p-2 rounded hover:bg-blue-700">
          Login
        </button>
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
