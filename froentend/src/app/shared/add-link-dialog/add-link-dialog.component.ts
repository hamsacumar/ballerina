import { Component, Inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { MatDialogModule, MatDialogRef, MAT_DIALOG_DATA } from '@angular/material/dialog';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatInputModule } from '@angular/material/input';
import { MatButtonModule } from '@angular/material/button';

export interface LinkDialogData {
  name?: string;
  url?: string;
  mode: 'create' | 'edit';
  id?: string;
  categoryId: string;
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
    if (this.data.mode === 'edit') {
      if (this.data.name) this.linkName = this.data.name;
      if (this.data.url) this.linkUrl = this.data.url;
    }
  }

  onCancel(): void {
    this.dialogRef.close();
  }

  onDone(): void {
    if (!this.linkName.trim() || !this.linkUrl.trim()) return;
    const finalUrl = this.linkUrl.startsWith('http') ? this.linkUrl : `https://${this.linkUrl}`;
    this.dialogRef.close({
      name: this.linkName.trim(),
      url: finalUrl,
      mode: this.data.mode,
      id: this.data.id,
      categoryId: this.data.categoryId
    });
  }
}
