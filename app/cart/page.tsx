import Navigation from '@/components/Navigation';
import CartDrawer from '@/components/CartDrawer';

export default function CartPage() {
  return (
    <div className="min-h-screen bg-gray-50">
      <Navigation />
      
      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <CartDrawer />
      </div>
    </div>
  );
}