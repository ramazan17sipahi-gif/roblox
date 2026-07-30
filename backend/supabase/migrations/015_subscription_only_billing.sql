-- Subscription-only billing: deactivate credit topups and fix Play Store product IDs.

UPDATE public.billing_products
SET is_active = false
WHERE type = 'topup';

UPDATE public.billing_products
SET
  ios_product_id = 'com.rblxclothingmaker.app.pro_monthly',
  android_product_id = 'com.rblxclothingmaker.app.pro_monthly',
  credit_amount = 0,
  display_name = 'Pro Monthly'
WHERE code = 'pro_monthly';

UPDATE public.billing_products
SET
  ios_product_id = 'com.rblxclothingmaker.app.studio_monthly',
  android_product_id = 'com.rblxclothingmaker.app.studio_monthly',
  credit_amount = 0,
  display_name = 'Studio Monthly'
WHERE code = 'studio_monthly';
