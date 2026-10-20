import React, { useState } from 'react';
import {
  PermissionsProvider,
  usePermissions
} from './context/PermissionsContext';
import { GrogSidebar } from './components/GrogSidebar';
import { GrogHeader } from './components/GrogHeader';
import { AdminControlModal } from './components/AdminControlModal';

// Views
import { DashboardView } from './views/DashboardView';
import { VendingView } from './views/VendingView';
import { CrmView } from './views/CrmView';
import { AnalyticsView } from './views/AnalyticsView';
import { FinancesView } from './views/FinancesView';
import { InventoryView } from './views/InventoryView';
import { IntelligenceView } from './views/IntelligenceView';
import { EcosystemView } from './views/EcosystemView';

import { Lock, ArrowLeft, ShieldAlert } from 'lucide-react';

const PlatformContent: React.FC = () => {
  const [activeModule, setActiveModule] = useState<string>(() => {
    if (typeof window !== 'undefined') {
      const p = new URLSearchParams(window.location.search);
      const mod = p.get('module');
      if (mod) return mod;
    }
    return 'dashboard';
  });
  const [isAdminModalOpen, setIsAdminModalOpen] = useState<boolean>(false);
  const { isModuleAccessible, modules, role, setRole } = usePermissions();

  const currentModObj = modules.find(m => m.id === activeModule);
  const currentModuleName = currentModObj?.name || 'Dashboard';
  const isAccessible = isModuleAccessible(activeModule);

  const renderActiveView = () => {
    if (!isAccessible) {
      return (
        <div className="min-h-[60vh] flex flex-col items-center justify-center text-center p-8 bg-white rounded-3xl border border-slate-200 shadow-sm animate-fadeIn">
          <div className="w-16 h-16 rounded-2xl bg-amber-50 border border-amber-200 text-amber-600 flex items-center justify-center mb-4">
            <Lock className="w-8 h-8" />
          </div>
          <h2 className="text-xl font-extrabold text-slate-900 tracking-tight">
            Módulo Desactivado por el Administrador
          </h2>
          <p className="text-xs text-slate-500 max-w-md mt-1 leading-relaxed">
            La sección <strong>"{currentModuleName}"</strong> no está habilitada actualmente para usuarios con rol de Operador. Si eres el administrador, puedes reactivarla desde el panel de control.
          </p>

          <div className="flex items-center gap-3 mt-6">
            <button
              onClick={() => setActiveModule('dashboard')}
              className="px-4 py-2 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-bold flex items-center gap-2 transition-colors"
            >
              <ArrowLeft className="w-4 h-4" />
              <span>Volver al Dashboard</span>
            </button>

            <button
              onClick={() => {
                setRole('ADMIN');
                setIsAdminModalOpen(true);
              }}
              className="px-4 py-2 rounded-xl bg-[#4F46E5] hover:bg-[#4338CA] text-white text-xs font-bold flex items-center gap-2 transition-colors shadow-sm"
            >
              <ShieldAlert className="w-4 h-4" />
              <span>Acceder como Administrador</span>
            </button>
          </div>
        </div>
      );
    }

    switch (activeModule) {
      case 'dashboard':
        return <DashboardView />;
      case 'vending':
        return <VendingView />;
      case 'crm':
        return <CrmView />;
      case 'analytics':
        return <AnalyticsView />;
      case 'finances':
        return <FinancesView />;
      case 'inventory':
        return <InventoryView />;
      case 'intelligence':
        return <IntelligenceView />;
      case 'ecosystem':
        return <EcosystemView />;
      default:
        return <DashboardView />;
    }
  };

  return (
    <div className="flex min-h-screen bg-[#F6F7FB] text-slate-900 font-sans selection:bg-indigo-500 selection:text-white">
      {/* Fixed Sidebar */}
      <GrogSidebar
        activeModule={activeModule}
        onSelectModule={id => {
          setActiveModule(id);
          if (typeof window !== 'undefined') {
            const url = new URL(window.location.href);
            url.searchParams.set('module', id);
            window.history.replaceState({}, '', url.toString());
          }
        }}
        onOpenAdminModal={() => setIsAdminModalOpen(true)}
      />

      {/* Main Content Area */}
      <div className="flex-1 flex flex-col min-w-0">
        <GrogHeader
          activeModuleName={currentModuleName}
          onOpenAdminModal={() => setIsAdminModalOpen(true)}
        />

        <main className="flex-1 p-6 md:p-8 max-w-7xl w-full mx-auto">
          {renderActiveView()}
        </main>
      </div>

      {/* Admin Permissions Modal */}
      <AdminControlModal
        isOpen={isAdminModalOpen}
        onClose={() => setIsAdminModalOpen(false)}
      />
    </div>
  );
};

export const GrogPlatformMain: React.FC = () => {
  return (
    <PermissionsProvider>
      <PlatformContent />
    </PermissionsProvider>
  );
};

export default GrogPlatformMain;
