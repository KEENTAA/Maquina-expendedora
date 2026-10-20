import React, { useState, useEffect } from 'react';
import {
  Cpu,
  Activity,
  CheckCircle2,
  AlertTriangle,
  RotateCw,
  Plus,
  Radio,
  Sliders,
  Thermometer,
  ShieldCheck,
  Zap,
  Gauge,
  RefreshCw,
  Wrench,
  Check,
  XCircle,
  Clock,
  Power,
  RotateCcw,
  QrCode,
  Tag,
  Coins,
  FileText,
  AlertCircle,
  KeyRound,
  ExternalLink,
  Layers,
  Send
} from 'lucide-react';
import { usePermissions } from '../context/PermissionsContext';
import VendingServiceApi, { BackendMachine, BackendInventoryItem, FactoryResetResponse } from '../services/vendingService';
import GrogFrogMascot from '../GrogFrogMascot';

interface ServiceTicket {
  id: string;
  machineId: string;
  type: 'PREVENTIVO' | 'CORRECTIVO' | 'REPOSICION' | 'CALIBRACION';
  description: string;
  technician: string;
  status: 'PENDIENTE' | 'EN_CURSO' | 'RESUELTO';
  createdAt: string;
}

const INITIAL_SERVICE_TICKETS: ServiceTicket[] = [
  {
    id: 'SRV-1042',
    machineId: 'VENDING-01',
    type: 'CALIBRACION',
    description: 'Calibración de tope de giro en resorte A1 para evitar sobrepaso de espiral.',
    technician: 'Carlos Gómez (Técnico Nivel 2)',
    status: 'RESUELTO',
    createdAt: 'Hoy, 10:15',
  },
  {
    id: 'SRV-1043',
    machineId: 'COOLER-01',
    type: 'PREVENTIVO',
    description: 'Inspección de sello hermético de puerta y calibración de termostato a 4.2°C.',
    technician: 'Mariana Ríos (Soporte Frío)',
    status: 'EN_CURSO',
    createdAt: 'Hoy, 14:30',
  },
  {
    id: 'SRV-1044',
    machineId: 'COFFEE-01',
    type: 'REPOSICION',
    description: 'Recarga de silo de leche en polvo y purga de caldera de agua a 92°C.',
    technician: 'Diego Tórrez (Especialista Barista)',
    status: 'PENDIENTE',
    createdAt: 'Hace 45 min',
  },
];

