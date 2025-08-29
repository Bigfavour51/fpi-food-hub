## FPI Food Hub — Local Setup Guide 

This guide explains how to install dependencies, configure Supabase, and run the project locally in a browser.


### 1) Prerequisites
- Node.js 18 or newer (recommend LTS)
- npm (bundled with Node) or yarn
- A Supabase account (`https://supabase.com`)
- Visual Studio Code (VS Code)


### 2) Get the project files
You can either:
- Copy the entire project folder (fpi-food-hub) to your computer, or
- Clone from Git if provided.

### 2.1) Open in VS Code
1. Install VS Code from `https://code.visualstudio.com/` (if not already installed).
2. Open VS Code → File → Open Folder… → select the project folder `fpi-food-hub`.
3. Open an integrated terminal: View → Terminal (or `` Ctrl+` ``).
4. You can run all commands in this integrated terminal.

Recommended VS Code extensions:
- ESLint (dbaeumer.vscode-eslint)
- Tailwind CSS IntelliSense (bradlc.vscode-tailwindcss)
- Prettier (esbenp.prettier-vscode)


### 3) Install dependencies

```bash
npm install
```

If you see warnings about Browserslist data being outdated, you can (optional):

```bash
npx update-browserslist-db@latest --yes
```

### 7) Run the app (development)

```bash
npm run dev
```

Open `http://localhost:3000` in your browser or whatever address it provides on the terminal.


---

### 8) Test the flow
- Browse the menu, add items to the cart.
- Go to Checkout.
- Select a Pickup Location (required).
- Review the Payment Details card:
  - Acct Name: FPI FOOD HUB
  - Acct No.: 3154810242
  - Bank Name: FIRST BANK PLC
- Read the note to pay the exact total amount, then click “Place Order”.
- You’ll be redirected to the Order Success page with your tracking ID.

Admin (optional):
- Visit `/admin` and use the demo credentials (username: `admin`, password: `admin123`) to view/manage orders.

---

### 9) Build for production (optional)

```bash
npm run build
npm start
```

Open `http://localhost:3000`.



### 11) Project scripts
- `npm run dev` — Start Next.js in development mode
- `npm run build` — Build for production
- `npm start` — Run the production build

---



