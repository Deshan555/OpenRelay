import { useState } from 'react';
import { Smartphone, Send, CheckCircle2, AlertTriangle } from 'lucide-react';
import { type Device, API_BASE_URL } from '../types';

interface SmsTabProps {
  devices: Device[];
  selectedDevice: string;
  setSelectedDevice: (val: string) => void;
  apiVersion: string;
  getAuthHeaders: (extraHeaders?: Record<string, string>) => Record<string, string>;
  fetchLogs: () => void;
}

export default function SmsTab({
  devices,
  selectedDevice,
  setSelectedDevice,
  apiVersion,
  getAuthHeaders,
  fetchLogs
}: SmsTabProps) {
  const [smsTo, setSmsTo] = useState<string>('');
  const [smsMessage, setSmsMessage] = useState<string>('');
  const [isSending, setIsSending] = useState<boolean>(false);
  const [sendStatus, setSendStatus] = useState<{ success: boolean; message: string } | null>(null);

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
        headers: getAuthHeaders({ 'Content-Type': 'application/json' }),
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
        fetchLogs();
      } else {
        setSendStatus({
          success: false,
          message: data.detail || 'Failed to queue SMS job.'
        });
      }
    } catch (err) {
      setSendStatus({
        success: false,
        message: 'Network error while queueing SMS.'
      });
    } finally {
      setIsSending(false);
    }
  };

  const dev = devices.find(d => d.uuid === selectedDevice);

  return (
    <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 items-start">
      {/* Send Form */}
      <section className="lg:col-span-2 space-y-4">
        <h2 className="font-bebas text-2xl font-bold tracking-wider text-[#111111] flex items-center gap-2">
          SMS CONSOLE
          <span className="font-roboto text-[9px] bg-[#E50012] text-white px-2 py-0.5 font-bold uppercase tracking-wider">QUICK SEND</span>
        </h2>

        <div className="bg-white border-2 border-[#111111] p-5">
          <form onSubmit={handleSendSms} className="space-y-4">
            <div>
              <label className="block text-[10px] font-black text-gray-700 mb-1.5 uppercase tracking-wider font-roboto">Target Device</label>
              <select
                value={selectedDevice}
                onChange={(e) => setSelectedDevice(e.target.value)}
                required
                className="w-full bg-white border-2 border-[#111111] focus:border-[#E50012] focus:ring-0 rounded-none px-3.5 py-2.5 text-[#111111] text-xs font-bold focus:outline-none transition-colors uppercase cursor-pointer"
              >
                <option value="">-- Choose a Device --</option>
                {devices.map((device) => (
                  <option key={device.uuid} value={device.uuid}>
                    {device.name?.toUpperCase() || 'DEVICE'} ({device.status?.toUpperCase()}) - {device.uuid.slice(0, 8)}...
                  </option>
                ))}
              </select>
            </div>

            <div>
              <label className="block text-[10px] font-black text-gray-700 mb-1.5 uppercase tracking-wider font-roboto">Recipient Number</label>
              <input
                type="tel"
                placeholder="e.g. +94771234567"
                value={smsTo}
                onChange={(e) => setSmsTo(e.target.value)}
                required
                className="w-full bg-white border-2 border-[#111111] focus:border-[#E50012] focus:ring-0 rounded-none px-3.5 py-2.5 text-[#111111] text-sm font-medium focus:outline-none transition-colors font-mono"
              />
            </div>

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

            <button
              type="submit"
              disabled={isSending || !selectedDevice}
              className="w-full flex items-center justify-center gap-2 bg-[#E50012] hover:bg-[#B3000E] disabled:bg-gray-200 disabled:text-gray-500 disabled:border-gray-300 disabled:cursor-not-allowed border-2 border-[#111111] text-white font-black uppercase py-3.5 px-4 text-xs font-roboto tracking-wider transition-colors duration-150 cursor-pointer font-bold"
            >
              <Send className="w-4 h-4" />
              {isSending ? 'Sending Live Push...' : 'Send SMS Message'}
            </button>
          </form>

          {sendStatus && (
            <div className={`mt-4 p-4 border-2 flex gap-3 text-xs rounded-none ${
              sendStatus.success
                ? 'bg-[#E8F5E9] border-[#2E7D32] text-[#2E7D32]'
                : 'bg-[#FFEBEE] border-[#E50012] text-[#E50012]'
            }`}>
              {sendStatus.success ? <CheckCircle2 className="w-5 h-5 flex-shrink-0" /> : <AlertTriangle className="w-5 h-5 flex-shrink-0" />}
              <div>
                <h4 className="font-black uppercase tracking-wider">{sendStatus.success ? 'Success' : 'Error'}</h4>
                <p className="mt-1 font-medium leading-relaxed">{sendStatus.message}</p>
              </div>
            </div>
          )}
        </div>
      </section>

      {/* Side Info */}
      <section className="space-y-4">
        <h2 className="font-bebas text-2xl font-bold tracking-wider text-[#111111]">
          DEVICE SPECS
        </h2>
        <div className="bg-white border-2 border-[#111111] p-5 space-y-4">
          {selectedDevice && dev ? (
            <div className="space-y-3.5 text-xs font-medium">
              <div className="border-b border-gray-200 pb-3">
                <span className="block text-[9px] font-black uppercase text-gray-500 tracking-wider">Device Name</span>
                <span className="text-sm font-black text-[#111111] uppercase">{dev.name || 'Unnamed Device'}</span>
              </div>
              <div>
                <span className="block text-[9px] font-black uppercase text-gray-500 tracking-wider">Signal Strength</span>
                <span className="font-bold text-gray-800 font-mono">
                  {dev.signal !== null ? `${dev.signal} / 4 Bars` : 'Unknown'}
                </span>
              </div>
              <div>
                <span className="block text-[9px] font-black uppercase text-gray-500 tracking-wider">Carrier Info</span>
                <span className="font-bold text-gray-800">{dev.carrier || 'Unknown'}</span>
              </div>
              <div>
                <span className="block text-[9px] font-black uppercase text-gray-500 tracking-wider">Battery Status</span>
                <span className="font-bold text-gray-800 font-mono">{dev.battery !== null ? `${dev.battery}%` : 'Unknown'}</span>
              </div>
              <div>
                <span className="block text-[9px] font-black uppercase text-gray-500 tracking-wider">Connection Status</span>
                <span className={`inline-block px-2 py-0.5 text-[9px] font-black uppercase border border-[#111111] ${
                  dev.status === 'online' ? 'bg-[#E8F5E9] text-[#2E7D32]' : 'bg-gray-150 text-gray-500'
                }`}>{dev.status}</span>
              </div>
            </div>
          ) : (
            <div className="text-center py-6">
              <Smartphone className="w-10 h-10 text-gray-300 mx-auto mb-2" />
              <p className="text-xs text-gray-500 font-bold uppercase">Select a target device above to view real-time hardware telemetry.</p>
            </div>
          )}
        </div>

        <div className="bg-white border-2 border-[#111111] p-5 text-xs text-gray-600 leading-relaxed space-y-2">
          <h4 className="font-black text-[#111111] uppercase text-[10px] tracking-wider mb-2">Gateway Instructions</h4>
          <p>• Make sure recipient numbers include the country code prefix (e.g., <code className="font-mono bg-gray-100 px-1 font-bold">+94...</code>).</p>
          <p>• The target device must be <strong className="text-[#2E7D32] uppercase">online</strong> to receive jobs immediately via WebSocket.</p>
          <p>• Messages sent through this console will bypass queue delays and trigger live pushes.</p>
        </div>
      </section>
    </div>
  );
}
