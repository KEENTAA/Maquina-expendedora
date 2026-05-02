import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { CreditCard, Wallet, QrCode, Lock, ShieldCheck, ChevronRight, AlertCircle, CheckCircle2, ArrowLeft, Scan } from 'lucide-react';
import { API_BASE_URL, APP_BASE_URL } from './config';

type PaymentMethod = 'card' | 'wallet' | 'qr';

export default function Checkout() {
  const { sessionId } = useParams();
  const navigate = useNavigate();
  const [session, setSession] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [showForceButton, setShowForceButton] = useState(false);
  const [processing, setProcessing] = useState(false);
  const [status, setStatus] = useState<'idle' | 'success' | 'error' | 'pending_qr'>('idle');
  const [method, setMethod] = useState<PaymentMethod>('card');
  const [cardNumber, setCardNumber] = useState('');
  const [qrData, setQrData] = useState<string | null>(null);
  const [qrImage, setQrImage] = useState<string | null>(null);
  const [walletUser, setWalletUser] = useState<any>(null);
  
  const token = localStorage.getItem('simupay_token');

  console.log("DEBUG: Renderizando Checkout. sessionId:", sessionId, "loading:", loading);

  useEffect(() => {
    console.log("DEBUG: useEffect iniciado");
    const initSession = async () => {
      console.log("DEBUG: Ejecutando initSession");
      // Mostrar botón de rescate después de 3 segundos
      const forceButtonTimer = setTimeout(() => setShowForceButton(true), 3000);

      try {
        if (!sessionId || sessionId === ':sessionId' || sessionId === 'undefined') {
          console.warn("DEBUG: sessionId inválido detectado:", sessionId);
          setSession({ amount: 20490.00, enrollment_id: "DEMO-1", status: 'pending' });
          setLoading(false);
          return;
        }

        console.log("DEBUG: Intentando fetch a:", `${API_BASE_URL}/sessions/${sessionId}`);
        const res = await fetch(`${API_BASE_URL}/sessions/${sessionId}`);
        console.log("DEBUG: Respuesta recibida. Status:", res.status);
        
        if (res.ok) {
          const data = await res.json();
          console.log("DEBUG: Datos de sesión cargados:", data);
          setSession(data);
        } else {
          console.error("DEBUG: Error en respuesta del servidor. Status:", res.status);
          setSession({ amount: 20490.00, enrollment_id: "ERROR_API", status: 'pending' });
        }
      } catch (err) {
        console.error("DEBUG: Error CRÍTICO en fetch de sesión:", err);
        setSession({ amount: 20490.00, enrollment_id: "FETCH_FAILED", status: 'pending' });
      } finally {
        console.log("DEBUG: Finalizando carga de sesión");
        setLoading(false);
        clearTimeout(forceButtonTimer);
      }
    };

    const loadWallet = async () => {
      if (!token) {
        console.log("DEBUG: No hay token para cargar billetera");
        return;
      }
      try {
        console.log("DEBUG: Cargando billetera...");
        const res = await fetch(`${API_BASE_URL}/wallet`, {
          headers: { 'Authorization': `Bearer ${token}` }
        });
        if (res.ok) {
          const data = await res.json();
          console.log("DEBUG: Billetera cargada:", data);
          setWalletUser(data);
        }
      } catch (e) {
        console.error("DEBUG: Error cargando billetera:", e);
      }
    };

    initSession();
    loadWallet();
  }, [sessionId, token]);

  const handlePay = async () => {
    console.log("DEBUG: Iniciando pago con método:", method);
    setProcessing(true);
    setStatus('idle');
    
    try {
      const payload: any = { method };
      if (method === 'card') payload.card_number = cardNumber;
      
      // Vincular el pago al usuario si está logueado (para el historial en gateway.db)
      if (walletUser?.user_id) {
        payload.user_id = walletUser.user_id;
      }

      console.log("DEBUG: Enviando proceso de pago:", payload);
      const res = await fetch(`${API_BASE_URL}/sessions/${sessionId}/process`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });
      
      const data = await res.json();
      console.log("DEBUG: Resultado de pago:", data);
      
      if (data.status === 'completed') {
        setStatus('success');
        console.log("DEBUG: Pago completado. Redirigiendo...");
        setTimeout(() => {
          window.location.href = `${APP_BASE_URL}/confirmation?enrollment=${session.enrollment_id}`;
        }, 3000);
      } else if (data.status === 'pending' && method === 'qr') {
        setStatus('pending_qr');
        setQrData(data.qr_data);
        setQrImage(data.qr_image);
        console.log("DEBUG: QR generado y mostrado");
      } else {
        console.warn("DEBUG: Pago fallido o estado desconocido:", data.status);
        setStatus('error');
      }
    } catch (e) {
      console.error("DEBUG: Error en handlePay:", e);
      setStatus('error');
    } finally {
      setProcessing(false);
    }
  };

  const downloadQR = () => {
    if (!qrImage) return;
    const link = document.createElement('a');
    link.href = qrImage;
    link.download = `simupay-qr-${sessionId}.png`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const simulateQRPayment = async () => {
    console.log("DEBUG: Simulando pago QR");
    setProcessing(true);
    try {
      const res = await fetch(`${API_BASE_URL}/simulate-qr-payment`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ transaction_id: sessionId, status: 'completed' })
      });
      console.log("DEBUG: Simulación enviada. Status:", res.status);
      setStatus('success');
      setTimeout(() => {
        window.location.href = `${APP_BASE_URL}/confirmation?enrollment=${session.enrollment_id}`;
      }, 3000);
    } catch (e) {
      console.error("DEBUG: Error en simulación:", e);
      setStatus('error');
    } finally {
      setProcessing(false);
    }
  };

  if (loading) return (
    <div className="min-h-screen flex flex-col items-center justify-center bg-slate-50 p-4">
      <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600 mb-6"></div>
      <div className="text-slate-500 font-bold text-lg text-center mb-6">Cargando datos de SimuPay...</div>
      {showForceButton && (
        <div className="bg-white p-6 rounded-2xl shadow-xl border border-slate-100 max-w-sm text-center">
          <p className="text-sm text-slate-500 mb-4">Parece que la conexión está tardando más de lo normal.</p>
          <button 
            onClick={() => {
              console.log("DEBUG: Acción de rescate manual ejecutada");
              setSession({ amount: 20490.00, enrollment_id: "FORCED_ID", status: 'pending' });
              setLoading(false);
            }}
            className="w-full px-6 py-3 bg-indigo-600 text-white rounded-xl font-bold hover:bg-indigo-700 transition-all shadow-lg active:scale-95"
          >
            Forzar Entrada (Modo Demo)
          </button>
        </div>
      )}
    </div>
  );

  if (status === 'success') return (
    <div className="min-h-screen flex items-center justify-center bg-green-50 px-4">
      <div className="text-center p-10 bg-white rounded-[40px] shadow-2xl max-w-md w-full border border-green-100">
        <div className="w-24 h-24 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-8 animate-bounce">
          <CheckCircle2 className="w-14 h-14 text-green-600" />
        </div>
        <h2 className="text-3xl font-black text-slate-900 mb-3">¡Pago Exitoso!</h2>
        <p className="text-slate-500 mb-8 font-medium leading-relaxed">SimuPay ha confirmado tu transacción. Estamos redirigiéndote de vuelta al colegio...</p>
        <div className="h-2 w-full bg-slate-100 rounded-full overflow-hidden">
          <div className="h-full bg-green-500 animate-[progress_3s_linear]"></div>
        </div>
      </div>
    </div>
  );

  return (
    <div className="min-h-screen bg-[#F8FAFC] font-sans text-slate-900 py-12 px-4">
      <div className="max-w-[1000px] mx-auto grid md:grid-cols-2 gap-12 items-start">
        {/* Left Side: Order Info */}
        <div className="space-y-8">
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 bg-indigo-600 rounded-2xl flex items-center justify-center shadow-xl shadow-indigo-100">
              <ShieldCheck className="w-7 h-7 text-white" />
            </div>
            <span className="font-black text-2xl tracking-tight text-slate-900">SimuPay</span>
          </div>

          <div className="bg-white rounded-[32px] p-8 border border-slate-100 shadow-sm">
            <button 
              onClick={() => window.location.href = APP_BASE_URL}
              className="flex items-center gap-2 text-slate-400 text-sm font-bold mb-6 hover:text-slate-600 transition-colors"
            >
              <ArrowLeft className="w-4 h-4" /> Volver al comercio
            </button>
            <div className="space-y-4">
              <div className="text-xs font-bold text-slate-400 uppercase tracking-widest">Resumen del pedido</div>
              <div className="flex justify-between items-end">
                <div>
                  <div className="text-4xl font-black text-slate-900">
                    Bs. {session?.amount?.toLocaleString(undefined, { minimumFractionDigits: 2 })}
                  </div>
                  <div className="text-sm font-bold text-slate-400">Experimental College - Matrícula 2026</div>
                </div>
                <div className="text-xs font-bold bg-indigo-50 text-indigo-600 px-3 py-1 rounded-full">SIM-{sessionId?.substring(0, 8)}</div>
              </div>
            </div>
          </div>

          <div className="flex items-center gap-6 text-sm font-bold text-slate-400">
            <div className="flex items-center gap-2"><Lock className="w-4 h-4" /> 256-bit SSL</div>
            <div className="flex items-center gap-2"><CheckCircle2 className="w-4 h-4" /> PCI DSS Compliant</div>
          </div>
        </div>

        {/* Right Side: Payment Methods */}
        <div className="bg-white rounded-[40px] shadow-2xl shadow-slate-200 border border-slate-100 overflow-hidden">
          <div className="p-8 border-b border-slate-50 flex gap-4 overflow-x-auto">
            <button 
              onClick={() => setMethod('card')}
              className={`flex-1 min-w-[100px] py-4 rounded-2xl border-2 transition-all flex flex-col items-center gap-2 ${method === 'card' ? 'border-indigo-600 bg-indigo-50/50 text-indigo-600' : 'border-slate-100 hover:border-slate-200 text-slate-400'}`}
            >
              <CreditCard className="w-6 h-6" />
              <span className="text-xs font-bold uppercase tracking-widest">Tarjeta</span>
            </button>
            <button 
              onClick={() => setMethod('wallet')}
              className={`flex-1 min-w-[100px] py-4 rounded-2xl border-2 transition-all flex flex-col items-center gap-2 ${method === 'wallet' ? 'border-indigo-600 bg-indigo-50/50 text-indigo-600' : 'border-slate-100 hover:border-slate-200 text-slate-400'}`}
            >
              <Wallet className="w-6 h-6" />
              <span className="text-xs font-bold uppercase tracking-widest">Billetera</span>
            </button>
            <button 
              onClick={() => setMethod('qr')}
              className={`flex-1 min-w-[100px] py-4 rounded-2xl border-2 transition-all flex flex-col items-center gap-2 ${method === 'qr' ? 'border-indigo-600 bg-indigo-50/50 text-indigo-600' : 'border-slate-100 hover:border-slate-200 text-slate-400'}`}
            >
              <QrCode className="w-6 h-6" />
              <span className="text-xs font-bold uppercase tracking-widest">QR</span>
            </button>
          </div>

          <div className="p-8">
            {status === 'pending_qr' ? (
              <div className="text-center py-6 space-y-6">
                <div className="text-lg font-bold text-slate-900">Escanea este código QR</div>
                <div className="w-64 h-64 bg-white rounded-3xl mx-auto flex flex-col items-center justify-center border-2 border-slate-100 shadow-inner overflow-hidden relative group">
                   {qrImage ? (
                     <>
                      <img src={qrImage} alt="QR Code" className="w-full h-full object-contain" />
                      <button 
                        onClick={downloadQR}
                        className="absolute inset-0 bg-indigo-600/90 text-white opacity-0 group-hover:opacity-100 transition-opacity flex flex-col items-center justify-center gap-2 font-bold"
                      >
                        <ShieldCheck className="w-8 h-8" />
                        Guardar QR
                      </button>
                     </>
                   ) : (
                    <div className="flex flex-col items-center gap-2">
                       <QrCode className="w-24 h-24 text-slate-200 animate-pulse" />
                       <span className="text-[10px] text-slate-400 font-bold">GENERANDO QR...</span>
                    </div>
                   )}
                </div>
                <div className="space-y-2">
                  <p className="text-sm font-bold text-slate-900">
                    Bs. {session?.amount?.toLocaleString()}
                  </p>
                  <p className="text-xs font-medium text-slate-400 px-6">
                    Abre la app de tu banco (Yape/SimuPay) y escanea el código para confirmar el pago.
                  </p>
                </div>
                <div className="flex flex-col gap-3">
                  <button
                    onClick={simulateQRPayment}
                    className="w-full py-4 bg-indigo-600 text-white rounded-2xl font-bold hover:bg-indigo-700 transition-all shadow-lg active:scale-95 flex items-center justify-center gap-2"
                  >
                    {processing ? <div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin" /> : <Scan className="w-5 h-5" />}
                    Confirmar Pago (Simulación)
                  </button>
                  <button
                    onClick={() => setStatus('idle')}
                    className="text-xs font-bold text-slate-400 hover:text-slate-600 uppercase tracking-widest"
                  >
                    Elegir otro método
                  </button>
                </div>
              </div>
            ) : (
              <div className="space-y-6">
                {method === 'card' && (
                  <div className="space-y-4">
                    <div className="space-y-2">
                      <label className="text-xs font-bold text-slate-400 uppercase tracking-widest">Información de la tarjeta</label>
                      <div className="relative">
                        <input
                          type="text"
                          placeholder="0000 0000 0000 0000"
                          className="w-full pl-4 pr-12 py-4 bg-slate-50 border-none rounded-2xl focus:ring-2 focus:ring-indigo-500 font-medium"
                          value={cardNumber}
                          onChange={e => setCardNumber(e.target.value)}
                        />
                        <CreditCard className="absolute right-4 top-4 w-6 h-6 text-slate-300" />
                      </div>
                    </div>
                    <div className="grid grid-cols-2 gap-4">
                      <input type="text" placeholder="MM / AA" className="w-full px-4 py-4 bg-slate-50 border-none rounded-2xl focus:ring-2 focus:ring-indigo-500 font-medium" />
                      <input type="text" placeholder="CVC" className="w-full px-4 py-4 bg-slate-50 border-none rounded-2xl focus:ring-2 focus:ring-indigo-500 font-medium" />
                    </div>
                  </div>
                )}

                {method === 'wallet' && (
                  <div className="py-6 text-center space-y-4">
                    {walletUser ? (
                      <div className="bg-slate-50 p-6 rounded-[24px] border border-slate-100">
                        <div className="text-xs font-bold text-slate-400 uppercase tracking-widest mb-1">Tu saldo disponible</div>
                        <div className="text-3xl font-black text-indigo-600">Bs. {walletUser.balance.toLocaleString()}</div>
                        {walletUser.balance < session?.amount && (
                          <div className="mt-4 p-3 bg-amber-50 text-amber-600 rounded-xl text-xs font-bold">
                            Saldo insuficiente. Por favor recarga.
                          </div>
                        )}
                      </div>
                    ) : (
                      <div className="bg-slate-50 p-8 rounded-[32px] border border-slate-100">
                        <div className="w-16 h-16 bg-white rounded-2xl flex items-center justify-center mx-auto mb-4 shadow-sm">
                           <Lock className="w-8 h-8 text-indigo-600" />
                        </div>
                        <h4 className="font-bold text-slate-900 mb-2">Identificación Requerida</h4>
                        <p className="text-slate-500 text-sm font-medium mb-6">Inicia sesión en SimuPay para pagar con tu billetera y obtener puntos de seguridad.</p>
                        <button 
                          onClick={() => navigate(`/login?redirect=/checkout/${sessionId}`)} 
                          className="w-full py-4 bg-indigo-600 text-white rounded-2xl font-bold hover:bg-indigo-700 transition-all flex items-center justify-center gap-2"
                        >
                          <ShieldCheck className="w-5 h-5" /> Iniciar sesión ahora
                        </button>
                      </div>
                    )}
                  </div>
                )}

                <button
                  onClick={handlePay}
                  disabled={processing || (method === 'wallet' && (!walletUser || walletUser.balance < session?.amount))}
                  className="w-full py-5 bg-indigo-600 hover:bg-indigo-700 text-white rounded-2xl font-black text-xl transition-all shadow-xl shadow-indigo-100 flex items-center justify-center gap-3 active:scale-[0.98] disabled:opacity-50"
                >
                  {processing ? (
                    <div className="w-6 h-6 border-4 border-white border-t-transparent rounded-full animate-spin"></div>
                  ) : (
                    <>Pagar Ahora <ChevronRight className="w-6 h-6" /></>
                  )}
                </button>

                {status === 'error' && (
                  <div className="flex items-center gap-2 p-4 bg-red-50 text-red-600 rounded-2xl text-sm font-bold animate-shake">
                    <AlertCircle className="w-5 h-5" />
                    Error al procesar el pago. Intenta de nuevo.
                  </div>
                )}
              </div>
            )}
          </div>
        </div>
      </div>
      
      <style>{`
        @keyframes progress { from { width: 0%; } to { width: 100%; } }
        @keyframes shake { 0%, 100% { transform: translateX(0); } 25% { transform: translateX(-4px); } 75% { transform: translateX(4px); } }
        .animate-shake { animation: shake 0.2s ease-in-out 0s 2; }
      `}</style>
    </div>
  );
}
