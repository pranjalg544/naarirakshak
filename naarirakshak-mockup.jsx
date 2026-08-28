import { useState, useRef, useCallback } from "react";
import {
  Home, Users, Phone, ShieldCheck, MapPin, Clock, Mic, AlertTriangle,
  Check, X, ChevronRight, ChevronLeft, PhoneCall, PhoneOff, UserPlus,
  Radio, Battery, Wifi, SignalHigh, Navigation, Settings, Volume2, Plus
} from "lucide-react";

const T = {
  bgDeep: "#1B2430",
  bg: "#F8F4FB",
  surface: "#FFFFFF",
  surface2: "#F1E8F8",
  border: "rgba(27,36,48,0.09)",
  amber: "#E0993A",
  amberDim: "#B98426",
  coral: "#FF5A5F",
  green: "#3FAE6E",
  text: "#1B2430",
  muted: "#5B6472",
  faint: "#8B94A3",
};

const display = { fontFamily: "'Fraunces', serif" };
const mono = { fontFamily: "'JetBrains Mono', monospace" };
const body = { fontFamily: "'Manrope', sans-serif" };

function BeaconRing({ size = 90, color = T.amber, ringCount = 3, active = true }) {
  return (
    <div style={{ position: "relative", width: size, height: size }} className="flex items-center justify-center">
      {active &&
        Array.from({ length: ringCount }).map((_, i) => (
          <span
            key={i}
            style={{
              position: "absolute",
              width: size,
              height: size,
              borderRadius: "9999px",
              border: `1.5px solid ${color}`,
              animation: `beaconPulse 2.6s ease-out infinite`,
              animationDelay: `${i * 0.7}s`,
            }}
          />
        ))}
      <div
        style={{
          width: size * 0.36,
          height: size * 0.36,
          borderRadius: "9999px",
          background: color,
          boxShadow: `0 0 16px ${color}99`,
        }}
      />
    </div>
  );
}

function StatusBar() {
  return (
    <div className="flex items-center justify-between px-6 pt-3 pb-1" style={{ color: T.text, ...mono }}>
      <span className="text-xs">9:41</span>
      <div className="flex items-center gap-1.5">
        <SignalHigh size={13} />
        <Wifi size={13} />
        <Battery size={14} />
      </div>
    </div>
  );
}

function NavBar({ screen, onNav }) {
  const items = [
    { key: "home", icon: Home, label: "Home" },
    { key: "pod", icon: Users, label: "Pod" },
    { key: "contacts", icon: Phone, label: "Contacts" },
    { key: "settings", icon: Settings, label: "Settings" },
  ];
  return (
    <div
      className="flex items-center justify-around px-2 pt-2.5 pb-6"
      style={{ background: T.surface, borderTop: `1px solid ${T.border}` }}
    >
      {items.map(({ key, icon: Icon, label }) => {
        const activeTab = screen === key;
        return (
          <button
            key={key}
            onClick={() => onNav(key)}
            className="flex flex-col items-center gap-1 px-3"
            style={{ ...body }}
          >
            <Icon size={19} color={activeTab ? T.amber : T.faint} strokeWidth={activeTab ? 2.4 : 2} />
            <span style={{ fontSize: 10, color: activeTab ? T.amber : T.faint }}>{label}</span>
          </button>
        );
      })}
    </div>
  );
}

function FloatingSOS({ onPress }) {
  return (
    <div style={{ position: "absolute", right: 16, bottom: 84, zIndex: 30 }}>
      <div style={{ position: "relative" }}>
        <span
          style={{
            position: "absolute",
            inset: -6,
            borderRadius: "9999px",
            border: `1.5px solid ${T.coral}`,
            animation: "beaconPulse 2.2s ease-out infinite",
          }}
        />
        <button
          onClick={onPress}
          className="flex items-center justify-center"
          style={{
            width: 54,
            height: 54,
            borderRadius: "9999px",
            background: T.coral,
            boxShadow: `0 4px 18px ${T.coral}66`,
          }}
        >
          <AlertTriangle size={22} color={T.bgDeep} strokeWidth={2.4} />
        </button>
      </div>
    </div>
  );
}

