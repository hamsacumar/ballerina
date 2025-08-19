// monthly-chart-data.model.ts
export interface MonthlyChartData {
  x: string;        // Display month name (e.g., Jan 2025)
  month: string;    // Raw month key (e.g., 2025-01)
  links: number;
  categories: number;
  users: number;
  total: number;
  isCurrent: boolean;
}
