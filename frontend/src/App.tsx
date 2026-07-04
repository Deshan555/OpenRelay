import { useState, useEffect } from 'react';
import {
  Smartphone,
  Send,
  Activity,
  Sliders,
  History,
  FileSpreadsheet,
  Shield
} from 'lucide-react';

import { type Device, API_BASE_URL } from './types';
import SetupScreen from './components/SetupScreen';
import LoginScreen from './components/LoginScreen';
import DashboardHeader from './components/DashboardHeader';
import DevicesTab from './components/DevicesTab';
import SmsTab from './components/SmsTab';
import BulkTab from './components/BulkTab';
import LogsTab from './components/LogsTab';
import QueueFlowTab from './components/QueueFlowTab';
import AdminTab from './components/AdminTab';

function App() {
  const [devices, setDevices] = useState<Device[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const [selectedDevice, setSelectedDevice] = useState<string>('');
  
  // Theme Background Selection
  const [useWhiteTheme, setUseWhiteTheme] = useState<boolean>(() => {
    return localStorage.getItem('theme_use_white') === 'true';
  });

  // Autorefresh Interval
  const [refreshInterval, setRefreshInterval] = useState<number>(() => {
    return Number(localStorage.getItem('refresh_interval')) || 5;
  });

  // Layout Tab selection
  const [activeTab, setActiveTab] = useState<'devices' | 'sms' | 'bulk' | 'logs' | 'flow' | 'admin'>('devices');

  // Authentication states
  const [token, setToken] = useState<string | null>(() => {
    return localStorage.getItem('admin_token');
  });
  const [adminUsername, setAdminUsername] = useState<string | null>(() => {
    return localStorage.getItem('admin_username');
  });
  const [setupRequired, setSetupRequired] = useState<boolean>(false);
  const [checkingSetup, setCheckingSetup] = useState<boolean>(true);

  const getAuthHeaders = (extraHeaders: Record<string, string> = {}) => {
    return {
      ...extraHeaders,
      ...(token ? { 'Authorization': `Bearer ${token}` } : {})
    };
  };

  const handleLogout = () => {
    setToken(null);
    setAdminUsername(null);
    localStorage.removeItem('admin_token');
    localStorage.removeItem('admin_username');
  };

  const handleAuthSuccess = (tokenVal: string, usernameVal: string) => {
    setToken(tokenVal);
    setAdminUsername(usernameVal);
    localStorage.setItem('admin_token', tokenVal);
    localStorage.setItem('admin_username', usernameVal);
  };

  // Check system setup on mount and token changes
  useEffect(() => {
    if (adminUsername) {
      console.debug(`Active admin session: ${adminUsername}`);
    }
    const checkSetup = async () => {
      try {
        setCheckingSetup(true);
        const res = await fetch(`${API_BASE_URL}/api/v2/admin/setup-check`);
        if (res.ok) {
          const data = await res.json();
          setSetupRequired(data.setup_required);
        }
      } catch (err) {
        console.error("Error checking setup:", err);
      } finally {
        setCheckingSetup(false);
      }
    };
    checkSetup();
  }, [token, adminUsername]);

  const toggleTheme = () => {
    const val = !useWhiteTheme;
    setUseWhiteTheme(val);
    localStorage.setItem('theme_use_white', String(val));
  };

  // Persist refresh interval settings
  useEffect(() => {
    localStorage.setItem('refresh_interval', String(refreshInterval));
  }, [refreshInterval]);

  const fetchDevices = async () => {
    if (!token) return;
    try {
      setLoading(true);
      const res = await fetch(`${API_BASE_URL}/api/v2/devices/`, { headers: getAuthHeaders() });
      if (res.ok) {
        const data = await res.json();
        setDevices(data);

        // Auto-select first online device if none selected
        if (data.length > 0 && !selectedDevice) {
          const firstOnline = data.find((d: Device) => d.status === 'online');
          if (firstOnline) {
            setSelectedDevice(firstOnline.uuid);
          } else {
            setSelectedDevice(data[0].uuid);
          }
        }
      }
    } catch (err) {
      console.error("Error fetching devices:", err);
    } finally {
      setLoading(false);
    }
  };

  // Fetch devices on mount, token change
  useEffect(() => {
    fetchDevices();
  }, [token]);

  // Autorefresh device listings
  useEffect(() => {
    if (!token) return;
    const timer = setInterval(() => {
      fetchDevices();
    }, refreshInterval * 1000);
    return () => clearInterval(timer);
  }, [refreshInterval, selectedDevice, token]);

  if (checkingSetup) {
    return (
      <div className="min-h-screen bg-[#F5F5F5] flex flex-col items-center justify-center p-6 text-center select-none font-roboto">
        <div className="bg-white border-2 border-[#111111] p-10 max-w-sm w-full shadow-[6px_6px_0px_0px_rgba(17,17,17,1)] flex flex-col items-center">
          <Activity className="w-14 h-14 text-[#E50012] animate-pulse mb-4" />
          <h2 className="font-bebas text-3xl font-bold tracking-wider text-[#111111] mb-1">
            OPENRELAY GATEWAY
          </h2>
          <p className="text-xs font-bold text-gray-500 uppercase tracking-widest animate-pulse font-mono">
            Checking system status...
          </p>
        </div>
      </div>
    );
  }

  if (setupRequired) {
    return <SetupScreen onInitialize={handleAuthSuccess} />;
  }

  if (!token) {
    return <LoginScreen onLogin={handleAuthSuccess} />;
  }

  const totalDevices = devices.length;
  const onlineDevices = devices.filter(d => d.status === 'online').length;

  return (
    <div className={`min-h-screen ${useWhiteTheme ? 'bg-white' : 'bg-[#F5F5F5]'} text-[#111111] p-6 font-roboto transition-colors duration-200`}>
      <DashboardHeader
        useWhiteTheme={useWhiteTheme}
        toggleTheme={toggleTheme}
        refreshInterval={refreshInterval}
        setRefreshInterval={setRefreshInterval}
        fetchDevices={fetchDevices}
        loading={loading}
        token={token}
        handleLogout={handleLogout}
      />

      <main className="max-w-7xl mx-auto space-y-6">
        {/* Stats Cards */}
        {activeTab === 'devices' && (
          <section className="grid grid-cols-1 sm:grid-cols-3 gap-6">
            <div className="bg-white border-2 border-[#111111] p-5 flex items-center justify-between">
              <div>
                <span className="block text-[10px] font-black text-gray-500 uppercase tracking-wider">Device Gateways</span>
                <span className="font-bebas text-4xl font-bold text-[#111111] tracking-wide mt-1 block">{onlineDevices} / {totalDevices} Online</span>
              </div>
              <div className="p-3 bg-[#E8F5E9] border-2 border-[#111111] text-[#2E7D32]">
                <Smartphone className="w-6 h-6" />
              </div>
            </div>
            <div className="bg-white border-2 border-[#111111] p-5 flex items-center justify-between">
              <div>
                <span className="block text-[10px] font-black text-gray-500 uppercase tracking-wider">Quick actions</span>
                <span className="font-bebas text-4xl font-bold text-[#111111] tracking-wide mt-1 block">Live SMS Push</span>
              </div>
              <div className="p-3 bg-[#E3F2FD] border-2 border-[#111111] text-[#0288D1]">
                <Send className="w-6 h-6" />
              </div>
            </div>
            <div className="bg-white border-2 border-[#111111] p-5 flex items-center justify-between">
              <div>
                <span className="block text-[10px] font-black text-gray-500 uppercase tracking-wider">System Access</span>
                <span className="font-bebas text-4xl font-bold text-[#111111] tracking-wide mt-1 block">Security Enabled</span>
              </div>
              <div className="p-3 bg-[#FFEBEE] border-2 border-[#E50012] text-[#E50012]">
                <Sliders className="w-6 h-6" />
              </div>
            </div>
          </section>
        )}

        {/* Tab Navigation */}
        <div className="flex flex-wrap gap-2.5 border-b-2 border-[#111111] pb-5">
          <button
            onClick={() => setActiveTab('devices')}
            className={`flex items-center gap-2 px-5 py-3 border-2 border-[#111111] font-black uppercase text-xs tracking-wider transition-all duration-100 cursor-pointer ${
              activeTab === 'devices'
                ? 'bg-[#111111] text-white shadow-none translate-x-0.5 translate-y-0.5'
                : 'bg-white text-[#111111] hover:bg-gray-50 hover:shadow-[2px_2px_0px_0px_rgba(17,17,17,1)]'
            }`}
          >
            <Smartphone className="w-4 h-4" />
            Registered Devices ({totalDevices})
          </button>
          <button
            onClick={() => setActiveTab('sms')}
            className={`flex items-center gap-2 px-5 py-3 border-2 border-[#111111] font-black uppercase text-xs tracking-wider transition-all duration-100 cursor-pointer ${
              activeTab === 'sms'
                ? 'bg-[#111111] text-white shadow-none translate-x-0.5 translate-y-0.5'
                : 'bg-white text-[#111111] hover:bg-gray-50 hover:shadow-[2px_2px_0px_0px_rgba(17,17,17,1)]'
            }`}
          >
            <Send className="w-4 h-4" />
            SMS Console
          </button>
          <button
            onClick={() => setActiveTab('bulk')}
            className={`flex items-center gap-2 px-5 py-3 border-2 border-[#111111] font-black uppercase text-xs tracking-wider transition-all duration-100 cursor-pointer ${
              activeTab === 'bulk'
                ? 'bg-[#111111] text-white shadow-none translate-x-0.5 translate-y-0.5'
                : 'bg-white text-[#111111] hover:bg-gray-50 hover:shadow-[2px_2px_0px_0px_rgba(17,17,17,1)]'
            }`}
          >
            <FileSpreadsheet className="w-4 h-4" />
            Bulk SMS Upload
          </button>
          <button
            onClick={() => setActiveTab('logs')}
            className={`flex items-center gap-2 px-5 py-3 border-2 border-[#111111] font-black uppercase text-xs tracking-wider transition-all duration-100 cursor-pointer ${
              activeTab === 'logs'
                ? 'bg-[#111111] text-white shadow-none translate-x-0.5 translate-y-0.5'
                : 'bg-white text-[#111111] hover:bg-gray-50 hover:shadow-[2px_2px_0px_0px_rgba(17,17,17,1)]'
            }`}
          >
            <History className="w-4 h-4" />
            Sending History
          </button>
          <button
            onClick={() => setActiveTab('flow')}
            className={`flex items-center gap-2 px-5 py-3 border-2 border-[#111111] font-black uppercase text-xs tracking-wider transition-all duration-100 cursor-pointer ${
              activeTab === 'flow'
                ? 'bg-[#111111] text-white shadow-none translate-x-0.5 translate-y-0.5'
                : 'bg-white text-[#111111] hover:bg-gray-50 hover:shadow-[2px_2px_0px_0px_rgba(17,17,17,1)]'
            }`}
          >
            <Activity className="w-4 h-4" />
            Queue Flow
          </button>
          <button
            onClick={() => setActiveTab('admin')}
            className={`flex items-center gap-2 px-5 py-3 border-2 border-[#111111] font-black uppercase text-xs tracking-wider transition-all duration-100 cursor-pointer ${
              activeTab === 'admin'
                ? 'bg-[#111111] text-white shadow-none translate-x-0.5 translate-y-0.5'
                : 'bg-white text-[#111111] hover:bg-gray-50 hover:shadow-[2px_2px_0px_0px_rgba(17,17,17,1)]'
            }`}
          >
            <Shield className="w-4 h-4" />
            Admins
          </button>
        </div>

        {/* Tab Content Panels */}
        <div className="mt-2">
          {activeTab === 'devices' && (
            <DevicesTab
              devices={devices}
              loading={loading}
              fetchDevices={fetchDevices}
              getAuthHeaders={getAuthHeaders}
            />
          )}

          {activeTab === 'sms' && (
            <SmsTab
              devices={devices}
              selectedDevice={selectedDevice}
              setSelectedDevice={setSelectedDevice}
              apiVersion="v2"
              getAuthHeaders={getAuthHeaders}
              fetchLogs={() => {}}
            />
          )}

          {activeTab === 'bulk' && (
            <BulkTab getAuthHeaders={getAuthHeaders} />
          )}

          {activeTab === 'logs' && (
            <LogsTab getAuthHeaders={getAuthHeaders} />
          )}

          {activeTab === 'flow' && (
            <QueueFlowTab getAuthHeaders={getAuthHeaders} />
          )}

          {activeTab === 'admin' && (
            <AdminTab
              getAuthHeaders={getAuthHeaders}
              currentAdminUsername={adminUsername}
            />
          )}
        </div>
      </main>
    </div>
  );
}

export default App;
