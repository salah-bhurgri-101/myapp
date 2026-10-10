import { DatePipe } from '@angular/common';
import { Component, OnInit, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { User } from '../models/user.model';
import { UserService } from '../services/user.service';
import { errorMessage } from '../utils/http-error';

@Component({
  selector: 'app-user-list',
  imports: [RouterLink, DatePipe],
  templateUrl: './user-list.html',
})
export class UserList implements OnInit {
  private readonly api = inject(UserService);

  readonly users = signal<User[]>([]);
  readonly page = signal(1);
  readonly limit = signal(10);
  readonly total = signal(0);
  readonly totalPages = signal(1);
  readonly loading = signal(false);
  readonly error = signal<string | null>(null);
  readonly deletingId = signal<number | null>(null);

  readonly pageSizes = [5, 10, 20, 50];

  ngOnInit(): void {
    this.load();
  }

  load(page = this.page()): void {
    this.loading.set(true);
    this.error.set(null);

    this.api.list(page, this.limit()).subscribe({
      next: (res) => {
        const pages = Math.max(res.meta.totalPages, 1);

        // Landed on a page that no longer exists (e.g. after deletes) -> go to the last one
        if (res.data.length === 0 && res.meta.total > 0 && page > pages) {
          this.load(pages);
          return;
        }

        this.users.set(res.data);
        this.page.set(res.meta.page);
        this.total.set(res.meta.total);
        this.totalPages.set(pages);
        this.loading.set(false);
      },
      error: (err) => {
        this.error.set(errorMessage(err));
        this.loading.set(false);
      },
    });
  }

  changePageSize(value: string): void {
    this.limit.set(Number(value));
    this.load(1);
  }

  remove(user: User): void {
    if (!confirm(`Delete ${user.name}? This cannot be undone.`)) {
      return;
    }

    this.deletingId.set(user.id);
    this.api.delete(user.id).subscribe({
      next: () => {
        this.deletingId.set(null);
        const isLastOnPage = this.users().length === 1 && this.page() > 1;
        this.load(isLastOnPage ? this.page() - 1 : this.page());
      },
      error: (err) => {
        this.deletingId.set(null);
        this.error.set(errorMessage(err));
      },
    });
  }
}
