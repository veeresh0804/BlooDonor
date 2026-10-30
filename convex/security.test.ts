import { describe, expect, test } from "vitest";
import { defineTestApp } from "convex-test";
import schema from "./schema";
import * as profiles from "./profiles";
import * as requests from "./requests";
import * as devices from "./devices";
import * as dashboard from "./dashboard";

const { api, internal, createTest } = defineTestApp({ schema }).defineModules({ profiles, requests, devices, dashboard });
function identity(subject: string, phone = "+919876543210") {
  return { issuer: "https://test.invalid", subject, tokenIdentifier: `https://test.invalid|${subject}`,
    phoneNumber: phone, phoneNumberVerified: true };
}
async function fixture() {
  const t = createTest();
  const h = t.withIdentity(identity("hospital"));
  const d = t.withIdentity(identity("donor", "+919876543211"));
  const outsider = t.withIdentity(identity("outsider", "+919876543212"));
  await h.mutation(api.profiles.onboard, { name: "Hospital", role: "hospital" });
  const donorUserId = await d.mutation(api.profiles.onboard, { name: "Donor", role: "donor" });
  await outsider.mutation(api.profiles.onboard, { name: "Other", role: "donor" });
  const hospitalId = await h.mutation(api.profiles.saveHospital, { name: "Hospital", address: "Hyderabad", lat: 17.38, lng: 78.48 });
  await t.mutation(internal.profiles.verifyHospital, { hospitalId, verified: true });
  const donorId = await d.mutation(api.profiles.saveDonor, { bloodGroup: "o", rhFactor: "positive", lat: 17.38, lng: 78.48, available: true });
  await outsider.mutation(api.profiles.saveDonor, { bloodGroup: "ab", rhFactor: "positive", lat: 17.38, lng: 78.48, available: true });
  const create = () => h.mutation(api.requests.create, { bloodGroup: "o", rhFactor: "positive", units: 1, urgency: "urgent", radiusKm: 10 });
  const requestId = await create();
  const responseId = (await h.query(api.requests.tracker, { requestId })).donors[0].responseId;
  const arrive = async () => {
    await d.mutation(api.requests.updateResponse, { requestId, status: "accepted", healthCheckPassed: true });
    await d.mutation(api.requests.updateResponse, { requestId, status: "on_the_way" });
    await d.mutation(api.requests.updateResponse, { requestId, status: "arrived" });
  };
  return { t, h, d, outsider, donorId, donorUserId, requestId, responseId, hospitalId, create, arrive };
}

