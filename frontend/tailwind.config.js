/** @type {import('tailwindcss').Config} */
export default {
  content: ["./index.html", "./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        epc: {
          900: "#0f2a43",
          800: "#163a5a",
          700: "#1F4E78",
          100: "#e7eef5",
        },
        critical: "#e4572e",
      },
    },
  },
  plugins: [],
};
