export class AppError extends Error {
  constructor(
    public readonly code: string,
    public readonly status: number,
    message: string,
    public readonly details?: unknown,
  ) {
    super(message);
    this.name = 'AppError';
  }
}

export const errors = {
  unauthorized: (message = 'Authentication required.') =>
    new AppError('UNAUTHORIZED', 401, message),
  forbidden: (message = 'You do not have access to this resource.') =>
    new AppError('FORBIDDEN', 403, message),
  notFound: (message = 'The requested resource was not found.') =>
    new AppError('NOT_FOUND', 404, message),
  conflict: (code: string, message: string) => new AppError(code, 409, message),
  unavailable: (code: string, message: string) => new AppError(code, 503, message),
  validation: (details: unknown, message = 'Request validation failed.') =>
    new AppError('VALIDATION_ERROR', 422, message, details),
  rateLimited: () => new AppError('RATE_LIMITED', 429, 'Too many requests. Try again later.'),
  badRequest: (code: string, message: string) => new AppError(code, 400, message),
};
