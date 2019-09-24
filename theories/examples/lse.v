From cap_machine Require Import rules logrel fundamental. 
From cap_machine.examples Require Import stack_macros. 
From iris.algebra Require Import frac.
From iris.proofmode Require Import tactics.
Require Import Eqdep_dec List.

Section lse.
  Context `{memG Σ, regG Σ, STSG Σ,
            logrel_na_invs Σ,
            MonRef: MonRefG (leibnizO _) CapR_rtc Σ,
                    World: MonRefG (leibnizO _) RelW Σ}.

   Ltac iPrologue_pre :=
    match goal with
    | Hlen : length ?a = ?n |- _ =>
      let a' := fresh "a" in
      destruct a as [_ | a' a]; inversion Hlen; simpl
    end.
  
  Ltac iPrologue prog :=
    (try iPrologue_pre);
    iDestruct prog as "[Hi Hprog]"; 
    iApply (wp_bind (fill [SeqCtx])).

  Ltac iEpilogue prog :=
    iNext; iIntros prog; iSimpl;
    iApply wp_pure_step_later;auto;iNext.

  Ltac middle_lt prev index :=
    match goal with
    | Ha_first : ?a !! 0 = Some ?a_first |- _ 
    => apply Z.lt_trans with prev; auto; apply incr_list_lt_succ with a index; auto
    end. 

  Ltac iCorrectPC index :=
    match goal with
    | [ Hnext : ∀ (i : nat) (ai aj : Addr), ?a !! i = Some ai
                                          → ?a !! (i + 1) = Some aj
                                          → (ai + 1)%a = Some aj,
          Ha_first : ?a !! 0 = Some ?a_first,
          Ha_last : list.last ?a = Some ?a_last |- _ ]
      => apply isCorrectPC_bounds_alt with a_first a_last; eauto; split ;
         [ apply Z.lt_le_incl;auto |
           apply incr_list_le_middle with a index; auto ]
    end.

  Ltac addr_succ :=
    match goal with
    | H : _ |- (?a1 + ?z)%a = Some ?a2 =>
      rewrite /incr_addr /=; do 2 f_equal; apply eq_proofs_unicity; decide equality
    end.
       
  Ltac wp_push_z Hstack a_lo a_hi b e a_cur a_next φ push1 push2 push3 ws prog ptrn :=
    match goal with
    | H : length _ = _ |- _ =>
      let wa := fresh "wa" in
      let Ha := fresh "w"a_next in
      let Ha_next := fresh "H"a_next in
      iDestruct prog as "[Hi Hf2]";
      destruct ws as [_ | wa ws]; first inversion H;
      iDestruct Hstack as "[Ha Hstack]"; 
      iApply (push_z_spec push1 push2 push3 _ _ _ _ _ _ _ b e a_cur a_next φ);
      eauto; try addr_succ; try apply PermFlows_refl; 
      [split; eauto; apply isCorrectPC_bounds with a_lo a_hi; eauto; split; done|];
      iFrame; iNext; iIntros ptrn
    end.

   Ltac wp_push_r Hstack a_lo a_hi b e a_cur a_next φ push1 push2 push3 ws prog ptrn :=
    match goal with
    | H : length _ = _ |- _ =>
      let wa := fresh "wa" in
      let Ha := fresh "w"a_next in
      iDestruct prog as "[Hi Hf2]";
      destruct ws as [_ | wa ws]; first inversion H;
      iDestruct Hstack as "[Ha Hstack]"; 
      iApply (push_r_spec push1 push2 push3 _ _ _ _ _ _ _ _ b e a_cur a_next φ);
      eauto; try addr_succ; try apply PermFlows_refl;
      [split; eauto; apply isCorrectPC_bounds with a_lo a_hi; eauto; split; done|];
      iFrame; iNext; iIntros ptrn
    end.

   (* The following ltac gets out the next general purpuse register *)
   Ltac get_genpur_reg Hr_gen wsr ptr :=
     let w := fresh "wr" in 
       destruct wsr as [? | w wsr]; first (by iApply bi.False_elim);
       iDestruct Hr_gen as ptr. 
    
        
  (* encapsulation of local state using local capabilities and scall *)
  (* assume r1 contains an executable pointer to adversarial code 
     (no linking table yet) *)
  Definition f2 (r1 : RegName) (p : Perm) : iProp Σ :=
    (    (* push 1 *)
           push_z a0 a1 p r_stk 1
    (* scall r1([],[]) *)
         (* push private state *)
         (* push activation code *)
         ∗ push_z a2 a3 p r_stk w_1
         ∗ push_z a4 a5 p r_stk w_2
         ∗ push_z a6 a7 p r_stk w_3
         ∗ push_z a8 a9 p r_stk w_4a
         ∗ push_z a10 a11 p r_stk w_4b
         ∗ push_z a12 a13 p r_stk w_4c
         (* push old pc *)
         ∗ a14 ↦ₐ[p] move_r r_t1 PC
         ∗ a15 ↦ₐ[p] lea_z r_t1 64 (* offset to "after" *)
         ∗ push_r a16 a17 p r_stk r_t1
         (* push stack pointer *)
         ∗ a18 ↦ₐ[p] lea_z r_stk 1
         ∗ a19 ↦ₐ[p] store_r r_stk r_stk
         (* set up protected return pointer *)
         ∗ a20 ↦ₐ[p] move_r r_t0 r_stk
         ∗ a21 ↦ₐ[p] lea_z r_t0 (-7)%Z
         ∗ a22 ↦ₐ[p] restrict_z r_t0 (local_e)
         (* restrict stack capability *)
         ∗ a23 ↦ₐ[p] geta r_t1 r_stk
         ∗ a24 ↦ₐ[p] add_r_z r_t1 r_t1 1
         ∗ a25 ↦ₐ[p] gete r_t2 r_stk
         ∗ a26 ↦ₐ[p] subseg_r_r r_stk r_t1 r_t2
         (* clear the unused part of the stack *)
         (* mclear r_stk: *)
         ∗ mclear (region_addrs_aux a27 22) p r_stk 10 2 (* contiguous *)
         (* clear non-argument registers *)
         ∗ rclear (region_addrs_aux a49 29) p
                  (list_difference all_registers [PC;r_stk;r_t0;r1])
         (* jump to unknown code *)
         ∗ a78 ↦ₐ[p] jmp r1
    (* after: *)
         (* pop the restore code *)
         (* to shorten the program we will do it all at once *)
         ∗ a79 ↦ₐ[p] sub_z_z r_t1 0 7
         ∗ a80 ↦ₐ[p] lea_r r_stk r_t1
         (* pop the private state into appropriate registers *)
    (* END OF SCALL *)
         ∗ a81 ↦ₐ[p] load_r r1 r_stk
         ∗ a82 ↦ₐ[p] sub_z_z r_t1 0 1
         ∗ a83 ↦ₐ[p] lea_r r_stk r_t1
         (* assert r1 points to 1. For "simplicity" I am not using the assert macro ! 
            but rather a hardcoded version for f2. TODO: change this to actual assert *)
         ∗ a84 ↦ₐ[p] move_r r_t1 PC
         ∗ a85 ↦ₐ[p] lea_z r_t1 5(* offset to fail *)
         ∗ a86 ↦ₐ[p] sub_r_z r1 r1 1
         ∗ a87 ↦ₐ[p] jnz r_t1 r1
         ∗ a88 ↦ₐ[p] halt
         (* set the flag to 1 to indicate failure. flag is set to be the address after 
            the program *)
         ∗ a89 ↦ₐ[p] move_r r_t1 PC
         ∗ a90 ↦ₐ[p] lea_z r_t1 4(* offset to flag *)
         ∗ a91 ↦ₐ[p] store_z r_t1 1
         ∗ a92 ↦ₐ[p] halt
    )%I.


  (* We want to show encapsulation of local state, by showing that an arbitrary adv 
     cannot change what lies on top of the stack after return, i.e. we want to show
     that the last pop indeed loads the value 1 into register r1 *)
  (* to make the proof simpler, we are assuming WLOG the r1 registers is r_t30 *)
  Lemma f2_spec M b e a pc_p pc_g pc_b pc_e :
    (* r1 ≠ PC ∧ r1 ≠ r_stk ∧ r1 ≠ r_t0 → *)
    isCorrectPC (inr ((pc_p,pc_g),pc_b,pc_e,a0)) ∧
    isCorrectPC (inr ((pc_p,pc_g),pc_b,pc_e,a110)) →
    {{{ r_stk ↦ᵣ inr ((RWLX,Local),a120,a150,a119)
      ∗ (∃ wsr, [∗ list] r_i;w_i ∈ list_difference all_registers [PC;r_stk;r_t30]; wsr,
           r_i ↦ᵣ w_i)
      ∗ (∃ ws, [[a120, a150]]↦ₐ[RWLX][[ws]])
      (* flag *)
      ∗ a93 ↦ₐ[RW] inl 0%Z
      (* token which states all invariants are closed *)
      ∗ na_own logrel_nais ⊤
      (* adv *)
      ∗ r_t30 ↦ᵣ inr ((E,Global),b,e,a)
      ∗ ([∗ list] a ∈ region_addrs b e, read_write_cond a RX interp)
      (* trusted *)
      ∗ PC ↦ᵣ inr ((pc_p,pc_g),pc_b,pc_e,a0)
      ∗ f2 r_t30 pc_p
      (* we start out with arbitrary sts *)
      ∗ sts_full M.1.1 M.1.2
      ∗ Exact_w wγ M
    }}}
      Seq (Instr Executable)
    {{{ v, RET v; ⌜v = HaltedV⌝ → a93 ↦ₐ[RW] inl 0%Z }}}.
  Proof.
    iIntros ([Hvpc0 Hvpc93] φ)
        "(Hr_stk & Hr_gen & Hstack & Hflag & Hna & Hr1 & #Hadv & HPC & Hf2 & Hs) Hφ /=".
    iDestruct "Hr_gen" as (wsr) "Hr_gen". 
    get_genpur_reg "Hr_gen" wsr "[Hrt0 Hr_gen]".
    get_genpur_reg "Hr_gen" wsr "[Hrt1 Hr_gen]".
    get_genpur_reg "Hr_gen" wsr "[Hrt2 Hr_gen]". 
    iDestruct "Hstack" as (ws) "Hstack". 
    iDestruct (big_sepL2_length with "Hstack") as %Hlength.
    assert (∃ ws_own ws_adv, ws = ws_own ++ ws_adv ∧ length ws_own = 9)
      as [ws_own [ws_adv [Happ Hlength'] ] ].
    { simpl in Hlength.
      do 9 (destruct ws as [|? ws]; inversion Hlength).
        by exists [w;w0;w1;w2;w3;w4;w5;w6;w7],ws. }
    assert ((a100 ≤ a108)%Z ∧ (a108 < a150)%Z); first (simpl; lia).  
    rewrite Happ (stack_split a120 a150 a128 a129); auto; try addr_succ.
    simpl in Hlength. 
    iDestruct "Hstack" as "[Hstack_own Hstack_adv]".
    rewrite /region_mapsto.
    assert (region_addrs a120 a128 = [a120;a121;a122;a123;a124;a125;a126;a127;a128])
      as ->.
    { rewrite /region_addrs. 
      simpl. repeat f_equal; (apply eq_proofs_unicity; decide equality). }
    wp_push_z "Hstack_own" a0 a110 a120 a150 a119 a120 φ a0 a1 a2 ws_own "Hf2"
              "(HPC & _ & Hr_stk & Ha120)".
    wp_push_z "Hstack" a0 a110 a120 a150 a120 a121 φ a2 a3 a4 ws_own "Hf2"
              "(HPC & _ & Hr_stk & Ha121)".
    wp_push_z "Hstack" a0 a110 a120 a150 a121 a122 φ a4 a5 a6 ws_own "Hf2"
              "(HPC & _ & Hr_stk & Ha122)".
    wp_push_z "Hstack" a0 a110 a120 a150 a122 a123 φ a6 a7 a8 ws_own "Hf2"
              "(HPC & _ & Hr_stk & Ha123)".
    wp_push_z "Hstack" a0 a110 a120 a150 a123 a124 φ a8 a9 a10 ws_own "Hf2"
              "(HPC & _ & Hr_stk & Ha124)".
    wp_push_z "Hstack" a0 a110 a120 a150 a124 a125 φ a10 a11 a12 ws_own "Hf2"
              "(HPC & _ & Hr_stk & Ha125)".
    wp_push_z "Hstack" a0 a110 a120 a150 a125 a126 φ a12 a13 a14 ws_own "Hf2"
              "(HPC & _ & Hr_stk & Ha126)".
    iDestruct "Hf2" as "[Hi Hf2]".
    iApply (wp_bind (fill [SeqCtx])).
    iApply (wp_move_success_reg_fromPC _ _ _ _ _ a14 a15 _ r_t1
              with "[Hi Hrt1 HPC]"); eauto; try addr_succ;
      first apply move_r_i; first apply PermFlows_refl;
      first (apply isCorrectPC_bounds with a0 a110; eauto; split; done).
    iFrame. iNext. iIntros "(HPC & _ & Hr_t1)". iSimpl.
    iDestruct "Hf2" as "[Hi Hf2]".
    iApply wp_pure_step_later;auto;iNext. 
    iApply (wp_bind (fill [SeqCtx])).
    iApply (wp_lea_success_z _ _ _ _ _ a15 a16 _ r_t1 pc_p _ _ _ a14 64 a78
              with "[Hi Hr_t1 HPC]"); eauto; try addr_succ;
      first apply lea_z_i; first apply PermFlows_refl;
      first (apply isCorrectPC_bounds with a0 a110; eauto; split; done).
    { inversion Hvpc0 as [?????? Hpc_p | ????? Hpc_p];
        destruct Hpc_p as [Hpc_p | [Hpc_p | Hpc_p] ]; congruence. }
    iFrame. iNext. iIntros "(HPC & _ & Hrt_1)"; iSimpl.
    iApply wp_pure_step_later;auto;iNext. 
    wp_push_r "Hstack" a0 a110 a120 a150 a126 a127 φ a16 a17 a18 ws_own "Hf2"
              "(HPC & _ & Hr_stk & Hr_t1 & Ha127)".
    iDestruct "Hf2" as "[Hi Hf2]".
    iApply (wp_bind (fill [SeqCtx])).
    iApply (wp_lea_success_z _ _ _ _ _ a18 a19 _ r_stk RWLX _ _ _ a127 1 a128
              with "[Hi Hr_stk HPC]"); eauto; try addr_succ;
      first apply lea_z_i; first apply PermFlows_refl;
      first (apply isCorrectPC_bounds with a0 a110; eauto; split; done).
    iFrame. iNext. iIntros "(HPC & _ & Hr_stk)"; iSimpl.
    iApply wp_pure_step_later;auto;iNext.
    destruct ws_own as [_ | wa129 ws_own]; first inversion Hlength';
      iDestruct "Hstack" as "[Ha128 Hstack]".
    iDestruct "Hf2" as "[Hi Hf2]".
    iApply (wp_bind (fill [SeqCtx])).
    iApply (wp_store_success_reg_same _ _ _ _ _ a19 a20 _ r_stk _ RWLX
                                 Local a120 a150 a128
              with "[HPC Hi Hr_stk Ha128]"); eauto; try addr_succ;
      first apply store_r_i; try apply PermFlows_refl;
      first (apply isCorrectPC_bounds with a0 a110; eauto; split; done).
    iFrame. iNext. iIntros "(HPC & _ & Hr_stk & Ha128)"; iSimpl.
    iApply wp_pure_step_later;auto;iNext. 
    iDestruct "Hf2" as "[Hi Hf2]".
    iApply (wp_bind (fill [SeqCtx])).
    iApply (wp_move_success_reg _ _ _ _ _ a20 a21 _ r_t0 _ r_stk
              with "[HPC Hi Hrt0 Hr_stk]"); eauto; try addr_succ;
      first apply move_r_i; first apply PermFlows_refl;
      first (apply isCorrectPC_bounds with a0 a110; eauto; split; done).
    iFrame. iNext. iIntros "(HPC & _ & Hrt0 & Hr_stk)"; iSimpl.
    iApply wp_pure_step_later;auto;iNext.
    iDestruct "Hf2" as "[Hi Hf2]".
    iApply (wp_bind (fill [SeqCtx])).
    iApply (wp_lea_success_z _ _ _ _ _ a21 a22 _ r_t0 RWLX _ _ _ a128 (-7)%Z a121 
              with "[Hi Hrt0 HPC]"); eauto; try addr_succ;
      first apply lea_z_i;first apply PermFlows_refl;
      first (apply isCorrectPC_bounds with a0 a110; eauto; split; done).
    iFrame. iNext. iIntros "(HPC & _ & Hrt0)"; iSimpl.
    iApply wp_pure_step_later;auto;iNext.
    iDestruct "Hf2" as "[Hi Hf2]".
    iApply (wp_bind (fill [SeqCtx])).
    iApply (wp_restrict_success_z _ _ _ _ _ a22 a23 _ r_t0 RWLX Local a120 a150 a121
        local_e with "[Hi HPC Hrt0]"); eauto; try addr_succ;
      [apply restrict_r_z|apply PermFlows_refl| | | |];
      first (apply isCorrectPC_bounds with a0 a110; eauto; split; done).
    { rewrite epp_local_e /=. auto. }
    iFrame. iNext. iIntros "(HPC & _ & Hrt0)"; iSimpl.
    iApply wp_pure_step_later;auto;iNext.
    iDestruct "Hf2" as "[Hi Hf2]".
    iApply (wp_bind (fill [SeqCtx])).
    iApply (wp_GetA_success _ r_t1 _ _ _ _ _ a23 _ _ _ a24
              with "[Hi HPC Hr_t1 Hr_stk]"); eauto;try addr_succ;
      first apply geta_i; first apply PermFlows_refl;
      first (apply isCorrectPC_bounds with a0 a110; eauto; split; done).
    { iFrame. iFrame. }
    destruct (reg_eq_dec PC r_stk) as [Hcontr | _]; [inversion Hcontr|].
    destruct (reg_eq_dec r_stk r_t1) as [Hcontr | _]; [inversion Hcontr|].
    iNext. iIntros "(HPC & _ & Hr_stk & Hr_t1)"; iSimpl.
    iApply wp_pure_step_later;auto;iNext.
    iDestruct "Hf2" as "[Hi Hf2]".
    iApply (wp_bind (fill [SeqCtx])).
    iApply (wp_add_sub_lt_success _ r_t1 _ _ _ _ a24 _ (inl (z_of a128)) _ (inl 1%Z)
           with "[Hi HPC Hr_t1]"); try addr_succ; eauto; 
      first (left;apply add_r_z_i); first apply PermFlows_refl;
      first (apply isCorrectPC_bounds with a0 a110; eauto; split; done).
    iFrame. iSplit;[eauto|done]. iNext.
    destruct (reg_eq_dec r_t1 PC) as [Hcontr | _]; [inversion Hcontr|].
    destruct (reg_eq_dec r_t1 r_t1); last contradiction.
    rewrite add_r_z_i. assert ((a24 + 1)%a = Some a25) as ->;[addr_succ|]. 
    iIntros "(HPC & _ & _ & _ & Hr_t1)";iSimpl.
    iApply wp_pure_step_later;auto;iNext.
    iDestruct "Hf2" as "[Hi Hf2]".
    iApply (wp_bind (fill [SeqCtx])).
    iApply (wp_GetE_success _ r_t2 _ _ _ _ _ a25 _ _ _ a26
              with "[Hi HPC Hrt2 Hr_stk]"); eauto;try addr_succ;
      first apply gete_i; first apply PermFlows_refl;
      first (apply isCorrectPC_bounds with a0 a110; eauto; split; done).
    iFrame. iFrame. iNext.
    destruct (reg_eq_dec PC r_stk) as [Hcontr | _];[inversion Hcontr|].
    destruct (reg_eq_dec r_stk r_t2) as [Hcontr | _];[inversion Hcontr|].
    iIntros "(HPC & _ & Hr_stk & Hr_t2)"; iSimpl.
    iApply wp_pure_step_later;auto;iNext.
    iDestruct "Hf2" as "[Hi Hf2]".
    iApply (wp_bind (fill [SeqCtx])).
    iApply (wp_subseg_success _ _ _ _ _ a26 a27 _ r_stk r_t1 r_t2
                              RWLX Local a120 a150 a128 129 150 a129 a150
              with "[Hi HPC Hr_stk Hr_t1 Hr_t2]");eauto;try addr_succ;
      first apply subseg_r_r_i; first apply PermFlows_refl;
      first (apply isCorrectPC_bounds with a0 a110; eauto; split; done).
    { assert (110 ≤ MemNum)%Z; [done|].
      assert (100 ≤ MemNum)%Z; [done|].
      rewrite /z_to_addr.
      destruct ( Z_le_dec 109%Z MemNum),(Z_le_dec 100%Z MemNum); try contradiction.
      split;[rewrite /a109|rewrite /a100];
        do 2 f_equal; apply eq_proofs_unicity; decide equality. 
    }
    iFrame.
    (* assert ((a150 =? -42)%a = false) as Ha10042;[done|]; rewrite Ha10042.   *)
    iNext. iIntros "(HPC & _ & Hr_t1 & Hr_t2 & Hr_stk)"; iSimpl.
    iApply wp_pure_step_later; auto;iNext. 
    (* mclear r_stk *)
    assert (list.last (region_addrs_aux a27 22) = Some a48).
    { cbn. cbv. do 2 f_equal. apply eq_proofs_unicity. decide equality. }
    get_genpur_reg "Hr_gen" wsr "[Hrt3 Hr_gen]".
    get_genpur_reg "Hr_gen" wsr "[Hrt4 Hr_gen]".
    get_genpur_reg "Hr_gen" wsr "[Hrt5 Hr_gen]".
    get_genpur_reg "Hr_gen" wsr "[Hrt6 Hr_gen]".
    iDestruct "Hf2" as "[Hi Hf2]".
    iApply (mclear_spec (region_addrs_aux a27 22) r_stk a48 a27 a33 a43
                        pc_p _ pc_g pc_b pc_e RWLX _ Local a129 a150 a128 a151 a49 
              with "[-Hstack]"); try apply PermFlows_refl;
      try addr_succ; try assumption;[|auto|auto| | | |].  
    { intros j ai aj Hai Haj.
      apply (region_addrs_aux_contiguous a27 22 j ai aj); auto.
      done. }
    { split; [cbn; f_equal; by apply addr_unique|].
      split; [addr_succ|cbn; f_equal; by apply addr_unique].  
    }
    { apply isCorrectPC_bounds with a0 a110; eauto; split; done. }
    { apply isCorrectPC_bounds with a0 a110; eauto; split; done. }
    iFrame.
    iSplitL "Hrt4"; [iNext;iExists _;iFrame|].
    iSplitL "Hr_t1"; [iNext;iExists _;iFrame|].
    iSplitL "Hr_t2"; [iNext;iExists _;iFrame|].
    iSplitL "Hrt3"; [iNext;iExists _;iFrame|].
    iSplitL "Hrt5"; [iNext;iExists _;iFrame|].
    iSplitL "Hrt6"; [iNext;iExists _;iFrame|].
    iSplitL "Hstack_adv"; [iNext;iExists _;iFrame|]. 
    iNext. iIntros "(HPC & Hr_t1 & Hr_t2 & Hr_t3 & Hr_t4 & Hr_t5 & Hr_t6
                   & Hr_stk & Hstack_adv & _)".
    iDestruct "Hf2" as "[Hi Hf2]".
    clear H3 Hlength'.
    assert (list.last (region_addrs_aux a49 29) = Some a77).
    { cbn. cbv. do 2 f_equal. apply eq_proofs_unicity. decide equality. }
    iApply (rclear_spec (region_addrs_aux a49 29)
                        (list_difference all_registers [PC; r_stk; r_t0; r_t30])
                        _ _ _ _ _ a49 a77 a78 with "[-]");
      try addr_succ; try assumption; try apply PermFlows_refl; auto. 
    { intros j ai aj Hai Haj.
      apply (region_addrs_aux_contiguous a49 29 j ai aj); eauto.
      done. }
    { apply not_elem_of_list, elem_of_list_here. }
    { split; (apply isCorrectPC_bounds with a0 a110; eauto; split; done). }
    iSplitL "Hr_t1 Hr_t2 Hr_t3 Hr_t4 Hr_t5 Hr_t6 Hr_gen". 
    { iNext. iExists ((repeat (inl 0%Z) 6) ++ wsr); iSimpl. iFrame. }
    iSplitL "HPC";[iFrame|].
    iSplitL "Hi";[iExact "Hi"|].
    iNext. iIntros "(HPC & Hr_gen & _)".
    iPrologue "Hf2".
    iApply (wp_jmp_success _ _ _ _ _ a78 with "[Hi HPC Hr1]");
      first apply jmp_i;first apply PermFlows_refl;
      first (apply isCorrectPC_bounds with a0 a110; eauto; split; done). 
    iFrame. iEpilogue "(HPC & _ & Hr1)"; iSimpl in "HPC".
    (* We have now arrived at the interesting part of the proof: namely the unknown 
       adversary code. In order to reason about unknown code, we must apply the 
       fundamental theorem. To this purpose, we must first define the stsf that will 
       describe the behavior of the memory. *)
    evar (r : gmap RegName Word).
    instantiate (r := <[PC    := inl 0%Z]>
                     (<[r_stk := inr (RWLX, Local, a129, a150, a128)]>
                     (<[r_t0  := inr (E, Local, a120, a150, a121)]>
                     (<[r_t30 := inr (E, Global, b, e, a)]>
                     (create_gmap_default
                (list_difference all_registers [PC; r_stk; r_t0; r_t30]) (inl 0%Z)))))).
    iAssert (interp_expression M r (inr (RX, Global, b, e, a)))
      as (fs' fr') "(-> & -> & Hvalid)". 
    { iApply fundamental. iLeft; auto. iExists RX. iFrame "#". done. }
    (* We have all the resources of r *)
    iAssert (registers_mapsto (<[PC:=inr (RX, Global, b, e, a)]> r))
                          with "[Hr_gen Hr_stk Hrt0 Hr1 HPC]" as "Hmaps".
    { rewrite /r /registers_mapsto (insert_insert _ PC).
      iApply (big_sepM_insert_2 with "[HPC]"); first iFrame.
      iApply (big_sepM_insert_2 with "[Hr_stk]"); first iFrame.
      iApply (big_sepM_insert_2 with "[Hrt0]"); first (rewrite epp_local_e;iFrame).
      iApply (big_sepM_insert_2 with "[Hr1]"); first iFrame.
      assert ((list_difference all_registers [PC; r_stk; r_t0; r_t30]) =
              [r_t1; r_t2; r_t3; r_t4; r_t5; r_t6; r_t7; r_t8; r_t9; r_t10; r_t11; r_t12;
               r_t13; r_t14; r_t15; r_t16; r_t17; r_t18; r_t19; r_t20; r_t21; r_t22; r_t23; r_t24;
               r_t25; r_t26; r_t27; r_t28; r_t29]) as ->; first auto. 
      rewrite /create_gmap_default. iSimpl in "Hr_gen". 
      repeat (iDestruct "Hr_gen" as "[Hr Hr_gen]";
              iApply (big_sepM_insert_2 with "[Hr]"); first iFrame).
      done. 
    }
    (* r contrains all registers *)
    iAssert (full_map r) as "#full".
    { iIntros (r0).
      iPureIntro.
      assert (r0 ∈ all_registers); [apply all_registers_correct|].
      destruct (decide (r0 = PC)); [subst;rewrite lookup_insert; eauto|]. 
      rewrite lookup_insert_ne;auto.
      destruct (decide (r0 = r_stk)); [subst;rewrite lookup_insert; eauto|]. 
      rewrite lookup_insert_ne;auto.
      destruct (decide (r0 = r_t0)); [subst;rewrite lookup_insert; eauto|]. 
      rewrite lookup_insert_ne;auto.
      destruct (decide (r0 = r_t30)); [subst;rewrite lookup_insert; eauto|].
      rewrite lookup_insert_ne;auto.
      assert (¬ r0 ∈ [PC; r_stk; r_t0; r_t30]).
      { repeat (apply not_elem_of_cons; split; auto). apply not_elem_of_nil. }
      exists (inl 0%Z).
      apply create_gmap_default_lookup. apply elem_of_list_difference. auto.
    }
    (* Need to prove the validity of the continuation, the stack, as well as put
       local memory into invariant. *)
    iMod (inv_alloc
            (nroot.@"Hprog")
            _
            (a79 ↦ₐ[pc_p] sub_z_z r_t1 0 7
            ∗ a80 ↦ₐ[pc_p] lea_r r_stk r_t1
              ∗ a81 ↦ₐ[pc_p] load_r r_t30 r_stk
                ∗ a82 ↦ₐ[pc_p] sub_z_z r_t1 0 1
                  ∗ a83 ↦ₐ[pc_p] lea_r r_stk r_t1
                    ∗ a84 ↦ₐ[pc_p] move_r r_t1 PC
                      ∗ a85 ↦ₐ[pc_p] lea_z r_t1 5
                        ∗ a86 ↦ₐ[pc_p] sub_r_z r_t30 r_t30 1
                          ∗ a87 ↦ₐ[pc_p] jnz r_t1 r_t30
                            ∗ a88 ↦ₐ[pc_p] halt
                              ∗ a89 ↦ₐ[pc_p] move_r r_t1 PC ∗ a90 ↦ₐ[pc_p] lea_z r_t1 4 ∗ a91 ↦ₐ[pc_p] store_z r_t1 1 ∗ a92 ↦ₐ[pc_p] halt)
            with "[Hprog]")%I as "#Hprog".
    { iNext; iFrame. }
    iMod (na_inv_alloc logrel_nais ⊤ (logN.@(a120, a150))
                        (a120 ↦ₐ[RWLX] inl 1%Z
                       ∗ a121 ↦ₐ[RWLX] inl w_1
                       ∗ a122 ↦ₐ[RWLX] inl w_2
                       ∗ a123 ↦ₐ[RWLX] inl w_3
                       ∗ a124 ↦ₐ[RWLX] inl w_4a
                       ∗ a125 ↦ₐ[RWLX] inl w_4b
                       ∗ a126 ↦ₐ[RWLX] inl w_4c
                       ∗ a127 ↦ₐ[RWLX] inr (pc_p, pc_g, pc_b, pc_e, a78)
                       ∗ a128 ↦ₐ[RWLX] inr (RWLX, Local, a120, a150, a128))%I with "[-Hφ Hs Hstack_adv Hvalid Hmaps Hna Hflag]")
      as "#Hlocal".
    { iNext. iFrame. }
    iAssert (|={⊤}=> ([∗ list] a0 ∈ region_addrs a129 a150,
                     read_write_cond a0 RWLX (fixpoint interp1)))%I
                                           with "[Hstack_adv]" as ">#Hstack_adv". 
    { iApply region_addrs_zeroes_valid. done. }
    iAssert (∀ r1 : RegName, ⌜r1 ≠ PC⌝ → (fixpoint interp1) (r !r! r1))%I
      with "[-Hs Hmaps Hvalid Hna Hφ Hflag]" as "Hreg".
    { iIntros (r1).
      assert (r1 = PC ∨ r1 = r_stk ∨ r1 = r_t0 ∨ r1 = r_t30 ∨ (r1 ≠ PC ∧ r1 ≠ r_stk ∧ r1 ≠ r_t0 ∧ r1 ≠ r_t30)).
      { destruct (decide (r1 = PC)); [by left|right].
        destruct (decide (r1 = r_stk)); [by left|right].
        destruct (decide (r1 = r_t0)); [by left|right].
        destruct (decide (r1 = r_t30)); [by left|right;auto].  
      }
      destruct H5 as [-> | [-> | [-> | [Hr_t30 | [Hnpc [Hnr_stk [Hnr_t0 Hnr_t30] ] ] ] ] ] ].
      - iIntros "%". contradiction.
      - (* invariant for the stack of the adversary *)
        assert (r !! r_stk = Some (inr (RWLX, Local, a129, a150, a128))) as Hr_stk; auto. 
        rewrite /RegLocate Hr_stk fixpoint_interp1_eq. iSimpl. 
        iIntros (_). iExists _,_,_,_. (iSplitR; [eauto|]).
        iExists RWLX. iSplitR; [auto|]. iFrame "#". 
        iAlways.
        rewrite /exec_cond.
        iIntros (a0 W r' Ha0). iNext.
        iApply fundamental.
        + iRight. iRight. done.
        + iExists RWLX. iSplit; auto. 
      - (* continuation *)
        iIntros (_). 
        assert (r !! r_t0 = Some (inr (E, Local, a120, a150, a121))) as Hr_t0; auto. 
        rewrite /RegLocate Hr_t0 fixpoint_interp1_eq. iSimpl. 
        (* prove continuation *)
        iExists _,_,_,_. iSplit;[eauto|].
        iAlways.
        rewrite /enter_cond. 
        iIntros (W r').
        destruct W as [fs' fr' ].
        iNext. iSimpl. 
        iExists _,_. do 2 (iSplit; [eauto|]).
        iIntros "(#[Hfull' Hreg'] & Hmreg' & _ & Hs & Hna)". 
        iExists _,_,_,_,_. iSplit; [eauto|rewrite /interp_conf].
        (* get the PC, currently pointing to the activation record *)
        iDestruct (big_sepM_delete _ _ PC with "Hmreg'") as "[HPC Hmreg']".
        { rewrite lookup_insert; eauto. }
        (* get a general purpose register *)
        iAssert (⌜∃ wr_t1, r' !! r_t1 = Some wr_t1⌝)%I as %[rt1w Hrt1];
          first iApply "Hfull'".
        iDestruct (big_sepM_delete _ _ r_t1 with "Hmreg'") as "[Hr_t1 Hmreg']".
        { rewrite lookup_delete_ne; auto.
          rewrite lookup_insert_ne; eauto. }
        (* get r_stk *)
        iAssert (⌜∃ wr_stk, r' !! r_stk = Some wr_stk⌝)%I as %[rstkw Hrstk];
          first iApply "Hfull'".
        iDestruct (big_sepM_delete _ _ r_stk with "Hmreg'") as "[Hr_stk Hmreg']".
        { do 2 (rewrite lookup_delete_ne; auto).
          rewrite lookup_insert_ne; eauto. }
        (* get r_t30 *)
        iAssert (⌜∃ wr30, r' !! r_t30 = Some wr30⌝)%I as %[wr30 Hr30];
          first iApply "Hfull'".
        iDestruct (big_sepM_delete _ _ r_t30 with "Hmreg'") as "[Hr_t30 Hmreg']".
        { do 3 (rewrite lookup_delete_ne; auto).
          rewrite lookup_insert_ne; eauto. }
        (* open the na invariant for the local stack content *)
        iMod (na_inv_open logrel_nais ⊤ ⊤ (logN.@(a120,a150)) with "Hlocal Hna")
          as "(>(Ha120 & Ha121 & Ha122 & Ha123 & Ha124 & Ha125 & Ha126 & Ha127 & Ha128) 
          & Hna & Hcls)"; auto.
        assert (PermFlows RX RWLX) as Hrx;[by rewrite /PermFlows /=|]. 
        (* step through instructions in activation record *)
        (* move rt_1 PC *)
        iApply (wp_bind (fill [SeqCtx])).
        iApply (wp_move_success_reg_fromPC _ RX Local a120 a150 a121 a122 (inl w_1)
               with "[HPC Ha121 Hr_t1]");
          [rewrite -i_1; apply decode_encode_inv|eauto
           |constructor; auto; split; done|
           addr_succ|
           auto|iFrame|]. 
        iEpilogue "(HPC & Ha121 & Hr_t1)".
        (* lea r_t1 7 *)
        iApply (wp_bind (fill [SeqCtx])).
        iApply (wp_lea_success_z _ RX Local a120 a150 a122 a123 (inl w_2)
                                 _ RX _ _ _ a121 7 a128 with "[HPC Ha122 Hr_t1]");
          try addr_succ;
          first (rewrite -i_2; apply decode_encode_inv);
          [eauto|(constructor; auto; split; done); auto|auto|auto|iFrame|].
        iEpilogue "(HPC & Ha122 & Hr_t1)".
        (* load r_stk r_t1 *)
        iApply (wp_bind (fill [SeqCtx])).
        iApply (wp_load_success _ _ _ RX Local a120 a150 a123 (inl w_3) _ _ RX Local a120 a150 a128 a124
                  with "[HPC Ha128 Hr_t1 Hr_stk Ha123]");
         try addr_succ;
         first (rewrite -i_3; apply decode_encode_inv);
         [eauto|eauto|(constructor; auto; split; done)|auto|auto|iFrame|].
        iEpilogue "(HPC & Hr_stk & Ha123 & Hr_t1 & Ha128)".
        (* sub r_t1 0 1 *)
        destruct (a128 =? a123)%a eqn:Hcontr;[inversion Hcontr|clear Hcontr].
        iApply (wp_bind (fill [SeqCtx])).
        iApply (wp_add_sub_lt_success _ r_t1 _ _ a120 a150 a124 (inl w_4a)
                  with "[HPC Hr_t1 Ha124]");
          try addr_succ;
          first (right; left; rewrite -i_4a; apply decode_encode_inv);
          [apply Hrx|constructor; auto; split; done| | ]. 
        iFrame. iSplit; auto.
        destruct (reg_eq_dec r_t1 PC) eqn:Hcontr;[inversion Hcontr|clear Hcontr].
        assert ((a124 + 1)%a = Some a125) as ->; [addr_succ|].
        rewrite -i_4a decode_encode_inv.
        iEpilogue "(HPC & Ha124 & _ & _ & Hr_t1)".
        (* Lea r_stk r_t1 *)
        iApply (wp_bind (fill [SeqCtx])).
        iApply (wp_lea_success_reg _ RX Local a120 a150 a125 a126 (inl w_4b) _ _ RWLX Local a120 a150 a128 (-1) a127
                  with "[HPC Hr_t1 Hr_stk Ha125]");
          try addr_succ;
          first (rewrite -i_4b; apply decode_encode_inv); first apply Hrx; 
          first (constructor; auto; split; done); auto.
        iFrame. iEpilogue "(HPC & Ha125 & Hr_t1 & Hr_stk)".
        (* Load PC r_t1 *)
        iApply (wp_bind (fill [SeqCtx])).
        iApply (wp_load_success_PC _ r_stk RX Local a120 a150 a126 (inl w_4c) RWLX Local a120 a150 a127
                                   _ _ _ _ a78 a79
                  with "[HPC Hr_stk Ha126 Ha127]");
          try addr_succ;
          first (rewrite -i_4c; apply decode_encode_inv);
          first apply Hrx; first apply PermFlows_refl;
          first (constructor; auto; split; done); auto.
        iFrame. iEpilogue "(HPC & Ha126 & Hr_stk & Ha127)".
        (* we don't want to close the stack invariant yet, as we will now need to pop it *)
        (* iMod ("Hcls" with "[$Ha120 $Ha121 $Ha122 $Ha123 $Ha124 $Ha125 $Ha126 $Ha127 $Ha128 $Hna]") as "Hna". *)
        (* go through rest of the program. We will now need to open the invariant one instruction at a time *)
        (* sub r_t1 0 7 *)
        iApply (wp_bind (fill [SeqCtx])). 
        iInv (nroot.@"Hprog") as "[>Ha79 Hprog_rest]" "Hcls'".
        iApply (wp_add_sub_lt_success _ r_t1 _ _ _ _ a79
                  with "[HPC Hr_t1 Ha79]");
          first (right; left; apply sub_z_z_i); first apply PermFlows_refl;
          first (apply isCorrectPC_bounds with a0 a110; eauto; split; done); auto. 
        iFrame. iSplit; auto. iNext.
        destruct (reg_eq_dec r_t1 PC) eqn:Hcontr;[inversion Hcontr|clear Hcontr].
        assert ((a79 + 1)%a = Some a80) as ->; [addr_succ|].
        rewrite sub_z_z_i.
        iIntros "(HPC & Ha79 & _ & _ & Hr_t1)".
        iMod ("Hcls'" with "[$Ha79 $Hprog_rest]") as "_".
        iModIntro;iApply wp_pure_step_later;auto;iNext.
        (* lea r_stk r_t1 *)
        iApply (wp_bind (fill [SeqCtx])). 
        iInv (nroot.@"Hprog") as "(Ha79 & >Ha80 & Hprog_rest)" "Hcls'".
        iApply (wp_lea_success_reg _ _ _ _ _ a80 a81 _ r_stk r_t1 RWLX _ _ _ a127 (-7)%Z a120
                  with "[HPC Hr_t1 Hr_stk Ha80]");
          try addr_succ;
          first apply lea_r_i; first apply PermFlows_refl;
          first (apply isCorrectPC_bounds with a0 a110; eauto; split; done); auto. 
        iFrame. iNext. iIntros "(HPC & Ha80 & Hr_t1 & Hr_stk)".
        iMod ("Hcls'" with "[$Ha79 $Ha80 $Hprog_rest]") as "_".
        iModIntro;iApply wp_pure_step_later;auto;iNext.
        (* load r_t30 r_stk *)
        iApply (wp_bind (fill [SeqCtx])). 
        iInv (nroot.@"Hprog") as "(Ha79 & Ha80 & >Ha81 & Hprog_rest)" "Hcls'".
        iApply (wp_load_success _ r_t30 _ _ _ _ _ a81 _ _ _ RWLX Local a120 a150 a120 a82
                  with "[HPC Ha81 Ha120 Hr_t30 Hr_stk]");
          try addr_succ;
          first apply load_r_i; try apply PermFlows_refl; 
          first (apply isCorrectPC_bounds with a0 a110; eauto; split; done); auto.
        iFrame. iNext. iIntros "(HPC & Hr_t30 & Ha81 & Hr_stk & Ha120)"; iSimpl.  
        iMod ("Hcls'" with "[$Ha79 $Ha80 $Ha81 $Hprog_rest]") as "_".
        iModIntro;iApply wp_pure_step_later;auto;iNext.
        (* we will not use the local stack anymore, so we may close the na_inv *)
        iMod ("Hcls" with "[$Ha120 $Ha121 $Ha122 $Ha123 $Ha124 $Ha125 $Ha126 $Ha127 $Ha128 $Hna]") as "Hna".
        (* we will now make the assertion that r_t30 points to 1 *)
        (* sub r_t1 0 1 *)
        iApply (wp_bind (fill [SeqCtx])). 
        iInv (nroot.@"Hprog") as "(Ha79 & Ha80 & Ha81 & >Ha82 & Hprog_rest)" "Hcls'".
        iApply (wp_add_sub_lt_success _ r_t1 _ _ _ _ a82
                  with "[HPC Hr_t1 Ha82]");
          first (right; left; apply sub_z_z_i); first apply PermFlows_refl;
          first (apply isCorrectPC_bounds with a0 a110; eauto; split; done); auto. 
        iFrame. iSplit; eauto. iNext.
        destruct (reg_eq_dec r_t1 PC) eqn:Hcontr;[inversion Hcontr|clear Hcontr].
        assert ((a82 + 1)%a = Some a83) as ->; [addr_succ|].
        rewrite sub_z_z_i.
        iIntros "(HPC & Ha82 & _ & _ & Hr_t1)".
        iMod ("Hcls'" with "[$Ha79 $Ha80 $Ha81 $Ha82 $Hprog_rest]") as "_".
        iModIntro;iApply wp_pure_step_later;auto;iNext.
        (* lea r_stk r_t1 *)
        iApply (wp_bind (fill [SeqCtx])). 
        iInv (nroot.@"Hprog") as "(Ha79 & Ha80 & Ha81 & Ha82 & >Ha83 & Hprog_rest)" "Hcls'".
        iApply (wp_lea_success_reg _ _ _ _ _ a83 a84 _ r_stk r_t1 RWLX _ _ _ a120 (-1)%Z a119
                  with "[HPC Hr_t1 Hr_stk Ha83]");
          try addr_succ;
          first apply lea_r_i; first apply PermFlows_refl;
          first (apply isCorrectPC_bounds with a0 a110; eauto; split; done); auto. 
        iFrame. iNext. iIntros "(HPC & Ha83 & Hr_t1 & Hr_stk)".
        iMod ("Hcls'" with "[$Ha79 $Ha80 $Ha81 $Ha82 $Ha83 $Hprog_rest]") as "_".
        iModIntro;iApply wp_pure_step_later;auto;iNext.
        (* move r_t1 PC *)
        iApply (wp_bind (fill [SeqCtx])). 
        iInv (nroot.@"Hprog") as "(Ha79 & Ha80 & Ha81 & Ha82 & Ha83 & >Ha84 & Hprog_rest)" "Hcls'".
        iApply (wp_move_success_reg_fromPC _ _ _ _ _ a84 a85 _ r_t1
                  with "[HPC Hr_t1 Ha84]");
          try addr_succ;
          first apply move_r_i; first apply PermFlows_refl;
          first (apply isCorrectPC_bounds with a0 a110; eauto; split; done); auto. 
        iFrame. iNext. iIntros "(HPC & Ha84 & Hr_t1)".
        iMod ("Hcls'" with "[$Ha79 $Ha80 $Ha81 $Ha82 $Ha83 $Ha84 $Hprog_rest]") as "_".
        iModIntro;iApply wp_pure_step_later;auto;iNext.
        (* lea r_t1 5 *)
        iApply (wp_bind (fill [SeqCtx])). 
        iInv (nroot.@"Hprog") as "(Ha79 & Ha80 & Ha81 & Ha82 & Ha83 & Ha84 & >Ha85 & Hprog_rest)" "Hcls'".
        iApply (wp_lea_success_z _ _ _ _ _ a85 a86 _ r_t1 pc_p _ _ _ a84 5 a89
               with "[HPC Ha85 Hr_t1]");
          try addr_succ;
          first apply lea_z_i; first apply PermFlows_refl;
          first (apply isCorrectPC_bounds with a0 a110; eauto; split; done); first auto. 
        { inversion Hvpc0 as [?????? Hpc_p | ????? Hpc_p];
            destruct Hpc_p as [Hpc_p | [Hpc_p | Hpc_p] ]; congruence. }
        iFrame. iNext. iIntros "(HPC & Ha85 & Hr_t1)".
        iMod ("Hcls'" with "[$Ha79 $Ha80 $Ha81 $Ha82 $Ha83 $Ha84 $Ha85 $Hprog_rest]") as "_".
        iModIntro;iApply wp_pure_step_later;auto;iNext.
        (* sub r_t30 r_t30 1 *)
        iApply (wp_bind (fill [SeqCtx])). 
        iInv (nroot.@"Hprog") as "(Ha79 & Ha80 & Ha81 & Ha82 & Ha83 & Ha84 & Ha85 & >Ha86 & Hprog_rest)" "Hcls'".
        iApply (wp_add_sub_lt_success _ r_t30 _ _ _ _ a86
                  with "[HPC Ha86 Hr_t30]"); 
          first (right;left;apply sub_r_z_i); first apply PermFlows_refl;
          first (apply isCorrectPC_bounds with a0 a110; eauto; split; done); auto. 
        iFrame. iSplit; auto. iNext.
        destruct (reg_eq_dec r_t30 PC) eqn:Hcontr; [inversion Hcontr|clear Hcontr].
        assert ((a86 + 1)%a = Some a87) as ->;[addr_succ|].
        destruct (reg_eq_dec r_t30 r_t30) eqn:Hcontr;[clear Hcontr| inversion Hcontr].
        rewrite sub_r_z_i. 
        iIntros "(HPC & Ha86 & _ & _ & Hr_t30 )".
        iMod ("Hcls'" with "[$Ha79 $Ha80 $Ha81 $Ha82 $Ha83 $Ha84 $Ha85 $ Ha86 $Hprog_rest]") as "_".
        iModIntro;iApply wp_pure_step_later;auto;iNext.
        (* jnz r_t1 r_t30 *)
        iApply (wp_bind (fill [SeqCtx])). 
        iInv (nroot.@"Hprog") as "(Ha79 & Ha80 & Ha81 & Ha82 & Ha83 & Ha84 & Ha85 & Ha86 & >Ha87 
        & Hprog_rest)" "Hcls'".
        iApply (wp_jnz_success_next _ r_t1 r_t30 _ _ _ _ a87 a88
                  with "[HPC Ha87 Hr_t30]");
          try addr_succ;
          first apply jnz_i; first apply PermFlows_refl;
          first (apply isCorrectPC_bounds with a0 a110; eauto; split; done).
        iFrame. iNext. iIntros "(HPC & Ha87 & Hr_t30)".
        iMod ("Hcls'" with "[$Ha79 $Ha80 $Ha81 $Ha82 $Ha83 $Ha84 $Ha85 $Ha86 $Ha87 $Hprog_rest]") as "_".
        iModIntro;iApply wp_pure_step_later;auto;iNext.
        (* halt *)
        iApply (wp_bind (fill [SeqCtx])). 
        iInv (nroot.@"Hprog") as "(Ha79 & Ha80 & Ha81 & Ha82 & Ha83 & Ha84 & Ha85 & Ha86 & Ha87 & >Ha88
        & Hprog_rest)" "Hcls'".
        iApply (wp_halt _ _ _ _ _ a88 with "[HPC Ha88]");
          first apply halt_i; first apply PermFlows_refl; 
          first (apply isCorrectPC_bounds with a0 a110; eauto; split; done).
        iFrame. iNext. iIntros "(HPC & Ha88)".
        iMod ("Hcls'" with "[$Ha79 $Ha80 $Ha81 $Ha82 $Ha83 $Ha84 $Ha85 $Ha86 $Ha87 $Ha88 $Hprog_rest]") as "_".
        iModIntro;iApply wp_pure_step_later;auto;iNext.
        (* halted: need to show post condition *)
        iApply wp_value. iIntros "_".
        evar (r'' : gmap RegName Word).
        instantiate (r'' := <[PC    := inr (pc_p, pc_g, pc_b, pc_e, a88)]>
                           (<[r_t1  := inr (pc_p, pc_g, pc_b, pc_e, a89)]>
                           (<[r_t30 := inl 0%Z]>
                           (<[r_stk := inr (RWLX, Local, a120, a150, a119)]> r')))). 
        iExists r'',fs',fr'.
        iFrame. iSplit;[|iSplit].
        + iDestruct "Hfull'" as %Hfull'.
          iPureIntro.
          intros r0. rewrite /r''.
          destruct (decide (PC = r0));first subst. 
          { rewrite lookup_insert. eauto. }
          rewrite lookup_insert_ne; auto. 
          destruct (decide (r_t1 = r0));first subst. 
          { rewrite lookup_insert. eauto. }
          rewrite lookup_insert_ne; auto. 
          destruct (decide (r_t30 = r0));first subst. 
          { rewrite lookup_insert. eauto. }
          rewrite lookup_insert_ne; auto. 
          destruct (decide (r_stk = r0));first subst. 
          { rewrite lookup_insert. eauto. }
          rewrite lookup_insert_ne; auto.
        + rewrite /r''.
          iDestruct (big_sepM_delete (λ x y, x ↦ᵣ y)%I r'' PC
                       with "[-]") as "Hmreg'"; auto.
          { by rewrite lookup_insert. }
          iFrame. do 2 rewrite delete_insert_delete.
          iDestruct (big_sepM_delete (λ x y, x ↦ᵣ y)%I
                        (delete PC (<[r_t1:=inr (pc_p, pc_g, pc_b, pc_e, a89)]>
                         (<[r_t30:=inl 0%Z]>
                          (<[r_stk:=inr (RWLX, Local, a120, a150, a119)]> r')))) r_t1
                       with "[-]") as "Hmreg'"; auto.
          { rewrite lookup_delete_ne; auto. by rewrite lookup_insert. }
          iFrame. do 2 rewrite (delete_commute _ r_t1 PC).
          rewrite delete_insert_delete.
          do 2 rewrite (delete_commute _ PC r_t1).
          iDestruct (big_sepM_delete (λ x y, x ↦ᵣ y)%I
                        (delete r_t1 (delete PC
                            (<[r_t30:=inl 0%Z]>
                             (<[r_stk:=inr (RWLX, Local, a120, a150, a119)]> r')))) r_stk
                       with "[-]") as "Hmreg'"; auto.
          { repeat (rewrite lookup_delete_ne; auto).
            rewrite lookup_insert_ne; auto. by rewrite lookup_insert. }
          iFrame. repeat rewrite (delete_commute _ r_stk _).
          rewrite insert_commute; auto. 
          rewrite delete_insert_delete; auto. 
          iDestruct (big_sepM_delete (λ x y, x ↦ᵣ y)%I
                  (delete r_t1 (delete PC (delete r_stk (<[r_t30:=inl 0%Z]> r')))) r_t30
                       with "[-]") as "Hmreg'"; auto.
          { repeat (rewrite lookup_delete_ne; auto). by rewrite lookup_insert. }
          iFrame. repeat rewrite (delete_commute _ r_t30 _).  
          rewrite delete_insert_delete. iFrame. 
        + iPureIntro. apply related_sts_priv_refl. 
      - rewrite Hr_t30. 
        assert (r !! r_t30 = Some (inr (E, Global, b, e, a))) as Hr_t30_some; auto. 
        rewrite /RegLocate Hr_t30_some fixpoint_interp1_eq. iSimpl. 
        iIntros (_). 
        iExists _,_,_,_. iSplit; [eauto|].
        iIntros (E' r').
        iAlways. rewrite /enter_cond.
        iNext. iApply fundamental.
        iLeft. done.
        iExists RX. iSplit; auto. 
      - (* in this case we can infer that r1 points to 0, since it is in the list diff *)
        assert (r !r! r1 = inl 0%Z) as Hr1.
        { rewrite /RegLocate.
          destruct (r !! r1) eqn:Hsome; rewrite Hsome; last done.
          do 4 (rewrite lookup_insert_ne in Hsome;auto).
          assert (Some w = Some (inl 0%Z)) as Heq.
          { rewrite -Hsome. apply create_gmap_default_lookup.
            apply elem_of_list_difference. split; first apply all_registers_correct.
            repeat (apply not_elem_of_cons;split;auto).
            apply not_elem_of_nil. 
          }
          by inversion Heq. 
        }
        rewrite Hr1 fixpoint_interp1_eq. iPureIntro. eauto.         
    }
    iAssert (((interp_reg interp) r))%I as "#HvalR";[iSimpl;auto|].
    iSpecialize ("Hvalid" with "[HvalR Hmaps Hs Hna]").
    { iDestruct "Hs" as "[Hs Hex]". iFrame "∗ #". } 
    iDestruct "Hvalid" as (p' g b0 e1 a0 Heq) "Ho". 
    inversion Heq; subst. rewrite /interp_conf.
    iApply wp_wand_r. iFrame.
    iIntros (v) "Htest".
    iApply "Hφ". 
    iIntros "_"; iFrame. Unshelve. eauto. 
  Qed. 


End lse.

 