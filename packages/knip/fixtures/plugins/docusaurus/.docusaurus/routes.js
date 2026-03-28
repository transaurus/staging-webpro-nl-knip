import React from 'react';
import ComponentCreator from '@docusaurus/ComponentCreator';

export default [
  {
    path: '/zh-Hans/blog',
    component: ComponentCreator('/zh-Hans/blog', 'ce7'),
    exact: true
  },
  {
    path: '/zh-Hans/blog/2021/08/01/mdx-blog-post',
    component: ComponentCreator('/zh-Hans/blog/2021/08/01/mdx-blog-post', '243'),
    exact: true
  },
  {
    path: '/zh-Hans/blog/archive',
    component: ComponentCreator('/zh-Hans/blog/archive', 'c6a'),
    exact: true
  },
  {
    path: '/zh-Hans/docs',
    component: ComponentCreator('/zh-Hans/docs', '45b'),
    routes: [
      {
        path: '/zh-Hans/docs',
        component: ComponentCreator('/zh-Hans/docs', 'bf5'),
        routes: [
          {
            path: '/zh-Hans/docs',
            component: ComponentCreator('/zh-Hans/docs', '422'),
            routes: [
              {
                path: '/zh-Hans/docs/tutorial-basics/markdown-features',
                component: ComponentCreator('/zh-Hans/docs/tutorial-basics/markdown-features', '026'),
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
    path: '/zh-Hans/',
    component: ComponentCreator('/zh-Hans/', 'fba'),
    exact: true
  },
  {
    path: '*',
    component: ComponentCreator('*'),
  },
];
