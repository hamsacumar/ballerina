import { Component, Output, EventEmitter } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-register-panel',
  standalone: true,
  imports: [
    CommonModule
  ],
  templateUrl: './register-panel.component.html',
  styleUrls: ['./register-panel.component.css']
})
export class RegisterPanelComponent {
  @Output() viewChange = new EventEmitter<string>();

  onVerify(): void {
    this.viewChange.emit('verify');
  }
}
