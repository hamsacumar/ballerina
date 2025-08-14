import { Routes } from '@angular/router';
import { TestComponent } from './test/test.component';
import { LandingpageComponent } from './landingpage/landingpage.component';

export const routes: Routes = [
  { path: 'test', component: TestComponent },
  { path: '', component: LandingpageComponent },
  { path: '**', redirectTo: '', pathMatch: 'full' }
];
