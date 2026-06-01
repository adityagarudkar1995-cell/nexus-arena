import type { Config } from 'tailwindcss';

const config: Config = {
  content: ['./app/**/*.{ts,tsx}', './lib/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        bg: '#0D0D0D',
        card: '#1A1A2E',
        surface: '#16213E',
        accent: '#00FF88',
        danger: '#FF4655',
        gold: '#FFD700',
        purple: '#7B2FBE',
        muted: '#6B6B8A',
      },
      fontFamily: { sans: ['Inter', 'system-ui', 'sans-serif'] },
    },
  },
  plugins: [],
};

export default config;
