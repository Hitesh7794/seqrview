import { createRouter, createWebHistory } from 'vue-router';
import { useAuthStore } from '../stores/auth';
import Login from '../views/Login.vue';

const router = createRouter({
    history: createWebHistory(),
    routes: [
        { path: '/login', component: Login },
        {
            path: '/',
            component: () => import('../layouts/AdminLayout.vue'),
            meta: { requiresAuth: true },
            children: [
                { path: '', component: () => import('../views/Dashboard.vue'), meta: { title: 'Dashboard' } },
                { path: 'masters/clients', component: () => import('../views/masters/ClientList.vue'), meta: { title: 'Client Master' } },
                { path: 'masters/centers', component: () => import('../views/masters/CenterList.vue'), meta: { title: 'Center Master' } },
                { path: 'masters/users', component: () => import('../views/masters/UserList.vue'), meta: { title: 'User Management' } },
                { path: 'masters/operators', component: () => import('../views/masters/OperatorList.vue'), meta: { title: 'Operators' } },
                { path: 'operations/exams', component: () => import('../views/operations/ExamList.vue'), meta: { title: 'Exams' } },
            ]
        },
        {
            path: '/exam/:code',
            component: () => import('../layouts/ExamLayout.vue'),
            meta: { requiresAuth: true },
            children: [
                { path: '', component: () => import('../views/exam/ExamDashboard.vue'), meta: { title: 'Exam Dashboard' } },
                // Add Shifts/Centers later if needed, can reuse components or make new ones
            ]
        }
    ]
});

router.beforeEach((to, from, next) => {
    const auth = useAuthStore();
    if (to.meta.requiresAuth && !auth.isAuthenticated) {
        next('/login');
    } else {
        next();
    }
});

export default router;
