import { describe, expect, it } from "@jest/globals";

import { add } from "./calculator";

describe("add", () => {
  it("adds positive numbers", () => {
    expect(add(2, 3)).toBe(5);
  });

  it("adds negative numbers", () => {
    expect(add(-1, 1)).toBe(0);
    expect(add(-4, -6)).toBe(-10);
  });

  it("adds zero", () => {
    expect(add(0, 0)).toBe(0);
  });
});
