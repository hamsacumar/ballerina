// src/app/guards/auth.guard.ts
import { Injectable } from '@angular/core';
import { CanActivate, Router } from '@angular/router';

@Injectable({ providedIn: 'root' })
export class AuthGuard implements CanActivate {
  constructor(private router: Router) {}

  canActivate(): boolean {
    console.log('AuthGuard: Checking authentication status');
    const token = localStorage.getItem('authToken');
    console.log('AuthGuard: Token found in localStorage:', !!token);
    
    if (!token) {
      console.log('AuthGuard: No token found, redirecting to landing page');
      this.router.navigate(['/']).then(success => {
        console.log('AuthGuard: Navigation to landing page successful:', success);
      }).catch(err => {
        console.error('AuthGuard: Navigation to landing page failed:', err);
      });
      return false;
    }
    
    console.log('AuthGuard: User is authenticated, allowing access');
    return true;
  }
}
