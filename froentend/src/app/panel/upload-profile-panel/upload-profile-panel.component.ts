import { Component, Output, EventEmitter } from '@angular/core';
import { ReactiveFormsModule } from '@angular/forms';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-upload-profile-panel',
  standalone: true,
  imports: [
    CommonModule,
    ReactiveFormsModule
  ],
  templateUrl: './upload-profile-panel.component.html',
  styleUrls: ['./upload-profile-panel.component.css']
})
export class UploadProfilePanelComponent {
  @Output() viewChange = new EventEmitter<string>();

  isDragOver = false;
  previewUrl: string | ArrayBuffer | null = null;
  selectedFile: File | null = null;

  navigateTo(view: string): void {
    this.viewChange.emit(view);
  }

  onDragOver(event: DragEvent) {
    event.preventDefault();
    this.isDragOver = true;
  }

  onDragLeave(event: DragEvent) {
    event.preventDefault();
    this.isDragOver = false;
  }

  onDrop(event: DragEvent) {
    event.preventDefault();
    this.isDragOver = false;
    if (event.dataTransfer?.files.length) {
      this.handleFile(event.dataTransfer.files[0]);
    }
  }

  onFileSelected(event: any) {
    if (event.target.files.length) {
      this.handleFile(event.target.files[0]);
    }
  }

  handleFile(file: File) {
    this.selectedFile = file;
    const reader = new FileReader();
    reader.onload = () => this.previewUrl = reader.result;
    reader.readAsDataURL(file);
  }

  onUpload() {
    if (!this.selectedFile) {
      alert("Please select a profile picture!");
      return;
    }
    console.log("Uploading:", this.selectedFile);
    // TODO: send file to backend via FormData
  }
}
