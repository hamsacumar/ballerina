import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { Link } from '../model/link.model';
import { environment } from '../../environments/environment';

@Injectable({ providedIn: 'root' })
export class LinkService {
  private apiUrl = `${environment.apiBaseUrl}/links`;

  constructor(private http: HttpClient) {}

  /** Get all links (categorized + uncategorized) */
  getAll(): Observable<{ categorizedLinks: Link[]; uncategorizedLinks: Link[]; totalLinks: number }> {
    return this.http.get<{ categorizedLinks: Link[]; uncategorizedLinks: Link[]; totalLinks: number }>(
      `${this.apiUrl}/all`
    );
  }

  /** Get links by category */
  getByCategory(categoryId: string): Observable<Link[]> {
    return this.http.get<Link[]>(`${this.apiUrl}/category/${categoryId}`);
  }

  /** Create a new link */
  create(data: { name: string; url: string; categoryId?: string | null }): Observable<any> {
    return this.http.post(this.apiUrl, data);
  }

  /** Update an existing link */
  update(id: string, data: { name: string; url: string; categoryId?: string | null }): Observable<any> {
    return this.http.put(`${this.apiUrl}/${id}`, data);
  }

  /** Delete a link */
  remove(id: string): Observable<any> {
    return this.http.delete(`${this.apiUrl}/${id}`);
  }
}
