import { Component, Output, EventEmitter } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-login-panel',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './login-panel.component.html',
  styleUrls: ['./login-panel.component.css']
})
export class LoginPanelComponent {
  @Output() viewChange = new EventEmitter<string>();

  navigateTo(view: string): void {
    this.viewChange.emit(view);
  }
}