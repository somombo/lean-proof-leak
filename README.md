# Lean "Proof Leak"

## Bug Report Title: Changing only a proof makes execution time quadruple instead of double when input size doubles

### Prerequisites

<!-- Please put an X between the brackets as you perform the following steps: -->

* [x] Check that your issue is not already filed:
      https://github.com/leanprover/lean4/issues
* [x] Reduce the issue to a minimal, self-contained, reproducible test case.
      Avoid dependencies to Mathlib or Batteries.
* [x] Test your test case against the latest nightly release, for example on
      https://live.lean-lang.org/#project=lean-nightly
      (You can also use the settings there to switch to “Lean nightly”)

### Description

I've encountered an issue where modifying a proof that gets erased at runtime dramatically alters the performance of a compiled Lean function. Specifically, it changes the execution time scaling from linear to near-quadratic over the tested range.

The reproducer contains two functions with identical signatures and return values. The only difference is how a precondition for a recursive call is proven:

```diff
-        (by clear_value inc; omega) (Nat.add_one_le_iff.mpr h)
+        (by omega) (Nat.add_one_le_iff.mpr h)
```

According to Lean's language reference on [run-time irrelevance](https://lean-lang.org/doc/reference/latest/The-Type-System/Propositions/), propositions are erased during compilation. Therefore, changing a proof shouldn't affect runtime performance. However, without `clear_value inc`, the execution time scales near-quadratically over the tested range instead of linearly, even though both variants produce the exact same correct output.

### Context

I discovered this problem while trying to isolate a performance regression in a recursive loop within my local project. The provided reproducer is completely synthetic, stripped of any application-specific logic, and relies on the standard Lean environment. Its only external dependency is [somombo/time-it](https://github.com/somombo/time-it), which is used solely to benchmark the execution time. It avoids any `sorry`, `unsafe`, or FFI code.

There is currently no discussion about this on the Lean Zulip.

### Steps to Reproduce

1. Get the reproducer repository:
   ```sh
   git clone https://github.com/somombo/lean-proof-leak
   cd lean-proof-leak
   ```
2. Compile a release build:
   ```sh
   lake build -R
   ```
3. Run the executable to benchmark different input sizes (the arguments represent the array size and the number of timing repetitions):
   ```sh
   .lake/build/bin/repro 1000 7
   .lake/build/bin/repro 2000 7
   .lake/build/bin/repro 4000 7
   .lake/build/bin/repro 8000 7
   ```

**Expected behavior:** Both variants of the function should run with identical linear time complexity, since the only difference between them is within a proof (that is erased before runtime). As the input size doubles, the runtime should also roughly double.

**Actual behavior:** The runtime of the version without `clear_value inc` scales near-quadratically over the tested range. While the `clear_value inc` version behaves as expected (doubling the input doubles the time), the variant without it takes roughly four times as long when the input size is doubled. For example, moving from an input size of 4,000 to 8,000 empirically demonstrates this 2x versus 4x scaling:

- **With `clear_value`:** Runtime increases from 22.458 µs to 44.893 µs (a ~2x increase).
- **Without `clear_value`:** Runtime jumps from 19.031 ms to 76.431 ms (a ~4x increase).

Overall, the estimated exponent jumps from about 1.0 to 2.0 simply by omitting `clear_value inc` in the proof.

### Versions

```lean
#version
```

Output:
```text
Lean 4.34.0-nightly-2026-08-04
Target: x86_64-unknown-linux-gnu Linux
```

Running on Ubuntu 24.04.4 LTS (Linux 6.14.0-37-generic, x86-64).

### Additional Information

The benchmarking was done by taking the minimum execution time across 7 invocations in a single process, and the median of those minima across 7 separate processes. Both implementations were verified to return the same correct values during every run.

You can automatically reproduce this entire testing methodology, calculate the medians, and compute the estimated fitted exponents using the included python script:
```sh
python3 run_benchmark.py
```
This script acts as a wrapper around the `.lake/build/bin/repro` executable to execute seven processes containing seven timed invocations at each input size.

Here is a summary of the timing results from one representative benchmark run:

| Input Size | With `clear_value` | Without `clear_value` | Slowdown Factor |
|---:|---:|---:|---:|
| 1,000 | 6.572 µs | 1.199 ms | 182.4x |
| 2,000 | 11.242 µs | 4.771 ms | 424.4x |
| 4,000 | 22.458 µs | 19.031 ms | 847.4x |
| 8,000 | 44.893 µs | 76.431 ms | 1,702.5x |

Using a least-squares fit on these values, the estimated exponent is 0.931 when `clear_value` is present and 1.998 when it is absent. The workaround on this nightly build is to use `by clear_value inc; omega`, which restores the expected linear scaling.

### Impact

This issue is problematic because refactoring a proof can silently ruin the performance of an application by introducing near-quadratic scaling. This happens without altering any executable source expressions and while compiling perfectly.

Add :+1: to [issues you consider important](https://github.com/leanprover/lean4/issues?q=is%3Aissue+is%3Aopen+sort%3Areactions-%2B1-desc). If others are impacted by this issue, please ask them to add :+1: to it.
