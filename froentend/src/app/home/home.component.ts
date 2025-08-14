import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { HeaderComponent } from '../shared/header/header.component';
import { FooterComponent } from '../shared/footer/footer.component';
import { MatButtonModule } from '@angular/material/button';
import { MatDialog } from '@angular/material/dialog';
import { MatIconModule } from '@angular/material/icon'; // Add this import

import { AddCategoryDialogComponent } from '../shared/add-category-dialog/add-category-dialog.component';
import { AddLinkDialogComponent } from '../shared/add-link-dialog/add-link-dialog.component';
@Component({
  selector: 'app-home',
  standalone: true,
  imports: [
    CommonModule,
    HeaderComponent,
    FooterComponent,
    MatButtonModule,
    MatIconModule, // Add this to imports array

  ],
  templateUrl: './home.component.html',
  styleUrls: ['./home.component.css']
})
export class HomeComponent {
  constructor(private dialog: MatDialog) {}

  openAddCategoryDialog() {
    const dialogRef = this.dialog.open(AddCategoryDialogComponent, {
      width: '400px',
      data: { name: '' }
    });

    dialogRef.afterClosed().subscribe(result => {
      if (result) {
        console.log('New category:', result.name);
        // Handle the saved category here
      }
    });
  }
 openAddLinkDialog(): void {
    const dialogRef = this.dialog.open(AddLinkDialogComponent, {
      width: '400px'
    });

    dialogRef.afterClosed().subscribe(result => {
      if (result) {
        console.log('New link:', result);
        // Handle the saved link here
      }
    });
  }

}
