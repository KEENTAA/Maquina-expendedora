import React, { createContext, useContext, useState, useEffect } from 'react';
import { UserRole, ModulePermission, MachineData, TransactionRecord } from '../types/platform';

interface PermissionsContextType {
  role: UserRole;
  setRole: (role: UserRole) => void;
  modules: ModulePermission[];
  toggleModuleForOperators: (moduleId: string) => void;
  isModuleAccessible: (moduleId: string) => boolean;
  machines: MachineData[];
  setMachines: React.Dispatch<React.SetStateAction<MachineData[]>>;
  transactions: TransactionRecord[];
  addTransaction: (tx: TransactionRecord) => void;
  restockMachine: (machineId: string) => void;
  simulateSale: (machineId: string, sku: string, method: 'CASH' | 'QR') => void;
  resetPermissions: () => void;
}

const DEFAULT_MODULES: ModulePermission[] = [
  {
    id: 'dashboard',
    name: 'Dashboard',
    number: '01',
    description: 'Resumen del negocio, ventas de hoy, máquinas activas, inventario y alertas.',
    enabledForOperators: true,
    category: 'core',
  },
  {
    id: 'vending',
    name: 'Vending y máquinas',
    number: '02',
    description: 'Máquinas conectadas, telemetría, sensores ópticos, MDB y estado operativo.',
    enabledForOperators: true,
    category: 'operations',
  },
  {
    id: 'crm',
    name: 'CRM',
    number: '03',
    description: 'Clientes identificados, frecuencia de compra, historial, segmentos y campañas.',
    enabledForOperators: true,
    category: 'growth',
  },
  {
    id: 'analytics',
    name: 'Analítica avanzada e IA',
    number: '04',
    description: 'Predicción de demanda, riesgo de caducidad, productos rentables y anomalías.',
    enabledForOperators: true,
    category: 'growth',
  },
  {
    id: 'finances',
    name: 'Finanzas y transacciones',
    number: '05',
    description: 'Pagos MDB fiduciarios, cobros QR, Proof of Service, conciliación y reembolsos.',
    enabledForOperators: true,
    category: 'operations',
  },
  {
    id: 'inventory',
    name: 'Inventario',
    number: '06',
    description: 'Stock por máquina, fechas de vencimiento, Dynamic Markdown y reposición.',
    enabledForOperators: true,
    category: 'operations',
  },
  {
    id: 'intelligence',
    name: 'GROG Intelligence',
    number: '07',
    description: 'Asistente IA explicable, recomendaciones de precios y alertas predictivas.',
    enabledForOperators: true,
    category: 'growth',
  },
  {
    id: 'ecosystem',
    name: 'Ecosistema',
    number: '08',
    description: 'Conexión a SimuPay, Gemelo Digital 3D en Unity, IoT Bridge y APIs.',
    enabledForOperators: true,
    category: 'infrastructure',
  },
];

