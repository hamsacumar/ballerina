import { Routes } from '@angular/router';
import { TestComponent } from './test/test.component';
import { LandingpageComponent } from './landingpage/landingpage.component';
import { UserListComponent } from './user-list/user-list.component';
// import { HomeComponent } from './home/home.component';

export const routes: Routes = [
  { path: 'test', component: TestComponent },
  { path: '', component: LandingpageComponent },
  // { path: 'home', component:HomeComponent },
  { path: 'userlist', component: UserListComponent },
  { path: '**', redirectTo: '', pathMatch: 'full' }
 
];
