-- Basic dummy seed examples
INSERT INTO users (id, role, first_name, is_active, is_verified)
VALUES
  (gen_random_uuid(), 'admin', 'AdminUser', true, true),
  (gen_random_uuid(), 'parent', 'ParentUser', true, true)
ON CONFLICT DO NOTHING;
