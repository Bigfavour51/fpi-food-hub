# FPI Food Hub - Campus Food Ordering System

A modern, full-stack food ordering web application built for Federal Polytechnic, Ilaro campus. This system allows students and staff to order food online with real-time order tracking and admin management capabilities.

## 🚀 Features

### User Features
- **No Registration Required**: Users get temporary session IDs for seamless ordering
- **Browse Menu**: View available food items with categories and search functionality
- **Shopping Cart**: Add items, modify quantities, and view total costs
- **Order Tracking**: Receive unique tracking IDs and real-time status updates
- **Real-time Notifications**: Toast notifications for order status changes
- **Responsive Design**: Works perfectly on mobile and desktop devices

### Admin Features
- **Secure Login**: Simple authentication system (username: admin, password: admin123)
- **Order Management**: View order queue and update order statuses
- **Menu Management**: Add, edit, delete, and toggle availability of food items
- **Real-time Updates**: Live order notifications and status management
- **Dashboard Analytics**: Order tracking and management overview

## 🛠 Tech Stack

- **Frontend**: Next.js 13, React, TypeScript
- **Styling**: Tailwind CSS, shadcn/ui components
- **Backend**: Supabase (PostgreSQL database, Real-time subscriptions, Authentication)
- **State Management**: React hooks, Local Storage for cart and session
- **Notifications**: Sonner for toast notifications
- **Icons**: Lucide React

## 📦 Installation & Setup

### Prerequisites
- Node.js 18+ 
- npm or yarn
- Supabase account

### 1. Clone the Repository
```bash
git clone <your-repo-url>
cd campus-food-ordering
npm install
```

### 2. Set up Supabase
1. Create a new project at [supabase.com](https://supabase.com)
2. Go to Project Settings > API
3. Copy your project URL and anon key

### 3. Environment Setup
```bash
cp .env.local.example .env.local
```

Edit `.env.local` with your Supabase credentials:
```
NEXT_PUBLIC_SUPABASE_URL=your_supabase_project_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_supabase_service_role_key
```

### 4. Database Setup
1. In your Supabase dashboard, go to SQL Editor
2. Copy and run the migration file content from `supabase/migrations/create_food_ordering_schema.sql`
3. This will create all necessary tables, RLS policies, and sample data

### 5. Run the Application
```bash
npm run dev
```

Visit `http://localhost:3000` to see the application.

## 📁 Project Structure

```
├── app/                    # Next.js 13 app directory
│   ├── admin/             # Admin dashboard page
│   ├── cart/              # Shopping cart page
│   ├── checkout/          # Checkout process page
│   ├── order-success/     # Order confirmation page
│   └── page.tsx           # Home page (menu)
├── components/            # React components
│   ├── admin/             # Admin-specific components
│   ├── ui/                # shadcn/ui components
│   ├── FoodCard.tsx       # Food item display component
│   ├── CartDrawer.tsx     # Shopping cart component
│   └── Navigation.tsx     # Main navigation
├── contexts/              # React contexts
│   └── NotificationContext.tsx  # Real-time notifications
├── lib/                   # Utility libraries
│   ├── supabase.ts        # Supabase client and types
│   ├── session.ts         # Session management
│   └── cart.ts            # Cart management
└── supabase/
    └── migrations/        # Database schema
```

## 🗄 Database Schema

### Tables
- `food_items`: Menu items with categories, prices, and availability
- `orders`: Customer orders with status tracking
- `order_items`: Junction table for order and food items
- `order_status_history`: Audit trail for order status changes
- `admin_credentials`: Admin authentication

### Order Status Flow
1. `pending` → Order created, awaiting payment
2. `payment_received` → Payment confirmed
3. `confirmed` → Order accepted for preparation
4. `preparing` → Food is being prepared
5. `dispatched` → Order sent for delivery
6. `delivered` → Order completed
7. `cancelled` → Order cancelled (can happen at any stage)

## 🔧 Key Features Implementation

### Session Management
- Uses UUID v4 for temporary user sessions
- Stored in localStorage for persistence
- No user registration required

### Real-time Notifications
- Supabase real-time subscriptions for order updates
- Toast notifications using Sonner
- Automatic status change detection

### Cart Management
- Local storage persistence
- Event-driven updates across components
- Quantity management and total calculation

### Admin Authentication
- Simple hardcoded credentials for demo
- Session-based authentication state
- Protected admin routes

## 🚀 Deployment

### Vercel Deployment (Recommended)
1. Push code to GitHub
2. Connect repository to Vercel
3. Add environment variables in Vercel dashboard
4. Deploy automatically

### Manual Build
```bash
npm run build
npm start
```

## 🔒 Security Features

- Row Level Security (RLS) on all Supabase tables
- Session-based access control
- Admin-only operations protection
- Input validation and sanitization

## 📱 Mobile Optimization

- Fully responsive design
- Touch-friendly interface
- Mobile-first approach
- Progressive Web App ready

## 🎨 Design System

- **Primary Colors**: Green (#16a34a) for campus branding
- **Typography**: Inter font family
- **Components**: shadcn/ui component library
- **Spacing**: 8px grid system
- **Animations**: Subtle hover effects and transitions

## 🔧 Customization

### Adding New Food Categories
Update the enum in the database migration:
```sql
ALTER TYPE food_category_enum ADD VALUE 'New Category';
```

### Modifying Order Statuses
Update the enum and corresponding UI components:
```sql
ALTER TYPE order_status_enum ADD VALUE 'new_status';
```

### Styling Customization
- Modify `tailwind.config.ts` for design tokens
- Update component styles in respective files
- Customize theme in `app/globals.css`

## 🐛 Troubleshooting

### Common Issues
1. **Supabase Connection**: Verify environment variables
2. **Real-time Not Working**: Check Supabase RLS policies
3. **Build Errors**: Ensure all dependencies are installed
4. **Cart Not Persisting**: Check localStorage permissions

### Debug Mode
Enable detailed logging by setting:
```bash
NODE_ENV=development
```

## 📈 Future Enhancements

- Payment gateway integration (Paystack/Flutterwave)
- SMS notifications for order updates
- Location-based delivery tracking
- Analytics dashboard for admins
- Multi-vendor support
- Rating and review system

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 📞 Support

For technical support or questions:
- Open an issue on GitHub
- Contact: [your-email@example.com]

---

Built with ❤️ for Federal Polytechnic, Ilaro Campus Community