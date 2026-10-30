import { v } from "convex/values";
import { mutation } from "./server";
import { account, fail, text } from "./access";

export const register = mutation({
  args: { installationId: v.string(), token: v.string(), platform: v.union(v.literal("android"), v.literal("ios"), v.literal("web")) },
  handler: async (ctx, args) => {
    const user = await account(ctx);
    const installationId = text(args.installationId, 128);
    const token = text(args.token, 4096);
    const existing = await ctx.db.query("devices").withIndex("by_installation", q => q.eq("installationId", installationId)).unique();
    const tokenOwner = await ctx.db.query("devices").withIndex("by_token", q => q.eq("token", token)).unique();
    if ((existing && existing.userId !== user._id) || (tokenOwner && tokenOwner._id !== existing?._id)) fail("Device is already registered; revoke before changing accounts");
    const fields = { userId: user._id, installationId, token, platform: args.platform, updatedAt: Date.now() };
    if (existing) { await ctx.db.patch(existing._id, fields); return; }
    await ctx.db.insert("devices", fields);
  },
});
export const revoke = mutation({
  args: { installationId: v.string() },
  handler: async (ctx, args) => {
    const user = await account(ctx);
    const existing = await ctx.db.query("devices").withIndex("by_installation", q => q.eq("installationId", args.installationId)).unique();
    if (!existing) return;
    if (existing.userId !== user._id) fail();
    await ctx.db.delete(existing._id);
  },
});
