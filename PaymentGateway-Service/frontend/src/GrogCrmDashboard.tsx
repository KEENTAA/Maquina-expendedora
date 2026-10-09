import React, { useState } from 'react';
import {
  Coins,
  QrCode,
  TrendingUp,
  Sparkles,
  Server,
  Activity,
  CheckCircle2,
  Clock,
  RefreshCw,
  SlidersHorizontal,
  PlusCircle,
  ShieldCheck,
  Zap,
  Tag,
  Calendar,
  Layers,
  ArrowUpRight,
  ExternalLink,
  ChevronRight,
  Bell,
  Sliders,
  DollarSign,
  AlertTriangle
} from 'lucide-react';
import GrogFrogMascot from './GrogFrogMascot';

interface TransactionItem {
  id: string;
  machineId: string;
  product: string;
  amount: number;
  method: 'CASH' | 'QR';
  timestamp: string;
  proofOfService: boolean;
  status: 'COMPLETED' | 'VERIFYING';
}

interface InventoryItem {
  sku: string;
  name: string;
  machineId: string;
  stock: number;
  maxStock: number;
  daysToExpiry: number;
  basePrice: number;
  discountPercent: number;
  currentPrice: number;
  expiryStatus: 'OPTIMAL' | 'MODERATE' | 'CRITICAL';
}

const INITIAL_INVENTORY: InventoryItem[] = [
  {
    sku: 'SNK-01',
    name: 'Papas Fritas Gourmet',
    machineId: 'VENDING-01',
    stock: 12,
    maxStock: 20,
    daysToExpiry: 4,
    basePrice: 5.00,
    discountPercent: 30,
    currentPrice: 3.50,
    expiryStatus: 'CRITICAL',
  },
  {
    sku: 'SNK-02',
    name: 'Chocolate Amargo 70%',
    machineId: 'VENDING-01',
    stock: 8,
    maxStock: 15,
    daysToExpiry: 18,
    basePrice: 6.00,
    discountPercent: 0,
    currentPrice: 6.00,
    expiryStatus: 'OPTIMAL',
  },
  {
    sku: 'DRK-01',
    name: 'Bebida Isotónica 500ml',
    machineId: 'COOLER-01',
    stock: 14,
    maxStock: 24,
    daysToExpiry: 6,
    basePrice: 7.00,
    discountPercent: 20,
    currentPrice: 5.60,
    expiryStatus: 'MODERATE',
  },
  {
    sku: 'DRK-02',
    name: 'Agua Mineral Glaciar',
    machineId: 'COOLER-01',
    stock: 22,
    maxStock: 25,
    daysToExpiry: 45,
    basePrice: 4.00,
    discountPercent: 0,
    currentPrice: 4.00,
    expiryStatus: 'OPTIMAL',
  },
  {
    sku: 'COF-01',
    name: 'Café Espresso Doble',
    machineId: 'COFFEE-01',
    stock: 35,
    maxStock: 50,
    daysToExpiry: 30,
    basePrice: 5.00,
    discountPercent: 0,
    currentPrice: 5.00,
    expiryStatus: 'OPTIMAL',
  },
  {
    sku: 'COF-02',
    name: 'Capuchino Vainilla Cremoso',
    machineId: 'COFFEE-01',
    stock: 9,
    maxStock: 30,
    daysToExpiry: 5,
    basePrice: 7.50,
    discountPercent: 25,
    currentPrice: 5.62,
    expiryStatus: 'MODERATE',
  },
];

const INITIAL_TRANSACTIONS: TransactionItem[] = [
  {
    id: 'TX-9041',
    machineId: 'VENDING-01',
    product: 'Papas Fritas Gourmet',
    amount: 3.50,
    method: 'QR',
    timestamp: 'Hace 3 min',
    proofOfService: true,
    status: 'COMPLETED',
  },
  {
    id: 'TX-9040',
    machineId: 'VENDING-01',
    product: 'Galleta de Avena',
    amount: 2.00,
    method: 'CASH',
    timestamp: 'Hace 8 min',
    proofOfService: true,
    status: 'COMPLETED',
  },
  {
    id: 'TX-9039',
    machineId: 'COOLER-01',
    product: 'Bebida Isotónica 500ml',
    amount: 5.60,
    method: 'QR',
    timestamp: 'Hace 14 min',
    proofOfService: true,
    status: 'COMPLETED',
  },
  {
    id: 'TX-9038',
    machineId: 'COFFEE-01',
    product: 'Café Espresso Doble',
    amount: 5.00,
    method: 'CASH',
    timestamp: 'Hace 21 min',
    proofOfService: true,
    status: 'COMPLETED',
  },
];

