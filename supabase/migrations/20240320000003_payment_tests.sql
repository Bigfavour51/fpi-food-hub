-- Test 1: Verify bank details table and sample data
SELECT 
    bank_name,
    account_number,
    account_name,
    is_active
FROM bank_details
ORDER BY created_at DESC;

-- Test 2: Create a new order with payment status
DO $$
DECLARE
    v_session_id UUID := uuid_generate_v4();
    v_tracking_id VARCHAR := 'PAYMENT-TEST-' || to_char(current_timestamp, 'YYYYMMDD-HH24MISS');
    v_order_items JSONB;
    v_result JSONB;
BEGIN
    -- Prepare order items
    v_order_items := jsonb_build_array(
        jsonb_build_object(
            'food_item_id', (SELECT id FROM food_items WHERE name = 'Jollof Rice'),
            'quantity', 2,
            'unit_price', 1500.00
        ),
        jsonb_build_object(
            'food_item_id', (SELECT id FROM food_items WHERE name = 'Chicken Wings'),
            'quantity', 1,
            'unit_price', 2000.00
        )
    );

    -- Create order
    SELECT create_order_with_items(
        v_session_id,
        5000.00, -- Total amount (2*1500 + 1*2000)
        v_tracking_id,
        'Please confirm payment via bank transfer',
        v_order_items
    ) INTO v_result;

    -- Display result
    RAISE NOTICE 'Created order with payment pending: %', v_result;
END $$;

-- Test 3: Verify order with payment status
SELECT 
    o.id,
    o.tracking_id,
    o.total_amount,
    o.status,
    o.payment_status,
    o.customer_note,
    jsonb_agg(
        jsonb_build_object(
            'item_name', f.name,
            'quantity', oi.quantity,
            'unit_price', oi.unit_price,
            'subtotal', oi.quantity * oi.unit_price
        )
    ) as items
FROM orders o
JOIN order_items oi ON o.id = oi.order_id
JOIN food_items f ON oi.food_item_id = f.id
WHERE o.tracking_id LIKE 'PAYMENT-TEST-%'
GROUP BY o.id, o.tracking_id, o.total_amount, o.status, o.payment_status, o.customer_note;

-- Test 4: Confirm payment as admin
DO $$
DECLARE
    v_order_id UUID;
    v_admin_id UUID;
    v_result JSONB;
BEGIN
    -- Get the most recent test order
    SELECT id INTO v_order_id 
    FROM orders 
    WHERE tracking_id LIKE 'PAYMENT-TEST-%'
    ORDER BY created_at DESC 
    LIMIT 1;

    -- Get admin ID
    SELECT id INTO v_admin_id 
    FROM admin_credentials 
    WHERE username = 'admin';

    -- Confirm payment
    SELECT confirm_payment(
        v_order_id,
        v_admin_id,
        'Payment received via bank transfer'
    ) INTO v_result;

    -- Display result
    RAISE NOTICE 'Payment confirmed: %', v_result;
END $$;

-- Test 5: Verify payment confirmation
SELECT 
    o.tracking_id,
    o.status,
    o.payment_status,
    o.payment_confirmed_at,
    ac.username as confirmed_by,
    pch.note as payment_note
FROM orders o
JOIN admin_credentials ac ON o.payment_confirmed_by = ac.id
JOIN payment_confirmation_history pch ON o.id = pch.order_id
WHERE o.tracking_id LIKE 'PAYMENT-TEST-%'
ORDER BY pch.created_at DESC;

-- Test 6: Verify order status history after payment
SELECT 
    o.tracking_id,
    osh.status,
    osh.note,
    osh.created_at
FROM orders o
JOIN order_status_history osh ON o.id = osh.order_id
WHERE o.tracking_id LIKE 'PAYMENT-TEST-%'
ORDER BY osh.created_at DESC;

-- Test 7: Add new bank account
DO $$
DECLARE
    v_admin_id UUID;
BEGIN
    -- Get admin ID
    SELECT id INTO v_admin_id 
    FROM admin_credentials 
    WHERE username = 'admin';

    -- Insert new bank account
    INSERT INTO bank_details (
        bank_name,
        account_number,
        account_name,
        created_by
    ) VALUES (
        'UBA',
        '1122334455',
        'FPI Food Hub',
        v_admin_id
    );

    RAISE NOTICE 'Added new bank account';
END $$;

-- Test 8: Verify all active bank accounts
SELECT 
    bank_name,
    account_number,
    account_name,
    is_active,
    created_at
FROM bank_details
WHERE is_active = true
ORDER BY created_at DESC;

-- Test 9: Deactivate a bank account
UPDATE bank_details
SET is_active = false
WHERE bank_name = 'Access Bank'
RETURNING bank_name, account_number, is_active;

-- Test 10: Verify bank account deactivation
SELECT 
    bank_name,
    account_number,
    account_name,
    is_active
FROM bank_details
WHERE bank_name = 'Access Bank';

-- Test 11: Clean up test data (optional)
-- DELETE FROM payment_confirmation_history WHERE order_id IN (SELECT id FROM orders WHERE tracking_id LIKE 'PAYMENT-TEST-%');
-- DELETE FROM order_status_history WHERE order_id IN (SELECT id FROM orders WHERE tracking_id LIKE 'PAYMENT-TEST-%');
-- DELETE FROM order_items WHERE order_id IN (SELECT id FROM orders WHERE tracking_id LIKE 'PAYMENT-TEST-%');
-- DELETE FROM orders WHERE tracking_id LIKE 'PAYMENT-TEST-%'; 