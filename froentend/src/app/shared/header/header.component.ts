import { Component, ElementRef, HostListener, ViewChild } from '@angular/core';
import { Router, RouterModule } from '@angular/router';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-header',
  standalone: true, // Mark as standalone
  imports: [CommonModule, RouterModule], // Required for *ngIf and routerLink
  templateUrl: './header.component.html',
  styleUrls: ['./header.component.css']
})
export class HeaderComponent {
  @ViewChild('profileDropdown', { static: false }) profileDropdown!: ElementRef;
  isProfileDropdownOpen = false;

  constructor(private router: Router) {}

  toggleProfileDropdown(): void {
    this.isProfileDropdownOpen = !this.isProfileDropdownOpen;
  }

  closeProfileDropdown(): void {
    this.isProfileDropdownOpen = false;
  }

  openSettings(): void {
    this.closeProfileDropdown();
    this.router.navigate(['/profile']);
  }

  logout(): void {
    this.closeProfileDropdown();
    localStorage.removeItem('userToken');
    this.router.navigate(['/login']);
  }

  @HostListener('document:click', ['$event'])
  onClickOutside(event: Event) {
    if (this.profileDropdown && !this.profileDropdown.nativeElement.contains(event.target)) {
      this.closeProfileDropdown();
    }
  }

  @HostListener('document:keydown.escape')
  onEscapeKey() {
    this.closeProfileDropdown();
  }
}