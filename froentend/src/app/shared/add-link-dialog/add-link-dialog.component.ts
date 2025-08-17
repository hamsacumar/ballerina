import { Component, Inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { MatDialogModule, MatDialogRef, MAT_DIALOG_DATA } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatButtonModule } from '@angular/material/button';

export interface LinkDialogData {
  name?: string;          // pre-fill for edit
  url?: string;           // pre-fill for edit
  mode: 'create' | 'edit';
  id?: string;            // link id for editing
  categoryId?: string | null; // ✅ allow null/undefined for uncategorized
}

@Component({
  selector: 'app-add-link-dialog',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule,
    MatDialogModule,
    MatFormFieldModule,
    MatInputModule,
    MatButtonModule
  ],
  templateUrl: './add-link-dialog.component.html',
  styleUrls: ['./add-link-dialog.component.css']
})
export class AddLinkDialogComponent implements OnInit {
  linkName = '';
  linkUrl = '';

  constructor(
    public dialogRef: MatDialogRef<AddLinkDialogComponent>,
    @Inject(MAT_DIALOG_DATA) public data: LinkDialogData
  ) {}

  ngOnInit(): void {
    // Pre-fill fields when editing
    if (this.data.mode === 'edit') {
      if (this.data.name) this.linkName = this.data.name;
      if (this.data.url) this.linkUrl = this.data.url;
    }
  }

  /** Close dialog without saving */
  onCancel(): void {
    this.dialogRef.close();
  }

  /** Close dialog and return trimmed data for HomeComponent to save via LinkService */
  onDone(): void {
    const trimmedName = this.linkName.trim();
    const trimmedUrl = this.linkUrl.trim();
    if (!trimmedName || !trimmedUrl) return; // prevent empty input

    // Ensure URL starts with http/https
    const finalUrl = trimmedUrl.startsWith('http') ? trimmedUrl : `https://${trimmedUrl}`;

    // ✅ Always return categoryId (keeps it tied to the category when adding/editing)
    this.dialogRef.close({
      name: trimmedName,
      url: finalUrl,
      mode: this.data.mode,
      id: this.data.id,
      categoryId: this.data.categoryId ?? null
    });
  }
}
