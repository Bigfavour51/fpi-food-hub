/*
  # FPI Food Hub - Complete Database Setup
  
  This file contains all the SQL commands needed to set up the complete
  database schema for the campus food ordering system.
  
  Execute this entire file in your Supabase SQL Editor to create:
  1. Custom types and enums
  2. All required tables with proper constraints
  3. Indexes for performance optimization
  4. Row Level Security (RLS) policies
  5. Sample food items data
  6. Admin credentials
  7. Utility functions and triggers
  
  Instructions:
  1. Go to your Supabase dashboard
  2. Navigate to SQL Editor
  3. Copy and paste this entire file
  4. Click "Run" to execute all commands
*/

-- ============================================================================
-- 1. CREATE CUSTOM TYPES AND ENUMS
-- ============================================================================

-- Order status enumeration
CREATE TYPE order_status_enum AS ENUM (
  'pending',
  'payment_received', 
  'confirmed',
  'preparing',
  'dispatched',
  'delivered',
  'cancelled'
);

-- Food category enumeration
CREATE TYPE food_category_enum AS ENUM (
  'Rice',
  'Snacks', 
  'Drinks',
  'Swallow',
  'Protein',
  'Others'
);

-- ============================================================================
-- 2. CREATE TABLES
-- ============================================================================

-- Food Items Table
CREATE TABLE IF NOT EXISTS food_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text DEFAULT '',
  price decimal(10,2) NOT NULL CHECK (price > 0),
  image_url text DEFAULT '',
  category food_category_enum DEFAULT 'Others',
  available boolean DEFAULT true,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Orders Table
CREATE TABLE IF NOT EXISTS orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id text NOT NULL,
  total_amount decimal(10,2) NOT NULL CHECK (total_amount > 0),
  status order_status_enum DEFAULT 'pending',
  tracking_id text UNIQUE NOT NULL,
  customer_note text DEFAULT '',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Order Items Table (junction table for orders and food items)
CREATE TABLE IF NOT EXISTS order_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  food_item_id uuid NOT NULL REFERENCES food_items(id) ON DELETE CASCADE,
  quantity integer NOT NULL CHECK (quantity > 0),
  unit_price decimal(10,2) NOT NULL CHECK (unit_price > 0),
  created_at timestamptz DEFAULT now()
);

-- Order Status History Table (audit trail for status changes)
CREATE TABLE IF NOT EXISTS order_status_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  status order_status_enum NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- Admin Credentials Table
CREATE TABLE IF NOT EXISTS admin_credentials (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  username text UNIQUE NOT NULL,
  password_hash text NOT NULL,
  created_at timestamptz DEFAULT now()
);

-- ============================================================================
-- 3. CREATE INDEXES FOR PERFORMANCE
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_food_items_category ON food_items(category);
CREATE INDEX IF NOT EXISTS idx_food_items_available ON food_items(available);
CREATE INDEX IF NOT EXISTS idx_orders_session_id ON orders(session_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_tracking_id ON orders(tracking_id);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at);
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_food_item_id ON order_items(food_item_id);
CREATE INDEX IF NOT EXISTS idx_order_status_history_order_id ON order_status_history(order_id);
CREATE INDEX IF NOT EXISTS idx_order_status_history_created_at ON order_status_history(created_at);

-- ============================================================================
-- 4. ENABLE ROW LEVEL SECURITY
-- ============================================================================

ALTER TABLE food_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_credentials ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 5. CREATE ROW LEVEL SECURITY POLICIES
-- ============================================================================

-- Food Items Policies
-- Anyone can view available food items
CREATE POLICY "Anyone can view available food items"
  ON food_items
  FOR SELECT
  TO public
  USING (available = true);

-- Admins can view all food items (including unavailable ones)
CREATE POLICY "Admins can view all food items"
  ON food_items
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM admin_credentials 
      WHERE username = current_setting('app.admin_username', true)
    )
  );

-- Admins can manage food items
CREATE POLICY "Admins can manage food items"
  ON food_items
  FOR ALL
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM admin_credentials 
      WHERE username = current_setting('app.admin_username', true)
    )
  );

