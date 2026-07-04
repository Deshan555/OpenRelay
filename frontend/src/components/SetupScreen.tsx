import React, { useState } from 'react';
import { Sliders } from 'lucide-react';
import { API_BASE_URL } from '../types';

interface SetupScreenProps {
  onInitialize: (token: string, username: string) => void;
}

export default function SetupScreen({ onInitialize }: SetupScreenProps) {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!username.trim() || !password || !confirmPassword) {
      setError('All fields are required.');
      return;
    }
    if (password !== confirmPassword) {
      setError('Passwords do not match.');
      return;
    }
    if (password.length < 6) {
      setError('Password must be at least 6 characters.');
      return;
    }
    setLoading(true);
    setError('');
    try {
      const res = await fetch(`${API_BASE_URL}/api/v2/admin/add-account`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username: username.trim(), password })
      });
      const data = await res.json();
      if (res.ok) {
        onInitialize(data.token, data.username);
      } else {
        setError(data.detail || 'Failed to initialize account.');
      }
    } catch (err) {
      setError('Network error during initialization.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-[#F5F5F5] flex flex-col items-center justify-center p-6 select-none font-roboto">
      <div className="bg-white border-2 border-[#111111] p-8 max-w-md w-full shadow-[6px_6px_0px_0px_rgba(17,17,17,1)]">
        <div className="flex items-center gap-3 mb-6 pb-4 border-b-2 border-[#111111]">
          <div className="p-2 bg-[#E50012] border-2 border-[#111111] text-white">
            <Sliders className="w-6 h-6" />
          </div>
          <div>
            <h2 className="font-bebas text-3xl font-bold tracking-wider text-[#111111] leading-none mb-1">
              SYSTEM INITIALIZATION
            </h2>
            <p className="text-[9px] font-black text-gray-500 uppercase tracking-wider font-roboto">
              Create the primary Administrator Account
            </p>
          </div>
        </div>

        <form onSubmit={handleSubmit} className="space-y-4">
          {error && (
            <div className="bg-[#FFEBEE] border-2 border-[#E50012] p-3 text-xs text-[#E50012] font-bold uppercase font-roboto">
              ⚠️ {error}
            </div>
          )}

          <div>
            <label className="block text-[10px] font-black text-gray-700 mb-1.5 uppercase tracking-wider font-roboto">
              Admin Username
            </label>
            <input
              type="text"
              placeholder="e.g. admin"
              value={username}
              onChange={(e) => setUsername(e.target.value)}
              required
              className="w-full bg-white border-2 border-[#111111] focus:border-[#E50012] focus:ring-0 rounded-none px-3.5 py-2.5 text-[#111111] text-xs font-bold focus:outline-none transition-colors"
            />
          </div>

          <div>
            <label className="block text-[10px] font-black text-gray-700 mb-1.5 uppercase tracking-wider font-roboto">
              Password
            </label>
            <input
              type="password"
              placeholder="••••••"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              className="w-full bg-white border-2 border-[#111111] focus:border-[#E50012] focus:ring-0 rounded-none px-3.5 py-2.5 text-[#111111] text-xs font-bold focus:outline-none transition-colors"
            />
          </div>

          <div>
            <label className="block text-[10px] font-black text-gray-700 mb-1.5 uppercase tracking-wider font-roboto">
              Confirm Password
            </label>
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
            disabled={loading}
            className="w-full bg-[#111111] hover:bg-gray-800 text-white font-black uppercase text-xs tracking-wider py-3 border-2 border-[#111111] hover:shadow-[4px_4px_0px_0px_rgba(17,17,17,0.15)] transition-all duration-100 flex items-center justify-center gap-2 cursor-pointer font-bold"
          >
            {loading ? 'Initializing...' : 'Initialize & Log In'}
          </button>
        </form>
      </div>
    </div>
  );
}
