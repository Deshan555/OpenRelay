export interface Device {
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
  regular_interval?: number;
}

export interface SmsLog {
  _id: string;
  device_uuid: string;
  recipient: string;
  message: string;
  status: string;
  created_at: string;
  sent_at: string | null;
}

export interface BulkSmsLog {
  _id: string;
  device_uuid: string;
  phone_number: string;
  message: string;
  status: string;
  created_at: string;
  sent_at: string | null;
}

export const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:8000';
