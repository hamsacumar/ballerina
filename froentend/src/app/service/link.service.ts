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

  /** Create a new link (ALWAYS sends categoryId, even if null) */
  create(data: { name: string; url: string; categoryId?: string | null }): Observable<any> {
    const payload = {
      name: data.name,
      url: data.url,
      categoryId: data.categoryId ?? null // Explicitly send null if undefined
    };
    return this.http.post(this.apiUrl, payload);
  }

  /** Update an existing link */
  update(id: string, data: { name: string; url: string }): Observable<any> {
    const payload = {
      name: data.name,
      url: data.url,
    };
    return this.http.put(`${this.apiUrl}/${id}`, payload);
  }

  /** Delete a link */
  remove(id: string): Observable<any> {
    return this.http.delete(`${this.apiUrl}/${id}`);
  }

}