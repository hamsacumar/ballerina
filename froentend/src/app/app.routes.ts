import { Routes } from '@angular/router';
import { TestComponent } from './test/test.component';

export const routes: Routes = [
    {
    path: 'test',
    component: TestComponent // ✅ directly reference the standalone component
  },

  {
    path: '',
    redirectTo: 'test',
    pathMatch: 'full'
  }
];
