export interface MonthlyChartData {
  year: number;
  month: string;
  monthNumber: number;
  yearMonth: string;
  links: number;
  categories: number;
  users: number;
  total: number;
  isCurrent: boolean;
}

export interface ChartResponse {
  chartData: MonthlyChartData[];
  chartConfig: {
    xAxisKey: string;
    dataKeys: string[];
    colors: { [key: string]: string };
    labels: { [key: string]: string };
  };
  summary: {
    totalMonths: number;
    startMonth: string;
    endMonth: string;
  };
  message: string;
}
