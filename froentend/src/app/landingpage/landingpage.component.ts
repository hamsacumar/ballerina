import { Component, CUSTOM_ELEMENTS_SCHEMA, inject } from '@angular/core';
import { Router } from '@angular/router';
import { CommonModule } from '@angular/common';
import { LoginPanelComponent } from '../panel/login-panel/login-panel.component';
import { RegisterPanelComponent } from '../panel/register-panel/register-panel.component';
import { ForgotpasswordPanelComponent } from '../panel/forgotpassword-panel/forgotpassword-panel.component';
import { VerifyPanelComponent } from '../panel/verify-panel/verify-panel.component';
import { ForgotCodeComponent } from "../panel/forgot-code/forgot-code.component";
import { UploadProfilePanelComponent } from '../panel/upload-profile-panel/upload-profile-panel.component';
import { ChangepasswordPanelComponent } from '../panel/changepassword-panel/changepassword-panel.component';

@Component({
  selector: 'app-landingpage',
  standalone: true,
  imports: [
    CommonModule,
    LoginPanelComponent,
    RegisterPanelComponent,
    ForgotpasswordPanelComponent,
    VerifyPanelComponent,
    ForgotCodeComponent,
    UploadProfilePanelComponent,
    ChangepasswordPanelComponent
],
  templateUrl: './landingpage.component.html',
  styleUrls: ['./landingpage.component.css'],
  schemas: [CUSTOM_ELEMENTS_SCHEMA ]
})

export class LandingpageComponent {
  activeView: string = 'login';

  setView(view: string) {
    console.log('setView called with:', view);
    // If the view is 'home', navigate to the home route
    if (view === 'home') {
      console.log('Navigating to /home');
      this.router.navigate(['/home']).then(success => {
        console.log('Navigation successful:', success);
      }).catch(err => {
        console.error('Navigation error:', err);
      });
      return;
    }
    // Otherwise, update the active view
    console.log('Updating activeView to:', view);
    this.activeView = view;
  }

  private router = inject(Router);
}
