import { Component, Output, EventEmitter} from '@angular/core';
import { CommonModule } from '@angular/common';
import { ReactiveFormsModule, FormBuilder, FormGroup, Validators } from '@angular/forms';
import { AuthService  } from '../../service/auth.service';
import { RegisterRequest } from '../../model/register.model';

@Component({
  selector: 'app-register-panel',
  standalone: true,
  imports: [
    CommonModule,
    ReactiveFormsModule,
  ],
  templateUrl: './register-panel.component.html',
  styleUrls: ['./register-panel.component.css']
})
export class RegisterPanelComponent {
   @Output() viewChange = new EventEmitter<string>();
  registerForm: FormGroup;

  constructor(private fb: FormBuilder, private AuthService : AuthService ) {
    this.registerForm = this.fb.group({
      username: ['', Validators.required],
      email: ['', [Validators.required, Validators.email]],
      password: ['', Validators.required],
      confirmPassword: ['', Validators.required]
    });
  }

  onVerify(): void {
    if (this.registerForm.valid) {
      const { username, email, password, confirmPassword } = this.registerForm.value;

      if (password !== confirmPassword) {
        alert('Passwords do not match');
        return;
      }

      const payload: RegisterRequest = { username, email, password };

      this.AuthService .register(payload).subscribe({
        next: (res) => {
          console.log('Registration successful', res);
          this.viewChange.emit('verify');
        },
        error: (err) => {
          console.error('Registration failed', err);
          alert('Something went wrong. Try again.');
        }
      });
    }
  }

  navigateTo(view: string): void {
    this.viewChange.emit(view);
  }
}
