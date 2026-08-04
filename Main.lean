module

public import Repro
import TimeIt.Basic

#version

private def parseNatOr (fallback : Nat) (arg? : Option String) : Nat :=
  arg?.bind String.toNat? |>.getD fallback

private def bestOf (repetitions : Nat) (expected : Nat)
    (f : Array Nat → Nat) (input : Array Nat) : IO Nat := do
  let mut best? : Option Nat := none
  for _ in *...repetitions do
    let (duration, result) ← IO.timeFn f input
    let elapsed := duration.toNanoseconds.toInt.toNat
    unless result == expected do
      throw <| IO.userError s!"unexpected result: got {result}, expected {expected}"
    best? := some <| match best? with
      | none => elapsed
      | some best => min best elapsed
  return best?.getD 0

private def slowdownTenths (fast slow : Nat) : Nat :=
  if fast == 0 then 0 else slow * 10 / fast

public def main (args : List String) : IO Unit := do
  let size := parseNatOr 2000 args[0]?
  let repetitions := parseNatOr 5 args[1]?
  let input := Array.replicate size 1

  let withClearValueNs ← bestOf repetitions size withClearValue input
  let withoutClearValueNs ← bestOf repetitions size withoutClearValue input
  let slowdown := slowdownTenths withClearValueNs withoutClearValueNs

  IO.println s!"array size: {size}; best of {repetitions}"
  IO.println s!"with clear_value:    {withClearValueNs} ns"
  IO.println s!"without clear_value: {withoutClearValueNs} ns"
  IO.println s!"slowdown:            {slowdown / 10}.{slowdown % 10}x"
