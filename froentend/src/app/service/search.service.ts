import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';

@Injectable({
  providedIn: 'root',
})
export class SearchService {
  constructor(private http: HttpClient) {}

  search(query: string): Observable<{ links: any[]; categories: any[] }> {
    const token = localStorage.getItem('token'); // JWT stored in localStorage
    const headers = new HttpHeaders({
      Authorization: `Bearer ${token}`,
    });

    return this.http.get<{ links: any[]; categories: any[] }>(
      `${environment.apiBaseUrl}/search?query=${encodeURIComponent(query)}`,
      { headers }
    );
  }
}