function Onboarding({ onStart }) {
  return (
    <div className="h-full flex flex-col items-center justify-between px-8 pt-16 pb-12" style={{ background: `radial-gradient(120% 90% at 50% 0%, ${T.surface2} 0%, ${T.bg} 70%)` }}>
      <div className="flex flex-col items-center gap-5 mt-6">
        <BeaconRing size={104} color={T.amber} />
        <div className="text-center mt-2">
          <h1 style={{ ...display, fontWeight: 700, fontSize: 30, color: T.text, letterSpacing: 0.2 }}>
            NaariRakshak
          </h1>
          <p style={{ ...display, fontStyle: "italic", fontWeight: 500, fontSize: 15, color: T.amber, marginTop: 6 }}>
            Never alone. Never silent.<br />Never undetected.
          </p>
        </div>
      </div>
      <div className="w-full flex flex-col items-center gap-6">
        <div className="flex items-center gap-6" style={{ color: T.muted }}>
          {[
            { icon: Users, label: "Pods" },
            { icon: Radio, label: "Silent SOS" },
            { icon: Mic, label: "AI Detect" },
          ].map(({ icon: Icon, label }) => (
            <div key={label} className="flex flex-col items-center gap-1.5">
              <Icon size={17} color={T.amber} />
              <span style={{ ...body, fontSize: 10 }}>{label}</span>
            </div>
          ))}
        </div>
        <button
          onClick={onStart}
          className="w-full py-3.5 rounded-full"
          style={{ background: T.amber, color: T.bgDeep, ...body, fontWeight: 700, fontSize: 15 }}
        >
          Get started
        </button>
        <p style={{ ...body, fontSize: 11, color: T.faint, textAlign: "center" }}>
          Three layers of protection for every commute.
        </p>
      </div>
    </div>
  );
}

function StatLine({ value, label }) {
  return (
    <div className="flex flex-col">
      <span style={{ ...mono, fontSize: 19, color: T.text, fontWeight: 500 }}>{value}</span>
      <span style={{ ...body, fontSize: 10.5, color: T.faint }}>{label}</span>
    </div>
  );
}

function LayerChip({ label, active, icon: Icon }) {
  return (
    <div
      className="flex items-center gap-1.5 px-2.5 py-1.5 rounded-full"
      style={{ background: active ? `${T.amber}1A` : T.surface, border: `1px solid ${active ? T.amber : T.border}` }}
    >
      <Icon size={12} color={active ? T.amber : T.faint} />
      <span style={{ ...body, fontSize: 10.5, color: active ? T.amber : T.faint }}>{label}</span>
    </div>
  );
}

function HomeScreen({ onStartCommute }) {
  return (
    <div className="h-full overflow-y-auto pb-4" style={{ background: T.bg }}>
      <div className="px-6 pt-2 pb-5">
        <p style={{ ...body, fontSize: 12.5, color: T.faint }}>Good evening,</p>
        <h2 style={{ ...display, fontWeight: 600, fontSize: 22, color: T.text }}>Aditi</h2>
      </div>

      <div className="mx-5 rounded-3xl p-5 mb-5" style={{ background: `linear-gradient(135deg, ${T.surface2}, ${T.surface})`, border: `1px solid ${T.border}` }}>
        <div className="flex items-center justify-between mb-4">
          <span style={{ ...body, fontSize: 12.5, color: T.muted }}>Ready for your commute</span>
          <ShieldCheck size={16} color={T.amber} />
        </div>
        <div className="flex items-center gap-2 mb-1.5" style={{ color: T.text }}>
          <MapPin size={13} color={T.amber} />
          <span style={{ ...body, fontSize: 13.5 }}>Kalkaji → Cyber Hub, Gurugram</span>
        </div>
        <div className="flex items-center gap-2 mb-4" style={{ color: T.faint }}>
          <Clock size={12} />
          <span style={{ ...mono, fontSize: 11.5 }}>Est. 38 min · Auto + Metro</span>
        </div>
        <button
          onClick={onStartCommute}
          className="w-full py-3 rounded-full flex items-center justify-center gap-2"
          style={{ background: T.amber, color: T.bgDeep, ...body, fontWeight: 700, fontSize: 14 }}
        >
          Start commute <Navigation size={14} />
        </button>
      </div>

      <div className="px-6 mb-5">
        <div className="flex items-center justify-between">
          <StatLine value="47" label="safe arrivals" />
          <StatLine value="312 km" label="protected this month" />
          <StatLine value="6" label="pod companions" />
        </div>
      </div>

      <div className="px-6 mb-2">
        <p style={{ ...body, fontSize: 11.5, color: T.faint, marginBottom: 8 }}>YOUR THREE LAYERS</p>
        <div className="flex items-center gap-2 flex-wrap">
          <LayerChip label="Pod matching" active icon={Users} />
          <LayerChip label="Silent SOS armed" active icon={Radio} />
          <LayerChip label="Audio detection" active icon={Mic} />
        </div>
      </div>
    </div>
  );
}

