import { Component, Output, EventEmitter } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { AuthService  } from '../../service/auth.service';
import { VerifyEmailRequest } from '../../model/verifyemail.model';

@Component({
  selector: 'app-verify-panel',
  imports: [CommonModule,FormsModule],
  templateUrl: './verify-panel.component.html',
  styleUrl: './verify-panel.component.css'
})
export class VerifyPanelComponent {
   @Output() viewChange = new EventEmitter<string>();

  email: string = '';
  code: string[] = ['', '', '', '', '', ''];

  constructor(private AuthService : AuthService ) {
    // ✅ get saved email from localStorage (set in register component)
    this.email = localStorage.getItem('email') || '';
  }

  onVerify(): void {
    const verificationCode = this.code.join('');

    if (verificationCode.length !== 6) {
      alert('Please enter the 6-digit verification code');
      return;
    }

    const payload: VerifyEmailRequest = {
      email: this.email,
      verificationCode
    };

    this.AuthService .verifyEmail(payload).subscribe({
      next: (res) => {
        console.log('Verification successful', res);

        // ✅ clear email from localStorage once verified
        localStorage.removeItem('email');

        this.viewChange.emit('profilecode');
      },
      error: (err) => {
        console.error('Verification failed', err);
        alert('Invalid verification code');
      }
    });
  }

  navigateTo(view: string): void {
    this.viewChange.emit(view);
  }
}
