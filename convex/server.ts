// Typed bindings kept local so unit tests need no deployment or generated files.
// These use Convex's public builder API; `convex dev` can generate SDK bindings later.
import { mutationGeneric, queryGeneric, internalMutationGeneric } from "convex/server";
import type { DataModelFromSchemaDefinition, GenericMutationCtx, GenericQueryCtx,
  MutationBuilder, QueryBuilder } from "convex/server";
import schema from "./schema";
export type DataModel = DataModelFromSchemaDefinition<typeof schema>;
export type MutationCtx = GenericMutationCtx<DataModel>;
export type QueryCtx = GenericQueryCtx<DataModel>;
export const mutation: MutationBuilder<DataModel, "public"> = mutationGeneric;
export const query: QueryBuilder<DataModel, "public"> = queryGeneric;
export const internalMutation: MutationBuilder<DataModel, "internal"> = internalMutationGeneric;
