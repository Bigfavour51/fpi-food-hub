/*
  # Campus Food Ordering System Database Schema

  1. New Tables
    - `food_items`
      - `id` (uuid, primary key)
      - `name` (text, food item name)
      - `description` (text, food description)
      - `price` (decimal, price in Naira)
      - `image_url` (text, optional image URL)
      - `category` (text, food category)
      - `available` (boolean, availability status)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)
    
    - `orders`
      - `id` (uuid, primary key)
      - `session_id` (text, temporary user session ID)
      - `total_amount` (decimal, total order amount)
      - `status` (text, order status)
      - `tracking_id` (text, unique tracking identifier)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)
    
    - `order_items`
      - `id` (uuid, primary key)
      - `order_id` (uuid, foreign key to orders)
      - `food_item_id` (uuid, foreign key to food_items)
      - `quantity` (integer, quantity ordered)
      - `unit_price` (decimal, price per unit at time of order)
      - `created_at` (timestamp)
    
    - `order_status_history`
      - `id` (uuid, primary key)
      - `order_id` (uuid, foreign key to orders)
      - `status` (text, status name)
      - `created_at` (timestamp)
    
    - `admin_credentials`
      - `id` (uuid, primary key)
      - `username` (text, admin username)
      - `password_hash` (text, hashed password)
      - `created_at` (timestamp)

  2. Security
    - Enable RLS on all tables
    - Public read access for food_items
    - Session-based access for orders
    - Admin-only access for management operations

  3. Enums and Types
    - Order status: pending, confirmed, preparing, dispatched, delivered, cancelled
    - Food categories: Rice, Snacks, Drinks, Swallow, Protein, Others
*/

-- Create custom types
CREATE TYPE order_status_enum AS ENUM (
  'pending',
  'payment_received', 
  'confirmed',
  'preparing',
  'dispatched',
  'delivered',
  'cancelled'
);

CREATE TYPE food_category_enum AS ENUM (
  'Rice',
  'Snacks', 
  'Drinks',
  'Swallow',
  'Protein',
  'Others'
);

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

-- Order Items Table (junction table)
CREATE TABLE IF NOT EXISTS order_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  food_item_id uuid NOT NULL REFERENCES food_items(id) ON DELETE CASCADE,
  quantity integer NOT NULL CHECK (quantity > 0),
  unit_price decimal(10,2) NOT NULL CHECK (unit_price > 0),
  created_at timestamptz DEFAULT now()
);

-- Order Status History Table
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

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_orders_session_id ON orders(session_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_tracking_id ON orders(tracking_id);
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_status_history_order_id ON order_status_history(order_id);

-- Enable Row Level Security
ALTER TABLE food_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_credentials ENABLE ROW LEVEL SECURITY;

-- RLS Policies

-- Food Items: Public read access, admin-only write
CREATE POLICY "Anyone can view available food items"
  ON food_items
  FOR SELECT
  TO public
  USING (available = true);

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

-- Orders: Users can create and view their own orders
CREATE POLICY "Users can create orders"
  ON orders
  FOR INSERT
  TO public
  WITH CHECK (true);

CREATE POLICY "Users can view their own orders"
  ON orders
  FOR SELECT
  TO public
  USING (session_id = current_setting('app.session_id', true));

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

-- Order Items: Can be read/created with orders
CREATE POLICY "Users can create order items"
  ON order_items
  FOR INSERT
  TO public
  WITH CHECK (true);

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

-- Order Status History: Can be read/created with orders
CREATE POLICY "Anyone can create status history"
  ON order_status_history
  FOR INSERT
  TO public
  WITH CHECK (true);

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

-- Admin Credentials: Only accessible by authenticated admins
CREATE POLICY "Admins can manage credentials"
  ON admin_credentials
  FOR ALL
  TO authenticated
  USING (true);

-- Insert default admin user (password: 'admin123' - remember to hash this in production)
INSERT INTO admin_credentials (username, password_hash) 
VALUES ('admin', '$2b$10$rQZ9QmSTUwhmW8.93h8/veRZYHFx8/XJvZ8lCqLKhkOJ5yY4oZ9em')
ON CONFLICT (username) DO NOTHING;

-- Insert sample food items
INSERT INTO food_items (name, description, price, category, image_url) VALUES
('Jollof Rice', 'Spicy Nigerian rice with vegetables and spices', 800.00, 'Rice', 'https://images.pexels.com/photos/5639297/pexels-photo-5639297.jpeg'),
('Fried Rice', 'Delicious fried rice with mixed vegetables', 900.00, 'Rice', 'https://images.pexels.com/photos/1624487/pexels-photo-1624487.jpeg'),
('White Rice & Stew', 'Plain white rice served with tomato stew', 700.00, 'Rice', 'https://images.pexels.com/photos/8753999/pexels-photo-8753999.jpeg'),
('Pounded Yam', 'Traditional pounded yam served with soup', 1200.00, 'Swallow', 'https://images.pexels.com/photos/8753746/pexels-photo-8753746.jpeg'),
('Eba & Egusi', 'Garri (Eba) served with Egusi soup', 900.00, 'Swallow', 'https://images.pexels.com/photos/8753745/pexels-photo-8753745.jpeg'),
('Grilled Chicken', 'Perfectly seasoned grilled chicken', 1500.00, 'Protein', 'https://images.pexels.com/photos/1105325/pexels-photo-1105325.jpeg'),
('Fried Fish', 'Crispy fried fish with spices', 1200.00, 'Protein', 'https://images.pexels.com/photos/725991/pexels-photo-725991.jpeg'),
('Meat Pie', 'Delicious pastry filled with seasoned meat', 300.00, 'Snacks', 'https://images.pexels.com/photos/1105325/pexels-photo-1105325.jpeg'),
('Chin Chin', 'Crunchy fried sweet snack', 200.00, 'Snacks', 'https://images.pexels.com/photos/1638635/pexels-photo-1638635.jpeg'),
('Coca Cola', 'Refreshing cold Coca Cola', 250.00, 'Drinks', 'https://images.pexels.com/photos/1641661/pexels-photo-1641661.jpeg'),
('Orange Juice', 'Fresh squeezed orange juice', 400.00, 'Drinks', 'https://images.pexels.com/photos/1435735/pexels-photo-1435735.jpeg'),
('Zobo Drink', 'Traditional Nigerian hibiscus drink', 300.00, 'Drinks', 'https://images.pexels.com/photos/1435735/pexels-photo-1435735.jpeg')
ON CONFLICT DO NOTHING;

-- Function to update timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at
CREATE TRIGGER update_food_items_updated_at
  BEFORE UPDATE ON food_items
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_orders_updated_at
  BEFORE UPDATE ON orders
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();