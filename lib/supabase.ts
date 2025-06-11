import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error('Missing Supabase environment variables. Please check your .env.local file.');
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
  realtime: {
    params: {
      eventsPerSecond: 10,
    },
  },
});

// Admin client with service role key for admin operations
const supabaseServiceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

export const supabaseAdmin = supabaseServiceRoleKey 
  ? createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false
      }
    })
  : null;

// Database types
export interface FoodItem {
  id: string;
  name: string;
  description: string;
  price: number;
  image_url: string;
  category: 'Rice' | 'Snacks' | 'Drinks' | 'Swallow' | 'Protein' | 'Others';
  available: boolean;
  created_at: string;
  updated_at: string;
}

export interface Order {
  id: string;
  session_id: string;
  total_amount: number;
  status: 'pending' | 'payment_received' | 'confirmed' | 'preparing' | 'dispatched' | 'delivered' | 'cancelled';
  tracking_id: string;
  customer_note: string;
  created_at: string;
  updated_at: string;
}

export interface OrderItem {
  id: string;
  order_id: string;
  food_item_id: string;
  quantity: number;
  unit_price: number;
  created_at: string;
  food_items?: FoodItem;
}

export interface OrderStatusHistory {
  id: string;
  order_id: string;
  status: Order['status'];
  created_at: string;
}

export interface CartItem {
  id: string;
  name: string;
  price: number;
  quantity: number;
  image_url: string;
}