/// Timing-safe bearer token comparison shared by the public and admin routes.
export async function isAuthorized(request, expectedToken) {
  const authorization = request.headers.get("Authorization") || "";
  const providedToken = authorization.startsWith("Bearer ") ? authorization.slice(7) : "";
  const encoder = new TextEncoder();
  const [providedHash, expectedHash] = await Promise.all([
    crypto.subtle.digest("SHA-256", encoder.encode(providedToken)),
    crypto.subtle.digest("SHA-256", encoder.encode(expectedToken))
  ]);
  if (typeof crypto.subtle.timingSafeEqual === "function") return crypto.subtle.timingSafeEqual(providedHash, expectedHash);
  const left = new Uint8Array(providedHash);
  const right = new Uint8Array(expectedHash);
  let difference = 0;
  for (let index = 0; index < left.length; index += 1) difference |= left[index] ^ right[index];
  return difference === 0;
}
