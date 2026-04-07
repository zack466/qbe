# Bug Fix Journal

## Bug 1: Apple ARM64 Stack Argument Alignment
**File**: `arm64/abi.c`
**Test**: `abi1.ssa`

### Description
On Apple Silicon (ARM64 Apple target), the ABI for passing arguments on the stack differs from the standard ARM64 AAPCS64. While the standard allows packing smaller types (like 32-bit integers) tightly, Apple's ABI requires each argument to occupy an 8-byte aligned slot. QBE was incorrectly packing these arguments, leading to the callee reading garbage values from the stack.

### Fix
Updated the `selcall` and `selpar` functions in `arm64/abi.c` to enforce 8-byte alignment for each stack argument when the target is `T_arm64_apple`. This ensures that every argument starts at an 8-byte boundary relative to the stack pointer, and that the total stack space allocated for arguments is correctly calculated. This fix covers both regular calls and variadic calls.

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
Added 4 new stress tests to verify compiler robustness for more complex language features:
1. **Register Spilling (`spill2.ssa`)**: Uses 64 simultaneous live variables to force heavy spilling on all architectures.
2. **Complex ABI (`abi10.ssa`)**: Tests nested structs with mixed types (byte, int, float, double, long) to verify ABI classification.
3. **Large Control Flow (`switch.ssa`)**: Simulates a large switch statement with 16+ branches to test branch resolution.
4. **Context Simulation (`ctx.ssa`)**: Simulates state saving/restoring (foundation for coroutines/effects) and verifies PHI node resolution across many cycles.
