import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Observable } from 'rxjs';
import { ChangePasswordRequest } from '../model/profile.model';

@Injectable({
  providedIn: 'root',
})
export class ProfileService {
  private http = inject(HttpClient);
  private baseUrl = 'http://localhost:9092/auth';

  // Safe wrapper to get token from localStorage
  private getToken(): string {
    if (typeof localStorage !== 'undefined') {
      return localStorage.getItem('token') || '';
    }
    return '';
  }

  // Get authentication headers with JWT token
  private getAuthHeaders(): HttpHeaders {
    const token = this.getToken();
    return new HttpHeaders({
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    });
  }

  // Get user profile
  getUserProfile(): Observable<any> {
    return this.http.get(`${this.baseUrl}/profile`, {
      headers: this.getAuthHeaders(),
    });
  }

  // Update username
  updateUsername(newUsername: string): Observable<any> {
    return this.http.put(
      `${this.baseUrl}/update-username`,
      { newUsername },
      { headers: this.getAuthHeaders() }
    );
  }

  // Update password
  updatePassword(passwordData: ChangePasswordRequest): Observable<any> {
    return this.http.put(`${this.baseUrl}/update-password`, passwordData, {
      headers: this.getAuthHeaders(),
    });
  }

  // Upload profile image
  uploadProfileImage(formData: FormData): Observable<any> {
    const token = this.getToken();
    const headers = new HttpHeaders({
      Authorization: `Bearer ${token}`,
      // Don't set Content-Type for FormData
    });

    return this.http.post(`${this.baseUrl}/upload-profile-image`, formData, {
      headers,
    });
  }

  // Get profile image URL
  getProfileImageUrl(imageName: string): string {
    return `${this.baseUrl}/profile-images/${imageName}`;
  }

  // Get current user data from token
  getCurrentUserFromToken(): any {
    const token = this.getToken();
    if (!token) return null;

    try {
      const payload = JSON.parse(atob(token.split('.')[1]));
      return {
        username: payload.username,
        email: payload.email,
        role: payload.role,
        isEmailVerified: payload.isEmailVerified,
      };
    } catch (error) {
      console.error('Error parsing token:', error);
      return null;
    }
  }

  // Check if user is authenticated
  isAuthenticated(): boolean {
    const token = this.getToken();
    if (!token) return false;

    try {
      const payload = JSON.parse(atob(token.split('.')[1]));
      const currentTime = Date.now() / 1000;
      return payload.exp > currentTime;
    } catch (error) {
      return false;
    }
  }
}
