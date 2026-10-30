import type { AuthConfig } from "convex/server";
// Trust only this deployment's configured Clerk issuer and Convex audience.
// Onboarding additionally requires a verified +91 phone claim.
export default {
  providers: [{ domain: process.env.AUTH_ISSUER!, applicationID: "convex" }],
} satisfies AuthConfig;
