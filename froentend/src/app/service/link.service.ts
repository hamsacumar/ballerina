import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';
import { Link } from '../model/link.model';

@Injectable({
  providedIn: 'root'
})
export class LinkService {
  private apiUrl = `${environment.apiBaseUrl}/links`;

  constructor(private http: HttpClient) {}

  create(payload: { name: string; url: string; categoryId: string }): Observable<any> {
    return this.http.post(this.apiUrl, payload);
  }

  getByCategory(categoryId: string): Observable<Link[]> {
    return this.http.get<Link[]>(`${this.apiUrl}/category/${categoryId}`);
  }

  update(id: string, payload: { name?: string; url?: string; categoryId?: string }): Observable<any> {
    return this.http.put(`${this.apiUrl}/${id}`, payload);
  }

  remove(id: string): Observable<any> {
    return this.http.delete(`${this.apiUrl}/${id}`);
  }
}
