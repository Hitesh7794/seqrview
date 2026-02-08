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
                { path: 'masters/clients/:uid/exams', component: () => import('../views/masters/ClientDetailExams.vue'), meta: { title: 'Client Exams' } },
                { path: 'masters/centers', component: () => import('../views/masters/CenterList.vue'), meta: { title: 'Center Master' } },
                { path: 'masters/users', component: () => import('../views/masters/UserList.vue'), meta: { title: 'User Management' } },
                { path: 'masters/operators', component: () => import('../views/masters/OperatorList.vue'), meta: { title: 'Operators' } },
                { path: 'masters/roles', component: () => import('../views/masters/RoleMasterList.vue'), meta: { title: 'Role Master' } },
                { path: 'masters/task-library', component: () => import('../views/masters/TaskLibraryList.vue'), meta: { title: 'Task Library' } },
                { path: 'operations/exams', component: () => import('../views/operations/ExamList.vue'), meta: { title: 'Exams' } },
                { path: 'operations/exams/:examId/shifts', component: () => import('../views/operations/ExamShiftsList.vue'), meta: { title: 'Exam Shifts' } },
                { path: 'operations/shifts/:shiftId/centers', component: () => import('../views/operations/ShiftCenters.vue'), meta: { title: 'Shift Centers' } },
                { path: 'operations/shift-centers/:centerId/assignments', component: () => import('../views/operations/ShiftCenterAssignments.vue'), meta: { title: 'Center Assignments' } },
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
