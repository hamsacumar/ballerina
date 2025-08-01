import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { TestserviceService } from '../service/testservice.service';
import { TestDoc } from '../model/testdata.model';

@Component({
  selector: 'app-test',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './test.component.html',
  styleUrls: ['./test.component.css']
})

export class TestComponent implements OnInit {
  testDocs: TestDoc[] = [];
  loading = true;
  error: string | null = null;

  constructor(private testService: TestserviceService) {}

  ngOnInit(): void {
    this.loadData();
  }

  loadData(): void {
    this.loading = true;
    this.error = null;
    this.testService.getTestData().subscribe({
      next: (data) => {
        this.testDocs = data;
        this.loading = false;
      },
      error: (err) => {
        console.error('Error fetching data:', err);
        this.error = 'Failed to load data. Make sure the backend server is running at http://localhost:9091';
        this.loading = false;
      }
    });
  }


}