import React from 'react';
import {
  LayoutDashboard,
  Cpu,
  Users,
  TrendingUp,
  DollarSign,
  Package,
  Sparkles,
  Layers,
  ShieldCheck,
  Lock,
  ChevronRight,
  ExternalLink,
  Gamepad2,
  Wallet
} from 'lucide-react';
import { usePermissions } from '../context/PermissionsContext';

interface GrogSidebarProps {
  activeModule: string;
  onSelectModule: (moduleId: string) => void;
  onOpenAdminModal: () => void;
}

export const GrogSidebar: React.FC<GrogSidebarProps> = ({
  activeModule,
  onSelectModule,
  onOpenAdminModal,
}) => {
  const { role, modules, isModuleAccessible } = usePermissions();

  const getModuleIcon = (id: string) => {
    switch (id) {
      case 'dashboard':
        return LayoutDashboard;
      case 'vending':
        return Cpu;
      case 'crm':
        return Users;
      case 'analytics':
        return TrendingUp;
      case 'finances':
        return DollarSign;
      case 'inventory':
        return Package;
      case 'intelligence':
        return Sparkles;
      case 'ecosystem':
        return Layers;
      default:
        return LayoutDashboard;
    }
  };

  return (
    <aside className="w-64 bg-white border-r border-slate-200 flex flex-col justify-between shrink-0 select-none h-screen sticky top-0 shadow-sm z-30">
      {/* Top Branding Section */}
      <div>
        <div className="p-5 border-b border-slate-100 flex items-center justify-between">
          <div className="flex items-center gap-3">
            {/* SVG Logo Mark */}
            <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-[#4F46E5] to-[#312E81] flex items-center justify-center shadow-md shadow-indigo-500/20 text-white relative">
              <svg viewBox="0 0 100 100" className="w-7 h-7">
                <circle cx="27" cy="32" r="18" fill="#FFFFFF" fillOpacity="0.9" />
                <circle cx="73" cy="32" r="18" fill="#FFFFFF" fillOpacity="0.9" />
                <rect x="12" y="30" width="76" height="52" rx="26" fill="#FFFFFF" fillOpacity="0.95" />
                <circle cx="27" cy="32" r="9" fill="#312E81" />
                <circle cx="73" cy="32" r="9" fill="#312E81" />
                <circle cx="25" cy="30" r="3" fill="#FFFFFF" />
                <circle cx="71" cy="30" r="3" fill="#FFFFFF" />
                <ellipse cx="22" cy="60" rx="5" ry="3" fill="#F472B6" />
                <ellipse cx="78" cy="60" rx="5" ry="3" fill="#F472B6" />
                <path d="M 38 64 Q 50 72 62 64" stroke="#312E81" strokeWidth="3" strokeLinecap="round" fill="none" />
              </svg>
              <div className="w-2.5 h-2.5 rounded-full bg-emerald-400 absolute -top-0.5 -right-0.5 ring-2 ring-white animate-pulse" />
            </div>

            <div>
              <div className="flex items-center gap-1.5">
                <span className="font-extrabold text-xl tracking-tight text-slate-900">GROG</span>
                <span className="text-[10px] uppercase font-bold tracking-wider px-1.5 py-0.5 rounded bg-indigo-50 text-[#4F46E5]">B2B</span>
              </div>
              <p className="text-[11px] text-slate-500 font-medium leading-none mt-0.5">Operations Center</p>
            </div>
          </div>
        </div>

        {/* Tagline Banner */}
        <div className="px-5 py-2.5 bg-slate-50/70 border-b border-slate-100 flex items-center justify-between">
          <p className="text-[10px] font-semibold text-slate-500 tracking-wider uppercase">
            Conecta · Analiza · Optimiza
          </p>
          <div className="w-1.5 h-1.5 rounded-full bg-indigo-500" />
        </div>

        {/* Modules List */}
        <div className="p-3 space-y-1 overflow-y-auto max-h-[calc(100vh-270px)]">
          <div className="px-3 pt-2 pb-1 text-[11px] font-bold text-slate-400 uppercase tracking-wider">
            Módulos de Operación
          </div>

          {modules.map(mod => {
            const Icon = getModuleIcon(mod.id);
            const isAccessible = isModuleAccessible(mod.id);
            const isActive = activeModule === mod.id;

            return (
              <button
                key={mod.id}
                onClick={() => {
                  if (isAccessible) {
                    onSelectModule(mod.id);
                  }
                }}
                disabled={!isAccessible}
                className={`w-full text-left px-3 py-2.5 rounded-xl text-xs font-semibold flex items-center justify-between transition-all group ${
                  isActive
                    ? 'bg-[#4F46E5] text-white shadow-sm shadow-indigo-500/25'
                    : isAccessible
                    ? 'text-slate-700 hover:bg-slate-100 hover:text-slate-900'
                    : 'text-slate-400 bg-slate-50/60 cursor-not-allowed opacity-60'
                }`}
              >
                <div className="flex items-center gap-2.5 truncate">
                  <span
                    className={`font-mono text-[11px] font-bold ${
                      isActive ? 'text-indigo-200' : 'text-slate-400'
                    }`}
                  >
                    {mod.number}
                  </span>
                  <div
                    className={`p-1.5 rounded-lg ${
                      isActive
                        ? 'bg-white/20 text-white'
                        : 'bg-slate-100 text-slate-600 group-hover:text-indigo-600 group-hover:bg-indigo-50'
                    }`}
                  >
                    <Icon className="w-4 h-4" />
                  </div>
                  <span className="truncate">{mod.name}</span>
                </div>

                {!isAccessible && (
                  <div className="flex items-center gap-1 text-[10px] text-amber-600 font-normal">
                    <Lock className="w-3.5 h-3.5" />
                  </div>
                )}
                {isAccessible && isActive && (
                  <ChevronRight className="w-3.5 h-3.5 text-indigo-200 shrink-0" />
                )}
              </button>
            );
          })}
        </div>
      </div>

      {/* Bottom Ecosystem & Admin Section */}
      <div className="p-3 border-t border-slate-100 bg-slate-50/50 space-y-2">
        {/* Quick Links to SimuPay & Unity Gemelo Digital */}
        <div className="px-2 pt-1 flex items-center justify-between text-[11px] font-bold text-slate-400 uppercase tracking-wider">
          <span>Acceso Rápido</span>
          <span className="text-[10px] font-normal text-slate-400">Ecosistema</span>
        </div>

        <div className="grid grid-cols-2 gap-1.5">
          <a
            href="/wallet"
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-1.5 px-2.5 py-1.5 bg-white border border-slate-200 hover:border-indigo-300 rounded-lg text-[11px] font-medium text-slate-700 hover:text-[#4F46E5] shadow-2xs transition-colors"
          >
            <Wallet className="w-3.5 h-3.5 text-indigo-600" />
            <span className="truncate">SimuPay</span>
            <ExternalLink className="w-2.5 h-2.5 text-slate-400 ml-auto" />
          </a>

          <a
            href="/unity"
            target="_blank"
            rel="noopener noreferrer"
            className="flex items-center gap-1.5 px-2.5 py-1.5 bg-white border border-slate-200 hover:border-indigo-300 rounded-lg text-[11px] font-medium text-slate-700 hover:text-[#4F46E5] shadow-2xs transition-colors"
          >
            <Gamepad2 className="w-3.5 h-3.5 text-indigo-600" />
            <span className="truncate">Gemelo 3D</span>
            <ExternalLink className="w-2.5 h-2.5 text-slate-400 ml-auto" />
          </a>
        </div>

        {/* Admin Section Control Button */}
        <button
          onClick={onOpenAdminModal}
          className={`w-full text-left px-3 py-2 rounded-xl text-xs font-semibold flex items-center justify-between border transition-all ${
            role === 'ADMIN'
              ? 'bg-indigo-50/80 border-indigo-200 text-indigo-900 hover:bg-indigo-100'
              : 'bg-white border-slate-200 text-slate-700 hover:bg-slate-100'
          }`}
        >
          <div className="flex items-center gap-2">
            <div className="p-1 rounded bg-[#4F46E5] text-white">
              <ShieldCheck className="w-3.5 h-3.5" />
            </div>
            <div>
              <p className="font-bold text-slate-900 leading-tight">Panel Administrador</p>
              <p className="text-[10px] text-slate-500 font-normal">Gestionar permisos y secciones</p>
            </div>
          </div>
          <span className="text-[10px] font-bold px-1.5 py-0.5 rounded bg-white text-indigo-700 border border-indigo-200 shadow-2xs">
            {role}
          </span>
        </button>
      </div>
    </aside>
  );
};
