import { defineStore } from 'pinia';
import api from '../api/axios';
import router from '../router';

export const useAuthStore = defineStore('auth', {
    state: () => ({
        token: localStorage.getItem('access_token') || null,
        user: JSON.parse(localStorage.getItem('user')) || null,
    }),
    getters: {
        isAuthenticated: (state) => !!state.token,
    },
    actions: {
        async login(username, password) {
            try {
                // Get Token
                const res = await api.post('/auth/token/', { username, password });
                this.token = res.data.access;
                localStorage.setItem('access_token', res.data.access);
                localStorage.setItem('refresh_token', res.data.refresh);

                // Get Profile (Mocking user for now or fetch from /auth/me/ if exists)
                // Let's assume we decode token or just store username
                this.user = { username };
                localStorage.setItem('user', JSON.stringify(this.user));

                router.push('/');
            } catch (error) {
                console.error("Login failed", error);
                throw error;
            }
        },
        logout() {
            this.token = null;
            this.user = null;
            localStorage.clear();
            router.push('/login');
        }
    }
});