function PodMember({ initials, status }) {
  const ok = status === "reached";
  return (
    <div className="flex items-center justify-between py-2.5" style={{ borderBottom: `1px solid ${T.border}` }}>
      <div className="flex items-center gap-3">
        <div
          className="flex items-center justify-center"
          style={{ width: 34, height: 34, borderRadius: "9999px", background: T.surface2, border: `1.5px solid ${ok ? T.green : T.amber}`, color: T.text, ...body, fontSize: 12, fontWeight: 700 }}
        >
          {initials}
        </div>
        <div>
          <p style={{ ...body, fontSize: 13, color: T.text }}>Companion {initials}</p>
          <p style={{ ...body, fontSize: 10.5, color: T.faint }}>{ok ? "Reached safely · 8:52 PM" : "En route · sharing location"}</p>
        </div>
      </div>
      {ok ? <Check size={15} color={T.green} /> : <span style={{ ...mono, fontSize: 10, color: T.amber }}>live</span>}
    </div>
  );
}

function PodScreen({ onReached }) {
  return (
    <div className="h-full overflow-y-auto pb-4" style={{ background: T.bg }}>
      <div className="px-6 pt-3 pb-4">
        <h2 style={{ ...display, fontWeight: 600, fontSize: 19, color: T.text }}>Your safety pod</h2>
        <p style={{ ...body, fontSize: 12, color: T.faint }}>Matched by route · 4 of 5 checked in</p>
      </div>

      <div className="flex flex-col items-center py-4">
        <BeaconRing size={130} color={T.amber} ringCount={2} />
        <p style={{ ...mono, fontSize: 12, color: T.amber, marginTop: 10 }}>ETA 14:32</p>
        <p style={{ ...body, fontSize: 11, color: T.faint }}>Live location shared with pod</p>
      </div>

      <div className="mx-5 rounded-2xl px-4" style={{ background: T.surface, border: `1px solid ${T.border}` }}>
        <PodMember initials="RS" status="reached" />
        <PodMember initials="MK" status="reached" />
        <PodMember initials="PJ" status="reached" />
        <PodMember initials="TN" status="live" />
      </div>

      <div className="px-5 mt-5">
        <button
          onClick={onReached}
          className="w-full py-3 rounded-full flex items-center justify-center gap-2"
          style={{ background: T.green, color: T.bgDeep, ...body, fontWeight: 700, fontSize: 14 }}
        >
          <Check size={15} /> I've reached safely
        </button>
        <p style={{ ...body, fontSize: 10.5, color: T.faint, textAlign: "center", marginTop: 10 }}>
          Missed check-ins auto-alert your pod and emergency contacts.
        </p>
      </div>
    </div>
  );
}

