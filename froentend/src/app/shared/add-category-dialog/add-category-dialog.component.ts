import { Component, Inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { MatDialogModule, MatDialogRef, MAT_DIALOG_DATA } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatButtonModule } from '@angular/material/button';

export interface CategoryDialogData {
  name?: string;
  mode: 'create' | 'edit';
  id?: string;
}

@Component({
  selector: 'app-add-category-dialog',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule,
    MatDialogModule,
    MatFormFieldModule,
    MatInputModule,
    MatButtonModule
  ],
  templateUrl: './add-category-dialog.component.html',
  styleUrls: ['./add-category-dialog.component.css']
})
export class AddCategoryDialogComponent implements OnInit {
  categoryName = '';

  constructor(
    public dialogRef: MatDialogRef<AddCategoryDialogComponent>,
    @Inject(MAT_DIALOG_DATA) public data: CategoryDialogData
  ) {}

  ngOnInit(): void {
    if (this.data.mode === 'edit' && this.data.name) {
      this.categoryName = this.data.name;
    }
  }

  onCancel(): void {
    this.dialogRef.close(); // closes without saving
  }

  onSave(): void {
    const trimmedName = this.categoryName.trim();
    if (!trimmedName) return; // prevent empty category

    // Close dialog and return data to HomeComponent
    this.dialogRef.close({
      name: trimmedName,
      mode: this.data.mode,
      id: this.data.id
    });
  }
}
