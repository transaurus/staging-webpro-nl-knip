export default {
  title: 'Docusaurus',
  url: 'https://docusaurus.io',
  baseUrl: '/',
  presets: [
    ['@docusaurus/preset-classic', { debug: false }],
  ],
  future: {
    // Use hash router to skip SSR/SSG phase entirely.
    // The SSG eval context can't resolve webpack aliases (@theme/*, @site/*, @generated/*).
    experimental_router: 'hash',
  },
};