function SOSTrigger({ onActivate, onDecoy, onCancel }) {
  const [progress, setProgress] = useState(0);
  const timer = useRef(null);
  const HOLD_MS = 1400;

  const start = useCallback(() => {
    const t0 = Date.now();
    timer.current = setInterval(() => {
      const p = Math.min(100, ((Date.now() - t0) / HOLD_MS) * 100);
      setProgress(p);
      if (p >= 100) {
        clearInterval(timer.current);
        onActivate();
      }
    }, 16);
  }, [onActivate]);

  const stop = useCallback(() => {
    clearInterval(timer.current);
    setProgress(0);
  }, []);

  return (
    <div className="h-full flex flex-col" style={{ background: T.bg }}>
      <div className="flex items-center justify-between px-5 pt-3">
        <button onClick={onCancel} className="p-1"><X size={20} color={T.muted} /></button>
        <span style={{ ...body, fontSize: 12, color: T.faint }}>Silent SOS</span>
        <div style={{ width: 22 }} />
      </div>

      <div className="flex-1 flex flex-col items-center justify-center px-8">
        <div style={{ position: "relative", width: 190, height: 190 }} className="flex items-center justify-center">
          <svg width="190" height="190" style={{ position: "absolute", transform: "rotate(-90deg)" }}>
            <circle cx="95" cy="95" r="86" stroke={T.surface2} strokeWidth="6" fill="none" />
            <circle
              cx="95" cy="95" r="86" stroke={T.coral} strokeWidth="6" fill="none"
              strokeDasharray={2 * Math.PI * 86}
              strokeDashoffset={2 * Math.PI * 86 * (1 - progress / 100)}
              strokeLinecap="round"
              style={{ transition: "stroke-dashoffset 0.05s linear" }}
            />
          </svg>
          <button
            onMouseDown={start}
            onMouseUp={stop}
            onMouseLeave={stop}
            onTouchStart={start}
            onTouchEnd={stop}
            className="flex items-center justify-center"
            style={{ width: 132, height: 132, borderRadius: "9999px", background: T.coral, boxShadow: `0 0 30px ${T.coral}55` }}
          >
            <AlertTriangle size={34} color={T.bgDeep} strokeWidth={2.2} />
          </button>
        </div>
        <p style={{ ...body, fontSize: 13, color: T.text, marginTop: 22, textAlign: "center" }}>Press and hold for 3 seconds</p>
        <p style={{ ...body, fontSize: 11, color: T.faint, marginTop: 4, textAlign: "center" }}>
          Shares live location, audio and alerts your pod, contacts and control room
        </p>
      </div>

      <div className="px-6 pb-8">
        <p style={{ ...body, fontSize: 10.5, color: T.faint, marginBottom: 10 }}>OTHER TRIGGERS</p>
        <div className="flex items-center justify-between py-2" style={{ borderTop: `1px solid ${T.border}` }}>
          <span style={{ ...body, fontSize: 12.5, color: T.muted }}>Power button pattern</span>
          <ChevronRight size={14} color={T.faint} />
        </div>
        <div className="flex items-center justify-between py-2" style={{ borderTop: `1px solid ${T.border}` }}>
          <span style={{ ...body, fontSize: 12.5, color: T.muted }}>Shake gesture</span>
          <ChevronRight size={14} color={T.faint} />
        </div>
        <button onClick={onDecoy} className="flex items-center justify-between w-full py-2" style={{ borderTop: `1px solid ${T.border}` }}>
          <span style={{ ...body, fontSize: 12.5, color: T.muted }}>Preview decoy screen</span>
          <ChevronRight size={14} color={T.faint} />
        </button>
      </div>
    </div>
  );
}

function SOSActive({ onResolve }) {
  return (
    <div className="h-full flex flex-col" style={{ background: `linear-gradient(180deg, #FCE7E7, ${T.bg})` }}>
      <div className="flex flex-col items-center pt-10 pb-6">
        <BeaconRing size={92} color={T.coral} />
        <h2 style={{ ...display, fontWeight: 700, fontSize: 19, color: T.text, marginTop: 14 }}>Alert sent</h2>
        <p style={{ ...mono, fontSize: 11, color: T.coral, marginTop: 4 }}>Live for 02:14</p>
      </div>

      <div className="mx-5 rounded-2xl p-4" style={{ background: T.surface, border: `1px solid ${T.border}` }}>
        {[
          { label: "Pod notified", done: true },
          { label: "Emergency contacts notified", done: true },
          { label: "Live location sharing", done: true },
          { label: "Control room (112) pinged", done: false },
        ].map((row) => (
          <div key={row.label} className="flex items-center justify-between py-2">
            <span style={{ ...body, fontSize: 12.5, color: T.text }}>{row.label}</span>
            {row.done ? <Check size={15} color={T.green} /> : <span style={{ ...mono, fontSize: 10, color: T.faint }}>pending</span>}
          </div>
        ))}
      </div>

      <div className="px-5 mt-6 flex flex-col gap-3">
        <button className="w-full py-3 rounded-full flex items-center justify-center gap-2" style={{ background: T.coral, color: T.bgDeep, ...body, fontWeight: 700, fontSize: 14 }}>
          <PhoneCall size={15} /> Call 112 now
        </button>
        <button onClick={onResolve} className="w-full py-3 rounded-full flex items-center justify-center gap-2" style={{ background: "transparent", border: `1px solid ${T.border}`, color: T.muted, ...body, fontSize: 13.5 }}>
          I'm safe — cancel alert
        </button>
      </div>
    </div>
  );
}

