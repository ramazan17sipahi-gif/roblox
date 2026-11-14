-- ============================================================================
-- 020: Catalog access ranks
--
-- Existing is_pro=true skins become "ad" (unlock with rewarded ads OR Pro).
-- New "pro" rank is subscription-only — ads cannot unlock those skins.
-- is_pro is kept in sync for older clients (true when rank is ad or pro).
-- ============================================================================

ALTER TABLE public.clothing_templates
  ADD COLUMN IF NOT EXISTS access_tier text NOT NULL DEFAULT 'free';

ALTER TABLE public.stickers
  ADD COLUMN IF NOT EXISTS access_tier text NOT NULL DEFAULT 'free';

UPDATE public.clothing_templates
SET access_tier = CASE WHEN is_pro THEN 'ad' ELSE 'free' END
WHERE access_tier = 'free';

UPDATE public.stickers
SET access_tier = CASE WHEN is_pro THEN 'ad' ELSE 'free' END
WHERE access_tier = 'free';

ALTER TABLE public.clothing_templates
  DROP CONSTRAINT IF EXISTS clothing_templates_access_tier_check;
ALTER TABLE public.clothing_templates
  ADD CONSTRAINT clothing_templates_access_tier_check
  CHECK (access_tier IN ('free', 'ad', 'pro'));

ALTER TABLE public.stickers
  DROP CONSTRAINT IF EXISTS stickers_access_tier_check;
ALTER TABLE public.stickers
  ADD CONSTRAINT stickers_access_tier_check
  CHECK (access_tier IN ('free', 'ad', 'pro'));

CREATE OR REPLACE FUNCTION public.sync_catalog_access_flags()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.access_tier = 'free' AND NEW.is_pro THEN
      NEW.access_tier := 'ad';
    END IF;
    NEW.is_pro := NEW.access_tier <> 'free';
    RETURN NEW;
  END IF;

  IF NEW.access_tier IS DISTINCT FROM OLD.access_tier THEN
    NEW.is_pro := NEW.access_tier <> 'free';
  ELSIF NEW.is_pro IS DISTINCT FROM OLD.is_pro THEN
    NEW.access_tier := CASE WHEN NEW.is_pro THEN 'ad' ELSE 'free' END;
  ELSE
    NEW.is_pro := NEW.access_tier <> 'free';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS clothing_templates_sync_access ON public.clothing_templates;
CREATE TRIGGER clothing_templates_sync_access
  BEFORE INSERT OR UPDATE ON public.clothing_templates
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_catalog_access_flags();

DROP TRIGGER IF EXISTS stickers_sync_access ON public.stickers;
CREATE TRIGGER stickers_sync_access
  BEFORE INSERT OR UPDATE ON public.stickers
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_catalog_access_flags();

COMMENT ON COLUMN public.clothing_templates.access_tier IS
  'free = open, ad = rewarded ads or Pro, pro = Pro subscribers only';
COMMENT ON COLUMN public.stickers.access_tier IS
  'free = open, ad = rewarded ads or Pro, pro = Pro subscribers only';
