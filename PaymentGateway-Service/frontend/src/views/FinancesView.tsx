import React, { useState } from 'react';
import {
  DollarSign,
  Coins,
  QrCode,
  ShieldCheck,
  CheckCircle2,
  Clock,
  RotateCcw,
  AlertCircle,
  Download,
  Filter,
  Check,
  XCircle,
  TrendingUp,
  Receipt
} from 'lucide-react';
import { usePermissions } from '../context/PermissionsContext';

export const FinancesView: React.FC = () => {
  const { machines, transactions } = usePermissions();
  const [selectedFilter, setSelectedFilter] = useState<'ALL' | 'CASH' | 'QR'>('ALL');

  // Calculating 4-stage numbers
  const initiatedSalesCount = 192;
  const confirmedPaymentsCount = 186;
  const completedSalesCount = 184; // Proof of service confirmed by drop sensor
  const refundedSalesCount = 2; // Auto-refund due to coil stall or drop sensor not triggered

  const totalHopperCash = machines.reduce((sum, m) => sum + m.cashHopperBalance, 0);
  const totalDigitalQr = 8580.50;
  const grandTotal = totalHopperCash + totalDigitalQr;

  return (
    <div className="space-y-6 animate-fadeIn pb-12">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <span className="text-[11px] font-extrabold uppercase tracking-widest text-[#4F46E5] bg-indigo-50 px-2 py-0.5 rounded border border-indigo-100">
            05. FINANZAS Y CONCILIACIÓN
          </span>
          <h2 className="text-2xl font-black text-slate-900 tracking-tight mt-1">
            Ciclo de Pago & Conciliación Proof of Service
          </h2>
          <p className="text-xs text-slate-500">
            Auditoría en 4 etapas: nunca se confunde dinero capturado con producto efectivamente dispensado.
          </p>
        </div>

        <button
          onClick={() => alert('Generando informe de conciliación contable en CSV/PDF...')}
          className="px-4 py-2.5 rounded-xl bg-white border border-slate-200 hover:border-indigo-300 text-slate-700 hover:text-[#4F46E5] text-xs font-bold flex items-center gap-2 shadow-2xs transition-all"
        >
          <Download className="w-4 h-4 text-indigo-600" />
          <span>Exportar Informe Contable</span>
        </button>
      </div>

      {/* The 4 Core Transaction Lifecycle Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* Stage 1: Iniciadas */}
        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-2xs">
          <div className="flex items-center justify-between text-slate-400 mb-2">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-500">
              1. Ventas Iniciadas
            </span>
            <Clock className="w-4 h-4 text-slate-400" />
          </div>
          <div className="flex items-baseline gap-2">
            <span className="text-3xl font-black text-slate-800">{initiatedSalesCount}</span>
            <span className="text-xs text-slate-400">sesiones</span>
          </div>
          <p className="text-[11px] text-slate-400 mt-2">QR escaneado o moneda ingresada</p>
        </div>

        {/* Stage 2: Pagos Confirmados */}
        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-2xs">
          <div className="flex items-center justify-between text-slate-400 mb-2">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-500">
              2. Pagos Confirmados
            </span>
            <CheckCircle2 className="w-4 h-4 text-indigo-500" />
          </div>
          <div className="flex items-baseline gap-2">
            <span className="text-3xl font-black text-indigo-600">{confirmedPaymentsCount}</span>
            <span className="text-xs text-emerald-600 font-bold">96.8%</span>
          </div>
          <p className="text-[11px] text-slate-400 mt-2">Dinero capturado en banco / validador</p>
        </div>

        {/* Stage 3: Ventas Completadas (Proof of Service) */}
        <div className="bg-white p-5 rounded-2xl border border-emerald-200/80 bg-emerald-50/20 shadow-2xs">
          <div className="flex items-center justify-between text-slate-400 mb-2">
            <span className="text-xs font-bold uppercase tracking-wider text-emerald-800">
              3. Proof of Service
            </span>
            <ShieldCheck className="w-4 h-4 text-emerald-600" />
          </div>
          <div className="flex items-baseline gap-2">
            <span className="text-3xl font-black text-emerald-700">{completedSalesCount}</span>
            <span className="text-xs text-emerald-600 font-bold">Completadas</span>
          </div>
          <p className="text-[11px] text-emerald-700 mt-2">Sensor láser confirmó caída de ítem</p>
        </div>

        {/* Stage 4: Reembolsos Automáticos */}
        <div className="bg-white p-5 rounded-2xl border border-rose-200/80 bg-rose-50/20 shadow-2xs">
          <div className="flex items-center justify-between text-slate-400 mb-2">
            <span className="text-xs font-bold uppercase tracking-wider text-rose-800">
              4. Reembolsos Auto
            </span>
            <RotateCcw className="w-4 h-4 text-rose-600" />
          </div>
          <div className="flex items-baseline gap-2">
            <span className="text-3xl font-black text-rose-700">{refundedSalesCount}</span>
            <span className="text-xs text-rose-600 font-bold">Devueltos</span>
          </div>
          <p className="text-[11px] text-rose-700 mt-2">Sin caída de producto = Reembolso 100%</p>
        </div>
      </div>

      {/* Breakdown: Cash (Nivel 0) vs QR (Nivel 1) */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Nivel 0: Arqueo de Tolvas Físicas MDB */}
        <div className="bg-white rounded-3xl border border-slate-200 p-6 shadow-sm space-y-4">
          <div className="flex items-center justify-between pb-4 border-b border-slate-100">
            <div className="flex items-center gap-3">
              <div className="p-2.5 rounded-xl bg-amber-50 text-amber-600 border border-amber-200/60">
                <Coins className="w-5 h-5" />
              </div>
              <div>
                <h3 className="text-base font-extrabold text-slate-900">
                  Nivel 0: Arqueo Físico en Tolvas (MDB)
                </h3>
                <p className="text-xs text-slate-500">
                  Monedas recaudadas auditadas por el validador mecánico.
                </p>
              </div>
            </div>
            <span className="text-xl font-black text-amber-600">
              Bs {totalHopperCash.toFixed(2)}
            </span>
          </div>

          <div className="space-y-3">
            {machines.map(m => (
              <div
                key={m.id}
                className="p-3.5 rounded-2xl bg-slate-50/80 border border-slate-200 flex items-center justify-between"
              >
                <div>
                  <p className="text-xs font-bold text-slate-800">{m.name} ({m.id})</p>
                  <p className="text-[11px] text-slate-400">Tubos de cambio: 1 Bs, 2 Bs, 5 Bs</p>
                </div>
                <div className="text-right">
                  <p className="text-sm font-black text-slate-900">
                    Bs {m.cashHopperBalance.toFixed(2)}
                  </p>
                  <span className="text-[10px] text-emerald-600 font-bold">Sin atascos</span>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Nivel 1: Cobros QR Dinámicos (SimuPay & Bancos) */}
        <div className="bg-white rounded-3xl border border-slate-200 p-6 shadow-sm space-y-4">
          <div className="flex items-center justify-between pb-4 border-b border-slate-100">
            <div className="flex items-center gap-3">
              <div className="p-2.5 rounded-xl bg-indigo-50 text-[#4F46E5] border border-indigo-200/60">
                <QrCode className="w-5 h-5" />
              </div>
              <div>
                <h3 className="text-base font-extrabold text-slate-900">
                  Nivel 1: Liquidaciones QR Dinámicas
                </h3>
                <p className="text-xs text-slate-500">
                  Conciliación 1:1 mediante payload JSON con SKU y cuenta.
                </p>
              </div>
            </div>
            <span className="text-xl font-black text-[#4F46E5]">
              Bs {totalDigitalQr.toFixed(2)}
            </span>
          </div>

          <div className="p-4 rounded-2xl bg-indigo-50/50 border border-indigo-100 space-y-2">
            <div className="flex items-center justify-between text-xs">
              <span className="text-slate-600">Liquidación Bancaria Inmediata:</span>
              <span className="font-bold text-emerald-600">Completada (0 disputas)</span>
            </div>
            <div className="flex items-center justify-between text-xs">
              <span className="text-slate-600">Comisión de Pasarela (SimuPay / ACH):</span>
              <span className="font-bold text-slate-700">1.2% (Bs 102.96)</span>
            </div>
            <div className="flex items-center justify-between text-xs pt-2 border-t border-indigo-100/60">
              <span className="font-bold text-slate-800">Neto Depositado:</span>
              <span className="font-black text-[#4F46E5] text-sm">Bs 8,477.54</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
