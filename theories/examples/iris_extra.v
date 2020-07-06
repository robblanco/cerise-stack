From iris.algebra Require Import frac.
From iris.proofmode Require Import tactics.
From iris.base_logic Require Import invariants.

Lemma big_sepM_to_big_sepL {Σ : gFunctors} {A B : Type} `{EqDecision A} `{Countable A}
      (r : gmap A B) (lr : list A) (φ : A → B → iProp Σ) :
  NoDup lr →
  (∀ r0, r0 ∈ lr → ∃ b, r !! r0 = Some b) →
  ([∗ map] k↦y ∈ r, φ k y) -∗ ([∗ list] y ∈ lr, ∃ b, φ y b).
Proof.
  iInduction (lr) as [ | r0 ] "IHl" forall (r); iIntros (Hdup Hlookup) "Hmap".
  - done.
  - assert (∃ b, r !! r0 = Some b) as [b Hr0].
    { apply Hlookup. apply elem_of_cons. by left. } 
    iDestruct (big_sepM_delete _ _ r0 with "Hmap") as "[Hr0 Hmap]"; eauto.
    iSplitL "Hr0".
    + iExists b. iFrame. 
    + iApply ("IHl" with "[] [] [$Hmap]").
      { iPureIntro. apply NoDup_cons_12 in Hdup. auto. }
      iPureIntro.
      intros r1 Hr1.
      destruct (decide (r0 = r1)).
      * subst. apply NoDup_cons in Hdup as [Hnelem Hdup]. contradiction. 
      * rewrite lookup_delete_ne;auto. apply Hlookup.
        apply elem_of_cons. by right.
Qed.

Lemma NoDup_of_sepL2_exclusive {Σ : gFunctors} {A B: Type} (l1: list A) (l2: list B) (Φ: A -> B -> iProp Σ):
  (∀ a x1 x2, Φ a x1 -∗ Φ a x2 -∗ False) -∗
  ([∗ list] a;x ∈ l1;l2, Φ a x) -∗
  ⌜NoDup l1⌝.
