module

/-- Deliberately linear work whose placement inside or outside `loop` is observable. -/
@[noinline]
public def expensiveInvariant (input : Array Nat) : Nat :=
  input.foldr (init := 0) (· + ·)

/-- Uses `omega` after hiding the value of `inc` from the tactic. -/
@[noinline]
public def withClearValue (input : Array Nat) : Nat :=
  let limit := input.size
  let invariant := expensiveInvariant input
  let rec loop (i k : Nat) (hik : i ≤ k) (hk : k ≤ limit) : Nat :=
    if h : k < limit then
      let inc := (decide (k < invariant) : Bool).toNat
      have hinc : inc ≤ 1 := Bool.toNat_le _
      loop (i + inc) (k + 1)
        (by clear_value inc; omega) (Nat.add_one_le_iff.mpr h)
    else
      i
  loop 0 0 (Nat.le_refl _) (Nat.zero_le limit)

/-- Differs from `withClearValue` only by omitting `clear_value inc`. -/
@[noinline]
public def withoutClearValue (input : Array Nat) : Nat :=
  let limit := input.size
  let invariant := expensiveInvariant input
  let rec loop (i k : Nat) (hik : i ≤ k) (hk : k ≤ limit) : Nat :=
    if h : k < limit then
      let inc := (decide (k < invariant) : Bool).toNat
      have hinc : inc ≤ 1 := Bool.toNat_le _
      loop (i + inc) (k + 1)
        (by omega) (Nat.add_one_le_iff.mpr h)
    else
      i
  loop 0 0 (Nat.le_refl _) (Nat.zero_le limit)
