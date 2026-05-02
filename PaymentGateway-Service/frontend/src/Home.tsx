import React from 'react';
import { ShieldCheck, CreditCard, Wallet, QrCode, ArrowRight, Lock, Zap } from 'lucide-react';
import { Link } from 'react-router-dom';
import { APP_BASE_URL } from './config';

export default function Home() {
  return (
    <div className="min-h-screen bg-white font-sans text-slate-900">
      {/* Navigation */}
      <nav className="flex items-center justify-between px-6 py-4 border-b border-slate-100 max-w-7xl mx-auto">
        <a href={APP_BASE_URL} className="flex items-center gap-2 hover:opacity-80 transition-opacity">
          <div className="w-10 h-10 bg-indigo-600 rounded-xl flex items-center justify-center shadow-lg shadow-indigo-200">
            <ShieldCheck className="w-6 h-6 text-white" />
          </div>
          <span className="font-extrabold text-2xl tracking-tight text-slate-900">SimuPay</span>
        </a>
        <div className="hidden md:flex items-center gap-8 text-sm font-semibold text-slate-600">
          <a href="#" className="hover:text-indigo-600 transition-colors">Productos</a>
          <a href="#" className="hover:text-indigo-600 transition-colors">Desarrolladores</a>
          <a href="#" className="hover:text-indigo-600 transition-colors">Empresas</a>
          <a href="#" className="hover:text-indigo-600 transition-colors">Precios</a>
        </div>
        <div className="flex items-center gap-4">
          <Link to="/login" className="text-sm font-bold text-slate-600 hover:text-indigo-600 px-4 py-2 transition-colors">
            Iniciar sesión
          </Link>
          <Link to="/signup" className="text-sm font-bold bg-slate-900 text-white px-5 py-2.5 rounded-full hover:bg-slate-800 transition-all shadow-md active:scale-95">
            Abrir cuenta
          </Link>
        </div>
      </nav>

      {/* Hero Section */}
      <div className="max-w-7xl mx-auto px-6 py-20 grid lg:grid-cols-2 gap-12 items-center">
        <div className="space-y-8">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-indigo-50 text-indigo-700 text-xs font-bold uppercase tracking-wider">
            <Zap className="w-3.5 h-3.5" /> La pasarela de pago del futuro
          </div>
          <h1 className="text-6xl md:text-7xl font-extrabold text-slate-900 leading-[1.1] tracking-tight">
            Pagos rápidos, <br />
            <span className="text-indigo-600 italic">sin fricciones.</span>
          </h1>
          <p className="text-xl text-slate-500 max-w-lg leading-relaxed">
            Una billetera virtual, pagos con tarjeta y códigos QR en una sola plataforma integrada. La solución definitiva para Experimental College.
          </p>
          <div className="flex flex-wrap gap-4 pt-4">
            <Link to="/signup" className="flex items-center gap-2 bg-indigo-600 text-white px-8 py-4 rounded-xl font-bold text-lg hover:bg-indigo-700 transition-all shadow-xl shadow-indigo-100 group">
              Empezar ahora <ArrowRight className="w-5 h-5 group-hover:translate-x-1 transition-transform" />
            </Link>
            <div className="flex items-center gap-3 px-6 py-4 rounded-xl border border-slate-200 text-slate-600 font-semibold hover:border-slate-300 transition-colors cursor-pointer">
              Ver documentación
            </div>
          </div>
          <div className="flex items-center gap-6 pt-8 text-sm text-slate-400 font-medium">
            <div className="flex items-center gap-2">
              <Lock className="w-4 h-4" /> Encriptación SSL
            </div>
            <div className="flex items-center gap-2">
              <ShieldCheck className="w-4 h-4" /> Certificación PCI
            </div>
          </div>
        </div>

        <div className="relative">
          <div className="absolute -inset-4 bg-indigo-100 rounded-3xl blur-3xl opacity-30 -z-10 animate-pulse"></div>
          <div className="bg-slate-50 rounded-[40px] p-8 border border-slate-100 shadow-2xl">
            <div className="grid grid-cols-2 gap-6">
              <div className="bg-white p-6 rounded-3xl shadow-sm border border-slate-100 space-y-4">
                <div className="w-12 h-12 bg-blue-50 text-blue-600 rounded-2xl flex items-center justify-center">
                  <CreditCard className="w-6 h-6" />
                </div>
                <h3 className="font-bold text-lg">Tarjetas</h3>
                <p className="text-sm text-slate-500">Acepta Visa y Mastercard de cualquier banco del país.</p>
              </div>
              <div className="bg-white p-6 rounded-3xl shadow-sm border border-slate-100 space-y-4">
                <div className="w-12 h-12 bg-purple-50 text-purple-600 rounded-2xl flex items-center justify-center">
                  <Wallet className="w-6 h-6" />
                </div>
                <h3 className="font-bold text-lg">Billetera</h3>
                <p className="text-sm text-slate-500">Recarga tu saldo y paga en un click con SimuPay.</p>
              </div>
              <div className="bg-white p-6 rounded-3xl shadow-sm border border-slate-100 space-y-4">
                <div className="w-12 h-12 bg-amber-50 text-amber-600 rounded-2xl flex items-center justify-center">
                  <QrCode className="w-6 h-6" />
                </div>
                <h3 className="font-bold text-lg">Pagos QR</h3>
                <p className="text-sm text-slate-500">Escanea y paga al instante con QR interconectado.</p>
              </div>
              <div className="bg-slate-900 p-6 rounded-3xl shadow-xl text-white space-y-4">
                <div className="text-indigo-400 font-bold text-xs uppercase tracking-widest">Saldo Actual</div>
                <div className="text-3xl font-black">Bs. 4,500.00</div>
                <div className="flex -space-x-2">
                  {[1,2,3].map(i => (
                    <div key={i} className="w-8 h-8 rounded-full border-2 border-slate-900 bg-slate-700"></div>
                  ))}
                  <div className="w-8 h-8 rounded-full border-2 border-slate-900 bg-indigo-600 flex items-center justify-center text-[10px] font-bold">
                    +12
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Partners / Trust */}
      <div className="bg-slate-50 py-16 border-y border-slate-100">
        <div className="max-w-7xl mx-auto px-6 text-center space-y-8">
          <p className="text-xs font-bold text-slate-400 uppercase tracking-[0.2em]">Utilizado por instituciones líderes</p>
          <div className="flex flex-wrap justify-center items-center gap-12 opacity-50 grayscale hover:grayscale-0 transition-all">
            <div className="text-2xl font-black italic">Experimental College</div>
            <div className="text-2xl font-black">BANCO UNI</div>
            <div className="text-2xl font-black">VISA</div>
            <div className="text-2xl font-black">MASTERCARD</div>
          </div>
        </div>
      </div>
    </div>
  );
}
