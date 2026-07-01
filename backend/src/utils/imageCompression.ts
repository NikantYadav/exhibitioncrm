// Server-side re-encode for client-supplied images before they hit Storage.
// Phone-camera card photos and chat image attachments commonly arrive at
// high resolution / high quality (e.g. 3000x4000 @ q90+), which is far more
// than needed for a legible card scan or chat preview and inflates Supabase
// Storage cost 1:1 with whatever the camera produced. Re-encoding to WebP at
// a capped dimension cuts stored bytes ~60-80% with no visible quality loss.
//
// Always outputs WebP — it beats JPEG by ~25-35% at equivalent visual quality
// and is already an allowed type (see utils/imageValidation.ts).

import sharp from 'sharp';
import type { AllowedImage } from './imageValidation';

const MAX_DIMENSION = 2000; // long edge, px — plenty for a card photo or chat image
const WEBP_QUALITY = 80;

export type CompressedImage = { buffer: Buffer; type: AllowedImage };

/**
 * Resize (if needed) and re-encode an already-validated image buffer as WebP.
 * Never throws on a clean input; if re-encoding fails for any reason, the
 * caller should fall back to storing the original buffer/type rather than
 * failing the upload.
 */
export async function compressImage(buffer: Buffer): Promise<CompressedImage> {
  const out = await sharp(buffer)
    .rotate() // apply EXIF orientation before resizing, then strip metadata
    .resize({ width: MAX_DIMENSION, height: MAX_DIMENSION, fit: 'inside', withoutEnlargement: true })
    .webp({ quality: WEBP_QUALITY })
    .toBuffer();

  return { buffer: out, type: { ext: 'webp', mime: 'image/webp' } };
}
