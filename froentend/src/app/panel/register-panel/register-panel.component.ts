import { Component, Output, EventEmitter } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ReactiveFormsModule, FormBuilder, FormGroup, Validators, AbstractControl, ValidationErrors, ValidatorFn } from '@angular/forms';
import { AuthService } from '../../service/auth.service';
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

  constructor(private fb: FormBuilder, private AuthService: AuthService) {
    this.registerForm = this.fb.group({
      username: [
        '',
        [
          Validators.required,
          Validators.minLength(4),
          Validators.maxLength(20),
          Validators.pattern('^[a-zA-Z0-9._-]+$') // only alphanumeric + . _ -
        ]
      ],
      email: ['', [Validators.required, Validators.email]],
      password: [
        '',
        [
          Validators.required,
          Validators.minLength(6),
          Validators.maxLength(30),
          Validators.pattern(/^(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]+$/)
          // At least 1 uppercase, 1 number, 1 special char
        ]
      ],
      confirmPassword: ['', Validators.required]
    }, { validators: this.passwordsMatchValidator }); // custom validator
  }

  // ✅ Custom validator for confirm password
  passwordsMatchValidator: ValidatorFn = (group: AbstractControl): ValidationErrors | null => {
    const password = group.get('password')?.value;
    const confirmPassword = group.get('confirmPassword')?.value;
    return password === confirmPassword ? null : { passwordsMismatch: true };
  };

  onVerify(): void {
    if (this.registerForm.invalid) return;

    const { username, email, password } = this.registerForm.value;
    const payload: RegisterRequest = { username, email, password };

    this.AuthService.register(payload).subscribe({
      next: () => {
        localStorage.setItem('email', email);   // used by verify
        this.viewChange.emit('verify');         // go to verify screen
      },
      error: (e) => alert(e?.error?.message ?? 'Registration failed')
    });
  }

  navigateTo(view: string): void {
    this.viewChange.emit(view);
  }

  // ✅ For easier template usage
  get username() { return this.registerForm.get('username'); }
  get email() { return this.registerForm.get('email'); }
  get password() { return this.registerForm.get('password'); }
  get confirmPassword() { return this.registerForm.get('confirmPassword'); }
}
