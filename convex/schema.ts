import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export const bloodGroup = v.union(v.literal("a"), v.literal("b"), v.literal("ab"), v.literal("o"));
export const rhFactor = v.union(v.literal("positive"), v.literal("negative"));
export const role = v.union(v.literal("donor"), v.literal("hospital"));
export const donationType = v.union(v.literal("whole_blood"), v.literal("platelets"), v.literal("plasma"), v.literal("double_red_cells"));
export const responseStatus = v.union(v.literal("notified"), v.literal("accepted"), v.literal("on_the_way"), v.literal("delayed"), v.literal("arrived"), v.literal("stepped_back"), v.literal("accident"), v.literal("donated"));

export default defineSchema({
  users: defineTable({
    identity: v.string(), phone: v.string(), name: v.string(), role,
    disabled: v.boolean(), createdAt: v.number(),
  }).index("by_identity", ["identity"]).index("by_phone", ["phone"]),
  hospitals: defineTable({
    userId: v.id("users"), name: v.string(), address: v.string(),
    lat: v.number(), lng: v.number(), verified: v.boolean(),
  }).index("by_user", ["userId"]),
  donors: defineTable({
    userId: v.id("users"), bloodGroup, rhFactor,
    lat: v.number(), lng: v.number(), available: v.boolean(),
    cooldownUntil: v.number(), points: v.number(), totalDonations: v.number(),
  }).index("by_user", ["userId"]).index("by_available", ["available"]),
  requests: defineTable({
    hospitalId: v.id("hospitals"), bloodGroup, rhFactor,
    units: v.number(), unitsFulfilled: v.number(),
    status: v.union(v.literal("active"), v.literal("fulfilled"), v.literal("cancelled")),
    urgency: v.union(v.literal("critical"), v.literal("urgent"), v.literal("normal")),
    radiusKm: v.number(), hospitalName: v.string(), hospitalAddress: v.string(),
    lat: v.number(), lng: v.number(), createdAt: v.number(), closedAt: v.optional(v.number()),
  }).index("by_hospital", ["hospitalId"]),
  responses: defineTable({
    requestId: v.id("requests"), donorId: v.id("donors"), status: responseStatus,
    healthCheckPassed: v.boolean(), createdAt: v.number(),
    acceptedAt: v.optional(v.number()), arrivedAt: v.optional(v.number()),
  }).index("by_pair", ["requestId", "donorId"])
    .index("by_request", ["requestId"]).index("by_donor", ["donorId"]),
  donations: defineTable({
    responseId: v.id("responses"), requestId: v.id("requests"), donorId: v.id("donors"),
    hospitalId: v.id("hospitals"), donationType, units: v.number(), recordedAt: v.number(),
  }).index("by_response", ["responseId"]).index("by_donor", ["donorId"]),
  devices: defineTable({
    userId: v.id("users"), installationId: v.string(), token: v.string(),
    platform: v.union(v.literal("android"), v.literal("ios"), v.literal("web")),
    updatedAt: v.number(),
  }).index("by_installation", ["installationId"]).index("by_token", ["token"])
    .index("by_user", ["userId"]),
  // Internal pending events only. A future delivery worker must implement retries.
  notificationOutbox: defineTable({
    userId: v.id("users"), requestId: v.id("requests"),
    kind: v.union(v.literal("request_available"), v.literal("request_closed")),
    createdAt: v.number(), state: v.literal("pending"),
  }).index("by_state", ["state"]),
});
