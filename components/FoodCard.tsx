'use client';

import { useState } from 'react';
import Image from 'next/image';
import { Plus, Minus } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardFooter } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { FoodItem } from '@/lib/supabase';
import { addToCart, getCart, updateCartItemQuantity } from '@/lib/cart';
import { toast } from 'sonner';

interface FoodCardProps {
  item: FoodItem;
}

export default function FoodCard({ item }: FoodCardProps) {
  const [quantity, setQuantity] = useState(() => {
    const cart = getCart();
    const existingItem = cart.find(cartItem => cartItem.id === item.id);
    return existingItem?.quantity || 0;
  });

  const handleAddToCart = () => {
    addToCart({
      id: item.id,
      name: item.name,
      price: item.price,
      image_url: item.image_url,
    });
    setQuantity(prev => prev + 1);
    toast.success(`${item.name} added to cart!`);
  };

  const handleUpdateQuantity = (newQuantity: number) => {
    if (newQuantity <= 0) {
      updateCartItemQuantity(item.id, 0);
      setQuantity(0);
      toast.success(`${item.name} removed from cart`);
    } else {
      updateCartItemQuantity(item.id, newQuantity);
      setQuantity(newQuantity);
    }
  };

  return (
    <Card className="group hover:shadow-lg transition-shadow duration-300">
      <CardContent className="p-0">
        <div className="relative overflow-hidden rounded-t-lg">
          <Image
            src={item.image_url || '/api/placeholder/300/200'}
            alt={item.name}
            width={300}
            height={200}
            className="w-full h-48 object-cover group-hover:scale-105 transition-transform duration-300"
          />
          <div className="absolute top-2 right-2">
            <Badge variant="secondary" className="bg-white/90">
              {item.category}
            </Badge>
          </div>
        </div>
        
        <div className="p-4">
          <h3 className="font-semibold text-lg text-gray-900 mb-2">
            {item.name}
          </h3>
          <p className="text-gray-600 text-sm mb-3 line-clamp-2">
            {item.description}
          </p>
          <div className="flex items-center justify-between">
            <span className="text-xl font-bold text-green-600">
              ₦{item.price.toLocaleString()}
            </span>
            {!item.available && (
              <Badge variant="destructive">Out of Stock</Badge>
            )}
          </div>
        </div>
      </CardContent>
      
      <CardFooter className="p-4 pt-0">
        {!item.available ? (
          <Button disabled className="w-full">
            Out of Stock
          </Button>
        ) : quantity === 0 ? (
          <Button onClick={handleAddToCart} className="w-full bg-green-600 hover:bg-green-700">
            <Plus className="h-4 w-4 mr-2" />
            Add to Cart
          </Button>
        ) : (
          <div className="flex items-center justify-center space-x-3 w-full">
            <Button
              variant="outline"
              size="sm"
              onClick={() => handleUpdateQuantity(quantity - 1)}
            >
              <Minus className="h-4 w-4" />
            </Button>
            <span className="font-semibold text-lg min-w-[2rem] text-center">
              {quantity}
            </span>
            <Button
              variant="outline"
              size="sm"
              onClick={() => handleUpdateQuantity(quantity + 1)}
            >
              <Plus className="h-4 w-4" />
            </Button>
          </div>
        )}
      </CardFooter>
    </Card>
  );
}