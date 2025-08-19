import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Chart, registerables } from 'chart.js';
import { ChartService } from '../service/chart.service';
import { ChartResponse, MonthlyChartData } from '../model/monthly-chart-data.model';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { HeaderComponent } from '../shared/header/header.component';
import { FooterComponent } from '../shared/footer/footer.component';

Chart.register(...registerables);

@Component({
  selector: 'app-monthly-bar-chart',
  standalone: true,
  imports: [CommonModule, FormsModule, HeaderComponent, FooterComponent],
  templateUrl: './monthly-bar-chart.component.html',
  styleUrls: ['./monthly-bar-chart.component.css']
})
export class MonthlyBarChartComponent implements OnInit {
  chartData: MonthlyChartData[] = [];
  selectedYear: number = new Date().getFullYear();

  linksChart: any;
  usersChart: any;
  categoriesChart: any;

  constructor(private chartService: ChartService, private router: Router) {}

  ngOnInit(): void {
    this.loadChartData();
  }

  applyFilter(): void {
    this.loadChartData();  // reload chart with selected year
  }

  loadChartData(): void {
    this.chartService.getMonthlyChartData(this.selectedYear).subscribe((res: ChartResponse) => {
      this.chartData = res.chartData.filter(d => d.year === this.selectedYear);

      if (this.linksChart) this.linksChart.destroy();
      if (this.usersChart) this.usersChart.destroy();
      if (this.categoriesChart) this.categoriesChart.destroy();

      const months = this.chartData.map(d => d.month);

      this.linksChart = new Chart("linksChartCanvas", {
        type: 'bar',
        data: {
          labels: months,
          datasets: [{
            label: "Links",
            data: this.chartData.map(d => d.links),
            backgroundColor: "#F4A460"
          }]
        },
        options: { responsive: true }
      });

      this.usersChart = new Chart("usersChartCanvas", {
        type: 'bar',
        data: {
          labels: months,
          datasets: [{
            label: "Users",
            data: this.chartData.map(d => d.users),
            backgroundColor: "#DC143C"
          }]
        },
        options: { responsive: true }
      });

      this.categoriesChart = new Chart("categoriesChartCanvas", {
        type: 'bar',
        data: {
          labels: months,
          datasets: [{
            label: "Categories",
            data: this.chartData.map(d => d.categories),
            backgroundColor: "#4169E1"
          }]
        },
        options: { responsive: true }
      });
    });
  }

  onYearChange(): void {
    this.loadChartData();
  }

  goBack(): void {
    this.router.navigate(['/userlist']); 
  }
}
