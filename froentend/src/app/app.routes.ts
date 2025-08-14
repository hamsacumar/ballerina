import { Routes } from '@angular/router';
import { TestComponent } from './test/test.component';
import { HeaderComponent } from './shared/header/header.component';
import { HomeComponent } from './home/home.component';
import { FooterComponent } from './shared/footer/footer.component';
import { AddLinkDialogComponent } from './shared/add-link-dialog/add-link-dialog.component';


export const routes: Routes = [
    {
    path: 'test',
    component: TestComponent // ✅ directly reference the standalone component
  },

  {
    path: 'header',
    component: HeaderComponent // ✅ directly reference the standalone component
  },
  {
    path: 'home',
    component: HomeComponent // ✅ directly reference the standalone component
  },

  {
    path: 'footer',
    component: FooterComponent // ✅ directly reference the standalone component
  },
   
    {
    path: 'add-link',
    component: AddLinkDialogComponent // ✅ directly reference the standalone component
  },

  {
    path: '',
    redirectTo: 'home',
    pathMatch: 'full'
  }
];
