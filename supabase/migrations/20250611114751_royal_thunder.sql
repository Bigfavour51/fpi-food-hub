-- ============================================================================
-- FPI FOOD HUB - COMPLETE DATABASE SETUP
-- Federal Polytechnic Ilaro Campus Food Ordering System
-- ============================================================================

-- ============================================================================
-- 1. CREATE CUSTOM TYPES AND ENUMS
-- ============================================================================

-- Order status enumeration
DO $$ BEGIN
    CREATE TYPE order_status_enum AS ENUM (
        'pending',
        'payment_received', 
        'confirmed',
        'preparing',
        'dispatched',
        'delivered',
        'cancelled'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Food category enumeration
DO $$ BEGIN
    CREATE TYPE food_category_enum AS ENUM (
        'Rice',
        'Snacks', 
        'Drinks',
        'Swallow',
        'Protein',
        'Others'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Payment status enumeration
DO $$ BEGIN
    CREATE TYPE payment_status_enum AS ENUM (
        'pending',
        'processing',
        'completed',
        'failed',
        'refunded'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Payment method enumeration
DO $$ BEGIN
    CREATE TYPE payment_method_enum AS ENUM (
        'bank_transfer',
        'cash_on_delivery',
        'card_payment'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

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
    payment_status payment_status_enum DEFAULT 'pending',
    payment_method payment_method_enum,
    payment_reference text UNIQUE,
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

-- Payment History Table
CREATE TABLE IF NOT EXISTS payment_history (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id uuid NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    amount decimal(10,2) NOT NULL CHECK (amount > 0),
    status payment_status_enum NOT NULL,
    payment_method payment_method_enum NOT NULL,
    reference text UNIQUE NOT NULL,
    metadata jsonb DEFAULT '{}',
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Bank Details Table
CREATE TABLE IF NOT EXISTS bank_details (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    bank_name text NOT NULL,
    account_name text NOT NULL,
    account_number text NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
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
CREATE INDEX IF NOT EXISTS idx_food_items_name ON food_items(name);
CREATE INDEX IF NOT EXISTS idx_orders_session_id ON orders(session_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_tracking_id ON orders(tracking_id);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at);
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_food_item_id ON order_items(food_item_id);
CREATE INDEX IF NOT EXISTS idx_order_status_history_order_id ON order_status_history(order_id);
CREATE INDEX IF NOT EXISTS idx_order_status_history_created_at ON order_status_history(created_at);
CREATE INDEX IF NOT EXISTS idx_admin_credentials_username ON admin_credentials(username);

-- New indexes for payment-related tables
CREATE INDEX IF NOT EXISTS idx_orders_payment_status ON orders(payment_status);
CREATE INDEX IF NOT EXISTS idx_orders_payment_method ON orders(payment_method);
CREATE INDEX IF NOT EXISTS idx_payment_history_order_id ON payment_history(order_id);
CREATE INDEX IF NOT EXISTS idx_payment_history_status ON payment_history(status);
CREATE INDEX IF NOT EXISTS idx_payment_history_reference ON payment_history(reference);
CREATE INDEX IF NOT EXISTS idx_bank_details_is_active ON bank_details(is_active);

-- ============================================================================
-- 4. ENABLE ROW LEVEL SECURITY
-- ============================================================================

ALTER TABLE food_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE bank_details ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_credentials ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 5. DROP EXISTING POLICIES (IF ANY) TO AVOID CONFLICTS
-- ============================================================================

DROP POLICY IF EXISTS "Anyone can view available food items" ON food_items;
DROP POLICY IF EXISTS "Admins can view all food items" ON food_items;
DROP POLICY IF EXISTS "Admins can manage food items" ON food_items;
DROP POLICY IF EXISTS "Users can create orders" ON orders;
DROP POLICY IF EXISTS "Users can view their own orders" ON orders;
DROP POLICY IF EXISTS "Admins can view all orders" ON orders;
DROP POLICY IF EXISTS "Admins can update order status" ON orders;
DROP POLICY IF EXISTS "Users can create order items" ON order_items;
DROP POLICY IF EXISTS "Users can view order items for their orders" ON order_items;
DROP POLICY IF EXISTS "Admins can view all order items" ON order_items;
DROP POLICY IF EXISTS "Anyone can create status history" ON order_status_history;
DROP POLICY IF EXISTS "Users can view status history for their orders" ON order_status_history;
DROP POLICY IF EXISTS "Admins can view all status history" ON order_status_history;
DROP POLICY IF EXISTS "Admins can manage credentials" ON admin_credentials;

-- ============================================================================
-- 6. CREATE ROW LEVEL SECURITY POLICIES
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

-- Payment History Policies
CREATE POLICY "Users can view their own payment history"
    ON payment_history
    FOR SELECT
    TO public
    USING (
        EXISTS (
            SELECT 1 FROM orders 
            WHERE orders.id = payment_history.order_id 
            AND orders.session_id = current_setting('app.session_id', true)
        )
    );

CREATE POLICY "Admins can view all payment history"
    ON payment_history
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM admin_credentials 
            WHERE username = current_setting('app.admin_username', true)
        )
    );

-- Bank Details Policies
CREATE POLICY "Anyone can view active bank details"
    ON bank_details
    FOR SELECT
    TO public
    USING (is_active = true);

CREATE POLICY "Admins can manage bank details"
    ON bank_details
    FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM admin_credentials 
            WHERE username = current_setting('app.admin_username', true)
        )
    );

-- ============================================================================
-- 7. CREATE UTILITY FUNCTIONS
-- ============================================================================

-- Function to automatically update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Function to generate tracking ID
CREATE OR REPLACE FUNCTION generate_tracking_id()
RETURNS text AS $$
DECLARE
    chars text := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    result text := 'FPI-';
    i integer;
BEGIN
    FOR i IN 1..6 LOOP
        result := result || substr(chars, floor(random() * length(chars) + 1)::integer, 1);
    END LOOP;
    RETURN result;
END;
$$ language 'plpgsql';

-- Function to create an order with items in a single transaction
CREATE OR REPLACE FUNCTION create_order_with_items(
  p_session_id text,
  p_total_amount decimal,
  p_tracking_id text,
  p_customer_note text DEFAULT '',
  p_order_items jsonb DEFAULT '[]'::jsonb
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_order_id uuid;
  v_order jsonb;
  v_item jsonb;
BEGIN
  -- Validate input
  IF p_total_amount <= 0 THEN
    RAISE EXCEPTION 'Invalid order total amount';
  END IF;

  -- Check for duplicate tracking ID
  IF EXISTS (SELECT 1 FROM orders WHERE tracking_id = p_tracking_id) THEN
    RAISE EXCEPTION 'Duplicate tracking ID';
  END IF;

  -- Start transaction
  BEGIN
    -- Create order
    INSERT INTO orders (
      session_id,
      total_amount,
      tracking_id,
      customer_note,
      status
    ) VALUES (
      p_session_id,
      p_total_amount,
      p_tracking_id,
      p_customer_note,
      'pending'
    )
    RETURNING id INTO v_order_id;

    -- Create order items
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_order_items)
    LOOP
      INSERT INTO order_items (
        order_id,
        food_item_id,
        quantity,
        unit_price
      ) VALUES (
        v_order_id,
        (v_item->>'food_item_id')::uuid,
        (v_item->>'quantity')::integer,
        (v_item->>'unit_price')::decimal
      );
    END LOOP;

    -- Add initial status to history
    INSERT INTO order_status_history (
      order_id,
      status
    ) VALUES (
      v_order_id,
      'pending'
    );

    -- Return the created order with its items
    SELECT jsonb_build_object(
      'id', o.id,
      'session_id', o.session_id,
      'total_amount', o.total_amount,
      'status', o.status,
      'tracking_id', o.tracking_id,
      'customer_note', o.customer_note,
      'created_at', o.created_at,
      'order_items', (
        SELECT jsonb_agg(
          jsonb_build_object(
            'id', oi.id,
            'food_item_id', oi.food_item_id,
            'quantity', oi.quantity,
            'unit_price', oi.unit_price
          )
        )
        FROM order_items oi
        WHERE oi.order_id = o.id
      )
    )
    INTO v_order
    FROM orders o
    WHERE o.id = v_order_id;

    RETURN v_order;
  EXCEPTION
    WHEN OTHERS THEN
      -- Rollback will happen automatically
      RAISE;
  END;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION create_order_with_items TO authenticated;
GRANT EXECUTE ON FUNCTION create_order_with_items TO anon;

-- Function to update order status with history
CREATE OR REPLACE FUNCTION update_order_status(
  p_order_id uuid,
  p_new_status order_status_enum
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Update order status
  UPDATE orders
  SET status = p_new_status
  WHERE id = p_order_id;

  -- Record status change
  INSERT INTO order_status_history (order_id, status)
  VALUES (p_order_id, p_new_status);
END;
$$;

-- Function to process payment
CREATE OR REPLACE FUNCTION process_payment(
  p_order_id uuid,
  p_amount decimal,
  p_payment_method payment_method_enum,
  p_reference text,
  p_metadata jsonb DEFAULT '{}'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_payment_id uuid;
  v_payment jsonb;
BEGIN
  -- Validate input
  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'Amount must be greater than 0';
  END IF;

  -- Check for duplicate reference
  IF EXISTS (SELECT 1 FROM payment_history WHERE reference = p_reference) THEN
    RAISE EXCEPTION 'Duplicate payment reference';
  END IF;

  -- Start transaction
  BEGIN
    -- Create payment record
    INSERT INTO payment_history (
      order_id,
      amount,
      status,
      payment_method,
      reference,
      metadata
    ) VALUES (
      p_order_id,
      p_amount,
      'processing',
      p_payment_method,
      p_reference,
      p_metadata
    ) RETURNING id INTO v_payment_id;

    -- Update order payment status
    UPDATE orders
    SET 
      payment_status = 'processing',
      payment_method = p_payment_method,
      payment_reference = p_reference
    WHERE id = p_order_id;

    -- Get payment details
    SELECT jsonb_build_object(
      'payment', ph,
      'order', o
    )
    INTO v_payment
    FROM payment_history ph
    JOIN orders o ON o.id = ph.order_id
    WHERE ph.id = v_payment_id;

    RETURN v_payment;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE;
  END;
END;
$$;

-- ============================================================================
-- 8. CREATE TRIGGERS
-- ============================================================================

-- Drop existing triggers if they exist
DROP TRIGGER IF EXISTS update_food_items_updated_at ON food_items;
DROP TRIGGER IF EXISTS update_orders_updated_at ON orders;
DROP TRIGGER IF EXISTS update_payment_history_updated_at ON payment_history;
DROP TRIGGER IF EXISTS update_bank_details_updated_at ON bank_details;

-- Trigger to update updated_at on food_items
CREATE TRIGGER update_food_items_updated_at
    BEFORE UPDATE ON food_items
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger to update updated_at on orders
CREATE TRIGGER update_orders_updated_at
    BEFORE UPDATE ON orders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger for payment_history updated_at
CREATE TRIGGER update_payment_history_updated_at
    BEFORE UPDATE ON payment_history
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger for bank_details updated_at
CREATE TRIGGER update_bank_details_updated_at
    BEFORE UPDATE ON bank_details
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- 9. INSERT ADMIN CREDENTIALS
-- ============================================================================

-- Insert default admin user (password: admin123)
-- Note: In production, use proper password hashing
INSERT INTO admin_credentials (username, password_hash) 
VALUES ('admin', '$2b$10$rQZ9QmSTUwhmW8.93h8/veRZYHFx8/XJvZ8lCqLKhkOJ5yY4oZ9em')
ON CONFLICT (username) DO NOTHING;

-- ============================================================================
-- 10. INSERT SAMPLE BANK DETAILS
-- ============================================================================

INSERT INTO bank_details (bank_name, account_name, account_number) VALUES
('First Bank', 'FPI Food Hub', '1234567890'),
('UBA', 'FPI Food Hub', '0987654321'),
('Access Bank', 'FPI Food Hub', '1122334455')
ON CONFLICT DO NOTHING;

-- ============================================================================
-- 11. INSERT SAMPLE FOOD ITEMS
-- ============================================================================

-- Clear existing food items (optional - remove this line if you want to keep existing data)
-- DELETE FROM food_items;

INSERT INTO food_items (name, description, price, category, image_url) VALUES
-- Rice Category
('Jollof Rice', 'Spicy Nigerian rice cooked with tomatoes, peppers, and aromatic spices. A campus favorite!', 800.00, 'Rice', 'https://images.pexels.com/photos/5639297/pexels-photo-5639297.jpeg'),
('Fried Rice', 'Delicious fried rice with mixed vegetables, carrots, green beans, and sweet corn', 900.00, 'Rice', 'https://images.pexels.com/photos/1624487/pexels-photo-1624487.jpeg'),
('White Rice & Stew', 'Plain white rice served with rich tomato stew and your choice of protein', 700.00, 'Rice', 'https://images.pexels.com/photos/8753999/pexels-photo-8753999.jpeg'),
('Coconut Rice', 'Fragrant rice cooked in coconut milk with spices and vegetables', 850.00, 'Rice', 'https://images.pexels.com/photos/1624487/pexels-photo-1624487.jpeg'),
('Ofada Rice & Sauce', 'Local brown rice served with spicy ofada sauce and assorted meat', 1000.00, 'Rice', 'https://images.pexels.com/photos/5639297/pexels-photo-5639297.jpeg'),

-- Swallow Category
('Pounded Yam', 'Traditional pounded yam served with your choice of soup (Egusi, Okra, or Vegetable)', 1200.00, 'Swallow', 'https://images.pexels.com/photos/8753746/pexels-photo-8753746.jpeg'),
('Eba & Egusi', 'Garri (Eba) served with rich Egusi soup, assorted meat, and fish', 900.00, 'Swallow', 'https://images.pexels.com/photos/8753745/pexels-photo-8753745.jpeg'),
('Amala & Ewedu', 'Yam flour (Amala) served with Ewedu soup and gbegiri', 800.00, 'Swallow', 'https://images.pexels.com/photos/8753746/pexels-photo-8753746.jpeg'),
('Fufu & Ogbono', 'Cassava fufu served with ogbono soup and assorted meat', 950.00, 'Swallow', 'https://images.pexels.com/photos/8753745/pexels-photo-8753745.jpeg'),
('Wheat & Vegetable Soup', 'Wheat meal served with mixed vegetable soup and fish', 850.00, 'Swallow', 'https://images.pexels.com/photos/8753746/pexels-photo-8753746.jpeg'),

-- Protein Category
('Grilled Chicken', 'Perfectly seasoned and grilled chicken breast with herbs and spices', 1500.00, 'Protein', 'https://images.pexels.com/photos/1105325/pexels-photo-1105325.jpeg'),
('Fried Fish', 'Crispy fried fish seasoned with local spices and served hot', 1200.00, 'Protein', 'https://images.pexels.com/photos/725991/pexels-photo-725991.jpeg'),
('Beef Stew', 'Tender beef chunks cooked in rich tomato stew with vegetables', 1300.00, 'Protein', 'https://images.pexels.com/photos/1105325/pexels-photo-1105325.jpeg'),
('Goat Meat Pepper Soup', 'Spicy goat meat in traditional pepper soup with local spices', 1800.00, 'Protein', 'https://images.pexels.com/photos/725991/pexels-photo-725991.jpeg'),
('Grilled Turkey', 'Succulent grilled turkey seasoned with herbs and spices', 2000.00, 'Protein', 'https://images.pexels.com/photos/1105325/pexels-photo-1105325.jpeg'),
('Fried Chicken', 'Crispy fried chicken pieces with special seasoning', 1400.00, 'Protein', 'https://images.pexels.com/photos/1105325/pexels-photo-1105325.jpeg'),

-- Snacks Category
('Meat Pie', 'Delicious pastry filled with seasoned minced meat and vegetables', 300.00, 'Snacks', 'https://images.pexels.com/photos/1105325/pexels-photo-1105325.jpeg'),
('Chin Chin', 'Crunchy fried sweet snack, perfect for any time of the day', 200.00, 'Snacks', 'https://images.pexels.com/photos/1638635/pexels-photo-1638635.jpeg'),
('Puff Puff', 'Sweet deep-fried dough balls, soft and fluffy inside', 150.00, 'Snacks', 'https://images.pexels.com/photos/1638635/pexels-photo-1638635.jpeg'),
('Buns', 'Sweet bread rolls perfect for breakfast or afternoon snacking', 250.00, 'Snacks', 'https://images.pexels.com/photos/1105325/pexels-photo-1105325.jpeg'),
('Scotch Egg', 'Hard-boiled egg wrapped in seasoned sausage meat and breadcrumbs', 400.00, 'Snacks', 'https://images.pexels.com/photos/1105325/pexels-photo-1105325.jpeg'),
('Samosa', 'Crispy triangular pastry filled with spiced vegetables or meat', 200.00, 'Snacks', 'https://images.pexels.com/photos/1638635/pexels-photo-1638635.jpeg'),
('Fish Roll', 'Pastry roll filled with seasoned fish and vegetables', 350.00, 'Snacks', 'https://images.pexels.com/photos/1105325/pexels-photo-1105325.jpeg'),
('Sausage Roll', 'Flaky pastry wrapped around seasoned sausage meat', 300.00, 'Snacks', 'https://images.pexels.com/photos/1105325/pexels-photo-1105325.jpeg'),

-- Drinks Category
('Coca Cola', 'Refreshing cold Coca Cola (50cl bottle)', 250.00, 'Drinks', 'https://images.pexels.com/photos/1641661/pexels-photo-1641661.jpeg'),
('Pepsi', 'Ice-cold Pepsi cola (50cl bottle)', 250.00, 'Drinks', 'https://images.pexels.com/photos/1641661/pexels-photo-1641661.jpeg'),
('Sprite', 'Crisp and refreshing lemon-lime soda (50cl)', 250.00, 'Drinks', 'https://images.pexels.com/photos/1641661/pexels-photo-1641661.jpeg'),
('Fanta Orange', 'Sweet orange flavored soda (50cl)', 250.00, 'Drinks', 'https://images.pexels.com/photos/1641661/pexels-photo-1641661.jpeg'),
('Orange Juice', 'Fresh squeezed orange juice, rich in vitamin C', 400.00, 'Drinks', 'https://images.pexels.com/photos/1435735/pexels-photo-1435735.jpeg'),
('Apple Juice', 'Pure apple juice, naturally sweet and refreshing', 450.00, 'Drinks', 'https://images.pexels.com/photos/1435735/pexels-photo-1435735.jpeg'),
('Zobo Drink', 'Traditional Nigerian hibiscus drink with natural flavors and fruits', 300.00, 'Drinks', 'https://images.pexels.com/photos/1435735/pexels-photo-1435735.jpeg'),
('Chapman', 'Nigerian cocktail drink with mixed fruits and flavors', 500.00, 'Drinks', 'https://images.pexels.com/photos/1435735/pexels-photo-1435735.jpeg'),
('Bottled Water', 'Pure drinking water (75cl bottle)', 150.00, 'Drinks', 'https://images.pexels.com/photos/1641661/pexels-photo-1641661.jpeg'),
('Malt Drink', 'Non-alcoholic malt beverage, rich and nutritious', 300.00, 'Drinks', 'https://images.pexels.com/photos/1641661/pexels-photo-1641661.jpeg'),
('Tiger Nut Drink', 'Creamy tiger nut drink (Kunun aya) with natural sweetness', 350.00, 'Drinks', 'https://images.pexels.com/photos/1435735/pexels-photo-1435735.jpeg'),
('Yogurt Drink', 'Creamy yogurt drink with fruit flavors', 400.00, 'Drinks', 'https://images.pexels.com/photos/1435735/pexels-photo-1435735.jpeg'),

-- Others Category
('Plantain (Fried)', 'Sweet fried plantain slices, perfectly caramelized', 300.00, 'Others', 'https://images.pexels.com/photos/1638635/pexels-photo-1638635.jpeg'),
('Yam Porridge', 'Yam cooked with vegetables, palm oil, and spices', 600.00, 'Others', 'https://images.pexels.com/photos/8753999/pexels-photo-8753999.jpeg'),
('Beans Porridge', 'Nutritious beans cooked with vegetables and palm oil', 500.00, 'Others', 'https://images.pexels.com/photos/8753999/pexels-photo-8753999.jpeg'),
('Moi Moi', 'Steamed bean pudding with eggs, fish, and vegetables', 400.00, 'Others', 'https://images.pexels.com/photos/8753999/pexels-photo-8753999.jpeg'),
('Akara', 'Deep-fried bean cakes, crispy outside and soft inside', 200.00, 'Others', 'https://images.pexels.com/photos/1638635/pexels-photo-1638635.jpeg'),
('Bread & Egg', 'Toasted bread served with fried or boiled eggs', 350.00, 'Others', 'https://images.pexels.com/photos/1105325/pexels-photo-1105325.jpeg'),
('Indomie Noodles', 'Instant noodles prepared with vegetables and egg', 400.00, 'Others', 'https://images.pexels.com/photos/8753999/pexels-photo-8753999.jpeg'),
('Fried Yam', 'Crispy fried yam slices served with pepper sauce', 350.00, 'Others', 'https://images.pexels.com/photos/1638635/pexels-photo-1638635.jpeg'),
('Boiled Corn', 'Fresh corn on the cob, boiled and served hot', 200.00, 'Others', 'https://images.pexels.com/photos/1638635/pexels-photo-1638635.jpeg'),
('Roasted Plantain', 'Plantain roasted over open fire with palm oil', 250.00, 'Others', 'https://images.pexels.com/photos/1638635/pexels-photo-1638635.jpeg')

ON CONFLICT DO NOTHING;

-- ============================================================================
-- SETUP COMPLETE
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '=================================================';
    RAISE NOTICE 'FPI Food Hub Database Setup Complete!';
    RAISE NOTICE '=================================================';
    RAISE NOTICE 'Created:';
    RAISE NOTICE '- Custom types and enums';
    RAISE NOTICE '- Tables with proper relationships';
    RAISE NOTICE '- Performance indexes';
    RAISE NOTICE '- Row Level Security policies';
    RAISE NOTICE '- Payment processing functions';
    RAISE NOTICE '- Order management functions';
    RAISE NOTICE '- Sample data';
    RAISE NOTICE '';
    RAISE NOTICE 'Your food ordering system is now ready to use!';
    RAISE NOTICE '=================================================';
END $$;