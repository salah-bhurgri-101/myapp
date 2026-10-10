import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { API_URL } from '../config';
import { Paginated, User, UserInput } from '../models/user.model';

@Injectable({ providedIn: 'root' })
export class UserService {
  private readonly http = inject(HttpClient);
  private readonly url = `${API_URL}/users`;

  list(page = 1, limit = 10): Observable<Paginated<User>> {
    return this.http.get<Paginated<User>>(this.url, { params: { page, limit } });
  }

  get(id: number): Observable<User> {
    return this.http.get<User>(`${this.url}/${id}`);
  }

  create(user: UserInput): Observable<User> {
    return this.http.post<User>(this.url, user);
  }

  update(id: number, user: Partial<UserInput>): Observable<User> {
    return this.http.put<User>(`${this.url}/${id}`, user);
  }

  delete(id: number): Observable<void> {
    return this.http.delete<void>(`${this.url}/${id}`);
  }
}
