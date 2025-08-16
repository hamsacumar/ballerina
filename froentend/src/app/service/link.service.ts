import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { Link } from '../model/link.model';
import { environment } from '../../environments/environment';

@Injectable({ providedIn: 'root' })
export class LinkService {
  private apiUrl = `${environment.apiBaseUrl}/links`;
; // Adjust if needed

  constructor(private http: HttpClient) {}

  getAll(): Observable<Link[]> {
    return this.http.get<Link[]>(`${this.apiUrl}/all`);
  }

  getByCategory(categoryId: string): Observable<Link[]> {
    return this.http.get<Link[]>(`${this.apiUrl}/category/${categoryId}`);
  }

  create(data: { name: string; url: string; categoryId?: string | null }): Observable<any> {
    return this.http.post(this.apiUrl, data);
  }

  update(id: string, data: { name: string; url: string; categoryId?: string | null }): Observable<any> {
    return this.http.put(`${this.apiUrl}/${id}`, data);
  }

  remove(id: string): Observable<any> {
    return this.http.delete(`${this.apiUrl}/${id}`);
  }
}
