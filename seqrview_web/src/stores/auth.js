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

                // Fetch User Profile
                const userRes = await api.get('/auth/me/');
                this.user = userRes.data;
                localStorage.setItem('user', JSON.stringify(this.user));

                // Redirect logic handled by component or here?
                // Ideally, return user so component can decide, or handle here.
                // Let's handle here for simplicity based on role.
                if (this.user.user_type === 'EXAM_ADMIN') {
                    router.push(`/exam/${this.user.exam || 'dashboard'}`);
                } else {
                    router.push('/');
                }
            } catch (error) {
                console.error("Login failed", error);
                throw error;
            }
        },
        async logout() {
            try {
                const refreshToken = localStorage.getItem('refresh_token');
                if (refreshToken) {
                    await api.post('/auth/logout/', { refresh: refreshToken });
                }
            } catch (error) {
                console.error("Logout API failed", error);
            } finally {
                this.token = null;
                this.user = null;
                localStorage.clear();
                router.push('/login');
            }
        }
    }
});
