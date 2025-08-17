import { Component, Output, EventEmitter, OnInit, QueryList, ViewChildren, ElementRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';

@Component({
  selector: 'app-forgot-code',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './forgot-code.component.html',
  styleUrls: ['./forgot-code.component.css']
})
export class ForgotCodeComponent implements OnInit {
  @Output() viewChange = new EventEmitter<{ view: string, data?: any }>();

  email: string = '';
  error: string = '';

  codeInputs: string[] = Array(6).fill('');

  @ViewChildren('codeInput') codeInputRefs!: QueryList<ElementRef<HTMLInputElement>>;

  ngOnInit() {
    const savedEmail = localStorage.getItem('resetEmail');
    if (savedEmail) {
      this.email = savedEmail;
    }
  }

  moveToNext(event: Event, index: number) {
    const input = event.target as HTMLInputElement;

    // Always allow only 1 char
    if (input.value.length > 1) {
      input.value = input.value.charAt(0);
      this.codeInputs[index] = input.value;
    }

    // Move to next
    if (input.value && index < this.codeInputs.length - 1) {
      this.codeInputRefs.toArray()[index + 1].nativeElement.focus();
    }
  }

  moveToPrev(event: KeyboardEvent, index: number) {
    if (event.key === 'Backspace' && !this.codeInputs[index] && index > 0) {
      this.codeInputRefs.toArray()[index - 1].nativeElement.focus();
    }
  }

  onVerify() {
    const verificationCode = this.codeInputs.join('');
    if (verificationCode.length !== 6) {
      this.error = 'Please enter a valid 6-digit code';
      return;
    }

    localStorage.setItem('resetCode', verificationCode);

    this.viewChange.emit({
      view: 'changepassword',
      data: { email: this.email, resetCode: verificationCode }
    });
  }

  navigateTo(view: string): void {
    this.viewChange.emit({ view });
  }
}
