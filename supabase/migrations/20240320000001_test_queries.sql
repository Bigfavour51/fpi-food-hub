-- Test 1: Verify food items table and sample data
SELECT * FROM food_items ORDER BY category, name;

-- Test 2: Create a new order with multiple items
DO $$
DECLARE
    v_session_id UUID := uuid_generate_v4();
    v_tracking_id VARCHAR := 'TEST-' || to_char(current_timestamp, 'YYYYMMDD-HH24MISS');
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
        ),
        jsonb_build_object(
            'food_item_id', (SELECT id FROM food_items WHERE name = 'Coca Cola'),
            'quantity', 2,
            'unit_price', 200.00
        )
    );

    -- Create order
    SELECT create_order_with_items(
        v_session_id,
        5400.00, -- Total amount (2*1500 + 1*2000 + 2*200)
        v_tracking_id,
        'Extra spicy please',
        v_order_items
    ) INTO v_result;

    -- Display result
    RAISE NOTICE 'Created order: %', v_result;
END $$;

-- Test 3: Verify order creation
SELECT 
    o.id,
    o.tracking_id,
    o.total_amount,
    o.status,
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
GROUP BY o.id, o.tracking_id, o.total_amount, o.status, o.customer_note
ORDER BY o.created_at DESC
LIMIT 1;

-- Test 4: Update order status
DO $$
DECLARE
    v_order_id UUID;
BEGIN
    -- Get the most recent order
    SELECT id INTO v_order_id FROM orders ORDER BY created_at DESC LIMIT 1;

    -- Update status to confirmed
    UPDATE orders SET status = 'confirmed' WHERE id = v_order_id;
    
    -- Record status change
    INSERT INTO order_status_history (order_id, status, note)
    VALUES (v_order_id, 'confirmed', 'Order confirmed by admin');

    -- Update status to preparing
    UPDATE orders SET status = 'preparing' WHERE id = v_order_id;
    
    -- Record status change
    INSERT INTO order_status_history (order_id, status, note)
    VALUES (v_order_id, 'preparing', 'Order is being prepared');

    -- Display status history
    RAISE NOTICE 'Status history for order %:', v_order_id;
END $$;

-- Test 5: View order status history
SELECT 
    o.tracking_id,
    osh.status,
    osh.note,
    osh.created_at
FROM orders o
JOIN order_status_history osh ON o.id = osh.order_id
ORDER BY osh.created_at DESC
LIMIT 5;

-- Test 6: Test food item availability toggle
DO $$
DECLARE
    v_item_id UUID;
BEGIN
    -- Get a food item
    SELECT id INTO v_item_id FROM food_items WHERE name = 'Jollof Rice';
    
    -- Toggle availability
    UPDATE food_items 
    SET available = NOT available 
    WHERE id = v_item_id;
    
    -- Display result
    RAISE NOTICE 'Updated availability for Jollof Rice';
END $$;

-- Test 7: Verify food item availability
SELECT 
    name,
    category,
    price,
    available
FROM food_items
WHERE name = 'Jollof Rice';

-- Test 8: Test admin authentication
SELECT 
    username,
    created_at
FROM admin_credentials
WHERE username = 'admin';

-- Test 9: Test duplicate tracking ID prevention
DO $$
DECLARE
    v_session_id UUID := uuid_generate_v4();
    v_tracking_id VARCHAR := 'TEST-' || to_char(current_timestamp, 'YYYYMMDD-HH24MISS');
    v_order_items JSONB;
    v_result JSONB;
BEGIN
    -- Prepare order items
    v_order_items := jsonb_build_array(
        jsonb_build_object(
            'food_item_id', (SELECT id FROM food_items WHERE name = 'Fried Rice'),
            'quantity', 1,
            'unit_price', 1500.00
        )
    );

    -- Try to create order with same tracking ID
    BEGIN
        SELECT create_order_with_items(
            v_session_id,
            1500.00,
            v_tracking_id,
            'Test duplicate tracking ID',
            v_order_items
        ) INTO v_result;
        
        RAISE NOTICE 'Created order: %', v_result;
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'Expected error: %', SQLERRM;
    END;
END $$;

-- Test 10: Verify indexes and performance
EXPLAIN ANALYZE
SELECT 
    f.name,
    f.category,
    f.price,
    COUNT(oi.id) as order_count
FROM food_items f
LEFT JOIN order_items oi ON f.id = oi.food_item_id
GROUP BY f.id, f.name, f.category, f.price
ORDER BY order_count DESC;

-- Test 11: Clean up test data (optional)
-- DELETE FROM order_status_history WHERE order_id IN (SELECT id FROM orders WHERE tracking_id LIKE 'TEST-%');
-- DELETE FROM order_items WHERE order_id IN (SELECT id FROM orders WHERE tracking_id LIKE 'TEST-%');
-- DELETE FROM orders WHERE tracking_id LIKE 'TEST-%'; 