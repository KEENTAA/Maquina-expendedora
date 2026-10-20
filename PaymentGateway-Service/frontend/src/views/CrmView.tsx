import React, { useState } from 'react';
import {
  Users,
  Search,
  Filter,
  Send,
  Sparkles,
  Smartphone,
  DollarSign,
  TrendingUp,
  Tag,
  CheckCircle2,
  Clock,
  QrCode,
  Coins,
  ShieldCheck,
  ChevronRight
} from 'lucide-react';
import { CustomerProfile } from '../types/platform';
import GrogFrogMascot from '../GrogFrogMascot';

const INITIAL_CUSTOMERS: CustomerProfile[] = [
  {
    id: 'CUST-101',
    name: 'Carlos Mendoza',
    email: 'carlos.mendoza@empresa.com',
    phone: '+591 701-23456',
    rfmSegment: 'CHAMPION',
    totalSpent: 420.50,
    purchaseCount: 48,
    lastPurchaseDate: 'Hoy, 09:42',
    favoriteProduct: 'Café Espresso Doble',
    preferredMethod: 'QR',
    discountSavings: 45.00,
  },
  {
    id: 'CUST-102',
    name: 'Sofia Vargas',
    email: 'sofia.vargas@gymfit.com',
    phone: '+591 712-34567',
    rfmSegment: 'LOYAL',
    totalSpent: 310.00,
    purchaseCount: 32,
    lastPurchaseDate: 'Ayer, 18:20',
    favoriteProduct: 'Bebida Isotónica 500ml',
    preferredMethod: 'QR',
    discountSavings: 62.00,
  },
  {
    id: 'CUST-103',
    name: 'Rodrigo Paz',
    email: 'rodrigo.paz@techhub.bo',
    phone: '+591 723-45678',
    rfmSegment: 'BARGAIN_HUNTER',
    totalSpent: 185.00,
    purchaseCount: 26,
    lastPurchaseDate: 'Hace 2 días',
    favoriteProduct: 'Papas Fritas Gourmet',
    preferredMethod: 'QR',
    discountSavings: 78.50,
  },
  {
    id: 'CUST-104',
    name: 'Mariana Flores',
    email: 'mariana.f@colegio.edu.bo',
    phone: '+591 734-56789',
    rfmSegment: 'AT_RISK',
    totalSpent: 94.00,
    purchaseCount: 12,
    lastPurchaseDate: 'Hace 14 días',
    favoriteProduct: 'Agua Mineral Glaciar',
    preferredMethod: 'CASH',
    discountSavings: 12.00,
  },
];

