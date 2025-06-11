-- Create payment_status enum
CREATE TYPE payment_status AS ENUM (
    'pending',
    'confirmed',
    'rejected'
);

-- Add payment_status to orders table
ALTER TABLE orders 
ADD COLUMN payment_status payment_status DEFAULT 'pending',
ADD COLUMN payment_confirmed_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN payment_confirmed_by UUID REFERENCES admin_credentials(id);

-- Create bank_details table
CREATE TABLE bank_details (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    bank_name VARCHAR(100) NOT NULL,
    account_number VARCHAR(20) NOT NULL,
    account_name VARCHAR(100) NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES admin_credentials(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create payment_confirmation_history table
CREATE TABLE payment_confirmation_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
    confirmed_by UUID REFERENCES admin_credentials(id),
    status payment_status NOT NULL,
    note TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create trigger for bank_details updated_at
CREATE TRIGGER update_bank_details_updated_at
    BEFORE UPDATE ON bank_details
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Create function to confirm payment
CREATE OR REPLACE FUNCTION confirm_payment(
    p_order_id UUID,
    p_admin_id UUID,
    p_note TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSONB;
BEGIN
    -- Update order payment status
    UPDATE orders
    SET 
        payment_status = 'confirmed',
        payment_confirmed_at = CURRENT_TIMESTAMP,
        payment_confirmed_by = p_admin_id
    WHERE id = p_order_id
    RETURNING jsonb_build_object(
        'id', id,
        'tracking_id', tracking_id,
        'payment_status', payment_status,
        'payment_confirmed_at', payment_confirmed_at
    ) INTO v_result;

    -- Record in payment confirmation history
    INSERT INTO payment_confirmation_history (
        order_id,
        confirmed_by,
        status,
        note
    ) VALUES (
        p_order_id,
        p_admin_id,
        'confirmed',
        p_note
    );

    -- Update order status to confirmed
    UPDATE orders
    SET status = 'confirmed'
    WHERE id = p_order_id;

    -- Record in order status history
    INSERT INTO order_status_history (
        order_id,
        status,
        note
    ) VALUES (
        p_order_id,
        'confirmed',
        'Payment confirmed: ' || COALESCE(p_note, 'No additional notes')
    );

    RETURN v_result;
END;
$$;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION confirm_payment TO authenticated;

-- Insert sample bank details
INSERT INTO bank_details (bank_name, account_number, account_name, created_by)
VALUES 
    ('First Bank', '1234567890', 'FPI Food Hub', (SELECT id FROM admin_credentials WHERE username = 'admin')),
    ('Access Bank', '0987654321', 'FPI Food Hub', (SELECT id FROM admin_credentials WHERE username = 'admin'));

-- Create indexes for better performance
CREATE INDEX idx_orders_payment_status ON orders(payment_status);
CREATE INDEX idx_bank_details_is_active ON bank_details(is_active);
CREATE INDEX idx_payment_confirmation_history_order_id ON payment_confirmation_history(order_id); 