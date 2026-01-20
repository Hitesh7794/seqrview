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
                { path: 'operations/exams', component: () => import('../views/operations/ExamList.vue'), meta: { title: 'Exams & Operations' } },
                { path: 'operations/assignments', component: () => import('../views/operations/AssignmentList.vue'), meta: { title: 'Assignments' } },
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
