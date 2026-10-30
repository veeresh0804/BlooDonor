import { v } from "convex/values";
import { mutation, query } from "./server";
import { account, donor, hospital, fail, integer } from "./access";
import { bloodGroup, rhFactor, donationType } from "./schema";
import type { MutationCtx } from "./server";
import type { GenericId } from "convex/values";

function compatible(d: {bloodGroup: string; rhFactor: string}, r: {bloodGroup: string; rhFactor: string}) {
  const groups: Record<string, string[]> = { o: ["o"], a: ["o", "a"], b: ["o", "b"], ab: ["o", "a", "b", "ab"] };
  return groups[r.bloodGroup].includes(d.bloodGroup) && (r.rhFactor === "positive" || d.rhFactor === "negative");
}
function distance(a: {lat: number; lng: number}, b: {lat: number; lng: number}) {
  const rad = Math.PI / 180;
  const term = Math.cos(a.lat * rad) * Math.cos(b.lat * rad) * Math.cos((a.lng - b.lng) * rad) + Math.sin(a.lat * rad) * Math.sin(b.lat * rad);
  return 6371 * Math.acos(Math.max(-1, Math.min(1, term)));
}
async function closeNotifications(ctx: MutationCtx, requestId: GenericId<"requests">) {
  const responses = await ctx.db.query("responses").withIndex("by_request", q => q.eq("requestId", requestId)).collect();
  for (const response of responses) {
    if (["donated", "stepped_back", "accident"].includes(response.status)) continue;
    const profile = await ctx.db.get(response.donorId);
    if (profile) await ctx.db.insert("notificationOutbox", { userId: profile.userId, requestId,
      kind: "request_closed", createdAt: Date.now(), state: "pending" });
  }
}

export const create = mutation({
  args: { bloodGroup, rhFactor, units: v.number(), radiusKm: v.number(),
    urgency: v.union(v.literal("critical"), v.literal("urgent"), v.literal("normal")) },
  handler: async (ctx, args) => {
    const profile = await hospital(ctx);
    if (!profile.verified) fail("Hospital verification required");
    integer(args.units, 1, 100); integer(args.radiusKm, 1, 50);
    // Explicit prototype limit: fail instead of silently missing candidates.
    const candidates = await ctx.db.query("donors").withIndex("by_available", q => q.eq("available", true)).take(101);
    if (candidates.length > 100) fail("Matching capacity exceeded; batching required");
    const requestId = await ctx.db.insert("requests", { ...args, hospitalId: profile._id,
      hospitalName: profile.name, hospitalAddress: profile.address, lat: profile.lat, lng: profile.lng,
      unitsFulfilled: 0, status: "active", createdAt: Date.now() });
    for (const candidate of candidates) {
      const user = await ctx.db.get(candidate.userId);
      if (!user || user.disabled || candidate.cooldownUntil > Date.now() || !compatible(candidate, args) || distance(profile, candidate) > args.radiusKm) continue;
      await ctx.db.insert("responses", { requestId, donorId: candidate._id, status: "notified",
        healthCheckPassed: false, createdAt: Date.now() });
      await ctx.db.insert("notificationOutbox", { requestId, userId: candidate.userId,
        kind: "request_available", state: "pending", createdAt: Date.now() });
    }
    return requestId;
  },
});

export const get = query({
  args: { requestId: v.id("requests") },
  handler: async (ctx, { requestId }) => {
    const user = await account(ctx);
    const request = await ctx.db.get(requestId);
    if (!request) fail();
    if (user.role === "hospital") {
      const owner = await hospital(ctx);
      if (owner._id !== request.hospitalId) fail();
    } else {
      const profile = await donor(ctx);
      const response = await ctx.db.query("responses").withIndex("by_pair", q => q.eq("requestId", requestId).eq("donorId", profile._id)).unique();
      if (!response) fail();
    }
    return { id: request._id, bloodGroup: request.bloodGroup, rhFactor: request.rhFactor,
      units: request.units, unitsFulfilled: request.unitsFulfilled, status: request.status,
      urgency: request.urgency, hospitalName: request.hospitalName, address: request.hospitalAddress,
      lat: request.lat, lng: request.lng };
  },
});

export const tracker = query({
  args: { requestId: v.id("requests") },
  handler: async (ctx, { requestId }) => {
    const owner = await hospital(ctx);
    const request = await ctx.db.get(requestId);
    if (!request || request.hospitalId !== owner._id) fail();
    const responses = await ctx.db.query("responses").withIndex("by_request", q => q.eq("requestId", requestId)).collect();
    const donors = await Promise.all(responses.map(async response => {
      const profile = await ctx.db.get(response.donorId);
      return { responseId: response._id, status: response.status,
        bloodGroup: profile?.bloodGroup, rhFactor: profile?.rhFactor,
        acceptedAt: response.acceptedAt, arrivedAt: response.arrivedAt };
    }));
    return { requestId, status: request.status, units: request.units, unitsFulfilled: request.unitsFulfilled, donors };
  },
});