describe("BlooDonor backend authorization and integrity", () => {
  test("dashboard queries derive ownership and enforce page bounds", async () => {
    const f = await fixture();
    const paging = { limit: 10, cursor: null };
    await expect(f.t.query(api.dashboard.profile, {})).rejects.toThrow();
    await expect(f.d.query(api.dashboard.hospitalRequests, paging)).rejects.toThrow();
    await expect(f.h.query(api.dashboard.donorRequests, paging)).rejects.toThrow();
    await expect(f.d.query(api.dashboard.donorRequests, { ...paging, limit: 1000 })).rejects.toThrow();
    await expect(f.d.query(api.dashboard.profile, { userId: f.donorUserId } as never)).rejects.toThrow();
    const own = await f.d.query(api.dashboard.profile, {});
    expect(own?.kind).toBe("donor");
    expect(own).not.toHaveProperty("identity");
    expect(own).not.toHaveProperty("phone");
    const requests = await f.h.query(api.dashboard.hospitalRequests, paging);
    expect(requests.page.map(r => r.id)).toEqual([f.requestId]);
    expect((await f.d.query(api.dashboard.donorRequests, paging)).page).toHaveLength(1);
    expect((await f.outsider.query(api.dashboard.donorRequests, paging)).page).toHaveLength(0);
    await f.arrive();
    await f.h.mutation(api.requests.confirmDonation, { responseId: f.responseId, donationType: "whole_blood", units: 1 });
    const history = await f.d.query(api.dashboard.donationHistory, paging);
    expect(history.page).toHaveLength(1);
    expect(history.page[0].units).toBe(1);
    expect(history.page[0]).not.toHaveProperty("donorId");
    expect((await f.outsider.query(api.dashboard.donationHistory, paging)).page).toHaveLength(0);
  });
  test("anonymous and unverified-phone onboarding fail; role is immutable", async () => {
    const t = createTest();
    await expect(t.query(api.profiles.me, {})).rejects.toThrow();
    await expect(t.mutation(api.profiles.onboard, { name: "Anon", role: "hospital" })).rejects.toThrow();
    const invalid = t.withIdentity({ ...identity("unverified"), phoneNumberVerified: false });
    await expect(invalid.mutation(api.profiles.onboard, { name: "User", role: "donor" })).rejects.toThrow();
    const user = t.withIdentity(identity("verified"));
    await user.mutation(api.profiles.onboard, { name: "User", role: "donor" });
    await expect(user.mutation(api.profiles.onboard, { name: "User", role: "hospital" })).rejects.toThrow();
    const duplicate = t.withIdentity(identity("other-subject"));
    await expect(duplicate.mutation(api.profiles.onboard, { name: "User", role: "donor" })).rejects.toThrow();
  });

  test("hospital cannot self-verify; profile edits invalidate verification", async () => {
    const f = await fixture();
    await expect(f.h.mutation(api.profiles.saveHospital, { name: "H", address: "A", lat: 0, lng: 0, verified: true } as never)).rejects.toThrow();
    await f.h.mutation(api.profiles.saveHospital, { name: "Changed", address: "Hyderabad", lat: 17.38, lng: 78.48 });
    await expect(f.create()).rejects.toThrow("verification");
  });

  test("unmatched and anonymous users cannot read or change a request", async () => {
    const f = await fixture();
    await expect(f.t.query(api.requests.get, { requestId: f.requestId })).rejects.toThrow();
    await expect(f.outsider.query(api.requests.get, { requestId: f.requestId })).rejects.toThrow();
    await expect(f.outsider.mutation(api.requests.updateResponse, { requestId: f.requestId, status: "accepted", healthCheckPassed: true })).rejects.toThrow("Not authorized");
    await f.h.mutation(api.requests.cancel, { requestId: f.requestId });
    await expect(f.outsider.mutation(api.requests.updateResponse, { requestId: f.requestId, status: "accepted", healthCheckPassed: true })).rejects.toThrow("Not authorized");
  });

  test("tracker excludes donor identity, contact, location and device secrets", async () => {
    const f = await fixture();
    await f.d.mutation(api.devices.register, { installationId: "phone-1", token: "secret-fcm-token", platform: "android" });
    await f.arrive();
    const tracker = await f.h.query(api.requests.tracker, { requestId: f.requestId });
    expect(Object.keys(tracker.donors[0]).sort()).toEqual(["acceptedAt", "arrivedAt", "bloodGroup", "responseId", "rhFactor", "status"].sort());
    expect(JSON.stringify(tracker)).not.toMatch(/987654|secret-fcm|17\.38|78\.48/);
    await expect(f.d.query(api.requests.tracker, { requestId: f.requestId })).rejects.toThrow();
  });

  test("invalid units, forged fields, and invalid state transitions fail", async () => {
    const f = await fixture();
    await expect(f.h.mutation(api.requests.create, { bloodGroup: "o", rhFactor: "positive", units: -1, radiusKm: 10, urgency: "urgent" })).rejects.toThrow();
    await expect(f.d.mutation(api.profiles.saveDonor, { bloodGroup: "o", rhFactor: "positive", lat: 17.38, lng: 78.48, available: true, points: 1000 } as never)).rejects.toThrow();
    await expect(f.d.mutation(api.requests.updateResponse, { requestId: f.requestId, status: "arrived" })).rejects.toThrow();
    await expect(f.d.mutation(api.requests.updateResponse, { requestId: f.requestId, status: "donated" } as never)).rejects.toThrow();
    await expect(f.h.mutation(api.requests.confirmDonation, { responseId: f.responseId, units: 1, donationType: "whole_blood" })).rejects.toThrow();
  });

  test("confirmation is atomic and idempotent after closure; changed replay fails", async () => {
    const f = await fixture();
    await f.arrive();
    const args = { responseId: f.responseId, units: 1, donationType: "whole_blood" as const };
    const recorded = await f.h.mutation(api.requests.confirmDonation, args);
    expect(await f.h.mutation(api.requests.confirmDonation, args)).toBe(recorded);
    await expect(f.h.mutation(api.requests.confirmDonation, { ...args, donationType: "plasma" })).rejects.toThrow();
    const state = await f.t.run(async ctx => ({ donor: await ctx.db.get(f.donorId), request: await ctx.db.get(f.requestId), donations: await ctx.db.query("donations").collect() }));
    expect(state.donor?.points).toBe(100);
    expect(state.donor?.totalDonations).toBe(1);
    expect(state.request?.unitsFulfilled).toBe(1);
    expect(state.request?.status).toBe("fulfilled");
    expect(state.donations).toHaveLength(1);
  });

  test("donor cannot accept a second active journey", async () => {
    const f = await fixture();
    const second = await f.create();
    await f.d.mutation(api.requests.updateResponse, { requestId: f.requestId, status: "accepted", healthCheckPassed: true });
    await expect(f.d.mutation(api.requests.updateResponse, { requestId: second, status: "accepted", healthCheckPassed: true })).rejects.toThrow("existing journey");
  });

  test("cooldown prevents a competing confirmation even with legacy arrived rows", async () => {
    const f = await fixture();
    const second = await f.create();
    await f.arrive();
    const secondResponse = (await f.h.query(api.requests.tracker, { requestId: second })).donors[0].responseId;
    await f.t.run(ctx => ctx.db.patch(secondResponse, { status: "arrived", healthCheckPassed: true }));
    await f.h.mutation(api.requests.confirmDonation, { responseId: f.responseId, units: 1, donationType: "whole_blood" });
    await expect(f.h.mutation(api.requests.confirmDonation, { responseId: secondResponse, units: 1, donationType: "whole_blood" })).rejects.toThrow("not eligible");
  });

  test("disabled donor cannot be confirmed", async () => {
    const f = await fixture();
    await f.arrive();
    await f.t.run(ctx => ctx.db.patch(f.donorUserId, { disabled: true }));
    await expect(f.h.mutation(api.requests.confirmDonation, { responseId: f.responseId, units: 1, donationType: "whole_blood" })).rejects.toThrow("not eligible");
  });

  test("device ownership prevents token theft and cross-account revocation", async () => {
    const f = await fixture();
    const device = { installationId: "installation", token: "token-value", platform: "android" as const };
    await f.d.mutation(api.devices.register, device);
    await expect(f.outsider.mutation(api.devices.register, device)).rejects.toThrow();
    await expect(f.outsider.mutation(api.devices.revoke, { installationId: device.installationId })).rejects.toThrow();
    await f.d.mutation(api.devices.revoke, { installationId: device.installationId });
    await f.outsider.mutation(api.devices.register, device);
    expect((await f.t.run(ctx => ctx.db.query("devices").collect()))).toHaveLength(1);
  });
});
