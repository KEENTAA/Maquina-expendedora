const host = window.location.hostname || 'localhost';
const protocol = window.location.protocol || 'http:';

export const API_BASE_URL = `${protocol}//${host}:8002`;
export const APP_BASE_URL = `${protocol}//${host}:3000`;
