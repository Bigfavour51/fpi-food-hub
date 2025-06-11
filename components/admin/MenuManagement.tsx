'use client';

import React, { useState, useEffect } from 'react';
import { Plus, Edit2, Trash2 } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@/components/ui/select';
import { Switch } from '@/components/ui/switch';
import { Card, CardContent } from '@/components/ui/card';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from '@/components/ui/dialog';
import { supabase, FoodItem } from '@/lib/supabase';
import { toast } from 'sonner';

const categories = ['Rice', 'Snacks', 'Drinks', 'Swallow', 'Protein', 'Others'] as const;

interface FormData {
  name: string;
  description: string;
  price: string;
  image_url: string;
  category: typeof categories[number];
  available: boolean;
}

const initialFormData: FormData = {
  name: '',
  description: '',
  price: '',
  image_url: '',
  category: 'Others',
  available: true,
};

export default function MenuManagement() {
  const [foodItems, setFoodItems] = useState<FoodItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [editingItem, setEditingItem] = useState<FoodItem | null>(null);
  const [isDialogOpen, setIsDialogOpen] = useState(false);
  const [formData, setFormData] = useState<FormData>(initialFormData);
  const [retryCount, setRetryCount] = useState(0);
  const MAX_RETRIES = 3;

  useEffect(() => {
    fetchFoodItems();
  }, []);

  const fetchFoodItems = async () => {
    try {
      setLoading(true);
      setError(null);

      const { data, error } = await supabase
        .from('food_items')
        .select('*')
        .order('name');

      if (error) throw error;

      setFoodItems(data || []);
      setRetryCount(0);
    } catch (err) {
      console.error('Error fetching food items:', err);
      setError('Failed to load menu items');
      
      if (retryCount < MAX_RETRIES) {
        setRetryCount(prev => prev + 1);
        setTimeout(fetchFoodItems, 1000 * Math.pow(2, retryCount));
      }
    } finally {
      setLoading(false);
    }
  };

  const validateFoodItem = (item: Partial<FoodItem>): string | null => {
    if (!item.name?.trim()) {
      return 'Name is required';
    }
    if (!item.price || item.price <= 0) {
      return 'Price must be greater than 0';
    }
    if (!item.category) {
      return 'Category is required';
    }
    if (item.name.length > 100) {
      return 'Name is too long (max 100 characters)';
    }
    if (item.description && item.description.length > 500) {
      return 'Description is too long (max 500 characters)';
    }
    return null;
  };

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    
    try {
      const itemData: Partial<FoodItem> = {
        name: formData.name.trim(),
        description: formData.description.trim(),
        price: parseFloat(formData.price),
        image_url: formData.image_url.trim(),
        category: formData.category,
        available: formData.available,
      };

      const validationError = validateFoodItem(itemData);
      if (validationError) {
        toast.error(validationError);
        return;
      }

      // Optimistic update
      if (editingItem) {
        setFoodItems((prev: FoodItem[]) => 
          prev.map((fi: FoodItem) => fi.id === editingItem.id ? { ...fi, ...itemData } : fi)
        );
      } else {
        setFoodItems((prev: FoodItem[]) => [...prev, { ...itemData, id: 'temp-' + Date.now() } as FoodItem]);
      }

      const { error } = editingItem
        ? await supabase
            .from('food_items')
            .update(itemData)
            .eq('id', editingItem.id)
        : await supabase
            .from('food_items')
            .insert([itemData]);

      if (error) throw error;

      toast.success(`Food item ${editingItem ? 'updated' : 'added'} successfully`);
      setIsDialogOpen(false);
      setEditingItem(null);
      setFormData(initialFormData);
    } catch (err) {
      console.error('Error saving food item:', err);
      
      // Revert optimistic update
      fetchFoodItems();
      
      if (err instanceof Error) {
        if (err.message.includes('duplicate key')) {
          toast.error('A food item with this name already exists');
        } else if (err.message.includes('permission denied')) {
          toast.error('You do not have permission to modify menu items');
        } else {
          toast.error('Failed to save food item. Please try again.');
        }
      } else {
        toast.error('An unexpected error occurred');
      }
    }
  };

  const handleDelete = async (id: string) => {
    if (!confirm('Are you sure you want to delete this item?')) {
      return;
    }

    try {
      // Optimistic update
      setFoodItems((prev: FoodItem[]) => prev.filter((item: FoodItem) => item.id !== id));

      const { error } = await supabase
        .from('food_items')
        .delete()
        .eq('id', id);

      if (error) throw error;

      toast.success('Food item deleted successfully');
    } catch (err) {
      console.error('Error deleting food item:', err);
      
      // Revert optimistic update
      fetchFoodItems();
      
      if (err instanceof Error) {
        if (err.message.includes('foreign key constraint')) {
          toast.error('Cannot delete item: it is part of existing orders');
        } else if (err.message.includes('permission denied')) {
          toast.error('You do not have permission to delete menu items');
        } else {
          toast.error('Failed to delete food item. Please try again.');
        }
      } else {
        toast.error('An unexpected error occurred');
      }
    }
  };

  const handleToggleAvailability = async (id: string, currentStatus: boolean) => {
    try {
      // Optimistic update
      setFoodItems((prev: FoodItem[]) =>
        prev.map((item: FoodItem) =>
          item.id === id ? { ...item, available: !currentStatus } : item
        )
      );

      const { error } = await supabase
        .from('food_items')
        .update({ available: !currentStatus })
        .eq('id', id);

      if (error) throw error;

      toast.success(`Item ${!currentStatus ? 'made available' : 'made unavailable'}`);
    } catch (err) {
      console.error('Error toggling availability:', err);
      
      // Revert optimistic update
      fetchFoodItems();
      
      if (err instanceof Error) {
        if (err.message.includes('permission denied')) {
          toast.error('You do not have permission to modify menu items');
        } else {
          toast.error('Failed to update item availability. Please try again.');
        }
      } else {
        toast.error('An unexpected error occurred');
      }
    }
  };

  const handleEdit = (item: FoodItem) => {
    setEditingItem(item);
    setFormData({
      name: item.name,
      description: item.description || '',
      price: item.price.toString(),
      image_url: item.image_url || '',
      category: item.category,
      available: item.available,
    });
    setIsDialogOpen(true);
  };

  if (error) {
    return (
      <div className="text-center py-8">
        <p className="text-red-600 mb-4">{error}</p>
        <Button 
          onClick={fetchFoodItems}
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
        <h2 className="text-2xl font-bold">Menu Management</h2>
        <Dialog open={isDialogOpen} onOpenChange={(open) => {
          setIsDialogOpen(open);
          if (!open) {
            setEditingItem(null);
            setFormData(initialFormData);
          }
        }}>
          <DialogTrigger asChild>
            <Button>
              <Plus className="h-4 w-4 mr-2" />
              Add Item
            </Button>
          </DialogTrigger>
          <DialogContent>
            <DialogHeader>
              <DialogTitle>
                {editingItem ? 'Edit Food Item' : 'Add New Food Item'}
              </DialogTitle>
            </DialogHeader>
            <form onSubmit={handleSave} className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="name">Name *</Label>
                <Input
                  id="name"
                  value={formData.name}
                  onChange={(e: React.ChangeEvent<HTMLInputElement>) => setFormData(prev => ({ ...prev, name: e.target.value }))}
                  required
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="description">Description</Label>
                <Textarea
                  id="description"
                  value={formData.description}
                  onChange={(e: React.ChangeEvent<HTMLTextAreaElement>) => setFormData(prev => ({ ...prev, description: e.target.value }))}
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="price">Price (₦) *</Label>
                <Input
                  id="price"
                  type="number"
                  min="0"
                  step="0.01"
                  value={formData.price}
                  onChange={(e: React.ChangeEvent<HTMLInputElement>) => setFormData(prev => ({ ...prev, price: e.target.value }))}
                  required
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="image_url">Image URL</Label>
                <Input
                  id="image_url"
                  type="url"
                  value={formData.image_url}
                  onChange={(e: React.ChangeEvent<HTMLInputElement>) => setFormData(prev => ({ ...prev, image_url: e.target.value }))}
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="category">Category *</Label>
                <Select
                  value={formData.category}
                  onValueChange={(value: typeof categories[number]) => setFormData(prev => ({ ...prev, category: value }))}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {categories.map((category) => (
                      <SelectItem key={category} value={category}>
                        {category}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>

              <div className="flex items-center space-x-2">
                <Switch
                  id="available"
                  checked={formData.available}
                  onCheckedChange={(checked: boolean) => setFormData(prev => ({ ...prev, available: checked }))}
                />
                <Label htmlFor="available">Available</Label>
              </div>

              <div className="flex justify-end space-x-2">
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => {
                    setIsDialogOpen(false);
                    setEditingItem(null);
                    setFormData(initialFormData);
                  }}
                >
                  Cancel
                </Button>
                <Button type="submit">
                  {editingItem ? 'Update' : 'Add'} Item
                </Button>
              </div>
            </form>
          </DialogContent>
        </Dialog>
      </div>

      <div className="grid gap-4">
        {foodItems.map((item) => (
          <Card key={item.id}>
            <CardContent className="p-6">
              <div className="flex justify-between items-start">
                <div>
                  <h3 className="font-semibold text-lg">{item.name}</h3>
                  <p className="text-gray-600 text-sm mt-1">{item.description}</p>
                  <div className="mt-2 space-x-2">
                    <span className="text-green-600 font-medium">₦{item.price.toLocaleString()}</span>
                    <span className="text-gray-500">•</span>
                    <span className="text-gray-600">{item.category}</span>
                  </div>
                </div>
                <div className="flex space-x-2">
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => handleToggleAvailability(item.id, item.available)}
                  >
                    {item.available ? 'Disable' : 'Enable'}
                  </Button>
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => handleEdit(item)}
                  >
                    <Edit2 className="h-4 w-4" />
                  </Button>
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => handleDelete(item.id)}
                    className="text-red-600 hover:text-red-700 hover:bg-red-50"
                  >
                    <Trash2 className="h-4 w-4" />
                  </Button>
                </div>
              </div>
            </CardContent>
          </Card>
        ))}

        {foodItems.length === 0 && (
          <Card>
            <CardContent className="text-center py-12">
              <p className="text-gray-600">No food items found. Add your first item!</p>
            </CardContent>
          </Card>
        )}
      </div>
    </div>
  );
}