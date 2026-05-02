import React, { useState, useEffect } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { ShieldCheck, Mail, Lock, ArrowRight, AlertCircle } from 'lucide-react';
import { API_BASE_URL } from './config';

// Declaración para TypeScript (para que no se queje de window.google)
declare global {
  interface Window {
    google: any;
  }
}

export default function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const navigate = useNavigate();

  const GOOGLE_CLIENT_ID = "668360177016-njs18vbi6u7ilju4dvj9o4mu00rigqv6.apps.googleusercontent.com";

  useEffect(() => {
    // 1. Cargar el script de Google nativo
    const script = document.createElement('script');
    script.src = 'https://accounts.google.com/gsi/client';
    script.async = true;
    script.defer = true;
    
    script.onload = () => {
      // 2. Inicializar Google
      window.google.accounts.id.initialize({
        client_id: GOOGLE_CLIENT_ID,
        callback: handleGoogleResponse,
        auto_select: false,
        cancel_on_tap_outside: true,
        use_fedcm_for_prompt: false
      });
      
      // 3. Renderizar el botón en el div con ID 'googleBtn'
      window.google.accounts.id.renderButton(
        document.getElementById('googleBtn'),
        { 
          theme: 'outline', 
          size: 'large', 
          width: '100%', 
          shape: 'pill',
          text: 'continue_with' 
        }
      );
    };
    
    document.head.appendChild(script);
    
    return () => {
      // Limpiar el script al desmontar
      const existingScript = document.querySelector('script[src*="gsi/client"]');
      if (existingScript) existingScript.remove();
    };
  }, []);

  const handleGoogleResponse = async (response: any) => {
    console.log("DEBUG LOGIN: Google response received", response);
    setLoading(true);
    setError('');

    // Safety timeout: Si en 10 segundos no pasa nada, liberar la UI
    const timeoutId = setTimeout(() => {
      if (loading) {
        console.error("DEBUG LOGIN: Timeout alcanzado en validación de Google");
        setLoading(false);
        setError("La validación está tardando demasiado. Revisa tu conexión o la terminal del servidor.");
      }
    }, 10000);

    try {
      console.log("DEBUG LOGIN: Fetching auth/google...");
      const res = await fetch(`${API_BASE_URL}/auth/google`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ token: response.credential })
      });

      console.log("DEBUG LOGIN: Server response status", res.status);
      if (!res.ok) {
        let errDetail = "Error en el servidor";
        try {
          const errData = await res.json();
          errDetail = errData.detail || errDetail;
          console.error("DEBUG LOGIN: Server error data", errData);
        } catch(e) {}
        throw new Error(errDetail);
      }
      
      const data = await res.json();
      console.log("DEBUG LOGIN: Token received successfully");
      localStorage.setItem('simupay_token', data.access_token);
      
      clearTimeout(timeoutId);
      
      // Verificar si hay una redirección pendiente
      const params = new URLSearchParams(window.location.search);
      const redirectTo = params.get('redirect');
      
      if (redirectTo) {
        console.log("DEBUG LOGIN: Redirecting to:", redirectTo);
        const finalRedirect = redirectTo.includes('?') 
          ? `${redirectTo}&email=${data.email || email}` 
          : `${redirectTo}?email=${data.email || email}`;
        
        if (redirectTo.startsWith('http')) {
          navigate(redirectTo);
        } else {
          window.location.href = finalRedirect;
        }
      } else {
        console.log("DEBUG LOGIN: Navigating to /wallet");
        navigate('/wallet');
      }
    } catch (err: any) {
      console.error("DEBUG LOGIN: Catch block error", err);
      setError(err.message || "Error al conectar con el servidor de SimuPay");
      setLoading(false);
      clearTimeout(timeoutId);
    }
  };

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    
    try {
      const formData = new URLSearchParams();
      formData.append('username', email);
      formData.append('password', password);

      const res = await fetch(`${API_BASE_URL}/token`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: formData
      });

      if (!res.ok) throw new Error('Credenciales inválidas');
      
      const data = await res.json();
      localStorage.setItem('simupay_token', data.access_token);
      navigate('/wallet');
    } catch (err: any) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-[#F8FAFC] flex items-center justify-center p-6">
      <div className="max-w-md w-full">
        <div className="text-center mb-10">
          <div className="inline-flex items-center justify-center w-16 h-16 bg-indigo-600 rounded-2xl shadow-xl shadow-indigo-200 mb-4">
            <ShieldCheck className="w-10 h-10 text-white" />
          </div>
          <h2 className="text-3xl font-extrabold text-slate-900">SimuPay</h2>
          <p className="text-slate-500 mt-2 font-medium">Inicia sesión para gestionar tus pagos</p>
        </div>

        <div className="bg-white p-8 rounded-[32px] shadow-2xl shadow-slate-200 border border-slate-100">
          
          <div className="mb-6 w-full flex justify-center">
             <div id="googleBtn" className="w-full"></div>
          </div>

          <div className="relative mb-8">
            <div className="absolute inset-0 flex items-center"><div className="w-full border-t border-slate-100"></div></div>
            <div className="relative flex justify-center text-xs uppercase"><span className="bg-white px-2 text-slate-400 font-bold tracking-widest">O con contraseña</span></div>
          </div>

          <form onSubmit={handleLogin} className="space-y-6">
            <div>
              <label className="block text-sm font-bold text-slate-700 mb-2">Correo Electrónico</label>
              <div className="relative">
                <input
                  type="email"
                  required
                  className="w-full pl-12 pr-4 py-4 bg-slate-50 border-none rounded-2xl focus:ring-2 focus:ring-indigo-500 transition-all font-medium"
                  placeholder="tu@email.com"
                  value={email}
                  onChange={e => setEmail(e.target.value)}
                />
                <Mail className="absolute left-4 top-4 w-5 h-5 text-slate-400" />
              </div>
            </div>

            <div>
              <label className="block text-sm font-bold text-slate-700 mb-2">Contraseña</label>
              <div className="relative">
                <input
                  type="password"
                  required
                  className="w-full pl-12 pr-4 py-4 bg-slate-50 border-none rounded-2xl focus:ring-2 focus:ring-indigo-500 transition-all font-medium"
                  placeholder="••••••••"
                  value={password}
                  onChange={e => setPassword(e.target.value)}
                />
                <Lock className="absolute left-4 top-4 w-5 h-5 text-slate-400" />
              </div>
            </div>

            {error && (
              <div className="p-4 bg-red-50 text-red-600 rounded-2xl text-sm font-bold flex items-center gap-2">
                <AlertCircle className="w-4 h-4" /> {error}
              </div>
            )}

            <button
              disabled={loading}
              type="submit"
              className="w-full py-4 bg-indigo-600 hover:bg-indigo-700 text-white rounded-2xl font-bold text-lg transition-all shadow-lg shadow-indigo-200 flex items-center justify-center gap-2 active:scale-[0.98] disabled:opacity-70"
            >
              {loading ? 'Cargando...' : <>Entrar ahora <ArrowRight className="w-5 h-5" /></>}
            </button>
          </form>

          <div className="mt-8 text-center text-sm font-medium text-slate-500">
            ¿No tienes cuenta? <Link to="/signup" className="text-indigo-600 font-bold hover:underline">Regístrate gratis</Link>
          </div>
        </div>
      </div>
    </div>
  );
}
