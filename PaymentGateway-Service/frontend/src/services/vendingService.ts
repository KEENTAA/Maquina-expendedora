export interface BackendMachine {
  id: string;
  name: string;
  owner_email: string;
  status: string;
  lat: number;
  lng: number;
  machine_type: string;
  environment: string;
  protocol: string;
  brand_model: string;
  is_claimed: boolean;
}

export interface BackendInventoryItem {
  inventory_id: string;
  slot: string;
  stock: number;
  capacity: number;
  product_sku: string;
  product_name: string;
  price: number;
  is_enabled: boolean;
  slot_type: string;
  display_order: number;
  image_base64: string | null;
}

export interface ProvisioningStatus {
  is_claimed: boolean;
  owner_email: string;
  has_active_token: boolean;
  seconds_left: number;
  name: string;
}

export interface FactoryResetResponse {
  pairing_token: string;
  pairing_code: string;
  expires_in: number;
  qr_image?: string;
  message: string;
}

const getApiBase = () => {
  return '';
};

export const VendingServiceApi = {
  async getMachines(): Promise<BackendMachine[]> {
    try {
      const res = await fetch(`${getApiBase()}/api/v1/machines`, {
        headers: { 'ngrok-skip-browser-warning': '1' }
      });
      if (!res.ok) throw new Error(`HTTP error ${res.status}`);
      const data = await res.json();
      return data.machines || [];
    } catch (e) {
      console.warn('[VendingServiceApi] Error fetching machines, using fallback:', e);
      return [];
    }
  },

  async getMachineInventory(machineId: string): Promise<BackendInventoryItem[]> {
    try {
      const res = await fetch(`${getApiBase()}/api/v1/machines/${machineId}/inventory`, {
        headers: { 'ngrok-skip-browser-warning': '1' }
      });
      if (!res.ok) throw new Error(`HTTP error ${res.status}`);
      const data = await res.json();
      return data.items || [];
    } catch (e) {
      console.warn(`[VendingServiceApi] Error fetching inventory for ${machineId}:`, e);
      return [];
    }
  },

  async getProvisioningStatus(machineId: string): Promise<ProvisioningStatus | null> {
    try {
      const res = await fetch(`${getApiBase()}/api/v1/machines/provisioning/status/${machineId}`, {
        headers: { 'ngrok-skip-browser-warning': '1' }
      });
      if (!res.ok) return null;
      return await res.json();
    } catch (e) {
      console.warn(`[VendingServiceApi] Error getting provisioning status for ${machineId}:`, e);
      return null;
    }
  },

  async factoryReset(machineId: string): Promise<FactoryResetResponse | null> {
    try {
      const res = await fetch(`${getApiBase()}/api/v1/machines/${machineId}/factory-reset`, {
        method: 'POST',
        headers: { 'ngrok-skip-browser-warning': '1' }
      });
      if (!res.ok) throw new Error(`HTTP error ${res.status}`);
      return await res.json();
    } catch (e) {
      console.error(`[VendingServiceApi] Factory reset failed for ${machineId}:`, e);
      return null;
    }
  },

  async updateSlotPrice(machineId: string, slot: string, price: number): Promise<boolean> {
    try {
      const res = await fetch(`${getApiBase()}/api/v1/machines/${machineId}/inventory/${slot}/price?price=${price}`, {
        method: 'PATCH',
        headers: { 'ngrok-skip-browser-warning': '1' }
      });
      return res.ok;
    } catch (e) {
      console.error(`[VendingServiceApi] Error updating price for slot ${slot}:`, e);
      return false;
    }
  },

  async toggleSlotStatus(machineId: string, slot: string, isEnabled: boolean): Promise<boolean> {
    try {
      const res = await fetch(`${getApiBase()}/api/v1/machines/${machineId}/inventory/${slot}/status`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': '1'
        },
        body: JSON.stringify({ is_enabled: isEnabled })
      });
      return res.ok;
    } catch (e) {
      console.error(`[VendingServiceApi] Error toggling status for slot ${slot}:`, e);
      return false;
    }
  }
};

export default VendingServiceApi;
