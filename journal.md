# Bug Fix Journal

## Bug 1: Apple ARM64 Stack Argument Alignment (Corrected)
**File**: `tools/test.sh`, `flake.nix` (reverted `arm64/abi.c`)
**Test**: `abi1.ssa`, `vararg2.ssa`

### Description
A mismatch was identified between QBE's ARM64 Apple target and the environment's default compiler (`gcc`). On Apple Silicon, the ABI allows for "tight" packing of stack arguments (e.g., 4-byte types only occupy 4 bytes). Standard AAPCS64 (followed by GCC) requires 8-byte slots. Initially, QBE was "fixed" to match GCC, but this made it non-compliant with the official Apple ABI used by system libraries and `clang`.

### Fix
Reverted the stack alignment changes in `arm64/abi.c` to maintain compliance with Apple's tight-packing ABI. Instead, the environment and test runner were updated to use `clang` on Darwin targets. This ensures that the test driver is compiled with a compiler that shares the same ABI expectations as QBE.

---

## Bug 2: Apple ARM64 Floating Point Comparison Negation
**File**: `arm64/emit.c`
**Test**: `ifc.ssa`

### Description
Floating point comparisons involving NaNs were failing on Apple ARM64 during conditional branches. QBE's branch-merging optimization was using condition codes whose negations did not account for the "unordered" state (NaNs). For example, `!(ordered <)` was being compiled to a branch that was false for NaNs, causing the comparison to incorrectly evaluate as true.

### Fix
Disabled the branch-merging optimization for floating-point comparisons in `arm64/isel.c`. This forces the compiler to materialize the comparison result into a register using `cset`, which correctly handles NaNs according to C and IEEE 754 semantics, before performing the branch based on that result.

---

## Bug 3: Apple ARM64 Reserved Register x18
**File**: `arm64/targ.c`

### Description
On Apple Silicon, register `x18` is reserved for the platform (e.g., Shadow Call Stack). QBE was including `x18` in its `arm64_rsave` list, which made it available for general register allocation. Using this register on Apple targets can lead to crashes or unstable behavior when interacting with the system.

### Fix
Created a separate register set `apple_rsave` for the Apple target that excludes `R18`. Updated `T_arm64_apple` to use this new set and adjusted the register count (`nrsave`) accordingly.

---

## New Tests
Added 5 new stress tests to verify compiler robustness for more complex language features:
1. **Register Spilling (`spill2.ssa`)**: Uses 64 simultaneous live variables to force heavy spilling on all architectures.
2. **Complex ABI (`abi10.ssa`)**: Tests nested structs with mixed types (byte, int, float, double, long) to verify ABI classification.
3. **Large Control Flow (`switch.ssa`)**: Simulates a large switch statement with 16+ branches to test branch resolution.
4. **Context Simulation (`ctx.ssa`)**: Simulates state saving/restoring (foundation for coroutines/effects) and verifies PHI node resolution across many cycles.
5. **Reserved Register Safeguard (`apple_x18.ssa`)**: Ensures the Apple Silicon reserved platform register `x18` is never used for general allocation, even under extreme register pressure.

---

## Final Verification of Apple Silicon ABI Compliance
In addition to the bug fixes above, the following Apple Silicon specific requirements were verified in the codebase:
- **Mandatory Frame Pointer**: Verified that `arm64/emit.c` maintains a strict `x29` frame pointer chain.
- **Narrow Returns/Arguments**: Verified that `apple_extsb` in `arm64/abi.c` correctly promotes sub-32-bit types.
- **PC-Relative Addressing**: Verified that `arm64/emit.c` uses Mach-O compatible `@page` and `@pageoff` relocations.
- **Reserved Registers**: Verified that `x18` is now reserved and `hint #34` (BTI) is used at function entry points.
