(** Formal definition of a use case. *)
Require Import Coq.Logic.JMeq.
Require Import Io.All.

Record t {E : Effect.t} {A : Type} (x : C.t E A) : Type := New {
  parameter : Type;
  result : parameter -> A;
  run : forall p, Run.t x (result p) }.
Arguments New {E A x} _ _ _.
Arguments parameter {E A x} _.
Arguments result {E A x} _ _.
Arguments run {E A x} _ _.

Module Le.
  Definition t {E A} {x : C.t E A} (u1 u2 : UseCase.t x) : Prop :=
    forall (p1 : parameter u1), exists (p2 : parameter u2),
      JMeq (run u1 p1) (run u2 p2).

  Lemma reflexive {E A} {x : C.t E A} (u : UseCase.t x) : t u u.
    intro p; exists p.
    apply JMeq_refl.
  Qed.

  Lemma transitivity {E A} {x : C.t E A} {u1 u2 u3 : UseCase.t x}
    (H12 : t u1 u2) (H23 : t u2 u3) : t u1 u3.
    intro p1.
    destruct (H12 p1) as [p2 Heq12].
    destruct (H23 p2) as [p3 Heq23].
    exists p3.
    now apply JMeq_trans with (y := run u2 p2).
  Qed.
End Le.

Module Eq.
  Definition t {E A} {x : C.t E A} (u1 u2 : UseCase.t x) : Prop :=
    Le.t u1 u2 /\ Le.t u2 u1.
End Eq.

Module Join.
  Definition t {E A} {x : C.t E A} (u1 u2 : UseCase.t x) : UseCase.t x := {|
    parameter := parameter u1 + parameter u2;
    result := fun p =>
      match p with
      | inl p1 => result u1 p1
      | inr p2 => result u2 p2
      end;
    run := fun p =>
      match p with
      | inl p1 => run u1 p1
      | inr p2 => run u2 p2
      end |}.

  Lemma le_left {E A} {x : C.t E A} (u1 u2 : UseCase.t x)
    : Le.t u1 (t u1 u2).
    intro p1; exists (inl p1).
    apply JMeq_refl.
  Qed.

  Lemma le_right {E A} {x : C.t E A} (u1 u2 : UseCase.t x)
    : Le.t u2 (t u1 u2).
    intro p2; exists (inr p2).
    apply JMeq_refl.
  Qed.

  Lemma smallest {E A} {x : C.t E A} (u1 u2 u3 : UseCase.t x)
    (H1 : Le.t u1 u3) (H2 : Le.t u2 u3) : Le.t (t u1 u2) u3.
    intro p.
    destruct p as [p1 | p2].
    - destruct (H1 p1) as [p3 H1'].
      now exists p3.
    - destruct (H2 p2) as [p3 H2'].
      now exists p3.
  Qed.
End Join.

Module Bottom.
  Definition new {E A} (x : C.t E A) : UseCase.t x := {|
    parameter := Empty_set;
    result := fun p => match p with end;
    run := fun p => match p with end |}.

  Lemma smallest {E A} {x : C.t E A} (u : UseCase.t x) : Le.t (new x) u.
    intro p.
    destruct p.
  Qed.
End Bottom.

Module Top.
  Definition ret {E A} (v : A) : UseCase.t (C.Ret (E := E) A v) := {|
    parameter := unit;
    result := fun _ => v;
    run := fun _ => Run.Ret v |}.

  Definition call {E} (c : Effect.command E) : UseCase.t (C.Call c) := {|
    parameter := Effect.answer E c;
    result := fun a => a;
    run := fun a => Run.Call E c a |}.

  Definition _let {E A B} {x : C.t E A} {f : A -> C.t E B} (u_x : UseCase.t x)
    (u_f : forall v_x, UseCase.t (f v_x)) : UseCase.t (C.Let A B x f).
    refine {|
      parameter := {p_x : parameter u_x & parameter (u_f (result u_x p_x))};
      result := fun p =>
        let (p_x, p_f) := p in
        result (u_f (result u_x p_x)) p_f;
      run := _ |}.
    intro p.
    destruct p as [p_x p_f].
    eapply Run.Let.
    - exact (run u_x p_x).
    - exact (run (u_f _) p_f).
  Defined.

  Definition choose {E A} {x1 x2 : C.t E A} (u1 : UseCase.t x1)
    (u2 : UseCase.t x2) : UseCase.t (C.Choose A x1 x2).
    refine {|
      parameter := parameter u1 + parameter u2;
      result := fun p =>
        match p with
        | inl p1 => result u1 p1
        | inr p2 => result u2 p2
        end;
      run := _ |}.
    intro p.
    destruct p as [p1 | p2].
    - apply Run.ChooseLeft.
      exact (run u1 p1).
    - apply Run.ChooseRight.
      exact (run u2 p2).
  Defined.

  Definition join {E A B} {x : C.t E A} {y : C.t E B} (u_x : UseCase.t x)
    (u_y : UseCase.t y) : UseCase.t (C.Join A B x y).
    refine {|
      parameter := parameter u_x * parameter u_y;
      result := fun p =>
        let (p_x, p_y) := p in
        (result u_x p_x, result u_y p_y);
      run := _ |}.
    intro p.
    destruct p as [p_x p_y].
    apply Run.Join.
    - exact (run u_x p_x).
    - exact (run u_y p_y).
  Defined.
End Top.
