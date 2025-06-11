'use client';

import { createContext, useContext, useEffect, useState, ReactNode } from 'react';
import { supabase } from '@/lib/supabase';
import { getSessionId } from '@/lib/session';
import { toast } from 'sonner';

interface NotificationContextType {
  isConnected: boolean;
}

const NotificationContext = createContext<NotificationContextType>({
  isConnected: false,
});

export function NotificationProvider({ children }: { children: ReactNode }) {
  const [isConnected, setIsConnected] = useState(false);

  useEffect(() => {
    const sessionId = getSessionId();
    if (!sessionId) return;

    // Subscribe to order status changes for this session
    const channel = supabase
      .channel('order-updates')
      .on(
        'postgres_changes',
        {
          event: '*',
          schema: 'public',
          table: 'orders',
          filter: `session_id=eq.${sessionId}`,
        },
        (payload) => {
          console.log('Order update received:', payload);
          
          if (payload.eventType === 'UPDATE') {
            const newOrder = payload.new as any;
            const oldOrder = payload.old as any;
            
            if (newOrder.status !== oldOrder.status) {
              handleOrderStatusChange(newOrder.status, newOrder.tracking_id);
            }
          }
        }
      )
      .subscribe((status) => {
        setIsConnected(status === 'SUBSCRIBED');
      });

    return () => {
      channel.unsubscribe();
    };
  }, []);

  const handleOrderStatusChange = (status: string, trackingId: string) => {
    const statusMessages = {
      payment_received: '💳 Payment received! Your order is being processed.',
      confirmed: '✅ Order confirmed! We\'re preparing your food.',
      preparing: '👨‍🍳 Your order is being prepared with care.',
      dispatched: '🚗 Order dispatched! Your food is on the way.',
      delivered: '🎉 Order delivered! Enjoy your meal!',
      cancelled: '❌ Order cancelled. Please contact support if you need help.',
    };

    const message = statusMessages[status as keyof typeof statusMessages] || 
                   `Order status updated: ${status}`;

    toast.success(message, {
      description: `Tracking ID: ${trackingId}`,
      duration: 5000,
    });
  };

  return (
    <NotificationContext.Provider value={{ isConnected }}>
      {children}
    </NotificationContext.Provider>
  );
}

export const useNotifications = () => useContext(NotificationContext);