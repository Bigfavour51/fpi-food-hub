import { supabase, supabaseAdmin } from './supabase';
import { v4 as uuidv4 } from 'uuid';

async function testDatabase() {
  console.log('Starting database tests...\n');

  try {
    // 1. Test Food Items
    console.log('1. Testing Food Items...');
    const { data: foodItems, error: foodError } = await supabase
      .from('food_items')
      .select('*')
      .limit(5);
    
    if (foodError) throw foodError;
    console.log('✓ Food items retrieved successfully');
    console.log('Sample food items:', foodItems);

    // 2. Test Order Creation
    console.log('\n2. Testing Order Creation...');
    const testOrder = {
      session_id: uuidv4(),
      total_amount: 1500.00,
      tracking_id: `TEST-${Date.now()}`,
      customer_note: 'Test order'
    };

    const { data: order, error: orderError } = await supabase
      .from('orders')
      .insert(testOrder)
      .select()
      .single();

    if (orderError) throw orderError;
    console.log('✓ Order created successfully');
    console.log('Created order:', order);

    // 3. Test Order Items
    console.log('\n3. Testing Order Items...');
    if (foodItems && foodItems.length > 0) {
      const testOrderItem = {
        order_id: order.id,
        food_item_id: foodItems[0].id,
        quantity: 2,
        unit_price: foodItems[0].price
      };

      const { data: orderItem, error: orderItemError } = await supabase
        .from('order_items')
        .insert(testOrderItem)
        .select()
        .single();

      if (orderItemError) throw orderItemError;
      console.log('✓ Order item created successfully');
      console.log('Created order item:', orderItem);
    }

    // 4. Test Order Status History
    console.log('\n4. Testing Order Status History...');
    const { data: statusHistory, error: statusError } = await supabase
      .from('order_status_history')
      .select('*')
      .eq('order_id', order.id)
      .order('created_at', { ascending: false });

    if (statusError) throw statusError;
    console.log('✓ Order status history retrieved successfully');
    console.log('Status history:', statusHistory);

    // 5. Test Payment Processing
    console.log('\n5. Testing Payment Processing...');
    const testPayment = {
      order_id: order.id,
      amount: testOrder.total_amount,
      status: 'processing',
      payment_method: 'card_payment',
      reference: `PAY-${Date.now()}`,
      metadata: { test: true }
    };

    const { data: payment, error: paymentError } = await supabase
      .from('payment_history')
      .insert(testPayment)
      .select()
      .single();

    if (paymentError) throw paymentError;
    console.log('✓ Payment record created successfully');
    console.log('Created payment:', payment);

    // 6. Test Bank Details
    console.log('\n6. Testing Bank Details...');
    const { data: bankDetails, error: bankError } = await supabase
      .from('bank_details')
      .select('*')
      .eq('is_active', true);

    if (bankError) throw bankError;
    console.log('✓ Bank details retrieved successfully');
    console.log('Active bank details:', bankDetails);

    console.log('\nAll tests completed successfully! 🎉');

  } catch (error) {
    console.error('Test failed:', error);
  }
}

// Run the tests
testDatabase(); 