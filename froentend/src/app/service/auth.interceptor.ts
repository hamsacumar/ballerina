// src/app/interceptors/auth.interceptor.ts
import { HttpInterceptorFn } from '@angular/common/http';

export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const token = localStorage.getItem('authToken'); // ✅ get saved token
  if (!token) return next(req);

  // Clone request with Authorization header
  const authReq = req.clone({
    setHeaders: { Authorization: `Bearer ${token}` }
  });

  return next(authReq);
};