export const CrmView: React.FC = () => {
  const [searchTerm, setSearchTerm] = useState('');
  const [segmentFilter, setSegmentFilter] = useState<string>('ALL');
  const [campaignSent, setCampaignSent] = useState(false);
  const [campaignMessage, setCampaignMessage] = useState(
    '¡Hola! Tu snack favorito Papas Fritas Gourmet tiene hoy -30% en VENDING-01 por cercanía a vencimiento.'
  );

  const filteredCustomers = INITIAL_CUSTOMERS.filter(c => {
    const matchesSearch = c.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
                          c.email.toLowerCase().includes(searchTerm.toLowerCase());
    const matchesSegment = segmentFilter === 'ALL' || c.rfmSegment === segmentFilter;
    return matchesSearch && matchesSegment;
  });

  const handleSendCampaign = (e: React.FormEvent) => {
    e.preventDefault();
    setCampaignSent(true);
    setTimeout(() => setCampaignSent(false), 4000);
  };

  return (
    <div className="space-y-6 animate-fadeIn pb-12">
      {/* Header */}
      <div>
        <span className="text-[11px] font-extrabold uppercase tracking-widest text-[#4F46E5] bg-indigo-50 px-2 py-0.5 rounded border border-indigo-100">
          03. CRM & FIDELIZACIÓN INTELIGENTE
        </span>
        <h2 className="text-2xl font-black text-slate-900 tracking-tight mt-1">
          Directorio de Clientes Identificados (Nivel 1 & 2)
        </h2>
        <p className="text-xs text-slate-500">
          Historial de consumo por usuario, segmentación algorítmica y envío de ofertas teledirigidas para reducción de mermas.
        </p>
      </div>

      {/* Campaign Sender Banner */}
      <div className="bg-gradient-to-r from-slate-900 via-[#1E1B4B] to-[#312E81] text-white p-6 rounded-3xl shadow-lg border border-indigo-900/40">
        <div className="flex flex-col lg:flex-row items-center justify-between gap-6">
          <div className="flex items-center gap-4">
            <div className="p-3 rounded-2xl bg-indigo-500/20 text-indigo-300 border border-indigo-400/30">
              <Smartphone className="w-6 h-6" />
            </div>
            <div>
              <span className="text-[10px] font-bold uppercase tracking-wider text-indigo-300">
                Campaña Teledirigida en App Móvil
              </span>
              <h3 className="text-lg font-black text-white mt-0.5">
                Enviar Notificación Push a Segmentos
              </h3>
              <p className="text-xs text-indigo-200/80 max-w-lg mt-0.5">
                Estimula la rotación de productos próximos a caducar notificando a usuarios con alta probabilidad de compra.
              </p>
            </div>
          </div>

          <form onSubmit={handleSendCampaign} className="w-full lg:w-auto flex flex-col sm:flex-row items-center gap-2">
            <input
              type="text"
              value={campaignMessage}
              onChange={e => setCampaignMessage(e.target.value)}
              className="w-full sm:w-80 px-3.5 py-2.5 rounded-xl bg-white/10 border border-white/20 text-white placeholder-slate-400 text-xs focus:outline-hidden focus:ring-2 focus:ring-indigo-400"
              placeholder="Mensaje de oferta..."
            />
            <button
              type="submit"
              className="w-full sm:w-auto px-4 py-2.5 rounded-xl bg-[#4F46E5] hover:bg-[#4338CA] text-white text-xs font-bold flex items-center justify-center gap-1.5 transition-all shadow-md shrink-0"
            >
              <Send className="w-3.5 h-3.5" />
              <span>{campaignSent ? '¡Enviado!' : 'Lanzar Campaña'}</span>
            </button>
          </form>
        </div>
      </div>

      {/* Search and Segment Filter */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div className="relative flex-1 max-w-md">
          <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2" />
          <input
            type="text"
            placeholder="Buscar por nombre, email o teléfono..."
            value={searchTerm}
            onChange={e => setSearchTerm(e.target.value)}
            className="w-full pl-10 pr-4 py-2.5 rounded-xl bg-white border border-slate-200 text-xs text-slate-800 placeholder-slate-400 focus:outline-hidden focus:border-indigo-400 shadow-2xs"
          />
        </div>

        <div className="flex items-center gap-1.5 bg-slate-100 p-1 rounded-xl border border-slate-200 text-xs font-bold overflow-x-auto">
          <button
            onClick={() => setSegmentFilter('ALL')}
            className={`px-3 py-1.5 rounded-lg transition-all ${
              segmentFilter === 'ALL' ? 'bg-white text-slate-900 shadow-2xs' : 'text-slate-600'
            }`}
          >
            Todos ({INITIAL_CUSTOMERS.length})
          </button>
          <button
            onClick={() => setSegmentFilter('CHAMPION')}
            className={`px-3 py-1.5 rounded-lg transition-all ${
              segmentFilter === 'CHAMPION' ? 'bg-white text-indigo-700 shadow-2xs' : 'text-slate-600'
            }`}
          >
            Campeones
          </button>
          <button
            onClick={() => setSegmentFilter('BARGAIN_HUNTER')}
            className={`px-3 py-1.5 rounded-lg transition-all ${
              segmentFilter === 'BARGAIN_HUNTER' ? 'bg-white text-rose-700 shadow-2xs' : 'text-slate-600'
            }`}
          >
            Cazadores Ofertas
          </button>
          <button
            onClick={() => setSegmentFilter('AT_RISK')}
            className={`px-3 py-1.5 rounded-lg transition-all ${
              segmentFilter === 'AT_RISK' ? 'bg-white text-amber-700 shadow-2xs' : 'text-slate-600'
            }`}
          >
            En Riesgo
          </button>
        </div>
      </div>

      {/* Customers Table */}
      <div className="bg-white rounded-3xl border border-slate-200 shadow-sm overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="bg-slate-50/70 border-b border-slate-200 text-slate-400 font-bold uppercase tracking-wider text-[10px]">
                <th className="py-3.5 px-6">Cliente</th>
                <th className="py-3.5 px-4">Segmento RFM</th>
                <th className="py-3.5 px-4">Consumo Total</th>
                <th className="py-3.5 px-4">Compras</th>
                <th className="py-3.5 px-4">Producto Favorito</th>
                <th className="py-3.5 px-4">Método Preferido</th>
                <th className="py-3.5 px-6 text-right">Última Compra</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {filteredCustomers.map(customer => (
                <tr key={customer.id} className="hover:bg-slate-50/60 transition-colors">
                  <td className="py-4 px-6">
                    <div className="font-bold text-slate-900">{customer.name}</div>
                    <div className="text-[11px] text-slate-400">{customer.email}</div>
                  </td>
                  <td className="py-4 px-4">
                    {customer.rfmSegment === 'CHAMPION' && (
                      <span className="px-2 py-0.5 rounded-full font-bold text-[10px] bg-indigo-100 text-[#4F46E5]">
                        Campeón
                      </span>
                    )}
                    {customer.rfmSegment === 'LOYAL' && (
                      <span className="px-2 py-0.5 rounded-full font-bold text-[10px] bg-emerald-100 text-emerald-800">
                        Leal
                      </span>
                    )}
                    {customer.rfmSegment === 'BARGAIN_HUNTER' && (
                      <span className="px-2 py-0.5 rounded-full font-bold text-[10px] bg-rose-100 text-rose-800">
                        Cazador de Ofertas
                      </span>
                    )}
                    {customer.rfmSegment === 'AT_RISK' && (
                      <span className="px-2 py-0.5 rounded-full font-bold text-[10px] bg-amber-100 text-amber-800">
                        En Riesgo
                      </span>
                    )}
                  </td>
                  <td className="py-4 px-4 font-black text-slate-900">
                    Bs {customer.totalSpent.toFixed(2)}
                  </td>
                  <td className="py-4 px-4 font-semibold text-slate-700">
                    {customer.purchaseCount} pedidos
                  </td>
                  <td className="py-4 px-4 text-slate-800 font-medium">
                    {customer.favoriteProduct}
                  </td>
                  <td className="py-4 px-4">
                    {customer.preferredMethod === 'QR' ? (
                      <span className="inline-flex items-center gap-1 font-bold text-[#4F46E5]">
                        <QrCode className="w-3.5 h-3.5" />
                        <span>QR</span>
                      </span>
                    ) : (
                      <span className="inline-flex items-center gap-1 font-bold text-amber-600">
                        <Coins className="w-3.5 h-3.5" />
                        <span>MDB Efectivo</span>
                      </span>
                    )}
                  </td>
                  <td className="py-4 px-6 text-right text-slate-500 font-medium">
                    {customer.lastPurchaseDate}
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
