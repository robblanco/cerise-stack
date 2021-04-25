From cap_machine
Require Import machine_parameters machine_base cap_lang machine_run.

Definition step `{MachineParameters} (c: Conf): Conf :=
  match c with
  | (Failed, _)
  | (Halted, _) => c
  | (NextI, (r, m))
  | (Executable, (r, m)) =>
    let pc := r !r! PC in
    if isCorrectPCb pc then
      let a := match pc with
               | inl _ => top (* dummy *)
               | inr (_, _, _, _, a) => a
               end in
      let i := decodeInstrW (m !m! a) in
      exec i (r, m)
    else
      (Failed, (r, m))
  end.
