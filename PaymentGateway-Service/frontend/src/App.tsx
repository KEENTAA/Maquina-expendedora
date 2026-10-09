import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import Checkout from './Checkout';
import Home from './Home';
import Login from './Login';
import Signup from './Signup';
import Wallet from './Wallet';
import GrogCrmPlatform from './GrogCrmPlatform';
import GrogCrmDashboard from './GrogCrmDashboard';

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<GrogCrmPlatform />} />
        <Route path="/crm" element={<GrogCrmDashboard />} />
        <Route path="/home" element={<Home />} />
        <Route path="/login" element={<Login />} />
        <Route path="/signup" element={<Signup />} />
        <Route path="/wallet" element={<Wallet />} />
        <Route path="/checkout/:sessionId" element={<Checkout />} />
        {/* Fallback for legacy /checkout/ (old index.html approach) */}
        <Route path="/checkout" element={<Checkout />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
