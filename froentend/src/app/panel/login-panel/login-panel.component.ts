import { Component, Output, EventEmitter, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ReactiveFormsModule, FormBuilder, FormGroup, Validators } from '@angular/forms';
import { MatInputModule } from '@angular/material/input';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { MatIconModule } from '@angular/material/icon';
import { AuthService } from '../../service/auth.service';
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

  constructor(private fb: FormBuilder, private authService: AuthService) {}

  ngOnInit(): void {
    this.loginForm = this.fb.group({
      username: ['', [Validators.required, Validators.email]], // treat username as email
      password: ['', Validators.required]
    });
  }

  onLogin(): void {
  if (this.loginForm.valid) {
    const payload: LoginRequest = this.loginForm.value;

    this.authService.login(payload).subscribe({
      next: (res) => {
        console.log('Login successful', res);

        // ✅ Save token for future requests
        if (res.token) {
          localStorage.setItem('authToken', res.token);
        }

        // Navigate to profile/dashboard
        this.viewChange.emit('profile');
      },
      error: (err) => {
        console.error('Login failed', err);
        alert('Invalid credentials, please try again.');
      }
    });
  }
}


  navigateTo(view: string): void {
    this.viewChange.emit(view);
  }
}
