-- ================================================
-- MYNA POWER ADMIN: PROMOTIONS & SUPPORT TABLES
-- ================================================
-- Run this SQL in Supabase SQL Editor
-- This adds: Promo Banners, Curated Shelves, Support Tickets

-- ================================================
-- 1. PROMOTIONS: CURATED SHELVES
-- ================================================

CREATE TABLE IF NOT EXISTS promo_shelves (
  id SERIAL PRIMARY KEY,
  title_fa TEXT NOT NULL,
  description_fa TEXT,
  sort_order INT DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  starts_at TIMESTAMPTZ,
  ends_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE promo_shelves ENABLE ROW LEVEL SECURITY;

-- Shelf Items (audiobooks in a shelf)
CREATE TABLE IF NOT EXISTS promo_shelf_items (
  id SERIAL PRIMARY KEY,
  shelf_id INT NOT NULL REFERENCES promo_shelves(id) ON DELETE CASCADE,
  audiobook_id INT NOT NULL REFERENCES audiobooks(id) ON DELETE CASCADE,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(shelf_id, audiobook_id)
);

-- Enable RLS
ALTER TABLE promo_shelf_items ENABLE ROW LEVEL SECURITY;

-- ================================================
-- 2. PROMOTIONS: BANNERS
-- ================================================

CREATE TABLE IF NOT EXISTS promo_banners (
  id SERIAL PRIMARY KEY,
  title_fa TEXT NOT NULL,
  subtitle_fa TEXT,
  image_url TEXT NOT NULL,
  target_type TEXT NOT NULL CHECK (target_type IN ('audiobook', 'shelf', 'category')),
  target_id INT NOT NULL,
  sort_order INT DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  starts_at TIMESTAMPTZ,
  ends_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE promo_banners ENABLE ROW LEVEL SECURITY;

-- ================================================
-- 3. SUPPORT: TICKETS
-- ================================================

CREATE TABLE IF NOT EXISTS support_tickets (
  id SERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  audiobook_id INT REFERENCES audiobooks(id) ON DELETE SET NULL,
  type TEXT NOT NULL CHECK (type IN ('book_issue', 'account', 'payment', 'other')),
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'closed')),
  subject TEXT NOT NULL,
  last_admin_id UUID REFERENCES profiles(id),
  last_message_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE support_tickets ENABLE ROW LEVEL SECURITY;

-- Support Messages
CREATE TABLE IF NOT EXISTS support_messages (
  id SERIAL PRIMARY KEY,
  ticket_id INT NOT NULL REFERENCES support_tickets(id) ON DELETE CASCADE,
  sender_type TEXT NOT NULL CHECK (sender_type IN ('user', 'admin')),
  sender_id UUID NOT NULL REFERENCES profiles(id),
  message_text TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable RLS
ALTER TABLE support_messages ENABLE ROW LEVEL SECURITY;

-- ================================================
-- 4. USER ADMIN NOTES (add column to profiles)
-- ================================================

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS admin_note TEXT;

-- ================================================
-- 5. RLS POLICIES: PROMO SHELVES
-- ================================================

-- Admin full access
DROP POLICY IF EXISTS "Admin full access on promo_shelves" ON promo_shelves;
CREATE POLICY "Admin full access on promo_shelves" ON promo_shelves FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- Public read active shelves (within date range)
DROP POLICY IF EXISTS "Public read active shelves" ON promo_shelves;
CREATE POLICY "Public read active shelves" ON promo_shelves FOR SELECT
  USING (
    is_active = true
    AND (starts_at IS NULL OR starts_at <= NOW())
    AND (ends_at IS NULL OR ends_at >= NOW())
  );

-- ================================================
-- 6. RLS POLICIES: PROMO SHELF ITEMS
-- ================================================

-- Admin full access
DROP POLICY IF EXISTS "Admin full access on promo_shelf_items" ON promo_shelf_items;
CREATE POLICY "Admin full access on promo_shelf_items" ON promo_shelf_items FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- Public read (needed to fetch audiobooks in shelves)
DROP POLICY IF EXISTS "Public read shelf items" ON promo_shelf_items;
CREATE POLICY "Public read shelf items" ON promo_shelf_items FOR SELECT USING (true);

-- ================================================
-- 7. RLS POLICIES: PROMO BANNERS
-- ================================================

-- Admin full access
DROP POLICY IF EXISTS "Admin full access on promo_banners" ON promo_banners;
CREATE POLICY "Admin full access on promo_banners" ON promo_banners FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- Public read active banners (within date range)
DROP POLICY IF EXISTS "Public read active banners" ON promo_banners;
CREATE POLICY "Public read active banners" ON promo_banners FOR SELECT
  USING (
    is_active = true
    AND (starts_at IS NULL OR starts_at <= NOW())
    AND (ends_at IS NULL OR ends_at >= NOW())
  );

-- ================================================
-- 8. RLS POLICIES: SUPPORT TICKETS
-- ================================================

-- Users can read their own tickets, admins can read all
DROP POLICY IF EXISTS "Users read own tickets" ON support_tickets;
CREATE POLICY "Users read own tickets" ON support_tickets FOR SELECT
  USING (
    user_id = auth.uid()
    OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- Users can create their own tickets
DROP POLICY IF EXISTS "Users create own tickets" ON support_tickets;
CREATE POLICY "Users create own tickets" ON support_tickets FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- Users can update own tickets (for replying), admins can update all
DROP POLICY IF EXISTS "Users update own or admin all tickets" ON support_tickets;
CREATE POLICY "Users update own or admin all tickets" ON support_tickets FOR UPDATE
  USING (
    user_id = auth.uid()
    OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- Only admin can delete tickets
DROP POLICY IF EXISTS "Admin delete tickets" ON support_tickets;
CREATE POLICY "Admin delete tickets" ON support_tickets FOR DELETE
  USING (EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'));

-- ================================================
-- 9. RLS POLICIES: SUPPORT MESSAGES
-- ================================================

-- Users can read messages on their own tickets, admins can read all
DROP POLICY IF EXISTS "Users read own ticket messages" ON support_messages;
CREATE POLICY "Users read own ticket messages" ON support_messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM support_tickets
      WHERE id = ticket_id
      AND (
        user_id = auth.uid()
        OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
      )
    )
  );

-- Users can create messages on their own tickets, admins on all
DROP POLICY IF EXISTS "Users create messages on accessible tickets" ON support_messages;
CREATE POLICY "Users create messages on accessible tickets" ON support_messages FOR INSERT
  WITH CHECK (
    sender_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM support_tickets
      WHERE id = ticket_id
      AND (
        user_id = auth.uid()
        OR EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
      )
    )
  );

-- ================================================
-- 10. INDEXES FOR PERFORMANCE
-- ================================================

CREATE INDEX IF NOT EXISTS idx_promo_shelves_active ON promo_shelves(is_active, sort_order);
CREATE INDEX IF NOT EXISTS idx_promo_shelf_items_shelf ON promo_shelf_items(shelf_id, sort_order);
CREATE INDEX IF NOT EXISTS idx_promo_banners_active ON promo_banners(is_active, sort_order);
CREATE INDEX IF NOT EXISTS idx_support_tickets_user ON support_tickets(user_id, status);
CREATE INDEX IF NOT EXISTS idx_support_tickets_status ON support_tickets(status, created_at);
CREATE INDEX IF NOT EXISTS idx_support_messages_ticket ON support_messages(ticket_id, created_at);

-- ================================================
-- DONE! All tables and policies created.
-- ================================================