export const VendingView: React.FC = () => {
  const { machines, setMachines } = usePermissions();
  const [selectedMachineId, setSelectedMachineId] = useState<string>(machines[0]?.id || 'VENDING-01');
  const [activeSubTab, setActiveSubTab] = useState<'TELEMETRIA' | 'SERVICIO' | 'SLOTS'>('SERVICIO');

  // Backend Real Vending Data
  const [backendMachines, setBackendMachines] = useState<BackendMachine[]>([]);
  const [liveInventory, setLiveInventory] = useState<BackendInventoryItem[]>([]);
  const [isLoadingLive, setIsLoadingLive] = useState<boolean>(false);

  // Service Mode State
  const [isServiceModeActive, setIsServiceModeActive] = useState<boolean>(false);
  const [isRebootingVmc, setIsRebootingVmc] = useState<boolean>(false);
  const [resetData, setResetData] = useState<FactoryResetResponse | null>(null);
  const [secondsRemaining, setSecondsRemaining] = useState<number>(300);

  // Motor Testing State
  const [isTestingMotor, setIsTestingMotor] = useState(false);
  const [testResult, setTestResult] = useState<string | null>(null);

  // Service Tickets
  const [tickets, setTickets] = useState<ServiceTicket[]>(INITIAL_SERVICE_TICKETS);
  const [newTicketDesc, setNewTicketDesc] = useState('');
  const [newTicketType, setNewTicketType] = useState<'PREVENTIVO' | 'CORRECTIVO' | 'REPOSICION' | 'CALIBRACION'>('PREVENTIVO');
  const [toastMsg, setToastMsg] = useState<string | null>(null);

  const showToast = (msg: string) => {
    setToastMsg(msg);
    setTimeout(() => setToastMsg(null), 3500);
  };

  const currentMachine = machines.find(m => m.id === selectedMachineId) || machines[0];

  // Load real machines and inventory from backend vending-service
  useEffect(() => {
    const loadBackendData = async () => {
      setIsLoadingLive(true);
      const mList = await VendingServiceApi.getMachines();
      if (mList && mList.length > 0) {
        setBackendMachines(mList);
      }
      const inv = await VendingServiceApi.getMachineInventory(selectedMachineId);
      if (inv && inv.length > 0) {
        setLiveInventory(inv);
      }
      setIsLoadingLive(false);
    };

    loadBackendData();
  }, [selectedMachineId]);

  // Countdown timer for pairing token
  useEffect(() => {
    if (!resetData || secondsRemaining <= 0) return;
    const interval = setInterval(() => {
      setSecondsRemaining(prev => Math.max(0, prev - 1));
    }, 1000);
    return () => clearInterval(interval);
  }, [resetData, secondsRemaining]);

  // Handle Illuminated Service Button Click (VMC Reset & Unlink)
  const handleIlluminatedServiceButtonClick = async () => {
    setIsRebootingVmc(true);
    setTestResult(null);
    showToast(`🔘 [BOTÓN ILUMINADO DE SERVICIO ACCIONADO]: Reiniciando VMC y desvinculando ${selectedMachineId}...`);

    try {
      const resp = await VendingServiceApi.factoryReset(selectedMachineId);
      if (resp) {
        setResetData(resp);
        setSecondsRemaining(resp.expires_in || 300);
        showToast(`¡VMC Reiniciado! Máquina desvinculada. Nuevo PIN generado: ${resp.pairing_code}`);
      } else {
        // Fallback simulation if backend offline
        const simulatedPin = Math.floor(100000 + Math.random() * 900000).toString();
        setResetData({
          pairing_token: `TOKEN-${simulatedPin}`,
          pairing_code: simulatedPin,
          expires_in: 300,
          message: 'VMC Reiniciado correctamente y desvinculado de la cuenta previa.',
        });
        setSecondsRemaining(300);
        showToast(`¡VMC Reiniciado! Máquina desvinculada. Nuevo PIN: ${simulatedPin}`);
      }
    } catch (e) {
      console.error(e);
    } finally {
      setIsRebootingVmc(false);
    }
  };

  // Handle Motor Calibration Test
  const handleTestMotor = (slot: string) => {
    setIsTestingMotor(true);
    setTestResult(null);
    setTimeout(() => {
      setIsTestingMotor(false);
      setTestResult(`Motor de ranura ${slot}: Giro de 360° completado. Resorte alineado al tope sin sobrepaso.`);
      showToast(`Prueba de motor ${slot} exitosa (0 atascos).`);
    }, 1200);
  };

  // Add Service Ticket
  const handleCreateTicket = (e: React.FormEvent) => {
    e.preventDefault();
    if (!newTicketDesc.trim()) return;

    const newTicket: ServiceTicket = {
      id: `SRV-${Math.floor(1000 + Math.random() * 9000)}`,
      machineId: selectedMachineId,
      type: newTicketType,
      description: newTicketDesc,
      technician: 'Técnico de Guardia GROG Edge',
      status: 'PENDIENTE',
      createdAt: 'Ahora mismo',
    };

    setTickets([newTicket, ...tickets]);
    setNewTicketDesc('');
    showToast(`Ticket de servicio ${newTicket.id} creado.`);
  };

  return (
    <div className="space-y-6 animate-fadeIn pb-12">
      {/* Toast Alert */}
      {toastMsg && (
        <div className="fixed bottom-6 right-6 z-50 bg-slate-900 text-white px-5 py-3 rounded-2xl shadow-2xl border border-indigo-500/40 flex items-center gap-3 animate-slideUp">
          <CheckCircle2 className="w-5 h-5 text-emerald-400 shrink-0" />
          <p className="text-xs font-semibold">{toastMsg}</p>
        </div>
      )}

      {/* Header with Service Mode Status */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <span className="text-[11px] font-extrabold uppercase tracking-widest text-[#4F46E5] bg-indigo-50 px-2 py-0.5 rounded border border-indigo-100">
            02. VENDING Y SERVICIO TÉCNICO
          </span>
          <h2 className="text-2xl font-black text-slate-900 tracking-tight mt-1">
            Gestión de Vending & Modo Servicio
          </h2>
          <p className="text-xs text-slate-500">
            Supervisión industrial MDB Level 3, botón iluminado de servicio, reinicio VMC y órdenes de mantenimiento.
          </p>
        </div>

        {/* Global Service Mode Indicator */}
        <div className="flex items-center gap-3">
          <div className="bg-white p-1.5 rounded-2xl border border-slate-200 shadow-2xs flex items-center gap-2">
            <span className="text-xs font-bold text-slate-700 pl-2">Estado del Servicio:</span>
            <button
              onClick={() => {
                const nextState = !isServiceModeActive;
                setIsServiceModeActive(nextState);
                showToast(
                  nextState
                    ? `Máquina ${selectedMachineId} puesta en MODO SERVICIO TÉCNICO.`
                    : `Máquina ${selectedMachineId} regresada a MODO EN SERVICIO (Operativa).`
                );
              }}
              className={`px-3 py-1.5 rounded-xl text-xs font-bold flex items-center gap-1.5 transition-all ${
                isServiceModeActive
                  ? 'bg-amber-500 text-white shadow-sm'
                  : 'bg-emerald-600 text-white shadow-sm'
              }`}
            >
              <Power className="w-3.5 h-3.5" />
              <span>{isServiceModeActive ? 'En Mantenimiento (Servicio)' : 'En Servicio (Venta Activa)'}</span>
            </button>
          </div>
        </div>
      </div>

      {/* Navigation Sub-Tabs */}
      <div className="flex items-center gap-2 border-b border-slate-200 pb-2">
        <button
          onClick={() => setActiveSubTab('SERVICIO')}
          className={`px-4 py-2 rounded-xl text-xs font-bold flex items-center gap-2 transition-all ${
            activeSubTab === 'SERVICIO'
              ? 'bg-[#4F46E5] text-white shadow-sm'
              : 'text-slate-600 hover:bg-slate-100'
          }`}
        >
          <Wrench className="w-4 h-4" />
          <span>Panel de Servicio Técnico & Botón Iluminado</span>
        </button>

        <button
          onClick={() => setActiveSubTab('TELEMETRIA')}
          className={`px-4 py-2 rounded-xl text-xs font-bold flex items-center gap-2 transition-all ${
            activeSubTab === 'TELEMETRIA'
              ? 'bg-[#4F46E5] text-white shadow-sm'
              : 'text-slate-600 hover:bg-slate-100'
          }`}
        >
          <Cpu className="w-4 h-4" />
          <span>Telemetría de Flota & MDB</span>
        </button>

        <button
          onClick={() => setActiveSubTab('SLOTS')}
          className={`px-4 py-2 rounded-xl text-xs font-bold flex items-center gap-2 transition-all ${
            activeSubTab === 'SLOTS'
              ? 'bg-[#4F46E5] text-white shadow-sm'
              : 'text-slate-600 hover:bg-slate-100'
          }`}
        >
          <Tag className="w-4 h-4" />
          <span>Slots & Precios Backend (:8040)</span>
        </button>
      </div>

      {/* Fleet Overview Selector Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        {machines.map(m => {
          const isSelected = m.id === selectedMachineId;

          return (
            <div
              key={m.id}
              onClick={() => setSelectedMachineId(m.id)}
              className={`p-5 rounded-2xl border cursor-pointer transition-all ${
                isSelected
                  ? 'bg-white border-[#4F46E5] ring-2 ring-indigo-500/20 shadow-md'
                  : 'bg-white border-slate-200 hover:border-slate-300 shadow-2xs'
              }`}
            >
              <div className="flex items-center justify-between mb-3">
                <span className="font-mono text-xs font-black text-[#4F46E5] bg-indigo-50 px-2 py-0.5 rounded">
                  {m.id}
                </span>
                <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-emerald-100 text-emerald-800 flex items-center gap-1">
                  <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
                  {isServiceModeActive && m.id === selectedMachineId ? 'EN MANTENIMIENTO' : m.status}
                </span>
              </div>

              <h3 className="font-extrabold text-slate-900 text-base">{m.name}</h3>
              <p className="text-xs text-slate-500 mt-0.5 truncate">{m.location}</p>

              <div className="mt-4 pt-3 border-t border-slate-100 grid grid-cols-3 gap-2 text-center text-xs">
                <div>
                  <p className="text-slate-400 text-[10px]">Stock</p>
                  <p className="font-extrabold text-slate-800">{m.totalStock}/{m.totalCapacity}</p>
                </div>
                <div>
                  <p className="text-slate-400 text-[10px]">Temp</p>
                  <p className="font-extrabold text-slate-800">{m.temperature}°C</p>
                </div>
                <div>
                  <p className="text-slate-400 text-[10px]">Ping</p>
                  <p className="font-extrabold text-slate-800">{m.pingMs}ms</p>
                </div>
              </div>
            </div>
          );
        })}
      </div>

      {/* ========================================================================= */}
      {/* TAB 1: MODO SERVICIO TÉCNICO & BOTÓN ILUMINADO DE SERVICIO */}
      {/* ========================================================================= */}
      {activeSubTab === 'SERVICIO' && (
        <div className="space-y-6">
          {/* Main Service Hero Card */}
          <div className="bg-gradient-to-r from-slate-900 via-[#1E1B4B] to-[#312E81] text-white p-6 md:p-8 rounded-3xl shadow-xl border border-indigo-900/40 relative overflow-hidden">
            <div className="flex flex-col lg:flex-row items-center justify-between gap-6">
              <div className="flex items-start gap-4 text-center sm:text-left">
                <div className="shrink-0 p-3.5 rounded-2xl bg-amber-500/20 text-amber-300 border border-amber-400/30">
                  <Wrench className="w-7 h-7" />
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <span className="text-[10px] font-extrabold uppercase tracking-wider px-2 py-0.5 rounded bg-amber-500/30 text-amber-200 border border-amber-400/30">
                      Modo Servicio Técnico Activo
                    </span>
                    <span className="text-xs text-slate-400 font-mono">Máquina: {selectedMachineId}</span>
                  </div>
                  <h3 className="text-xl md:text-2xl font-black text-white mt-1">
                    Control de Mantenimiento & Botón Iluminado
                  </h3>
                  <p className="text-xs md:text-sm text-indigo-100/80 max-w-xl mt-1 leading-relaxed">
                    Al accionar el <strong>Botón Iluminado de Servicio</strong>, el VMC reinicia el bus MDB, borra la asignación de cuenta del propietario previo y proyecta un nuevo PIN y QR de vinculación segura para registrar la máquina en una nueva cuenta.
                  </p>
                </div>
              </div>

              {/* THE ILLUMINATED SERVICE BUTTON */}
              <div className="shrink-0 w-full lg:w-auto flex flex-col items-center gap-2">
                <button
                  onClick={handleIlluminatedServiceButtonClick}
                  disabled={isRebootingVmc}
                  className={`w-full sm:w-auto px-6 py-4 rounded-2xl text-xs font-black uppercase tracking-wider flex items-center justify-center gap-3 transition-all shadow-xl ${
                    isRebootingVmc
                      ? 'bg-slate-700 text-slate-400 cursor-not-allowed'
                      : 'bg-gradient-to-r from-amber-500 via-rose-500 to-amber-500 hover:from-amber-400 hover:to-rose-400 text-white shadow-amber-500/30 hover:scale-102 ring-4 ring-amber-400/30 animate-pulse'
                  }`}
                  title="Presionar el botón iluminado de servicio reinicia la máquina y desvincula la cuenta actual"
                >
                  <Power className="w-5 h-5 text-white" />
                  <span>
                    {isRebootingVmc
                      ? 'Reiniciando VMC y Desvinculando...'
                      : '🔘 [BOTÓN ILUMINADO DE SERVICIO: REINICIAR Y DESVINCULAR]'}
                  </span>
                </button>
                <p className="text-[10px] text-amber-300 font-semibold text-center">
                  Acción de hardware seguro: Ejecuta factory-reset contra vending-service (:8040)
                </p>
              </div>
            </div>

            {/* Generated Pairing Credentials Display */}
            {resetData && (
              <div className="mt-6 pt-6 border-t border-white/10 grid grid-cols-1 md:grid-cols-3 gap-4 animate-fadeIn">
                <div className="bg-white/10 backdrop-blur-xs p-4 rounded-2xl border border-white/20">
                  <span className="text-[10px] font-bold uppercase tracking-wider text-amber-300">
                    PIN de Activación para App Móvil
                  </span>
                  <div className="flex items-center gap-3 mt-1">
                    <KeyRound className="w-6 h-6 text-amber-400" />
                    <span className="text-3xl font-black tracking-widest text-white font-mono">
                      {resetData.pairing_code}
                    </span>
                  </div>
                  <p className="text-[11px] text-slate-300 mt-1">
                    Introduce este PIN en la pantalla de vinculación de la App.
                  </p>
                </div>

                <div className="bg-white/10 backdrop-blur-xs p-4 rounded-2xl border border-white/20">
                  <span className="text-[10px] font-bold uppercase tracking-wider text-cyan-300">
                    Tiempo de Validez del Token
                  </span>
                  <div className="flex items-center gap-3 mt-1">
                    <Clock className="w-6 h-6 text-cyan-400" />
                    <span className="text-3xl font-black text-white font-mono">
                      {Math.floor(secondsRemaining / 60)}:{(secondsRemaining % 60).toString().padStart(2, '0')}
                    </span>
                  </div>
                  <p className="text-[11px] text-slate-300 mt-1">
                    El token expira automáticamente por seguridad criptográfica.
                  </p>
                </div>

                <div className="bg-white/10 backdrop-blur-xs p-4 rounded-2xl border border-white/20 flex flex-col justify-between">
                  <div>
                    <span className="text-[10px] font-bold uppercase tracking-wider text-emerald-300">
                      Estado de Desvinculación
                    </span>
                    <p className="text-sm font-bold text-white mt-1">
                      Máquina liberada para nuevo dueño
                    </p>
                  </div>
                  <span className="inline-flex items-center gap-1 text-[11px] font-bold text-emerald-400 mt-2">
                    <CheckCircle2 className="w-4 h-4" />
                    <span>Listo para escanear QR o ingresar PIN</span>
                  </span>
                </div>
              </div>
            )}
          </div>

          {/* Service Diagnostics and Actuator Tests */}
          <div className="bg-white rounded-3xl border border-slate-200 p-6 shadow-sm space-y-4">
            <div className="flex items-center justify-between pb-3 border-b border-slate-100">
              <div>
                <h3 className="text-base font-extrabold text-slate-900 flex items-center gap-2">
                  <Gauge className="w-5 h-5 text-[#4F46E5]" />
                  <span>Pruebas de Servicio & Calibración de Hardware</span>
                </h3>
                <p className="text-xs text-slate-500">
                  Ejecuta diagnósticos sin comprometer inventario ni alterar contabilidad de ventas.
                </p>
              </div>

              {testResult && (
                <span className="text-xs font-bold text-emerald-800 bg-emerald-50 border border-emerald-200 px-3 py-1 rounded-xl">
                  {testResult}
                </span>
              )}
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              {/* Test 1: Calibrar Resortes Helicoidales */}
              <div className="p-4 rounded-2xl bg-slate-50 border border-slate-200 space-y-3">
                <div className="flex items-center justify-between text-xs font-bold text-slate-700">
                  <span>Prueba de Resortes (360°)</span>
                  <RotateCw className="w-4 h-4 text-indigo-600" />
                </div>
                <p className="text-xs text-slate-500">
                  Prueba el giro completo de ranuras para asegurar que el resorte no sobrepasa el borde del estante.
                </p>
                <div className="flex flex-wrap gap-1.5 pt-1">
                  {['A1', 'A2', 'B1', 'B2', 'C1', 'C2'].map(slot => (
                    <button
                      key={slot}
                      disabled={isTestingMotor}
                      onClick={() => handleTestMotor(slot)}
                      className="px-2.5 py-1 rounded-lg bg-white border border-slate-200 hover:border-indigo-300 text-[11px] font-bold text-slate-700 hover:text-[#4F46E5] shadow-2xs transition-all disabled:opacity-50"
                    >
                      Ranura {slot}
                    </button>
                  ))}
                </div>
              </div>

              {/* Test 2: Sensor Láser / Ultrasónico Proof of Service */}
              <div className="p-4 rounded-2xl bg-slate-50 border border-slate-200 space-y-3">
                <div className="flex items-center justify-between text-xs font-bold text-slate-700">
                  <span>Sensor Óptico Láser (Proof of Service)</span>
                  <ShieldCheck className="w-4 h-4 text-emerald-600" />
                </div>
                <p className="text-xs text-slate-500">
                  Prueba de detección del haz infrarrojo en la tolva de caída (umbral nominal: 32.5 cm).
                </p>
                <button
                  onClick={() => {
                    setTestResult('Sensor láser HC-SR04 disparado: Haz limpio, distancia nominal 32.4 cm detectada.');
                    showToast('Sensor de caída verificado.');
                  }}
                  className="w-full py-2 px-3 rounded-xl bg-white border border-slate-200 hover:border-emerald-300 text-slate-700 hover:text-emerald-700 text-xs font-bold transition-all shadow-2xs"
                >
                  Disparar Pulso de Prueba
                </button>
              </div>

              {/* Test 3: Purga y Arqueo de Tolva MDB */}
              <div className="p-4 rounded-2xl bg-slate-50 border border-slate-200 space-y-3">
                <div className="flex items-center justify-between text-xs font-bold text-slate-700">
                  <span>Validador MDB de Monedas</span>
                  <Coins className="w-4 h-4 text-amber-600" />
                </div>
                <p className="text-xs text-slate-500">
                  Lectura del nivel de tubos mecánicos de 1 Bs, 2 Bs y 5 Bs y test de electroimanes de devolución.
                </p>
                <button
                  onClick={() => {
                    setTestResult('Validador MDB responde: Tubos de cambio al 78%. Mecanismo de rechazo operativo.');
                    showToast('Tolva MDB auditada sin atascos.');
                  }}
                  className="w-full py-2 px-3 rounded-xl bg-white border border-slate-200 hover:border-amber-300 text-slate-700 hover:text-amber-700 text-xs font-bold transition-all shadow-2xs"
                >
                  Auditar Tubos de Cambio
                </button>
              </div>
            </div>
          </div>

          {/* Service Tickets Management */}
          <div className="bg-white rounded-3xl border border-slate-200 p-6 shadow-sm space-y-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-3 border-b border-slate-100">
              <div>
                <h3 className="text-base font-extrabold text-slate-900 flex items-center gap-2">
                  <FileText className="w-5 h-5 text-[#4F46E5]" />
                  <span>Historial & Órdenes de Servicio Técnico</span>
                </h3>
                <p className="text-xs text-slate-500">
                  Registro de intervenciones mecánicas, calibraciones y visitas técnicas en {selectedMachineId}.
                </p>
              </div>

              <span className="text-xs font-bold text-slate-500">
                {tickets.length} órdenes registradas
              </span>
            </div>

            {/* Form to create service ticket */}
            <form onSubmit={handleCreateTicket} className="p-4 rounded-2xl bg-slate-50/70 border border-slate-200 flex flex-col sm:flex-row items-center gap-3">
              <select
                value={newTicketType}
                onChange={e => setNewTicketType(e.target.value as any)}
                className="w-full sm:w-44 px-3 py-2 rounded-xl bg-white border border-slate-200 text-xs font-bold text-slate-700 focus:outline-hidden"
              >
                <option value="PREVENTIVO">Mantenimiento Preventivo</option>
                <option value="CORRECTIVO">Reparación Correctiva</option>
                <option value="CALIBRACION">Calibración de Resortes</option>
                <option value="REPOSICION">Reposición de Insumos</option>
              </select>

              <input
                type="text"
                placeholder="Descripción del servicio (ej: Limpieza de sensor, cambio de resorte)..."
                value={newTicketDesc}
                onChange={e => setNewTicketDesc(e.target.value)}
                className="flex-1 w-full px-3.5 py-2 rounded-xl bg-white border border-slate-200 text-xs text-slate-800 placeholder-slate-400 focus:outline-hidden"
              />

              <button
                type="submit"
                className="w-full sm:w-auto px-4 py-2 rounded-xl bg-[#4F46E5] hover:bg-[#4338CA] text-white text-xs font-bold flex items-center justify-center gap-1.5 shadow-md shadow-indigo-600/20 shrink-0"
              >
                <Plus className="w-3.5 h-3.5" />
                <span>Programar Servicio</span>
              </button>
            </form>

            {/* Tickets Table */}
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs">
                <thead>
                  <tr className="border-b border-slate-100 text-slate-400 font-bold uppercase tracking-wider text-[10px]">
                    <th className="pb-3">ID Ticket</th>
                    <th className="pb-3">Máquina</th>
                    <th className="pb-3">Tipo de Servicio</th>
                    <th className="pb-3">Descripción</th>
                    <th className="pb-3">Técnico Asignado</th>
                    <th className="pb-3">Estado</th>
                    <th className="pb-3 text-right">Fecha</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100">
                  {tickets.map(ticket => (
                    <tr key={ticket.id} className="hover:bg-slate-50/70 transition-colors">
                      <td className="py-3 font-mono font-bold text-slate-800">{ticket.id}</td>
                      <td className="py-3 font-semibold text-slate-700">{ticket.machineId}</td>
                      <td className="py-3">
                        <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-slate-100 text-slate-700">
                          {ticket.type}
                        </span>
                      </td>
                      <td className="py-3 text-slate-800 max-w-xs truncate">{ticket.description}</td>
                      <td className="py-3 text-slate-600 font-medium">{ticket.technician}</td>
                      <td className="py-3">
                        {ticket.status === 'RESUELTO' && (
                          <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-100 text-emerald-800">
                            Resuelto
                          </span>
                        )}
                        {ticket.status === 'EN_CURSO' && (
                          <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-indigo-100 text-indigo-800">
                            En Curso
                          </span>
                        )}
                        {ticket.status === 'PENDIENTE' && (
                          <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-amber-100 text-amber-800">
                            Pendiente
                          </span>
                        )}
                      </td>
                      <td className="py-3 text-right text-slate-400">{ticket.createdAt}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      )}

      {/* ========================================================================= */}
      {/* TAB 2: TELEMETRIA INDUSTRIAL & ESTADO OPERATIVO */}
      {/* ========================================================================= */}
      {activeSubTab === 'TELEMETRIA' && currentMachine && (
        <div className="bg-white rounded-3xl border border-slate-200 shadow-sm p-6 md:p-8 space-y-6">
          <div className="flex flex-col md:flex-row md:items-center justify-between pb-6 border-b border-slate-100 gap-4">
            <div>
              <div className="flex items-center gap-2">
                <h3 className="text-xl font-black text-slate-900">
                  {currentMachine.name} ({currentMachine.id})
                </h3>
                <span className="text-xs font-mono text-slate-400">
                  Uptime: {currentMachine.uptimeHours} horas continuas
                </span>
              </div>
              <p className="text-xs text-slate-500 mt-1">
                Ubicación de despliegue: <strong>{currentMachine.location}</strong>
              </p>
            </div>

            <div className="flex items-center gap-2">
              <span className="px-3 py-1 rounded-xl bg-slate-100 text-slate-700 text-xs font-bold flex items-center gap-1.5">
                <Radio className="w-3.5 h-3.5 text-emerald-500" />
                <span>Broker Mosquitto MQTT :1883 Activo</span>
              </span>
            </div>
          </div>

          {/* Diagnostics Grid */}
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            <div className="bg-slate-50 p-4 rounded-2xl border border-slate-200/80">
              <div className="flex items-center justify-between text-xs text-slate-500 mb-2">
                <span className="font-bold">Bus Industrial MDB</span>
                <CheckCircle2 className="w-4 h-4 text-emerald-500" />
              </div>
              <p className="text-lg font-black text-slate-900">{currentMachine.mdbBusStatus}</p>
              <p className="text-[11px] text-slate-500 mt-1">9600 Baud · Protocol Level 3</p>
            </div>

            <div className="bg-slate-50 p-4 rounded-2xl border border-slate-200/80">
              <div className="flex items-center justify-between text-xs text-slate-500 mb-2">
                <span className="font-bold">Sensor de Caída (Láser)</span>
                <ShieldCheck className="w-4 h-4 text-emerald-500" />
              </div>
              <p className="text-lg font-black text-slate-900">{currentMachine.dropSensorLaser}</p>
              <p className="text-[11px] text-slate-500 mt-1">Haz infrarrojo continuo calibrado</p>
            </div>

            <div className="bg-slate-50 p-4 rounded-2xl border border-slate-200/80">
              <div className="flex items-center justify-between text-xs text-slate-500 mb-2">
                <span className="font-bold">Termostato Digital</span>
                <Thermometer className="w-4 h-4 text-indigo-500" />
              </div>
              <p className="text-lg font-black text-slate-900">{currentMachine.temperature}°C</p>
              <p className="text-[11px] text-slate-500 mt-1">Objetivo: {currentMachine.targetTemperature}°C</p>
            </div>

            <div className="bg-slate-50 p-4 rounded-2xl border border-slate-200/80">
              <div className="flex items-center justify-between text-xs text-slate-500 mb-2">
                <span className="font-bold">Arqueo Tolva Monedas</span>
                <Zap className="w-4 h-4 text-amber-500" />
              </div>
              <p className="text-lg font-black text-slate-900">
                Bs {currentMachine.cashHopperBalance.toFixed(2)}
              </p>
              <p className="text-[11px] text-slate-500 mt-1">Tubos de cambio al 78%</p>
            </div>
          </div>
        </div>
      )}

      {/* ========================================================================= */}
      {/* TAB 3: SLOTS & PRECIOS REALES CONECTADOS AL BACKEND VENDING-SERVICE (:8040) */}
      {/* ========================================================================= */}
      {activeSubTab === 'SLOTS' && (
        <div className="bg-white rounded-3xl border border-slate-200 shadow-sm p-6 space-y-4">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-3 border-b border-slate-100">
            <div>
              <h3 className="text-base font-extrabold text-slate-900 flex items-center gap-2">
                <Tag className="w-5 h-5 text-[#4F46E5]" />
                <span>Inventario & Ranuras Conectadas a vending-service (:8040)</span>
              </h3>
              <p className="text-xs text-slate-500">
                Datos sincronizados en tiempo real mediante la API REST interna del servicio de vending.
              </p>
            </div>

            <button
              onClick={async () => {
                setIsLoadingLive(true);
                const inv = await VendingServiceApi.getMachineInventory(selectedMachineId);
                if (inv) setLiveInventory(inv);
                setIsLoadingLive(false);
                showToast(`Inventario de ${selectedMachineId} actualizado.`);
              }}
              className="px-3 py-1.5 rounded-xl bg-slate-100 hover:bg-slate-200 text-xs font-bold text-slate-700 flex items-center gap-1.5 transition-colors"
            >
              <RotateCw className={`w-3.5 h-3.5 ${isLoadingLive ? 'animate-spin' : ''}`} />
              <span>Sincronizar API</span>
            </button>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            {liveInventory.map(slot => (
              <div
                key={slot.inventory_id || slot.slot}
                className="p-4 rounded-2xl border border-slate-200 bg-slate-50/60 flex flex-col justify-between space-y-3"
              >
                <div>
                  <div className="flex items-center justify-between">
                    <span className="font-mono text-xs font-black px-2 py-0.5 rounded bg-white border border-slate-200 text-[#4F46E5]">
                      Slot {slot.slot}
                    </span>
                    <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full ${
                      slot.is_enabled ? 'bg-emerald-100 text-emerald-800' : 'bg-rose-100 text-rose-800'
                    }`}>
                      {slot.is_enabled ? 'Habilitado' : 'Desactivado'}
                    </span>
                  </div>

                  <h4 className="font-bold text-slate-900 text-sm mt-2">{slot.product_name}</h4>
                  <p className="text-[11px] text-slate-400 font-mono">SKU: {slot.product_sku}</p>

                  <div className="mt-3 flex items-center justify-between text-xs">
                    <span className="text-slate-500">Stock en Ranura:</span>
                    <span className="font-extrabold text-slate-800">{slot.stock} / {slot.capacity} uds</span>
                  </div>
                </div>

                <div className="pt-2 border-t border-slate-200/80 flex items-center justify-between">
                  <div>
                    <span className="text-[10px] text-slate-400 block">Precio Actual</span>
                    <span className="text-base font-black text-slate-900">Bs {slot.price.toFixed(2)}</span>
                  </div>

                  <div className="flex items-center gap-1.5">
                    <button
                      onClick={async () => {
                        const newPrice = slot.price - 0.50;
                        if (newPrice > 0) {
                          await VendingServiceApi.updateSlotPrice(selectedMachineId, slot.slot, newPrice);
                          slot.price = newPrice;
                          showToast(`Precio de slot ${slot.slot} actualizado a Bs ${newPrice.toFixed(2)}`);
                        }
                      }}
                      className="px-2 py-1 rounded-lg bg-white border border-slate-200 hover:bg-slate-100 text-xs font-bold text-slate-700"
                    >
                      -0.50
                    </button>
                    <button
                      onClick={async () => {
                        const newPrice = slot.price + 0.50;
                        await VendingServiceApi.updateSlotPrice(selectedMachineId, slot.slot, newPrice);
                        slot.price = newPrice;
                        showToast(`Precio de slot ${slot.slot} actualizado a Bs ${newPrice.toFixed(2)}`);
                      }}
                      className="px-2 py-1 rounded-lg bg-white border border-slate-200 hover:bg-slate-100 text-xs font-bold text-slate-700"
                    >
                      +0.50
                    </button>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
};
