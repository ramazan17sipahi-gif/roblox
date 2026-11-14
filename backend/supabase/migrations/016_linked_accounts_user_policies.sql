-- Allow users to manage their own linked platform accounts from the mobile app.

CREATE POLICY linked_insert_own ON public.linked_accounts
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY linked_update_own ON public.linked_accounts
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY linked_delete_own ON public.linked_accounts
  FOR DELETE USING (auth.uid() = user_id);
