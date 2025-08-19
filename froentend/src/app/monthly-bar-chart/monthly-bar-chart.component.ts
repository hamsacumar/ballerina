import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ChartService } from '../../service/chart.service';
import { MonthlyChartData } from '../model/monthly-chart-data.model';
import { Chart, registerables } from 'chart.js';
import { FormsModule } from '@angular/forms';  

// Import Header & Footer
import { HeaderComponent } from '../shared/header/header.component';
import { FooterComponent } from '../shared/footer/footer.component';

Chart.register(...registerables);

@Component({
  selector: 'app-monthly-bar-chart',
  standalone: true,
  imports: [CommonModule, HeaderComponent, FooterComponent,FormsModule],
  templateUrl: './monthly-bar-chart.component.html',
  styleUrls: ['./monthly-bar-chart.component.css']
})
export class MonthlyBarChartComponent implements OnInit {
  chartData: MonthlyChartData[] = [];
  filteredData: MonthlyChartData[] = [];
  availableYears: number[] = [];
  selectedYear: number = new Date().getFullYear();

  constructor(private chartService: ChartService) {}

  ngOnInit(): void {
    this.loadChart();
  }

  goBack(): void {
    window.history.back();
  }

  loadChart(): void {
    this.chartService.getMonthlyChartData().subscribe({
      next: (response) => {
        this.chartData = response.chartData; // contains ALL years
        this.extractYears();
        this.filterByYear(this.selectedYear, response.chartConfig);
      },
      error: (err) => console.error('Error loading chart data:', err)
    });
  }

  extractYears(): void {
    // Extract unique years from chartData.x (assuming format "Jan 2023")
    const years = this.chartData.map(d => new Date(d.x).getFullYear());
    this.availableYears = [...new Set(years)];
  }

  filterByYear(year: number, config: any): void {
    this.selectedYear = year;
    this.filteredData = this.chartData.filter(
      d => new Date(d.x).getFullYear() === year
    );

    const labels = this.filteredData.map(d =>
      new Date(d.x).toLocaleString('default', { month: 'short' }) // "Jan", "Feb"
    );

    // Render charts with filtered data
    this.renderChart(
      'linksBarChartCanvas',
      labels,
      this.filteredData.map(d => d.links),
      config.labels['links'],
      config.colors['links']
    );

    this.renderChart(
      'categoriesBarChartCanvas',
      labels,
      this.filteredData.map(d => d.categories),
      config.labels['categories'],
      config.colors['categories']
    );

    this.renderChart(
      'usersBarChartCanvas',
      labels,
      this.filteredData.map(d => d.users),
      config.labels['users'],
      config.colors['users']
    );
  }

  renderChart(
    canvasId: string,
    labels: string[],
    data: number[],
    label: string,
    color: string
  ) {
    const canvas = document.getElementById(canvasId) as HTMLCanvasElement;
    if (!canvas) return;

    // Destroy old chart if exists (to avoid duplicate canvas bug)
    if (Chart.getChart(canvasId)) {
      Chart.getChart(canvasId)?.destroy();
    }

    new Chart(canvas, {
      type: 'bar',
      data: {
        labels,
        datasets: [
          {
            label,
            data,
            backgroundColor: color
          }
        ]
      },
      options: {
        responsive: true,
        plugins: {
          legend: { display: true },
          title: { display: true, text: label }
        },
        scales: {
          x: { title: { display: true, text: 'Months' } },
          y: { title: { display: true, text: 'Count' }, beginAtZero: true }
        }
      }
    });
  }
}
