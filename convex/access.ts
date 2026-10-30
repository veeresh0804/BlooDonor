import { ConvexError } from "convex/values";
import type { QueryCtx } from "./server";

export function fail(message = "Not authorized"): never { throw new ConvexError(message); }
export async function account(ctx: QueryCtx) {
  const identity = await ctx.auth.getUserIdentity();
  if (!identity) fail();
  const user = await ctx.db.query("users").withIndex("by_identity", q => q.eq("identity", identity.tokenIdentifier)).unique();
  if (!user || user.disabled) fail();
  return user;
}
export async function hospital(ctx: QueryCtx) {
  const user = await account(ctx);
  if (user.role !== "hospital") fail();
  const profile = await ctx.db.query("hospitals").withIndex("by_user", q => q.eq("userId", user._id)).unique();
  if (!profile) fail("Complete hospital profile first");
  return profile;
}
export async function donor(ctx: QueryCtx) {
  const user = await account(ctx);
  if (user.role !== "donor") fail();
  const profile = await ctx.db.query("donors").withIndex("by_user", q => q.eq("userId", user._id)).unique();
  if (!profile) fail("Complete donor profile first");
  return profile;
}
export function text(value: string, max: number) {
  if (!value.trim() || value.length > max) fail("Invalid text length");
  return value.trim();
}
export function integer(value: number, min: number, max: number) {
  if (!Number.isSafeInteger(value) || value < min || value > max) fail("Invalid integer range");
}
export function location(lat: number, lng: number) {
  if (!Number.isFinite(lat) || !Number.isFinite(lng) || lat < -90 || lat > 90 || lng < -180 || lng > 180) fail("Invalid location");
}
