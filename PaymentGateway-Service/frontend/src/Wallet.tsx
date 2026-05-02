import React, { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  Wallet as WalletIcon,
  Plus,
  History,
  LogOut,
  CreditCard,
  ShieldCheck,
  TrendingUp,
  QrCode,
  Download,
  Send,
  Camera,
  Upload,
  X,
} from 'lucide-react';
import { API_BASE_URL } from './config';

type WalletData = {
  id: string;
  user_id: string;
  balance: number;
};

type TransactionData = {
  id: string;
  amount: number;
  status: string;
  method?: string;
  type: string;
  created_at: string;
};

export default function Wallet() {
  const [wallet, setWallet] = useState<WalletData | null>(null);
  const [transactions, setTransactions] = useState<TransactionData[]>([]);
  const [loading, setLoading] = useState(true);
  const [recharging, setRecharging] = useState(false);
  const [payingQr, setPayingQr] = useState(false);
  const [amount, setAmount] = useState('');
  const [cardNumber, setCardNumber] = useState('');
  const [payAmount, setPayAmount] = useState('');
  const [chargeAmount, setChargeAmount] = useState('');
  const [chargeNote, setChargeNote] = useState('');
  const [qrDataToPay, setQrDataToPay] = useState('');
  const [myQrImage, setMyQrImage] = useState('');
  const [myQrData, setMyQrData] = useState('');
  const [chargeQrImage, setChargeQrImage] = useState('');
  const [chargeQrData, setChargeQrData] = useState('');
  const [creatingChargeQr, setCreatingChargeQr] = useState(false);
  const [parsedQrInfo, setParsedQrInfo] = useState<{ recipientName?: string; amount?: number; note?: string }>({});
  const [scannerOpen, setScannerOpen] = useState(false);
  const [scanError, setScanError] = useState('');
  const navigate = useNavigate();
  const token = localStorage.getItem('simupay_token');
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const fileInputRef = useRef<HTMLInputElement | null>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const scanLoopRef = useRef<number | null>(null);

  useEffect(() => {
    if (!token) {
      navigate('/login');
      return;
    }
    fetchData();
  }, [token]);

  useEffect(() => {
    return () => {
      stopScanner();
    };
  }, []);

  const fetchData = async () => {
    setLoading(true);
    await Promise.all([fetchWallet(), fetchTransactions(), fetchMyQr()]);
    setLoading(false);
  };

  const fetchWallet = async () => {
    try {
      const res = await fetch(`${API_BASE_URL}/wallet`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (!res.ok) throw new Error('Unauthorized');
      const data = await res.json();
      setWallet(data);
    } catch {
      localStorage.removeItem('simupay_token');
      navigate('/login');
    }
  };

  const fetchTransactions = async () => {
    try {
      const res = await fetch(`${API_BASE_URL}/transactions`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (res.ok) {
        const data = await res.json();
        setTransactions(data);
      }
    } catch (err) {
      console.error('Error fetching transactions:', err);
    }
  };

  const fetchMyQr = async () => {
    try {
      const res = await fetch(`${API_BASE_URL}/wallet/qr`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (res.ok) {
        const data = await res.json();
        setMyQrImage(data.qr_image);
        setMyQrData(data.qr_data);
      }
    } catch (err) {
      console.error('Error fetching my QR:', err);
    }
  };

  const handleRecharge = async (e: React.FormEvent) => {
    e.preventDefault();
    setRecharging(true);
    try {
      const res = await fetch(`${API_BASE_URL}/wallet/recharge`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({ amount: parseFloat(amount), card_number: cardNumber }),
      });
      if (res.ok) {
        setAmount('');
        setCardNumber('');
        await fetchData();
        alert('Recarga exitosa');
      }
    } catch {
      alert('Error en recarga');
    } finally {
      setRecharging(false);
    }
  };

  const handlePayByQr = async (e: React.FormEvent) => {
    e.preventDefault();
    setPayingQr(true);
    try {
      const res = await fetch(`${API_BASE_URL}/wallet/pay-qr`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          qr_data: qrDataToPay,
          amount: payAmount ? parseFloat(payAmount) : null,
        }),
      });
      const data = await res.json();
      if (!res.ok) {
        throw new Error(data.detail || 'No se pudo completar el pago por QR');
      }
      setPayAmount('');
      setQrDataToPay('');
      setParsedQrInfo({});
      await fetchData();
      alert(`Pago QR completado a ${data.recipient_name}`);
    } catch (err: any) {
      alert(err.message || 'Error en pago por QR');
    } finally {
      setPayingQr(false);
    }
  };

  const stopScanner = () => {
    if (scanLoopRef.current) {
      cancelAnimationFrame(scanLoopRef.current);
      scanLoopRef.current = null;
    }
    if (streamRef.current) {
      streamRef.current.getTracks().forEach((track) => track.stop());
      streamRef.current = null;
    }
    setScannerOpen(false);
  };

  const startScanner = async () => {
    try {
      setScanError('');
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: { ideal: 'environment' } },
      });
      streamRef.current = stream;
      setScannerOpen(true);

      setTimeout(() => {
        if (!videoRef.current) return;
        videoRef.current.srcObject = stream;
        videoRef.current.play();
        runBarcodeScanLoop();
      }, 50);
    } catch {
      setScanError('No se pudo acceder a la cámara. Revisa permisos del navegador.');
    }
  };

  const runBarcodeScanLoop = () => {
    const BarcodeDetectorCtor = (window as any).BarcodeDetector;
    if (!BarcodeDetectorCtor) {
      setScanError('Tu navegador no soporta escaneo en vivo. Pega el contenido del QR manualmente.');
      return;
    }
    const detector = new BarcodeDetectorCtor({ formats: ['qr_code'] });

    const tick = async () => {
      if (!videoRef.current || !streamRef.current) return;
      try {
        const barcodes = await detector.detect(videoRef.current);
        if (barcodes.length > 0 && barcodes[0].rawValue) {
          applyQrContent(barcodes[0].rawValue);
          stopScanner();
          return;
        }
      } catch {
        setScanError('No se pudo leer el QR. Intenta nuevamente.');
        stopScanner();
        return;
      }
      scanLoopRef.current = requestAnimationFrame(tick);
    };

    scanLoopRef.current = requestAnimationFrame(tick);
  };

  const applyQrContent = (rawContent: string) => {
    setQrDataToPay(rawContent);
    const trimmed = rawContent.trim();
    if (!trimmed.startsWith('simupay://pay')) {
      setParsedQrInfo({});
      return;
    }

    try {
      const parsed = new URL(trimmed);
      const amount = parsed.searchParams.get('amount');
      const recipientName = parsed.searchParams.get('name');
      const note = parsed.searchParams.get('note');
      const parsedAmount = amount ? parseFloat(amount) : undefined;

      if (typeof parsedAmount === 'number' && !Number.isNaN(parsedAmount)) {
        setPayAmount(parsedAmount.toFixed(2));
      }

      setParsedQrInfo({
        recipientName: recipientName || undefined,
        amount: typeof parsedAmount === 'number' && !Number.isNaN(parsedAmount) ? parsedAmount : undefined,
        note: note || undefined,
      });
    } catch {
      setParsedQrInfo({});
    }
  };

  const handleQrUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    try {
      setScanError('');
      const BarcodeDetectorCtor = (window as any).BarcodeDetector;
      if (!BarcodeDetectorCtor) {
        throw new Error('Tu navegador no soporta lectura QR desde imagen. Usa escaneo en cámara o pega el contenido.');
      }

      const detector = new BarcodeDetectorCtor({ formats: ['qr_code'] });
      const bitmap = await createImageBitmap(file);
      const barcodes = await detector.detect(bitmap);
      bitmap.close();

      if (!barcodes.length || !barcodes[0].rawValue) {
        throw new Error('No se detectó un QR válido en la imagen seleccionada.');
      }

      applyQrContent(barcodes[0].rawValue);
    } catch (err: any) {
      setScanError(err.message || 'No se pudo leer la imagen QR.');
    } finally {
      e.target.value = '';
    }
  };

  const handleCreateChargeQr = async (e: React.FormEvent) => {
    e.preventDefault();
    setCreatingChargeQr(true);
    try {
      const res = await fetch(`${API_BASE_URL}/wallet/qr-request`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,
        },
        body: JSON.stringify({
          amount: parseFloat(chargeAmount),
          note: chargeNote || null,
        }),
      });
      const data = await res.json();
      if (!res.ok) {
        throw new Error(data.detail || 'No se pudo generar el QR de cobro');
      }
      setChargeQrImage(data.qr_image);
      setChargeQrData(data.qr_data);
      alert('QR de cobro generado correctamente');
    } catch (err: any) {
      alert(err.message || 'Error al generar QR de cobro');
    } finally {
      setCreatingChargeQr(false);
    }
  };

  const handleLogout = () => {
    localStorage.removeItem('simupay_token');
    navigate('/login');
  };

  if (loading) return <div className="flex items-center justify-center min-h-screen">Cargando...</div>;

  return (
    <div className="min-h-screen bg-slate-50 font-sans">
      <header className="bg-white border-b border-slate-200 sticky top-0 z-10">
        <div className="max-w-5xl mx-auto px-6 py-4 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 bg-indigo-600 rounded-lg flex items-center justify-center">
              <ShieldCheck className="w-5 h-5 text-white" />
            </div>
            <span className="font-bold text-xl text-slate-900">SimuPay</span>
          </div>
          <button onClick={handleLogout} className="text-slate-500 hover:text-red-600 transition-colors p-2 rounded-lg hover:bg-red-50">
            <LogOut className="w-5 h-5" />
          </button>
        </div>
      </header>

      <main className="max-w-5xl mx-auto px-6 py-10">
        <div className="grid md:grid-cols-3 gap-8">
          <div className="md:col-span-2 space-y-8">
            <div className="bg-slate-900 rounded-[32px] p-10 text-white relative overflow-hidden shadow-2xl shadow-indigo-200">
              <div className="absolute top-0 right-0 w-64 h-64 bg-indigo-500/10 rounded-full -mr-20 -mt-20 blur-3xl"></div>
              <div className="relative z-10">
                <div className="flex items-center gap-2 text-indigo-300 mb-2 font-bold uppercase tracking-widest text-xs">
                  <WalletIcon className="w-4 h-4" /> Saldo disponible
                </div>
                <div className="text-6xl font-black mb-8">
                  <span className="text-3xl font-medium text-slate-400 mr-2">Bs.</span>
                  {(wallet?.balance || 0).toLocaleString(undefined, { minimumFractionDigits: 2 })}
                </div>
                <div className="flex gap-4">
                  <div className="bg-white/10 backdrop-blur-md px-4 py-2 rounded-xl text-sm font-medium border border-white/10">
                    Visa •••• 4242
                  </div>
                  <div className="bg-white/10 backdrop-blur-md px-4 py-2 rounded-xl text-sm font-medium border border-white/10">
                    ID: {wallet?.user_id?.substring(0, 8)}
                  </div>
                </div>
              </div>
            </div>

            <div className="bg-white rounded-3xl p-8 border border-slate-100 shadow-sm">
              <div className="flex items-center justify-between mb-6">
                <h3 className="text-xl font-bold text-slate-900 flex items-center gap-2">
                  <History className="w-5 h-5 text-indigo-600" /> Actividad Reciente
                </h3>
              </div>
              <div className="space-y-4 max-h-[400px] overflow-y-auto pr-2">
                {transactions.length > 0 ? (
                  transactions.map((tx) => {
                    const incoming = tx.type === 'recharge' || tx.type === 'income';
                    return (
                      <div key={tx.id} className="flex items-center justify-between py-4 border-b border-slate-50 last:border-0 hover:bg-slate-50/50 transition-colors px-2 rounded-xl">
                        <div className="flex items-center gap-4">
                          <div className={`w-12 h-12 rounded-2xl flex items-center justify-center ${incoming ? 'bg-green-50 text-green-500' : 'bg-slate-50 text-slate-400'}`}>
                            {incoming ? <TrendingUp className="w-6 h-6" /> : <CreditCard className="w-6 h-6" />}
                          </div>
                          <div>
                            <div className="font-bold text-slate-900">
                              {tx.type === 'recharge'
                                ? 'Recarga de Saldo'
                                : tx.type === 'income'
                                ? 'Ingreso por QR'
                                : `Pago: ${tx.method === 'wallet' ? 'Billetera' : tx.method === 'qr' || tx.method === 'qr-account' ? 'QR' : 'Tarjeta'}`}
                            </div>
                            <div className="text-[10px] font-bold text-slate-400 uppercase tracking-widest mt-0.5">
                              {new Date(tx.created_at).toLocaleString()} • {tx.status.toUpperCase()}
                            </div>
                          </div>
                        </div>
                        <div className={`font-black ${incoming ? 'text-green-600' : 'text-slate-900'}`}>
                          {incoming ? '+' : '-'} Bs. {tx.amount.toFixed(2)}
                        </div>
                      </div>
                    );
                  })
                ) : (
                  <div className="py-10 text-center text-slate-400 font-bold uppercase text-xs tracking-widest">
                    No hay transacciones registradas todavía
                  </div>
                )}
              </div>
            </div>
          </div>

          <div className="space-y-6">
            <div className="bg-white rounded-3xl p-8 border border-slate-100 shadow-sm">
              <h3 className="text-xl font-bold text-slate-900 mb-6 flex items-center gap-2">
                <Plus className="w-5 h-5 text-indigo-600" /> Recargar Saldo
              </h3>
              <form onSubmit={handleRecharge} className="space-y-4">
                <div>
                  <label className="block text-xs font-bold text-slate-400 uppercase tracking-widest mb-2">Monto (Bs.)</label>
                  <input
                    type="number"
                    required
                    min="1"
                    step="0.01"
                    placeholder="0.00"
                    className="w-full px-4 py-3 bg-slate-50 border-none rounded-xl focus:ring-2 focus:ring-indigo-500 font-bold text-lg"
                    value={amount}
                    onChange={(e) => setAmount(e.target.value)}
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-400 uppercase tracking-widest mb-2">Tarjeta de Crédito</label>
                  <input
                    type="text"
                    required
                    placeholder="4242 4242 4242 4242"
                    className="w-full px-4 py-3 bg-slate-50 border-none rounded-xl focus:ring-2 focus:ring-indigo-500 font-medium"
                    value={cardNumber}
                    onChange={(e) => setCardNumber(e.target.value)}
                  />
                </div>
                <button
                  disabled={recharging}
                  type="submit"
                  className="w-full py-4 bg-indigo-600 hover:bg-indigo-700 text-white rounded-xl font-bold shadow-lg shadow-indigo-100 transition-all active:scale-95 disabled:opacity-70"
                >
                  {recharging ? 'Procesando...' : 'Recargar Ahora'}
                </button>
              </form>
            </div>

            <div className="bg-white rounded-3xl p-8 border border-slate-100 shadow-sm text-center">
              <h3 className="text-xl font-bold text-slate-900 mb-6 flex items-center justify-center gap-2">
                <QrCode className="w-5 h-5 text-indigo-600" /> Mi QR SimuPay
              </h3>
              <div className="w-48 h-48 bg-slate-50 rounded-2xl mx-auto mb-4 flex items-center justify-center border border-slate-100 overflow-hidden">
                {myQrImage ? (
                  <img src={myQrImage} alt="User QR" className="w-full h-full object-contain p-2" />
                ) : (
                  <span className="text-xs text-slate-400">Cargando QR...</span>
                )}
              </div>
              <p className="text-[11px] font-medium text-slate-400 mb-4 break-all">{myQrData}</p>
              <button
                onClick={() => {
                  if (!myQrImage) return;
                  const link = document.createElement('a');
                  link.href = myQrImage;
                  link.download = 'simupay-mi-qr.png';
                  document.body.appendChild(link);
                  link.click();
                  document.body.removeChild(link);
                }}
                className="w-full py-3 bg-slate-50 hover:bg-slate-100 text-slate-600 rounded-xl font-bold text-xs flex items-center justify-center gap-2 transition-colors"
              >
                <Download className="w-4 h-4" /> Guardar QR
              </button>
            </div>

            <div className="bg-white rounded-3xl p-8 border border-slate-100 shadow-sm">
              <h3 className="text-xl font-bold text-slate-900 mb-4 flex items-center gap-2">
                <QrCode className="w-5 h-5 text-indigo-600" /> Crear QR de cobro
              </h3>
              <form onSubmit={handleCreateChargeQr} className="space-y-4">
                <input
                  type="number"
                  required
                  min="0.01"
                  step="0.01"
                  placeholder="Monto a cobrar (Bs.)"
                  className="w-full px-4 py-3 bg-slate-50 border-none rounded-xl focus:ring-2 focus:ring-indigo-500 font-medium"
                  value={chargeAmount}
                  onChange={(e) => setChargeAmount(e.target.value)}
                />
                <input
                  type="text"
                  placeholder="Detalle (opcional)"
                  className="w-full px-4 py-3 bg-slate-50 border-none rounded-xl focus:ring-2 focus:ring-indigo-500 font-medium"
                  value={chargeNote}
                  onChange={(e) => setChargeNote(e.target.value)}
                />
                <button
                  disabled={creatingChargeQr}
                  type="submit"
                  className="w-full py-3 bg-indigo-600 hover:bg-indigo-700 text-white rounded-xl font-bold transition-all disabled:opacity-70"
                >
                  {creatingChargeQr ? 'Generando...' : 'Generar QR de cobro'}
                </button>
              </form>
              {chargeQrImage && (
                <div className="mt-5 text-center">
                  <div className="w-40 h-40 bg-slate-50 rounded-2xl mx-auto mb-3 flex items-center justify-center border border-slate-100 overflow-hidden">
                    <img src={chargeQrImage} alt="QR de cobro" className="w-full h-full object-contain p-2" />
                  </div>
                  <p className="text-[11px] font-medium text-slate-400 mb-3 break-all">{chargeQrData}</p>
                  <button
                    onClick={() => {
                      const link = document.createElement('a');
                      link.href = chargeQrImage;
                      link.download = 'simupay-cobro-qr.png';
                      document.body.appendChild(link);
                      link.click();
                      document.body.removeChild(link);
                    }}
                    className="w-full py-3 bg-slate-50 hover:bg-slate-100 text-slate-600 rounded-xl font-bold text-xs flex items-center justify-center gap-2 transition-colors"
                  >
                    <Download className="w-4 h-4" /> Guardar QR de cobro
                  </button>
                </div>
              )}
            </div>

            <div className="bg-white rounded-3xl p-8 border border-slate-100 shadow-sm">
              <h3 className="text-xl font-bold text-slate-900 mb-4 flex items-center gap-2">
                <Send className="w-5 h-5 text-indigo-600" /> Pagar escaneando QR
              </h3>
              <form onSubmit={handlePayByQr} className="space-y-4">
                <button
                  type="button"
                  onClick={startScanner}
                  className="w-full py-3 bg-indigo-50 hover:bg-indigo-100 text-indigo-700 rounded-xl font-bold text-sm flex items-center justify-center gap-2 transition-colors"
                >
                  <Camera className="w-4 h-4" /> Escanear con cámara
                </button>
                <input
                  ref={fileInputRef}
                  type="file"
                  accept="image/*"
                  className="hidden"
                  onChange={handleQrUpload}
                />
                <button
                  type="button"
                  onClick={() => fileInputRef.current?.click()}
                  className="w-full py-3 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-xl font-bold text-sm flex items-center justify-center gap-2 transition-colors"
                >
                  <Upload className="w-4 h-4" /> Subir imagen QR
                </button>
                <textarea
                  required
                  placeholder="Pega aquí el contenido del QR (simupay://user/... o simupay://pay?...)"
                  className="w-full p-3 bg-slate-50 border-none rounded-xl focus:ring-2 focus:ring-indigo-500 text-sm font-medium min-h-[86px]"
                  value={qrDataToPay}
                  onChange={(e) => applyQrContent(e.target.value)}
                />
                {(parsedQrInfo.recipientName || parsedQrInfo.amount || parsedQrInfo.note) && (
                  <div className="bg-indigo-50 text-indigo-700 rounded-xl p-3 text-xs font-semibold space-y-1">
                    {parsedQrInfo.recipientName && <p>A nombre de: {parsedQrInfo.recipientName}</p>}
                    {parsedQrInfo.amount && <p>Monto del QR: Bs. {parsedQrInfo.amount.toFixed(2)}</p>}
                    {parsedQrInfo.note && <p>Detalle: {parsedQrInfo.note}</p>}
                  </div>
                )}
                <input
                  type="number"
                  min="0.01"
                  step="0.01"
                  placeholder="Monto a pagar (si el QR ya trae monto, se autocompleta)"
                  className="w-full px-4 py-3 bg-slate-50 border-none rounded-xl focus:ring-2 focus:ring-indigo-500 font-medium"
                  value={payAmount}
                  onChange={(e) => setPayAmount(e.target.value)}
                />
                <button
                  disabled={payingQr}
                  type="submit"
                  className="w-full py-4 bg-indigo-600 hover:bg-indigo-700 text-white rounded-xl font-bold shadow-lg shadow-indigo-100 transition-all active:scale-95 disabled:opacity-70"
                >
                  {payingQr ? 'Procesando...' : 'Pagar con QR'}
                </button>
              </form>
            </div>
          </div>
        </div>
      </main>

      {scannerOpen && (
        <div className="fixed inset-0 z-50 bg-black/80 flex items-center justify-center p-4">
          <div className="bg-white rounded-2xl p-4 w-full max-w-sm">
            <div className="flex items-center justify-between mb-3">
              <h4 className="font-bold text-slate-900">Escanear QR</h4>
              <button onClick={stopScanner} className="p-2 rounded-lg hover:bg-slate-100">
                <X className="w-4 h-4 text-slate-600" />
              </button>
            </div>
            <video ref={videoRef} className="w-full rounded-xl bg-slate-900" autoPlay muted playsInline />
          </div>
        </div>
      )}

      {scanError && (
        <div className="fixed bottom-4 right-4 bg-red-50 text-red-600 px-4 py-3 rounded-xl text-sm font-bold border border-red-100">
          {scanError}
        </div>
      )}
    </div>
  );
}
