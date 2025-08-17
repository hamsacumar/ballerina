import { AuthService  } from '../../service/auth.service';
import { VerifyEmailRequest } from '../../model/verifyemail.model';
import { Component, Output, EventEmitter } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';

@Component({
  selector: 'app-verify-panel',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './verify-panel.component.html',
  styleUrls: ['./verify-panel.component.css']
})
export class VerifyPanelComponent {
  @Output() viewChange = new EventEmitter<string>();

  email = localStorage.getItem('email') || '';
  code: string[] = ['', '', '', '', '', ''];

  constructor(private auth: AuthService) {}

  onVerify(): void {
    const verificationCode = this.code.join('');
    if (verificationCode.length !== 6) {
      alert('Enter the 6-digit code');
      return;
    }

    const payload: VerifyEmailRequest = { email: this.email, verificationCode };
    this.auth.verifyEmail(payload).subscribe({
      next: () => {
        localStorage.removeItem('email'); // clean up
        this.viewChange.emit('login');    // go to login now
      },
      error: (e) => alert(e?.error?.message ?? 'Verification failed')
    });
  }

  navigateTo(view: string) {
    this.viewChange.emit(view);
  }
}
