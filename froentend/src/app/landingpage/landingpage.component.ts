import { Component ,CUSTOM_ELEMENTS_SCHEMA } from '@angular/core';
import { CommonModule } from '@angular/common';
import { LoginPanelComponent } from '../panel/login-panel/login-panel.component';
import { RegisterPanelComponent } from '../panel/register-panel/register-panel.component';
import { ForgotpasswordPanelComponent } from '../panel/forgotpassword-panel/forgotpassword-panel.component';
import { VerifyPanelComponent } from '../panel/verify-panel/verify-panel.component';
import { ForgotCodeComponent } from "../panel/forgot-code/forgot-code.component";
import { UploadProfilePanelComponent } from '../panel/upload-profile-panel/upload-profile-panel.component';

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
    UploadProfilePanelComponent
],
  templateUrl: './landingpage.component.html',
  styleUrls: ['./landingpage.component.css'],
  schemas: [CUSTOM_ELEMENTS_SCHEMA ]
})

export class LandingpageComponent {
  activeView: string = 'login';

  setView(event: Event | string) {
    // If event is a string, use it directly
    if (typeof event === 'string') {
      this.activeView = event;
    } 
    // If it's an event from a select element
    else if (event && event.target) {
      this.activeView = (event.target as HTMLSelectElement).value;
    }
  }
}
