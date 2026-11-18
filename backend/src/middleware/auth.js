import { HttpError } from '../utils/httpError.js';

// Verifies `Authorization: Bearer <Firebase ID token>` and sets req.user.
export function requireAuth(verifyIdToken) {
  return async (req, res, next) => {
    try {
      const header = req.get('authorization') || '';
      const [scheme, token] = header.split(' ');
      if (scheme !== 'Bearer' || !token) throw new HttpError(401, 'Missing bearer token');
      let decoded;
      try {
        decoded = await verifyIdToken(token);
      } catch {
        throw new HttpError(401, 'Invalid or expired token');
      }
      req.user = {
        uid: decoded.uid,
        isGuest: decoded.firebase?.sign_in_provider === 'anonymous',
        name: decoded.name,
        email: decoded.email,
        picture: decoded.picture,
      };
      next();
    } catch (e) {
      next(e);
    }
  };
}