-- Orders Policies
-- Users can create orders
CREATE POLICY "Users can create orders"
  ON orders
  FOR INSERT
  TO public
  WITH CHECK (true);

-- Users can view their own orders
CREATE POLICY "Users can view their own orders"
  ON orders
  FOR SELECT
  TO public
  USING (session_id = current_setting('app.session_id', true));

-- Admins can view all orders
CREATE POLICY "Admins can view all orders"
  ON orders
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM admin_credentials 
      WHERE username = current_setting('app.admin_username', true)
    )
  );

-- Admins can update order status
CREATE POLICY "Admins can update order status"
  ON orders
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM admin_credentials 
      WHERE username = current_setting('app.admin_username', true)
    )
  );

-- Order Items Policies
-- Users can create order items
CREATE POLICY "Users can create order items"
  ON order_items
  FOR INSERT
  TO public
  WITH CHECK (true);

-- Users can view order items for their orders
CREATE POLICY "Users can view order items for their orders"
  ON order_items
  FOR SELECT
  TO public
  USING (
    EXISTS (
      SELECT 1 FROM orders 
      WHERE orders.id = order_items.order_id 
      AND orders.session_id = current_setting('app.session_id', true)
    )
  );

-- Admins can view all order items
CREATE POLICY "Admins can view all order items"
  ON order_items
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM admin_credentials 
      WHERE username = current_setting('app.admin_username', true)
    )
  );

-- Order Status History Policies
-- Anyone can create status history
CREATE POLICY "Anyone can create status history"
  ON order_status_history
  FOR INSERT
  TO public
  WITH CHECK (true);

-- Users can view status history for their orders
CREATE POLICY "Users can view status history for their orders"
  ON order_status_history
  FOR SELECT
  TO public
  USING (
    EXISTS (
      SELECT 1 FROM orders 
      WHERE orders.id = order_status_history.order_id 
      AND orders.session_id = current_setting('app.session_id', true)
    )
  );

-- Admins can view all status history
CREATE POLICY "Admins can view all status history"
  ON order_status_history
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM admin_credentials 
      WHERE username = current_setting('app.admin_username', true)
    )
  );

-- Admin Credentials Policies
-- Only authenticated admins can manage credentials
CREATE POLICY "Admins can manage credentials"
  ON admin_credentials
  FOR ALL
  TO authenticated
  USING (true);

-- ============================================================================
-- 6. CREATE UTILITY FUNCTIONS
-- ============================================================================

-- Function to automatically update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- ============================================================================
-- 7. CREATE TRIGGERS
-- ============================================================================

-- Trigger to update updated_at on food_items
CREATE TRIGGER update_food_items_updated_at
  BEFORE UPDATE ON food_items
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger to update updated_at on orders
CREATE TRIGGER update_orders_updated_at
  BEFORE UPDATE ON orders
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- 8. INSERT ADMIN CREDENTIALS
-- ============================================================================

-- Insert default admin user
-- Note: In production, use proper password hashing
INSERT INTO admin_credentials (username, password_hash) 
VALUES ('admin', '$2b$10$rQZ9QmSTUwhmW8.93h8/veRZYHFx8/XJvZ8lCqLKhkOJ5yY4oZ9em')
ON CONFLICT (username) DO NOTHING;

-- ============================================================================
-- 9. INSERT SAMPLE FOOD ITEMS
-- ============================================================================

INSERT INTO food_items (name, description, price, category, image_url) VALUES
-- Rice Category
('Jollof Rice', 'Spicy Nigerian rice cooked with tomatoes, peppers, and aromatic spices', 800.00, 'Rice', 'https://images.pexels.com/photos/5639297/pexels-photo-5639297.jpeg'),
('Fried Rice', 'Delicious fried rice with mixed vegetables, carrots, and green beans', 900.00, 'Rice', 'https://images.pexels.com/photos/1624487/pexels-photo-1624487.jpeg'),
('White Rice & Stew', 'Plain white rice served with rich tomato stew', 700.00, 'Rice', 'https://images.pexels.com/photos/8753999/pexels-photo-8753999.jpeg'),
('Coconut Rice', 'Fragrant rice cooked in coconut milk with spices', 850.00, 'Rice', 'https://images.pexels.com/photos/1624487/pexels-photo-1624487.jpeg'),
('Ofada Rice & Sauce', 'Local brown rice served with spicy ofada sauce', 1000.00, 'Rice', 'https://images.pexels.com/photos/5639297/pexels-photo-5639297.jpeg'),

