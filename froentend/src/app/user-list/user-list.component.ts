import { Component, OnInit } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { CommonModule } from '@angular/common';

interface User {
  _id: any;
  name: string;
  email: string;
  linkCount: number;
  categoryCount: number;
  createdAt: string;
  lastUpdated: string;
}

@Component({
  selector: 'app-user-list',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './user-list.component.html',
  styleUrls: ['./user-list.component.css']
})
export class UserListComponent implements OnInit {
  users: User[] = [];
  loading = true;
  errorMessage = '';

  constructor(private http: HttpClient) {}

  ngOnInit(): void {
    this.fetchUsers();
  }

  fetchUsers(): void {
    this.http.get<User[]>('http://localhost:9093/admin/users')
      .subscribe({
        next: (data) => {
          this.users = data;
          this.loading = false;
          console.log('Users loaded:', data);
        },
        error: (error) => {
          console.error('Error loading users:', error);
          this.errorMessage = 'Failed to load users';
          this.loading = false;
        }
      });
  }
}