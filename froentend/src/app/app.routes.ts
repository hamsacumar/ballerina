// src/app/app.routes.ts
import { Routes } from '@angular/router';
import { TestComponent } from './test/test.component';
import { HeaderComponent } from './shared/header/header.component';
import { HomeComponent } from './home/home.component';
import { FooterComponent } from './shared/footer/footer.component';
import { AddLinkDialogComponent } from './shared/add-link-dialog/add-link-dialog.component';
import { LandingpageComponent } from './landingpage/landingpage.component';
import { UserListComponent } from './user-list/user-list.component';
// import { HomeComponent } from './home/home.component';
import { ProfileComponent } from './profile/profile.component';
import { AuthGuard } from '../app/guard/auth.guard';

export const routes: Routes = [
  {
    path: '',
    component: LandingpageComponent,
    children: [
      { path: 'login', redirectTo: '', pathMatch: 'full' },
      { path: 'register', redirectTo: '', pathMatch: 'full' },
    ],
  },
  { 
    path: 'home', 
    component: HomeComponent, 
    canActivate: [AuthGuard] 
  },
  { 
    path: 'userlist', 
    component: UserListComponent,
    canActivate: [AuthGuard],
    data: { roles: ['admin'] }
  },
  { path: 'test', component: TestComponent },
  { path: 'header', component: HeaderComponent },
  { path: 'footer', component: FooterComponent },
  { path: 'add-link', component: AddLinkDialogComponent },
  // { path: 'home', component:HomeComponent },
  
  { path: '**', redirectTo: '' }, // Catch-all route
 
  { path: 'profile', component: ProfileComponent },
  { path: '**', redirectTo: '' }, // Catch-all route
];
