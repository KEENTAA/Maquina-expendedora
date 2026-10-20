import React, { useState } from 'react';
import {
  Package,
  Calendar,
  AlertTriangle,
  CheckCircle2,
  Tag,
  Plus,
  Search,
  Filter,
  ArrowUpDown,
  Clock,
  Layers,
  Sparkles
} from 'lucide-react';
import { usePermissions } from '../context/PermissionsContext';

export const InventoryView: React.FC = () => {
  const { machines, restockMachine } = usePermissions();
  const [searchTerm, setSearchTerm] = useState('');
  const [filterExpiry, setFilterExpiry] = useState<'ALL' | 'CRITICAL' | 'MODERATE' | 'OPTIMAL'>('ALL');

  // Flatten all products across all machines
  const allProducts = machines.flatMap(m =>
    m.products.map(p => ({
      ...p,
      machineId: m.id,
      machineName: m.name,
      location: m.location,
    }))
  );

  const filteredProducts = allProducts.filter(p => {
    const matchesSearch = p.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
                          p.sku.toLowerCase().includes(searchTerm.toLowerCase()) ||
                          p.machineId.toLowerCase().includes(searchTerm.toLowerCase());
    const matchesExpiry = filterExpiry === 'ALL' || p.expiryStatus === filterExpiry;
    return matchesSearch && matchesExpiry;
  });

  return (
    <div className="space-y-6 animate-fadeIn pb-12">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <span className="text-[11px] font-extrabold uppercase tracking-widest text-[#4F46E5] bg-indigo-50 px-2 py-0.5 rounded border border-indigo-100">
            06. INVENTARIO & GESTIÓN DE LOTES
          </span>
          <h2 className="text-2xl font-black text-slate-900 tracking-tight mt-1">
            Control de Existencias & Fechas de Vencimiento
          </h2>
          <p className="text-xs text-slate-500">
            Seguimiento de lotes perecederos, reglas de Dynamic Expiry Markdown y órdenes de reabastecimiento.
          </p>
        </div>

        <button
          onClick={() => alert('Asistente de registro de lote y asignación de slots abierto.')}
          className="px-4 py-2.5 rounded-xl bg-[#4F46E5] hover:bg-[#4338CA] text-white font-bold text-xs flex items-center gap-2 transition-all shadow-md shadow-indigo-600/20"
        >
          <Plus className="w-4 h-4" />
          <span>Registrar Nuevo Lote</span>
        </button>
      </div>

      {/* Expiry Risk Highlights */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="p-5 rounded-2xl bg-rose-50/70 border border-rose-200">
          <div className="flex items-center justify-between text-rose-800 text-xs font-bold mb-1">
            <span>Riesgo Crítico (≤ 4 días)</span>
            <AlertTriangle className="w-4 h-4 text-rose-600" />
          </div>
          <p className="text-2xl font-black text-rose-900">2 productos</p>
          <p className="text-[11px] text-rose-700 mt-1">
            Descuento automático de 30% a 40% aplicado para acelerar consumo.
          </p>
        </div>

        <div className="p-5 rounded-2xl bg-amber-50/70 border border-amber-200">
          <div className="flex items-center justify-between text-amber-800 text-xs font-bold mb-1">
            <span>Riesgo Moderado (5 a 10 días)</span>
            <Clock className="w-4 h-4 text-amber-600" />
          </div>
          <p className="text-2xl font-black text-amber-900">3 productos</p>
          <p className="text-[11px] text-amber-700 mt-1">
            Monitoreados por la IA para sugerir promociones teledirigidas.
          </p>
        </div>

        <div className="p-5 rounded-2xl bg-emerald-50/70 border border-emerald-200">
          <div className="flex items-center justify-between text-emerald-800 text-xs font-bold mb-1">
            <span>Estado Óptimo (&gt; 15 días)</span>
            <CheckCircle2 className="w-4 h-4 text-emerald-600" />
          </div>
          <p className="text-2xl font-black text-emerald-900">5 productos</p>
          <p className="text-[11px] text-emerald-700 mt-1">
            Precios regulares de venta sin necesidad de markdown.
          </p>
        </div>
      </div>

      {/* Filters and Search */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div className="relative flex-1 max-w-md">
          <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            placeholder="Buscar por producto, SKU o máquina..."
            value={searchTerm}
            onChange={e => setSearchTerm(e.target.value)}
            className="w-full pl-10 pr-4 py-2.5 rounded-xl bg-white border border-slate-200 text-xs text-slate-800 placeholder-slate-400 focus:outline-hidden focus:border-indigo-400 shadow-2xs"
          />
        </div>

        <div className="flex items-center gap-1.5 bg-slate-100 p-1 rounded-xl border border-slate-200 text-xs font-bold overflow-x-auto">
          <button
            onClick={() => setFilterExpiry('ALL')}
            className={`px-3 py-1.5 rounded-lg transition-all ${
              filterExpiry === 'ALL' ? 'bg-white text-slate-900 shadow-2xs' : 'text-slate-600'
            }`}
          >
            Todos ({allProducts.length})
          </button>
          <button
            onClick={() => setFilterExpiry('CRITICAL')}
            className={`px-3 py-1.5 rounded-lg transition-all ${
              filterExpiry === 'CRITICAL' ? 'bg-white text-rose-700 shadow-2xs' : 'text-slate-600'
            }`}
          >
            Críticos
          </button>
          <button
            onClick={() => setFilterExpiry('MODERATE')}
            className={`px-3 py-1.5 rounded-lg transition-all ${
              filterExpiry === 'MODERATE' ? 'bg-white text-amber-700 shadow-2xs' : 'text-slate-600'
            }`}
          >
            Moderados
          </button>
          <button
            onClick={() => setFilterExpiry('OPTIMAL')}
            className={`px-3 py-1.5 rounded-lg transition-all ${
              filterExpiry === 'OPTIMAL' ? 'bg-white text-emerald-700 shadow-2xs' : 'text-slate-600'
            }`}
          >
            Óptimos
          </button>
        </div>
      </div>

      {/* Table */}
      <div className="bg-white rounded-3xl border border-slate-200 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="bg-slate-50/70 border-b border-slate-200 text-slate-400 font-bold uppercase tracking-wider text-[10px]">
                <th className="py-3.5 px-6">Producto / SKU</th>
                <th className="py-3.5 px-4">Máquina & Slot</th>
                <th className="py-3.5 px-4">Stock Restante</th>
                <th className="py-3.5 px-4">Días a Caducar</th>
                <th className="py-3.5 px-4">Precio Base</th>
                <th className="py-3.5 px-4">Precio Dinámico</th>
                <th className="py-3.5 px-6 text-right">Acción</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {filteredProducts.map(p => (
                <tr key={`${p.machineId}-${p.sku}`} className="hover:bg-slate-50/60 transition-colors">
                  <td className="py-4 px-6">
                    <div className="font-bold text-slate-900">{p.name}</div>
                    <div className="text-[11px] text-slate-400 font-mono">{p.sku} · {p.category}</div>
                  </td>
                  <td className="py-4 px-4">
                    <span className="font-bold text-slate-800">{p.machineId}</span>
                    <span className="text-[11px] text-slate-400 block">Slot {p.slot}</span>
                  </td>
                  <td className="py-4 px-4">
                    <span className="font-black text-slate-900">{p.currentStock} / {p.maxStock}</span>
                    <div className="w-20 bg-slate-100 rounded-full h-1.5 mt-1 overflow-hidden">
                      <div
                        className={`h-1.5 rounded-full ${
                          p.currentStock > 10 ? 'bg-emerald-500' : 'bg-rose-500'
                        }`}
                        style={{ width: `${(p.currentStock / p.maxStock) * 100}%` }}
                      />
                    </div>
                  </td>
                  <td className="py-4 px-4">
                    {p.daysToExpiry <= 4 ? (
                      <span className="px-2 py-0.5 rounded-full font-bold text-[10px] bg-rose-100 text-rose-800">
                        {p.daysToExpiry} días (Crítico)
                      </span>
                    ) : p.daysToExpiry <= 10 ? (
                      <span className="px-2 py-0.5 rounded-full font-bold text-[10px] bg-amber-100 text-amber-800">
                        {p.daysToExpiry} días (Moderado)
                      </span>
                    ) : (
                      <span className="px-2 py-0.5 rounded-full font-bold text-[10px] bg-emerald-100 text-emerald-800">
                        {p.daysToExpiry} días (Óptimo)
                      </span>
                    )}
                  </td>
                  <td className="py-4 px-4 font-mono text-slate-500">
                    Bs {p.basePrice.toFixed(2)}
                  </td>
                  <td className="py-4 px-4">
                    <span className="font-black text-[#4F46E5] text-sm">
                      Bs {p.currentPrice.toFixed(2)}
                    </span>
                    {p.discountPercent > 0 && (
                      <span className="text-[10px] font-bold text-rose-600 block">
                        -{p.discountPercent}% descuento IA
                      </span>
                    )}
                  </td>
                  <td className="py-4 px-6 text-right">
                    <button
                      onClick={() => alert(`Lote de ${p.name} actualizado.`)}
                      className="text-xs font-bold text-[#4F46E5] hover:text-[#4338CA] hover:underline"
                    >
                      Ajustar Lote
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};