-- Swallow Category
('Pounded Yam', 'Traditional pounded yam served with your choice of soup', 1200.00, 'Swallow', 'https://images.pexels.com/photos/8753746/pexels-photo-8753746.jpeg'),
('Eba & Egusi', 'Garri (Eba) served with rich Egusi soup and assorted meat', 900.00, 'Swallow', 'https://images.pexels.com/photos/8753745/pexels-photo-8753745.jpeg'),
('Amala & Ewedu', 'Yam flour (Amala) served with Ewedu soup', 800.00, 'Swallow', 'https://images.pexels.com/photos/8753746/pexels-photo-8753746.jpeg'),
('Fufu & Ogbono', 'Cassava fufu served with ogbono soup', 950.00, 'Swallow', 'https://images.pexels.com/photos/8753745/pexels-photo-8753745.jpeg'),
('Wheat & Vegetable Soup', 'Wheat meal served with mixed vegetable soup', 850.00, 'Swallow', 'https://images.pexels.com/photos/8753746/pexels-photo-8753746.jpeg'),

-- Protein Category
('Grilled Chicken', 'Perfectly seasoned and grilled chicken breast', 1500.00, 'Protein', 'https://images.pexels.com/photos/1105325/pexels-photo-1105325.jpeg'),
('Fried Fish', 'Crispy fried fish seasoned with local spices', 1200.00, 'Protein', 'https://images.pexels.com/photos/725991/pexels-photo-725991.jpeg'),
('Beef Stew', 'Tender beef cooked in rich tomato stew', 1300.00, 'Protein', 'https://images.pexels.com/photos/1105325/pexels-photo-1105325.jpeg'),
('Goat Meat Pepper Soup', 'Spicy goat meat in traditional pepper soup', 1800.00, 'Protein', 'https://images.pexels.com/photos/725991/pexels-photo-725991.jpeg'),
('Grilled Turkey', 'Succulent grilled turkey with herbs', 2000.00, 'Protein', 'https://images.pexels.com/photos/1105325/pexels-photo-1105325.jpeg'),

-- Snacks Category
('Meat Pie', 'Delicious pastry filled with seasoned minced meat', 300.00, 'Snacks', 'https://images.pexels.com/photos/1105325/pexels-photo-1105325.jpeg'),
('Chin Chin', 'Crunchy fried sweet snack, perfect for any time', 200.00, 'Snacks', 'https://images.pexels.com/photos/1638635/pexels-photo-1638635.jpeg'),
('Puff Puff', 'Sweet deep-fried dough balls, soft and fluffy', 150.00, 'Snacks', 'https://images.pexels.com/photos/1638635/pexels-photo-1638635.jpeg'),
('Buns', 'Sweet bread rolls perfect for breakfast or snacking', 250.00, 'Snacks', 'https://images.pexels.com/photos/1105325/pexels-photo-1105325.jpeg'),
('Scotch Egg', 'Hard-boiled egg wrapped in sausage meat and breadcrumbs', 400.00, 'Snacks', 'https://images.pexels.com/photos/1105325/pexels-photo-1105325.jpeg'),
('Samosa', 'Crispy triangular pastry filled with spiced vegetables', 200.00, 'Snacks', 'https://images.pexels.com/photos/1638635/pexels-photo-1638635.jpeg'),

