import { Component, Output, EventEmitter } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-verify-panel',
  imports: [CommonModule],
  templateUrl: './verify-panel.component.html',
  styleUrl: './verify-panel.component.css'
})
export class VerifyPanelComponent {
  @Output() viewChange = new EventEmitter<string>();

  navigateTo(view: string): void {
    this.viewChange.emit(view);
  }
}
