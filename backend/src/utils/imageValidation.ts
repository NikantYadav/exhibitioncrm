// Shared, dependency-free image validation for any client-supplied image
// upload (card scans, file scans, vision analysis).
//
// Security contract:
//  - Type is decided by SNIFFING real magic bytes, never by the client-supplied
//    MIME or data: prefix (both are attacker-controlled and trivially spoofed).
//  - Only raster formats we explicitly trust are allowed. SVG is excluded — it
//    can carry script and become stored XSS when served. GIF is excluded too.
//  - A hard byte cap defends against oversized payloads / unbounded allocation,
//    independent of the express body-size limit.

export const MAX_IMAGE_BYTES = 5 * 1024 * 1024; // 5 MB

export type AllowedImage = { ext: 'jpg' | 'png' | 'webp'; mime: string };

export class ImageValidationError extends Error {}

/** Identify an image by its magic bytes. Returns null if not an allowed type. */
export function sniffImage(buf: Buffer): AllowedImage | null {
  if (buf.length < 12) return null;

  // JPEG: FF D8 FF
  if (buf[0] === 0xff && buf[1] === 0xd8 && buf[2] === 0xff) {
    return { ext: 'jpg', mime: 'image/jpeg' };
  }
  // PNG: 89 50 4E 47 0D 0A 1A 0A
  if (
    buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4e && buf[3] === 0x47 &&
    buf[4] === 0x0d && buf[5] === 0x0a && buf[6] === 0x1a && buf[7] === 0x0a
  ) {
    return { ext: 'png', mime: 'image/png' };
  }
  // WebP: "RIFF" .... "WEBP"
  if (buf.toString('ascii', 0, 4) === 'RIFF' && buf.toString('ascii', 8, 12) === 'WEBP') {
    return { ext: 'webp', mime: 'image/webp' };
  }
  return null;
}

/** Strip an optional `data:...;base64,` prefix, returning the bare base64. */
export function stripDataUri(image: string): string {
  return /^data:[^;,]*;base64,(.+)$/is.exec(image)?.[1] ?? image;
}

/**
 * Decode + validate a client-supplied image string (data URI or bare base64).
 * Throws ImageValidationError for oversized / malformed / disallowed input.
 * Returns the decoded buffer and the sniffed (trusted) type.
 */
export function decodeAndValidateImage(image: string): { buffer: Buffer; type: AllowedImage } {
  const b64 = stripDataUri(image);

  // Cheap length check before allocating the buffer (base64 ≈ 4/3 of bytes).
  if (Math.floor((b64.length * 3) / 4) > MAX_IMAGE_BYTES) {
    throw new ImageValidationError('Image is too large (max 5 MB)');
  }

  let buffer: Buffer;
  try {
    buffer = Buffer.from(b64, 'base64');
  } catch {
    throw new ImageValidationError('Invalid image data');
  }

  if (buffer.length > MAX_IMAGE_BYTES) {
    throw new ImageValidationError('Image is too large (max 5 MB)');
  }

  const type = sniffImage(buffer);
  if (!type) {
    throw new ImageValidationError('Unsupported image type (allowed: JPEG, PNG, WebP)');
  }

  return { buffer, type };
}
