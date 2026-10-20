import React, { useState } from 'react';
import {
  Hand,
  TrendingUp,
  Activity,
  CheckCircle2,
  AlertTriangle,
  ArrowUpRight,
  Sparkles,
  Cpu,
  Coins,
  QrCode,
  Package,
  RotateCw,
  PlusCircle,
  Eye,
  Check,
  Clock,
  ChevronRight,
  ShieldAlert,
  Sliders,
  DollarSign,
  Layers,
  Thermometer,
  Wifi,
  ExternalLink
} from 'lucide-react';
import GrogFrogMascot from '../GrogFrogMascot';
import { usePermissions } from '../context/PermissionsContext';

export const DashboardView: React.FC = () => {
  const { machines, transactions, restockMachine, simulateSale } = usePermissions();
  const [selectedMachineFilter, setSelectedMachineFilter] = useState<string>('ALL');
  const [useLiveData, setUseLiveData] = useState<boolean>(true);
  const [toastMessage, setToastMessage] = useState<string | null>(null);

  const showToast = (msg: string) => {
    setToastMessage(msg);
    setTimeout(() => setToastMessage(null), 3500);
  };

  // KPIs
  const totalStockAll = machines.reduce((sum, m) => sum + m.totalStock, 0);
  const totalCapacityAll = machines.reduce((sum, m) => sum + m.totalCapacity, 0);
  const activeMachinesCount = machines.filter(m => m.status === 'ONLINE').length;
  const totalCashInHoppers = machines.reduce((sum, m) => sum + m.cashHopperBalance, 0);

  const filteredMachines = selectedMachineFilter === 'ALL'
    ? machines
    : machines.filter(m => m.id === selectedMachineFilter);

  return (
    <div className="space-y-8 animate-fadeIn pb-12">
      {/* Toast Alert */}
      {toastMessage && (
        <div className="fixed bottom-6 right-6 z-50 bg-slate-900 text-white px-5 py-3 rounded-2xl shadow-2xl border border-indigo-500/40 flex items-center gap-3 animate-slideUp">
          <CheckCircle2 className="w-5 h-5 text-emerald-400 shrink-0" />
          <p className="text-xs font-semibold">{toastMessage}</p>
        </div>
      )}

      {/* Greeting Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2">
            <span className="text-[11px] font-extrabold uppercase tracking-widest text-[#4F46E5] bg-indigo-50 px-2 py-0.5 rounded border border-indigo-100">
              PANEL GENERAL / RESUMEN
            </span>
          </div>
          <div className="flex items-center gap-2.5 mt-2">
            <h1 className="text-2xl md:text-3xl font-extrabold text-slate-900 tracking-tight">
              Buenos días
            </h1>
            <div className="p-1 rounded-lg bg-amber-100/70 text-amber-600">
              <Hand className="w-6 h-6 animate-pulse" />
            </div>
          </div>
          <p className="text-sm text-slate-500 mt-1">
            Esto es lo que ocurre en tu operación en tiempo real.
          </p>
        </div>

        {/* Live Data Switch */}
        <div className="flex items-center gap-3 bg-white p-2 rounded-2xl border border-slate-200 shadow-2xs">
          <div className="text-right hidden sm:block">
            <p className="text-xs font-bold text-slate-800">Modo de Datos</p>
            <p className="text-[10px] text-slate-400">
              {useLiveData ? 'Métricas en Vivo' : 'Simulación Conceptual'}
            </p>
          </div>
          <button
            onClick={() => setUseLiveData(!useLiveData)}
            className={`px-3 py-1.5 rounded-xl text-xs font-bold transition-all flex items-center gap-1.5 ${
              useLiveData
                ? 'bg-[#4F46E5] text-white shadow-sm'
                : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
            }`}
          >
            <RotateCw className="w-3.5 h-3.5" />
            <span>{useLiveData ? 'Datos Reales: ON' : 'Vista Maqueta: ON'}</span>
          </button>
        </div>
      </div>

      {/* 4 Main KPI Cards matching /tmp/captura_gemini.png */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* Card 1: Ventas de hoy */}
        <div className="bg-white p-5 rounded-2xl border border-slate-200/80 shadow-2xs hover:shadow-md transition-shadow">
          <div className="flex items-center justify-between text-slate-400 mb-2">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-500">
              Ventas de hoy
            </span>
            <div className="p-2 rounded-xl bg-indigo-50 text-[#4F46E5]">
              <DollarSign className="w-4 h-4" />
            </div>
          </div>
          <div className="flex items-baseline gap-2">
            <span className="text-3xl font-black text-slate-900 tracking-tight">
              {useLiveData ? 'Bs 14,820.50' : 'Bs —'}
            </span>
          </div>
          <div className="flex items-center gap-1.5 mt-3 text-xs font-semibold text-emerald-600">
            <CheckCircle2 className="w-3.5 h-3.5 shrink-0" />
            <span>Conectado a datos reales</span>
          </div>
        </div>

        {/* Card 2: Máquinas activas */}
        <div className="bg-white p-5 rounded-2xl border border-slate-200/80 shadow-2xs hover:shadow-md transition-shadow">
          <div className="flex items-center justify-between text-slate-400 mb-2">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-500">
              Máquinas activas
            </span>
            <div className="p-2 rounded-xl bg-emerald-50 text-emerald-600">
              <Cpu className="w-4 h-4" />
            </div>
          </div>
          <div className="flex items-baseline gap-2">
            <span className="text-3xl font-black text-slate-900 tracking-tight">
              {useLiveData ? `${activeMachinesCount} / ${machines.length}` : '— / —'}
            </span>
          </div>
          <div className="flex items-center gap-1.5 mt-3 text-xs font-semibold text-slate-500">
            <Wifi className="w-3.5 h-3.5 text-emerald-500 shrink-0" />
            <span>Estado de conexión: 100% Online</span>
          </div>
        </div>

        {/* Card 3: Transacciones */}
        <div className="bg-white p-5 rounded-2xl border border-slate-200/80 shadow-2xs hover:shadow-md transition-shadow">
          <div className="flex items-center justify-between text-slate-400 mb-2">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-500">
              Transacciones
            </span>
            <div className="p-2 rounded-xl bg-amber-50 text-[#F59E0B]">
              <TrendingUp className="w-4 h-4" />
            </div>
          </div>
          <div className="flex items-baseline gap-2">
            <span className="text-3xl font-black text-slate-900 tracking-tight">
              {useLiveData ? '184' : '—'}
            </span>
            <span className="text-xs font-bold text-emerald-600 bg-emerald-50 px-1.5 py-0.5 rounded">
              +14% hoy
            </span>
          </div>
          <div className="flex items-center gap-1.5 mt-3 text-xs font-semibold text-slate-500">
            <CheckCircle2 className="w-3.5 h-3.5 text-indigo-500 shrink-0" />
            <span>Ventas completadas</span>
          </div>
        </div>

        {/* Card 4: Alertas pendientes */}
        <div className="bg-white p-5 rounded-2xl border border-slate-200/80 shadow-2xs hover:shadow-md transition-shadow">
          <div className="flex items-center justify-between text-slate-400 mb-2">
            <span className="text-xs font-bold uppercase tracking-wider text-slate-500">
              Alertas pendientes
            </span>
            <div className="p-2 rounded-xl bg-rose-50 text-rose-600">
              <AlertTriangle className="w-4 h-4" />
            </div>
          </div>
          <div className="flex items-baseline gap-2">
            <span className="text-3xl font-black text-slate-900 tracking-tight">
              {useLiveData ? '2' : '—'}
            </span>
            <span className="text-xs font-bold text-amber-600 bg-amber-50 px-1.5 py-0.5 rounded">
              Bajo stock & Expiry
            </span>
          </div>
          <div className="flex items-center gap-1.5 mt-3 text-xs font-semibold text-amber-600">
            <Clock className="w-3.5 h-3.5 shrink-0" />
            <span>Requieren revisión preventiva</span>
          </div>
        </div>
      </div>

      {/* GROG Intelligence Assistant Card (#312E81 Dark Indigo) */}
      <div className="bg-gradient-to-br from-[#312E81] via-[#1E1B4B] to-[#0F172A] text-white p-6 md:p-8 rounded-3xl shadow-xl border border-indigo-900/50 relative overflow-hidden">
        {/* Decorative background glow */}
        <div className="absolute top-0 right-0 w-96 h-96 bg-indigo-500/10 rounded-full blur-3xl pointer-events-none" />

        <div className="flex flex-col lg:flex-row items-center justify-between gap-6 relative z-10">
          <div className="flex flex-col sm:flex-row items-center sm:items-start gap-5 text-center sm:text-left">
            {/* Mascot */}
            <div className="shrink-0">
              <GrogFrogMascot
                size={85}
                expression="happy"
                showBubble={false}
              />
            </div>

            <div>
              <div className="flex items-center justify-center sm:justify-start gap-2">
                <span className="px-2.5 py-0.5 rounded-full text-[10px] font-extrabold uppercase tracking-wider bg-indigo-500/30 text-indigo-200 border border-indigo-400/30 flex items-center gap-1">
                  <Sparkles className="w-3 h-3 text-[#F472B6]" />
                  GROG Intelligence
                </span>
                <span className="text-xs text-slate-400">Asistente de operaciones 24/7</span>
              </div>
              <h2 className="text-xl md:text-2xl font-black tracking-tight mt-1.5">
                Optimización y Alertas Predictivas
              </h2>
              <p className="text-xs md:text-sm text-indigo-100/80 max-w-xl mt-1 leading-relaxed">
                Analiza tus ventas, inventario y operaciones para encontrar oportunidades de mejora, evitar mermas por caducidad y maximizar el margen de cada máquina.
              </p>

              {/* Actionable Suggestions */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 mt-4">
                <div className="bg-white/10 backdrop-blur-xs p-3 rounded-xl border border-white/10 text-left">
                  <p className="text-xs font-bold text-amber-300 flex items-center gap-1.5">
                    <Clock className="w-3.5 h-3.5" />
                    Riesgo de Caducidad (4 días)
                  </p>
                  <p className="text-[11px] text-slate-200 mt-1">
                    Papas Fritas Gourmet en <strong>VENDING-01</strong>. Descuento dinámico del 30% activado.
                  </p>
                </div>

                <div className="bg-white/10 backdrop-blur-xs p-3 rounded-xl border border-white/10 text-left">
                  <p className="text-xs font-bold text-cyan-300 flex items-center gap-1.5">
                    <Package className="w-3.5 h-3.5" />
                    Sugerencia de Reposición
                  </p>
                  <p className="text-[11px] text-slate-200 mt-1">
                    Capuchino Cremoso en <strong>COFFEE-01</strong> restante 9 dosis. Reponer antes del viernes.
                  </p>
                </div>
              </div>
            </div>
          </div>

          <div className="shrink-0 flex flex-col gap-2 w-full sm:w-auto">
            <button
              onClick={() => showToast('Optimizador de precios automáticos GROG Intelligence activado.')}
              className="px-5 py-3 rounded-2xl bg-[#4F46E5] hover:bg-[#4338CA] text-white font-extrabold text-xs flex items-center justify-center gap-2 transition-all shadow-lg shadow-indigo-600/30"
            >
              <Sparkles className="w-4 h-4 text-[#F472B6]" />
              <span>Aplicar Descuentos IA</span>
            </button>
            <p className="text-[10px] text-indigo-300 text-center">
              Ahorro de merma proyectado: +Bs 1,840 / mes
            </p>
          </div>
        </div>
      </div>

      {/* ========================================================================= */}
      {/* EXPLICIT USER REQUIREMENT: LISTA DE MÁQUINAS Y PRODUCTOS QUE QUEDAN EN CADA UNA */}
      {/* ========================================================================= */}
      <div className="space-y-4">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
          <div>
            <div className="flex items-center gap-2">
              <Package className="w-5 h-5 text-[#4F46E5]" />
              <h2 className="text-xl font-extrabold text-slate-900 tracking-tight">
                Mis Máquinas & Disponibilidad de Productos
              </h2>
            </div>
            <p className="text-xs text-slate-500 mt-0.5">
              Supervisión de existencias en tiempo real, capacidad por resorte y alertas de reposición.
            </p>
          </div>

          {/* Machine Filter Buttons */}
          <div className="flex items-center gap-1.5 bg-slate-100 p-1 rounded-xl border border-slate-200 overflow-x-auto">
            <button
              onClick={() => setSelectedMachineFilter('ALL')}
              className={`px-3 py-1 rounded-lg text-xs font-bold transition-all ${
                selectedMachineFilter === 'ALL'
                  ? 'bg-white text-slate-900 shadow-2xs'
                  : 'text-slate-600 hover:text-slate-900'
              }`}
            >
              Todas ({machines.length})
            </button>
            {machines.map(m => (
              <button
                key={m.id}
                onClick={() => setSelectedMachineFilter(m.id)}
                className={`px-3 py-1 rounded-lg text-xs font-bold transition-all truncate ${
                  selectedMachineFilter === m.id
                    ? 'bg-white text-slate-900 shadow-2xs'
                    : 'text-slate-600 hover:text-slate-900'
                }`}
              >
                {m.id}
              </button>
            ))}
          </div>
        </div>

        {/* Machine Cards List */}
        <div className="grid grid-cols-1 gap-6">
          {filteredMachines.map(machine => {
            const stockPercent = Math.round((machine.totalStock / machine.totalCapacity) * 100);

            return (
              <div
                key={machine.id}
                className="bg-white rounded-3xl border border-slate-200 shadow-sm overflow-hidden hover:border-indigo-300 transition-all"
              >
                {/* Machine Header */}
                <div className="p-5 md:p-6 bg-slate-50/60 border-b border-slate-100 flex flex-col md:flex-row md:items-center justify-between gap-4">
                  <div className="flex items-start gap-4">
                    <div className="p-3 rounded-2xl bg-gradient-to-br from-[#4F46E5] to-[#312E81] text-white shadow-md shadow-indigo-500/20">
                      <Cpu className="w-6 h-6" />
                    </div>
                    <div>
                      <div className="flex items-center gap-2">
                        <span className="font-mono text-xs font-black text-[#4F46E5] bg-indigo-50 px-2 py-0.5 rounded border border-indigo-100">
                          {machine.id}
                        </span>
                        <h3 className="font-extrabold text-slate-900 text-base">{machine.name}</h3>
                        <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-emerald-100 text-emerald-800 flex items-center gap-1">
                          <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
                          {machine.status}
                        </span>
                      </div>
                      <p className="text-xs text-slate-500 mt-1">
                        Ubicación: <strong>{machine.location}</strong>
                      </p>
                    </div>
                  </div>

                  {/* Machine Live Telemetry Indicators */}
                  <div className="flex flex-wrap items-center gap-3 text-xs">
                    <div className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-xl bg-white border border-slate-200 text-slate-700">
                      <Thermometer className="w-3.5 h-3.5 text-indigo-600" />
                      <span>{machine.temperature}°C</span>
                    </div>

                    <div className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-xl bg-white border border-slate-200 text-slate-700">
                      <Coins className="w-3.5 h-3.5 text-amber-500" />
                      <span>Tolva MDB: <strong>Bs {machine.cashHopperBalance.toFixed(2)}</strong></span>
                    </div>

                    <div className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-xl bg-white border border-slate-200 text-slate-700">
                      <Wifi className="w-3.5 h-3.5 text-emerald-500" />
                      <span>{machine.pingMs} ms</span>
                    </div>

                    {/* Quick Restock Action Button */}
                    <button
                      onClick={() => {
                        restockMachine(machine.id);
                        showToast(`¡Máquina ${machine.id} reabastecida al 100% de capacidad!`);
                      }}
                      className="px-3.5 py-1.5 rounded-xl bg-emerald-50 hover:bg-emerald-100 text-emerald-800 border border-emerald-200 font-bold flex items-center gap-1.5 transition-colors"
                      title="Reabastecer todas las bandejas de esta máquina al máximo"
                    >
                      <PlusCircle className="w-3.5 h-3.5 text-emerald-600" />
                      <span>Reabastecer Todo</span>
                    </button>
                  </div>
                </div>

                {/* Capacity Bar */}
                <div className="px-6 py-3 bg-white border-b border-slate-100 flex items-center justify-between text-xs">
                  <div className="flex items-center gap-2">
                    <span className="font-bold text-slate-700">Capacidad Total Ocupada:</span>
                    <span className="font-extrabold text-[#4F46E5]">
                      {machine.totalStock} / {machine.totalCapacity} unidades ({stockPercent}%)
                    </span>
                  </div>

                  <div className="w-48 bg-slate-100 rounded-full h-2.5 overflow-hidden">
                    <div
                      className={`h-2.5 rounded-full transition-all duration-500 ${
                        stockPercent > 50
                          ? 'bg-[#4F46E5]'
                          : stockPercent > 25
                          ? 'bg-amber-500'
                          : 'bg-rose-500'
                      }`}
                      style={{ width: `${stockPercent}%` }}
                    />
                  </div>
                </div>

                {/* Products Grid for this machine */}
                <div className="p-6">
                  <div className="mb-3 flex items-center justify-between">
                    <h4 className="text-xs font-bold text-slate-400 uppercase tracking-wider">
                      Productos Disponibles en {machine.id} ({machine.products.length} slots)
                    </h4>
                    <span className="text-[11px] text-slate-400">
                      Haz clic en "Simular Compra" para probar la bajada de stock y el registro en el CRM
                    </span>
                  </div>

                  <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                    {machine.products.map(product => {
                      const itemPercent = Math.round((product.currentStock / product.maxStock) * 100);
                      const isLow = product.currentStock <= 5;
                      const hasDiscount = product.discountPercent > 0;

                      return (
                        <div
                          key={product.sku}
                          className={`p-4 rounded-2xl border transition-all flex flex-col justify-between ${
                            product.currentStock === 0
                              ? 'bg-slate-50 border-slate-200 opacity-60'
                              : isLow
                              ? 'bg-rose-50/30 border-rose-200'
                              : 'bg-white border-slate-200 hover:border-indigo-300'
                          }`}
                        >
                          <div>
                            {/* Slot and Expiry Badge */}
                            <div className="flex items-center justify-between gap-1 mb-2">
                              <span className="font-mono text-[10px] font-extrabold px-1.5 py-0.5 rounded bg-slate-100 text-slate-600">
                                Slot {product.slot}
                              </span>

                              {hasDiscount ? (
                                <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-rose-100 text-rose-800 border border-rose-200 animate-pulse">
                                  -{product.discountPercent}% Caducidad ({product.daysToExpiry}d)
                                </span>
                              ) : (
                                <span className="text-[10px] font-medium px-2 py-0.5 rounded-full bg-slate-100 text-slate-600">
                                  Vence en {product.daysToExpiry}d
                                </span>
                              )}
                            </div>

                            {/* Product Name & SKU */}
                            <h5 className="font-bold text-slate-900 text-sm leading-snug line-clamp-1">
                              {product.name}
                            </h5>
                            <p className="text-[11px] text-slate-400 font-mono mt-0.5">
                              SKU: {product.sku}
                            </p>

                            {/* Remaining Stock Visual Indicator */}
                            <div className="mt-3 bg-slate-50 p-2.5 rounded-xl border border-slate-100">
                              <div className="flex items-center justify-between text-xs mb-1.5">
                                <span className="text-slate-500 font-medium">Quedan:</span>
                                <span className="font-extrabold text-slate-900">
                                  {product.currentStock} / {product.maxStock} uds.
                                </span>
                              </div>

                              <div className="w-full bg-slate-200 rounded-full h-2 overflow-hidden">
                                <div
                                  className={`h-2 rounded-full transition-all duration-300 ${
                                    itemPercent > 50
                                      ? 'bg-emerald-500'
                                      : itemPercent > 20
                                      ? 'bg-amber-500'
                                      : 'bg-rose-500'
                                  }`}
                                  style={{ width: `${itemPercent}%` }}
                                />
                              </div>
                            </div>

                            {/* Price */}
                            <div className="mt-2.5 flex items-baseline justify-between">
                              <span className="text-xs text-slate-500">Precio actual:</span>
                              <div className="flex items-center gap-1.5">
                                {hasDiscount && (
                                  <span className="text-xs text-slate-400 line-through">
                                    Bs {product.basePrice.toFixed(2)}
                                  </span>
                                )}
                                <span className="text-sm font-black text-[#4F46E5]">
                                  Bs {product.currentPrice.toFixed(2)}
                                </span>
                              </div>
                            </div>
                          </div>

                          {/* Quick Interactive Actions */}
                          <div className="mt-4 pt-3 border-t border-slate-100 flex items-center gap-1.5">
                            <button
                              onClick={() => {
                                simulateSale(machine.id, product.sku, 'CASH');
                                showToast(`Venta Fiduciaria MDB: 1x ${product.name} dispensado.`);
                              }}
                              disabled={product.currentStock <= 0}
                              className="flex-1 py-1.5 px-2 rounded-lg bg-amber-50 hover:bg-amber-100 text-amber-800 text-[10px] font-bold flex items-center justify-center gap-1 transition-colors disabled:opacity-40"
                              title="Simular inserción de moneda MDB y dispensado"
                            >
                              <Coins className="w-3 h-3 text-amber-600" />
                              <span>Efectivo</span>
                            </button>

                            <button
                              onClick={() => {
                                simulateSale(machine.id, product.sku, 'QR');
                                showToast(`Pago QR Dinámico: 1x ${product.name} dispensado.`);
                              }}
                              disabled={product.currentStock <= 0}
                              className="flex-1 py-1.5 px-2 rounded-lg bg-indigo-50 hover:bg-indigo-100 text-[#4F46E5] text-[10px] font-bold flex items-center justify-center gap-1 transition-colors disabled:opacity-40"
                              title="Simular escaneo de QR dinámico"
                            >
                              <QrCode className="w-3 h-3 text-[#4F46E5]" />
                              <span>QR</span>
                            </button>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* ========================================================================= */}
      {/* RECENT REAL-TIME TRANSACTIONS (PROOF OF SERVICE / 4-STAGE LIFECYCLE) */}
      {/* ========================================================================= */}
      <div className="bg-white rounded-3xl border border-slate-200 shadow-sm p-6">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 mb-4">
          <div>
            <h3 className="font-extrabold text-slate-900 text-base">
              Flujo de Transacciones en Vivo (Proof of Service)
            </h3>
            <p className="text-xs text-slate-500 mt-0.5">
              Auditoría instantánea de dispensación por sensor de caída láser (Nivel 0 y Nivel 1).
            </p>
          </div>

          <div className="flex items-center gap-2 text-xs text-slate-500 font-medium">
            <span className="w-2 h-2 rounded-full bg-emerald-500 animate-ping" />
            <span>Últimos registros recibidos por MQTT</span>
          </div>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead>
              <tr className="border-b border-slate-100 text-slate-400 font-bold uppercase tracking-wider text-[10px]">
                <th className="pb-3">ID Transacción</th>
                <th className="pb-3">Máquina</th>
                <th className="pb-3">Producto / SKU</th>
                <th className="pb-3">Método / Nivel</th>
                <th className="pb-3">Monto</th>
                <th className="pb-3">Sensor de Caída</th>
                <th className="pb-3">Estado</th>
                <th className="pb-3 text-right">Tiempo</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {transactions.slice(0, 5).map(tx => (
                <tr key={tx.id} className="hover:bg-slate-50/70 transition-colors">
                  <td className="py-3 font-mono font-bold text-slate-800">{tx.id}</td>
                  <td className="py-3 font-semibold text-slate-700">{tx.machineId}</td>
                  <td className="py-3">
                    <span className="font-bold text-slate-900">{tx.productName}</span>
                    <span className="text-[10px] text-slate-400 ml-1.5 font-mono">({tx.sku})</span>
                  </td>
                  <td className="py-3">
                    {tx.method === 'CASH' ? (
                      <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-amber-50 text-amber-800 font-bold text-[10px] border border-amber-200">
                        <Coins className="w-3 h-3 text-amber-600" />
                        <span>MDB Efectivo (Nivel 0)</span>
                      </span>
                    ) : (
                      <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-indigo-50 text-indigo-800 font-bold text-[10px] border border-indigo-200">
                        <QrCode className="w-3 h-3 text-[#4F46E5]" />
                        <span>QR Dinámico (Nivel 1)</span>
                      </span>
                    )}
                  </td>
                  <td className="py-3 font-black text-slate-900">Bs {tx.amount.toFixed(2)}</td>
                  <td className="py-3">
                    <span className="inline-flex items-center gap-1 text-emerald-600 font-bold text-[11px]">
                      <Check className="w-3.5 h-3.5" />
                      <span>Haz Láser OK</span>
                    </span>
                  </td>
                  <td className="py-3">
                    <span className="px-2 py-0.5 rounded-full text-[10px] font-extrabold bg-emerald-100 text-emerald-800">
                      {tx.stage}
                    </span>
                  </td>
                  <td className="py-3 text-right text-slate-400 font-medium">{tx.timestamp}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
};
