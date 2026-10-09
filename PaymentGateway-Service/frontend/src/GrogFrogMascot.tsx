import React, { useState, useEffect } from 'react';
import { LucideIcon, Sparkles } from 'lucide-react';

export interface GrogFrogMascotProps {
  size?: number;
  message?: string;
  subMessage?: string;
  icon?: LucideIcon;
  expression?: 'happy' | 'thinking' | 'wink' | 'idle';
  showBubble?: boolean;
  bubblePosition?: 'top' | 'right' | 'bottom';
  className?: string;
  onClick?: () => void;
}

export const GrogFrogMascot: React.FC<GrogFrogMascotProps> = ({
  size = 120,
  message,
  subMessage,
  icon: MessageIcon,
  expression = 'happy',
  showBubble = true,
  bubblePosition = 'right',
  className = '',
  onClick,
}) => {
  const [isBlinking, setIsBlinking] = useState(false);

  // Ciclo aleatorio de parpadeo natural de la rana (cada 3-5 segundos)
  useEffect(() => {
    let timeoutId: ReturnType<typeof setTimeout>;
    const scheduleBlink = () => {
      const waitTime = 3000 + Math.random() * 2500;
      timeoutId = setTimeout(() => {
        setIsBlinking(true);
        setTimeout(() => {
          setIsBlinking(false);
          scheduleBlink();
        }, 180);
      }, waitTime);
    };

    scheduleBlink();
    return () => clearTimeout(timeoutId);
  }, []);

  const effectiveIcon = MessageIcon || Sparkles;

  return (
    <div
      className={`inline-flex items-center gap-3 select-none relative ${
        bubblePosition === 'top'
          ? 'flex-col-reverse'
          : bubblePosition === 'bottom'
          ? 'flex-col'
          : 'flex-row'
      } ${className}`}
      onClick={onClick}
    >
      {/* Contenedor Flotante de la Mascota */}
      <div
        className="relative cursor-pointer transition-transform duration-300 hover:scale-105"
        style={{
          width: size,
          height: size,
          animation: 'grog-float 3s ease-in-out infinite',
        }}
      >
        {/* Resplandor radial neon */}
        <div
          className="absolute inset-0 rounded-full blur-xl pointer-events-none opacity-40"
          style={{
            background: 'radial-gradient(circle, rgba(99,102,241,0.5) 0%, rgba(56,189,248,0.2) 60%, transparent 100%)',
          }}
        />

        {/* SVG Vectorial de la Mascota GROG */}
        <svg
          viewBox="0 0 100 100"
          width={size}
          height={size}
          className="drop-shadow-[0_8px_16px_rgba(79,70,229,0.35)] relative z-10"
        >
          <defs>
            {/* Gradiente principal Indigo GROG */}
            <linearGradient id="grogFrogBodyGrad" x1="0%" y1="0%" x2="0%" y2="100%">
              <stop offset="0%" stopColor="#6366F1" />
              <stop offset="100%" stopColor="#4338CA" />
            </linearGradient>

            {/* Gradiente de ojos */}
            <radialGradient id="grogEyeGlow" cx="50%" cy="50%" r="50%">
              <stop offset="0%" stopColor="#FFFFFF" />
              <stop offset="85%" stopColor="#F1F5F9" />
              <stop offset="100%" stopColor="#CBD5E1" />
            </radialGradient>
          </defs>

          {/* Ojos base (montículos del cráneo) */}
          <circle cx="27" cy="32" r="20" fill="url(#grogFrogBodyGrad)" />
          <circle cx="73" cy="32" r="20" fill="url(#grogFrogBodyGrad)" />

          {/* Cabeza principal */}
          <rect
            x="9"
            y="30"
            width="82"
            height="56"
            rx="28"
            ry="28"
            fill="url(#grogFrogBodyGrad)"
          />

          {/* Mentón / Barriga iluminada */}
          <ellipse cx="50" cy="72" rx="26" ry="11" fill="#FFFFFF" fillOpacity="0.16" />

          {/* Mejillas sonrosadas */}
          <ellipse cx="22" cy="62" rx="6.5" ry="4" fill="#F472B6" fillOpacity="0.55" />
          <ellipse cx="78" cy="62" rx="6.5" ry="4" fill="#F472B6" fillOpacity="0.55" />

          {/* Nariz (dos pequeños orificios sutiles) */}
          <circle cx="45" cy="53" r="1.8" fill="#312E81" />
          <circle cx="55" cy="53" r="1.8" fill="#312E81" />

          {/* Boca sonriente */}
          <path
            d="M 35 65 Q 50 76 65 65"
            stroke="#FFFFFF"
            strokeWidth="3.2"
            strokeLinecap="round"
            fill="none"
          />

          {/* Lengüita pícara */}
          <path
            d="M 46 71 Q 50 78 54 71"
            fill="#FB7185"
          />

          {/* OJO IZQUIERDO */}
          <g transform="translate(27, 32)">
            {isBlinking ? (
              <path
                d="M -10 0 Q 0 5 10 0"
                stroke="#1E1B4B"
                strokeWidth="3"
                strokeLinecap="round"
                fill="none"
              />
            ) : (
              <>
                <circle cx="0" cy="0" r="14.5" fill="url(#grogEyeGlow)" />
                <circle cx="1.5" cy="0" r="10" fill="#1E1B4B" />
                {/* Reflejos de luz vivos */}
                <circle cx="-2.5" cy="-3.5" r="3.5" fill="#FFFFFF" />
                <circle cx="3.5" cy="3" r="1.8" fill="#FFFFFF" fillOpacity="0.85" />
              </>
            )}
          </g>

          {/* OJO DERECHO */}
          <g transform="translate(73, 32)">
            {isBlinking || expression === 'wink' ? (
              <path
                d="M -10 0 Q 0 5 10 0"
                stroke="#1E1B4B"
                strokeWidth="3"
                strokeLinecap="round"
                fill="none"
              />
            ) : (
              <>
                <circle cx="0" cy="0" r="14.5" fill="url(#grogEyeGlow)" />
                <circle cx="-1.5" cy="0" r="10" fill="#1E1B4B" />
                {/* Reflejos de luz vivos */}
                <circle cx="-3.5" cy="-3.5" r="3.5" fill="#FFFFFF" />
                <circle cx="2.5" cy="3" r="1.8" fill="#FFFFFF" fillOpacity="0.85" />
              </>
            )}
          </g>
        </svg>

        {/* Insignia pulsante pequeña en esquina */}
        <div className="absolute -bottom-1 -right-1 bg-emerald-500 text-white rounded-full p-1 shadow-md border-2 border-slate-900 flex items-center justify-center">
          <div className="w-2 h-2 rounded-full bg-white animate-ping" />
        </div>
      </div>

      {/* Globo de Diálogo / Asistente Interactivo */}
      {showBubble && message && (
        <div className="relative z-20 max-w-sm bg-slate-900/95 backdrop-blur-md text-white border border-indigo-500/30 rounded-2xl p-4 shadow-2xl">
          <div className="flex items-start gap-2.5">
            <div className="p-1.5 rounded-lg bg-indigo-500/20 text-cyan-400 shrink-0 mt-0.5">
              {React.createElement(effectiveIcon, { className: "w-4 h-4 text-cyan-400" })}
            </div>
            <div>
              <p className="text-sm font-semibold text-slate-100 leading-snug">
                {message}
              </p>
              {subMessage && (
                <p className="text-xs text-slate-400 mt-1 leading-normal">
                  {subMessage}
                </p>
              )}
            </div>
          </div>

          {/* Flecha indicadora del globo según posición */}
          {bubblePosition === 'right' && (
            <div
              className="absolute -left-2 top-1/2 -translate-y-1/2 w-0 h-0 border-y-8 border-y-transparent border-r-8 border-r-slate-900"
            />
          )}
          {bubblePosition === 'top' && (
            <div
              className="absolute -bottom-2 left-1/2 -translate-x-1/2 w-0 h-0 border-x-8 border-x-transparent border-t-8 border-t-slate-900"
            />
          )}
          {bubblePosition === 'bottom' && (
            <div
              className="absolute -top-2 left-1/2 -translate-x-1/2 w-0 h-0 border-x-8 border-x-transparent border-b-8 border-b-slate-900"
            />
          )}
        </div>
      )}

      {/* Estilos CSS Inyectados para Animación Flotante */}
      <style>{`
        @keyframes grog-float {
          0%, 100% {
            transform: translateY(0px);
          }
          50% {
            transform: translateY(-8px);
          }
        }
      `}</style>
    </div>
  );
};

export default GrogFrogMascot;