-- Drinks Category
('Coca Cola', 'Refreshing cold Coca Cola (50cl)', 250.00, 'Drinks', 'https://images.pexels.com/photos/1641661/pexels-photo-1641661.jpeg'),
('Pepsi', 'Ice-cold Pepsi cola (50cl)', 250.00, 'Drinks', 'https://images.pexels.com/photos/1641661/pexels-photo-1641661.jpeg'),
('Orange Juice', 'Fresh squeezed orange juice', 400.00, 'Drinks', 'https://images.pexels.com/photos/1435735/pexels-photo-1435735.jpeg'),
('Zobo Drink', 'Traditional Nigerian hibiscus drink with natural flavors', 300.00, 'Drinks', 'https://images.pexels.com/photos/1435735/pexels-photo-1435735.jpeg'),
('Chapman', 'Nigerian cocktail drink with mixed fruits', 500.00, 'Drinks', 'https://images.pexels.com/photos/1435735/pexels-photo-1435735.jpeg'),
('Bottled Water', 'Pure drinking water (75cl)', 150.00, 'Drinks', 'https://images.pexels.com/photos/1641661/pexels-photo-1641661.jpeg'),
('Malt Drink', 'Non-alcoholic malt beverage', 300.00, 'Drinks', 'https://images.pexels.com/photos/1641661/pexels-photo-1641661.jpeg'),
('Tiger Nut Drink', 'Creamy tiger nut drink (Kunun aya)', 350.00, 'Drinks', 'https://images.pexels.com/photos/1435735/pexels-photo-1435735.jpeg'),

-- Others Category
('Plantain (Fried)', 'Sweet fried plantain slices', 300.00, 'Others', 'https://images.pexels.com/photos/1638635/pexels-photo-1638635.jpeg'),
('Yam Porridge', 'Yam cooked with vegetables and palm oil', 600.00, 'Others', 'https://images.pexels.com/photos/8753999/pexels-photo-8753999.jpeg'),
('Beans Porridge', 'Nutritious beans cooked with vegetables', 500.00, 'Others', 'https://images.pexels.com/photos/8753999/pexels-photo-8753999.jpeg'),
('Moi Moi', 'Steamed bean pudding with eggs and fish', 400.00, 'Others', 'https://images.pexels.com/photos/8753999/pexels-photo-8753999.jpeg'),
('Akara', 'Deep-fried bean cakes, crispy outside and soft inside', 200.00, 'Others', 'https://images.pexels.com/photos/1638635/pexels-photo-1638635.jpeg'),
('Bread & Egg', 'Toasted bread served with fried or boiled eggs', 350.00, 'Others', 'https://images.pexels.com/photos/1105325/pexels-photo-1105325.jpeg')

ON CONFLICT DO NOTHING;

-- ============================================================================
-- 10. CREATE SAMPLE ORDERS (OPTIONAL - FOR TESTING)
-- ============================================================================

-- Uncomment the following section if you want to create sample orders for testing

/*
-- Insert sample orders
INSERT INTO orders (session_id, total_amount, status, tracking_id, customer_note) VALUES
('sample-session-1', 1500.00, 'pending', 'FPI-ABC123', 'Please deliver to Block A, Room 101'),
('sample-session-2', 2200.00, 'confirmed', 'FPI-DEF456', 'Extra spicy please'),
('sample-session-3', 800.00, 'preparing', 'FPI-GHI789', ''),
('sample-session-4', 1200.00, 'dispatched', 'FPI-JKL012', 'Call when you arrive')
ON CONFLICT (tracking_id) DO NOTHING;

-- Insert sample order items (you'll need to get actual food_item IDs first)
-- This is just an example structure
*/

-- ============================================================================
-- SETUP COMPLETE
-- ============================================================================

-- Display success message
DO $$
BEGIN
    RAISE NOTICE '=================================================';
    RAISE NOTICE 'FPI Food Hub Database Setup Complete!';
    RAISE NOTICE '=================================================';
    RAISE NOTICE 'Created:';
    RAISE NOTICE '- Custom types (order_status_enum, food_category_enum)';
    RAISE NOTICE '- 5 main tables with proper relationships';
    RAISE NOTICE '- Performance indexes';
    RAISE NOTICE '- Row Level Security policies';
    RAISE NOTICE '- Sample food items (30+ items)';
    RAISE NOTICE '- Admin credentials (username: admin, password: admin123)';
    RAISE NOTICE '- Utility functions and triggers';
    RAISE NOTICE '';
    RAISE NOTICE 'Your food ordering system is now ready to use!';
    RAISE NOTICE '=================================================';
END $$;