function DecoyScreen({ onBack }) {
  return (
    <div className="h-full flex flex-col items-center justify-between" style={{ background: "#0B0B10" }} onDoubleClick={onBack}>
      <div className="w-full flex justify-between px-5 pt-4">
        <span style={{ ...mono, fontSize: 10, color: "#555" }}>double-tap to exit preview</span>
        <button onClick={onBack}><X size={16} color="#666" /></button>
      </div>
      <div className="flex flex-col items-center">
        <div style={{ width: 92, height: 92, borderRadius: "9999px", background: "#2A2A32" }} className="flex items-center justify-center mb-6">
          <span style={{ ...display, fontSize: 30, color: "#999" }}>M</span>
        </div>
        <p style={{ ...body, fontSize: 20, color: "#EDEDED", fontWeight: 600 }}>Mom</p>
        <p style={{ ...body, fontSize: 12.5, color: "#888", marginTop: 4 }}>mobile · calling…</p>
      </div>
      <div className="w-full flex justify-around pb-14">
        <div className="flex flex-col items-center gap-2">
          <div style={{ width: 58, height: 58, borderRadius: "9999px", background: "#E5484D" }} className="flex items-center justify-center">
            <PhoneOff size={22} color="#fff" />
          </div>
          <span style={{ ...body, fontSize: 10, color: "#888" }}>Decline</span>
        </div>
        <div className="flex flex-col items-center gap-2">
          <div style={{ width: 58, height: 58, borderRadius: "9999px", background: "#30C85E" }} className="flex items-center justify-center">
            <PhoneCall size={22} color="#fff" />
          </div>
          <span style={{ ...body, fontSize: 10, color: "#888" }}>Accept</span>
        </div>
      </div>
    </div>
  );
}

function ContactRow({ initials, name, relation }) {
  return (
    <div className="flex items-center gap-3 py-2.5" style={{ borderBottom: `1px solid ${T.border}` }}>
      <div className="flex items-center justify-center" style={{ width: 34, height: 34, borderRadius: "9999px", background: T.surface2, color: T.amber, ...body, fontSize: 12, fontWeight: 700 }}>
        {initials}
      </div>
      <div className="flex-1">
        <p style={{ ...body, fontSize: 13, color: T.text }}>{name}</p>
        <p style={{ ...body, fontSize: 10.5, color: T.faint }}>{relation}</p>
      </div>
      <ChevronRight size={14} color={T.faint} />
    </div>
  );
}

function ContactsScreen() {
  return (
    <div className="h-full overflow-y-auto pb-4" style={{ background: T.bg }}>
      <div className="px-6 pt-3 pb-4 flex items-center justify-between">
        <h2 style={{ ...display, fontWeight: 600, fontSize: 19, color: T.text }}>Emergency contacts</h2>
        <UserPlus size={17} color={T.amber} />
      </div>
      <div className="mx-5 rounded-2xl px-4" style={{ background: T.surface, border: `1px solid ${T.border}` }}>
        <ContactRow initials="MA" name="Mother" relation="Primary · always alerted" />
        <ContactRow initials="RK" name="Rohan (brother)" relation="Secondary" />
        <ContactRow initials="SN" name="Neha (flatmate)" relation="Secondary" />
      </div>
      <button className="mx-5 mt-4 flex items-center justify-center gap-2 py-3 rounded-2xl w-[calc(100%-40px)]" style={{ border: `1px dashed ${T.border}`, color: T.muted }}>
        <Plus size={14} /> <span style={{ ...body, fontSize: 12.5 }}>Add contact</span>
      </button>
    </div>
  );
}

