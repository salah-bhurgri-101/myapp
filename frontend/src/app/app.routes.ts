import { Routes } from '@angular/router';

export const routes: Routes = [
  { path: '', pathMatch: 'full', redirectTo: 'users' },
  {
    path: 'users',
    title: 'Users',
    loadComponent: () => import('./users/user-list').then((m) => m.UserList),
  },
  {
    path: 'users/new',
    title: 'Add user',
    loadComponent: () => import('./users/user-form').then((m) => m.UserForm),
  },
  {
    path: 'users/:id/edit',
    title: 'Edit user',
    loadComponent: () => import('./users/user-form').then((m) => m.UserForm),
  },
  { path: '**', redirectTo: 'users' },
];
