import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { RegisterRequest } from '../model/register.model';
import { VerifyEmailRequest } from '../model/verifyemail.model';
import { LoginRequest } from '../model/login.model';
import { environment } from '../../environments/environment';

export interface LoginResponse {
  token: string;
  user: {
    _id: string;
    username: string;
    email: string;
    role: string;
    createdAt: string;
    isEmailVerified: boolean;
  };
  message: string;
}

@Injectable({
  providedIn: 'root',
})
export class AuthService {
  private api = environment.authApi;

  constructor(private http: HttpClient) {}

  register(data: RegisterRequest): Observable<any> {
    return this.http.post(`${this.api}/register`, data);
  }

  verifyEmail(data: VerifyEmailRequest): Observable<any> {
    return this.http.post(`${this.api}/verifyemail`, data);
  }

  login(data: LoginRequest): Observable<LoginResponse> {
    return this.http.post<LoginResponse>(`${this.api}/login`, data);
  }

  getProfile(): Observable<any> {
    // Token will be auto-attached by interceptor
    return this.http.get(`${this.api}/profile`);
  }

  forgotPassword(data: { email: string }): Observable<any> {
    return this.http.post(`${this.api}/forgotpassword`, data);
  }

  resetPassword(data: {
    email: string;
    resetCode: string;
    newPassword: string;
  }): Observable<any> {
    return this.http.post(`${this.api}/resetpassword`, {
      email: data.email,
      resetCode: data.resetCode,
      newPassword: data.newPassword,
    });
  }

  logout(): Observable<any> {
    return this.http.post(`${this.api}/logout`, {});
  }
}