const INITIAL_MACHINES: MachineData[] = [
  {
    id: 'VENDING-01',
    name: 'GROG Spiral Express',
    type: 'VENDING_SPIRAL',
    location: 'Edificio Central - Hall Principal',
    status: 'ONLINE',
    temperature: 19.5,
    targetTemperature: 20.0,
    signalDbm: -62,
    pingMs: 14,
    uptimeHours: 342,
    mdbBusStatus: 'CONNECTED',
    dropSensorLaser: 'READY',
    cashHopperBalance: 380.00,
    totalCapacity: 70,
    totalStock: 45,
    products: [
      {
        sku: 'SNK-01',
        name: 'Papas Fritas Gourmet',
        category: 'Snacks',
        currentStock: 12,
        maxStock: 20,
        basePrice: 5.00,
        currentPrice: 3.50,
        discountPercent: 30,
        daysToExpiry: 4,
        expiryStatus: 'CRITICAL',
        slot: 'A1-A2',
      },
      {
        sku: 'SNK-02',
        name: 'Chocolate Amargo 70%',
        category: 'Snacks',
        currentStock: 8,
        maxStock: 15,
        basePrice: 6.00,
        currentPrice: 6.00,
        discountPercent: 0,
        daysToExpiry: 18,
        expiryStatus: 'OPTIMAL',
        slot: 'B1-B2',
      },
      {
        sku: 'SNK-03',
        name: 'Galleta de Avena y Miel',
        category: 'Snacks',
        currentStock: 15,
        maxStock: 20,
        basePrice: 3.00,
        currentPrice: 3.00,
        discountPercent: 0,
        daysToExpiry: 25,
        expiryStatus: 'OPTIMAL',
        slot: 'C1-C2',
      },
      {
        sku: 'SNK-04',
        name: 'Mix de Frutos Secos',
        category: 'Snacks',
        currentStock: 10,
        maxStock: 15,
        basePrice: 7.00,
        currentPrice: 7.00,
        discountPercent: 0,
        daysToExpiry: 40,
        expiryStatus: 'OPTIMAL',
        slot: 'D1-D2',
      },
    ],
  },
  {
    id: 'COOLER-01',
    name: 'GROG Smart Cooler',
    type: 'COOLER_SMART',
    location: 'Área Deportiva & Gimnasio',
    status: 'ONLINE',
    temperature: 3.8,
    targetTemperature: 4.0,
    signalDbm: -58,
    pingMs: 12,
    uptimeHours: 512,
    mdbBusStatus: 'CONNECTED',
    dropSensorLaser: 'READY',
    cashHopperBalance: 520.00,
    totalCapacity: 80,
    totalStock: 56,
    products: [
      {
        sku: 'DRK-01',
        name: 'Bebida Isotónica 500ml',
        category: 'Bebidas',
        currentStock: 14,
        maxStock: 24,
        basePrice: 7.00,
        currentPrice: 5.60,
        discountPercent: 20,
        daysToExpiry: 6,
        expiryStatus: 'MODERATE',
        slot: 'R1-R2',
      },
      {
        sku: 'DRK-02',
        name: 'Agua Mineral Glaciar',
        category: 'Bebidas',
        currentStock: 22,
        maxStock: 25,
        basePrice: 4.00,
        currentPrice: 4.00,
        discountPercent: 0,
        daysToExpiry: 45,
        expiryStatus: 'OPTIMAL',
        slot: 'R3-R4',
      },
      {
        sku: 'DRK-03',
        name: 'Jugo Natural Naranja',
        category: 'Bebidas',
        currentStock: 8,
        maxStock: 15,
        basePrice: 6.00,
        currentPrice: 3.60,
        discountPercent: 40,
        daysToExpiry: 3,
        expiryStatus: 'CRITICAL',
        slot: 'R5',
      },
      {
        sku: 'DRK-04',
        name: 'Té Frío Limón Antioxidante',
        category: 'Bebidas',
        currentStock: 12,
        maxStock: 16,
        basePrice: 5.50,
        currentPrice: 5.50,
        discountPercent: 0,
        daysToExpiry: 30,
        expiryStatus: 'OPTIMAL',
        slot: 'R6',
      },
    ],
  },
  {
    id: 'COFFEE-01',
    name: 'GROG Barista Touch',
    type: 'COFFEE_BARISTA',
    location: 'Coworking & Oficinas Piso 3',
    status: 'ONLINE',
    temperature: 92.4,
    targetTemperature: 92.0,
    signalDbm: -51,
    pingMs: 9,
    uptimeHours: 720,
    mdbBusStatus: 'CONNECTED',
    dropSensorLaser: 'READY',
    cashHopperBalance: 740.00,
    totalCapacity: 80,
    totalStock: 44,
    products: [
      {
        sku: 'COF-01',
        name: 'Café Espresso Doble Grano',
        category: 'Cafetería',
        currentStock: 35,
        maxStock: 50,
        basePrice: 5.00,
        currentPrice: 5.00,
        discountPercent: 0,
        daysToExpiry: 30,
        expiryStatus: 'OPTIMAL',
        slot: 'Silo Granos A',
      },
      {
        sku: 'COF-02',
        name: 'Capuchino Cremoso Vainilla',
        category: 'Cafetería',
        currentStock: 9,
        maxStock: 30,
        basePrice: 7.50,
        currentPrice: 5.60,
        discountPercent: 25,
        daysToExpiry: 5,
        expiryStatus: 'MODERATE',
        slot: 'Silo Leche B',
      },
    ],
  },
];

const INITIAL_TXS: TransactionRecord[] = [
  {
    id: 'TX-9412',
    machineId: 'VENDING-01',
    machineName: 'GROG Spiral Express',
    productName: 'Papas Fritas Gourmet',
    sku: 'SNK-01',
    amount: 3.50,
    method: 'QR',
    level: 1,
    stage: 'COMPLETED',
    proofOfService: true,
    timestamp: 'Hace 2 min',
    customerName: 'Carlos Mendoza',
  },
  {
    id: 'TX-9411',
    machineId: 'VENDING-01',
    machineName: 'GROG Spiral Express',
    productName: 'Galleta de Avena',
    sku: 'SNK-03',
    amount: 3.00,
    method: 'CASH',
    level: 0,
    stage: 'COMPLETED',
    proofOfService: true,
    timestamp: 'Hace 7 min',
    customerName: 'Cliente Fiduciario MDB',
  },
  {
    id: 'TX-9410',
    machineId: 'COOLER-01',
    machineName: 'GROG Smart Cooler',
    productName: 'Bebida Isotónica 500ml',
    sku: 'DRK-01',
    amount: 5.60,
    method: 'QR',
    level: 2,
    stage: 'COMPLETED',
    proofOfService: true,
    timestamp: 'Hace 14 min',
    customerName: 'Sofia Vargas (Oferta App)',
  },
  {
    id: 'TX-9409',
    machineId: 'COFFEE-01',
    machineName: 'GROG Barista Touch',
    productName: 'Café Espresso Doble',
    sku: 'COF-01',
    amount: 5.00,
    method: 'CASH',
    level: 0,
    stage: 'COMPLETED',
    proofOfService: true,
    timestamp: 'Hace 22 min',
    customerName: 'Cliente Fiduciario MDB',
  },
  {
    id: 'TX-9408',
    machineId: 'COOLER-01',
    machineName: 'GROG Smart Cooler',
    productName: 'Jugo Natural Naranja',
    sku: 'DRK-03',
    amount: 3.60,
    method: 'QR',
    level: 2,
    stage: 'COMPLETED',
    proofOfService: true,
    timestamp: 'Hace 38 min',
    customerName: 'Rodrigo Paz (-40% Expiry)',
  },
];

