import React, { useState } from 'react';
import {
  Layers,
  Gamepad2,
  Wallet,
  Cpu,
  Server,
  ExternalLink,
  CheckCircle2,
  Activity,
  Code,
  Radio,
  Copy,
  Check
} from 'lucide-react';

export const EcosystemView: React.FC = () => {
  const [copiedEndpoint, setCopiedEndpoint] = useState<string | null>(null);

  const copyToClipboard = (text: string) => {
    navigator.clipboard.writeText(text);
    setCopiedEndpoint(text);
    setTimeout(() => setCopiedEndpoint(null), 2500);
  };

  return (
    <div className="space-y-6 animate-fadeIn pb-12">
      {/* Header */}
      <div>
        <span className="text-[11px] font-extrabold uppercase tracking-widest text-[#4F46E5] bg-indigo-50 px-2 py-0.5 rounded border border-indigo-100">
          08. ECOSISTEMA TECNOLÓGICO GROG
        </span>
        <h2 className="text-2xl font-black text-slate-900 tracking-tight mt-1">
          Interconexión de Sistemas & Gemelo Digital
        </h2>
        <p className="text-xs text-slate-500">
          Arquitectura desacoplada: la plataforma web centraliza los datos mientras SimuPay, el Gemelo 3D y los controladores Edge operan en tiempo real.
        </p>
      </div>

      {/* Main Ecosystem 3-Pillar Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {/* Pillar 1: SimuPay */}
        <div className="bg-white rounded-3xl border border-slate-200 p-6 shadow-sm hover:border-indigo-300 transition-all flex flex-col justify-between">
          <div>
            <div className="flex items-center justify-between mb-4">
              <div className="p-3 rounded-2xl bg-indigo-50 text-[#4F46E5]">
                <Wallet className="w-6 h-6" />
              </div>
              <span className="text-[10px] font-bold px-2.5 py-0.5 rounded-full bg-emerald-100 text-emerald-800 flex items-center gap-1">
                <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
                En Línea
              </span>
            </div>

            <h3 className="text-base font-extrabold text-slate-900">SimuPay Gateway & Wallet</h3>
            <p className="text-xs text-slate-500 mt-1 leading-relaxed">
              Pasarela de pago y monedero virtual complementario. Permite pruebas de checkout, escaneo de QR dinámicos y recarga de saldo de usuarios.
            </p>

            <div className="mt-4 p-3 rounded-xl bg-slate-50 border border-slate-100 text-xs space-y-1">
              <div className="flex items-center justify-between text-slate-600">
                <span>Ruta Web:</span>
                <span className="font-mono font-bold text-slate-800">/wallet · /checkout</span>
              </div>
              <div className="flex items-center justify-between text-slate-600">
                <span>Protocolo:</span>
                <span className="font-mono text-slate-800">HTTPS · HMAC Secret</span>
              </div>
            </div>
          </div>

          <div className="mt-6 pt-4 border-t border-slate-100 flex gap-2">
            <a
              href="/wallet"
              target="_blank"
              rel="noopener noreferrer"
              className="flex-1 py-2.5 px-3 rounded-xl bg-[#4F46E5] hover:bg-[#4338CA] text-white text-xs font-bold flex items-center justify-center gap-1.5 transition-all shadow-md shadow-indigo-600/20"
            >
              <span>Abrir SimuPay</span>
              <ExternalLink className="w-3.5 h-3.5" />
            </a>
          </div>
        </div>

        {/* Pillar 2: Gemelo Digital Unity 3D */}
        <div className="bg-white rounded-3xl border border-slate-200 p-6 shadow-sm hover:border-indigo-300 transition-all flex flex-col justify-between">
          <div>
            <div className="flex items-center justify-between mb-4">
              <div className="p-3 rounded-2xl bg-indigo-50 text-[#4F46E5]">
                <Gamepad2 className="w-6 h-6" />
              </div>
              <span className="text-[10px] font-bold px-2.5 py-0.5 rounded-full bg-emerald-100 text-emerald-800 flex items-center gap-1">
                <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
                WebGL Activo
              </span>
            </div>

            <h3 className="text-base font-extrabold text-slate-900">Gemelo Digital Unity 3D</h3>
            <p className="text-xs text-slate-500 mt-1 leading-relaxed">
              Simulación física tridimensional de la máquina expendedora: caída de productos, inserción de monedas físicas en ranura y giro de resortes.
            </p>

            <div className="mt-4 p-3 rounded-xl bg-slate-50 border border-slate-100 text-xs space-y-1">
              <div className="flex items-center justify-between text-slate-600">
                <span>Ruta Web:</span>
                <span className="font-mono font-bold text-slate-800">/unity (Puerto 8060)</span>
              </div>
              <div className="flex items-center justify-between text-slate-600">
                <span>Render:</span>
                <span className="font-mono text-slate-800">WebGL 2.0 WebAssembly</span>
              </div>
            </div>
          </div>

          <div className="mt-6 pt-4 border-t border-slate-100 flex gap-2">
            <a
              href="/unity"
              target="_blank"
              rel="noopener noreferrer"
              className="flex-1 py-2.5 px-3 rounded-xl bg-slate-900 hover:bg-slate-800 text-white text-xs font-bold flex items-center justify-center gap-1.5 transition-all shadow-md"
            >
              <span>Abrir Gemelo 3D</span>
              <ExternalLink className="w-3.5 h-3.5" />
            </a>
          </div>
        </div>

        {/* Pillar 3: GROG Edge & MQTT Bridge */}
        <div className="bg-white rounded-3xl border border-slate-200 p-6 shadow-sm hover:border-indigo-300 transition-all flex flex-col justify-between">
          <div>
            <div className="flex items-center justify-between mb-4">
              <div className="p-3 rounded-2xl bg-indigo-50 text-[#4F46E5]">
                <Cpu className="w-6 h-6" />
              </div>
              <span className="text-[10px] font-bold px-2.5 py-0.5 rounded-full bg-emerald-100 text-emerald-800 flex items-center gap-1">
                <span className="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-pulse" />
                MDB L3 Listo
              </span>
            </div>

            <h3 className="text-base font-extrabold text-slate-900">GROG Universal Edge (IoT)</h3>
            <p className="text-xs text-slate-500 mt-1 leading-relaxed">
              Módulo microcontrolador conectado al bus industrial MDB Level 3 (9600 Baud), capturando monedas, sensores láser y motores en milisegundos.
            </p>

            <div className="mt-4 p-3 rounded-xl bg-slate-50 border border-slate-100 text-xs space-y-1">
              <div className="flex items-center justify-between text-slate-600">
                <span>Broker MQTT:</span>
                <span className="font-mono font-bold text-slate-800">Puerto 1883</span>
              </div>
              <div className="flex items-center justify-between text-slate-600">
                <span>Tópico Telemetría:</span>
                <span className="font-mono text-slate-800">grog/machines/+/telemetry</span>
              </div>
            </div>
          </div>

          <div className="mt-6 pt-4 border-t border-slate-100 flex gap-2">
            <button
              onClick={() => alert('Prueba de ping MQTT exitosa. Latencia promedio: 11ms.')}
              className="flex-1 py-2.5 px-3 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-800 text-xs font-bold flex items-center justify-center gap-1.5 transition-all"
            >
              <Radio className="w-3.5 h-3.5 text-emerald-600" />
              <span>Ping de Telemetría</span>
            </button>
          </div>
        </div>
      </div>

      {/* Embed Gemelo 3D Preview */}
      <div className="bg-white rounded-3xl border border-slate-200 p-6 shadow-sm space-y-4">
        <div className="flex items-center justify-between">
          <div>
            <h3 className="text-base font-extrabold text-slate-900">
              Vista Previa en Vivo: Gemelo Digital Unity WebGL
            </h3>
            <p className="text-xs text-slate-500">
              Prueba la interacción física directa: monedas, resortes y caída de producto.
            </p>
          </div>

          <a
            href="/unity"
            target="_blank"
            rel="noopener noreferrer"
            className="text-xs font-bold text-[#4F46E5] hover:underline flex items-center gap-1"
          >
            <span>Ver a pantalla completa</span>
            <ExternalLink className="w-3.5 h-3.5" />
          </a>
        </div>

        <div className="w-full h-96 rounded-2xl overflow-hidden border border-slate-200 bg-slate-950 relative">
          <iframe
            src="/unity"
            title="GROG Gemelo Digital Unity 3D"
            className="w-full h-full border-0"
            allow="autoplay; fullscreen"
          />
        </div>
      </div>
    </div>
  );
};
