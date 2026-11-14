-- Prevent OAuth bypass: linked accounts must be created via edge functions only.
-- Users may still unlink their own account (DELETE).

DROP POLICY IF EXISTS linked_insert_own ON public.linked_accounts;
DROP POLICY IF EXISTS linked_update_own ON public.linked_accounts;
