'use client';

import { useState, useEffect } from 'react';
import AdminLoginForm from '@/components/admin/AdminLoginForm';
import AdminNav from '@/components/admin/AdminNav';
import OrdersQueue from '@/components/admin/OrdersQueue';
import MenuManagement from '@/components/admin/MenuManagement';

export default function AdminPage() {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [activeTab, setActiveTab] = useState('orders');
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    // Check if admin is already authenticated
    const authenticated = localStorage.getItem('admin_authenticated') === 'true';
    setIsAuthenticated(authenticated);
    setIsLoading(false);
  }, []);

  const handleLogin = () => {
    setIsAuthenticated(true);
  };

  const handleLogout = () => {
    setIsAuthenticated(false);
  };

  if (isLoading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-green-600"></div>
      </div>
    );
  }

  if (!isAuthenticated) {
    return <AdminLoginForm onLogin={handleLogin} />;
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <AdminNav 
        activeTab={activeTab} 
        onTabChange={setActiveTab}
        onLogout={handleLogout} 
      />
      
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {activeTab === 'orders' && <OrdersQueue />}
        {activeTab === 'menu' && <MenuManagement />}
      </div>
    </div>
  );
}