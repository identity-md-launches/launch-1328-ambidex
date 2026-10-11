import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { App } from './App';
import { WalletProvider } from './lib/WalletContext';
import './styles.css';

const root = document.getElementById('root');
if (!root) throw new Error('Missing #root element');

createRoot(root).render(
  <StrictMode>
    <WalletProvider>
      <App />
    </WalletProvider>
  </StrictMode>,
);
