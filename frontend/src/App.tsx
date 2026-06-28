import React, { useState, useEffect } from 'react';
import { 
  Smartphone, 
  Send, 
  RefreshCw, 
  Battery, 
  Signal, 
  MapPin, 
  AlertTriangle, 
  CheckCircle2, 
  Activity, 
  ShieldCheck, 
  Sliders
} from 'lucide-react';

interface Device {
  uuid: string;
  name: string | null;
  model: string | null;
  android_version: string | null;
  battery: number | null;
  carrier: string | null;
  signal: number | null;
  status: string;
  last_seen: string;
  latitude: number | null;
  longitude: number | null;
}

const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000';

function App() {
  const [devices, setDevices] = useState<Device[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const [selectedDevice, setSelectedDevice] = useState<string>('');
  const [smsTo, setSmsTo] = useState<string>('');
  const [smsMessage, setSmsMessage] = useState<string>('');
  const [sendStatus, setSendStatus] = useState<{ success?: boolean; message: string } | null>(null);
  const [isSending, setIsSending] = useState<boolean>(false);
  const [refreshInterval, setRefreshInterval] = useState<number>(5); // seconds

  const fetchDevices = async () => {
    try {
      setLoading(true);
      const res = await fetch(`${API_BASE_URL}/devices/`);
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

  useEffect(() => {
    fetchDevices();
  }, []);

  // Poll for updates
  useEffect(() => {
    const timer = setInterval(() => {
      fetchDevices();
    }, refreshInterval * 1000);
    return () => clearInterval(timer);
  }, [refreshInterval, selectedDevice]);

  const handleSendSms = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedDevice || !smsTo || !smsMessage) return;

    setIsSending(true);
    setSendStatus(null);

    try {
      const res = await fetch(`${API_BASE_URL}/sms/send`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          device: selectedDevice,
          to: smsTo,
          message: smsMessage
        })
      });

      const data = await res.json();
      if (res.ok) {
        setSendStatus({
          success: true,
          message: `SMS job queued successfully! Job ID: ${data.jobId}`
        });
        setSmsMessage('');
      } else {
        setSendStatus({
          success: false,
          message: data.detail || 'Failed to queue SMS job.'
        });
      }
    } catch (err) {
      setSendStatus({
        success: false,
        message: 'Could not connect to backend server.'
      });
    } finally {
      setIsSending(false);
    }
  };

  const totalDevices = devices.length;
  const onlineDevices = devices.filter(d => d.status === 'online').length;

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 p-6">
      {/* Header */}
      <header className="max-w-7xl mx-auto mb-8 flex justify-between items-center border-b border-slate-800 pb-5">
        <div className="flex items-center gap-3">
          <div className="p-2.5 bg-blue-600/10 border border-blue-500/20 rounded-xl text-blue-500 shadow-lg shadow-blue-500/5">
            <Activity className="w-7 h-7" />
          </div>
          <div>
            <h1 className="text-2xl font-bold tracking-tight text-white flex items-center gap-2">
              OpenRelay <span className="text-xs bg-slate-800 text-slate-400 font-medium px-2 py-0.5 rounded-full border border-slate-700">Admin Control Panel</span>
            </h1>
            <p className="text-xs text-slate-400">Self-Hosted SMS Gateway Device Manager</p>
          </div>
        </div>

        <div className="flex items-center gap-4">
          <div className="flex items-center gap-2 text-xs bg-slate-900 border border-slate-800 rounded-lg p-2">
            <span className="text-slate-400">Autorefresh:</span>
            <select 
              value={refreshInterval} 
              onChange={(e) => setRefreshInterval(Number(e.target.value))}
              className="bg-transparent text-blue-400 focus:outline-none font-semibold cursor-pointer"
            >
              <option value={2}>2s</option>
              <option value={5}>5s</option>
              <option value={10}>10s</option>
              <option value={30}>30s</option>
            </select>
          </div>

          <button 
            onClick={fetchDevices} 
            className="flex items-center gap-2 text-xs bg-slate-800 hover:bg-slate-700 border border-slate-700 hover:border-slate-600 transition-colors font-medium px-3.5 py-2 rounded-lg"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} />
            Refresh
          </button>
        </div>
      </header>

      {/* Main Grid */}
      <main className="max-w-7xl mx-auto space-y-6">
        
        {/* Stats Cards */}
        <section className="grid grid-cols-1 sm:grid-cols-3 gap-6">
          <div className="bg-slate-900/40 backdrop-blur-md border border-slate-800/80 p-5 rounded-2xl flex items-center justify-between">
            <div>
              <p className="text-xs font-semibold uppercase tracking-wider text-slate-400">Total Registered Devices</p>
              <h3 className="text-3xl font-extrabold text-white mt-1">{totalDevices}</h3>
            </div>
            <div className="p-3 bg-slate-800/60 rounded-xl text-slate-400 border border-slate-700/50">
              <Smartphone className="w-6 h-6" />
            </div>
          </div>

          <div className="bg-slate-900/40 backdrop-blur-md border border-slate-800/80 p-5 rounded-2xl flex items-center justify-between">
            <div>
              <p className="text-xs font-semibold uppercase tracking-wider text-slate-400">Online Devices</p>
              <h3 className="text-3xl font-extrabold text-emerald-400 mt-1 flex items-center gap-2">
                {onlineDevices}
                {onlineDevices > 0 && <span className="inline-block w-2.5 h-2.5 rounded-full bg-emerald-400 animate-pulse"></span>}
              </h3>
            </div>
            <div className="p-3 bg-emerald-500/10 rounded-xl text-emerald-400 border border-emerald-500/20">
              <ShieldCheck className="w-6 h-6" />
            </div>
          </div>

          <div className="bg-slate-900/40 backdrop-blur-md border border-slate-800/80 p-5 rounded-2xl flex items-center justify-between">
            <div>
              <p className="text-xs font-semibold uppercase tracking-wider text-slate-400">Backend Connection</p>
              <h3 className="text-sm font-bold text-slate-200 mt-2 truncate max-w-[200px]">
                {API_BASE_URL}
              </h3>
            </div>
            <div className="p-3 bg-blue-500/10 rounded-xl text-blue-400 border border-blue-500/20">
              <Sliders className="w-6 h-6" />
            </div>
          </div>
        </section>

        {/* Dashboard Panels */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 items-start">
          
          {/* Registered Devices List */}
          <section className="lg:col-span-2 space-y-4">
            <h2 className="text-lg font-bold text-white flex items-center gap-2">
              Registered Devices
              <span className="text-xs bg-slate-800 text-slate-400 px-2 py-0.5 rounded-md border border-slate-700">Live Status</span>
            </h2>

            {devices.length === 0 ? (
              <div className="bg-slate-900/30 border border-slate-850 p-8 rounded-2xl text-center">
                <Smartphone className="w-12 h-12 text-slate-600 mx-auto mb-3" />
                <p className="text-slate-450 text-sm">No registered devices found.</p>
                <p className="text-slate-500 text-xs mt-1">Start the device simulator to register a test device.</p>
              </div>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {devices.map((device) => {
                  const isOnline = device.status === 'online';
                  return (
                    <div 
                      key={device.uuid} 
                      className={`bg-slate-900/50 backdrop-blur-md border rounded-2xl p-5 hover:border-slate-700 transition-all ${
                        isOnline ? 'border-slate-800 shadow-md shadow-emerald-500/2' : 'border-slate-850 opacity-70'
                      }`}
                    >
                      {/* Name & Status Header */}
                      <div className="flex justify-between items-start mb-3.5">
                        <div>
                          <h3 className="font-semibold text-slate-200 text-sm truncate max-w-[170px]">
                            {device.name || 'Unnamed Device'}
                          </h3>
                          <p className="text-xs text-slate-500 font-mono mt-0.5 truncate max-w-[170px]">
                            UUID: {device.uuid}
                          </p>
                        </div>
                        <span className={`inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-semibold ${
                          isOnline ? 'bg-emerald-500/10 text-emerald-400 border border-emerald-500/20' : 'bg-slate-800 text-slate-400 border border-slate-700'
                        }`}>
                          <span className={`w-1.5 h-1.5 rounded-full ${isOnline ? 'bg-emerald-400 animate-pulse' : 'bg-slate-500'}`}></span>
                          {device.status}
                        </span>
                      </div>

                      {/* Device specifications grid */}
                      <div className="grid grid-cols-2 gap-y-3 gap-x-2 border-t border-b border-slate-800/80 py-3.5 my-3 text-xs text-slate-400">
                        <div>
                          <span className="block text-slate-500 text-[10px] uppercase font-medium">Model</span>
                          <span className="text-slate-350">{device.model || 'Unknown'}</span>
                        </div>
                        <div>
                          <span className="block text-slate-500 text-[10px] uppercase font-medium">Android OS</span>
                          <span className="text-slate-350">{device.android_version || 'Unknown'}</span>
                        </div>
                        <div>
                          <span className="block text-slate-500 text-[10px] uppercase font-medium">Carrier</span>
                          <span className="text-slate-350 truncate block">{device.carrier || 'Unknown'}</span>
                        </div>
                        <div>
                          <span className="block text-slate-500 text-[10px] uppercase font-medium">Last Ping</span>
                          <span className="text-slate-350">
                            {device.last_seen ? new Date(device.last_seen).toLocaleTimeString() : 'Never'}
                          </span>
                        </div>
                      </div>

                      {/* Hardware stats */}
                      <div className="flex justify-between items-center gap-3 mt-3 text-xs text-slate-400">
                        {/* Battery Level */}
                        <div className="flex items-center gap-1.5">
                          <Battery className={`w-4 h-4 ${
                            device.battery && device.battery < 20 ? 'text-red-500 animate-bounce' : 'text-slate-450'
                          }`} />
                          <span>{device.battery !== null ? `${device.battery}%` : 'N/A'}</span>
                        </div>

                        {/* Signal level */}
                        <div className="flex items-center gap-1.5">
                          <Signal className="w-4 h-4 text-slate-450" />
                          <span>{device.signal !== null ? `${device.signal}/4` : 'N/A'}</span>
                        </div>

                        {/* Geolocation coordinates */}
                        <div className="flex items-center gap-1 truncate max-w-[120px]">
                          <MapPin className="w-4 h-4 text-slate-450 flex-shrink-0" />
                          <span className="truncate">
                            {device.latitude !== null && device.longitude !== null 
                              ? `${device.latitude.toFixed(3)}, ${device.longitude.toFixed(3)}`
                              : 'No GPS'
                            }
                          </span>
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </section>

          {/* Quick Send SMS Form */}
          <section className="space-y-4">
            <h2 className="text-lg font-bold text-white flex items-center gap-2">
              SMS Console
              <span className="text-xs bg-slate-800 text-slate-400 px-2 py-0.5 rounded-md border border-slate-700">Quick Send</span>
            </h2>

            <div className="bg-slate-900/50 backdrop-blur-md border border-slate-800 p-5 rounded-2xl">
              <form onSubmit={handleSendSms} className="space-y-4">
                
                {/* Target device select dropdown */}
                <div>
                  <label className="block text-xs font-semibold text-slate-400 mb-1.5 uppercase tracking-wide">Target Device</label>
                  <select
                    value={selectedDevice}
                    onChange={(e) => setSelectedDevice(e.target.value)}
                    required
                    className="w-full bg-slate-950 border border-slate-800 focus:border-blue-500 focus:ring-1 focus:ring-blue-500 rounded-xl px-3.5 py-2.5 text-slate-200 text-sm focus:outline-none transition-colors"
                  >
                    <option value="">-- Choose a Device --</option>
                    {devices.map((device) => (
                      <option key={device.uuid} value={device.uuid}>
                        {device.name || 'Device'} ({device.status === 'online' ? 'Online' : 'Offline'}) - {device.uuid.slice(0, 8)}...
                      </option>
                    ))}
                  </select>
                </div>

                {/* Recipient Input */}
                <div>
                  <label className="block text-xs font-semibold text-slate-400 mb-1.5 uppercase tracking-wide">Recipient Number</label>
                  <input
                    type="tel"
                    placeholder="e.g. +94771234567"
                    value={smsTo}
                    onChange={(e) => setSmsTo(e.target.value)}
                    required
                    className="w-full bg-slate-950 border border-slate-800 focus:border-blue-500 focus:ring-1 focus:ring-blue-500 rounded-xl px-3.5 py-2.5 text-slate-200 text-sm focus:outline-none transition-colors"
                  />
                </div>

                {/* Message text area */}
                <div>
                  <label className="block text-xs font-semibold text-slate-400 mb-1.5 uppercase tracking-wide">SMS Message</label>
                  <textarea
                    placeholder="Enter message text here..."
                    rows={4}
                    value={smsMessage}
                    onChange={(e) => setSmsMessage(e.target.value)}
                    required
                    maxLength={160}
                    className="w-full bg-slate-950 border border-slate-800 focus:border-blue-500 focus:ring-1 focus:ring-blue-500 rounded-xl px-3.5 py-2.5 text-slate-200 text-sm focus:outline-none transition-colors resize-none"
                  ></textarea>
                  <span className="text-[10px] text-slate-500 block text-right mt-1">
                    {smsMessage.length}/160 characters
                  </span>
                </div>

                {/* Send Button */}
                <button
                  type="submit"
                  disabled={isSending || !selectedDevice}
                  className="w-full flex items-center justify-center gap-2 bg-blue-600 hover:bg-blue-500 disabled:bg-slate-800 disabled:text-slate-500 transition-colors text-white font-semibold py-3 px-4 rounded-xl text-sm focus:outline-none"
                >
                  <Send className="w-4 h-4" />
                  {isSending ? 'Sending Live Push...' : 'Send SMS Message'}
                </button>
              </form>

              {/* Status Alert panel */}
              {sendStatus && (
                <div className={`mt-4 p-4 rounded-xl border flex gap-3 text-xs ${
                  sendStatus.success 
                    ? 'bg-emerald-500/10 border-emerald-500/20 text-emerald-400' 
                    : 'bg-rose-500/10 border-rose-500/20 text-rose-450'
                }`}>
                  {sendStatus.success ? (
                    <CheckCircle2 className="w-5 h-5 flex-shrink-0" />
                  ) : (
                    <AlertTriangle className="w-5 h-5 flex-shrink-0" />
                  )}
                  <div>
                    <h4 className="font-bold">{sendStatus.success ? 'Success' : 'Error'}</h4>
                    <p className="mt-0.5 leading-relaxed">{sendStatus.message}</p>
                  </div>
                </div>
              )}
            </div>
          </section>
        </div>
      </main>
    </div>
  );
}

export default App;
