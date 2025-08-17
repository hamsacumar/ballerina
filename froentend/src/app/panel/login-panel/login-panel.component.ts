import { Component, Output, EventEmitter, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ReactiveFormsModule, FormBuilder, FormGroup, Validators } from '@angular/forms';
import { MatInputModule } from '@angular/material/input';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { MatIconModule } from '@angular/material/icon';
import { Router } from '@angular/router';
import { MatSnackBar } from '@angular/material/snack-bar';
import { AuthService, LoginResponse } from '../../service/auth.service';
import { LoginRequest } from '../../model/login.model';

@Component({
  selector: 'app-login-panel',
  standalone: true,
  imports: [
    CommonModule,
    ReactiveFormsModule,
    MatInputModule,
    MatButtonModule,
    MatCardModule,
    MatIconModule
  ],
  templateUrl: './login-panel.component.html',
  styleUrls: ['./login-panel.component.css']
})
export class LoginPanelComponent implements OnInit {
  @Output() viewChange = new EventEmitter<string>();
  loginForm!: FormGroup;
  showPassword: boolean = false;



  constructor(
    private fb: FormBuilder,
    private auth: AuthService,
    private router: Router,
    private snackBar: MatSnackBar
  ) { }

  ngOnInit(): void {
    this.loginForm = this.fb.group({
      username: [
        '',
        [
          Validators.required,
          Validators.minLength(4),
          Validators.maxLength(20),
          Validators.pattern('^[a-zA-Z0-9._-]+$') // allow only letters, numbers, ., _, -
        ]
      ],
      password: [
        '',
        [
          Validators.required,
          Validators.minLength(6),
          Validators.maxLength(30)
        ]
      ]
    });
  }

  get username() {
    return this.loginForm.get('username');
  }

  get password() {
    return this.loginForm.get('password');
  }


  onLogin(): void {
    console.log('Login form submitted');
    console.log('Form value:', this.loginForm.value);
    console.log('Form valid:', this.loginForm.valid);
    console.log('Form errors:', this.loginForm.errors);

    // Log individual field status
    Object.keys(this.loginForm.controls).forEach(key => {
      const control = this.loginForm.get(key);
      console.log(`Field ${key}:`, {
        value: control?.value,
        valid: control?.valid,
        errors: control?.errors,
        dirty: control?.dirty,
        touched: control?.touched
      });
    });

    if (this.loginForm.invalid) {
      console.log('Form is invalid');
      this.snackBar.open('Please fill in all required fields correctly', 'Close', { duration: 5000 });
      return;
    }

    // Use form values directly since they now match the API
    const payload: LoginRequest = this.loginForm.value;
    console.log('Sending login request with payload:', payload);

    this.auth.login(payload).subscribe({
      next: (res: LoginResponse) => {
        console.log('Login response received:', res);

        if (!res?.token) {
          console.error('No token in response');
          this.snackBar.open('No authentication token received', 'Close', { duration: 3000 });
          return;
        }

        // Store token and user data
        localStorage.setItem('authToken', res.token);
        localStorage.setItem('user', JSON.stringify(res.user));
        console.log('Token and user data stored in localStorage');

        // Show success message
        this.snackBar.open('Login successful!', 'Close', { duration: 2000 });

        console.log('Emitting viewChange event with:', 'home');
        console.log('viewChange.observed:', this.viewChange.observed);

        // Emit view change event for parent components (landing page)
        this.viewChange.emit('home');

        // Only navigate if we're not in the landing page context
        if (!this.viewChange.observed) {
          console.log('Navigating to /home via router');
          this.router.navigate(['/home']);
        }
      },
      error: (err) => {
        const errorMessage = err?.error?.message || 'Login failed. Please try again.';
        this.snackBar.open(errorMessage, 'Close', { duration: 5000 });
        console.error('Login error:', err);
      }
    });
  }

  navigateTo(view: string): void {
    // Emit view change event for parent components (landing page)
    this.viewChange.emit(view);

    // Only navigate if we're not in the landing page context
    if (!this.viewChange.observed) {
      this.router.navigate([view]);
    }
  }
}
