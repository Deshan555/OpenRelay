import { useState, useEffect } from 'react';
import { Smartphone, RefreshCw, LayoutGrid, Table as TableIcon, Battery as BatteryIcon, MapPin, Map } from 'lucide-react';
import { type Device, API_BASE_URL } from '../types';

declare const L: any;

interface DevicesTabProps {
  devices: Device[];
  loading: boolean;
  fetchDevices: () => void;
  getAuthHeaders: (extraHeaders?: Record<string, string>) => Record<string, string>;
}

export default function DevicesTab({
  devices,
  loading,
  fetchDevices,
  getAuthHeaders
}: DevicesTabProps) {
  const [viewMode, setViewMode] = useState<'grid' | 'table' | 'map'>(() => {
    return (localStorage.getItem('devices_view_mode') as 'grid' | 'table' | 'map') || 'grid';
  });

  const toggleViewMode = (mode: 'grid' | 'table' | 'map') => {
    setViewMode(mode);
    localStorage.setItem('devices_view_mode', mode);
  };

  // Leaflet Map Initialization and lifecycle
  useEffect(() => {
    if (viewMode !== 'map') return;
    if (typeof L === 'undefined') {
      console.warn("Leaflet global library 'L' is undefined. Make sure it is loaded via index.html CDN.");
      return;
    }

    const mapElement = document.getElementById('leaflet-map');
    if (!mapElement) return;

    // Initialize map
    const map = L.map('leaflet-map').setView([20.0, 0.0], 2);

    // CartoDB Positron tile layer matching neobrutalist interface style
    L.tileLayer('https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png', {
      attribution: '&copy; OpenStreetMap contributors &copy; CARTO',
      subdomains: 'abcd',
      maxZoom: 20
    }).addTo(map);

    const markers: any[] = [];
    const geoDevices = devices.filter(d => d.latitude !== null && d.longitude !== null);

    geoDevices.forEach(device => {
      const lat = device.latitude!;
      const lon = device.longitude!;
      const isOnline = device.status === 'online';

      // Pin Color Theme
      let markerColor = "#9E9E9E"; // offline gray
      if (isOnline) {
        markerColor = device.battery !== null && device.battery < 20 ? "#E50012" : "#2E7D32"; // red vs green
      }

      const customHtmlIcon = L.divIcon({
        html: `
          <div style="
            position: relative;
            width: 18px;
            height: 18px;
            background-color: ${markerColor};
            border: 2px solid #111111;
            border-radius: 50%;
            box-shadow: 2px 2px 0px 0px rgba(17,17,17,1);
            display: flex;
            align-items: center;
            justify-content: center;
          ">
            <div style="width: 5px; height: 5px; background-color: #ffffff; border-radius: 50%;"></div>
            ${isOnline ? `
              <div class="animate-ping" style="
                position: absolute;
                width: 24px;
                height: 24px;
                left: -5px;
                top: -5px;
                border-radius: 50%;
                background-color: ${markerColor};
                opacity: 0.25;
                pointer-events: none;
              "></div>
            ` : ''}
          </div>
        `,
        className: 'custom-leaflet-icon',
        iconSize: [18, 18],
        iconAnchor: [9, 9]
      });

      const popupContent = `
        <div style="font-family: 'Roboto', sans-serif; color: #111111; min-width: 190px;">
          <div style="border-bottom: 2px solid #111111; padding-bottom: 4px; margin-bottom: 6px; display: flex; justify-content: space-between; align-items: center;">
            <strong style="text-transform: uppercase; font-size: 12px; font-weight: 900; letter-spacing: 0.05em;">${device.name || 'Device'}</strong>
            <span style="
              border: 1px solid #111111;
              background-color: ${isOnline ? '#E8F5E9' : '#ECEFF1'};
              color: ${isOnline ? '#2E7D32' : '#546E7A'};
              font-size: 8px;
              font-weight: 900;
              padding: 1px 4px;
              text-transform: uppercase;
            ">${device.status}</span>
          </div>
          <div style="font-size: 10px; line-height: 1.4; font-family: monospace;">
            <div><strong>Model:</strong> ${device.model || 'N/A'}</div>
            <div><strong>Carrier:</strong> ${device.carrier || 'N/A'}</div>
            <div><strong>Battery:</strong> <span style="font-weight: bold; color: ${device.battery !== null && device.battery < 20 ? '#E50012' : '#111111'};">${device.battery !== null ? `${device.battery}%` : 'N/A'}</span></div>
            <div><strong>GPS:</strong> ${lat.toFixed(4)}°, ${lon.toFixed(4)}°</div>
            <div style="margin-top: 4px; border-top: 1px solid #eee; padding-top: 4px; color: #666; font-size: 9px;">
              <strong>Ping:</strong> ${device.last_seen ? new Date(device.last_seen).toLocaleTimeString() : 'Never'}
            </div>
          </div>
        </div>
      `;

      const marker = L.marker([lat, lon], { icon: customHtmlIcon })
        .bindPopup(popupContent, {
          closeButton: false,
          className: 'neobrutalist-leaflet-popup'
        })
        .addTo(map);

      // Open popup on hover
      marker.on('mouseover', () => {
        marker.openPopup();
      });

      markers.push(marker);
    });

    // Auto fit bounds
    if (geoDevices.length > 0) {
      const bounds = L.latLngBounds(geoDevices.map(d => [d.latitude!, d.longitude!]));
      map.fitBounds(bounds, { padding: [50, 50], maxZoom: 10 });
    }

    return () => {
      map.remove();
    };
  }, [viewMode, devices]);

  return (
    <section className="space-y-4">
      <div className="flex justify-between items-center">
        <h2 className="font-bebas text-2xl font-bold tracking-wider text-[#111111] flex items-center gap-2">
          REGISTERED DEVICES
          <span className="font-roboto text-[9px] bg-[#111111] text-white px-2 py-0.5 font-bold uppercase tracking-wider">LIVE STATUS</span>
        </h2>
        <div className="flex items-center gap-3">
          {/* View Mode Toggle */}
          <div className="flex border-2 border-[#111111] bg-white">
            <button
              onClick={() => toggleViewMode('grid')}
              className={`p-1.5 transition-colors cursor-pointer ${viewMode === 'grid' ? 'bg-[#111111] text-white' : 'text-[#111111] hover:bg-gray-100'}`}
              title="Grid View"
            >
              <LayoutGrid className="w-4 h-4" />
            </button>
            <button
              onClick={() => toggleViewMode('table')}
              className={`p-1.5 border-l-2 border-[#111111] transition-colors cursor-pointer ${viewMode === 'table' ? 'bg-[#111111] text-white' : 'text-[#111111] hover:bg-gray-100'}`}
              title="Table View"
            >
              <TableIcon className="w-4 h-4" />
            </button>
            <button
              onClick={() => toggleViewMode('map')}
              className={`p-1.5 border-l-2 border-[#111111] transition-colors cursor-pointer ${viewMode === 'map' ? 'bg-[#111111] text-white' : 'text-[#111111] hover:bg-gray-100'}`}
              title="Map View"
            >
              <Map className="w-4 h-4" />
            </button>
          </div>

          <button
            onClick={fetchDevices}
            className="flex items-center gap-1.5 text-[10px] bg-white border-2 border-[#111111] hover:bg-gray-50 text-[#111111] font-black uppercase py-1.5 px-3 tracking-wider transition-colors duration-150 cursor-pointer"
          >
            <RefreshCw className={`w-3.5 h-3.5 ${loading ? 'animate-spin' : ''}`} />
            Refresh Devices
          </button>
        </div>
      </div>

      {devices.length === 0 ? (
        <div className="bg-white border-2 border-[#111111] p-10 text-center">
          <Smartphone className="w-14 h-14 text-gray-400 mx-auto mb-4" />
          <p className="font-roboto text-sm font-bold text-gray-700 uppercase">No registered devices found.</p>
          <p className="font-roboto text-xs text-gray-500 mt-1">Ensure the device simulator or mobile client is running and registered.</p>
        </div>
      ) : viewMode === 'grid' ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {devices.map((device) => {
            const isOnline = device.status === 'online';
            const batteryLevel = device.battery !== null ? Math.max(0, Math.min(100, device.battery)) : 64;
            const redFlex = batteryLevel;
            const blackFlex = 100 - redFlex;
            const signalStrength = device.signal !== null ? device.signal : 3;

            return (
              <div
                key={device.uuid}
                className={`bg-white border-2 border-[#111111] p-5 transition-all duration-150 hover:translate-x-0.5 hover:translate-y-0.5 hover:shadow-[4px_4px_0px_0px_rgba(17,17,17,1)] ${
                  isOnline ? 'opacity-100' : 'opacity-70'
                }`}
              >
                {/* Name & Status Header */}
                <div className="flex justify-between items-start mb-3.5">
                  <div>
                    <h3 className="font-bebas text-2xl font-bold text-[#111111] tracking-wide truncate max-w-[170px]">
                      {device.name?.toUpperCase() || 'UNNAMED DEVICE'}
                    </h3>
                    <p className="font-roboto text-[10px] text-gray-500 font-black mt-0.5 truncate max-w-[170px] font-mono">
                      UUID: {device.uuid}
                    </p>
                  </div>
                  <span className={`inline-flex items-center gap-1.5 px-3 py-1 border-2 border-[#111111] text-[10px] font-black uppercase ${
                    isOnline ? 'bg-[#E8F5E9] text-[#2E7D32]' : 'bg-gray-150 text-gray-600'
                  }`}>
                    <span className={`w-2 h-2 rounded-full ${isOnline ? 'bg-[#2E7D32] animate-pulse' : 'bg-gray-500'}`}></span>
                    {device.status}
                  </span>
                </div>

                {/* Specs */}
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
                  <div>
                    <span className="block text-gray-500 text-[10px] uppercase font-black tracking-wider">Queue Interval</span>
                    <select
                      value={device.regular_interval ?? 2.0}
                      onChange={async (e) => {
                        const val = parseFloat(e.target.value);
                        try {
                          const res = await fetch(`${API_BASE_URL}/api/v2/devices/${device.uuid}/config`, {
                            method: 'POST',
                            headers: getAuthHeaders({
                              'Content-Type': 'application/json'
                            }),
                            body: JSON.stringify({ regular_interval: val })
                          });
                          if (res.ok) {
                            fetchDevices();
                          } else {
                            alert('Failed to update sending interval.');
                          }
                        } catch (err) {
                          alert('Network error while updating interval.');
                        }
                      }}
                      className="mt-0.5 bg-white border border-[#111111] focus:border-[#E50012] focus:ring-0 rounded-none px-1 py-0.5 text-[#111111] text-[10px] font-bold focus:outline-none transition-colors cursor-pointer"
                    >
                      <option value="1">1s</option>
                      <option value="2">2s</option>
                      <option value="5">5s</option>
                      <option value="10">10s</option>
                    </select>
                  </div>
                </div>

                {/* Hardware */}
                <div className="grid grid-cols-3 gap-2 mt-4 items-center">
                  {/* Battery */}
                  <div className="flex flex-col items-start">
                    <span className="text-[10px] font-black text-gray-500 uppercase tracking-wider">Battery</span>
                    <div className="flex items-center gap-1.5 mt-1">
                      <BatteryIcon className={`w-4 h-4 ${device.battery && device.battery < 20 ? 'text-[#E50012] animate-bounce' : 'text-[#111111]'}`} />
                      <span className="font-bebas text-lg font-bold text-[#111111]">{device.battery !== null ? `${device.battery}%` : 'N/A'}</span>
                    </div>
                    <div className="h-1.5 w-full border border-[#111111] flex mt-1 bg-[#111111]">
                      {redFlex > 0 && <div className="bg-[#E50012] h-full" style={{ width: `${redFlex}%` }} />}
                      {blackFlex > 0 && <div className="bg-[#111111] h-full" style={{ width: `${blackFlex}%` }} />}
                    </div>
                  </div>

                  {/* Signal */}
                  <div className="flex flex-col items-start pl-2 border-l border-gray-300">
                    <span className="text-[10px] font-black text-gray-500 uppercase tracking-wider">Signal</span>
                    <div className="flex items-center gap-2 mt-1">
                      <div className="flex items-end gap-[3px]">
                        {Array.from({ length: 4 }).map((_, idx) => {
                          const barHeight = 4 + idx * 3;
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
                      <span className="font-bebas text-lg font-bold text-[#111111]">{device.signal !== null ? `${device.signal}/4` : 'N/A'}</span>
                    </div>
                  </div>

                  {/* GPS */}
                  <div className="flex flex-col items-start pl-2 border-l border-gray-300">
                    <span className="text-[10px] font-black text-gray-500 uppercase tracking-wider">Location</span>
                    <div className="flex items-center gap-1 mt-1 text-[#111111]">
                      <MapPin className="w-4 h-4 flex-shrink-0 text-gray-700" />
                      <span className="font-mono text-[9px] font-bold truncate max-w-[70px]">
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
      ) : viewMode === 'table' ? (
        <div className="bg-white border-2 border-[#111111] overflow-x-auto shadow-[4px_4px_0px_0px_rgba(17,17,17,1)]">
          <table className="w-full text-left border-collapse">
            <thead>
              <tr className="border-b-2 border-[#111111] bg-[#F5F5F5] font-bebas text-base uppercase tracking-wider text-[#111111]">
                <th className="p-4 border-r-2 border-[#111111]">Device Details</th>
                <th className="p-4 border-r-2 border-[#111111]">Connection Status</th>
                <th className="p-4 border-r-2 border-[#111111]">Hardware Telemetry</th>
                <th className="p-4 border-r-2 border-[#111111]">Queue Interval</th>
                <th className="p-4">Location</th>
              </tr>
            </thead>
            <tbody>
              {devices.map((device) => {
                const isOnline = device.status === 'online';
                const signalStrength = device.signal !== null ? device.signal : 3;

                return (
                  <tr key={device.uuid} className="border-b-2 border-[#111111] hover:bg-gray-50 transition-colors">
                    {/* Device Details */}
                    <td className="p-4 border-r-2 border-[#111111]">
                      <div className="font-bold text-sm text-[#111111] uppercase tracking-wide">
                        {device.name || 'Unnamed Device'}
                      </div>
                      <div className="text-[10px] text-gray-500 font-mono mt-0.5">
                        UUID: {device.uuid}
                      </div>
                      <div className="text-[10px] text-gray-600 font-mono mt-1 flex gap-2">
                        <span>Model: {device.model || 'N/A'}</span>
                        <span>OS: {device.android_version || 'N/A'}</span>
                      </div>
                    </td>

                    {/* Connection Status */}
                    <td className="p-4 border-r-2 border-[#111111]">
                      <div className="flex items-center gap-2">
                        <span className={`inline-flex items-center gap-1 px-2.5 py-0.5 border border-[#111111] text-[9px] font-black uppercase ${
                          isOnline ? 'bg-[#E8F5E9] text-[#2E7D32]' : 'bg-gray-150 text-gray-600'
                        }`}>
                          <span className={`w-1.5 h-1.5 rounded-full ${isOnline ? 'bg-[#2E7D32] animate-pulse' : 'bg-gray-500'}`}></span>
                          {device.status}
                        </span>
                      </div>
                      <div className="text-[9px] text-gray-500 font-mono mt-1">
                        Ping: {device.last_seen ? new Date(device.last_seen).toLocaleTimeString() : 'Never'}
                      </div>
                    </td>

                    {/* Telemetry */}
                    <td className="p-4 border-r-2 border-[#111111]">
                      <div className="flex items-center gap-4">
                        {/* Battery */}
                        <div>
                          <span className="block text-[8px] font-black uppercase text-gray-500 tracking-wider">Battery</span>
                          <div className="flex items-center gap-1 mt-0.5">
                            <BatteryIcon className="w-3.5 h-3.5 text-gray-700" />
                            <span className="font-mono text-xs font-bold text-gray-800">{device.battery !== null ? `${device.battery}%` : 'N/A'}</span>
                          </div>
                        </div>

                        {/* Signal */}
                        <div>
                          <span className="block text-[8px] font-black uppercase text-gray-500 tracking-wider">Signal</span>
                          <div className="flex items-center gap-1 mt-0.5">
                            <div className="flex items-end gap-[1.5px] h-3">
                              {Array.from({ length: 4 }).map((_, idx) => {
                                const barHeight = 3 + idx * 2.5;
                                const isFilled = idx < signalStrength;
                                return (
                                  <div
                                    key={idx}
                                    className="w-[1.8px]"
                                    style={{
                                      height: `${barHeight}px`,
                                      backgroundColor: isOnline && isFilled ? '#111111' : '#E2E8F0'
                                    }}
                                  />
                                );
                              })}
                            </div>
                            <span className="font-mono text-[10px] font-bold text-gray-800 ml-1">{device.signal !== null ? `${device.signal}/4` : 'N/A'}</span>
                          </div>
                        </div>

                        {/* Carrier */}
                        <div>
                          <span className="block text-[8px] font-black uppercase text-gray-500 tracking-wider">Carrier</span>
                          <span className="text-[10px] font-bold text-gray-800 truncate max-w-[80px] block mt-0.5">{device.carrier || 'N/A'}</span>
                        </div>
                      </div>
                    </td>

                    {/* Queue Interval */}
                    <td className="p-4 border-r-2 border-[#111111]">
                      <select
                        value={device.regular_interval ?? 2.0}
                        onChange={async (e) => {
                          const val = parseFloat(e.target.value);
                          try {
                            const res = await fetch(`${API_BASE_URL}/api/v2/devices/${device.uuid}/config`, {
                              method: 'POST',
                              headers: getAuthHeaders({
                                'Content-Type': 'application/json'
                              }),
                              body: JSON.stringify({ regular_interval: val })
                            });
                            if (res.ok) {
                              fetchDevices();
                            } else {
                              alert('Failed to update sending interval.');
                            }
                          } catch (err) {
                            alert('Network error while updating interval.');
                          }
                        }}
                        className="bg-white border border-[#111111] focus:border-[#E50012] focus:ring-0 rounded-none px-1.5 py-0.5 text-[#111111] text-[10px] font-bold focus:outline-none cursor-pointer"
                      >
                        <option value="1">1s</option>
                        <option value="2">2s</option>
                        <option value="5">5s</option>
                        <option value="10">10s</option>
                      </select>
                    </td>

                    {/* GPS Coordinates */}
                    <td className="p-4">
                      <div>
                        <span className="block text-[8px] font-black uppercase text-gray-500 tracking-wider">GPS Position</span>
                        <div className="flex items-center gap-1 mt-0.5 text-[#111111] w-full">
                          <MapPin className="w-3 h-3 flex-shrink-0" />
                          <span className="font-mono text-[9px] font-bold truncate max-w-[90px]">
                            {device.latitude !== null && device.longitude !== null
                              ? `${device.latitude.toFixed(3)}, ${device.longitude.toFixed(3)}`
                              : 'NO GPS'
                            }
                          </span>
                        </div>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      ) : (
        <div className="bg-white border-4 border-[#111111] p-6 shadow-[6px_6px_0px_0px_rgba(17,17,17,1)] relative select-none">
          <div className="mb-4">
            <span className="block text-[10px] font-black text-gray-500 uppercase tracking-widest font-mono">
              World Telemetry Operations Center
            </span>
            <h3 className="font-bebas text-xl font-bold tracking-wide text-[#111111] mt-0.5">
              LEAFLET INTERACTIVE DISPATCH MAP
            </h3>
          </div>

          {/* Leaflet map anchor element */}
          <div 
            id="leaflet-map" 
            className="w-full h-[520px] bg-gray-100 border-2 border-[#111111] relative z-10 shadow-[inner_4px_4px_0px_0px_rgba(0,0,0,0.05)]"
          />
        </div>
      )}
    </section>
  );
}
