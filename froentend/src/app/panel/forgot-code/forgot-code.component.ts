import { Component, Output, EventEmitter } from '@angular/core';

@Component({
  selector: 'app-forgot-code',
  imports: [],
  templateUrl: './forgot-code.component.html',
  styleUrl: './forgot-code.component.css'
})
export class ForgotCodeComponent {
  @Output() viewChange = new EventEmitter<string>();

  navigateTo(view: string): void {
    this.viewChange.emit(view);
  }
}
