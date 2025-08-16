import { Component, Output, EventEmitter, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ReactiveFormsModule, FormBuilder, FormGroup, Validators } from '@angular/forms';
import { MatInputModule } from '@angular/material/input';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { MatIconModule } from '@angular/material/icon';
import { Router } from '@angular/router';
import { MatSnackBar } from '@angular/material/snack-bar';
import { AuthService } from '../../service/auth.service';

@Component({
  selector: 'app-changepassword-panel',
  standalone: true,
  imports: [
    CommonModule,
    ReactiveFormsModule,
    MatInputModule,
    MatButtonModule,
    MatCardModule,
    MatIconModule
  ],
  templateUrl: './changepassword-panel.component.html',
  styleUrls: ['./changepassword-panel.component.css']
})
export class ChangepasswordPanelComponent implements OnInit {
  @Output() viewChange = new EventEmitter<string>();
  changePasswordForm!: FormGroup;
  hidePassword = true;
  hideConfirmPassword = true;

  constructor(
    private fb: FormBuilder,
    private auth: AuthService,
    private router: Router,
    private snackBar: MatSnackBar
  ) {}

  verificationCode: string = '';

  ngOnInit(): void {
    const savedEmail = localStorage.getItem('resetEmail') || '';
    const savedCode = localStorage.getItem('resetCode') || '';
  
    this.changePasswordForm = this.fb.group({
      email: [savedEmail, [Validators.required, Validators.email]],
      verificationCode: [savedCode, [Validators.required, Validators.minLength(6)]],
      newPassword: ['', [Validators.required, Validators.minLength(6)]],
      confirmPassword: ['', [Validators.required]]
    }, { validators: this.passwordsMatchValidator });
  }
  

  // Validator to ensure newPassword and confirmPassword match
  private passwordsMatchValidator(form: FormGroup) {
    const password = form.get('newPassword')?.value;
    const confirmPassword = form.get('confirmPassword')?.value;
    return password === confirmPassword ? null : { passwordMismatch: true };
  }

  onChangePassword(): void {
    this.changePasswordForm.markAllAsTouched();
  
    if (this.changePasswordForm.invalid) {
      this.snackBar.open('Please fill in all fields correctly', 'Close', { duration: 5000 });
      return;
    }
  
    const { email, verificationCode, newPassword } = this.changePasswordForm.value;
  
    const snackBarRef = this.snackBar.open('Resetting password...', undefined, { duration: 0 });
  
    this.auth.resetPassword({ 
      email, 
      resetCode: verificationCode,
      newPassword 
    }).subscribe({
      next: () => {
        snackBarRef.dismiss();
        this.snackBar.open('Password changed successfully!', 'Close', { duration: 3000, panelClass: 'success-snackbar' });
  
        // ✅ clean localStorage
        localStorage.removeItem('resetEmail');
        localStorage.removeItem('resetCode');
  
        this.viewChange.emit('login');
      },
      error: (err) => {
        snackBarRef.dismiss();
        const errorMessage = err?.error?.message || 'Password change failed. Please try again.';
        this.snackBar.open(errorMessage, 'Close', { 
          duration: 5000,
          panelClass: 'error-snackbar'
        });
        console.error('Password change error:', err);
      }
    });
  }
  

  navigateTo(view: string): void {
    this.viewChange.emit(view);
    if (!this.viewChange.observed) {
      this.router.navigate([view]);
    }
  }
}