function ToggleRow({ icon: Icon, title, sub, on }) {
  const [checked, setChecked] = useState(on);
  return (
    <div className="flex items-start gap-3 py-3.5" style={{ borderBottom: `1px solid ${T.border}` }}>
      <Icon size={16} color={T.amber} style={{ marginTop: 2 }} />
      <div className="flex-1">
        <p style={{ ...body, fontSize: 13, color: T.text }}>{title}</p>
        <p style={{ ...body, fontSize: 10.5, color: T.faint, marginTop: 2 }}>{sub}</p>
      </div>
      <button
        onClick={() => setChecked(!checked)}
        style={{ width: 38, height: 22, borderRadius: 9999, background: checked ? T.amber : T.surface2, position: "relative", flexShrink: 0 }}
      >
        <span style={{ position: "absolute", top: 2, left: checked ? 18 : 2, width: 18, height: 18, borderRadius: 9999, background: "#FFFFFF", transition: "left 0.15s", boxShadow: "0 1px 3px rgba(0,0,0,0.25)" }} />
      </button>
    </div>
  );
}

function SettingsScreen() {
  return (
    <div className="h-full overflow-y-auto pb-4" style={{ background: T.bg }}>
      <div className="px-6 pt-3 pb-4">
        <h2 style={{ ...display, fontWeight: 600, fontSize: 19, color: T.text }}>Safety settings</h2>
      </div>
      <div className="mx-5 rounded-2xl px-4" style={{ background: T.surface, border: `1px solid ${T.border}` }}>
        <ToggleRow icon={Mic} title="Passive audio detection" sub="On-device only, opt-in, active during commutes" on />
        <ToggleRow icon={Users} title="Auto pod matching" sub="Match with others on similar routes and timing" on />
        <ToggleRow icon={MapPin} title="Precise location sharing" sub="Share exact GPS instead of general area" on />
        <ToggleRow icon={Volume2} title="Decoy call on SOS" sub="Show a fake incoming call when alert triggers" on />
      </div>
      <p style={{ ...body, fontSize: 10.5, color: T.faint, margin: "12px 24px" }}>
        Audio is processed on your device. Nothing is uploaded unless an SOS is triggered.
      </p>
    </div>
  );
}

export default function App() {
  const [screen, setScreen] = useState("onboarding");
  const [prevScreen, setPrevScreen] = useState("home");

  const goto = (s) => {
    if (screen !== "sos" && screen !== "decoy") setPrevScreen(screen);
    setScreen(s);
  };

  const showNav = ["home", "pod", "contacts", "settings"].includes(screen);
  const showFab = showNav;

  return (
    <div className="w-full flex items-center justify-center py-6" style={{ background: "#E9E2F2", minHeight: 640 }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Fraunces:ital,wght@0,500;0,600;0,700;1,500&family=Manrope:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500&display=swap');
        @keyframes beaconPulse {
          0% { transform: scale(0.75); opacity: 0.55; }
          100% { transform: scale(1.9); opacity: 0; }
        }
      `}</style>

      <div
        style={{
          width: 340,
          height: 700,
          borderRadius: 42,
          background: "#000",
          padding: 10,
          boxShadow: "0 30px 60px rgba(0,0,0,0.5)",
        }}
      >
        <div style={{ width: "100%", height: "100%", borderRadius: 32, overflow: "hidden", position: "relative", background: T.bg }}>
          <StatusBar />
          <div style={{ height: screen === "onboarding" || screen === "decoy" ? "calc(100% - 34px)" : "calc(100% - 34px - 78px)" }}>
            {screen === "onboarding" && <Onboarding onStart={() => goto("home")} />}
            {screen === "home" && <HomeScreen onStartCommute={() => goto("pod")} />}
            {screen === "pod" && <PodScreen onReached={() => goto("home")} />}
            {screen === "contacts" && <ContactsScreen />}
            {screen === "settings" && <SettingsScreen />}
            {screen === "sos" && (
              <SOSTrigger onActivate={() => goto("sos-active")} onDecoy={() => goto("decoy")} onCancel={() => goto(prevScreen)} />
            )}
            {screen === "sos-active" && <SOSActive onResolve={() => goto("home")} />}
            {screen === "decoy" && <DecoyScreen onBack={() => goto("sos")} />}
          </div>

          {showFab && <FloatingSOS onPress={() => goto("sos")} />}
          {showNav && (
            <div style={{ position: "absolute", bottom: 0, left: 0, right: 0 }}>
              <NavBar screen={screen} onNav={goto} />
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
