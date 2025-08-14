import { Component, Output, EventEmitter } from '@angular/core';

@Component({
  selector: 'app-forgotpassword-panel',
  imports: [],
  templateUrl: './forgotpassword-panel.component.html',
  styleUrl: './forgotpassword-panel.component.css'
})
export class ForgotpasswordPanelComponent {
  @Output() viewChange = new EventEmitter<string>();

  navigateTo(view: string): void {
    this.viewChange.emit(view);
  }
}
