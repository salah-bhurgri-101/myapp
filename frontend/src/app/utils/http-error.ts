import { HttpErrorResponse } from '@angular/common/http';

/** Turns an HTTP error from the API into a message safe to show to the user. */
export function errorMessage(err: unknown): string {
  if (err instanceof HttpErrorResponse) {
    if (err.status === 0) {
      return 'Cannot reach the API. Make sure the Fastify server is running.';
    }
    if (err.status === 409) {
      return 'A user with this email already exists.';
    }
    if (err.status === 404) {
      return 'User not found.';
    }
    const message = err.error?.message;
    if (typeof message === 'string' && message.length > 0) {
      return message;
    }
  }
  return 'Something went wrong. Please try again.';
}
