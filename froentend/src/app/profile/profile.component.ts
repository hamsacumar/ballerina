import {
  Component,
  OnInit,
  ElementRef,
  ViewChild,
  inject,
} from '@angular/core';
import {
  FormBuilder,
  FormGroup,
  Validators,
  ReactiveFormsModule,
} from '@angular/forms';
import { CommonModule } from '@angular/common';
import { ProfileService } from '../service/profile.service';
import { ChangePasswordRequest, User } from '../model/profile.model';
import { Output, EventEmitter } from '@angular/core';
import { AuthService } from '../service/auth.service';
import { Router } from '@angular/router';


@Component({
  selector: 'app-profile',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './profile.component.html',
  styleUrls: ['./profile.component.css'],
})
export class ProfileComponent implements OnInit {
  @ViewChild('fileInput', { static: false }) fileInput!: ElementRef;

  private fb = inject(FormBuilder);
  private profileService = inject(ProfileService);

  private authService = inject(AuthService);
  private router = inject(Router);

  user: User | null = null;
  profileImageUrl: string = 'assets/images/default-avatar.png'; // Default avatar

  // Form states
  isEditingUsername = false;
  isChangingPassword = false;

  // Forms
  usernameForm: FormGroup;
  passwordForm: FormGroup;

  // Loading states
  isUpdatingUsername = false;
  isUpdatingPassword = false;
  isUploadingImage = false;

  // Error messages
  usernameError = '';
  passwordError = '';
  imageError = '';

  // Success messages
  usernameSuccess = '';
  passwordSuccess = '';
  imageSuccess = '';

  // Password visibility and popup states
  showOldPassword = false;
  showNewPassword = false;
  showConfirmPassword = false;
  showUsernameSuccessPopup = false;
  showPasswordSuccessPopup = false;

  constructor() {
    this.usernameForm = this.fb.group({
      newUsername: ['', [Validators.required, Validators.minLength(3)]],
    });

    this.passwordForm = this.fb.group(
      {
        oldPassword: ['', [Validators.required]],
        newPassword: ['', [Validators.required, Validators.minLength(6)]],
        confirmPassword: ['', [Validators.required]],
      },
      { validator: this.passwordMatchValidator }
    );
  }

  ngOnInit(): void {
    if (typeof localStorage !== 'undefined') {
      this.loadUserProfile();
    }
  }

  loadUserProfile(): void {
    this.profileService.getUserProfile().subscribe({
      next: (user) => {
        this.user = user;
        this.profileImageUrl =
          user.profileImage || 'assets/cloud-upload-icon.jpg';
        this.usernameForm.patchValue({
          newUsername: user.username,
        });
      },
      error: (error) => {
        console.error('Error loading profile:', error);
      },
    });
  }

  // Password match validator
  passwordMatchValidator(form: FormGroup) {
    const newPassword = form.get('newPassword');
    const confirmPassword = form.get('confirmPassword');

    if (
      newPassword &&
      confirmPassword &&
      newPassword.value !== confirmPassword.value
    ) {
      confirmPassword.setErrors({ mismatch: true });
    } else {
      if (confirmPassword?.hasError('mismatch')) {
        confirmPassword.setErrors(null);
      }
    }
    return null;
  }

  // Profile image methods
  onFileSelected(event: any): void {
    const file = event.target.files[0];
    if (file) {
      this.validateAndUploadImage(file);
    }
  }

  validateAndUploadImage(file: File): void {
    // Validate file type
    const allowedTypes = [
      'image/jpeg',
      'image/jpg',
      'image/png',
      'image/gif',
      'image/webp',
      'image/svg+xml',
      'image/bmp',
      'image/tiff',
    ];
    if (!allowedTypes.includes(file.type)) {
      this.imageError =
        'Please select a valid image file (JPG, JPEG, PNG,webpg, GIF, SVG, BMP, TIFF)';
      return;
    }

    // Validate file size (max 5MB)
    if (file.size > 5 * 1024 * 1024) {
      this.imageError = 'File size must be less than 5MB';
      return;
    }

    this.uploadProfileImage(file);
  }

  uploadProfileImage(file: File): void {
    this.isUploadingImage = true;
    this.imageError = '';
    this.imageSuccess = '';

    const formData = new FormData();
    formData.append('profileImage', file);

    this.profileService.uploadProfileImage(formData).subscribe({
      next: (response: any) => {
        this.profileImageUrl = response.imageUrl;
        this.imageSuccess = 'Profile image updated successfully!';
        this.isUploadingImage = false;
        setTimeout(() => (this.imageSuccess = ''), 3000);
      },
      error: (error) => {
        this.imageError = 'Failed to upload image. Please try again.';
        this.isUploadingImage = false;
        console.error('Image upload error:', error);
      },
    });
  }

