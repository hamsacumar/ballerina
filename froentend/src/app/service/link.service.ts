import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';
import { Link } from '../model/link.model';
import { map } from 'rxjs/operators';

@Injectable({
  providedIn: 'root'
})
export class LinkService {
  private apiUrl = `${environment.apiBaseUrl}/links`;

  constructor(private http: HttpClient) { }

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
  getAll(): Observable<Link[]> {
    return this.http.get<Link[]>(this.apiUrl).pipe(
      map((links: any[]) => links.map(link => ({
        _id: link._id,
        name: link.name,
        url: link.url,
        icon: link.icon || this.getDefaultIcon(link.url),
        categoryId: link.categoryId,
        createdAt: link.createdAt,
        updatedAt: link.updatedAt
      } as Link)))
    );
  }

  private getDefaultIcon(url: string): string {
    // Extract domain and return default icon path
    try {
      const domain = new URL(url.startsWith('http') ? url : `https://${url}`).hostname;
      return `assets/domain-icons/${domain}.png`; // or use a service like favicon API
    } catch {
      return 'assets/default-favicon.png';
    }
  }
}