export type UserRole = 'ADMIN' | 'OPERATOR';

export interface ModulePermission {
  id: string;
  name: string;
  number: string;
  description: string;
  enabledForOperators: boolean;
  category: 'core' | 'operations' | 'growth' | 'infrastructure';
}

export interface ProductStock {
  sku: string;
  name: string;
  category: string;
  currentStock: number;
  maxStock: number;
  basePrice: number;
  currentPrice: number;
  discountPercent: number;
  daysToExpiry: number;
  expiryStatus: 'OPTIMAL' | 'MODERATE' | 'CRITICAL';
  slot: string;
}

export interface MachineData {
  id: string;
  name: string;
  type: 'VENDING_SPIRAL' | 'COOLER_SMART' | 'COFFEE_BARISTA';
  location: string;
  status: 'ONLINE' | 'WARNING' | 'OFFLINE';
  temperature: number;
  targetTemperature: number;
  signalDbm: number;
  pingMs: number;
  uptimeHours: number;
  mdbBusStatus: 'CONNECTED' | 'DEGRADED' | 'DISCONNECTED';
  dropSensorLaser: 'READY' | 'TRIGGERED' | 'OBSTRUCTED';
  cashHopperBalance: number;
  totalCapacity: number;
  totalStock: number;
  products: ProductStock[];
}

export interface TransactionRecord {
  id: string;
  machineId: string;
  machineName: string;
  productName: string;
  sku: string;
  amount: number;
  method: 'CASH' | 'QR';
  level: 0 | 1 | 2;
  stage: 'INITIATED' | 'PAYMENT_CONFIRMED' | 'COMPLETED' | 'REFUNDED';
  proofOfService: boolean;
  timestamp: string;
  customerName?: string;
}

export interface CustomerProfile {
  id: string;
  name: string;
  email: string;
  phone: string;
  rfmSegment: 'CHAMPION' | 'LOYAL' | 'AT_RISK' | 'BARGAIN_HUNTER';
  totalSpent: number;
  purchaseCount: number;
  lastPurchaseDate: string;
  favoriteProduct: string;
  preferredMethod: 'QR' | 'CASH';
  discountSavings: number;
}
