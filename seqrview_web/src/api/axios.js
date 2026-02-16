import axios from 'axios';

const api = axios.create({
    baseURL: 'http://127.0.0.1:8000/api', // Functioning Django URL
    headers: {
        'Content-Type': 'application/json',
    }
});

// Request Interceptor: Add Token
api.interceptors.request.use(config => {
    const token = localStorage.getItem('access_token');
    if (token) {
        config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
});

// Response Interceptor: Handle Token Refresh & Expiry
api.interceptors.response.use(
    (response) => response,
    async (error) => {
        const originalRequest = error.config;

        // Skip interceptor for login endpoint itself to allow component to handle 401
        if (originalRequest.url.includes('/auth/token/') && !originalRequest.url.includes('refresh')) {
            return Promise.reject(error);
        }

        // If error is 401 and we haven't tried to refresh yet
        if (error.response && error.response.status === 401 && !originalRequest._retry) {
            originalRequest._retry = true;
            const refreshToken = localStorage.getItem('refresh_token');

            if (refreshToken) {
                try {
                    // Attempt to get a new access token
                    // We use axios directly to avoid interceptors for this specific call
                    const response = await axios.post('http://127.0.0.1:8000/api/auth/token/refresh/', {
                        refresh: refreshToken
                    });

                    const newAccessToken = response.data.access;
                    localStorage.setItem('access_token', newAccessToken);

                    // Update header and retry original request
                    originalRequest.headers.Authorization = `Bearer ${newAccessToken}`;
                    return api(originalRequest);
                } catch (refreshError) {
                    console.error("Refresh token expired or invalid", refreshError);
                    // Clear storage and redirect to login if refresh fails
                    localStorage.removeItem('access_token');
                    localStorage.removeItem('refresh_token');
                    localStorage.removeItem('user');
                    window.location.href = '/login';
                }
            } else {
                // No refresh token available, just logout
                // Only redirect if not already on login page to avoid loops
                if (!window.location.pathname.includes('/login')) {
                    localStorage.clear();
                    window.location.href = '/login';
                }
            }
        }

        return Promise.reject(error);
    }
);

export default api;
