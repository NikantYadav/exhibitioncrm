import { Request, Response, NextFunction } from 'express';

// ANSI color codes for terminal output
const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  dim: '\x1b[2m',
  
  // Foreground colors
  black: '\x1b[30m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m',
  white: '\x1b[37m',
  
  // Background colors
  bgBlack: '\x1b[40m',
  bgRed: '\x1b[41m',
  bgGreen: '\x1b[42m',
  bgYellow: '\x1b[43m',
  bgBlue: '\x1b[44m',
  bgMagenta: '\x1b[45m',
  bgCyan: '\x1b[46m',
  bgWhite: '\x1b[47m',
};

// Get color based on HTTP method
function getMethodColor(method: string): string {
  switch (method) {
    case 'GET':
      return colors.green;
    case 'POST':
      return colors.blue;
    case 'PUT':
    case 'PATCH':
      return colors.yellow;
    case 'DELETE':
      return colors.red;
    default:
      return colors.white;
  }
}

// Get color based on status code
function getStatusColor(status: number): string {
  if (status >= 500) return colors.red;
  if (status >= 400) return colors.yellow;
  if (status >= 300) return colors.cyan;
  if (status >= 200) return colors.green;
  return colors.white;
}

// Format timestamp
function getTimestamp(): string {
  const now = new Date();
  return now.toLocaleTimeString('en-US', { 
    hour12: false,
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit'
  });
}

// Request logging middleware
export function requestLogger(req: Request, res: Response, next: NextFunction) {
  const startTime = Date.now();
  const timestamp = getTimestamp();
  const method = req.method;
  const url = req.originalUrl || req.url;
  const methodColor = getMethodColor(method);

  // Log incoming request
  console.log(
    `${colors.dim}[${timestamp}]${colors.reset} ` +
    `${methodColor}${colors.bright}${method.padEnd(7)}${colors.reset} ` +
    `${colors.cyan}${url}${colors.reset}`
  );

  // Log request body for POST/PUT/PATCH (excluding sensitive data)
  if (['POST', 'PUT', 'PATCH'].includes(method) && req.body) {
    const sanitizedBody = { ...req.body };
    
    // Remove sensitive fields
    if (sanitizedBody.password) sanitizedBody.password = '***';
    if (sanitizedBody.token) sanitizedBody.token = '***';
    if (sanitizedBody.refresh_token) sanitizedBody.refresh_token = '***';
    
    if (Object.keys(sanitizedBody).length > 0) {
      console.log(
        `${colors.dim}         Body:${colors.reset} `,
        JSON.stringify(sanitizedBody, null, 2)
          .split('\n')
          .map((line, i) => i === 0 ? line : `               ${line}`)
          .join('\n')
      );
    }
  }

  // Log query parameters
  if (Object.keys(req.query).length > 0) {
    console.log(
      `${colors.dim}         Query:${colors.reset}`,
      req.query
    );
  }

  // Capture response
  const originalSend = res.send;
  res.send = function (data: any): Response {
    const duration = Date.now() - startTime;
    const status = res.statusCode;
    const statusColor = getStatusColor(status);

    // Log response
    console.log(
      `${colors.dim}[${timestamp}]${colors.reset} ` +
      `${methodColor}${colors.bright}${method.padEnd(7)}${colors.reset} ` +
      `${colors.cyan}${url}${colors.reset} ` +
      `${statusColor}${colors.bright}${status}${colors.reset} ` +
      `${colors.dim}${duration}ms${colors.reset}`
    );

    // Log response body for errors
    if (status >= 400) {
      try {
        const responseData = typeof data === 'string' ? JSON.parse(data) : data;
        if (responseData && responseData.error) {
          console.log(
            `${colors.red}         Error:${colors.reset}`,
            responseData.error
          );
        }
      } catch (e) {
        // Ignore JSON parse errors
      }
    }

    console.log(''); // Empty line for readability

    return originalSend.call(this, data);
  };

  next();
}

// Error logging
export function logError(error: Error, context?: string) {
  console.error(
    `${colors.red}${colors.bright}[ERROR]${colors.reset} ` +
    `${context ? `${colors.yellow}${context}${colors.reset} - ` : ''}` +
    `${colors.red}${error.message}${colors.reset}`
  );
  
  if (error.stack) {
    console.error(
      `${colors.dim}${error.stack}${colors.reset}`
    );
  }
  console.log(''); // Empty line
}

// Info logging
export function logInfo(message: string, data?: any) {
  console.log(
    `${colors.blue}${colors.bright}[INFO]${colors.reset} ` +
    `${message}`
  );
  
  if (data) {
    console.log(
      `${colors.dim}       ${JSON.stringify(data, null, 2)}${colors.reset}`
    );
  }
  console.log(''); // Empty line
}

// Success logging
export function logSuccess(message: string, data?: any) {
  console.log(
    `${colors.green}${colors.bright}[SUCCESS]${colors.reset} ` +
    `${message}`
  );
  
  if (data) {
    console.log(
      `${colors.dim}          ${JSON.stringify(data, null, 2)}${colors.reset}`
    );
  }
  console.log(''); // Empty line
}

// Warning logging
export function logWarning(message: string, data?: any) {
  console.log(
    `${colors.yellow}${colors.bright}[WARNING]${colors.reset} ` +
    `${message}`
  );
  
  if (data) {
    console.log(
      `${colors.dim}          ${JSON.stringify(data, null, 2)}${colors.reset}`
    );
  }
  console.log(''); // Empty line
}
