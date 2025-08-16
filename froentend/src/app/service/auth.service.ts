import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { RegisterRequest } from '../model/register.model';
import { VerifyEmailRequest } from '../model/verifyemail.model';
import { LoginRequest } from '../model/login.model';

@Injectable({
  providedIn: 'root'
})



export class AuthService {

  private apiUrl = 'http://localhost:9092/auth'; // base url

  constructor(private http: HttpClient) { }

  register(data: RegisterRequest): Observable<any> {
    return this.http.post(`${this.apiUrl}/register`, data);
  }

  verifyEmail(data: VerifyEmailRequest): Observable<any> {
    return this.http.post(`${this.apiUrl}/verifyemail`, data);
  }

  login(data: LoginRequest): Observable<any> {
    return this.http.post(`${this.apiUrl}/login`, data);
  }

  getProfile(): Observable<any> {
    const token = localStorage.getItem('authToken'); // saved after login
    return this.http.get(`${this.apiUrl}/profile`, {
      headers: {
        Authorization: `Bearer ${token}`
      }
    });
  }

}
