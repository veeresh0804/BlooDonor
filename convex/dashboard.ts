import { v } from "convex/values";
import { query } from "./server";
import { account, donor, hospital, integer } from "./access";

const pageArgs = { limit: v.number(), cursor: v.union(v.string(), v.null()) };

// No caller-supplied owner IDs. These queries are safe to subscribe to.
export const profile = query({
  args: {},
  handler: async ctx => {
    const user = await account(ctx);
    if (user.role === "hospital") {
      const p = await ctx.db.query("hospitals").withIndex("by_user", q => q.eq("userId", user._id)).unique();
      return p ? { kind: "hospital" as const, id: p._id, name: p.name,
        address: p.address, lat: p.lat, lng: p.lng, verified: p.verified } : null;
    }
    const p = await ctx.db.query("donors").withIndex("by_user", q => q.eq("userId", user._id)).unique();
    return p ? { kind: "donor" as const, id: p._id, bloodGroup: p.bloodGroup,
      rhFactor: p.rhFactor, lat: p.lat, lng: p.lng, available: p.available,
      cooldownUntil: p.cooldownUntil, points: p.points, totalDonations: p.totalDonations } : null;
  },
});

export const hospitalRequests = query({
  args: pageArgs,
  handler: async (ctx, args) => {
    const owner = await hospital(ctx);
    integer(args.limit, 1, 50);
    const result = await ctx.db.query("requests").withIndex("by_hospital", q => q.eq("hospitalId", owner._id))
      .order("desc").paginate({ numItems: args.limit, cursor: args.cursor });
    return { ...result, page: result.page.map(r => ({ id: r._id, bloodGroup: r.bloodGroup,
      rhFactor: r.rhFactor, units: r.units, unitsFulfilled: r.unitsFulfilled,
      status: r.status, urgency: r.urgency, createdAt: r.createdAt, closedAt: r.closedAt })) };
  },
});

export const donorRequests = query({
  args: pageArgs,
  handler: async (ctx, args) => {
    const owner = await donor(ctx);
    integer(args.limit, 1, 50);
    const result = await ctx.db.query("responses").withIndex("by_donor", q => q.eq("donorId", owner._id))
      .order("desc").paginate({ numItems: args.limit, cursor: args.cursor });
    const page = await Promise.all(result.page.map(async r => {
      const request = await ctx.db.get(r.requestId);
      return { responseId: r._id, requestId: r.requestId, status: r.status,
        acceptedAt: r.acceptedAt, arrivedAt: r.arrivedAt,
        request: request ? { status: request.status, hospitalName: request.hospitalName,
          bloodGroup: request.bloodGroup, rhFactor: request.rhFactor, urgency: request.urgency,
          units: request.units, unitsFulfilled: request.unitsFulfilled } : null };
    }));
    return { ...result, page };
  },
});

export const donationHistory = query({
  args: pageArgs,
  handler: async (ctx, args) => {
    const owner = await donor(ctx);
    integer(args.limit, 1, 50);
    const result = await ctx.db.query("donations").withIndex("by_donor", q => q.eq("donorId", owner._id))
      .order("desc").paginate({ numItems: args.limit, cursor: args.cursor });
    return { ...result, page: result.page.map(d => ({ id: d._id, requestId: d.requestId,
      donationType: d.donationType, units: d.units, recordedAt: d.recordedAt })) };
  },
});
