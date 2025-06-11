'use client';

import { useState, useEffect } from 'react';
import { useSearchParams } from 'next/navigation';
import Link from 'next/link';
import { CheckCircle, Clock, Package, Truck, ChefHat } from 'lucide-react';
import Navigation from '@/components/Navigation';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { supabase, Order, OrderItem } from '@/lib/supabase';
import { getSessionId } from '@/lib/session';
import { format } from 'date-fns';

interface OrderWithItems extends Order {
  order_items: (OrderItem & { food_items: { name: string; price: number } })[];
}

export default function OrderSuccessPage() {
  const searchParams = useSearchParams();
  const trackingId = searchParams.get('tracking');
  const [order, setOrder] = useState<OrderWithItems | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (trackingId) {
      fetchOrder();
      
      // Subscribe to real-time order updates
      const channel = supabase
        .channel('order-status')
        .on(
          'postgres_changes',
          {
            event: 'UPDATE',
            schema: 'public',
            table: 'orders',
            filter: `tracking_id=eq.${trackingId}`,
          },
          () => {
            fetchOrder();
          }
        )
        .subscribe();

      return () => {
        channel.unsubscribe();
      };
    }
  }, [trackingId]);

  const fetchOrder = async () => {
    if (!trackingId) return;

    const { data, error } = await supabase
      .from('orders')
      .select(`
        *,
        order_items (
          *,
          food_items (
            name,
            price
          )
        )
      `)
      .eq('tracking_id', trackingId)
      .eq('session_id', getSessionId())
      .single();

    if (error) {
      console.error('Error fetching order:', error);
    } else {
      setOrder(data);
    }
    
    setLoading(false);
  };

  const getStatusIcon = (status: Order['status']) => {
    switch (status) {
      case 'pending':
        return <Clock className="h-5 w-5" />;
      case 'payment_received':
      case 'confirmed':
        return <CheckCircle className="h-5 w-5" />;
      case 'preparing':
        return <ChefHat className="h-5 w-5" />;
      case 'dispatched':
        return <Truck className="h-5 w-5" />;
      case 'delivered':
        return <CheckCircle className="h-5 w-5" />;
      default:
        return <Package className="h-5 w-5" />;
    }
  };

  const getStatusColor = (status: Order['status']) => {
    switch (status) {
      case 'pending':
        return 'bg-yellow-100 text-yellow-800';
      case 'payment_received':
        return 'bg-blue-100 text-blue-800';
      case 'confirmed':
        return 'bg-green-100 text-green-800';
      case 'preparing':
        return 'bg-orange-100 text-orange-800';
      case 'dispatched':
        return 'bg-purple-100 text-purple-800';
      case 'delivered':
        return 'bg-green-100 text-green-800';
      default:
        return 'bg-gray-100 text-gray-800';
    }
  };

  const getStatusMessage = (status: Order['status']) => {
    switch (status) {
      case 'pending':
        return 'Your order has been received and is waiting for payment confirmation.';
      case 'payment_received':
        return 'Payment received! Your order is being reviewed.';
      case 'confirmed':
        return 'Order confirmed! We\'re getting ready to prepare your food.';
      case 'preparing':
        return 'Your delicious meal is being prepared with care.';
      case 'dispatched':
        return 'Your order is on the way to your location!';
      case 'delivered':
        return 'Order delivered! Enjoy your meal!';
      default:
        return 'Order status updated.';
    }
  };

  if (!trackingId) {
    return (
      <div className="min-h-screen bg-gray-50">
        <Navigation />
        <div className="max-w-2xl mx-auto px-4 sm:px-6 lg:px-8 py-16 text-center">
          <h1 className="text-2xl font-bold text-gray-900 mb-4">
            Invalid Order
          </h1>
          <p className="text-gray-600 mb-8">
            No tracking ID provided. Please check your order confirmation.
          </p>
          <Link href="/">
            <Button className="bg-green-600 hover:bg-green-700">
              Return to Menu
            </Button>
          </Link>
        </div>
      </div>
    );
  }

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50">
        <Navigation />
        <div className="max-w-2xl mx-auto px-4 sm:px-6 lg:px-8 py-16">
          <div className="animate-pulse space-y-4">
            <div className="h-8 bg-gray-200 rounded w-1/2 mx-auto"></div>
            <div className="h-4 bg-gray-200 rounded w-3/4 mx-auto"></div>
            <div className="h-32 bg-gray-200 rounded"></div>
          </div>
        </div>
      </div>
    );
  }

  if (!order) {
    return (
      <div className="min-h-screen bg-gray-50">
        <Navigation />
        <div className="max-w-2xl mx-auto px-4 sm:px-6 lg:px-8 py-16 text-center">
          <h1 className="text-2xl font-bold text-gray-900 mb-4">
            Order Not Found
          </h1>
          <p className="text-gray-600 mb-8">
            We couldn't find an order with this tracking ID.
          </p>
          <Link href="/">
            <Button className="bg-green-600 hover:bg-green-700">
              Return to Menu
            </Button>
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <Navigation />
      
      <div className="max-w-2xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Success Header */}
        <div className="text-center mb-8">
          <div className="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <CheckCircle className="h-8 w-8 text-green-600" />
          </div>
          <h1 className="text-3xl font-bold text-gray-900 mb-2">
            Order Placed Successfully!
          </h1>
          <p className="text-gray-600">
            Your order has been received and is being processed.
          </p>
        </div>

        {/* Order Status */}
        <Card className="mb-8">
          <CardHeader>
            <CardTitle className="flex items-center justify-between">
              <span>Order Status</span>
              <Badge className={`${getStatusColor(order.status)} flex items-center gap-1`}>
                {getStatusIcon(order.status)}
                {order.status.replace('_', ' ').toUpperCase()}
              </Badge>
            </CardTitle>
          </CardHeader>
          <CardContent>
            <p className="text-gray-700 mb-4">
              {getStatusMessage(order.status)}
            </p>
            <div className="bg-gray-50 rounded-lg p-4">
              <div className="grid grid-cols-2 gap-4 text-sm">
                <div>
                  <span className="text-gray-600">Tracking ID:</span>
                  <p className="font-semibold">{order.tracking_id}</p>
                </div>
                <div>
                  <span className="text-gray-600">Order Date:</span>
                  <p className="font-semibold">
                    {format(new Date(order.created_at), 'PPp')}
                  </p>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Order Details */}
        <Card className="mb-8">
          <CardHeader>
            <CardTitle>Order Details</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            {order.order_items.map((item) => (
              <div key={item.id} className="flex justify-between items-center">
                <div>
                  <h4 className="font-medium">{item.food_items.name}</h4>
                  <p className="text-sm text-gray-600">Quantity: {item.quantity}</p>
                </div>
                <span className="font-semibold">
                  ₦{(item.unit_price * item.quantity).toLocaleString()}
                </span>
              </div>
            ))}
            
            <div className="border-t pt-4">
              <div className="flex justify-between items-center text-lg font-bold">
                <span>Total:</span>
                <span className="text-green-600">₦{order.total_amount.toLocaleString()}</span>
              </div>
            </div>

            {order.customer_note && (
              <div className="border-t pt-4">
                <h4 className="font-semibold mb-2">Special Instructions:</h4>
                <p className="text-gray-700 text-sm">{order.customer_note}</p>
              </div>
            )}
          </CardContent>
        </Card>

        {/* Important Information */}
        <Card className="mb-8">
          <CardContent className="pt-6">
            <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
              <h4 className="font-semibold text-blue-900 mb-2">
                📱 Real-time Updates
              </h4>
              <p className="text-blue-800 text-sm">
                You'll receive popup notifications as your order progresses through each stage. 
                Keep this page open or save your tracking ID: <strong>{order.tracking_id}</strong>
              </p>
            </div>
          </CardContent>
        </Card>

        {/* Actions */}
        <div className="flex flex-col sm:flex-row gap-4">
          <Link href="/" className="flex-1">
            <Button variant="outline" className="w-full">
              Continue Shopping
            </Button>
          </Link>
          <Button 
            onClick={() => window.location.reload()} 
            className="flex-1 bg-green-600 hover:bg-green-700"
          >
            Refresh Status
          </Button>
        </div>
      </div>
    </div>
  );
}