import { Injectable } from '@angular/core';
import { CanActivate, Router } from '@angular/router';
import { isPlatformBrowser } from '@angular/common';
import { Inject, PLATFORM_ID } from '@angular/core';

@Injectable({ providedIn: 'root' })
export class AuthGuard implements CanActivate {
  constructor(
    private router: Router,
    @Inject(PLATFORM_ID) private platformId: Object
  ) {}

  canActivate(): boolean {
    console.log('AuthGuard: Checking authentication status');
    
    // Check if we're in the browser environment
    if (isPlatformBrowser(this.platformId)) {
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
    
    // For server-side rendering, you might want to handle this case differently
    console.log('AuthGuard: Server-side rendering detected');
    return false; // or true based on your requirements
  }
}