import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { UserService } from '../service/user.service';
import { User } from '../model/admin_user.model';
import { SearchBarComponent } from '../search-bar/search-bar.component';
import { FilterBarComponent } from '../filter-bar/filter-bar.component';
import { HeaderComponent } from '../shared/header/header.component';
import { FooterComponent } from '../shared/footer/footer.component';

@Component({
  selector: 'app-user-list',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule,
    SearchBarComponent,
    FilterBarComponent,
    HeaderComponent,
    FooterComponent
  ],
  templateUrl: './user-list.component.html',
  styleUrls: ['./user-list.component.css']
})
export class UserListComponent implements OnInit {
  users: User[] = [];
  filteredUsers: User[] = [];
  loading = true;
  errorMessage = '';

  constructor(private userService: UserService) {}

  ngOnInit(): void {
    this.fetchUsers();
  }

  fetchUsers(): void {
    this.userService.getUsers().subscribe({
      next: (data) => {
        this.users = data;
        this.filteredUsers = data;
        this.loading = false;
      },
      error: (error) => {
        console.error('Error loading users:', error);
        this.errorMessage = 'Failed to load users';
        this.loading = false;
      }
    });
  }

  onSearch(query: string) {
    this.applyFilters(query, undefined);
  }

  onFilter(range: { from: string; to: string }) {
    this.applyFilters(undefined, range);
  }

  private applyFilters(query?: string, range?: { from: string; to: string }) {
    this.filteredUsers = this.users.filter(user => {
      let matchesQuery = true;
      let matchesDate = true;

      if (query) {
        matchesQuery =
          user.name.toLowerCase().includes(query.toLowerCase()) ||
          user.email.toLowerCase().includes(query.toLowerCase());
      }

      if (range) {
        const createdAt = new Date(user.createdAt).getTime();
        const from = range.from ? new Date(range.from).getTime() : null;
        const to = range.to ? new Date(range.to).getTime() : null;

        if (from && createdAt < from) matchesDate = false;
        if (to && createdAt > to) matchesDate = false;
      }

      return matchesQuery && matchesDate;
    });
  }
}
