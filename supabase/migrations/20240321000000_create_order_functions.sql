-- Drop the function if it exists
DROP FUNCTION IF EXISTS create_order_with_items;

-- Create the function with proper RPC configuration
CREATE OR REPLACE FUNCTION create_order_with_items(
  p_session_id text,
  p_total_amount decimal,
  p_tracking_id text,
  p_order_items jsonb,
  p_customer_note text DEFAULT ''
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order_id uuid;
  v_order jsonb;
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
    INSERT INTO order_items (
      order_id,
      food_item_id,
      quantity,
      unit_price
    )
    SELECT
      v_order_id,
      (item->>'food_item_id')::uuid,
      (item->>'quantity')::integer,
      (item->>'unit_price')::decimal
    FROM jsonb_array_elements(p_order_items) AS item;

    -- Record initial status
    INSERT INTO order_status_history (order_id, status)
    VALUES (v_order_id, 'pending');

    -- Get complete order with items
    SELECT jsonb_build_object(
      'order', o,
      'items', (
        SELECT jsonb_agg(
          jsonb_build_object(
            'id', oi.id,
            'food_item', fi,
            'quantity', oi.quantity,
            'unit_price', oi.unit_price
          )
        )
        FROM order_items oi
        JOIN food_items fi ON fi.id = oi.food_item_id
        WHERE oi.order_id = o.id
      )
    )
    INTO v_order
    FROM orders o
    WHERE o.id = v_order_id;

    RETURN v_order;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE;
  END;
END;
$$;

-- Grant execute permission to authenticated users and anon
GRANT EXECUTE ON FUNCTION create_order_with_items TO authenticated;
GRANT EXECUTE ON FUNCTION create_order_with_items TO anon;

-- Enable RPC
ALTER FUNCTION create_order_with_items(text, decimal, text, jsonb, text) SET search_path = public;

-- Create a test function to verify the order creation
CREATE OR REPLACE FUNCTION test_create_order()
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_result jsonb;
BEGIN
  -- Test data
  v_result := create_order_with_items(
    'test-session-' || gen_random_uuid(),
    1500.00,
    'TEST-' || gen_random_uuid(),
    jsonb_build_array(
      jsonb_build_object(
        'food_item_id', (SELECT id FROM food_items LIMIT 1),
        'quantity', 2,
        'unit_price', 750.00
      )
    ),
    'Test order'
  );
  
  RAISE NOTICE 'Test order created successfully: %', v_result;
END;
$$; 