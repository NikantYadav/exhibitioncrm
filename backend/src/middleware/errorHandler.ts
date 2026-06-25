import { Request, Response, NextFunction } from 'express';
import { randomUUID } from 'crypto';

export const errorHandler = (
  err: Error,
  req: Request,
  res: Response,
  next: NextFunction
) => {
  // Correlation ID lets us tie a client-visible error back to the full
  // server-side detail in the logs without leaking that detail to the client.
  const correlationId = randomUUID();
  console.error(`Error [${correlationId}]:`, err);

  const isDev = process.env.NODE_ENV === 'development';

  res.status(500).json({
    error: 'Internal server error',
    correlationId,
    // Only expose internal detail (message + stack) outside production.
    ...(isDev && { message: err.message, stack: err.stack }),
  });
};
