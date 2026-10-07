import {defineConfig} from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins:[react()],
  define: {
    __TALENTOS_VERCEL_ENV__: JSON.stringify(process.env.VERCEL_ENV ?? ''),
  },
  build:{
    sourcemap:false,
    minify:'esbuild',
  },
});
