import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { ChartResponse } from '../model/monthly-chart-data.model';

@Injectable({
  providedIn: 'root'
})
export class ChartService {
  private apiUrl = 'http://localhost:9093/admin/monthlyBarChart';

  constructor(private http: HttpClient) {}

  getMonthlyChartData(year: number): Observable<ChartResponse> {
    return this.http.get<ChartResponse>(`${this.apiUrl}?year=${year}`);
  }
}
