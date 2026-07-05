import { useState, useEffect } from 'react';
import { Search, RefreshCw, History, FileSpreadsheet, X, Eye } from 'lucide-react';
import { type SmsLog, type BulkSmsLog, API_BASE_URL } from '../types';

interface LogsTabProps {
  getAuthHeaders: (extraHeaders?: Record<string, string>) => Record<string, string>;
}

export default function LogsTab({ getAuthHeaders }: LogsTabProps) {
  const [activeLogSubTab, setActiveLogSubTab] = useState<'single' | 'bulk'>('single');
  const [searchQuery, setSearchQuery] = useState<string>('');
  const [statusFilter, setStatusFilter] = useState<string>('ALL');
  
  // Number masking state
  const [maskNumbers, setMaskNumbers] = useState<boolean>(() => {
    return localStorage.getItem('logs_mask_numbers') === 'true';
  });

  // Pagination & Lists
  const [singleLogsPage, setSingleLogsPage] = useState<number>(1);
  const [bulkLogsPage, setBulkLogsPage] = useState<number>(1);
  const [pageSize, setPageSize] = useState<number>(10);

  const [smsLogs, setSmsLogs] = useState<SmsLog[]>([]);
  const [bulkLogs, setBulkLogs] = useState<BulkSmsLog[]>([]);
  const [totalSinglePages, setTotalSinglePages] = useState<number>(1);
  const [totalBulkPages, setTotalBulkPages] = useState<number>(1);
  
  const [loadingLogs, setLoadingLogs] = useState<boolean>(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [selectedLog, setSelectedLog] = useState<any | null>(null);

  const handleMaskChange = (val: boolean) => {
    setMaskNumbers(val);
    localStorage.setItem('logs_mask_numbers', String(val));
  };

  const displayPhoneNumber = (phone: string) => {
    if (!phone) return '';
    if (!maskNumbers) return phone;
    
    // Masking e.g. +94771234567 -> +9477******67
    if (phone.length <= 7) return '***-***';
    const firstPart = phone.slice(0, 5);
    const lastPart = phone.slice(-3);
    const maskedLength = phone.length - 8;
    const asterisks = '*'.repeat(maskedLength > 0 ? maskedLength : 4);
    return `${firstPart}${asterisks}${lastPart}`;
  };

  const fetchLogs = async () => {
    try {
      setLoadingLogs(true);
      setErrorMessage(null);
      const queryParams = `page_size=${pageSize}&search=${encodeURIComponent(searchQuery)}&status=${statusFilter}`;
      
      const [smsRes, bulkRes] = await Promise.all([
        fetch(`${API_BASE_URL}/api/v2/sms/logs?page=${singleLogsPage}&${queryParams}`, { headers: getAuthHeaders() }),
        fetch(`${API_BASE_URL}/api/v2/admin/bulk-sms/logs?page=${bulkLogsPage}&${queryParams}`, { headers: getAuthHeaders() })
      ]);

      let hasError = false;
      if (smsRes.ok) {
        const smsData = await smsRes.json();
        setSmsLogs(smsData.logs);
        setTotalSinglePages(smsData.total_pages);
      } else {
        hasError = true;
      }
      if (bulkRes.ok) {
        const bulkData = await bulkRes.json();
        setBulkLogs(bulkData.logs);
        setTotalBulkPages(bulkData.total_pages);
      } else {
        hasError = true;
      }

      if (hasError) {
        setErrorMessage("Failed to fetch some logs. Please check backend server status.");
      }
    } catch (err) {
      console.error("Error fetching logs:", err);
      setErrorMessage("Network error fetching logs. Please try again.");
    } finally {
      setLoadingLogs(false);
    }
  };

  // Re-fetch when dependencies change
  useEffect(() => {
    fetchLogs();
  }, [activeLogSubTab, singleLogsPage, bulkLogsPage, pageSize, searchQuery, statusFilter]);

  return (
    <section className="space-y-4">
      <div className="flex flex-col md:flex-row justify-between md:items-center gap-3">
        <div className="flex flex-wrap gap-2 items-center">
          <button
            onClick={() => {
              setActiveLogSubTab('single');
              setSearchQuery('');
              setStatusFilter('ALL');
              setSingleLogsPage(1);
            }}
            className={`px-4 py-2 border-2 border-[#111111] text-[10px] font-black uppercase tracking-wider transition-all cursor-pointer font-bold ${
              activeLogSubTab === 'single'
                ? 'bg-[#111111] text-white shadow-none translate-x-0.5 translate-y-0.5'
                : 'bg-white text-[#111111] hover:bg-gray-50 hover:shadow-[2px_2px_0px_0px_rgba(17,17,17,1)]'
            }`}
          >
            Single Message Logs
          </button>
          <button
            onClick={() => {
              setActiveLogSubTab('bulk');
              setSearchQuery('');
              setStatusFilter('ALL');
              setBulkLogsPage(1);
            }}
            className={`px-4 py-2 border-2 border-[#111111] text-[10px] font-black uppercase tracking-wider transition-all cursor-pointer font-bold ${
              activeLogSubTab === 'bulk'
                ? 'bg-[#111111] text-white shadow-none translate-x-0.5 translate-y-0.5'
                : 'bg-white text-[#111111] hover:bg-gray-50 hover:shadow-[2px_2px_0px_0px_rgba(17,17,17,1)]'
            }`}
          >
            Bulk Upload logs
          </button>

          {/* Search Logs */}
          <div className="flex items-center gap-2 bg-white border-2 border-[#111111] px-3.5 py-1.5 w-full sm:w-56 font-roboto rounded-none">
            <Search className="w-3.5 h-3.5 text-gray-500 flex-shrink-0" />
            <input
              type="text"
              placeholder="Search logs..."
              value={searchQuery}
              onChange={(e) => {
                setSearchQuery(e.target.value);
                setSingleLogsPage(1);
                setBulkLogsPage(1);
              }}
              className="w-full text-xs font-bold text-[#111111] bg-transparent focus:outline-none placeholder-gray-400 font-mono"
            />
            {searchQuery && (
              <button onClick={() => { setSearchQuery(''); setSingleLogsPage(1); setBulkLogsPage(1); }} className="text-gray-400 hover:text-gray-600 font-bold text-xs font-mono">×</button>
            )}
          </div>

          {/* Filter By Status */}
          <div className="flex items-center gap-1.5 bg-white border-2 border-[#111111] px-3 py-1.5 font-roboto rounded-none text-xs font-bold">
            <span className="text-gray-500 uppercase text-[9px] font-black">Status:</span>
            <select
              value={statusFilter}
              onChange={(e) => {
                setStatusFilter(e.target.value);
                setSingleLogsPage(1);
                setBulkLogsPage(1);
              }}
              className="bg-transparent text-[#111111] focus:outline-none font-black cursor-pointer uppercase text-xs"
            >
              <option value="ALL">ALL STATUSES</option>
              <option value="PENDING">PENDING</option>
              <option value="QUEUED">QUEUED</option>
              <option value="PROCESSING">PROCESSING</option>
              <option value="SENT">SENT</option>
              <option value="FAILED">FAILED</option>
            </select>
          </div>

          {/* Masking Toggle Radio Button Group */}
          <div className="flex items-center gap-3 bg-white border-2 border-[#111111] px-3.5 py-1.5 font-roboto text-xs font-bold rounded-none">
            <span className="text-gray-500 uppercase text-[9px] font-black">Numbers:</span>
            <label className="flex items-center gap-1.5 cursor-pointer select-none">
              <input
                type="radio"
                name="number-masking"
                checked={maskNumbers}
                onChange={() => handleMaskChange(true)}
                className="w-3.5 h-3.5 accent-[#111111] border-[#111111] cursor-pointer"
              />
              <span>Masked</span>
            </label>
            <label className="flex items-center gap-1.5 cursor-pointer select-none">
              <input
                type="radio"
                name="number-masking"
                checked={!maskNumbers}
                onChange={() => handleMaskChange(false)}
                className="w-3.5 h-3.5 accent-[#111111] border-[#111111] cursor-pointer"
              />
              <span>Full</span>
            </label>
          </div>
        </div>

        <button
          onClick={fetchLogs}
          disabled={loadingLogs}
          className="flex items-center justify-center gap-1.5 text-[10px] bg-white border-2 border-[#111111] hover:bg-gray-50 text-[#111111] font-black uppercase py-2 px-4.5 tracking-wider transition-colors cursor-pointer font-bold"
        >
          <RefreshCw className={`w-3.5 h-3.5 ${loadingLogs ? 'animate-spin' : ''}`} />
          Refresh Logs
        </button>
      </div>

      {loadingLogs ? (
        <div className="bg-white border-2 border-[#111111] p-12 text-center">
          <RefreshCw className="w-10 h-10 text-[#E50012] animate-spin mx-auto mb-3" />
          <p className="font-roboto text-xs font-bold text-gray-600 uppercase tracking-widest animate-pulse">Fetching Logs from Gateway Database...</p>
        </div>
      ) : (
        <>
          {errorMessage && (
            <div className="bg-[#FFEBEE] border-2 border-[#E50012] text-[#E50012] p-4 text-xs font-bold font-mono rounded-none mb-4 flex items-center justify-between">
              <span>⚠️ ERROR: {errorMessage}</span>
              <button onClick={() => setErrorMessage(null)} className="text-[#E50012] hover:text-black font-black cursor-pointer">✕</button>
            </div>
          )}
          <div className="bg-white border-2 border-[#111111] overflow-x-auto">
            {activeLogSubTab === 'single' ? (
              smsLogs.length === 0 ? (
                <div className="p-10 text-center">
                  <History className="w-12 h-12 text-gray-300 mx-auto mb-3" />
                  <p className="text-xs text-gray-500 font-bold uppercase">
                    {searchQuery.trim() !== '' || statusFilter !== 'ALL' ? 'No logs match your filter criteria.' : 'No single SMS records found in database.'}
                  </p>
                </div>
              ) : (
                <table className="w-full text-left border-collapse text-xs">
                  <thead>
                    <tr className="bg-gray-50 border-b-2 border-[#111111] text-[9px] uppercase font-black tracking-wider text-gray-500">
                      <th className="p-3 border-r border-gray-200">Job ID</th>
                      <th className="p-3 border-r border-gray-200">Recipient</th>
                      <th className="p-3 border-r border-gray-200">Message</th>
                      <th className="p-3 border-r border-gray-200">Device UUID</th>
                      <th className="p-3 border-r border-gray-200">Status</th>
                      <th className="p-3">Created At</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-200 font-medium">
                    {smsLogs.map((log) => (
                      <tr
                        key={log._id}
                        onClick={() => setSelectedLog(log)}
                        className="hover:bg-gray-50 cursor-pointer transition-colors"
                      >
                        <td className="p-3 border-r border-gray-200 font-mono font-bold text-[10px] text-gray-500 truncate max-w-[100px]">{log._id}</td>
                        <td className="p-3 border-r border-gray-200 font-bold text-gray-800 font-mono">{displayPhoneNumber(log.recipient)}</td>
                        <td className="p-3 border-r border-gray-200 text-gray-700 max-w-[200px] truncate font-mono" title={log.message}>{log.message}</td>
                        <td className="p-3 border-r border-gray-200 font-mono text-[10px] text-gray-500 truncate max-w-[100px]" title={log.device_uuid}>{log.device_uuid}</td>
                        <td className="p-3 border-r border-gray-200">
                          <span className={`inline-block px-2.5 py-0.5 border border-[#111111] text-[9px] font-black uppercase ${
                            log.status === 'SENT' ? 'bg-[#E8F5E9] text-[#2E7D32]' :
                            log.status === 'FAILED' || log.status === 'ABANDONED' ? 'bg-[#FFEBEE] text-[#E50012]' : 'bg-[#FFF9C4] text-[#F57F17]'
                          }`}>
                            {log.status}
                          </span>
                        </td>
                        <td className="p-3 text-gray-500 font-mono text-[10px]">
                          {log.created_at ? new Date(log.created_at).toLocaleString() : '--'}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )
            ) : (
              bulkLogs.length === 0 ? (
                <div className="p-10 text-center">
                  <FileSpreadsheet className="w-12 h-12 text-gray-300 mx-auto mb-3" />
                  <p className="text-xs text-gray-500 font-bold uppercase">
                    {searchQuery.trim() !== '' || statusFilter !== 'ALL' ? 'No logs match your filter criteria.' : 'No bulk SMS upload records found in database.'}
                  </p>
                </div>
              ) : (
                <table className="w-full text-left border-collapse text-xs">
                  <thead>
                    <tr className="bg-gray-50 border-b-2 border-[#111111] text-[9px] uppercase font-black tracking-wider text-gray-500">
                      <th className="p-3 border-r border-gray-200">Log ID</th>
                      <th className="p-3 border-r border-gray-200">Recipient</th>
                      <th className="p-3 border-r border-gray-200">Message</th>
                      <th className="p-3 border-r border-gray-200">Selected Device</th>
                      <th className="p-3 border-r border-gray-200">Status</th>
                      <th className="p-3">Created At</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-200 font-medium">
                    {bulkLogs.map((log) => (
                      <tr
                        key={log._id}
                        onClick={() => setSelectedLog(log)}
                        className="hover:bg-gray-50 cursor-pointer transition-colors"
                      >
                        <td className="p-3 border-r border-gray-200 font-mono font-bold text-[10px] text-gray-500 truncate max-w-[100px]">{log._id}</td>
                        <td className="p-3 border-r border-gray-200 font-bold text-gray-800 font-mono">{displayPhoneNumber(log.phone_number)}</td>
                        <td className="p-3 border-r border-gray-200 text-gray-700 max-w-[200px] truncate font-mono" title={log.message}>{log.message}</td>
                        <td className="p-3 border-r border-gray-200 font-mono text-[10px] text-gray-500 truncate max-w-[100px]" title={log.device_uuid}>{log.device_uuid}</td>
                        <td className="p-3 border-r border-gray-200">
                          <span className={`inline-block px-2.5 py-0.5 border border-[#111111] text-[9px] font-black uppercase ${
                            log.status === 'SENT' ? 'bg-[#E8F5E9] text-[#2E7D32]' :
                            log.status === 'FAILED' || log.status === 'ABANDONED' ? 'bg-[#FFEBEE] text-[#E50012]' : 'bg-[#FFF9C4] text-[#F57F17]'
                          }`}>
                            {log.status}
                          </span>
                        </td>
                        <td className="p-3 text-gray-500 font-mono text-[10px]">
                          {log.created_at ? new Date(log.created_at).toLocaleString() : '--'}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )
            )}
          </div>

          {/* Pagination Footer Controls */}
          <div className="flex flex-col sm:flex-row justify-between items-center bg-white border-2 border-[#111111] border-t-0 p-3.5 gap-3.5 text-xs select-none">
            <div className="flex items-center gap-2 font-roboto text-[10px] font-black text-gray-500 uppercase tracking-wider">
              <span>Show</span>
              <select
                value={pageSize}
                onChange={(e) => {
                  setPageSize(Number(e.target.value));
                  setSingleLogsPage(1);
                  setBulkLogsPage(1);
                }}
                className="bg-white border border-[#111111] px-1.5 py-0.5 rounded-none text-[11px] font-bold text-[#111111] focus:outline-none cursor-pointer"
              >
                <option value="5">5 rows</option>
                <option value="10">10 rows</option>
                <option value="20">20 rows</option>
                <option value="50">50 rows</option>
              </select>
              <span>per page</span>
            </div>
            
            <div className="flex items-center gap-1 font-mono font-bold text-gray-800">
              <button
                disabled={activeLogSubTab === 'single' ? singleLogsPage === 1 : bulkLogsPage === 1}
                onClick={() => {
                  if (activeLogSubTab === 'single') {
                    setSingleLogsPage(prev => Math.max(1, prev - 1));
                  } else {
                    setBulkLogsPage(prev => Math.max(1, prev - 1));
                  }
                }}
                className="px-2.5 py-1 border border-[#111111] disabled:opacity-30 disabled:cursor-not-allowed hover:bg-gray-50 font-black rounded-none cursor-pointer"
              >
                &lt; PREV
              </button>
              <span className="px-3.5 text-xs text-gray-500 font-roboto font-black uppercase tracking-wider">
                Page {activeLogSubTab === 'single' ? singleLogsPage : bulkLogsPage} of {activeLogSubTab === 'single' ? totalSinglePages || 1 : totalBulkPages || 1}
              </span>
              <button
                disabled={activeLogSubTab === 'single' ? singleLogsPage >= totalSinglePages : bulkLogsPage >= totalBulkPages}
                onClick={() => {
                  if (activeLogSubTab === 'single') {
                    setSingleLogsPage(prev => Math.min(totalSinglePages, prev + 1));
                  } else {
                    setBulkLogsPage(prev => Math.min(totalBulkPages, prev + 1));
                  }
                }}
                className="px-2.5 py-1 border border-[#111111] disabled:opacity-30 disabled:cursor-not-allowed hover:bg-gray-50 font-black rounded-none cursor-pointer"
              >
                NEXT &gt;
              </button>
            </div>
          </div>
        </>
      )}

      {/* Selected SMS Details Modal */}
      {selectedLog && (
        <div className="fixed inset-0 bg-[#111111]/70 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white border-4 border-[#111111] w-full max-w-lg shadow-[8px_8px_0px_0px_rgba(17,17,17,1)] relative p-6 space-y-4 rounded-none">
            <button
              onClick={() => setSelectedLog(null)}
              className="absolute top-4 right-4 border-2 border-[#111111] hover:bg-gray-50 text-[#111111] p-1 font-black transition-colors rounded-none cursor-pointer animate-none"
            >
              <X className="w-4 h-4" />
            </button>
            
            <div className="flex items-center gap-2 text-[#E50012] font-bebas text-2xl font-bold tracking-wider uppercase border-b-2 border-[#111111] pb-3 pr-8">
              <Eye className="w-5 h-5 flex-shrink-0" />
              SMS Job Dispatch Details
            </div>
            
            <div className="space-y-3 text-xs leading-relaxed">
              <div className="grid grid-cols-3 gap-1 py-1.5 border-b border-gray-150">
                <span className="font-roboto font-black text-gray-500 uppercase tracking-wider text-[9px] self-center">Job ID</span>
                <span className="col-span-2 font-mono font-bold text-gray-800 break-all select-all">{selectedLog._id}</span>
              </div>
              <div className="grid grid-cols-3 gap-1 py-1.5 border-b border-gray-150">
                <span className="font-roboto font-black text-gray-500 uppercase tracking-wider text-[9px] self-center">Recipient</span>
                <span className="col-span-2 font-mono font-bold text-[#111111] text-sm break-all">{displayPhoneNumber(selectedLog.recipient || selectedLog.phone_number)}</span>
              </div>
              <div className="grid grid-cols-3 gap-1 py-1.5 border-b border-gray-150">
                <span className="font-roboto font-black text-gray-500 uppercase tracking-wider text-[9px]">Message Payload</span>
                <span className="col-span-2 font-mono font-bold text-gray-700 bg-gray-50 border border-gray-200 p-2.5 leading-normal max-h-24 overflow-y-auto whitespace-pre-wrap select-all">{selectedLog.message}</span>
              </div>
              <div className="grid grid-cols-3 gap-1 py-1.5 border-b border-gray-150">
                <span className="font-roboto font-black text-gray-500 uppercase tracking-wider text-[9px] self-center">Selected Gateway</span>
                <span className="col-span-2 font-mono font-bold text-gray-800 break-all">{selectedLog.device_uuid}</span>
              </div>
              <div className="grid grid-cols-3 gap-1 py-1.5 border-b border-gray-150">
                <span className="font-roboto font-black text-gray-500 uppercase tracking-wider text-[9px] self-center">Dispatch Status</span>
                <div className="col-span-2">
                  <span className={`inline-block px-2.5 py-0.5 border border-[#111111] text-[9px] font-black uppercase ${
                    selectedLog.status === 'SENT' ? 'bg-[#E8F5E9] text-[#2E7D32]' :
                    selectedLog.status === 'FAILED' || selectedLog.status === 'ABANDONED' ? 'bg-[#FFEBEE] text-[#E50012]' : 'bg-[#FFF9C4] text-[#F57F17]'
                  }`}>
                    {selectedLog.status}
                  </span>
                </div>
              </div>
              {selectedLog.sent_at && (
                <div className="grid grid-cols-3 gap-1 py-1.5 border-b border-gray-150">
                  <span className="font-roboto font-black text-gray-500 uppercase tracking-wider text-[9px] self-center">Dispatched Time</span>
                  <span className="col-span-2 font-mono font-bold text-gray-800">{new Date(selectedLog.sent_at).toLocaleString()}</span>
                </div>
              )}
              <div className="grid grid-cols-3 gap-1 py-1.5">
                <span className="font-roboto font-black text-gray-500 uppercase tracking-wider text-[9px] self-center">Logged Date</span>
                <span className="col-span-2 font-mono font-bold text-gray-800">{new Date(selectedLog.created_at).toLocaleString()}</span>
              </div>
            </div>
          </div>
        </div>
      )}
    </section>
  );
}
