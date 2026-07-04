import React, { useState } from 'react';
import { FileSpreadsheet, CheckCircle2, AlertTriangle } from 'lucide-react';
import { API_BASE_URL } from '../types';

interface BulkTabProps {
  getAuthHeaders: (extraHeaders?: Record<string, string>) => Record<string, string>;
}

export default function BulkTab({ getAuthHeaders }: BulkTabProps) {
  const [file, setFile] = useState<File | null>(null);
  const [queueType, setQueueType] = useState<string>('REGULAR');
  const [isBulkSending, setIsBulkSending] = useState<boolean>(false);
  const [bulkStatus, setBulkStatus] = useState<{ success: boolean; message: string } | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!file) return;

    setIsBulkSending(true);
    setBulkStatus(null);

    const formData = new FormData();
    formData.append('file', file);
    formData.append('queue_type', queueType);

    try {
      const res = await fetch(`${API_BASE_URL}/api/v2/admin/bulk-sms`, {
        method: 'POST',
        headers: getAuthHeaders(),
        body: formData
      });
      const data = await res.json();
      setBulkStatus({
        success: res.ok,
        message: data.detail || (res.ok ? 'Bulk SMS processing started successfully.' : 'Error uploading CSV')
      });
    } catch (err) {
      setBulkStatus({ success: false, message: 'Network error while uploading CSV.' });
    } finally {
      setIsBulkSending(false);
    }
  };

  return (
    <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 items-start">
      {/* Upload Form */}
      <section className="lg:col-span-2 space-y-4">
        <h2 className="font-bebas text-2xl font-bold tracking-wider text-[#111111] flex items-center gap-2">
          BULK SMS UPLOAD
          <span className="font-roboto text-[9px] bg-[#E50012] text-white px-2 py-0.5 font-bold uppercase tracking-wider font-bold">ADMIN</span>
        </h2>
        <div className="bg-white border-2 border-[#111111] p-5">
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-[10px] font-black text-gray-700 mb-1.5 uppercase tracking-wider font-roboto">CSV File</label>
              <input
                type="file"
                accept="text/csv"
                onChange={(e) => setFile(e.target.files?.[0] || null)}
                required
                className="w-full bg-white border-2 border-[#111111] focus:border-[#E50012] focus:ring-0 rounded-none px-3.5 py-2.5 text-[#111111] text-sm font-medium focus:outline-none transition-colors cursor-pointer"
              />
            </div>
            <div>
              <label className="block text-[10px] font-black text-gray-700 mb-1.5 uppercase tracking-wider font-roboto">Queue Type</label>
              <select
                value={queueType}
                onChange={(e) => setQueueType(e.target.value)}
                className="w-full bg-white border-2 border-[#111111] focus:border-[#E50012] focus:ring-0 rounded-none px-3.5 py-2.5 text-[#111111] text-xs font-bold focus:outline-none transition-colors uppercase cursor-pointer"
              >
                <option value="REGULAR">Regular Queue</option>
                <option value="PRIORITY">Priority Queue</option>
              </select>
            </div>

            <button
              type="submit"
              disabled={isBulkSending || !file}
              className="w-full flex items-center justify-center gap-2 bg-[#111111] hover:bg-gray-800 disabled:bg-gray-200 disabled:text-gray-500 disabled:border-gray-300 disabled:cursor-not-allowed border-2 border-[#111111] text-white font-black uppercase py-3.5 px-4 text-xs font-roboto tracking-wider transition-colors duration-150 cursor-pointer font-bold"
            >
              <FileSpreadsheet className="w-4 h-4" />
              {isBulkSending ? 'Uploading & Dispatching...' : 'Upload SMS Campaign'}
            </button>
          </form>

          {bulkStatus && (
            <div className={`mt-4 p-4 border-2 flex gap-3 text-xs rounded-none ${bulkStatus.success ? 'bg-[#E8F5E9] border-[#2E7D32] text-[#2E7D32]' : 'bg-[#FFEBEE] border-[#E50012] text-[#E50012]'}`}>
              {bulkStatus.success ? <CheckCircle2 className="w-5 h-5 flex-shrink-0" /> : <AlertTriangle className="w-5 h-5 flex-shrink-0" />}
              <div>
                <h4 className="font-black uppercase tracking-wider">{bulkStatus.success ? 'Success' : 'Error'}</h4>
                <p className="mt-1 font-medium leading-relaxed">{bulkStatus.message}</p>
              </div>
            </div>
          )}
        </div>
      </section>

      {/* Instructions */}
      <section className="space-y-4">
        <h2 className="font-bebas text-2xl font-bold tracking-wider text-[#111111]">
          CSV REQUIREMENTS
        </h2>
        <div className="bg-white border-2 border-[#111111] p-5 space-y-4">
          <div className="text-xs font-medium space-y-2">
            <span className="block text-[10px] font-black uppercase text-gray-500 tracking-wider">Required Column Headers</span>
            <p className="font-mono bg-gray-150 p-2.5 border border-gray-300 text-gray-800 leading-normal block select-all">
              phone_number,message,name
            </p>
          </div>

          <div className="bg-white border-2 border-[#111111] p-4 text-xs text-gray-600 leading-relaxed space-y-2">
            <h4 className="font-black text-[#111111] uppercase text-[10px] tracking-wider mb-2">Campaign Guidelines</h4>
            <p>• Make sure the file format is strictly comma-separated <code className="font-mono bg-gray-100 px-1 font-bold">.csv</code>.</p>
            <p>• Empty rows or columns missing required fields will be automatically skipped.</p>
            <p>• Priority queues will preempt regular dispatching on active gateways immediately.</p>
          </div>
        </div>
      </section>
    </div>
  );
}
