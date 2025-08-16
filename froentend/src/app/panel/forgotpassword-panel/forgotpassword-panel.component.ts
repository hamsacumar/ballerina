import { Component, Output, EventEmitter } from '@angular/core';
import { AuthService } from '../../service/auth.service'; // Make sure path is correct
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';

@Component({
  selector: 'app-forgotpassword-panel',
  imports: [
    CommonModule,
    FormsModule
  ],
  templateUrl: './forgotpassword-panel.component.html',
  styleUrls: ['./forgotpassword-panel.component.css']
})
export class ForgotpasswordPanelComponent {
  @Output() viewChange = new EventEmitter<string>();

  email: string = '';

  constructor(private authService: AuthService) {}

  navigateTo(view: string): void {
    this.viewChange.emit(view);
  }

  sendCode(): void {
    if (!this.email) return;
  
    // Save email to local storage for later (reset step)
    localStorage.setItem('resetEmail', this.email);
  
    this.authService.forgotPassword({ email: this.email }).subscribe({
      next: (res) => {
        console.log('✅ Verification code sent', res);
        this.navigateTo('forgotpasswordcode'); 
      },
      error: (err) => {
        console.error('❌ Error sending code', err);
  
        // Optional: still navigate so attacker can't guess which emails exist
        this.navigateTo('forgotpasswordcode');
      }
    });
  }  
}
