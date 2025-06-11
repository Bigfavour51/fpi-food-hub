import { CartItem } from './supabase';

const CART_KEY = 'campus_food_cart';

export function getCart(): CartItem[] {
  if (typeof window === 'undefined') return [];
  
  const cart = localStorage.getItem(CART_KEY);
  return cart ? JSON.parse(cart) : [];
}

export function addToCart(item: Omit<CartItem, 'quantity'>, quantity: number = 1): void {
  if (typeof window === 'undefined') return;
  
  const cart = getCart();
  const existingItem = cart.find(cartItem => cartItem.id === item.id);
  
  if (existingItem) {
    existingItem.quantity += quantity;
  } else {
    cart.push({ ...item, quantity });
  }
  
  localStorage.setItem(CART_KEY, JSON.stringify(cart));
  
  // Dispatch custom event for cart updates
  window.dispatchEvent(new CustomEvent('cartUpdated'));
}

export function updateCartItemQuantity(id: string, quantity: number): void {
  if (typeof window === 'undefined') return;
  
  const cart = getCart();
  const item = cart.find(cartItem => cartItem.id === id);
  
  if (item) {
    if (quantity <= 0) {
      removeFromCart(id);
    } else {
      item.quantity = quantity;
      localStorage.setItem(CART_KEY, JSON.stringify(cart));
      window.dispatchEvent(new CustomEvent('cartUpdated'));
    }
  }
}

export function removeFromCart(id: string): void {
  if (typeof window === 'undefined') return;
  
  const cart = getCart();
  const filteredCart = cart.filter(item => item.id !== id);
  
  localStorage.setItem(CART_KEY, JSON.stringify(filteredCart));
  window.dispatchEvent(new CustomEvent('cartUpdated'));
}

export function clearCart(): void {
  if (typeof window === 'undefined') return;
  
  localStorage.removeItem(CART_KEY);
  window.dispatchEvent(new CustomEvent('cartUpdated'));
}

export function getCartTotal(): number {
  const cart = getCart();
  return cart.reduce((total, item) => total + (item.price * item.quantity), 0);
}

export function getCartItemCount(): number {
  const cart = getCart();
  return cart.reduce((count, item) => count + item.quantity, 0);
}