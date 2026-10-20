import React from 'react';
import {
  Bell,
  Activity,
  Shield,
  User,
  Sliders,
  CheckCircle2,
  RefreshCw
} from 'lucide-react';
import { usePermissions } from '../context/PermissionsContext';

interface GrogHeaderProps {
  activeModuleName: string;
  onOpenAdminModal: () => void;
}

export const GrogHeader: React.FC<GrogHeaderProps> = ({
  activeModuleName,
  onOpenAdminModal,
}) => {
  const { role, setRole } = usePermissions();

  return (
    <header className="bg-white border-b border-slate-200 px-6 py-3.5 sticky top-0 z-20 flex items-center justify-between shadow-2xs">
      {/* Left Title and Breadcrumbs */}
      <div className="flex items-center gap-3">
        <div>
          <div className="flex items-center gap-2 text-xs font-semibold text-slate-400">
            <span>GROG Platform</span>
            <span>/</span>
            <span className="text-[#4F46E5] font-bold">{activeModuleName}</span>
          </div>
          <h1 className="text-lg font-extrabold text-slate-900 tracking-tight leading-tight mt-0.5">
            {activeModuleName}
          </h1>
        </div>
      </div>

      {/* Right Actions & Role Switcher */}
      <div className="flex items-center gap-4">
        {/* Live Telemetry Ping Status */}
        <div className="hidden sm:flex items-center gap-2 px-3 py-1.5 bg-emerald-50 border border-emerald-200/60 rounded-full text-xs font-medium text-emerald-700">
          <span className="relative flex h-2 w-2">
            <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
            <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>
          </span>
          <span>Telemetría en Vivo (MDB + IoT)</span>
        </div>

        {/* Role Switcher (Admin vs Operator) */}
        <div className="flex items-center bg-slate-100 p-1 rounded-xl border border-slate-200">
          <button
            onClick={() => setRole('ADMIN')}
            className={`px-3 py-1 rounded-lg text-xs font-bold transition-all flex items-center gap-1.5 ${
              role === 'ADMIN'
                ? 'bg-[#4F46E5] text-white shadow-sm'
                : 'text-slate-600 hover:text-slate-900'
            }`}
            title="Vista completa con control de permisos y activación de módulos"
          >
            <Shield className="w-3.5 h-3.5" />
            <span>Admin</span>
          </button>

          <button
            onClick={() => setRole('OPERATOR')}
            className={`px-3 py-1 rounded-lg text-xs font-bold transition-all flex items-center gap-1.5 ${
              role === 'OPERATOR'
                ? 'bg-[#312E81] text-white shadow-sm'
                : 'text-slate-600 hover:text-slate-900'
            }`}
            title="Vista de usuario operador con restricciones configuradas"
          >
            <User className="w-3.5 h-3.5" />
            <span>Operador</span>
          </button>
        </div>

        {/* Admin Settings Button */}
        <button
          onClick={onOpenAdminModal}
          className="p-2 rounded-xl border border-slate-200 hover:bg-slate-50 text-slate-600 hover:text-[#4F46E5] transition-colors relative"
          title="Configurar permisos de secciones para usuarios"
        >
          <Sliders className="w-4 h-4" />
        </button>

        {/* Notifications */}
        <div className="relative">
          <button className="p-2 rounded-xl border border-slate-200 hover:bg-slate-50 text-slate-600 transition-colors">
            <Bell className="w-4 h-4" />
            <span className="absolute top-1 right-1 w-2 h-2 bg-rose-500 rounded-full ring-2 ring-white" />
          </button>
        </div>

        {/* User Profile */}
        <div className="flex items-center gap-2.5 pl-2 border-l border-slate-200">
          <div className="w-8 h-8 rounded-full bg-gradient-to-tr from-[#4F46E5] to-[#6366F1] text-white font-bold flex items-center justify-center text-xs shadow-inner">
            {role === 'ADMIN' ? 'AD' : 'OP'}
          </div>
          <div className="hidden md:block text-left">
            <p className="text-xs font-bold text-slate-800 leading-tight">
              {role === 'ADMIN' ? 'Super Administrador' : 'Operador de Ruta'}
            </p>
            <p className="text-[10px] text-slate-400 font-medium">
              {role === 'ADMIN' ? 'Control de Sistema' : 'Vending Restringido'}
            </p>
          </div>
        </div>
      </div>
    </header>
  );
};
