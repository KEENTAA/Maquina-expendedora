import React from 'react';
import {
  X,
  ShieldCheck,
  Lock,
  Unlock,
  AlertCircle,
  RotateCcw,
  CheckCircle2,
  Sliders
} from 'lucide-react';
import { usePermissions } from '../context/PermissionsContext';

interface AdminControlModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const AdminControlModal: React.FC<AdminControlModalProps> = ({ isOpen, onClose }) => {
  const { modules, toggleModuleForOperators, resetPermissions, role, setRole } = usePermissions();

  if (!isOpen) return null;

  const enabledCount = modules.filter(m => m.enabledForOperators).length;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-900/60 backdrop-blur-xs select-none animate-fadeIn">
      <div className="bg-white rounded-2xl shadow-2xl border border-slate-200 w-full max-w-2xl max-h-[90vh] flex flex-col overflow-hidden">
        {/* Modal Header */}
        <div className="px-6 py-5 bg-gradient-to-r from-slate-900 to-[#1E1B4B] text-white flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="p-2 rounded-xl bg-indigo-500/20 text-indigo-300 border border-indigo-400/30">
              <ShieldCheck className="w-6 h-6" />
            </div>
            <div>
              <h2 className="text-base font-extrabold tracking-tight">
                Panel de Administración & Control de Secciones
              </h2>
              <p className="text-xs text-indigo-200/80 mt-0.5">
                Configura la visibilidad y permisos de acceso para usuarios con rol Operador.
              </p>
            </div>
          </div>

          <button
            onClick={onClose}
            className="p-1.5 rounded-lg text-slate-400 hover:text-white hover:bg-white/10 transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Status Banner */}
        <div className="px-6 py-3 bg-indigo-50/70 border-b border-indigo-100 flex items-center justify-between text-xs">
          <div className="flex items-center gap-2 text-indigo-900 font-medium">
            <AlertCircle className="w-4 h-4 text-indigo-600 shrink-0" />
            <span>
              Actualmente <strong className="font-bold text-indigo-700">{enabledCount} de 8</strong> módulos están habilitados para operadores.
            </span>
          </div>

          <button
            onClick={resetPermissions}
            className="flex items-center gap-1.5 text-xs font-bold text-indigo-600 hover:text-indigo-800 hover:underline"
          >
            <RotateCcw className="w-3.5 h-3.5" />
            <span>Restablecer todo</span>
          </button>
        </div>

        {/* Modules Toggles List */}
        <div className="p-6 overflow-y-auto space-y-3 flex-1">
          {modules.map(mod => {
            const isEnabled = mod.enabledForOperators;

            return (
              <div
                key={mod.id}
                className={`p-4 rounded-xl border transition-all flex items-center justify-between gap-4 ${
                  isEnabled
                    ? 'border-slate-200 bg-white hover:border-indigo-200'
                    : 'border-amber-200/80 bg-amber-50/40'
                }`}
              >
                <div className="flex items-start gap-3">
                  <span className="font-mono text-xs font-bold text-slate-400 px-2 py-1 rounded bg-slate-100 mt-0.5">
                    {mod.number}
                  </span>
                  <div>
                    <div className="flex items-center gap-2">
                      <h3 className="font-bold text-slate-900 text-sm">{mod.name}</h3>
                      <span
                        className={`text-[10px] font-bold px-2 py-0.5 rounded-full flex items-center gap-1 ${
                          isEnabled
                            ? 'bg-emerald-100 text-emerald-800'
                            : 'bg-amber-100 text-amber-800'
                        }`}
                      >
                        {isEnabled ? (
                          <>
                            <Unlock className="w-3 h-3" />
                            <span>Habilitado</span>
                          </>
                        ) : (
                          <>
                            <Lock className="w-3 h-3" />
                            <span>Desactivado</span>
                          </>
                        )}
                      </span>
                    </div>
                    <p className="text-xs text-slate-500 mt-1">{mod.description}</p>
                  </div>
                </div>

                {/* Toggle Switch */}
                <div className="shrink-0 flex items-center">
                  <button
                    onClick={() => toggleModuleForOperators(mod.id)}
                    className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors focus:outline-hidden ${
                      isEnabled ? 'bg-[#4F46E5]' : 'bg-slate-300'
                    }`}
                  >
                    <span
                      className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform shadow-xs ${
                        isEnabled ? 'translate-x-6' : 'translate-x-1'
                      }`}
                    />
                  </button>
                </div>
              </div>
            );
          })}
        </div>

        {/* Footer info & test role */}
        <div className="px-6 py-4 bg-slate-50 border-t border-slate-200 flex flex-col sm:flex-row items-center justify-between gap-3 text-xs">
          <p className="text-slate-500 text-center sm:text-left">
            Los cambios se guardan automáticamente y afectan la sesión en tiempo real.
          </p>

          <div className="flex items-center gap-3">
            <button
              onClick={() => {
                setRole(role === 'ADMIN' ? 'OPERATOR' : 'ADMIN');
              }}
              className="px-3.5 py-1.5 rounded-xl border border-slate-300 bg-white hover:bg-slate-50 text-slate-700 font-bold flex items-center gap-1.5 transition-colors"
            >
              <Sliders className="w-3.5 h-3.5 text-indigo-600" />
              <span>Probar como {role === 'ADMIN' ? 'Operador' : 'Admin'}</span>
            </button>

            <button
              onClick={onClose}
              className="px-4 py-1.5 rounded-xl bg-[#4F46E5] hover:bg-[#4338CA] text-white font-bold transition-colors shadow-sm"
            >
              Listo
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