export const GrogCrmDashboard: React.FC = () => {
  const [selectedMachine, setSelectedMachine] = useState<string>('ALL');
  const [transactions, setTransactions] = useState<TransactionItem[]>(INITIAL_TRANSACTIONS);
  const [inventory, setInventory] = useState<InventoryItem[]>(INITIAL_INVENTORY);
  const [cashTotal, setCashTotal] = useState<number>(6240.00);
  const [qrTotal, setQrTotal] = useState<number>(8580.50);
  const [wasteSavedTotal, setWasteSavedTotal] = useState<number>(1840.00);
  const [mascotMessage, setMascotMessage] = useState<string>(
    '¡Hola Operador! El CRM sincroniza automáticamente las ventas físicas (Nivel 0) y los pagos QR (Nivel 1).'
  );
  const [mascotSubMessage, setMascotSubMessage] = useState<string>(
    'Prueba el simulador de transacciones para ver cómo actualiza el arqueo en vivo.'
  );

  // Filtrado de transacciones
  const filteredTransactions = selectedMachine === 'ALL'
    ? transactions
    : transactions.filter(t => t.machineId === selectedMachine);

  // Filtrado de inventario
  const filteredInventory = selectedMachine === 'ALL'
    ? inventory
    : inventory.filter(i => i.machineId === selectedMachine);

  const grandTotal = cashTotal + qrTotal;
  const cashShare = ((cashTotal / grandTotal) * 100).toFixed(1);
  const qrShare = ((qrTotal / grandTotal) * 100).toFixed(1);

  // Simular transacción Nivel 0 (Efectivo / Monedas)
  const handleSimulateCashSale = () => {
    const amount = 2.50;
    const newTx: TransactionItem = {
      id: `TX-${Math.floor(1000 + Math.random() * 9000)}`,
      machineId: selectedMachine === 'ALL' ? 'VENDING-01' : selectedMachine,
      product: 'Snack Fiduciario (MDB)',
      amount: amount,
      method: 'CASH',
      timestamp: 'Ahora mismo',
      proofOfService: true,
      status: 'COMPLETED',
    };

    setTransactions([newTx, ...transactions]);
    setCashTotal(prev => prev + amount);
    setMascotMessage('¡Venta en Efectivo (Nivel 0) registrada por GROG Edge!');
    setMascotSubMessage(
      `El aceptador MDB detectó la moneda de Bs ${amount.toFixed(2)}. Arqueo físico actualizado en el panel.`
    );
  };

  // Simular transacción Nivel 1 (QR Dinámico)
  const handleSimulateQrSale = () => {
    const amount = 6.00;
    const newTx: TransactionItem = {
      id: `TX-${Math.floor(1000 + Math.random() * 9000)}`,
      machineId: selectedMachine === 'ALL' ? 'COOLER-01' : selectedMachine,
      product: 'Producto Digital QR',
      amount: amount,
      method: 'QR',
      timestamp: 'Ahora mismo',
      proofOfService: true,
      status: 'COMPLETED',
    };

    setTransactions([newTx, ...transactions]);
    setQrTotal(prev => prev + amount);
    setMascotMessage('¡Pago Digital QR (Nivel 1) liquidado al instante!');
    setMascotSubMessage(
      `Payload JSON validado con SKU y usuario. Conciliación 1:1 sin disputas ni diferencias de caja.`
    );
  };

  return (
    <div className="min-h-screen bg-[#080C15] text-slate-100 font-sans p-4 md:p-8">
      {/* Contenedor Central */}
      <div className="max-w-7xl mx-auto space-y-8">
        
        {/* Cabecera del CRM */}
        <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-6 pb-6 border-b border-slate-800">
          <div>
            <div className="flex items-center gap-3">
              <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-indigo-600 to-cyan-500 flex items-center justify-center shadow-lg shadow-indigo-500/20">
                <Layers className="w-5 h-5 text-white" />
              </div>
              <div>
                <h1 className="text-2xl font-black tracking-tight text-white flex items-center gap-2">
                  GROG CRM & Telemetry Studio
                  <span className="text-xs font-semibold px-2 py-0.5 rounded-full bg-cyan-500/10 text-cyan-400 border border-cyan-500/30">
                    OPERATOR SUITE v2.6
                  </span>
                </h1>
                <p className="text-xs text-slate-400">
                  Operador: <span className="text-slate-200 font-medium">GRUPO VENDING SUR S.A.</span> | Protocolo MDB Level 3 & Universal IoT Edge
                </p>
              </div>
            </div>
          </div>

          {/* Selector de Máquina */}
          <div className="flex flex-wrap items-center gap-2">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-400 mr-2 flex items-center gap-1">
              <Sliders className="w-3.5 h-3.5" /> Máquina:
            </span>
            {[
              { id: 'ALL', label: 'Flota Completa (3)' },
              { id: 'VENDING-01', label: 'VENDING-01 (Snacks)' },
              { id: 'COOLER-01', label: 'COOLER-01 (Bebidas 4.2°C)' },
              { id: 'COFFEE-01', label: 'COFFEE-01 (Café 92°C)' },
            ].map((mach) => (
              <button
                key={mach.id}
                onClick={() => setSelectedMachine(mach.id)}
                className={`text-xs font-bold px-3 py-2 rounded-xl transition-all border ${
                  selectedMachine === mach.id
                    ? 'bg-indigo-600 border-indigo-400 text-white shadow-lg shadow-indigo-600/30 scale-105'
                    : 'bg-slate-900 border-slate-800 text-slate-400 hover:text-slate-200 hover:border-slate-700'
                }`}
              >
                {mach.label}
              </button>
            ))}
          </div>
        </div>

        {/* Sección de Asistente Interactivo Mascota GROG */}
        <div className="bg-gradient-to-r from-slate-900 via-indigo-950/40 to-slate-900 rounded-3xl p-6 border border-indigo-500/20 shadow-xl flex flex-col md:flex-row items-center justify-between gap-6">
          <GrogFrogMascot
            size={95}
            message={mascotMessage}
            subMessage={mascotSubMessage}
            icon={Sparkles}
            bubblePosition="right"
          />

          {/* Botones del Simulador en Vivo */}
          <div className="flex flex-wrap items-center gap-3 shrink-0">
            <div className="text-right hidden sm:block mr-2">
              <span className="text-[11px] font-bold uppercase tracking-wider text-slate-400 block">
                Simulador Interactivo
              </span>
              <span className="text-xs text-cyan-400 font-medium">
                Prueba en tiempo real
              </span>
            </div>

            <button
              onClick={handleSimulateCashSale}
              className="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-amber-500/10 text-amber-400 hover:bg-amber-500/20 border border-amber-500/30 font-bold text-xs transition-all active:scale-95 shadow-md"
            >
              <Coins className="w-4 h-4 text-amber-400" />
              + Simular Efectivo (Nivel 0)
            </button>

            <button
              onClick={handleSimulateQrSale}
              className="flex items-center gap-2 px-4 py-2.5 rounded-xl bg-cyan-500/10 text-cyan-400 hover:bg-cyan-500/20 border border-cyan-500/30 font-bold text-xs transition-all active:scale-95 shadow-md"
            >
              <QrCode className="w-4 h-4 text-cyan-400" />
              + Simular Pago QR (Nivel 1)
            </button>
          </div>
        </div>

        {/* Métricas Principales (KPI Cards) */}
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
          {/* Tarjeta 1: Ventas Totales */}
          <div className="bg-slate-900/80 rounded-2xl p-5 border border-slate-800 shadow-lg relative overflow-hidden group hover:border-slate-700 transition-all">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold uppercase tracking-wider text-slate-400">
                Ventas Consolidadas
              </span>
              <div className="p-2 rounded-xl bg-indigo-500/10 text-indigo-400">
                <TrendingUp className="w-4 h-4" />
              </div>
            </div>
            <div className="mt-3">
              <span className="text-2xl font-black text-white">
                Bs {grandTotal.toLocaleString('es-BO', { minimumFractionDigits: 2 })}
              </span>
            </div>
            <div className="mt-2 flex items-center gap-1.5 text-xs text-emerald-400 font-semibold">
              <ArrowUpRight className="w-3.5 h-3.5" />
              +18.4% vs mes anterior
            </div>
          </div>

          {/* Tarjeta 2: Nivel 0 - Efectivo / Fiduciario */}
          <div className="bg-slate-900/80 rounded-2xl p-5 border border-amber-500/30 shadow-lg relative overflow-hidden group hover:border-amber-500/50 transition-all">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold uppercase tracking-wider text-amber-400 flex items-center gap-1.5">
                <Coins className="w-3.5 h-3.5" /> Nivel 0: Fiduciario
              </span>
              <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-amber-500/20 text-amber-300">
                {cashShare}%
              </span>
            </div>
            <div className="mt-3">
              <span className="text-2xl font-black text-white">
                Bs {cashTotal.toLocaleString('es-BO', { minimumFractionDigits: 2 })}
              </span>
            </div>
            <div className="mt-2 flex items-center justify-between text-xs text-slate-400">
              <span>Arqueo en Tolva MDB</span>
              <span className="text-amber-400 font-medium">Capacidad 74%</span>
            </div>
          </div>

          {/* Tarjeta 3: Nivel 1 - QR Dinámico Digital */}
          <div className="bg-slate-900/80 rounded-2xl p-5 border border-cyan-500/30 shadow-lg relative overflow-hidden group hover:border-cyan-500/50 transition-all">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold uppercase tracking-wider text-cyan-400 flex items-center gap-1.5">
                <QrCode className="w-3.5 h-3.5" /> Nivel 1: QR Dinámico
              </span>
              <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-cyan-500/20 text-cyan-300">
                {qrShare}%
              </span>
            </div>
            <div className="mt-3">
              <span className="text-2xl font-black text-white">
                Bs {qrTotal.toLocaleString('es-BO', { minimumFractionDigits: 2 })}
              </span>
            </div>
            <div className="mt-2 flex items-center justify-between text-xs text-slate-400">
              <span>Conciliación Instantánea</span>
              <span className="text-cyan-400 font-medium">JSON 1:1 OK</span>
            </div>
          </div>

          {/* Tarjeta 4: Nivel 2 - Merma Salvada con IA */}
          <div className="bg-slate-900/80 rounded-2xl p-5 border border-indigo-500/30 shadow-lg relative overflow-hidden group hover:border-indigo-500/50 transition-all">
            <div className="flex items-center justify-between">
              <span className="text-xs font-bold uppercase tracking-wider text-indigo-400 flex items-center gap-1.5">
                <Sparkles className="w-3.5 h-3.5" /> Nivel 2: Merma Salvada
              </span>
              <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-indigo-500/20 text-indigo-300">
                IA Activa
              </span>
            </div>
            <div className="mt-3">
              <span className="text-2xl font-black text-white">
                Bs {wasteSavedTotal.toLocaleString('es-BO', { minimumFractionDigits: 2 })}
              </span>
            </div>
            <div className="mt-2 flex items-center justify-between text-xs text-slate-400">
              <span>Dynamic Expiry Pricing</span>
              <span className="text-emerald-400 font-medium">0% Desperdicio</span>
            </div>
          </div>
        </div>

        {/* Bloque de Dos Columnas: Inventario Inteligente (Nivel 2) + Historial de Auditoría */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          
          {/* Columna Izquierda (2/3): Inventario con Descuentos Dinámicos por Caducidad */}
          <div className="lg:col-span-2 bg-slate-900/90 rounded-2xl p-6 border border-slate-800 shadow-xl space-y-4">
            <div className="flex items-center justify-between">
              <div>
                <h3 className="text-lg font-bold text-white flex items-center gap-2">
                  <Tag className="w-4 h-4 text-indigo-400" />
                  Inventario Inteligente & Algoritmo de Caducidad (Nivel 2)
                </h3>
                <p className="text-xs text-slate-400">
                  Precios dinámicos teledirigidos calculados por proximidad a fecha de vencimiento
                </p>
              </div>
              <span className="text-xs font-semibold px-2.5 py-1 rounded-lg bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 flex items-center gap-1">
                <CheckCircle2 className="w-3.5 h-3.5" /> Algoritmo Automático ON
              </span>
            </div>

            {/* Tabla de Inventario */}
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs">
                <thead>
                  <tr className="border-b border-slate-800 text-slate-400 uppercase font-semibold tracking-wider">
                    <th className="py-3 px-3">Producto / SKU</th>
                    <th className="py-3 px-3">Máquina</th>
                    <th className="py-3 px-3">Stock</th>
                    <th className="py-3 px-3">Vencimiento</th>
                    <th className="py-3 px-3">Precio Base</th>
                    <th className="py-3 px-3">Descuento IA</th>
                    <th className="py-3 px-3">Precio Vigente</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-800/60 font-medium">
                  {filteredInventory.map((item) => (
                    <tr key={item.sku} className="hover:bg-slate-800/40 transition-colors">
                      <td className="py-3 px-3">
                        <span className="font-bold text-slate-200 block">{item.name}</span>
                        <span className="text-[10px] text-slate-500 font-mono">{item.sku}</span>
                      </td>
                      <td className="py-3 px-3 text-slate-400">
                        {item.machineId}
                      </td>
                      <td className="py-3 px-3">
                        <span className="text-slate-200">{item.stock}/{item.maxStock}</span>
                      </td>
                      <td className="py-3 px-3">
                        <span
                          className={`px-2 py-0.5 rounded-md text-[11px] font-bold ${
                            item.daysToExpiry <= 5
                              ? 'bg-rose-500/20 text-rose-400 border border-rose-500/30'
                              : item.daysToExpiry <= 10
                              ? 'bg-amber-500/20 text-amber-400 border border-amber-500/30'
                              : 'bg-emerald-500/20 text-emerald-400 border border-emerald-500/30'
                          }`}
                        >
                          {item.daysToExpiry} días
                        </span>
                      </td>
                      <td className="py-3 px-3 text-slate-400">
                        Bs {item.basePrice.toFixed(2)}
                      </td>
                      <td className="py-3 px-3">
                        {item.discountPercent > 0 ? (
                          <span className="font-bold text-cyan-400 bg-cyan-500/10 px-2 py-0.5 rounded border border-cyan-500/30">
                            -{item.discountPercent}%
                          </span>
                        ) : (
                          <span className="text-slate-500">Sin rebaja</span>
                        )}
                      </td>
                      <td className="py-3 px-3 font-bold text-emerald-400">
                        Bs {item.currentPrice.toFixed(2)}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            <div className="pt-2 flex items-center justify-between text-xs text-slate-400 border-t border-slate-800">
              <span className="flex items-center gap-1.5">
                <Sparkles className="w-3.5 h-3.5 text-indigo-400" />
                Los clientes de la App GROG reciben alertas push teledirigidas para consumir estos ítems con descuento.
              </span>
            </div>
          </div>

          {/* Columna Derecha (1/3): Auditoría y Transacciones en Tiempo Real */}
          <div className="bg-slate-900/90 rounded-2xl p-6 border border-slate-800 shadow-xl space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="text-base font-bold text-white flex items-center gap-2">
                <Activity className="w-4 h-4 text-cyan-400" />
                Auditoría en Tiempo Real
              </h3>
              <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
            </div>

            <div className="space-y-3">
              {filteredTransactions.slice(0, 6).map((tx) => (
                <div
                  key={tx.id}
                  className="p-3 rounded-xl bg-slate-950/60 border border-slate-800 flex items-center justify-between gap-3 hover:border-slate-700 transition-all"
                >
                  <div className="flex items-center gap-2.5">
                    <div
                      className={`p-2 rounded-lg ${
                        tx.method === 'CASH'
                          ? 'bg-amber-500/10 text-amber-400 border border-amber-500/20'
                          : 'bg-cyan-500/10 text-cyan-400 border border-cyan-500/20'
                      }`}
                    >
                      {tx.method === 'CASH' ? (
                        <Coins className="w-4 h-4" />
                      ) : (
                        <QrCode className="w-4 h-4" />
                      )}
                    </div>
                    <div>
                      <div className="flex items-center gap-1.5">
                        <span className="font-bold text-xs text-white">
                          {tx.id}
                        </span>
                        <span className="text-[10px] px-1.5 rounded bg-slate-800 text-slate-400">
                          {tx.machineId}
                        </span>
                      </div>
                      <span className="text-[11px] text-slate-400 block truncate max-w-[130px]">
                        {tx.product}
                      </span>
                    </div>
                  </div>

                  <div className="text-right">
                    <span className="font-black text-sm text-emerald-400 block">
                      +Bs {tx.amount.toFixed(2)}
                    </span>
                    <span className="text-[10px] text-slate-500">
                      {tx.timestamp}
                    </span>
                  </div>
                </div>
              ))}
            </div>

            <div className="pt-2 text-center">
              <span className="text-xs text-slate-500 flex items-center justify-center gap-1">
                <ShieldCheck className="w-3.5 h-3.5 text-emerald-400" />
                Proof of Service: 100% de entregas validadas físicamente
              </span>
            </div>
          </div>
        </div>

        {/* Estado de Telemetría de la Flota (Las 3 Máquinas) */}
        <div className="bg-slate-900/90 rounded-2xl p-6 border border-slate-800 shadow-xl space-y-4">
          <div className="flex items-center justify-between">
            <div>
              <h3 className="text-lg font-bold text-white flex items-center gap-2">
                <Server className="w-4 h-4 text-cyan-400" />
                Telemetría en Vivo de las 3 Máquinas Conectadas
              </h3>
              <p className="text-xs text-slate-400">
                Monitoreo de bus MDB, sensores ultrasónicos HC-SR04 y controladores GROG Edge
              </p>
            </div>
            <a
              href="/unity/"
              target="_blank"
              rel="noreferrer"
              className="text-xs font-bold px-3 py-1.5 rounded-xl bg-cyan-500/10 text-cyan-400 hover:bg-cyan-500/20 border border-cyan-500/30 flex items-center gap-1.5 transition-all"
            >
              Abrir Gemelo 3D en Unity <ExternalLink className="w-3 h-3" />
            </a>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-4 pt-2">
            {/* Máquina 1 */}
            <div className="p-4 rounded-xl bg-slate-950/70 border border-slate-800 space-y-2">
              <div className="flex items-center justify-between">
                <span className="font-bold text-sm text-white">VENDING-01 (Snacks)</span>
                <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-emerald-500/20 text-emerald-400">
                  ONLINE
                </span>
              </div>
              <p className="text-xs text-slate-400">
                Espirales Helicoidales 3D | MDB Level 3 (9600 Baud)
              </p>
              <div className="pt-2 border-t border-slate-800/80 flex items-center justify-between text-xs">
                <span className="text-slate-500">Sensor HC-SR04:</span>
                <span className="font-mono text-cyan-400">32.5 cm (Bandeja Vacía)</span>
              </div>
            </div>

            {/* Máquina 2 */}
            <div className="p-4 rounded-xl bg-slate-950/70 border border-slate-800 space-y-2">
              <div className="flex items-center justify-between">
                <span className="font-bold text-sm text-white">COOLER-01 (Bebidas)</span>
                <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-emerald-500/20 text-emerald-400">
                  ONLINE
                </span>
              </div>
              <p className="text-xs text-slate-400">
                Compuerta Gravitatoria | GROG Universal Machine Adapter
              </p>
              <div className="pt-2 border-t border-slate-800/80 flex items-center justify-between text-xs">
                <span className="text-slate-500">Temperatura Interna:</span>
                <span className="font-mono text-cyan-400">4.2 °C (Óptima)</span>
              </div>
            </div>

            {/* Máquina 3 */}
            <div className="p-4 rounded-xl bg-slate-950/70 border border-slate-800 space-y-2">
              <div className="flex items-center justify-between">
                <span className="font-bold text-sm text-white">COFFEE-01 (Café)</span>
                <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-emerald-500/20 text-emerald-400">
                  ONLINE
                </span>
              </div>
              <p className="text-xs text-slate-400">
                Caldera Especializada | Erogación de Insumos Automática
              </p>
              <div className="pt-2 border-t border-slate-800/80 flex items-center justify-between text-xs">
                <span className="text-slate-500">Presión / Caldera:</span>
                <span className="font-mono text-amber-400">92.4 °C (9.2 bar)</span>
              </div>
            </div>
          </div>
        </div>

      </div>
    </div>
  );
};

export default GrogCrmDashboard;
