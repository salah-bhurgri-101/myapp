import { Component, OnInit, computed, inject, signal } from '@angular/core';
import {
  AbstractControl,
  NonNullableFormBuilder,
  ReactiveFormsModule,
  ValidationErrors,
  Validators,
} from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { Observable } from 'rxjs';
import { User, UserInput } from '../models/user.model';
import { UserService } from '../services/user.service';
import { errorMessage } from '../utils/http-error';

function integerOrEmpty(control: AbstractControl): ValidationErrors | null {
  const value = control.value;
  return value === null || value === '' || Number.isInteger(value) ? null : { integer: true };
}

@Component({
  selector: 'app-user-form',
  imports: [ReactiveFormsModule, RouterLink],
  templateUrl: './user-form.html',
})
export class UserForm implements OnInit {
  private readonly fb = inject(NonNullableFormBuilder);
  private readonly api = inject(UserService);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);

  readonly userId = signal<number | null>(null);
  readonly isEdit = computed(() => this.userId() !== null);
  readonly loading = signal(false);
  readonly saving = signal(false);
  readonly error = signal<string | null>(null);

  readonly form = this.fb.group({
    name: ['', [Validators.required, Validators.maxLength(191)]],
    email: ['', [Validators.required, Validators.email, Validators.maxLength(191)]],
    age: [null as number | null, [Validators.min(0), Validators.max(150), integerOrEmpty]],
  });

  get name() {
    return this.form.controls.name;
  }
  get email() {
    return this.form.controls.email;
  }
  get age() {
    return this.form.controls.age;
  }

  ngOnInit(): void {
    const idParam = this.route.snapshot.paramMap.get('id');
    if (idParam === null) {
      return;
    }

    const id = Number(idParam);
    this.userId.set(id);
    this.loading.set(true);

    this.api.get(id).subscribe({
      next: (user: User) => {
        this.form.patchValue({ name: user.name, email: user.email, age: user.age });
        this.loading.set(false);
      },
      error: (err) => {
        this.error.set(errorMessage(err));
        this.loading.set(false);
      },
    });
  }

  submit(): void {
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }

    const { name, email, age } = this.form.getRawValue();
    const payload: UserInput = { name: name.trim(), email: email.trim(), age: age ?? null };
    const id = this.userId();

    const request$: Observable<User> =
      id === null ? this.api.create(payload) : this.api.update(id, payload);

    this.saving.set(true);
    this.error.set(null);

    request$.subscribe({
      next: () => this.router.navigate(['/users']),
      error: (err) => {
        this.error.set(errorMessage(err));
        this.saving.set(false);
      },
    });
  }
}
