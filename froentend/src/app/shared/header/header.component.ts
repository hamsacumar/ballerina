import { Component, ElementRef, HostListener, ViewChild } from '@angular/core';
import { Router, RouterModule } from '@angular/router';
import { CommonModule } from '@angular/common';
import { ProfileComponent } from '../../profile/profile.component'; // Import ProfileComponent

@Component({
  selector: 'app-header',
  standalone: true,
  imports: [CommonModule, RouterModule, ProfileComponent], // Add ProfileComponent here
  templateUrl: './header.component.html',
  styleUrls: ['./header.component.css'],
})

export class HeaderComponent {
  @ViewChild('profileDropdown', { static: false }) profileDropdown!: ElementRef;
  isProfileModalOpen = false; // Changed from isProfileDropdownOpen

  constructor(private router: Router) {}

  isDarkMode = false;
isBackendMode = false;

toggleDarkMode() {
  this.isDarkMode = !this.isDarkMode;

  if (this.isDarkMode) {
    document.body.classList.add('dark-mode');
  } else {
    document.body.classList.remove('dark-mode');
  }
}


  toggleProfileModal(): void {
    // Renamed method
    this.isProfileModalOpen = !this.isProfileModalOpen;
  }

  closeProfileModal(): void {
    // Renamed method
    this.isProfileModalOpen = false;
  }

  logout(): void {
    this.closeProfileModal(); // Updated method name
    localStorage.removeItem('userToken');
    this.router.navigate(['/login']);
  }

  @HostListener('document:click', ['$event'])
  onClickOutside(event: Event) {
    if (
      this.profileDropdown &&
      !this.profileDropdown.nativeElement.contains(event.target)
    ) {
      this.closeProfileModal(); // Updated method name
    }
  }

  @HostListener('document:keydown.escape')
  onEscapeKey() {
    this.closeProfileModal(); // Updated method name
  }
}
