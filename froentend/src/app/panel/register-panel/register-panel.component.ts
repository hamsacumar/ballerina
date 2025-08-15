import { Component, Output, EventEmitter} from '@angular/core';
import { CommonModule } from '@angular/common';
import { ReactiveFormsModule, FormBuilder, FormGroup, Validators } from '@angular/forms';

@Component({
  selector: 'app-register-panel',
  standalone: true,
  imports: [
    CommonModule,
    ReactiveFormsModule
  ],
  templateUrl: './register-panel.component.html',
  styleUrls: ['./register-panel.component.css']
})
export class RegisterPanelComponent {
  @Output() viewChange = new EventEmitter<string>();

  onVerify(): void {
    this.viewChange.emit('verify');
  }

    navigateTo(view: string): void {
    this.viewChange.emit(view);
  }
}