  triggerFileInput(): void {
    this.fileInput.nativeElement.click();
  }

  // Username methods
  startEditingUsername(): void {
    this.isEditingUsername = true;
    this.usernameError = '';
    this.usernameSuccess = '';
  }

  cancelUsernameEdit(): void {
    this.isEditingUsername = false;
    this.usernameForm.patchValue({
      newUsername: this.user?.username || '',
    });
    this.usernameError = '';
  }

  updateUsername(): void {
    if (this.usernameForm.invalid) return;

    const newUsername = this.usernameForm.value.newUsername;
    if (newUsername === this.user?.username) {
      this.isEditingUsername = false;
      return;
    }

    this.isUpdatingUsername = true;
    this.usernameError = '';

    this.profileService.updateUsername(newUsername).subscribe({
      next: (response) => {
        this.user!.username = newUsername;
        this.usernameSuccess = 'Username updated successfully!';
        this.isEditingUsername = false;
        this.isUpdatingUsername = false;
        // Show success popup instead of timeout message
        this.showUsernameSuccessMessage();
        // Keep the original timeout for the inline message as fallback
        setTimeout(() => (this.usernameSuccess = ''), 3000);
      },
      error: (error) => {
        this.usernameError =
          error.error?.message || 'Failed to update username';
        this.isUpdatingUsername = false;
      },
    });
  }

  // Password methods
  startChangingPassword(): void {
    this.isChangingPassword = true;
    this.passwordError = '';
    this.passwordSuccess = '';
    this.passwordForm.reset();
  }

  cancelPasswordChange(): void {
    this.isChangingPassword = false;
    this.passwordForm.reset();
    this.passwordError = '';
  }

  updatePassword(): void {
    if (this.passwordForm.invalid) return;

    this.isUpdatingPassword = true;
    this.passwordError = '';

    const passwordRequest: ChangePasswordRequest = {
      oldPassword: this.passwordForm.value.oldPassword,
      newPassword: this.passwordForm.value.newPassword,
      confirmPassword: this.passwordForm.value.confirmPassword,
    };

    this.profileService.updatePassword(passwordRequest).subscribe({
      next: (response) => {
        this.passwordSuccess = 'Password updated successfully!';
        this.isChangingPassword = false;
        this.isUpdatingPassword = false;
        this.passwordForm.reset();
        // Show success popup instead of timeout message
        this.showPasswordSuccessMessage();
        // Keep the original timeout for the inline message as fallback
        setTimeout(() => (this.passwordSuccess = ''), 3000);
      },
      error: (error) => {
        this.passwordError =
          error.error?.message || 'Failed to update password';
        this.isUpdatingPassword = false;
      },
    });
  }

  // Password visibility toggle methods
  toggleOldPassword(): void {
    this.showOldPassword = !this.showOldPassword;
  }

  toggleNewPassword(): void {
    this.showNewPassword = !this.showNewPassword;
  }

  toggleConfirmPassword(): void {
    this.showConfirmPassword = !this.showConfirmPassword;
  }

  // Success popup methods
  showUsernameSuccessMessage(): void {
    this.showUsernameSuccessPopup = true;
    // Auto-close after 3 seconds
    setTimeout(() => {
      this.closeUsernameSuccessPopup();
    }, 3000);
  }

  closeUsernameSuccessPopup(): void {
    this.showUsernameSuccessPopup = false;
  }

  showPasswordSuccessMessage(): void {
    this.showPasswordSuccessPopup = true;
    // Auto-close after 3 seconds
    setTimeout(() => {
      this.closePasswordSuccessPopup();
    }, 3000);
  }

  closePasswordSuccessPopup(): void {
    this.showPasswordSuccessPopup = false;
  }

  // Utility methods
  get canUpdateUsername(): boolean {
    return (
      this.usernameForm.valid &&
      this.usernameForm.value.newUsername !== this.user?.username &&
      !this.isUpdatingUsername
    );
  }

  get canUpdatePassword(): boolean {
    return this.passwordForm.valid && !this.isUpdatingPassword;
  }

  clearMessages(): void {
    this.usernameError = '';
    this.usernameSuccess = '';
    this.passwordError = '';
    this.passwordSuccess = '';
    this.imageError = '';
    this.imageSuccess = '';
  }

  @Output() closeModal = new EventEmitter<void>();

  logout(): void {
    this.authService.logout().subscribe({
      next: (res) => {
        console.log('Logout response:', res);
  
        // Clear token (if stored in localStorage/sessionStorage)
        localStorage.removeItem('authToken');
        sessionStorage.removeItem('authToken');
  
        // Navigate back to login
        this.router.navigate(['/login']);
      },
      error: (err) => {
        console.error('Logout failed:', err);
      }
    });
  }
  
}
