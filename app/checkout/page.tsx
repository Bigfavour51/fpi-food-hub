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
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';

export default function CheckoutPage() {
  const router = useRouter();
  const [isLoading, setIsLoading] = useState(false);
  const [customerNote, setCustomerNote] = useState('');
  const [pickupLocation, setPickupLocation] = useState('');
  const cartItems = getCart();
  const total = getCartTotal();
  const pickupLocations = [
    'ASUP Hall',
    'Blue Roof',
    'UBA Bank',
    'Mass Communication Studio',
    'BA Block',
    'Complex',
    'School Farm',
  ];

  const handleCheckout = async () => {
    if (cartItems.length === 0) {
      toast.error('Your cart is empty');
      return;
    }
    if (!pickupLocation) {
      toast.error('Please select a pickup location');
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
        })),
        p_pickup_location: pickupLocation,
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
          <CardTitle>Pickup Location</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium mb-2">
                Select Pickup Location <span className="text-red-500">*</span>
              </label>
              <Select value={pickupLocation} onValueChange={setPickupLocation}>
                <SelectTrigger className="w-full">
                  <SelectValue placeholder="Choose a location..." />
                </SelectTrigger>
                <SelectContent>
                  {pickupLocations.map((loc) => (
                    <SelectItem key={loc} value={loc}>{loc}</SelectItem>
                  ))}
                </SelectContent>
              </Select>
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
      <Card className="mb-8">
        <CardHeader>
          <CardTitle>Payment Details</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="space-y-2">
            <div className="bg-gray-50 p-4 rounded-lg">
              <p className="text-sm text-gray-600 mb-2">Please make payment to:</p>
              <div className="space-y-2">
                <p className="font-medium">Acct Name: FPI FOOD HUB</p>
                <p className="font-medium">Acct No.: 3154810242</p>
                <p className="font-medium">Bank Name: FIRST BANK PLC</p>
              </div>
            </div>
            <div className="text-sm text-yellow-700 bg-yellow-50 border-l-4 border-yellow-400 p-3 rounded">
              Make payment of the <span className="font-semibold">exact total amount</span> above, then click the <span className="font-semibold">"Place Order"</span> button to complete your order.
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