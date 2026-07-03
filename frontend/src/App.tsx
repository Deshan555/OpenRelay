import React, { useState, useEffect } from 'react';
import {
  Smartphone,
  Send,
  RefreshCw,
  Battery as BatteryIcon,
  Signal as SignalIcon,
  MapPin,
  AlertTriangle,
  CheckCircle2,
  Activity,
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
  const [apiVersion, setApiVersion] = useState<'v1' | 'v2'>('v1');

  // Theme Background toggle (White vs Off-white)
  const [useWhiteTheme, setUseWhiteTheme] = useState<boolean>(() => {
    return localStorage.getItem('web_use_white_theme') === 'true';
  });

  const toggleTheme = () => {
    const newValue = !useWhiteTheme;
    setUseWhiteTheme(newValue);
    localStorage.setItem('web_use_white_theme', String(newValue));
  };

  const fetchDevices = async () => {
    try {
      setLoading(true);
      const res = await fetch(`${API_BASE_URL}/api/${apiVersion}/devices/`);
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
  }, [apiVersion]);

  // Poll for updates
  useEffect(() => {
    const timer = setInterval(() => {
      fetchDevices();
    }, refreshInterval * 1000);
    return () => clearInterval(timer);
  }, [refreshInterval, selectedDevice, apiVersion]);

  const handleSendSms = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedDevice || !smsTo || !smsMessage) return;

    setIsSending(true);
    setSendStatus(null);

    try {
      const isV2 = apiVersion === 'v2';
      const bodyPayload = isV2
        ? { device_id: selectedDevice, to: smsTo, message: smsMessage }
        : { device: selectedDevice, to: smsTo, message: smsMessage };

      const res = await fetch(`${API_BASE_URL}/api/${apiVersion}/sms/send`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(bodyPayload)
      });

      const data = await res.json();
      if (res.ok) {
        const jobId = isV2 ? data.job_id : data.jobId;
        setSendStatus({
          success: true,
          message: `SMS job queued successfully! Job ID: ${jobId} (via API ${apiVersion.toUpperCase()})`
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
    <div className={`min-h-screen ${useWhiteTheme ? 'bg-white' : 'bg-[#F5F5F5]'} text-[#111111] p-6 font-roboto transition-colors duration-200`}>
      {/* Header */}
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

        <div className="flex flex-wrap items-center gap-3 w-full md:w-auto">
          {/* Theme background switcher */}
          <button
            onClick={toggleTheme}
            className="flex items-center gap-2 text-xs bg-white hover:bg-gray-150 border-2 border-[#111111] font-black uppercase px-3.5 py-2.5 transition-colors"
          >
            THEME BACKGROUND: {useWhiteTheme ? 'WHITE' : 'OFF-WHITE'}
          </button>

          <div className="flex items-center gap-2 text-xs bg-white border-2 border-[#111111] p-2.5 font-bold">
            <span className="text-gray-600 uppercase tracking-wide text-[10px] font-black">API Version:</span>
            <select
              value={apiVersion}
              onChange={(e) => setApiVersion(e.target.value as 'v1' | 'v2')}
              className="bg-transparent text-[#E50012] focus:outline-none font-black cursor-pointer uppercase"
            >
              <option value="v1">v1 (Legacy)</option>
              <option value="v2">v2 (snake_case)</option>
            </select>
          </div>

          <div className="flex items-center gap-2 text-xs bg-white border-2 border-[#111111] p-2.5 font-bold">
            <span className="text-gray-600 uppercase tracking-wide text-[10px] font-black">Autorefresh:</span>
            <select
              value={refreshInterval}
              onChange={(e) => setRefreshInterval(Number(e.target.value))}
              className="bg-transparent text-[#E50012] focus:outline-none font-black cursor-pointer uppercase"
            >
              <option value={2}>2s</option>
              <option value={5}>5s</option>
              <option value={10}>10s</option>
              <option value={30}>30s</option>
            </select>
          </div>

          <button
            onClick={fetchDevices}
            className="flex items-center gap-2 text-xs bg-[#E50012] hover:bg-[#B3000E] border-2 border-[#111111] text-white font-black uppercase px-4 py-2.5 transition-colors"
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
          <div className="bg-white border-2 border-[#111111] p-5 flex items-center justify-between">
            <div>
              <p className="text-[11px] font-black uppercase tracking-wider text-gray-700 font-roboto">Total Registered Devices</p>
              <h3 className="font-bebas text-5xl font-bold text-[#111111] mt-2 leading-none">{totalDevices}</h3>
              <div className="w-8 h-1 bg-[#111111] mt-4"></div>
            </div>
            <div className="p-3 bg-[#F5F5F5] border-2 border-[#111111] text-[#111111]">
              <Smartphone className="w-6 h-6" />
            </div>
          </div>

          <div className="bg-white border-2 border-[#111111] p-5 flex items-center justify-between">
            <div>
              <p className="text-[11px] font-black uppercase tracking-wider text-gray-700 font-roboto">Online Devices</p>
              <h3 className="font-bebas text-5xl font-bold text-[#2E7D32] mt-2 leading-none flex items-center gap-2">
                {onlineDevices}
                {onlineDevices > 0 && <span className="inline-block w-2.5 h-2.5 rounded-full bg-[#2E7D32] animate-pulse"></span>}
              </h3>
              <div className="w-8 h-1 bg-[#2E7D32] mt-4"></div>
            </div>
            <div className="p-3 bg-[#E8F5E9] border-2 border-[#2E7D32] text-[#2E7D32]">
              <CheckCircle2 className="w-6 h-6" />
            </div>
          </div>

          <div className="bg-white border-2 border-[#111111] p-5 flex items-center justify-between">
            <div>
              <p className="text-[11px] font-black uppercase tracking-wider text-gray-700 font-roboto">Backend Connection</p>
              <h3 className="font-roboto text-sm font-bold text-gray-800 mt-3 truncate max-w-[220px]">
                {API_BASE_URL}
              </h3>
              <div className="w-8 h-1 bg-[#E50012] mt-4"></div>
            </div>
            <div className="p-3 bg-[#FFEBEE] border-2 border-[#E50012] text-[#E50012]">
              <Sliders className="w-6 h-6" />
            </div>
          </div>
        </section>

        {/* Dashboard Panels */}
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 items-start">

          {/* Registered Devices List */}
          <section className="lg:col-span-2 space-y-4">
            <h2 className="font-bebas text-2xl font-bold tracking-wider text-[#111111] flex items-center gap-2">
              REGISTERED DEVICES
              <span className="font-roboto text-[9px] bg-[#111111] text-white px-2 py-0.5 font-bold uppercase tracking-wider">LIVE STATUS</span>
            </h2>

            {devices.length === 0 ? (
              <div className="bg-white border-2 border-[#111111] p-8 text-center">
                <Smartphone className="w-12 h-12 text-gray-400 mx-auto mb-3" />
                <p className="font-roboto text-sm font-bold text-gray-700 uppercase">No registered devices found.</p>
                <p className="font-roboto text-xs text-gray-500 mt-1">Start the device simulator to register a test device.</p>
              </div>
            ) : (
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {devices.map((device) => {
                  const isOnline = device.status === 'online';

                  // Custom battery percentage bar logic
                  const batteryLevel = device.battery !== null ? Math.max(0, Math.min(100, device.battery)) : 64;
                  const redFlex = batteryLevel;
                  const blackFlex = 100 - redFlex;

                  // Signal bars logic matching flutter app (4 vertical bars)
                  const signalStrength = device.signal !== null ? device.signal : 3;

                  return (
                    <div
                      key={device.uuid}
                      className={`bg-white border-2 border-[#111111] p-5 transition-all duration-150 hover:translate-x-0.5 hover:translate-y-0.5 hover:shadow-[4px_4px_0px_0px_rgba(17,17,17,1)] ${isOnline ? 'opacity-100' : 'opacity-70'
                        }`}
                    >
                      {/* Name & Status Header */}
                      <div className="flex justify-between items-start mb-3.5">
                        <div>
                          <h3 className="font-bebas text-2xl font-bold text-[#111111] tracking-wide truncate max-w-[170px]">
                            {device.name?.toUpperCase() || 'UNNAMED DEVICE'}
                          </h3>
                          <p className="font-roboto text-[10px] text-gray-500 font-black mt-0.5 truncate max-w-[170px]">
                            UUID: {device.uuid}
                          </p>
                        </div>
                        <span className={`inline-flex items-center gap-1.5 px-3 py-1 border-2 border-[#111111] text-[10px] font-black uppercase ${isOnline ? 'bg-[#E8F5E9] text-[#2E7D32]' : 'bg-gray-150 text-gray-600'
                          }`}>
                          <span className={`w-2 h-2 rounded-full ${isOnline ? 'bg-[#2E7D32] animate-pulse' : 'bg-gray-500'}`}></span>
                          {device.status}
                        </span>
                      </div>

                      {/* Device specifications grid (with dividers like the table in flutter) */}
                      <div className="grid grid-cols-2 gap-y-3.5 gap-x-2 border-t border-b border-[#111111] py-3.5 my-3.5 text-xs">
                        <div>
                          <span className="block text-gray-500 text-[10px] uppercase font-black tracking-wider">Model</span>
                          <span className="font-bold text-[#111111] font-mono">{device.model || 'Unknown'}</span>
                        </div>
                        <div>
                          <span className="block text-gray-500 text-[10px] uppercase font-black tracking-wider">Android OS</span>
                          <span className="font-bold text-[#111111] font-mono">{device.android_version || 'Unknown'}</span>
                        </div>
                        <div>
                          <span className="block text-gray-500 text-[10px] uppercase font-black tracking-wider">Carrier</span>
                          <span className="font-bold text-[#111111] truncate block">{device.carrier || 'Unknown'}</span>
                        </div>
                        <div>
                          <span className="block text-gray-500 text-[10px] uppercase font-black tracking-wider">Last Ping</span>
                          <span className="font-bold text-[#111111] font-mono">
                            {device.last_seen ? new Date(device.last_seen).toLocaleTimeString() : 'Never'}
                          </span>
                        </div>
                      </div>

                      {/* Hardware stats */}
                      <div className="grid grid-cols-3 gap-2 mt-4 items-center">
                        {/* Battery Level */}
                        <div className="flex flex-col items-start">
                          <span className="text-[10px] font-black text-gray-500 uppercase tracking-wider">Battery</span>
                          <div className="flex items-center gap-1.5 mt-1">
                            <BatteryIcon className={`w-4 h-4 ${device.battery && device.battery < 20 ? 'text-[#E50012] animate-bounce' : 'text-[#111111]'
                              }`} />
                            <span className="font-bebas text-lg font-bold text-[#111111]">{device.battery !== null ? `${device.battery}%` : 'N/A'}</span>
                          </div>
                          {/* Custom Flat Battery Bar (Red left, Black right) matching Mobile App */}
                          <div className="h-1.5 w-full border border-[#111111] flex mt-1 bg-[#111111]">
                            {redFlex > 0 && <div className="bg-[#E50012] h-full" style={{ width: `${redFlex}%` }} />}
                            {blackFlex > 0 && <div className="bg-[#111111] h-full" style={{ width: `${blackFlex}%` }} />}
                          </div>
                        </div>

                        {/* Signal level */}
                        <div className="flex flex-col items-start pl-2 border-l border-gray-300">
                          <span className="text-[10px] font-black text-gray-500 uppercase tracking-wider">Signal</span>
                          <div className="flex items-center gap-2 mt-1">
                            {/* Vertical signal bars */}
                            <div className="flex items-end gap-[3px]">
                              {Array.from({ length: 4 }).map((_, idx) => {
                                const barHeight = 8 + idx * 6;
                                const isFilled = idx < signalStrength;
                                return (
                                  <div
                                    key={idx}
                                    className="w-[4.5px] border border-[#111111]"
                                    style={{
                                      height: `${barHeight}px`,
                                      backgroundColor: isFilled ? '#111111' : '#E2E8F0'
                                    }}
                                  />
                                );
                              })}
                            </div>
                            <span className="font-bebas text-lg font-bold text-[#111111]">{device.signal !== null ? `${device.signal}` : '--'}</span>
                          </div>
                        </div>

                        {/* Geolocation coordinates */}
                        <div className="flex flex-col items-start pl-2 border-l border-gray-300">
                          <span className="text-[10px] font-black text-gray-500 uppercase tracking-wider">Location</span>
                          <div className="flex items-center gap-1 mt-1 text-[#111111] w-full">
                            <MapPin className="w-3.5 h-3.5 flex-shrink-0" />
                            <span className="font-mono font-bold text-[9px] truncate block w-full">
                              {device.latitude !== null && device.longitude !== null
                                ? `${device.latitude.toFixed(3)}, ${device.longitude.toFixed(3)}`
                                : 'NO GPS'
                              }
                            </span>
                          </div>
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
            <h2 className="font-bebas text-2xl font-bold tracking-wider text-[#111111] flex items-center gap-2">
              SMS CONSOLE
              <span className="font-roboto text-[9px] bg-[#E50012] text-white px-2 py-0.5 font-bold uppercase tracking-wider">QUICK SEND</span>
            </h2>

            <div className="bg-white border-2 border-[#111111] p-5">
              <form onSubmit={handleSendSms} className="space-y-4">

                {/* Target device select dropdown */}
                <div>
                  <label className="block text-[10px] font-black text-gray-700 mb-1.5 uppercase tracking-wider font-roboto">Target Device</label>
                  <select
                    value={selectedDevice}
                    onChange={(e) => setSelectedDevice(e.target.value)}
                    required
                    className="w-full bg-white border-2 border-[#111111] focus:border-[#E50012] focus:ring-0 rounded-none px-3.5 py-2.5 text-[#111111] text-xs font-bold focus:outline-none transition-colors uppercase"
                  >
                    <option value="">-- Choose a Device --</option>
                    {devices.map((device) => (
                      <option key={device.uuid} value={device.uuid}>
                        {device.name?.toUpperCase() || 'DEVICE'} ({device.status?.toUpperCase()}) - {device.uuid.slice(0, 8)}...
                      </option>
                    ))}
                  </select>
                </div>

                {/* Recipient Input */}
                <div>
                  <label className="block text-[10px] font-black text-gray-700 mb-1.5 uppercase tracking-wider font-roboto">Recipient Number</label>
                  <input
                    type="tel"
                    placeholder="e.g. +94771234567"
                    value={smsTo}
                    onChange={(e) => setSmsTo(e.target.value)}
                    required
                    className="w-full bg-white border-2 border-[#111111] focus:border-[#E50012] focus:ring-0 rounded-none px-3.5 py-2.5 text-[#111111] text-sm font-medium focus:outline-none transition-colors"
                  />
                </div>

                {/* Message text area */}
                <div>
                  <label className="block text-[10px] font-black text-gray-700 mb-1.5 uppercase tracking-wider font-roboto">SMS Message</label>
                  <textarea
                    placeholder="Enter message text here..."
                    rows={4}
                    value={smsMessage}
                    onChange={(e) => setSmsMessage(e.target.value)}
                    required
                    maxLength={160}
                    className="w-full bg-white border-2 border-[#111111] focus:border-[#E50012] focus:ring-0 rounded-none px-3.5 py-2.5 text-[#111111] text-sm focus:outline-none transition-colors resize-none"
                  ></textarea>
                  <span className="text-[10px] text-gray-500 font-bold block text-right mt-1">
                    {smsMessage.length}/160 characters
                  </span>
                </div>

                {/* Send Button */}
                <button
                  type="submit"
                  disabled={isSending || !selectedDevice}
                  className="w-full flex items-center justify-center gap-2 bg-[#E50012] hover:bg-[#B3000E] disabled:bg-gray-200 disabled:text-gray-500 disabled:border-gray-300 disabled:cursor-not-allowed border-2 border-[#111111] text-white font-black uppercase py-3.5 px-4 text-xs font-roboto tracking-wider transition-colors duration-150"
                >
                  <Send className="w-4 h-4" />
                  {isSending ? 'Sending Live Push...' : 'Send SMS Message'}
                </button>
              </form>

              {/* Status Alert panel */}
              {sendStatus && (
                <div className={`mt-4 p-4 border-2 flex gap-3 text-xs rounded-none ${sendStatus.success
                    ? 'bg-[#E8F5E9] border-[#2E7D32] text-[#2E7D32]'
                    : 'bg-[#FFEBEE] border-[#E50012] text-[#E50012]'
                  }`}>
                  {sendStatus.success ? (
                    <CheckCircle2 className="w-5 h-5 flex-shrink-0" />
                  ) : (
                    <AlertTriangle className="w-5 h-5 flex-shrink-0" />
                  )}
                  <div>
                    <h4 className="font-black uppercase tracking-wider">{sendStatus.success ? 'Success' : 'Error'}</h4>
                    <p className="mt-1 font-medium leading-relaxed">{sendStatus.message}</p>
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
