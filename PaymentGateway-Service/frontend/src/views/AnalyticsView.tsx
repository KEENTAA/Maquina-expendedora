import React, { useState } from 'react';
import {
  TrendingUp,
  Brain,
  Sparkles,
  BarChart3,
  Calendar,
  DollarSign,
  ArrowUpRight,
  ArrowDownRight,
  Percent,
  Sliders,
  CheckCircle2,
  Clock
} from 'lucide-react';

export const AnalyticsView: React.FC = () => {
  const [discountScenario, setDiscountScenario] = useState<number>(30);

  // Simulated metrics based on dynamic discount
  const projectedWasteReduction = Math.round(55 + (discountScenario * 1.1));
  const projectedRevenueGain = Math.round(1200 + (discountScenario * 25));

  return (
    <div className="space-y-6 animate-fadeIn pb-12">
      {/* Header */}
      <div>
        <span className="text-[11px] font-extrabold uppercase tracking-widest text-[#4F46E5] bg-indigo-50 px-2 py-0.5 rounded border border-indigo-100">
          04. ANALÍTICA AVANZADA E IA
        </span>
        <h2 className="text-2xl font-black text-slate-900 tracking-tight mt-1">
          Predicción de Demanda & Escenarios de Descuento
        </h2>
        <p className="text-xs text-slate-500">
          Algoritmos de aprendizaje sobre rotación de inventario, elasticidad de precio y prevención de pérdidas.
        </p>
      </div>

      {/* Analytics KPI Cards */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-2xs">
          <p className="text-xs font-bold text-slate-400 uppercase tracking-wider">Margen Bruto Promedio</p>
          <div className="flex items-baseline gap-2 mt-1">
            <span className="text-2xl font-black text-slate-900">42.8%</span>
            <span className="text-xs font-bold text-emerald-600 flex items-center">
              <ArrowUpRight className="w-3.5 h-3.5" /> +3.2%
            </span>
          </div>
          <p className="text-[11px] text-slate-500 mt-2">Optimizado con precios dinámicos</p>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-2xs">
          <p className="text-xs font-bold text-slate-400 uppercase tracking-wider">Merma Evitada Este Mes</p>
          <div className="flex items-baseline gap-2 mt-1">
            <span className="text-2xl font-black text-emerald-600">Bs 1,840</span>
            <span className="text-xs font-bold text-emerald-600 flex items-center">
              <ArrowUpRight className="w-3.5 h-3.5" /> 84% recuperado
            </span>
          </div>
          <p className="text-[11px] text-slate-500 mt-2">Productos vendidos antes de caducar</p>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-2xs">
          <p className="text-xs font-bold text-slate-400 uppercase tracking-wider">Ticket Promedio</p>
          <div className="flex items-baseline gap-2 mt-1">
            <span className="text-2xl font-black text-slate-900">Bs 5.40</span>
            <span className="text-xs font-bold text-emerald-600 flex items-center">
              <ArrowUpRight className="w-3.5 h-3.5" /> +0.60 Bs
            </span>
          </div>
          <p className="text-[11px] text-slate-500 mt-2">Impulsado por pagos QR 1:1</p>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-2xs">
          <p className="text-xs font-bold text-slate-400 uppercase tracking-wider">Hora Pico de Mayor Tráfico</p>
          <div className="flex items-baseline gap-2 mt-1">
            <span className="text-2xl font-black text-indigo-700">10:30 AM & 16:15 PM</span>
          </div>
          <p className="text-[11px] text-slate-500 mt-2">Picos de cafetería y snacks</p>
        </div>
      </div>

      {/* Hourly Sales Visual Chart */}
      <div className="bg-white rounded-3xl border border-slate-200 shadow-sm p-6 space-y-4">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
          <div>
            <h3 className="text-base font-extrabold text-slate-900">
              Curva de Demanda por Franja Horaria (24h)
            </h3>
            <p className="text-xs text-slate-500">
              Distribución de compras entre pagos en efectivo MDB y pagos digitales QR.
            </p>
          </div>
          <div className="flex items-center gap-4 text-xs font-bold">
            <span className="flex items-center gap-1.5 text-[#4F46E5]">
              <span className="w-2.5 h-2.5 rounded-full bg-[#4F46E5]" /> Pagos QR (64%)
            </span>
            <span className="flex items-center gap-1.5 text-amber-600">
              <span className="w-2.5 h-2.5 rounded-full bg-amber-500" /> Monedas MDB (36%)
            </span>
          </div>
        </div>

        {/* Visual Bar chart */}
        <div className="h-48 flex items-end gap-2 pt-6 pb-2 border-b border-slate-100">
          {[
            { hour: '07h', qr: 15, cash: 10 },
            { hour: '08h', qr: 35, cash: 20 },
            { hour: '09h', qr: 55, cash: 30 },
            { hour: '10h', qr: 85, cash: 45 },
            { hour: '11h', qr: 70, cash: 35 },
            { hour: '12h', qr: 60, cash: 40 },
            { hour: '13h', qr: 50, cash: 25 },
            { hour: '14h', qr: 45, cash: 30 },
            { hour: '15h', qr: 65, cash: 35 },
            { hour: '16h', qr: 90, cash: 40 },
            { hour: '17h', qr: 75, cash: 30 },
            { hour: '18h', qr: 50, cash: 20 },
            { hour: '19h', qr: 30, cash: 15 },
            { hour: '20h', qr: 20, cash: 10 },
          ].map((bar, idx) => (
            <div key={idx} className="flex-1 flex flex-col items-center gap-1 h-full justify-end group">
              <div className="w-full flex flex-col gap-0.5 justify-end h-full">
                <div
                  className="w-full bg-[#4F46E5] rounded-t-sm transition-all group-hover:bg-[#4338CA]"
                  style={{ height: `${(bar.qr / 140) * 100}%` }}
                  title={`QR: ${bar.qr} txs`}
                />
                <div
                  className="w-full bg-amber-400 rounded-b-sm transition-all group-hover:bg-amber-500"
                  style={{ height: `${(bar.cash / 140) * 100}%` }}
                  title={`CASH: ${bar.cash} txs`}
                />
              </div>
              <span className="text-[10px] text-slate-400 font-mono mt-1">{bar.hour}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Simulator: Interactive AI Discount Scenarios */}
      <div className="bg-gradient-to-br from-indigo-50 to-white rounded-3xl border border-indigo-200/70 p-6 md:p-8 space-y-6">
        <div className="flex items-center gap-3">
          <div className="p-2.5 rounded-xl bg-[#4F46E5] text-white">
            <Brain className="w-5 h-5" />
          </div>
          <div>
            <h3 className="text-lg font-black text-slate-900">
              Simulador de Escenarios de Descuento por Vencimiento (IA)
            </h3>
            <p className="text-xs text-slate-500">
              Ajusta el porcentaje de rebaja agresiva para evaluar el balance entre velocidad de rotación y margen recuperado.
            </p>
          </div>
        </div>

        <div className="bg-white p-6 rounded-2xl border border-indigo-100 space-y-4">
          <div className="flex items-center justify-between">
            <span className="text-xs font-bold text-slate-700">Porcentaje de Descuento Simulador:</span>
            <span className="text-lg font-black text-[#4F46E5]">-{discountScenario}%</span>
          </div>

          <input
            type="range"
            min="10"
            max="60"
            step="5"
            value={discountScenario}
            onChange={e => setDiscountScenario(parseInt(e.target.value))}
            className="w-full accent-[#4F46E5] cursor-pointer"
          />

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 pt-2">
            <div className="p-4 rounded-xl bg-slate-50 border border-slate-200">
              <p className="text-xs text-slate-500 font-medium">Tasa de Reducción de Merma:</p>
              <p className="text-2xl font-black text-emerald-600 mt-1">
                {projectedWasteReduction}% de éxito
              </p>
              <p className="text-[11px] text-slate-400 mt-1">
                El 92% de los compradores en App aceptan la oferta si el descuento supera el 25%.
              </p>
            </div>

            <div className="p-4 rounded-xl bg-slate-50 border border-slate-200">
              <p className="text-xs text-slate-500 font-medium">Ingreso Recuperado Mensual Estimado:</p>
              <p className="text-2xl font-black text-indigo-700 mt-1">
                +Bs {projectedRevenueGain.toLocaleString()}
              </p>
              <p className="text-[11px] text-slate-400 mt-1">
                Dinero que en vending tradicional se convertía en merma y pérdida directa de coste.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
