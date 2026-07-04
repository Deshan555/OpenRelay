import { useState, useEffect } from 'react';
import { RefreshCw, Activity, Megaphone, Database, Zap, Send, Calendar, Smartphone, Clock, AlertTriangle, Check } from 'lucide-react';
import { API_BASE_URL } from '../types';

interface QueueFlowTabProps {
  getAuthHeaders: (extraHeaders?: Record<string, string>) => Record<string, string>;
}

export default function QueueFlowTab({ getAuthHeaders }: QueueFlowTabProps) {
  const [queueStats, setQueueStats] = useState<any>(null);
  const [loading, setLoading] = useState<boolean>(false);

  const fetchQueueStats = async () => {
    try {
      setLoading(true);
      const res = await fetch(`${API_BASE_URL}/api/v2/admin/queue/stats`, { headers: getAuthHeaders() });
      if (res.ok) {
        const data = await res.json();
        setQueueStats(data);
      }
    } catch (err) {
      console.error("Error fetching queue stats:", err);
    } finally {
      setLoading(false);
    }
  };

  // Poll stats every 3 seconds on mount/active
  useEffect(() => {
    fetchQueueStats();
    const interval = setInterval(() => {
      fetchQueueStats();
    }, 3000);
    return () => clearInterval(interval);
  }, []);

  const formatCountdown = (seconds: number) => {
    const s = Math.max(0, Math.ceil(seconds));
    const hrs = Math.floor(s / 3600).toString().padStart(2, '0');
    const mins = Math.floor((s % 3600) / 60).toString().padStart(2, '0');
    const secs = (s % 60).toString().padStart(2, '0');
    return `${hrs}:${mins}:${secs}`;
  };

  const formatLastUpdated = (isoString?: string) => {
    if (!isoString) return new Date().toLocaleTimeString();
    return new Date(isoString).toLocaleTimeString();
  };

  return (
    <section className="space-y-4">
      <div className="flex justify-between items-center">
        <h2 className="font-bebas text-2xl font-bold tracking-wider text-[#111111] flex items-center gap-2">
          QUEUE PROCESSING FLOW
          <span className="font-roboto text-[9px] bg-[#E50012] text-white px-2 py-0.5 font-bold uppercase tracking-wider font-bold">REAL-TIME DIAGRAM</span>
        </h2>
        <div className="flex items-center gap-3">
          <div className="flex items-center gap-1 text-[9px] font-black text-gray-500 uppercase tracking-widest font-mono">
            <span>Live Update active (3s polling)</span>
            <span className="relative flex h-2 w-2">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
              <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>
            </span>
          </div>
          <button
            onClick={fetchQueueStats}
            className="ml-2 flex items-center gap-1.5 text-[10px] bg-white border-2 border-[#111111] hover:bg-gray-50 text-[#111111] font-black uppercase py-1 px-2.5 tracking-wider transition-colors duration-150 cursor-pointer font-bold"
          >
            <RefreshCw className={`w-3 h-3 ${loading ? 'animate-spin' : ''}`} />
            Refresh
          </button>
        </div>
      </div>

      {!queueStats ? (
        <div className="bg-white border-2 border-[#111111] p-20 text-center">
          <Activity className="w-14 h-14 text-gray-400 mx-auto mb-4 animate-pulse" />
          <p className="font-roboto text-sm font-bold text-gray-700 uppercase">
            Loading Queue Statistics...
          </p>
          <p className="font-roboto text-xs text-gray-500 mt-1">
            Fetching real-time processing metrics from backend server.
          </p>
        </div>
      ) : (
        <div className="flex flex-col items-center w-full select-none overflow-x-auto pb-6">
          <div className="min-w-[760px] w-full flex flex-col items-center">
            {/* 1. Campaign Source */}
            <div className="bg-[#F3E5F5] border-2 border-[#111111] p-4 w-64 text-center font-black uppercase tracking-wider shadow-[4px_4px_0px_0px_rgba(17,17,17,1)] relative transition-all duration-150 hover:translate-x-0.5 hover:translate-y-0.5 hover:shadow-[2px_2px_0px_0px_rgba(17,17,17,1)]">
              <div className="flex items-center justify-center gap-2 text-[#4A148C]">
                <Megaphone className="w-4 h-4" />
                <span className="font-bebas text-lg tracking-wide">Campaign Input</span>
              </div>
              <p className="text-[9px] text-[#4A148C] opacity-85 mt-1 font-roboto font-bold">
                Triggered Bulk CSV / API Requests
              </p>
            </div>

            {/* Arrow: Campaign -> Queue Manager */}
            <div className="flex justify-center my-2">
              <svg className="w-6 h-8 text-[#111111]" fill="none" viewBox="0 0 24 32" stroke="currentColor" strokeWidth="2.5">
                <path d="M12 0v30M7 25l5 5 5-5" strokeLinecap="square" />
              </svg>
            </div>

            {/* 2. Queue Manager */}
            <div className="bg-[#E3F2FD] border-2 border-[#111111] p-4 w-64 text-center font-black uppercase tracking-wider shadow-[4px_4px_0px_0px_rgba(17,17,17,1)] transition-all duration-150 hover:translate-x-0.5 hover:translate-y-0.5 hover:shadow-[2px_2px_0px_0px_rgba(17,17,17,1)]">
              <div className="flex items-center justify-center gap-2 text-[#0D47A1]">
                <Database className="w-4 h-4" />
                <span className="font-bebas text-lg tracking-wide">Queue Manager</span>
              </div>
              <p className="text-[9px] text-[#0D47A1] opacity-85 mt-1 font-roboto font-bold">
                Triage & Priority Classifier
              </p>
            </div>

            {/* Arrow Split: Queue Manager -> Priority / Regular queues */}
            <div className="w-full flex justify-center -my-1">
              <svg className="w-[450px] h-10 text-[#111111]" fill="none" stroke="currentColor" strokeWidth="2.5">
                <path d="M225 0v16 M225 16H80 M225 16h145 M80 16v24 M370 16v24" strokeLinecap="square" />
              </svg>
            </div>

            {/* 3. Priority and Regular Queue Blocks */}
            <div className="flex justify-center gap-16 w-full max-w-[600px] mb-4">
              {/* Priority Queue */}
              <div className="flex-1 bg-[#FFEBEE] border-2 border-[#111111] p-4 text-center shadow-[4px_4px_0px_0px_rgba(17,17,17,1)] transition-all duration-150 hover:translate-x-0.5 hover:translate-y-0.5 hover:shadow-[2px_2px_0px_0px_rgba(17,17,17,1)]">
                <div className="flex items-center justify-center gap-1.5 text-[#B71C1C] font-black uppercase tracking-wider mb-1">
                  <Zap className="w-4 h-4 fill-[#B71C1C]" />
                  <span className="font-bebas text-sm">Priority Queue</span>
                </div>
                <div className="font-bebas text-3xl font-bold text-[#B71C1C] my-1">
                  {queueStats.priority_queue_count}
                </div>
                <span className="text-[9px] text-[#B71C1C] font-black font-roboto uppercase">
                  High Priority Messages
                </span>
              </div>

              {/* Regular Queue */}
              <div className="flex-1 bg-[#E0F7FA] border-2 border-[#111111] p-4 text-center shadow-[4px_4px_0px_0px_rgba(17,17,17,1)] transition-all duration-150 hover:translate-x-0.5 hover:translate-y-0.5 hover:shadow-[2px_2px_0px_0px_rgba(17,17,17,1)]">
                <div className="flex items-center justify-center gap-1.5 text-[#006064] font-black uppercase tracking-wider mb-1">
                  <Send className="w-4 h-4" />
                  <span className="font-bebas text-sm">Regular Queue</span>
                </div>
                <div className="font-bebas text-3xl font-bold text-[#006064] my-1">
                  {queueStats.regular_queue_count}
                </div>
                <span className="text-[9px] text-[#006064] font-black font-roboto uppercase">
                  Normal Priority Messages
                </span>
              </div>
            </div>

            {/* Arrow Merge: Priority / Regular queues -> Device Scheduler */}
            <div className="w-full flex justify-center -my-1">
              <svg className="w-[450px] h-10 text-[#111111]" fill="none" stroke="currentColor" strokeWidth="2.5">
                <path d="M80 0v20 M370 0v20 M80 20h290 M225 20v20" strokeLinecap="square" />
              </svg>
            </div>

            {/* 4. Device Scheduler */}
            <div className="bg-[#E8F5E9] border-2 border-[#111111] p-4 w-80 text-center font-black uppercase tracking-wider shadow-[4px_4px_0px_0px_rgba(17,17,17,1)] transition-all duration-150 hover:translate-x-0.5 hover:translate-y-0.5 hover:shadow-[2px_2px_0px_0px_rgba(17,17,17,1)]">
              <div className="flex items-center justify-center gap-2 text-[#1B5E20]">
                <Calendar className="w-4 h-4" />
                <span className="font-bebas text-lg tracking-wide">Device Scheduler</span>
              </div>
              <p className="text-[9px] text-[#1B5E20] opacity-85 mt-1 font-roboto font-bold">
                Distributes messages to available devices
              </p>
            </div>

            {/* Arrow Down: Device Scheduler -> Devices */}
            <div className="flex justify-center my-3">
              <svg className="w-6 h-8 text-[#111111]" fill="none" viewBox="0 0 24 32" stroke="currentColor" strokeWidth="2.5">
                <path d="M12 0v30M7 25l5 5 5-5" strokeLinecap="square" />
              </svg>
            </div>

            {/* 5. Device execution nodes grid */}
            <div className="w-full px-4 mt-2">
              <h3 className="font-bebas text-xl font-bold tracking-wide text-[#111111] mb-4 text-center">
                ACTIVE DESPATCH GATEWAYS
              </h3>

              {(() => {
                const onlineFlowDevices = queueStats.devices.filter((device: any) => device.status === 'online');
                if (onlineFlowDevices.length === 0) {
                  return (
                    <div className="bg-white border-2 border-[#111111] p-6 text-center w-full">
                      <Smartphone className="w-8 h-8 text-gray-300 mx-auto mb-2" />
                      <p className="font-roboto text-xs font-bold text-gray-500 uppercase">
                        No active (online) gateways connected.
                      </p>
                    </div>
                  );
                }
                return (
                  <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 w-full max-w-[1100px] mx-auto">
                    {onlineFlowDevices.map((device: any) => {
                      const isOnline = device.status === 'online';
                      const signalStrength = device.signal !== null ? device.signal : 0;
                      
                      // Determine borders, background accent, and labels based on action/status
                      let borderTheme = "border-[#111111]";
                      let ringDotColor = "bg-gray-400";
                      let iconBg = "bg-gray-100 text-gray-500";
                      let footerTheme = "bg-gray-50 border-t border-gray-200 text-gray-600";
                      let statusText = "Offline";
                      let actionDesc = "Device disconnected";

                      if (isOnline) {
                        if (device.action === 'sending') {
                          borderTheme = "border-[#2E7D32]";
                          ringDotColor = "bg-[#2E7D32]";
                          iconBg = "bg-[#E8F5E9] text-[#2E7D32]";
                          footerTheme = "bg-[#E8F5E9] border-t border-[#2E7D32] text-[#2E7D32]";
                          statusText = "Sending";
                          actionDesc = "Currently sending messages";
                        } else if (device.action === 'waiting') {
                          borderTheme = "border-[#EF6C00]";
                          ringDotColor = "bg-[#EF6C00]";
                          iconBg = "bg-[#FFF3E0] text-[#EF6C00]";
                          footerTheme = "bg-[#FFF3E0] border-t border-[#EF6C00] text-[#EF6C00]";
                          statusText = "Waiting";
                          actionDesc = "Queue hold";
                        } else { // idle
                          borderTheme = "border-[#0288D1]";
                          ringDotColor = "bg-[#0288D1]";
                          iconBg = "bg-[#E1F5FE] text-[#0288D1]";
                          footerTheme = "bg-[#E1F5FE] border-t border-[#0288D1] text-[#0288D1]";
                          statusText = "Idle";
                          actionDesc = "Ready for new messages";
                        }
                      }

                      return (
                        <div
                          key={device.uuid}
                          className={`bg-white border-2 flex flex-col justify-between shadow-[4px_4px_0px_0px_rgba(17,17,17,1)] hover:translate-x-0.5 hover:translate-y-0.5 hover:shadow-[2px_2px_0px_0px_rgba(17,17,17,1)] transition-all duration-150 ${borderTheme}`}
                        >
                          <div className="p-4 flex-grow">
                            {/* Top header: name, online status badge, signal */}
                            <div className="flex justify-between items-center mb-3">
                              <div className="flex items-center gap-1.5">
                                <span className="font-bebas text-lg font-bold text-[#111111] tracking-wide">
                                  {device.name.toUpperCase()}
                                </span>
                                <span className={`px-1.5 py-0.5 border border-[#111111] text-[8px] font-black uppercase ${
                                  isOnline ? 'bg-[#E8F5E9] text-[#2E7D32]' : 'bg-gray-150 text-gray-500'
                                }`}>
                                  {device.status}
                                </span>
                              </div>
                              
                              {/* Signal bars */}
                              <div className="flex items-end gap-[2px]">
                                {Array.from({ length: 4 }).map((_, idx) => {
                                  const barHeight = 6 + idx * 4;
                                  const isFilled = idx < signalStrength;
                                  return (
                                    <div
                                      key={idx}
                                      className="w-[2.5px] border border-[#111111]"
                                      style={{
                                        height: `${barHeight}px`,
                                        backgroundColor: isOnline && isFilled ? '#111111' : '#E2E8F0'
                                      }}
                                    />
                                  );
                                })}
                              </div>
                            </div>

                            {/* Sub-header: Smartphone circle and status text */}
                            <div className="flex items-center gap-3.5 mb-4">
                              <div className={`w-12 h-12 rounded-full border-2 border-[#111111] flex items-center justify-center relative ${iconBg}`}>
                                <Smartphone className="w-6 h-6" />
                                {isOnline && (
                                  <span className={`absolute -top-0.5 -right-0.5 w-3.5 h-3.5 rounded-full border-2 border-white ${ringDotColor} ${
                                    device.action === 'sending' ? 'animate-ping' : ''
                                  }`} />
                                )}
                              </div>
                              <div>
                                <span className="block text-[8px] font-black uppercase text-gray-500 tracking-wider">Gateway State</span>
                                <span className="text-base font-bebas font-black tracking-wide block leading-none">{statusText}</span>
                                <span className="text-[9px] font-bold text-gray-500 block mt-0.5 font-roboto">{actionDesc}</span>
                              </div>
                            </div>

                            {/* Metrics details */}
                            {isOnline && (
                              <div className="space-y-2 text-xs border-t border-gray-100 pt-3">
                                {device.action === 'sending' && (
                                  <div className="grid grid-cols-3 gap-1 text-center font-mono">
                                    <div>
                                      <span className="block text-[8px] text-gray-500 uppercase font-black font-roboto">Sent</span>
                                      <span className="font-bold text-gray-800">{device.sent_count}</span>
                                    </div>
                                    <div>
                                      <span className="block text-[8px] text-gray-500 uppercase font-black font-roboto">Speed</span>
                                      <span className="font-bold text-gray-800">{device.speed.toFixed(1)}/s</span>
                                    </div>
                                    <div>
                                      <span className="block text-[8px] text-gray-500 uppercase font-black font-roboto">Success</span>
                                      <span className="font-bold text-[#2E7D32]">{device.success_rate.toFixed(0)}%</span>
                                    </div>
                                  </div>
                                )}

                                {device.action === 'waiting' && (
                                  <div className="grid grid-cols-3 gap-1 text-center font-mono">
                                    <div>
                                      <span className="block text-[8px] text-gray-500 uppercase font-black font-roboto">Pending</span>
                                      <span className="font-bold text-gray-800">{device.pending_count}</span>
                                    </div>
                                    <div>
                                      <span className="block text-[8px] text-gray-500 uppercase font-black font-roboto">In Queue</span>
                                      <span className="font-bold text-gray-850">{device.pending_count + device.processing_count}</span>
                                    </div>
                                    <div>
                                      <span className="block text-[8px] text-gray-500 uppercase font-black font-roboto">Next SMS In</span>
                                      <span className="font-bold text-[#EF6C00] tracking-tight">{formatCountdown(device.next_send_in)}</span>
                                    </div>
                                  </div>
                                )}

                                {device.action === 'idle' && (
                                  <div className="grid grid-cols-2 gap-2 font-mono">
                                    <div className="text-center border-r border-gray-150">
                                      <span className="block text-[8px] text-gray-500 uppercase font-black font-roboto">Total Sent</span>
                                      <span className="font-bold text-gray-800">{device.sent_count}</span>
                                    </div>
                                    <div className="text-center">
                                      <span className="block text-[8px] text-gray-500 uppercase font-black font-roboto">Success Rate</span>
                                      <span className="font-bold text-[#0288D1]">
                                        {device.success_rate.toFixed(1)}%
                                      </span>
                                    </div>
                                  </div>
                                )}
                              </div>
                            )}
                          </div>

                          {/* Footer active badge */}
                          <div className={`p-2.5 flex items-center justify-between text-[9px] font-black uppercase ${footerTheme}`}>
                            <div className="flex items-center gap-1 font-roboto font-bold">
                              {device.action === 'sending' && (
                                <>
                                  <Check className="w-3.5 h-3.5 border border-[#2E7D32] bg-white p-[1px]" />
                                  <span>Success</span>
                                </>
                              )}
                              {device.action === 'waiting' && (
                                <>
                                  <Clock className="w-3.5 h-3.5" />
                                  <span>Queue Hold</span>
                                </>
                              )}
                              {device.action === 'idle' && (
                                <>
                                  <Activity className="w-3.5 h-3.5 animate-pulse" />
                                  <span>Listening...</span>
                                </>
                              )}
                              {device.action === 'offline' && (
                                <>
                                  <AlertTriangle className="w-3.5 h-3.5 text-[#E50012]" />
                                  <span className="text-[#E50012]">Disconnected</span>
                                </>
                              )}
                            </div>
                            <span className="font-mono text-[9px] opacity-75">
                              Last seen: {formatLastUpdated(device.last_updated)}
                            </span>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                );
              })()}
            </div>
          </div>
        </div>
      )}
    </section>
  );
}
