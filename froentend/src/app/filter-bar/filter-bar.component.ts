import { Component, EventEmitter, Output } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';

@Component({
  selector: 'app-filter-bar',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './filter-bar.component.html',
  styleUrls: ['./filter-bar.component.css']
})
export class FilterBarComponent {
  fromDate: string = '';
  toDate: string = '';

  @Output() filterChange = new EventEmitter<{ from: string; to: string }>();

  onFilter() {
    this.filterChange.emit({ from: this.fromDate, to: this.toDate });
  }
}
