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
import { FooterComponent } from './footer/footer.component';

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
    ChangepasswordPanelComponent,
    FooterComponent
],
  templateUrl: './landingpage.component.html',
  styleUrls: ['./landingpage.component.css'],
  schemas: [CUSTOM_ELEMENTS_SCHEMA ]
})

export class LandingpageComponent {
  activeView: string = 'login';
  private router = inject(Router);

  setView(view: string | { view: string, data?: any }) {
    let viewName: string;
    let viewData: any;

    if (typeof view === 'string') {
      viewName = view;
    } else {
      viewName = view.view;
      viewData = view.data;
      // Handle any additional data if needed
      if (viewData) {
        console.log('Received data:', viewData);
        // Store the data in a service or component property if needed
      }
    }

    console.log('setView called with:', viewName);
    
    if (viewName === 'home') {
      console.log('Navigating to /home');
      this.router.navigate(['/home']).then((success: boolean) => {
        console.log('Navigation successful:', success);
      });
    } else {
      this.activeView = viewName;
    }
  }
}
