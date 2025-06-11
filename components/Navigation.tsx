'use client';

import { useState, useEffect } from 'react';
import Link from 'next/link';
import { ShoppingCart, UtensilsCrossed, User } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { getCartItemCount } from '@/lib/cart';

export default function Navigation() {
  const [cartCount, setCartCount] = useState(0);

  useEffect(() => {
    // Initial cart count
    setCartCount(getCartItemCount());

    // Listen for cart updates
    const handleCartUpdate = () => {
      setCartCount(getCartItemCount());
    };

    window.addEventListener('cartUpdated', handleCartUpdate);
    return () => window.removeEventListener('cartUpdated', handleCartUpdate);
  }, []);

  return (
    <nav className="bg-white border-b border-gray-200 sticky top-0 z-50">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex justify-between h-16">
          <div className="flex items-center">
            <Link href="/" className="flex items-center space-x-2">
              <UtensilsCrossed className="h-8 w-8 text-green-600" />
              <span className="text-xl font-bold text-gray-900">
                FPI Food Hub
              </span>
            </Link>
          </div>

          <div className="flex items-center space-x-4">
            <Link href="/cart">
              <Button variant="outline" size="sm" className="relative">
                <ShoppingCart className="h-4 w-4 mr-2" />
                Cart
                {cartCount > 0 && (
                  <Badge 
                    variant="destructive" 
                    className="absolute -top-2 -right-2 h-5 w-5 rounded-full p-0 flex items-center justify-center text-xs"
                  >
                    {cartCount > 99 ? '99+' : cartCount}
                  </Badge>
                )}
              </Button>
            </Link>

            <Link href="/admin">
              <Button variant="ghost" size="sm">
                <User className="h-4 w-4 mr-2" />
                Admin
              </Button>
            </Link>
          </div>
        </div>
      </div>
    </nav>
  );
}