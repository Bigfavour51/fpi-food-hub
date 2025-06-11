-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create enum types
CREATE TYPE order_status AS ENUM (
    'pending',
    'confirmed',
    'preparing',
    'ready_for_pickup',
    'delivered',
    'cancelled'
);

-- Create food_items table
CREATE TABLE food_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL CHECK (price > 0),
    image_url TEXT,
    category VARCHAR(50) NOT NULL,
    available BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create orders table
CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL CHECK (total_amount > 0),
    status order_status DEFAULT 'pending',
    tracking_id VARCHAR(50) UNIQUE,
    customer_note TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create order_items table
CREATE TABLE order_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    food_item_id UUID NOT NULL REFERENCES food_items(id) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price DECIMAL(10,2) NOT NULL CHECK (unit_price > 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(order_id, food_item_id)
);

-- Create order_status_history table
CREATE TABLE order_status_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    status order_status NOT NULL,
    note TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create admin_credentials table
CREATE TABLE admin_credentials (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at
CREATE TRIGGER update_food_items_updated_at
    BEFORE UPDATE ON food_items
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_orders_updated_at
    BEFORE UPDATE ON orders
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_admin_credentials_updated_at
    BEFORE UPDATE ON admin_credentials
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Create function for order creation with items
CREATE OR REPLACE FUNCTION create_order_with_items(
    p_session_id UUID,
    p_total_amount DECIMAL,
    p_tracking_id VARCHAR,
    p_customer_note TEXT,
    p_order_items JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_order_id UUID;
    v_item JSONB;
    v_result JSONB;
BEGIN
    -- Validate input
    IF p_total_amount <= 0 THEN
        RAISE EXCEPTION 'Total amount must be greater than 0';
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
            customer_note
        ) VALUES (
            p_session_id,
            p_total_amount,
            p_tracking_id,
            p_customer_note
        ) RETURNING id INTO v_order_id;

        -- Insert order items
        FOR v_item IN SELECT * FROM jsonb_array_elements(p_order_items)
        LOOP
            INSERT INTO order_items (
                order_id,
                food_item_id,
                quantity,
                unit_price
            ) VALUES (
                v_order_id,
                (v_item->>'food_item_id')::UUID,
                (v_item->>'quantity')::INTEGER,
                (v_item->>'unit_price')::DECIMAL
            );
        END LOOP;

        -- Record initial status
        INSERT INTO order_status_history (
            order_id,
            status,
            note
        ) VALUES (
            v_order_id,
            'pending',
            'Order created'
        );

        -- Get complete order data
        SELECT jsonb_build_object(
            'id', o.id,
            'session_id', o.session_id,
            'total_amount', o.total_amount,
            'status', o.status,
            'tracking_id', o.tracking_id,
            'customer_note', o.customer_note,
            'created_at', o.created_at,
            'items', (
                SELECT jsonb_agg(jsonb_build_object(
                    'id', oi.id,
                    'food_item_id', oi.food_item_id,
                    'quantity', oi.quantity,
                    'unit_price', oi.unit_price
                ))
                FROM order_items oi
                WHERE oi.order_id = o.id
            )
        ) INTO v_result
        FROM orders o
        WHERE o.id = v_order_id;

        RETURN v_result;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE;
    END;
END;
$$;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION create_order_with_items TO authenticated;
GRANT EXECUTE ON FUNCTION create_order_with_items TO anon;

-- Insert sample food items
INSERT INTO food_items (name, description, price, category, available) VALUES
    ('Jollof Rice', 'Classic Nigerian jollof rice with tomato sauce and spices', 1500.00, 'Rice', true),
    ('Fried Rice', 'Chinese-style fried rice with mixed vegetables', 1500.00, 'Rice', true),
    ('Chicken Wings', 'Crispy fried chicken wings with special sauce', 2000.00, 'Protein', true),
    ('Beef Stew', 'Rich and spicy beef stew with vegetables', 1800.00, 'Protein', true),
    ('Pounded Yam', 'Smooth pounded yam served with soup', 1200.00, 'Swallow', true),
    ('Eba', 'Garri-based swallow served with soup', 800.00, 'Swallow', true),
    ('Coca Cola', 'Refreshing carbonated drink', 200.00, 'Drinks', true),
    ('Water', 'Pure bottled water', 100.00, 'Drinks', true),
    ('Chin Chin', 'Crispy fried snack', 500.00, 'Snacks', true),
    ('Meat Pie', 'Flaky pastry filled with spiced minced meat', 300.00, 'Snacks', true);

-- Insert default admin credentials (password: admin123)
INSERT INTO admin_credentials (username, password_hash) VALUES
    ('admin', '$2a$10$rM7yDZ4x5Y5Y5Y5Y5Y5Y5O5Y5Y5Y5Y5Y5Y5Y5Y5Y5Y5Y5Y5Y5Y');

-- Create indexes for better performance
CREATE INDEX idx_food_items_category ON food_items(category);
CREATE INDEX idx_food_items_available ON food_items(available);
CREATE INDEX idx_orders_session_id ON orders(session_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_tracking_id ON orders(tracking_id);
CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_food_item_id ON order_items(food_item_id);
CREATE INDEX idx_order_status_history_order_id ON order_status_history(order_id);
CREATE INDEX idx_order_status_history_status ON order_status_history(status); 