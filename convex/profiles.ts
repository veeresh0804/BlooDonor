import { v } from "convex/values";
import { mutation, query, internalMutation } from "./server";
import { account, fail, location, text } from "./access";
import { bloodGroup, rhFactor, role } from "./schema";

export const onboard = mutation({
  args: { name: v.string(), role },
  handler: async (ctx, args) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) fail();
    // The configured provider must issue verified E.164 phone claims.
    if (identity.phoneNumberVerified !== true || typeof identity.phoneNumber !== "string" || !/^\+91[6-9]\d{9}$/.test(identity.phoneNumber)) fail("Verified +91 phone required");
    const existing = await ctx.db.query("users").withIndex("by_identity", q => q.eq("identity", identity.tokenIdentifier)).unique();
    if (existing) {
      if (existing.disabled || existing.role !== args.role) fail("Role cannot be changed");
      return existing._id;
    }
    const phoneOwner = await ctx.db.query("users").withIndex("by_phone", q => q.eq("phone", identity.phoneNumber!)).unique();
    if (phoneOwner) fail("Account recovery required");
    return ctx.db.insert("users", { identity: identity.tokenIdentifier, phone: identity.phoneNumber,
      name: text(args.name, 100), role: args.role, disabled: false, createdAt: Date.now() });
  },
});

export const me = query({ args: {}, handler: async ctx => {
  const user = await account(ctx);
  return { id: user._id, name: user.name, role: user.role };
} });

export const saveHospital = mutation({
  args: { name: v.string(), address: v.string(), lat: v.number(), lng: v.number() },
  handler: async (ctx, args) => {
    const user = await account(ctx);
    if (user.role !== "hospital") fail();
    location(args.lat, args.lng);
    const fields = { name: text(args.name, 160), address: text(args.address, 500), lat: args.lat, lng: args.lng };
    const existing = await ctx.db.query("hospitals").withIndex("by_user", q => q.eq("userId", user._id)).unique();
    if (existing) {
      // Identity/location changes require renewed verification.
      const changed = existing.name !== fields.name || existing.address !== fields.address || existing.lat !== fields.lat || existing.lng !== fields.lng;
      await ctx.db.patch(existing._id, { ...fields, verified: changed ? false : existing.verified });
      return existing._id;
    }
    return ctx.db.insert("hospitals", { userId: user._id, ...fields, verified: false });
  },
});

export const saveDonor = mutation({
  args: { bloodGroup, rhFactor, lat: v.number(), lng: v.number(), available: v.boolean() },
  handler: async (ctx, args) => {
    const user = await account(ctx);
    if (user.role !== "donor") fail();
    location(args.lat, args.lng);
    const existing = await ctx.db.query("donors").withIndex("by_user", q => q.eq("userId", user._id)).unique();
    if (existing) {
      if (existing.bloodGroup !== args.bloodGroup || existing.rhFactor !== args.rhFactor) fail("Blood type correction requires review");
      await ctx.db.patch(existing._id, { lat: args.lat, lng: args.lng, available: args.available });
      return existing._id;
    }
    return ctx.db.insert("donors", { userId: user._id, ...args, cooldownUntil: 0, points: 0, totalDonations: 0 });
  },
});

// Dashboard/administrative operation only; never exposed through a public wrapper.
export const verifyHospital = internalMutation({
  args: { hospitalId: v.id("hospitals"), verified: v.boolean() },
  handler: async (ctx, args) => {
    if (!await ctx.db.get(args.hospitalId)) fail("Hospital not found");
    await ctx.db.patch(args.hospitalId, { verified: args.verified });
  },
});
