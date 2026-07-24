import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { createBrowserRouter, RouterProvider } from 'react-router-dom'
import './styles/global.css'
import App from './App.tsx'

const router = createBrowserRouter(
  [{ path: '/:slug?/:chapter?', element: <App /> }],
  { basename: import.meta.env.BASE_URL.replace(/\/$/, '') || '/' },
)
createRoot(document.getElementById('root')!).render(
  <StrictMode><RouterProvider router={router} /></StrictMode>,
)
