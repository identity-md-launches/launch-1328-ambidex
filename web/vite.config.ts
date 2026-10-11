import { defineConfig, loadEnv, type Plugin } from 'vite';
import react from '@vitejs/plugin-react';

/**
 * The export is served from an IPFS gateway subpath or an ENS name, so every asset URL is
 * relative and the page claims no origin by default. When the publisher knows the origin the
 * export will live at, `VITE_SITE_URL=https://example.org npm run build` makes the share image
 * absolute (what most link scrapers need) and adds canonical and og:url tags for that origin.
 * Without it the share image stays relative and the two origin tags are left out, so the page
 * never points at a host that does not serve it.
 */
function siteOrigin(url: string): Plugin {
  const origin = url.replace(/\/+$/, '');
  return {
    name: 'ambidex-site-origin',
    transformIndexHtml(html) {
      if (!origin) return html;
      if (!/^https?:\/\//.test(origin)) {
        throw new Error(`VITE_SITE_URL must be an absolute http(s) origin, got "${url}"`);
      }
      const esc = origin.replace(/&/g, '&amp;').replace(/"/g, '&quot;');
      return html
        .replace(/content="\.\/og\.png"/g, `content="${esc}/og.png"`)
        .replace(
          '<meta property="og:type"',
          `<link rel="canonical" href="${esc}/" />\n    <meta property="og:url" content="${esc}/" />\n    <meta property="og:type"`,
        );
    },
  };
}

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), 'VITE_');
  return {
    base: './',
    plugins: [react(), siteOrigin(env.VITE_SITE_URL ?? '')],
    build: {
      outDir: '../dist',
      emptyOutDir: true,
      sourcemap: false,
      target: 'es2022',
    },
  };
});