Proof.
  revert l2. induction l1 as [| a1' l1].
  { iIntros (?) "_ _". iPureIntro. constructor. }
  { iIntros (l2) "HΦ H". destruct l2 as [| a2' l2]; [done|]. cbn. iDestruct "H" as "[Ha1 H]".
    iDestruct (IHl1 with "HΦ H") as %?.
    iAssert (⌜a1' ∉ l1⌝)%I as %?.
    { iIntros (Hin). destruct (elem_of_list_lookup_1 _ _ Hin) as [k ?].
      iDestruct (big_sepL2_length with "H") as %Hlen12.
      destruct (lookup_lt_is_Some_2 l2 k).
      { rewrite -Hlen12 -lookup_lt_is_Some; eauto. }
      iDestruct (big_sepL2_lookup with "H") as "Ha1'"; eauto.
      iApply ("HΦ" with "Ha1 Ha1'"). }
    iPureIntro. by constructor. }
Qed.

Lemma big_sepL2_extract_l `{Σ : gFunctors} {A B : Type}
      (i : nat) (ai : A) (a : list A) (b : list B) (φ : A -> B -> iProp Σ) :
  a !! i = Some ai ->
  (([∗ list] a_i;b_i ∈ a;b, φ a_i b_i) -∗
    (∃ b', [∗ list] a_i;b_i ∈ (delete i a);b', φ a_i b_i) ∗ ∃ b, φ ai b)%I.
Proof. 
  iIntros (Hsome) "Hl".
  iDestruct (big_sepL2_length with "Hl") as %Hlength.      
  assert (take i a ++ drop i a = a) as Heqa;[apply take_drop|]. 
  assert (take i b ++ drop i b = b) as Heqb;[apply take_drop|]. 
  rewrite -Heqa -Heqb.
  iDestruct (big_sepL2_app_inv with "Hl") as "[Htake Hdrop]". 
  { apply lookup_lt_Some in Hsome.
    do 2 (rewrite take_length_le;[|lia]). done. 
  }
  apply take_drop_middle in Hsome as Hcons.
  assert (ai :: drop (S i) a = drop i a) as Hh.
  { apply app_inv_head with (take i a). congruence. }
  rewrite -Hh.
  iDestruct (big_sepL2_length with "Hdrop") as %Hlength'.      
  destruct (drop i b);[inversion Hlength'|].
  iDestruct "Hdrop" as "[Hφ Hdrop]".
  iSplitR "Hφ";[|eauto].
  iExists (take i b ++ l). rewrite Hcons. 
  iDestruct (big_sepL2_app with "Htake Hdrop") as "Hl". 
  rewrite delete_take_drop. iFrame.
Qed.

Lemma region_addrs_exists `{Σ : gFunctors} {A B: Type} (a : list A) (φ : A → B → iProp Σ) :
     (([∗ list] a0 ∈ a, (∃ b0, φ a0 b0)) ∗-∗
      (∃ (ws : list B), [∗ list] a0;b0 ∈ a;ws, φ a0 b0))%I.
Proof.
  iSplit. 
  - iIntros "Ha".
    iInduction (a) as [ | a0] "IHn". 
    + iExists []. done.
    + iDestruct "Ha" as "[Ha0 Ha]".
      iDestruct "Ha0" as (w0) "Ha0". 
      iDestruct ("IHn" with "Ha") as (ws) "Ha'".
      iExists (w0 :: ws). iFrame.
  - iIntros "Ha".
    iInduction (a) as [ | a0] "IHn". 
    + done. 
    + iDestruct "Ha" as (ws) "Ha".
      destruct ws;[by iApply bi.False_elim|]. 
      iDestruct "Ha" as "[Ha0 Ha]". 
      iDestruct ("IHn" with "[Ha]") as "Ha'"; eauto. 
      iFrame. eauto.        
Qed.

Lemma region_addrs_exists_zip `{Σ : gFunctors} {A B C: Type} (a : list A) (φ : A → B → C -> iProp Σ) :
  (([∗ list] a0 ∈ a, (∃ b0 c0, φ a0 b0 c0)) ∗-∗
                                            (∃ (ws : list (B * C)), [∗ list] a0;bc0 ∈ a;ws, φ a0 bc0.1 bc0.2))%I.
Proof.
  iSplit. 
  - iIntros "Ha".
    iInduction (a) as [ | a0] "IHn". 
    + iExists []. done.
    + iDestruct "Ha" as "[Ha0 Ha]".
      iDestruct "Ha0" as (w0 p0) "Ha0". 
      iDestruct ("IHn" with "Ha") as (ws) "Ha'".
      iExists ((w0,p0) :: ws). iFrame.
  - iIntros "Ha".
    iInduction (a) as [ | a0] "IHn". 
    + done. 
    + iDestruct "Ha" as (ws) "Ha".
      destruct ws;[by iApply bi.False_elim|]. 
      iDestruct "Ha" as "[Ha0 Ha]". 
      iDestruct ("IHn" with "[Ha]") as "Ha'"; eauto. 
      iFrame. eauto.        
Qed.

Lemma region_addrs_exists2 `{Σ : gFunctors} {A B C: Type} (a : list A) (b : list B) (φ : A → B → C -> iProp Σ) :
     (([∗ list] a0;b0 ∈ a;b, (∃ c0, φ a0 b0 c0)) ∗-∗
      (∃ (ws : list C), ⌜length ws = length b⌝ ∗ [∗ list] a0;bc0 ∈ a;(zip b ws), φ a0 bc0.1 bc0.2))%I.
Proof.
  iSplit. 
  - iIntros "Ha".
    iInduction (a) as [ | a0] "IHn" forall (b). 
    + iExists []. iDestruct (big_sepL2_length with "Ha") as %Hlength. 
      destruct b;inversion Hlength. iSplit;auto. 
    + iDestruct (big_sepL2_length with "Ha") as %Hlength.
      destruct b; [inversion Hlength|]. 
      iDestruct "Ha" as "[Ha0 Ha]".
      iDestruct "Ha0" as (w0) "Ha0". 
      iDestruct ("IHn" with "Ha") as (ws Hlen) "Ha'".
      iExists (w0 :: ws). simpl. iSplit;auto. iFrame. 
   - iIntros "Ha".
     iInduction (a) as [ | a0] "IHn" forall (b). 
     + iDestruct "Ha" as (ws Hlen) "Ha". 
       iDestruct (big_sepL2_length with "Ha") as %Hlength. destruct b,ws;inversion Hlength; done. 
     + iDestruct "Ha" as (ws Hlen) "Ha".
       destruct ws,b;try by iApply bi.False_elim. simpl. 
       iDestruct "Ha" as "[Ha0 Ha]". iDestruct (big_sepL2_length with "Ha") as %Hlength.
       iDestruct ("IHn" with "[Ha]") as "Ha'"; iFrame; eauto. 
Qed.

Lemma big_sepL2_to_big_sepL_r `{Σ : gFunctors} {A B : Type} (φ : B → iProp Σ) (l1 : list A) l2 :
  length l1 = length l2 →
  (([∗ list] _;y2 ∈ l1;l2, φ y2) ∗-∗
                                 ([∗ list] y ∈ l2, φ y))%I. 
Proof.
  iIntros (Hlen). 
  iSplit. 
  - iIntros "Hl2". iRevert (Hlen). 
    iInduction (l2) as [ | y2] "IHn" forall (l1); iIntros (Hlen). 
    + done.
    + destruct l1;[by iApply bi.False_elim|]. 
      iDestruct "Hl2" as "[$ Hl2]". 
      iApply ("IHn" with "Hl2"). auto. 
  - iIntros "Hl2". 
    iRevert (Hlen). 
    iInduction (l2) as [ | y2] "IHn" forall (l1); iIntros (Hlen). 
    + destruct l1; inversion Hlen. done.
    + iDestruct "Hl2" as "[Hy2 Hl2]".
      destruct l1; inversion Hlen. 
      iDestruct ("IHn" $! l1 with "Hl2") as "Hl2".
      iFrame. iApply "Hl2". auto. 
Qed.

   Lemma big_sepL2_to_big_sepL_l `{Σ : gFunctors} {A B : Type} (φ : A → iProp Σ) (l1 : list A)
         (l2 : list B) :
     length l1 = length l2 →
     (([∗ list] y1;_ ∈ l1;l2, φ y1) ∗-∗
     ([∗ list] y ∈ l1, φ y))%I. 
   Proof.
     iIntros (Hlen). 
     iSplit. 
     - iIntros "Hl2". iRevert (Hlen). 
       iInduction (l1) as [ | y1] "IHn" forall (l2); iIntros (Hlen). 
       + done.
       + destruct l2;[by iApply bi.False_elim|]. 
         iDestruct "Hl2" as "[$ Hl2]". 
         iApply ("IHn" with "Hl2"). auto. 
     - iIntros "Hl2". 
       iRevert (Hlen). 
       iInduction (l1) as [ | y1] "IHn" forall (l2); iIntros (Hlen). 
       + destruct l2; inversion Hlen. done.
       + iDestruct "Hl2" as "[Hy2 Hl2]".
         destruct l2; inversion Hlen. 
         iDestruct ("IHn" $! l2 with "Hl2") as "Hl2".
         iFrame. iApply "Hl2". auto. 
   Qed.

   Lemma big_sepL2_app'
         (PROP : bi) (A B : Type) (Φ : nat → A → B → PROP) (l1 l2 : list A)
         (l1' l2' : list B) :
     (length l1) = (length l1') →
     (([∗ list] k↦y1;y2 ∈ l1;l1', Φ k y1 y2)
        ∗ ([∗ list] k↦y1;y2 ∈ l2;l2', Φ (strings.length l1 + k) y1 y2))%I
      ≡ ([∗ list] k↦y1;y2 ∈ (l1 ++ l2);(l1' ++ l2'), Φ k y1 y2)%I.
   Proof.
     intros Hlenl1.
     iSplit.
     - iIntros "[Hl1 Hl2]". iApply (big_sepL2_app with "Hl1 Hl2").
     - iIntros "Happ".
       iAssert (∃ l0' l0'' : list A,
                   ⌜(l1 ++ l2) = l0' ++ l0''⌝
                   ∧ ([∗ list] k↦y1;y2 ∈ l0';l1', Φ k y1 y2)
                       ∗ ([∗ list] k↦y1;y2 ∈ l0'';l2', Φ (strings.length l1' + k) y1 y2))%I
         with "[Happ]" as (l0' l0'') "(% & Happl0' & Happl0'')".
       { by iApply (big_sepL2_app_inv_r with "Happ"). }
       iDestruct (big_sepL2_length with "Happl0'") as %Hlen1.
       iDestruct (big_sepL2_length with "Happl0''") as %Hlen2.
       rewrite -Hlenl1 in Hlen1.
       assert (l1 = l0' ∧ l2 = l0'') as [Heq1 Heq2]; first by apply app_inj_1.
       simplify_eq; rewrite Hlenl1.
       iFrame.
   Qed.

  Lemma big_sepL_delete' {PROP: bi} {A: Type} (φ: A -> PROP) (l: list A):
        forall k, (([∗ list] k0↦y ∈ l, if decide (k0 = k) then emp else φ y) -∗
             ([∗ list] k0↦x0 ∈ delete k l, (λ (_ : nat) (x1 : A), φ x1) k0 x0))%I.
  Proof.
    iInduction (l) as [|x l] "IH"; simpl; auto; iIntros (k) "H".
    iDestruct "H" as "[H1 H2]".
    rewrite /delete /=. destruct k.
    - iApply (big_sepL_impl with "H2").
      iClear "H1". iModIntro. iIntros. destruct (decide (S k = 0)); auto. lia.
    - simpl. iFrame. iApply ("IH" with "[H2]").
      iApply (big_sepL_impl with "H2").
      iModIntro; iIntros. destruct (decide (k0 = k)); destruct (decide (S k0 = S k)); auto; lia.
  Qed.

  Lemma big_sepL_merge {PROP: bi} {A: Type} (l: list A) (HNoDup: NoDup l) (φ: A -> PROP) {Haffine: forall a, Affine (φ a)}:
    forall l1 l2, (forall a, a ∈ l -> a ∈ l1 \/ a ∈ l2) ->
             (([∗ list] a ∈ l1, φ a) -∗
              ([∗ list] a ∈ l2, φ a) -∗
              ([∗ list] a ∈ l, φ a))%I.
  Proof.
    iInduction (l) as [|x l] "IH"; iIntros (l1 l2 H) "Hl1 Hl2".
    - iApply big_sepL_nil; auto.
    - iApply big_sepL_cons. destruct (H x ltac:(eapply elem_of_list_here)) as [H'|H']; eapply elem_of_list_lookup in H'; destruct H' as [k H'].
      + iDestruct (big_sepL_delete with "Hl1") as "[$ Hl1]"; eauto.
        iAssert ([∗ list] a ∈ delete k l1, φ a)%I with "[Hl1]" as "Hl1".
        { iApply (big_sepL_impl with "[Hl1]"); auto.
          iApply (big_sepL_delete' with "Hl1"). }
        assert (Hincl: ∀ a : A, a ∈ l → a ∈ delete k l1 ∨ a ∈ l2).
        { intros. destruct (H a ltac:(eapply elem_of_list_further; eauto)).
          - left. eapply elem_of_list_lookup in H1. destruct H1.
            eapply elem_of_list_lookup. assert (x0 <> k).
            + red; intros; subst x0. rewrite H1 in H'; inversion H'.
              inversion HNoDup. eapply H5. subst. auto.
            + assert  (x0 < k \/ k <= x0) by lia. destruct H3.
              * exists x0. rewrite lookup_delete_lt; auto.
              * exists (x0 - 1). rewrite lookup_delete_ge; auto; try lia.
                replace (S (x0 - 1)) with x0; auto. lia.
          - right. auto. }
        inversion HNoDup. iApply ("IH" $! H3 (delete k l1) l2 Hincl with "[$Hl1] [$Hl2]").
      + iDestruct (big_sepL_delete with "Hl2") as "[$ Hl2]"; eauto.
        iAssert ([∗ list] a ∈ delete k l2, φ a)%I with "[Hl2]" as "Hl2".
        { iApply (big_sepL_impl with "[Hl2]"); auto.
          iApply (big_sepL_delete' with "Hl2"). }
        assert (Hincl: ∀ a : A, a ∈ l → a ∈ l1 ∨ a ∈ delete k l2).
        { intros. destruct (H a ltac:(eapply elem_of_list_further; eauto)).
          - left. auto.
          - right. eapply elem_of_list_lookup in H1. destruct H1.
            eapply elem_of_list_lookup. assert (x0 <> k).
            + red; intros; subst x0. rewrite H1 in H'; inversion H'.
              inversion HNoDup. subst. eapply H5. auto.
            + assert  (x0 < k \/ k <= x0) by lia. destruct H3.
              * exists x0. rewrite lookup_delete_lt; auto.
              * exists (x0 - 1). rewrite lookup_delete_ge; auto; try lia.
                replace (S (x0 - 1)) with x0; auto. lia. }
        inversion HNoDup. iApply ("IH" $! H3 l1 (delete k l2) Hincl with "[$Hl1] [$Hl2]").
  Qed.

  Lemma big_sepL2_to_big_sepM (PROP : bi) (A B : Type) `{EqDecision A} `{Countable A}
        (φ: A -> B -> PROP) (l1: list A) (l2: list B):
        NoDup l1 ->
        (([∗ list] y1;y2 ∈ l1;l2, φ y1 y2) -∗
        ([∗ map] y1↦y2 ∈ list_to_map (zip l1 l2), φ y1 y2))%I.
  Proof.
    revert l2. iInduction (l1) as [|x l1] "IH"; iIntros (l2 Hnd) "H".
    - iSimpl. iDestruct (big_sepL2_length with "H") as "%".
      destruct l2; simpl in H0; inversion H0.
      iApply big_sepM_empty. auto.
    - iDestruct (big_sepL2_length with "H") as "%".
      destruct l2; simpl in H0; inversion H0.
      simpl. inversion Hnd. iDestruct "H" as "[A B]".
      iApply (big_sepM_insert with "[A B]").
      + eapply not_elem_of_list_to_map.
        rewrite fst_zip; auto. lia.
      + iFrame. iApply ("IH" $! l2 H5 with "B"); auto.
  Qed.
