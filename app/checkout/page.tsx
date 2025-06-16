'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Separator } from '@/components/ui/separator';
import { getCart, getCartTotal, clearCart, CartItem } from '@/lib/cart';
import { getSessionId, generateTrackingId } from '@/lib/session';
import { supabase } from '@/lib/supabase';
import { toast } from 'sonner';

export default function CheckoutPage() {
  const router = useRouter();
  const [isLoading, setIsLoading] = useState(false);
  const [customerNote, setCustomerNote] = useState('');
  const cartItems = getCart();
  const total = getCartTotal();

  const handleCheckout = async () => {
    if (cartItems.length === 0) {
      toast.error('Your cart is empty');
      return;
    }

    setIsLoading(true);
    try {
      const sessionId = getSessionId();
      const trackingId = generateTrackingId();

      const { data, error } = await supabase.rpc('create_order_with_items', {
        p_session_id: sessionId,
        p_total_amount: total,
        p_tracking_id: trackingId,
        p_customer_note: customerNote,
        p_order_items: cartItems.map(item => ({
          food_item_id: item.id,
          quantity: item.quantity,
          unit_price: item.price
        }))
      });

      if (error) throw error;

      clearCart();
      toast.success('Order placed successfully!');
      router.push(`/order-success?tracking=${trackingId}`);
    } catch (error) {
      console.error('Checkout error:', error);
      toast.error('Failed to place order. Please try again.');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="container max-w-2xl py-8">
      <h1 className="text-3xl font-bold mb-8">Checkout</h1>
      
      <Card className="mb-8">
        <CardHeader>
          <CardTitle>Order Summary</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            {cartItems.map((item) => (
              <div key={item.id} className="flex justify-between items-center">
                <div>
                  <p className="font-medium">{item.name}</p>
                  <p className="text-sm text-gray-500">Qty: {item.quantity}</p>
                </div>
                <p className="font-medium">₦{(item.price * item.quantity).toLocaleString()}</p>
              </div>
            ))}
            <Separator />
            <div className="flex justify-between items-center font-bold">
              <p>Total</p>
              <p>₦{total.toLocaleString()}</p>
            </div>
          </div>
        </CardContent>
      </Card>

      <Card className="mb-8">
        <CardHeader>
          <CardTitle>Additional Information</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium mb-2">
                Customer Note (Optional)
              </label>
              <Textarea
                value={customerNote}
                onChange={(e) => setCustomerNote(e.target.value)}
                placeholder="Add any special instructions or notes..."
                className="h-24"
              />
            </div>
          </div>
        </CardContent>
      </Card>

      <Button
        onClick={handleCheckout}
        disabled={isLoading || cartItems.length === 0}
        className="w-full"
      >
        {isLoading ? 'Processing...' : 'Place Order'}
      </Button>
    </div>
  );
}