import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { MonthlyChartData } from '../model/monthly-chart-data.model';

@Injectable({
  providedIn: 'root'
})
export class ChartService {
  private apiUrl = 'http://localhost:9093/admin/monthlyBarChart'; // your Ballerina API

  constructor(private http: HttpClient) { }

  getMonthlyChartData(): Observable<{ chartData: MonthlyChartData[], chartConfig: any, message: string }> {
    return this.http.get<{ chartData: MonthlyChartData[], chartConfig: any, message: string }>(this.apiUrl);
  }
}
