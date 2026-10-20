/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        'grog-indigo': '#4F46E5',
        'grog-indigo-light': '#6366F1',
        'grog-indigo-dark': '#312E81',
        'grog-bg': '#F6F7FB',
        'grog-amber': '#F59E0B',
        'grog-pink': '#F472B6',
      },
    },
  },
  plugins: [],
}
