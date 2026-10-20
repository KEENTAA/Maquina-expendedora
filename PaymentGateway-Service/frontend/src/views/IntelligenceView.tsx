import React, { useState } from 'react';
import {
  Sparkles,
  Brain,
  TrendingUp,
  AlertTriangle,
  CheckCircle2,
  Clock,
  ArrowRight,
  ShieldCheck,
  Zap,
  Tag,
  Sliders,
  DollarSign,
  Lightbulb
} from 'lucide-react';
import GrogFrogMascot from '../GrogFrogMascot';

export const IntelligenceView: React.FC = () => {
  const [appliedAction, setAppliedAction] = useState<string | null>(null);

  const handleApply = (id: string, text: string) => {
    setAppliedAction(text);
    setTimeout(() => setAppliedAction(null), 4000);
  };

  return (
    <div className="space-y-6 animate-fadeIn pb-12">
      {/* Header */}
      <div>
        <span className="text-[11px] font-extrabold uppercase tracking-widest text-[#4F46E5] bg-indigo-50 px-2 py-0.5 rounded border border-indigo-100">
          07. GROG INTELLIGENCE (IA EXPLICABLE)
        </span>
        <h2 className="text-2xl font-black text-slate-900 tracking-tight mt-1">
          Motor de Recomendaciones & Alertas Operativas
        </h2>
        <p className="text-xs text-slate-500">
          Inteligencia artificial que no es una caja negra: cada propuesta incluye fundamento técnico, impacto económico y confirmación humana con 1 clic.
        </p>
      </div>

      {/* Mascot Big Interactive Hero Card */}
      <div className="bg-gradient-to-r from-slate-900 via-[#1E1B4B] to-[#312E81] text-white p-6 md:p-8 rounded-3xl shadow-xl border border-indigo-900/40 relative overflow-hidden">
        <div className="flex flex-col md:flex-row items-center gap-6">
          <div className="shrink-0">
            <GrogFrogMascot
              size={100}
              expression="happy"
              showBubble={false}
            />
          </div>

          <div className="flex-1 text-center md:text-left">
            <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-indigo-500/20 text-indigo-200 border border-indigo-400/30 text-xs font-bold mb-2">
              <Lightbulb className="w-3.5 h-3.5 text-amber-300" />
              <span>Diagnóstico General de la Flota</span>
            </div>
            <h3 className="text-xl md:text-2xl font-black text-white">
              Rendimiento Operativo Óptimo: 94.2/100
            </h3>
            <p className="text-xs text-indigo-100/80 mt-1 max-w-xl">
              "Detecté 3 oportunidades prioritarias para hoy: 1 rebaja por caducidad en snacks, 1 previsión de reposición de insumos de café y 1 optimización de precio en bebidas isotónicas para el horario de gimnasio."
            </p>
          </div>
        </div>
      </div>

      {/* Applied Banner */}
      {appliedAction && (
        <div className="p-4 rounded-2xl bg-emerald-50 border border-emerald-200 text-emerald-800 text-xs font-bold flex items-center gap-2 animate-fadeIn">
          <CheckCircle2 className="w-4 h-4 text-emerald-600" />
          <span>{appliedAction}</span>
        </div>
      )}

      {/* Recommendations Cards Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Recommendation 1 */}
        <div className="bg-white rounded-3xl border border-slate-200 p-6 shadow-sm hover:border-indigo-300 transition-all flex flex-col justify-between">
          <div>
            <div className="flex items-center justify-between mb-3">
              <span className="text-[10px] font-extrabold uppercase tracking-wider px-2.5 py-1 rounded-full bg-rose-50 text-rose-700 border border-rose-200">
                Prevención de Merma
              </span>
              <span className="text-xs font-bold text-slate-400">Prioridad Alta</span>
            </div>

            <h4 className="text-base font-extrabold text-slate-900">
              Activar Rebaja del 30% en Papas Fritas (VENDING-01)
            </h4>
            <p className="text-xs text-slate-500 mt-1.5 leading-relaxed">
              <strong>Motivo:</strong> Lote de 12 unidades vencerá en 4 días. El modelo predictivo indica que con precio regular sólo se venderán 3 unidades, dejando 9 unidades de merma (pérdida de Bs 45.00). Con -30% se proyecta venta total del 100%.
            </p>

            <div className="mt-4 p-3 rounded-xl bg-slate-50 border border-slate-100 flex items-center justify-between text-xs">
              <span className="text-slate-500">Impacto Estimado:</span>
              <span className="font-extrabold text-emerald-600">+Bs 42.00 recuperados</span>
            </div>
          </div>

          <button
            onClick={() => handleApply('REC-1', '¡Rebaja del 30% aplicada inmediatamente en VENDING-01 y enviada a la App!')}
            className="mt-5 w-full py-2.5 px-4 rounded-xl bg-[#4F46E5] hover:bg-[#4338CA] text-white text-xs font-bold flex items-center justify-center gap-2 transition-all shadow-md shadow-indigo-600/20"
          >
            <span>Aplicar Rebaja Inmediata</span>
            <ArrowRight className="w-3.5 h-3.5" />
          </button>
        </div>

        {/* Recommendation 2 */}
        <div className="bg-white rounded-3xl border border-slate-200 p-6 shadow-sm hover:border-indigo-300 transition-all flex flex-col justify-between">
          <div>
            <div className="flex items-center justify-between mb-3">
              <span className="text-[10px] font-extrabold uppercase tracking-wider px-2.5 py-1 rounded-full bg-amber-50 text-amber-700 border border-amber-200">
                Mantenimiento & Insumos
              </span>
              <span className="text-xs font-bold text-slate-400">Prioridad Media</span>
            </div>

            <h4 className="text-base font-extrabold text-slate-900">
              Programar Reposición de Silo Leche en COFFEE-01
            </h4>
            <p className="text-xs text-slate-500 mt-1.5 leading-relaxed">
              <strong>Motivo:</strong> Capuchino Cremoso tiene sólo 9 dosis disponibles. Al ritmo de consumo habitual del coworking (14 dosis/día), el producto se agotará mañana a las 11:30 AM provocando pérdida de ventas en la hora pico.
            </p>

            <div className="mt-4 p-3 rounded-xl bg-slate-50 border border-slate-100 flex items-center justify-between text-xs">
              <span className="text-slate-500">Ventas en Riesgo:</span>
              <span className="font-extrabold text-amber-700">Bs 112.50 (15 clientes)</span>
            </div>
          </div>

          <button
            onClick={() => handleApply('REC-2', '¡Ruta de reposición creada en el calendario del técnico de campo!')}
            className="mt-5 w-full py-2.5 px-4 rounded-xl bg-slate-900 hover:bg-slate-800 text-white text-xs font-bold flex items-center justify-center gap-2 transition-all shadow-md"
          >
            <span>Programar Visita de Reposición</span>
            <ArrowRight className="w-3.5 h-3.5" />
          </button>
        </div>
      </div>
    </div>
  );
};
