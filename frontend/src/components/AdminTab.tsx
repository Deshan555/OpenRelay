import React, { useState, useEffect } from 'react';
import { UserPlus, Trash2, CheckCircle2, AlertTriangle, Users } from 'lucide-react';
import { API_BASE_URL } from '../types';

interface AdminTabProps {
  getAuthHeaders: (extraHeaders?: Record<string, string>) => Record<string, string>;
  currentAdminUsername: string | null;
}

export default function AdminTab({ getAuthHeaders, currentAdminUsername }: AdminTabProps) {
  const [admins, setAdmins] = useState<string[]>([]);
  const [loading, setLoading] = useState(false);
  const [statusMsg, setStatusMsg] = useState<{ success: boolean; message: string } | null>(null);

  // New admin registration form states
  const [newUsername, setNewUsername] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [formLoading, setFormLoading] = useState(false);

  const fetchAdmins = async () => {
    try {
      setLoading(true);
      const res = await fetch(`${API_BASE_URL}/api/v2/admin/accounts`, {
        headers: getAuthHeaders()
      });
      if (res.ok) {
        const data = await res.json();
        setAdmins(data);
      }
    } catch (err) {
      console.error("Error fetching admin accounts:", err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchAdmins();
  }, []);

  const handleRegister = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!newUsername.trim() || !newPassword || !confirmPassword) {
      setStatusMsg({ success: false, message: 'All fields are required.' });
      return;
    }
    if (newPassword !== confirmPassword) {
      setStatusMsg({ success: false, message: 'Passwords do not match.' });
      return;
    }
    if (newPassword.length < 6) {
      setStatusMsg({ success: false, message: 'Password must be at least 6 characters.' });
      return;
    }
    setFormLoading(true);
    setStatusMsg(null);
    try {
      const res = await fetch(`${API_BASE_URL}/api/v2/admin/add-account`, {
        method: 'POST',
        headers: getAuthHeaders({ 'Content-Type': 'application/json' }),
        body: JSON.stringify({ username: newUsername.trim(), password: newPassword })
      });
      const data = await res.json();
      if (res.ok) {
        setStatusMsg({ success: true, message: `Admin account '${data.username}' created successfully!` });
        setNewUsername('');
        setNewPassword('');
        setConfirmPassword('');
        fetchAdmins();
      } else {
        setStatusMsg({ success: false, message: data.detail || 'Failed to create account.' });
      }
    } catch (err) {
      setStatusMsg({ success: false, message: 'Network error during registration.' });
    } finally {
      setFormLoading(false);
    }
  };

  const handleDelete = async (username: string) => {
    if (username.toLowerCase() === currentAdminUsername?.toLowerCase()) {
      alert("Self-deletion is forbidden. You cannot delete your own logged-in session.");
      return;
    }
    if (!window.confirm(`Are you sure you want to delete admin account '${username}'?`)) {
      return;
    }
    try {
      const res = await fetch(`${API_BASE_URL}/api/v2/admin/accounts/${username}`, {
        method: 'DELETE',
        headers: getAuthHeaders()
      });
      const data = await res.json();
      if (res.ok) {
        setStatusMsg({ success: true, message: `Admin account '${username}' deleted successfully.` });
        fetchAdmins();
      } else {
        setStatusMsg({ success: false, message: data.detail || 'Failed to delete account.' });
      }
    } catch (err) {
      setStatusMsg({ success: false, message: 'Network error while deleting account.' });
    }
  };

  return (
    <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 items-start">
      {/* Registration Form */}
      <section className="lg:col-span-2 space-y-4">
        <h2 className="font-bebas text-2xl font-bold tracking-wider text-[#111111] flex items-center gap-2">
          REGISTER NEW ADMIN
          <span className="font-roboto text-[9px] bg-[#E50012] text-white px-2 py-0.5 font-bold uppercase tracking-wider font-bold">ADD ACCOUNT</span>
        </h2>
        <div className="bg-white border-2 border-[#111111] p-5">
          <form onSubmit={handleRegister} className="space-y-4">
            <div>
              <label className="block text-[10px] font-black text-gray-700 mb-1.5 uppercase tracking-wider font-roboto">Username</label>
              <input
                type="text"
                placeholder="e.g. supervisor"
                value={newUsername}
                onChange={(e) => setNewUsername(e.target.value)}
                required
                className="w-full bg-white border-2 border-[#111111] focus:border-[#E50012] focus:ring-0 rounded-none px-3.5 py-2.5 text-[#111111] text-xs font-bold focus:outline-none transition-colors"
              />
            </div>
            <div>
              <label className="block text-[10px] font-black text-gray-700 mb-1.5 uppercase tracking-wider font-roboto">Password</label>
              <input
                type="password"
                placeholder="••••••"
                value={newPassword}
                onChange={(e) => setNewPassword(e.target.value)}
                required
                className="w-full bg-white border-2 border-[#111111] focus:border-[#E50012] focus:ring-0 rounded-none px-3.5 py-2.5 text-[#111111] text-xs font-bold focus:outline-none transition-colors"
              />
            </div>
            <div>
              <label className="block text-[10px] font-black text-gray-700 mb-1.5 uppercase tracking-wider font-roboto">Confirm Password</label>
              <input
                type="password"
                placeholder="••••••"
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                required
                className="w-full bg-white border-2 border-[#111111] focus:border-[#E50012] focus:ring-0 rounded-none px-3.5 py-2.5 text-[#111111] text-xs font-bold focus:outline-none transition-colors"
              />
            </div>

            <button
              type="submit"
              disabled={formLoading}
              className="w-full flex items-center justify-center gap-2 bg-[#E50012] hover:bg-[#B3000E] disabled:bg-gray-200 border-2 border-[#111111] text-white font-black uppercase py-3.5 px-4 text-xs font-roboto tracking-wider transition-colors duration-150 cursor-pointer font-bold"
            >
              <UserPlus className="w-4 h-4" />
              {formLoading ? 'Creating User...' : 'Add Admin Account'}
            </button>
          </form>

          {statusMsg && (
            <div className={`mt-4 p-4 border-2 flex gap-3 text-xs rounded-none ${statusMsg.success ? 'bg-[#E8F5E9] border-[#2E7D32] text-[#2E7D32]' : 'bg-[#FFEBEE] border-[#E50012] text-[#E50012]'}`}>
              {statusMsg.success ? <CheckCircle2 className="w-5 h-5 flex-shrink-0" /> : <AlertTriangle className="w-5 h-5 flex-shrink-0" />}
              <div>
                <h4 className="font-black uppercase tracking-wider">{statusMsg.success ? 'Success' : 'Error'}</h4>
                <p className="mt-1 font-medium leading-relaxed">{statusMsg.message}</p>
              </div>
            </div>
          )}
        </div>
      </section>

      {/* Admin Account List Management */}
      <section className="space-y-4">
        <h2 className="font-bebas text-2xl font-bold tracking-wider text-[#111111] flex items-center gap-2">
          ADMIN ACCOUNTS
          <span className="font-roboto text-[9px] bg-[#111111] text-white px-2 py-0.5 font-bold uppercase tracking-wider font-bold">MANAGEMENT</span>
        </h2>
        <div className="bg-white border-2 border-[#111111] overflow-hidden shadow-[4px_4px_0px_0px_rgba(17,17,17,1)]">
          <div className="bg-gray-50 border-b border-[#111111] p-3 flex items-center gap-2 text-[10px] font-black uppercase text-gray-500 tracking-wider">
            <Users className="w-4 h-4 text-gray-700" />
            <span>Registered Administrators ({admins.length})</span>
          </div>
          
          {loading && admins.length === 0 ? (
            <div className="p-6 text-center text-xs font-bold text-gray-500 uppercase tracking-widest animate-pulse font-roboto">Loading...</div>
          ) : (
            <div className="divide-y-2 divide-[#111111]">
              {admins.map((username) => {
                const isSelf = username.toLowerCase() === currentAdminUsername?.toLowerCase();
                return (
                  <div key={username} className="flex justify-between items-center p-3.5 bg-white hover:bg-gray-50 transition-colors">
                    <div className="flex items-center gap-2">
                      <span className="font-mono text-sm font-bold text-[#111111]">{username}</span>
                      {isSelf && (
                        <span className="text-[7.5px] bg-[#E8F5E9] text-[#2E7D32] border border-[#2E7D32] px-1 py-0.2 font-black uppercase font-roboto leading-none">
                          YOU
                        </span>
                      )}
                    </div>
                    
                    {!isSelf && (
                      <button
                        onClick={() => handleDelete(username)}
                        className="p-1.5 border border-[#111111] bg-[#FFEBEE] hover:bg-[#FFCDD2] text-[#E50012] transition-colors cursor-pointer"
                        title={`Delete ${username}`}
                      >
                        <Trash2 className="w-3.5 h-3.5" />
                      </button>
                    )}
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </section>
    </div>
  );
}
