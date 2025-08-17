import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Observable } from 'rxjs';
import { Category } from '../model/category.model';
import { environment } from '../../environments/environment';

@Injectable({ providedIn: 'root' })
export class CategoryService {
  private apiUrl = `${environment.apiBaseUrl}/categories`;

  constructor(private http: HttpClient) {}

  /** Get JWT from localStorage (you must set this when user logs in) */
  private getAuthHeaders(): HttpHeaders {
    const token = localStorage.getItem('authToken'); // or sessionStorage
    return new HttpHeaders({
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json'
    });
  }

  /** Get all categories */
  getAll(): Observable<Category[]> {
    return this.http.get<Category[]>(this.apiUrl, {
      headers: this.getAuthHeaders()
    });
  }

  /** Create category */
  create(data: { name: string }): Observable<any> {
    return this.http.post(this.apiUrl, data, {
      headers: this.getAuthHeaders()
    });
  }

  /** Update category */
  update(id: string, data: { name: string }): Observable<any> {
    return this.http.put(`${this.apiUrl}/${id}`, data, {
      headers: this.getAuthHeaders()
    });
  }

  /** Delete category */
  remove(id: string): Observable<any> {
    return this.http.delete(`${this.apiUrl}/${id}`, {
      headers: this.getAuthHeaders()
    });
  }
}
