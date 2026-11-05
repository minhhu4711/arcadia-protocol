/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        base: '#0B1224',
        panel: '#111C32',
        card: '#15233B',
        line: '#24344F',
        brand: '#3185FF',
        aqua: '#21C6B7',
        ink: '#FFFFFF',
        mute: '#9CAAC4',
        ok: '#20C997',
        warn: '#F5B942',
        bad: '#F06565',
      },
      fontFamily: {
        display: ['"Space Grotesk"', 'sans-serif'],
        sans: ['"DM Sans"', 'sans-serif'],
        mono: ['"JetBrains Mono"', 'Menlo', 'monospace'],
      },
    },
  },
  plugins: [],
}
