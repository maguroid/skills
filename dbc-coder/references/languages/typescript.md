# TypeScript Patterns

Use this reference when implementing DbC in TypeScript or JavaScript codebases. Prefer a functional style: express contracts in types first, validate at trust boundaries, and compose small pure functions that accept already-validated values.

## Contract To Code

- Preconditions: refine unknown or broad input into narrower domain types at the boundary
- Postconditions: return types that make success guarantees explicit, often with discriminated unions or branded values
- Invariants: represent stable domain rules in constructors or smart constructors that produce validated values
- Failure semantics: prefer explicit `Result`-style return types for expected contract violations; use thrown errors for programmer mistakes only if that matches the repository

## TypeScript Guidance

- Let the type system carry as much of the contract as possible after validation
- Prefer functional modules with pure functions over mutable classes unless the existing codebase is stateful
- Use `unknown` at external boundaries, then decode into domain types
- Prefer discriminated unions, literal types, and branded types to make invalid states hard to represent
- Reuse repository-native validation or `Result` helpers when they exist instead of inventing a new algebra
- Keep runtime validation at the edge; internal functions should usually consume validated types rather than repeating checks

## Type Patterns

Use opaque or branded types to mark values that have satisfied a contract:

```ts
type Brand<T, Name extends string> = T & { readonly __brand: Name };

type NonEmptyString = Brand<string, "NonEmptyString">;
type NonNegativeInt = Brand<number, "NonNegativeInt">;

type ContractError =
  | { readonly kind: "empty_string"; readonly message: string }
  | { readonly kind: "not_integer"; readonly message: string }
  | { readonly kind: "negative_value"; readonly message: string };

type Result<Ok, Err> =
  | { readonly ok: true; readonly value: Ok }
  | { readonly ok: false; readonly error: Err };
```

Model preconditions with smart constructors:

```ts
const makeNonEmptyString = (value: string): Result<NonEmptyString, ContractError> =>
  value.trim().length > 0
    ? { ok: true, value: value as NonEmptyString }
    : { ok: false, error: { kind: "empty_string", message: "value must not be empty" } };

const makeNonNegativeInt = (value: number): Result<NonNegativeInt, ContractError> => {
  if (!Number.isInteger(value)) {
    return { ok: false, error: { kind: "not_integer", message: "value must be an integer" } };
  }

  if (value < 0) {
    return { ok: false, error: { kind: "negative_value", message: "value must be >= 0" } };
  }

  return { ok: true, value: value as NonNegativeInt };
};
```

## Assertion Patterns

If the codebase prefers exceptions, keep the type-first shape and swap the smart constructor for an assertion function:

```ts
function assertNonEmptyString(value: string, name: string): asserts value is NonEmptyString {
  if (value.trim().length === 0) {
    throw new TypeError(`${name} must not be empty`);
  }
}
```

Use this sparingly. For expected validation failures at IO boundaries, a `Result` is usually easier to test and compose in functional code.

## Example: Functional Contract

This example models a small domain where validated types carry the contract. Parsing owns the preconditions, and the formatter works only with already-validated data.

```ts
type Brand<T, Name extends string> = T & { readonly __brand: Name };

type NonEmptyString = Brand<string, "NonEmptyString">;
type NonNegativeInt = Brand<number, "NonNegativeInt">;

type UserProfile = Readonly<{
  name: NonEmptyString;
  age: NonNegativeInt;
}>;

type RawUserProfile = {
  name: string;
  age: number;
};

type ContractError =
  | { readonly field: "name"; readonly kind: "empty"; readonly message: string }
  | { readonly field: "age"; readonly kind: "not_integer"; readonly message: string }
  | { readonly field: "age"; readonly kind: "negative"; readonly message: string };

type Result<Ok, Err> =
  | { readonly ok: true; readonly value: Ok }
  | { readonly ok: false; readonly error: Err };

const makeName = (value: string): Result<NonEmptyString, ContractError> =>
  value.trim().length > 0
    ? { ok: true, value: value as NonEmptyString }
    : {
        ok: false,
        error: { field: "name", kind: "empty", message: "name must not be empty" },
      };

const makeAge = (value: number): Result<NonNegativeInt, ContractError> => {
  if (!Number.isInteger(value)) {
    return {
      ok: false,
      error: { field: "age", kind: "not_integer", message: "age must be an integer" },
    };
  }

  if (value < 0) {
    return {
      ok: false,
      error: { field: "age", kind: "negative", message: "age must be >= 0" },
    };
  }

  return { ok: true, value: value as NonNegativeInt };
};

export const parseUserProfile = (
  input: RawUserProfile,
): Result<UserProfile, ContractError> => {
  const name = makeName(input.name);
  if (!name.ok) {
    return name;
  }

  const age = makeAge(input.age);
  if (!age.ok) {
    return age;
  }

  return {
    ok: true,
    value: {
      name: name.value,
      age: age.value,
    },
  };
};

export const formatUserProfile = (profile: UserProfile): string =>
  `${profile.name} (${profile.age})`;
```

Contract reading:

- Precondition for `parseUserProfile`: raw input may be invalid, so return `Result`
- Postcondition for successful parse: `value` is a `UserProfile`, and each field satisfies its domain contract
- Precondition for `formatUserProfile`: caller must pass an already-validated `UserProfile`
- Invariant: a `UserProfile` can only exist with non-empty `name` and non-negative integer `age`

## Test Matrix

Translate the same contract into tests. The example below uses Vitest syntax that also maps closely to Jest.

```ts
import { describe, expect, it } from "vitest";

import { formatUserProfile, parseUserProfile } from "./user-profile";

describe("parseUserProfile", () => {
  it("returns a validated profile for valid input", () => {
    const result = parseUserProfile({ name: "Aiko", age: 24 });

    expect(result).toEqual({
      ok: true,
      value: {
        name: "Aiko",
        age: 24,
      },
    });
  });

  it("rejects an empty name", () => {
    const result = parseUserProfile({ name: "   ", age: 24 });

    expect(result).toEqual({
      ok: false,
      error: {
        field: "name",
        kind: "empty",
        message: "name must not be empty",
      },
    });
  });

  it("rejects a negative age", () => {
    const result = parseUserProfile({ name: "Aiko", age: -1 });

    expect(result).toEqual({
      ok: false,
      error: {
        field: "age",
        kind: "negative",
        message: "age must be >= 0",
      },
    });
  });
});

describe("formatUserProfile", () => {
  it("formats only validated profiles", () => {
    const parsed = parseUserProfile({ name: "Aiko", age: 24 });

    expect(parsed.ok).toBe(true);
    if (!parsed.ok) {
      return;
    }

    expect(formatUserProfile(parsed.value)).toBe("Aiko (24)");
  });
});
```

## Review Checklist

- Are preconditions pushed to parsing or decoding functions at the boundary?
- Do internal functions accept refined domain types instead of raw primitives where possible?
- Do types make invalid states hard to represent?
- Are expected contract failures returned in a structured form consistent with the codebase?
- Do tests cover success, boundary, and contract-violation paths without coupling too tightly to implementation details?