const PermissionsContext = createContext<PermissionsContextType | undefined>(undefined);

export const PermissionsProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [role, setRole] = useState<UserRole>('ADMIN');
  const [modules, setModules] = useState<ModulePermission[]>(() => {
    const saved = localStorage.getItem('grog_modules_permissions');
    if (saved) {
      try {
        return JSON.parse(saved);
      } catch (e) {
        console.error('Error parsing stored permissions', e);
      }
    }
    return DEFAULT_MODULES;
  });

  const [machines, setMachines] = useState<MachineData[]>(INITIAL_MACHINES);
  const [transactions, setTransactions] = useState<TransactionRecord[]>(INITIAL_TXS);

  useEffect(() => {
    localStorage.setItem('grog_modules_permissions', JSON.stringify(modules));
  }, [modules]);

  const toggleModuleForOperators = (moduleId: string) => {
    setModules(prev =>
      prev.map(mod =>
        mod.id === moduleId
          ? { ...mod, enabledForOperators: !mod.enabledForOperators }
          : mod
      )
    );
  };

  const resetPermissions = () => {
    setModules(DEFAULT_MODULES);
    localStorage.removeItem('grog_modules_permissions');
  };

  const isModuleAccessible = (moduleId: string): boolean => {
    if (role === 'ADMIN') return true;
    const target = modules.find(m => m.id === moduleId);
    return target ? target.enabledForOperators : true;
  };

  const addTransaction = (tx: TransactionRecord) => {
    setTransactions(prev => [tx, ...prev]);
  };

  const restockMachine = (machineId: string) => {
    setMachines(prev =>
      prev.map(m => {
        if (m.id !== machineId) return m;
        const updatedProducts = m.products.map(p => ({
          ...p,
          currentStock: p.maxStock,
        }));
        const newTotalStock = updatedProducts.reduce((sum, p) => sum + p.currentStock, 0);
        return {
          ...m,
          products: updatedProducts,
          totalStock: newTotalStock,
        };
      })
    );
  };

  const simulateSale = (machineId: string, sku: string, method: 'CASH' | 'QR') => {
    setMachines(prev =>
      prev.map(m => {
        if (m.id !== machineId) return m;
        let salePrice = 0;
        let productName = '';
        const updatedProducts = m.products.map(p => {
          if (p.sku === sku && p.currentStock > 0) {
            salePrice = p.currentPrice;
            productName = p.name;
            return { ...p, currentStock: p.currentStock - 1 };
          }
          return p;
        });

        if (salePrice > 0) {
          const newTx: TransactionRecord = {
            id: `TX-${Math.floor(1000 + Math.random() * 9000)}`,
            machineId: m.id,
            machineName: m.name,
            productName: productName,
            sku: sku,
            amount: salePrice,
            method: method,
            level: method === 'CASH' ? 0 : 1,
            stage: 'COMPLETED',
            proofOfService: true,
            timestamp: 'Hace instantes',
            customerName: method === 'CASH' ? 'Cliente Fiduciario MDB' : 'Usuario Digital QR',
          };
          addTransaction(newTx);
        }

        const newTotalStock = updatedProducts.reduce((sum, p) => sum + p.currentStock, 0);
        const newHopper = method === 'CASH' ? m.cashHopperBalance + salePrice : m.cashHopperBalance;

        return {
          ...m,
          products: updatedProducts,
          totalStock: newTotalStock,
          cashHopperBalance: newHopper,
        };
      })
    );
  };

  return (
    <PermissionsContext.Provider
      value={{
        role,
        setRole,
        modules,
        toggleModuleForOperators,
        isModuleAccessible,
        machines,
        setMachines,
        transactions,
        addTransaction,
        restockMachine,
        simulateSale,
        resetPermissions,
      }}
    >
      {children}
    </PermissionsContext.Provider>
  );
};

export const usePermissions = (): PermissionsContextType => {
  const context = useContext(PermissionsContext);
  if (!context) {
    throw new Error('usePermissions must be used within a PermissionsProvider');
  }
  return context;
};
