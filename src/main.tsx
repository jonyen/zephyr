import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { createBrowserRouter, RouterProvider } from 'react-router-dom'
import './styles/global.css'
import App from './App.tsx'

// Restore a deep link stashed by deploy/root-404.html's redirect (GitHub Pages only honors a
// 404.html at the site ROOT, so a hard reload of e.g. /zephyr/isaiah/40 bounces through the
// root 404 page, which redirects here with the original path encoded as ?p=...). Swap it back
// into the URL before the router reads location, so it boots on the restored deep path.
if (location.search.startsWith('?p=')) {
  const restored = new URLSearchParams(location.search).get('p')
  if (restored) history.replaceState(null, '', decodeURIComponent(restored))
}

const router = createBrowserRouter(
  [{ path: '/:slug?/:chapter?', element: <App /> }],
  { basename: import.meta.env.BASE_URL.replace(/\/$/, '') || '/' },
)
createRoot(document.getElementById('root')!).render(
  <StrictMode><RouterProvider router={router} /></StrictMode>,
)
