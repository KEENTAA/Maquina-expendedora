import React, { useState } from 'react';
import {
  Coins,
  QrCode,
  Smartphone,
  Lock,
  Sparkles,
  TrendingUp,
  Cpu,
  Layers,
  Activity,
  CheckCircle2,
  XCircle,
  Clock,
  ArrowRight,
  ExternalLink,
  ShieldCheck,
  Server,
  Zap,
  Box,
  Eye,
  DollarSign,
  ChevronRight,
  Sliders,
  HelpCircle
} from 'lucide-react';
import GrogFrogMascot from './GrogFrogMascot';
import GrogCrmDashboard from './GrogCrmDashboard';

export const GrogCrmPlatform: React.FC = () => {
  const [activeTab, setActiveTab] = useState<'OVERVIEW' | 'CRM_DEMO' | 'TECH_3D'>('OVERVIEW');
  const [selectedLevel, setSelectedLevel] = useState<number>(0);

  const levelInfo = [
    {
      level: 0,
      title: 'Nivel 0: Fiduciario (Hardware Retrofit MDB)',
      subtitle: 'Captura y Arqueo Automatizado de Efectivo',
      icon: Coins,
      badgeColor: 'border-amber-500/30 bg-amber-500/10 text-amber-400',
      description:
        'El 60%+ de las transacciones de vending aún se realizan en efectivo. GROG Universal Edge se conecta de manera no invasiva al bus industrial MDB Level 3 (9600 Baud), capturando cada moneda y billete insertado en milisegundos.',
      benefits: [
        'Arqueo de caja físico en tiempo real visible desde el CRM del operador.',
        'Supervisión del nivel de tubos de monedas y alertas de cambio agotado.',
        'Detección de trampas mecánicas, atascos de monedas y billetes falsos.',
        'Conciliación automática entre el dinero físico recaudado y el inventario dispensado.',
      ],
      frogTip:
        '¡Nivel 0: Fiduciario! Las monedas físicas caen en la ranura, el validador MDB las audita y el CRM registra el dinero sin desfases contables.',
    },
    {
      level: 1,
      title: 'Nivel 1: Escaneo QR Dinámico (Digital Interoperable)',
      subtitle: 'Identificación 1:1 de Usuario y SKU en JSON',
      icon: QrCode,
      badgeColor: 'border-cyan-500/30 bg-cyan-500/10 text-cyan-400',
      description:
        'Pantallas TFT o e-paper proyectan un código QR dinámico único para cada sesión. A diferencia de un QR estático impreso, el payload JSON transporta la identidad del comprador, el ID de la máquina y el SKU exacto del producto.',
      benefits: [
        'Payload JSON interoperable: se conoce con precisión quién compró y qué pagó.',
        'Liquidación bancaria inmediata y conciliación contable sin margen de error.',
        'Soporte universal: compatible con SimuPay, billeteras bancarias y transferencias inmediatas.',
        'Zero fallas de cobro: la transacción solo se captura si el sensor físico confirma la entrega.',
      ],
      frogTip:
        '¡Nivel 1: QR Dinámico! El usuario escanea, el backend valida el JSON al instante y la máquina recibe la orden de dispensar.',
    },
    {
      level: 2,
      title: 'Nivel 2: App Móvil + Fidelización IA & Descuentos por Vencimiento',
      subtitle: 'Dynamic Expiry Markdown & Ofertas Teledirigidas',
      icon: Smartphone,
      badgeColor: 'border-indigo-500/30 bg-indigo-500/10 text-indigo-400',
      description:
        'La máxima inteligencia de autoservicio. Conecta la experiencia del consumidor con algoritmos predictivos de consumo e inventario para maximizar las ventas y eliminar por completo el desperdicio de comida.',
      benefits: [
        'Dynamic Expiry Pricing: rebajas automáticas del precio (-20%, -35%, -50%) según la cercanía a la fecha de caducidad.',
        'Ofertas teledirigidas en la App GROG basadas en patrones de consumo del usuario.',
        'Reducción drástica de mermas: los productos perecederos se venden antes de vencer.',
        'Trato ultra personalizado que eleva el ticket promedio y la fidelidad del cliente.',
      ],
      frogTip:
        '¡Nivel 2: Inteligencia y Cero Merma! La IA detecta qué ítems están próximos a caducar y lanza rebajas teledirigidas en la App.',
    },
    {
      level: 3,
      title: 'Nivel 3: Protocolo Autónomo M2M (Secreto / Confidencial)',
      subtitle: 'Economía de Máquinas Descentralizada y Auto-Reabastecimiento',
      icon: Lock,
      badgeColor: 'border-purple-500/30 bg-purple-500/10 text-purple-400',
      description:
        'Módulo reservado para la próxima generación de redes autónomas de autoservicio. Protocolo Machine-to-Machine para auditoría descentralizada, auto-diagnóstico y contratos inteligentes de reposición.',
      benefits: [
        'Contratos inteligentes para reabastecimiento desatendido entre máquinas y proveedores.',
        'Tokenización y liquidación peer-to-peer de microtransacciones.',
        'Gobernanza distribuida de flota de autoservicio.',
        'Acceso restringido: Lanzamiento oficial programado para Q4 2026.',
      ],
      frogTip:
        '¡Nivel 3: Confidencial! Un protocolo autónomo futurista que convertirá cada expendedora en un nodo financiero autosuficiente.',
    },
  ];

  return (
    <div className="min-h-screen bg-[#080C15] text-slate-100 font-sans selection:bg-indigo-600 selection:text-white">
      {/* ─────────────────────────────────────────────────────────────
          NAVBAR PRINCIPAL
      ───────────────────────────────────────────────────────────── */}
      <nav className="sticky top-0 z-50 bg-[#080C15]/90 backdrop-blur-md border-b border-slate-800/80">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-20 flex items-center justify-between">
          {/* Logo GROG */}
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-indigo-600 to-cyan-500 flex items-center justify-center shadow-lg shadow-indigo-500/25">
              <Layers className="w-5 h-5 text-white" />
            </div>
            <div>
              <span className="text-xl font-black tracking-wider text-white flex items-center gap-1.5">
                GROG <span className="text-cyan-400 font-light">SYSTEMS</span>
              </span>
              <span className="text-[10px] text-slate-400 font-semibold tracking-widest block uppercase">
                Smart Vending CRM & IoT Cloud
              </span>
            </div>
          </div>

          {/* Menú de Navegación de Pestañas */}
          <div className="hidden md:flex items-center gap-2 p-1.5 bg-slate-900/90 rounded-2xl border border-slate-800">
            <button
              onClick={() => setActiveTab('OVERVIEW')}
              className={`px-4 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-2 ${
                activeTab === 'OVERVIEW'
                  ? 'bg-indigo-600 text-white shadow-md'
                  : 'text-slate-400 hover:text-white'
              }`}
            >
              <Zap className="w-3.5 h-3.5" /> Ecosistema & 4 Niveles
            </button>
            <button
              onClick={() => setActiveTab('CRM_DEMO')}
              className={`px-4 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-2 ${
                activeTab === 'CRM_DEMO'
                  ? 'bg-indigo-600 text-white shadow-md'
                  : 'text-slate-400 hover:text-white'
              }`}
            >
              <Activity className="w-3.5 h-3.5" /> CRM de Operador (Demo)
            </button>
            <button
              onClick={() => setActiveTab('TECH_3D')}
              className={`px-4 py-2 rounded-xl text-xs font-bold transition-all flex items-center gap-2 ${
                activeTab === 'TECH_3D'
                  ? 'bg-indigo-600 text-white shadow-md'
                  : 'text-slate-400 hover:text-white'
              }`}
            >
              <Box className="w-3.5 h-3.5" /> Gemelo Digital 3D
            </button>
          </div>

          {/* Botones de Acción Directa */}
          <div className="flex items-center gap-3">
            <a
              href="/unity/"
              target="_blank"
              rel="noreferrer"
              className="hidden sm:flex items-center gap-2 text-xs font-bold px-4 py-2.5 rounded-xl bg-slate-900 border border-slate-700 hover:border-cyan-400 text-cyan-400 transition-all shadow-sm"
            >
              <Box className="w-3.5 h-3.5" />
              Lanzar 3D WebGL <ExternalLink className="w-3 h-3" />
            </a>
            <button
              onClick={() => setActiveTab('CRM_DEMO')}
              className="flex items-center gap-2 text-xs font-bold px-4 py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white transition-all shadow-lg shadow-indigo-600/30 active:scale-95"
            >
              <Activity className="w-3.5 h-3.5" />
              Acceso Operador
            </button>
          </div>
        </div>
      </nav>

      {/* ─────────────────────────────────────────────────────────────
          CONTENIDO DINÁMICO SEGÚN PESTAÑA ACTIVA
      ───────────────────────────────────────────────────────────── */}
      {activeTab === 'CRM_DEMO' ? (
        <div className="space-y-6">
          <div className="max-w-7xl mx-auto px-4 pt-6 flex items-center justify-between">
            <button
              onClick={() => setActiveTab('OVERVIEW')}
              className="text-xs font-bold text-cyan-400 hover:text-cyan-300 flex items-center gap-1.5"
            >
              <ChevronRight className="w-4 h-4 rotate-180" /> Volver a la presentación del Ecosistema
            </button>
            <span className="text-xs text-slate-400 font-medium">
              Modo Demostración Interactivo con datos en vivo
            </span>
          </div>
          <GrogCrmDashboard />
        </div>
      ) : activeTab === 'TECH_3D' ? (
        /* VISTA DEDICADA AL GEMELO DIGITAL 3D */
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12 space-y-12">
          <div className="text-center max-w-3xl mx-auto space-y-4">
            <span className="text-xs font-bold px-3 py-1 rounded-full bg-cyan-500/10 text-cyan-400 border border-cyan-500/30 uppercase tracking-widest inline-flex items-center gap-1.5">
              <Box className="w-3.5 h-3.5" /> Simulación de Alta Fidelidad
            </span>
            <h2 className="text-3xl md:text-5xl font-black text-white tracking-tight">
              Gemelo Digital 3D con Física Industrial
            </h2>
            <p className="text-sm md:text-base text-slate-400 leading-relaxed">
              GROG no solo provee software: modela el comportamiento electromecánico exacto de cada máquina expendedora en un gemelo digital 3D interactivo en WebGL.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div className="bg-slate-900/80 rounded-2xl p-6 border border-slate-800 space-y-4">
              <div className="p-3 rounded-xl bg-amber-500/10 text-amber-400 w-fit">
                <Coins className="w-6 h-6" />
              </div>
              <h3 className="font-bold text-lg text-white">1. Inserción de Moneda Real</h3>
              <p className="text-xs text-slate-400 leading-relaxed">
                Inserción visual de moneda cilíndrica 3D en la ranura frontal del VMC. El aceptador MDB valida el diámetro y aleación, acreditando el saldo en pantalla LCD de forma idéntica a una máquina real.
              </p>
            </div>

            <div className="bg-slate-900/80 rounded-2xl p-6 border border-slate-800 space-y-4">
              <div className="p-3 rounded-xl bg-indigo-500/10 text-indigo-400 w-fit">
                <Cpu className="w-6 h-6" />
              </div>
              <h3 className="font-bold text-lg text-white">2. Resortes Helicoidales & Caída</h3>
              <p className="text-xs text-slate-400 leading-relaxed">
                Los resortes helicoidales 3D giran 360° contenidos perfectamente dentro de las baldas metálicas. El producto se desplaza hacia adelante y cae por gravedad física con colisiones y rebotes en la bandeja.
              </p>
            </div>

            <div className="bg-slate-900/80 rounded-2xl p-6 border border-slate-800 space-y-4">
              <div className="p-3 rounded-xl bg-emerald-500/10 text-emerald-400 w-fit">
                <ShieldCheck className="w-6 h-6" />
              </div>
              <h3 className="font-bold text-lg text-white">3. Proof of Service (HC-SR04)</h3>
              <p className="text-xs text-slate-400 leading-relaxed">
                El sensor ultrasónico HC-SR04 detecta la variación de distancia (de 32.5 cm en vacío a 11.4 cm con snack). Si el producto no cae, se ejecuta un Zero-Loss Refund protegiendo los fondos del cliente.
              </p>
            </div>
          </div>

          {/* Tarjeta de Lanzamiento */}
          <div className="bg-gradient-to-r from-indigo-950/60 via-slate-900 to-indigo-950/60 rounded-3xl p-8 border border-indigo-500/30 text-center space-y-6">
            <h3 className="text-2xl font-black text-white">
              ¿Listo para probar las 3 máquinas en el entorno 3D?
            </h3>
            <p className="text-xs md:text-sm text-slate-300 max-w-xl mx-auto">
              Accede a la simulación WebGL completa: prueba la expendedora de snacks (VENDING-01), el refrigerador a 4.2 °C (COOLER-01) y la cafetera a 92 °C (COFFEE-01).
            </p>
            <div className="flex flex-wrap items-center justify-center gap-4">
              <a
                href="/unity/"
                target="_blank"
                rel="noreferrer"
                className="inline-flex items-center gap-2 px-6 py-3.5 rounded-xl bg-gradient-to-r from-indigo-600 to-cyan-500 hover:from-indigo-500 hover:to-cyan-400 text-white font-bold text-sm shadow-xl shadow-cyan-500/20 transition-all"
              >
                <Box className="w-4 h-4" /> Lanzar Gemelo 3D WebGL <ExternalLink className="w-4 h-4" />
              </a>
              <button
                onClick={() => setActiveTab('OVERVIEW')}
                className="px-6 py-3.5 rounded-xl bg-slate-900 border border-slate-700 text-slate-300 font-semibold text-sm hover:border-slate-500"
              >
                Ver Explicación de los 4 Niveles
              </button>
            </div>
          </div>
        </div>
      ) : (
        /* VISTA PRINCIPAL: HERO + LOS 4 NIVELES + PRESENTACIÓN CRM */
        <div className="space-y-24 pb-24">
          
          {/* ─────────────────────────────────────────────────────────────
              HERO SECTION
          ───────────────────────────────────────────────────────────── */}
          <section className="relative overflow-hidden pt-12 md:pt-20">
            {/* Resplandor ambiental de fondo */}
            <div className="absolute top-1/4 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[700px] h-[400px] bg-indigo-600/15 blur-[140px] pointer-events-none rounded-full" />
            <div className="absolute top-1/3 left-1/4 w-[400px] h-[300px] bg-cyan-500/10 blur-[120px] pointer-events-none rounded-full" />

            <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 grid lg:grid-cols-12 gap-12 items-center relative z-10">
              
              {/* Columna Izquierda: Mensaje y Propuesta de Valor */}
              <div className="lg:col-span-7 space-y-6">
                <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-indigo-500/10 border border-indigo-500/30 text-indigo-400 text-xs font-bold uppercase tracking-wider">
                  <Zap className="w-3.5 h-3.5 text-cyan-400" />
                  Ecosistema FinTech & IoT para Vending
                </div>

                <h1 className="text-4xl sm:text-5xl lg:text-6xl font-black text-white tracking-tight leading-[1.1]">
                  El CRM Inteligente que transforma cualquier <br />
                  <span className="bg-gradient-to-r from-cyan-400 via-indigo-400 to-indigo-200 bg-clip-text text-transparent">
                    máquina expendedora.
                  </span>
                </h1>

                <p className="text-base sm:text-lg text-slate-300 max-w-xl leading-relaxed">
                  Conecte su parque de máquinas sin cambiar de hardware. Desde monedas fiduciarias <strong>(Nivel 0)</strong> y pagos QR interoperables <strong>(Nivel 1)</strong>, hasta fidelización con IA y rebajas automáticas por fecha de vencimiento <strong>(Nivel 2)</strong>.
                </p>

                {/* CTAs */}
                <div className="flex flex-wrap items-center gap-4 pt-2">
                  <button
                    onClick={() => setActiveTab('CRM_DEMO')}
                    className="flex items-center gap-2 px-6 py-3.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white font-bold text-sm shadow-xl shadow-indigo-600/30 transition-all active:scale-95 group"
                  >
                    <Activity className="w-4 h-4" />
                    Explorar CRM de Operador
                    <ArrowRight className="w-4 h-4 group-hover:translate-x-1 transition-transform" />
                  </button>

                  <a
                    href="/unity/"
                    target="_blank"
                    rel="noreferrer"
                    className="flex items-center gap-2 px-6 py-3.5 rounded-xl bg-slate-900 border border-slate-700 hover:border-cyan-400 text-cyan-400 font-bold text-sm transition-all shadow-md"
                  >
                    <Box className="w-4 h-4" />
                    Probar Gemelo 3D en Unity
                  </a>
                </div>

                {/* Métricas de Confianza */}
                <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 pt-6 border-t border-slate-800/80">
                  <div>
                    <span className="text-2xl font-black text-white block">99.98%</span>
                    <span className="text-xs text-slate-400">Uptime MDB Edge</span>
                  </div>
                  <div>
                    <span className="text-2xl font-black text-amber-400 block">&lt;35 ms</span>
                    <span className="text-xs text-slate-400">Latencia Efectivo</span>
                  </div>
                  <div>
                    <span className="text-2xl font-black text-cyan-400 block">0%</span>
                    <span className="text-xs text-slate-400">Merma Alimentaria</span>
                  </div>
                  <div>
                    <span className="text-2xl font-black text-emerald-400 block">100%</span>
                    <span className="text-xs text-slate-400">Proof of Service</span>
                  </div>
                </div>
              </div>

              {/* Columna Derecha: Mascota GROG + Tarjeta Interactiva */}
              <div className="lg:col-span-5 flex flex-col items-center justify-center relative">
                <div className="relative w-full max-w-md bg-gradient-to-b from-slate-900 to-slate-950 p-6 rounded-3xl border border-indigo-500/30 shadow-2xl space-y-6">
                  
                  {/* Mascota GROG Asistente */}
                  <div className="flex justify-center pt-2">
                    <GrogFrogMascot
                      size={130}
                      message="¡Bienvenido a GROG! Modernizamos tus máquinas tradicionales al instante."
                      subMessage="Sin sustituir la máquina: añadimos telemetría MDB, cobro dual y CRM inteligente."
                      icon={Sparkles}
                      bubblePosition="bottom"
                    />
                  </div>

                  {/* Resumen de Flujo */}
                  <div className="p-4 rounded-2xl bg-slate-950/80 border border-slate-800 space-y-3">
                    <div className="flex items-center justify-between text-xs font-bold">
                      <span className="text-slate-400 uppercase tracking-wider">Ecosistema Conectado:</span>
                      <span className="text-emerald-400 flex items-center gap-1">
                        <CheckCircle2 className="w-3.5 h-3.5" /> GROG Cloud Sync
                      </span>
                    </div>

                    <div className="space-y-2 text-xs">
                      <div className="flex items-center justify-between p-2 rounded-lg bg-slate-900 border border-slate-800">
                        <span className="text-slate-300 flex items-center gap-1.5">
                          <Coins className="w-3.5 h-3.5 text-amber-400" /> Moneda Fiduciaria (Nivel 0)
                        </span>
                        <span className="font-mono font-bold text-amber-400">Arqueo MDB</span>
                      </div>
                      <div className="flex items-center justify-between p-2 rounded-lg bg-slate-900 border border-slate-800">
                        <span className="text-slate-300 flex items-center gap-1.5">
                          <QrCode className="w-3.5 h-3.5 text-cyan-400" /> QR Dinámico (Nivel 1)
                        </span>
                        <span className="font-mono font-bold text-cyan-400">JSON 1:1</span>
                      </div>
                      <div className="flex items-center justify-between p-2 rounded-lg bg-slate-900 border border-slate-800">
                        <span className="text-slate-300 flex items-center gap-1.5">
                          <Sparkles className="w-3.5 h-3.5 text-indigo-400" /> Fidelización IA (Nivel 2)
                        </span>
                        <span className="font-mono font-bold text-indigo-400">Precios Dinámicos</span>
                      </div>
                    </div>
                  </div>

                </div>
              </div>

            </div>
          </section>

          {/* ─────────────────────────────────────────────────────────────
              SECCIÓN: LOS 4 NIVELES DE EVOLUCIÓN GROG
          ───────────────────────────────────────────────────────────── */}
          <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-12">
            <div className="text-center max-w-3xl mx-auto space-y-4">
              <span className="text-xs font-bold px-3 py-1 rounded-full bg-indigo-500/10 text-indigo-400 border border-indigo-500/30 uppercase tracking-widest inline-flex items-center gap-1.5">
                <Layers className="w-3.5 h-3.5" /> Arquitectura Escalonada
              </span>
              <h2 className="text-3xl md:text-5xl font-black text-white tracking-tight">
                La Evolución del Vending en 4 Niveles
              </h2>
              <p className="text-sm md:text-base text-slate-400 leading-relaxed">
                GROG resuelve la brecha entre el hardware físico existente y las demandas del consumidor digital actual a través de cuatro niveles arquitectónicos progresivos.
              </p>
            </div>

            {/* Selector de Niveles */}
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
              {levelInfo.map((item) => (
                <button
                  key={item.level}
                  onClick={() => setSelectedLevel(item.level)}
                  className={`p-4 rounded-2xl border text-left transition-all ${
                    selectedLevel === item.level
                      ? 'bg-slate-900 border-indigo-500 shadow-xl shadow-indigo-500/10 scale-102'
                      : 'bg-slate-950/60 border-slate-800 text-slate-400 hover:border-slate-700'
                  }`}
                >
                  <div className="flex items-center justify-between mb-2">
                    <span
                      className={`text-[11px] font-bold px-2 py-0.5 rounded-full border ${item.badgeColor}`}
                    >
                      NIVEL {item.level}
                    </span>
                    {React.createElement(item.icon, { className: "w-4 h-4 text-slate-300" })}
                  </div>
                  <h4 className="font-bold text-xs sm:text-sm text-white truncate">
                    {item.title.split(':')[1]?.trim() || item.title}
                  </h4>
                  <p className="text-[11px] text-slate-500 mt-1 line-clamp-1">
                    {item.subtitle}
                  </p>
                </button>
              ))}
            </div>

            {/* Detalle del Nivel Seleccionado */}
            {(() => {
              const cur = levelInfo[selectedLevel];
              return (
                <div className="bg-slate-900/90 rounded-3xl p-6 sm:p-10 border border-slate-800 shadow-2xl grid lg:grid-cols-12 gap-8 items-center">
                  <div className="lg:col-span-7 space-y-6">
                    <div className="flex items-center gap-3">
                      <div className={`p-3 rounded-2xl border ${cur.badgeColor}`}>
                        {React.createElement(cur.icon, { className: "w-6 h-6" })}
                      </div>
                      <div>
                        <span className={`text-xs font-bold uppercase tracking-widest block ${cur.badgeColor.split(' ')[2]}`}>
                          NIVEL {cur.level}
                        </span>
                        <h3 className="text-2xl sm:text-3xl font-black text-white">
                          {cur.title}
                        </h3>
                      </div>
                    </div>

                    <p className="text-sm sm:text-base text-slate-300 leading-relaxed">
                      {cur.description}
                    </p>

                    <div className="space-y-3 pt-2">
                      <span className="text-xs font-bold uppercase tracking-wider text-slate-400 block">
                        Beneficios Clave para el Operador:
                      </span>
                      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                        {cur.benefits.map((b, idx) => (
                          <div
                            key={idx}
                            className="p-3 rounded-xl bg-slate-950/80 border border-slate-800/80 flex items-start gap-2.5 text-xs text-slate-300"
                          >
                            <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0 mt-0.5" />
                            <span>{b}</span>
                          </div>
                        ))}
                      </div>
                    </div>
                  </div>

                  <div className="lg:col-span-5 flex flex-col items-center justify-center p-6 bg-slate-950/60 rounded-2xl border border-slate-800">
                    <GrogFrogMascot
                      size={110}
                      message={cur.frogTip}
                      icon={cur.icon}
                      bubblePosition="top"
                    />
                  </div>
                </div>
              );
            })()}
          </section>

          {/* ─────────────────────────────────────────────────────────────
              SECCIÓN: CRM DE OPERADOR EMBEBIDO (PREVIEW)
          ───────────────────────────────────────────────────────────── */}
          <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-8">
            <div className="flex flex-col md:flex-row md:items-end justify-between gap-4">
              <div>
                <span className="text-xs font-bold px-3 py-1 rounded-full bg-cyan-500/10 text-cyan-400 border border-cyan-500/30 uppercase tracking-widest inline-flex items-center gap-1.5">
                  <Activity className="w-3.5 h-3.5" /> Panel de Control Unificado
                </span>
                <h2 className="text-3xl font-black text-white mt-2">
                  CRM de Operador: Visibilidad Total del Negocio
                </h2>
                <p className="text-xs sm:text-sm text-slate-400">
                  Consulte arqueos de efectivo, liquidaciones QR en vivo y estado del inventario inteligente.
                </p>
              </div>

              <button
                onClick={() => setActiveTab('CRM_DEMO')}
                className="flex items-center gap-2 px-5 py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white font-bold text-xs shadow-lg shadow-indigo-600/30 transition-all self-start md:self-auto"
              >
                Abrir CRM en Pantalla Completa <ChevronRight className="w-4 h-4" />
              </button>
            </div>

            {/* Embebido del CRM Dashboard */}
            <div className="rounded-3xl border border-slate-800 overflow-hidden shadow-2xl">
              <GrogCrmDashboard />
            </div>
          </section>

          {/* ─────────────────────────────────────────────────────────────
              SECCIÓN COMPARATIVA: TRADICIONAL VS GROG
          ───────────────────────────────────────────────────────────── */}
          <section className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 space-y-12">
            <div className="text-center max-w-2xl mx-auto space-y-3">
              <span className="text-xs font-bold px-3 py-1 rounded-full bg-indigo-500/10 text-indigo-400 border border-indigo-500/30 uppercase tracking-widest inline-flex items-center gap-1.5">
                <Sliders className="w-3.5 h-3.5" /> Comparativa de Negocio
              </span>
              <h2 className="text-3xl font-black text-white">
                ¿Por Qué Elegir GROG?
              </h2>
              <p className="text-xs sm:text-sm text-slate-400">
                La diferencia económica y operativa entre un parque tradicional y una flota inteligente con GROG.
              </p>
            </div>

            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs bg-slate-900/60 rounded-2xl border border-slate-800">
                <thead>
                  <tr className="border-b border-slate-800 text-slate-400 uppercase font-bold tracking-wider">
                    <th className="py-4 px-6">Característica</th>
                    <th className="py-4 px-6 text-slate-500">Máquina Tradicional</th>
                    <th className="py-4 px-6 text-cyan-400 font-black">Con GROG CRM & IoT</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-800 text-slate-300 font-medium">
                  <tr>
                    <td className="py-4 px-6 font-bold text-white">Arqueo de Efectivo</td>
                    <td className="py-4 px-6 text-slate-400 flex items-center gap-2">
                      <XCircle className="w-4 h-4 text-rose-500" /> Manual al retirar la recaudación
                    </td>
                    <td className="py-4 px-6 text-emerald-400 font-bold flex items-center gap-2">
                      <CheckCircle2 className="w-4 h-4 text-emerald-400" /> En tiempo real por bus MDB (Nivel 0)
                    </td>
                  </tr>
                  <tr>
                    <td className="py-4 px-6 font-bold text-white">Trazabilidad de Ventas</td>
                    <td className="py-4 px-6 text-slate-400 flex items-center gap-2">
                      <XCircle className="w-4 h-4 text-rose-500" /> Sin registro de quién compró
                    </td>
                    <td className="py-4 px-6 text-emerald-400 font-bold flex items-center gap-2">
                      <CheckCircle2 className="w-4 h-4 text-emerald-400" /> Payload JSON 1:1 con SKU y Usuario (Nivel 1)
                    </td>
                  </tr>
                  <tr>
                    <td className="py-4 px-6 font-bold text-white">Control de Vencimiento y Merma</td>
                    <td className="py-4 px-6 text-slate-400 flex items-center gap-2">
                      <XCircle className="w-4 h-4 text-rose-500" /> Alta pérdida de alimentos vencidos
                    </td>
                    <td className="py-4 px-6 text-emerald-400 font-bold flex items-center gap-2">
                      <CheckCircle2 className="w-4 h-4 text-emerald-400" /> Dynamic Expiry Pricing con IA (Nivel 2)
                    </td>
                  </tr>
                  <tr>
                    <td className="py-4 px-6 font-bold text-white">Verificación de Entrega</td>
                    <td className="py-4 px-6 text-slate-400 flex items-center gap-2">
                      <XCircle className="w-4 h-4 text-rose-500" /> Riesgo de quejas por producto atascado
                    </td>
                    <td className="py-4 px-6 text-emerald-400 font-bold flex items-center gap-2">
                      <CheckCircle2 className="w-4 h-4 text-emerald-400" /> Proof of Service ultrasónico HC-SR04
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </section>

          {/* ─────────────────────────────────────────────────────────────
              FOOTER
          ───────────────────────────────────────────────────────────── */}
          <footer className="border-t border-slate-800/80 pt-12">
            <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 flex flex-col md:flex-row items-center justify-between gap-6">
              <div className="flex items-center gap-3">
                <div className="w-8 h-8 rounded-lg bg-indigo-600 flex items-center justify-center">
                  <Layers className="w-4 h-4 text-white" />
                </div>
                <span className="font-bold text-sm text-white">
                  GROG Systems &copy; 2026. Todos los derechos reservados.
                </span>
              </div>

              <div className="flex items-center gap-6 text-xs text-slate-400">
                <span className="flex items-center gap-1.5">
                  <ShieldCheck className="w-3.5 h-3.5 text-cyan-400" /> MDB Level 3 NAMA / EVA-CVS
                </span>
                <span className="flex items-center gap-1.5">
                  <Lock className="w-3.5 h-3.5 text-indigo-400" /> Criptografía TLS 1.3
                </span>
              </div>
            </div>
          </footer>

        </div>
      )}
    </div>
  );
};

export default GrogCrmPlatform;
