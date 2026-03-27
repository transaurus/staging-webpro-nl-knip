import React from 'react';
import ComponentCreator from '@docusaurus/ComponentCreator';

export default [
  {
    path: '/blog',
    component: ComponentCreator('/blog', '1b9'),
    exact: true
  },
  {
    path: '/blog/2021/08/01/mdx-blog-post',
    component: ComponentCreator('/blog/2021/08/01/mdx-blog-post', 'f2b'),
    exact: true
  },
  {
    path: '/blog/archive',
    component: ComponentCreator('/blog/archive', '182'),
    exact: true
  },
  {
    path: '/docs',
    component: ComponentCreator('/docs', '2e8'),
    routes: [
      {
        path: '/docs',
        component: ComponentCreator('/docs', 'd25'),
        routes: [
          {
            path: '/docs',
            component: ComponentCreator('/docs', '57e'),
            routes: [
              {
                path: '/docs/tutorial-basics/markdown-features',
                component: ComponentCreator('/docs/tutorial-basics/markdown-features', '209'),
                exact: true,
                sidebar: "defaultSidebar"
              }
            ]
          }
        ]
      }
    ]
  },
  {
    path: '/',
    component: ComponentCreator('/', '2e1'),
    exact: true
  },
  {
    path: '*',
    component: ComponentCreator('*'),
  },
];
