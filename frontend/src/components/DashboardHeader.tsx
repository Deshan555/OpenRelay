import { Activity, Clock, RefreshCw, Moon, Sun, LogOut } from 'lucide-react';

interface DashboardHeaderProps {
  useWhiteTheme: boolean;
  toggleTheme: () => void;
  refreshInterval: number;
  setRefreshInterval: (val: number) => void;
  fetchDevices: () => void;
  loading: boolean;
  token: string | null;
  handleLogout: () => void;
}

export default function DashboardHeader({
  useWhiteTheme,
  toggleTheme,
  refreshInterval,
  setRefreshInterval,
  fetchDevices,
  loading,
  token,
  handleLogout
}: DashboardHeaderProps) {
  return (
    <header className="max-w-7xl mx-auto mb-8 flex flex-col md:flex-row justify-between items-start md:items-center border-b-2 border-[#111111] pb-5 gap-4">
      <div className="flex items-center gap-3">
        <div className="p-2.5 bg-[#E50012] border-2 border-[#111111] text-white">
          <Activity className="w-7 h-7" />
        </div>
        <div>
          <h1 className="font-bebas text-4xl font-bold tracking-wider text-[#111111] flex items-center gap-2">
            OPENRELAY <span className="font-roboto text-[10px] bg-[#111111] text-white font-black px-2.5 py-1 uppercase tracking-wide">Admin Control Panel</span>
          </h1>
          <p className="font-roboto text-xs font-bold text-gray-600 uppercase tracking-wider mt-0.5">Self-Hosted Cellular SMS Gateway Device Manager</p>
        </div>
      </div>

      <div className="flex flex-wrap items-center gap-2 w-full md:w-auto">
        {/* Autorefresh toggle using Clock icon */}
        <div className="flex items-center gap-1.5 bg-white border-2 border-[#111111] px-2.5 py-2 font-bold" title="Autorefresh Interval">
          <Clock className="w-4 h-4 text-gray-700" />
          <select
            value={refreshInterval}
            onChange={(e) => setRefreshInterval(Number(e.target.value))}
            className="bg-transparent text-[#E50012] focus:outline-none font-black cursor-pointer text-xs uppercase"
          >
            <option value={2}>2s</option>
            <option value={5}>5s</option>
            <option value={10}>10s</option>
            <option value={30}>30s</option>
          </select>
        </div>

        {/* Refresh button as icon */}
        <button
          onClick={fetchDevices}
          className="p-2.5 bg-white hover:bg-gray-150 border-2 border-[#111111] text-[#111111] transition-colors cursor-pointer flex items-center justify-center"
          title="Refresh Devices"
        >
          <RefreshCw className={`w-4 h-4 ${loading ? 'animate-spin' : ''}`} />
        </button>

        {/* Theme background switcher as icon */}
        <button
          onClick={toggleTheme}
          className="p-2.5 bg-white hover:bg-gray-150 border-2 border-[#111111] text-[#111111] transition-colors cursor-pointer flex items-center justify-center"
          title={useWhiteTheme ? "Switch to Off-White Background" : "Switch to White Background"}
        >
          {useWhiteTheme ? <Moon className="w-4 h-4" /> : <Sun className="w-4 h-4" />}
        </button>

        {/* Logout button as icon */}
        {token && (
          <button
            onClick={handleLogout}
            className="p-2.5 bg-[#FFEBEE] hover:bg-[#FFCDD2] text-[#E50012] border-2 border-[#111111] transition-colors cursor-pointer flex items-center justify-center"
            title="Logout Admin Session"
          >
            <LogOut className="w-4 h-4" />
          </button>
        )}
      </div>
    </header>
  );
}
