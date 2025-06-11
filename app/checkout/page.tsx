'use client';

import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { CreditCard, MapPin, User, MessageCircle } from 'lucide-react';
import Navigation from '@/components/Navigation';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Separator } from '@/components/ui/separator';
import { getCart, getCartTotal, clearCart, CartItem } from '@/lib/cart';
import { getSessionId, generateTrackingId } from '@/lib/session';
import { supabase } from '@/lib/supabase';
import { toast } from 'sonner';

export default function CheckoutPage() {
  const [cart, setCart] = useState<CartItem[]>([]);
  const [total, setTotal] = useState(0);
  const [isProcessing, setIsProcessing] = useState(false);
  const [customerNote, setCustomerNote] = useState('');
  const router = useRouter();

  useEffect(() => {
    const cartItems = getCart();
    const cartTotal = getCartTotal();
    
    if (cartItems.length === 0) {
      router.push('/');
      return;
    }
    
    setCart(cartItems);
    setTotal(cartTotal);
  }, [router]);

  const handlePlaceOrder = async () => {
    setIsProcessing(true);

    try {
      // Validate cart
      if (cart.length === 0) {
        throw new Error('Cart is empty');
      }

      // Validate total amount
      if (total <= 0) {
        throw new Error('Invalid order total');
      }

      const sessionId = getSessionId();
      const trackingId = generateTrackingId();

      // Start a transaction
      const { data: order, error: orderError } = await supabase.rpc('create_order_with_items', {
        p_session_id: sessionId,
        p_total_amount: total,
        p_tracking_id: trackingId,
        p_customer_note: customerNote,
        p_order_items: cart.map(item => ({
          food_item_id: item.id,
          quantity: item.quantity,
          unit_price: item.price
        }))
      });

      if (orderError) {
        console.error('Error creating order:', orderError);
        throw new Error(orderError.message);
      }

      // Clear cart and redirect
      clearCart();
      toast.success('Order placed successfully!');
      router.push(`/order-success?tracking=${trackingId}`);
      
    } catch (error) {
      console.error('Error placing order:', error);
      
      // Handle specific error cases
      if (error instanceof Error) {
        if (error.message.includes('duplicate key')) {
          toast.error('This order has already been placed. Please try again.');
        } else if (error.message.includes('cart is empty')) {
          toast.error('Your cart is empty. Please add items before placing an order.');
        } else if (error.message.includes('invalid order total')) {
          toast.error('Invalid order total. Please try again.');
        } else {
          toast.error('Failed to place order. Please try again.');
        }
      } else {
        toast.error('An unexpected error occurred. Please try again.');
      }
    } finally {
      setIsProcessing(false);
    }
  };

  if (cart.length === 0) {
    return null; // Will redirect in useEffect
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <Navigation />
      
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
          {/* Order Summary */}
          <div>
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center">
                  <CreditCard className="h-5 w-5 mr-2" />
                  Order Summary
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                {cart.map((item) => (
                  <div key={item.id} className="flex justify-between items-center">
                    <div className="flex items-center space-x-3">
                      <div className="w-12 h-12 bg-gray-200 rounded-lg overflow-hidden">
                        <img
                          src={item.image_url || '/api/placeholder/48/48'}
                          alt={item.name}
                          className="w-full h-full object-cover"
                        />
                      </div>
                      <div>
                        <h4 className="font-medium">{item.name}</h4>
                        <p className="text-sm text-gray-600">Qty: {item.quantity}</p>
                      </div>
                    </div>
                    <span className="font-semibold">
                      ₦{(item.price * item.quantity).toLocaleString()}
                    </span>
                  </div>
                ))}
                
                <Separator />
                
                <div className="flex justify-between items-center text-lg font-bold">
                  <span>Total:</span>
                  <span className="text-green-600">₦{total.toLocaleString()}</span>
                </div>
              </CardContent>
            </Card>
          </div>

          {/* Order Details */}
          <div className="space-y-6">
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center">
                  <MessageCircle className="h-5 w-5 mr-2" />
                  Additional Information
                </CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-4">
                  <div>
                    <Label htmlFor="note">Special Instructions (Optional)</Label>
                    <Textarea
                      id="note"
                      placeholder="Any special requests or delivery instructions..."
                      value={customerNote}
                      onChange={(e) => setCustomerNote(e.target.value)}
                      rows={4}
                    />
                  </div>
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>Payment Simulation</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-4">
                  <p className="text-blue-800 text-sm">
                    <strong>Demo Mode:</strong> This is a simulated payment process. 
                    No actual payment will be processed.
                  </p>
                </div>
                
                <div className="space-y-3">
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-gray-600">Subtotal:</span>
                    <span>₦{total.toLocaleString()}</span>
                  </div>
                  <div className="flex items-center justify-between text-sm">
                    <span className="text-gray-600">Delivery Fee:</span>
                    <span className="text-green-600">Free</span>
                  </div>
                  <Separator />
                  <div className="flex items-center justify-between font-semibold">
                    <span>Total Amount:</span>
                    <span className="text-green-600">₦{total.toLocaleString()}</span>
                  </div>
                </div>
              </CardContent>
            </Card>

            <Button
              onClick={handlePlaceOrder}
              disabled={isProcessing}
              className="w-full bg-green-600 hover:bg-green-700 text-white py-3 text-lg"
            >
              {isProcessing ? 'Processing Order...' : `Place Order - ₦${total.toLocaleString()}`}
            </Button>

            <p className="text-xs text-gray-500 text-center">
              By placing this order, you agree to our terms and conditions. 
              You will receive real-time updates about your order status.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}