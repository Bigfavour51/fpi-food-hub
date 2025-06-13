#!/bin/bash

# Check if .env.local exists
if [ ! -f .env.local ]; then
    echo "Error: .env.local file not found!"
    echo "Please create a .env.local file with your Supabase credentials:"
    echo "NEXT_PUBLIC_SUPABASE_URL=your_supabase_url"
    echo "NEXT_PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key"
    echo "SUPABASE_SERVICE_ROLE_KEY=your_service_role_key"
    exit 1
fi

# Load environment variables
source .env.local

# Apply the migration using Supabase CLI
echo "Applying migration to Supabase..."
supabase db push

# Test the function
echo "Testing the create_order_with_items function..."
curl -X POST "${NEXT_PUBLIC_SUPABASE_URL}/rest/v1/rpc/create_order_with_items" \
  -H "apikey: ${NEXT_PUBLIC_SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "p_session_id": "test-session-'$(date +%s)'",
    "p_total_amount": 1500.00,
    "p_tracking_id": "TEST-'$(date +%s)'",
    "p_customer_note": "Test order",
    "p_order_items": [
      {
        "food_item_id": "00000000-0000-0000-0000-000000000000",
        "quantity": 2,
        "unit_price": 750.00
      }
    ]
  }' 