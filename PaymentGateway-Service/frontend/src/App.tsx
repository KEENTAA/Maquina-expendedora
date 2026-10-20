import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import Checkout from './Checkout';
import Home from './Home';
import Login from './Login';
import Signup from './Signup';
import Wallet from './Wallet';
import GrogPlatformMain from './GrogPlatformMain';
import GrogCrmPlatform from './GrogCrmPlatform';
import GrogCrmDashboard from './GrogCrmDashboard';

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        {/* GROG Intelligent Operations Platform (Main Centro de Control) */}
        <Route path="/" element={<GrogPlatformMain />} />
        <Route path="/platform" element={<GrogPlatformMain />} />
        <Route path="/crm" element={<GrogPlatformMain />} />

        {/* Pitch & Level 0-3 Explanatory Landing */}
        <Route path="/pitch" element={<GrogCrmPlatform />} />
        <Route path="/overview" element={<GrogCrmPlatform />} />

        {/* SimuPay & Authentication Modules */}
        <Route path="/wallet" element={<Wallet />} />
        <Route path="/checkout/:sessionId" element={<Checkout />} />
        <Route path="/checkout" element={<Checkout />} />
        <Route path="/home" element={<Home />} />
        <Route path="/login" element={<Login />} />
        <Route path="/signup" element={<Signup />} />

        {/* Fallback */}
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
