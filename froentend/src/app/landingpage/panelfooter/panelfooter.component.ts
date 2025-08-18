import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-panelfooter',
  imports: [CommonModule],
  templateUrl: './panelfooter.component.html',
  styleUrl: './panelfooter.component.css'
})
export class PanelfooterComponent {
  currentYear = new Date().getFullYear();
}
