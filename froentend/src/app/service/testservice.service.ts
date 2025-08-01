import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpClientModule } from '@angular/common/http';
import { Observable } from 'rxjs';
import { TestDoc } from '../model/testdata.model';


@Injectable({
  providedIn: 'root'
})
export class TestserviceService {
  private apiUrl = 'http://localhost:9091/data';
  private http = inject(HttpClient);

  getTestData(): Observable<TestDoc[]> {
    return this.http.get<TestDoc[]>(this.apiUrl);
  }
}
