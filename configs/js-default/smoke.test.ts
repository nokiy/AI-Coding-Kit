// Keeps `vitest run` green on a fresh scaffold, which has no tests (zero test files exits 1).
import { expect, test } from "vitest";

test("the test runner runs", () => {
  expect([1, 2, 3].includes(2)).toBe(true);
});
