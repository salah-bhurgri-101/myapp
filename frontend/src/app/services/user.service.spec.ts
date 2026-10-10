import { provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { TestBed } from '@angular/core/testing';
import { API_URL } from '../config';
import { UserService } from './user.service';

describe('UserService', () => {
  let service: UserService;
  let http: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [provideHttpClient(), provideHttpClientTesting()],
    });
    service = TestBed.inject(UserService);
    http = TestBed.inject(HttpTestingController);
  });

  afterEach(() => http.verify());

  it('lists users with pagination params', () => {
    service.list(2, 5).subscribe();
    const req = http.expectOne((r) => r.url === `${API_URL}/users`);
    expect(req.request.method).toBe('GET');
    expect(req.request.params.get('page')).toBe('2');
    expect(req.request.params.get('limit')).toBe('5');
    req.flush({ data: [], meta: { page: 2, limit: 5, total: 0, totalPages: 1 } });
  });

  it('creates a user', () => {
    const body = { name: 'Ali', email: 'ali@example.com', age: 25 };
    service.create(body).subscribe();
    const req = http.expectOne(`${API_URL}/users`);
    expect(req.request.method).toBe('POST');
    expect(req.request.body).toEqual(body);
    req.flush({});
  });

  it('updates and deletes a user', () => {
    service.update(3, { name: 'New' }).subscribe();
    const put = http.expectOne(`${API_URL}/users/3`);
    expect(put.request.method).toBe('PUT');
    put.flush({});

    service.delete(3).subscribe();
    const del = http.expectOne(`${API_URL}/users/3`);
    expect(del.request.method).toBe('DELETE');
    del.flush(null);
  });
});
