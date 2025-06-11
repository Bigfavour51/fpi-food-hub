'use client';

import { useState, useEffect } from 'react';
import { Clock, CheckCircle, Truck, Package, XCircle } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Separator } from '@/components/ui/separator';
import { supabase, Order, OrderItem } from '@/lib/supabase';
import { toast } from 'sonner';
import { format } from 'date-fns';

interface OrderWithItems extends Order {
  order_items: (OrderItem & { food_items: { name: string; price: number } })[];
}

export default function OrdersQueue() {
  const [orders, setOrders] = useState<OrderWithItems[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [retryCount, setRetryCount] = useState(0);
  const MAX_RETRIES = 3;

  useEffect(() => {
    fetchOrders();
    
    // Subscribe to real-time order updates with optimized channel
    const channel = supabase
      .channel('admin-orders')
      .on(
        'postgres_changes',
        { 
          event: '*', 
          schema: 'public', 
          table: 'orders',
          filter: 'status=neq.delivered' // Only track non-delivered orders
        },
        (payload) => {
          console.log('Order update received:', payload);
          fetchOrders();
        }
      )
      .subscribe((status) => {
        if (status === 'SUBSCRIBED') {
          console.log('Successfully subscribed to order updates');
        } else {
          console.error('Failed to subscribe to order updates:', status);
          setError('Failed to connect to real-time updates');
        }
      });

    return () => {
      channel.unsubscribe();
    };
  }, []);

  const fetchOrders = async () => {
    try {
      setLoading(true);
      setError(null);
      
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
        .order('created_at', { ascending: false })
        .limit(50); // Add pagination limit

      if (error) {
        throw error;
      }

      setOrders(data || []);
      setRetryCount(0); // Reset retry count on success
    } catch (err) {
      console.error('Error fetching orders:', err);
      setError('Failed to fetch orders');
      
      // Implement retry mechanism
      if (retryCount < MAX_RETRIES) {
        setRetryCount(prev => prev + 1);
        setTimeout(fetchOrders, 1000 * Math.pow(2, retryCount)); // Exponential backoff
      }
    } finally {
      setLoading(false);
    }
  };

  const updateOrderStatus = async (orderId: string, newStatus: Order['status']) => {
    try {
      // Optimistic update
      setOrders(prevOrders => 
        prevOrders.map(order => 
          order.id === orderId 
            ? { ...order, status: newStatus }
            : order
        )
      );

      const { error } = await supabase
        .from('orders')
        .update({ 
          status: newStatus, 
          updated_at: new Date().toISOString() 
        })
        .eq('id', orderId);

      if (error) throw error;

      // Add to status history
      const { error: historyError } = await supabase
        .from('order_status_history')
        .insert({
          order_id: orderId,
          status: newStatus,
        });

      if (historyError) throw historyError;

      toast.success(`Order status updated to ${newStatus.replace('_', ' ')}`);
    } catch (err) {
      console.error('Error updating order status:', err);
      
      // Revert optimistic update
      fetchOrders();
      
      // Show specific error message
      if (err instanceof Error) {
        if (err.message.includes('permission denied')) {
          toast.error('You do not have permission to update this order');
        } else {
          toast.error('Failed to update order status. Please try again.');
        }
      } else {
        toast.error('An unexpected error occurred');
      }
    }
  };

  const getStatusIcon = (status: Order['status']) => {
    switch (status) {
      case 'pending':
        return <Clock className="h-4 w-4" />;
      case 'payment_received':
      case 'confirmed':
        return <CheckCircle className="h-4 w-4" />;
      case 'preparing':
        return <Package className="h-4 w-4" />;
      case 'dispatched':
        return <Truck className="h-4 w-4" />;
      case 'delivered':
        return <CheckCircle className="h-4 w-4" />;
      case 'cancelled':
        return <XCircle className="h-4 w-4" />;
      default:
        return <Clock className="h-4 w-4" />;
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
      case 'cancelled':
        return 'bg-red-100 text-red-800';
      default:
        return 'bg-gray-100 text-gray-800';
    }
  };

  const getNextActions = (status: Order['status']) => {
    switch (status) {
      case 'pending':
        return [
          { label: 'Confirm Payment', status: 'payment_received' as const },
          { label: 'Cancel Order', status: 'cancelled' as const },
        ];
      case 'payment_received':
        return [
          { label: 'Confirm Order', status: 'confirmed' as const },
          { label: 'Cancel Order', status: 'cancelled' as const },
        ];
      case 'confirmed':
        return [
          { label: 'Start Preparing', status: 'preparing' as const },
          { label: 'Cancel Order', status: 'cancelled' as const },
        ];
      case 'preparing':
        return [
          { label: 'Dispatch Order', status: 'dispatched' as const },
        ];
      case 'dispatched':
        return [
          { label: 'Mark Delivered', status: 'delivered' as const },
        ];
      default:
        return [];
    }
  };

  if (error) {
    return (
      <div className="text-center py-8">
        <p className="text-red-600 mb-4">{error}</p>
        <Button 
          onClick={fetchOrders}
          disabled={retryCount >= MAX_RETRIES}
        >
          {retryCount >= MAX_RETRIES ? 'Max retries reached' : 'Retry'}
        </Button>
      </div>
    );
  }

  if (loading) {
    return (
      <div className="space-y-4">
        {[...Array(3)].map((_, i) => (
          <Card key={i} className="animate-pulse">
            <CardContent className="p-6">
              <div className="h-4 bg-gray-200 rounded w-1/4 mb-4"></div>
              <div className="h-4 bg-gray-200 rounded w-3/4 mb-2"></div>
              <div className="h-4 bg-gray-200 rounded w-1/2"></div>
            </CardContent>
          </Card>
        ))}
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-center">
        <h2 className="text-2xl font-bold text-gray-900">Orders Queue</h2>
        <Button onClick={fetchOrders} variant="outline">
          Refresh
        </Button>
      </div>

      {orders.length === 0 ? (
        <Card>
          <CardContent className="text-center py-12">
            <Package className="h-12 w-12 text-gray-400 mx-auto mb-4" />
            <h3 className="text-lg font-semibold text-gray-900 mb-2">No orders yet</h3>
            <p className="text-gray-600">Orders will appear here when customers place them.</p>
          </CardContent>
        </Card>
      ) : (
        <div className="space-y-4">
          {orders.map((order) => (
            <Card key={order.id} className="overflow-hidden">
              <CardHeader className="pb-4">
                <div className="flex justify-between items-start">
                  <div>
                    <CardTitle className="text-lg">
                      Order #{order.tracking_id}
                    </CardTitle>
                    <p className="text-sm text-gray-600 mt-1">
                      {format(new Date(order.created_at), 'PPp')}
                    </p>
                  </div>
                  <Badge className={`${getStatusColor(order.status)} flex items-center gap-1`}>
                    {getStatusIcon(order.status)}
                    {order.status.replace('_', ' ').toUpperCase()}
                  </Badge>
                </div>
              </CardHeader>

              <CardContent className="space-y-4">
                <div>
                  <h4 className="font-semibold mb-2">Items:</h4>
                  <div className="space-y-2">
                    {order.order_items.map((item) => (
                      <div key={item.id} className="flex justify-between items-center text-sm">
                        <span>
                          {item.quantity}x {item.food_items.name}
                        </span>
                        <span className="font-medium">
                          ₦{(item.unit_price * item.quantity).toLocaleString()}
                        </span>
                      </div>
                    ))}
                  </div>
                </div>

                <Separator />

                <div className="flex justify-between items-center">
                  <span className="font-semibold">Total:</span>
                  <span className="font-bold text-lg text-green-600">
                    ₦{order.total_amount.toLocaleString()}
                  </span>
                </div>

                {order.customer_note && (
                  <>
                    <Separator />
                    <div>
                      <h4 className="font-semibold mb-1">Customer Note:</h4>
                      <p className="text-sm text-gray-600">{order.customer_note}</p>
                    </div>
                  </>
                )}

                <Separator />

                <div className="flex flex-wrap gap-2">
                  {getNextActions(order.status).map((action) => (
                    <Button
                      key={action.status}
                      size="sm"
                      variant={action.status === 'cancelled' ? 'destructive' : 'default'}
                      onClick={() => updateOrderStatus(order.id, action.status)}
                      className={action.status !== 'cancelled' ? 'bg-green-600 hover:bg-green-700' : ''}
                    >
                      {action.label}
                    </Button>
                  ))}
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}