const transitions: Record<string, string[]> = {
  notified: ["accepted", "stepped_back"], accepted: ["on_the_way", "stepped_back"],
  on_the_way: ["delayed", "arrived", "stepped_back", "accident"],
  delayed: ["on_the_way", "arrived", "stepped_back", "accident"],
  arrived: ["stepped_back"], stepped_back: [], accident: [], donated: [],
};
export const updateResponse = mutation({
  args: { requestId: v.id("requests"), status: v.union(v.literal("accepted"), v.literal("on_the_way"),
    v.literal("delayed"), v.literal("arrived"), v.literal("stepped_back"), v.literal("accident")),
    healthCheckPassed: v.optional(v.boolean()) },
  handler: async (ctx, args) => {
    const profile = await donor(ctx);
    const response = await ctx.db.query("responses").withIndex("by_pair", q => q.eq("requestId", args.requestId).eq("donorId", profile._id)).unique();
    if (!response) fail();
    const request = await ctx.db.get(args.requestId);
    if (!request || request.status !== "active") fail("Request is not active");
    if (response.status === args.status) return response._id;
    if (!transitions[response.status].includes(args.status)) fail("Invalid status transition");
    if (args.status === "accepted") {
      if (args.healthCheckPassed !== true || profile.cooldownUntil > Date.now()) fail("Donor is not eligible");
      const priorResponses = await ctx.db.query("responses").withIndex("by_donor", q => q.eq("donorId", profile._id)).collect();
      for (const prior of priorResponses) {
        if (prior._id === response._id || !["accepted", "on_the_way", "delayed", "arrived"].includes(prior.status)) continue;
        const priorRequest = await ctx.db.get(prior.requestId);
        if (priorRequest?.status === "active") fail("Finish or leave the existing journey first");
      }
      await ctx.db.patch(response._id, { status: args.status, acceptedAt: Date.now(), healthCheckPassed: true });
    } else {
      await ctx.db.patch(response._id, { status: args.status,
        ...(args.status === "arrived" ? { arrivedAt: Date.now() } : {}) });
    }
    return response._id;
  },
});

export const confirmDonation = mutation({
  args: { responseId: v.id("responses"), donationType, units: v.number() },
  handler: async (ctx, args) => {
    const owner = await hospital(ctx);
    integer(args.units, 1, 100);
    const response = await ctx.db.get(args.responseId);
    if (!response) fail();
    const request = await ctx.db.get(response.requestId);
    if (!request || request.hospitalId !== owner._id) fail();
    const previous = await ctx.db.query("donations").withIndex("by_response", q => q.eq("responseId", args.responseId)).unique();
    if (previous) {
      if (previous.units !== args.units || previous.donationType !== args.donationType) fail("Confirmation conflicts with recorded donation");
      return previous._id;
    }
    if (!owner.verified) fail("Hospital verification required");
    if (request.status !== "active" || response.status !== "arrived" || !response.healthCheckPassed) fail("Donation cannot be confirmed in this state");
    if (args.units > request.units - request.unitsFulfilled) fail("Units exceed request remainder");
    const profile = await ctx.db.get(response.donorId);
    if (!profile || profile.cooldownUntil > Date.now()) fail("Donor is not eligible");
    const donorAccount = await ctx.db.get(profile.userId);
    if (!donorAccount || donorAccount.disabled) fail("Donor is not eligible");
    const cooldownDays = { whole_blood: 90, platelets: 14, plasma: 28, double_red_cells: 180 };
    const donationId = await ctx.db.insert("donations", { ...args, requestId: request._id,
      donorId: profile._id, hospitalId: owner._id, recordedAt: Date.now() });
    await ctx.db.patch(response._id, { status: "donated" });
    await ctx.db.patch(profile._id, { points: profile.points + 100, totalDonations: profile.totalDonations + 1,
      cooldownUntil: Date.now() + cooldownDays[args.donationType] * 86400000 });
    const fulfilled = request.unitsFulfilled + args.units;
    await ctx.db.patch(request._id, { unitsFulfilled: fulfilled,
      ...(fulfilled === request.units ? { status: "fulfilled" as const, closedAt: Date.now() } : {}) });
    if (fulfilled === request.units) await closeNotifications(ctx, request._id);
    return donationId;
  },
});

export const cancel = mutation({
  args: { requestId: v.id("requests") },
  handler: async (ctx, { requestId }) => {
    const owner = await hospital(ctx);
    const request = await ctx.db.get(requestId);
    if (!request || request.hospitalId !== owner._id) fail();
    if (request.status === "cancelled") return;
    if (request.status !== "active") fail("Request is closed");
    await ctx.db.patch(requestId, { status: "cancelled", closedAt: Date.now() });
    await closeNotifications(ctx, requestId);
  },
});
