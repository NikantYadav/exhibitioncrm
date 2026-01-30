'use client';

import { useState, useEffect } from 'react';
import { AppShell } from '@/components/layout/AppShell';
import { Button } from '@/components/ui/Button';
import { FileSpreadsheet, Wifi, Download, Upload, User, Database, Cloud } from 'lucide-react';
import { MarketingAssets } from '@/components/settings/MarketingAssets';
import { ProfileSection } from '@/components/settings/ProfileSection';
import { getAssets, MarketingAsset } from '@/app/actions/assets';
import { toast } from 'sonner';

export default function SettingsPage() {
    const [assets, setAssets] = useState<MarketingAsset[]>([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        const loadAssets = async () => {
            try {
                const initialAssets = await getAssets();
                setAssets(initialAssets);
            } catch (error) {
                console.error('Failed to load assets:', error);
            } finally {
                setLoading(false);
            }
        };
        loadAssets();
    }, []);

    return (
        <AppShell>
            <div className="max-w-7xl mx-auto px-4 py-8">
                <div className="mb-12">
                    <h1 className="text-4xl font-black text-stone-900 tracking-tight mb-3">Settings</h1>
                    <p className="text-stone-500 font-medium italic">Manage your profile, assets, and data.</p>
                </div>

                <div className="grid grid-cols-1 xl:grid-cols-3 gap-12">
                    {/* Main Workbench (Profile) */}
                    <div className="xl:col-span-2 space-y-12">
                        <ProfileSection />
                    </div>

                    {/* Sidebar (Data & Assets) */}
                    <div className="space-y-12">
                        <section className="premium-card overflow-hidden">
                            <div className="px-8 py-6 border-b border-stone-100 bg-stone-50/30 flex items-center gap-3">
                                <div className="p-2 bg-white rounded-lg shadow-sm border border-stone-100">
                                    <Database className="w-4 h-4 text-stone-600" />
                                </div>
                                <h2 className="text-sm font-black text-stone-900 uppercase tracking-widest">Data Management</h2>
                            </div>

                            <div className="p-8 space-y-8">
                                <div>
                                    <h4 className="text-[10px] font-bold text-stone-400 uppercase tracking-widest mb-4">Export Data</h4>
                                    <div className="grid grid-cols-2 gap-3">
                                        <a href="/api/export/excel" className="w-full" download>
                                            <Button variant="outline" className="w-full justify-center border-stone-200 rounded-xl">
                                                <Download className="w-4 h-4 mr-2" />
                                                Excel
                                            </Button>
                                        </a>
                                        <a href="/api/export/csv" className="w-full" download>
                                            <Button variant="outline" className="w-full justify-center border-stone-200 rounded-xl">
                                                <Download className="w-4 h-4 mr-2" />
                                                CSV
                                            </Button>
                                        </a>
                                    </div>
                                </div>

                                <div className="pt-8 border-t border-stone-100">
                                    <h4 className="text-[10px] font-bold text-stone-400 uppercase tracking-widest mb-4">Import Data</h4>
                                    <label className="block w-full">
                                        <Button className="w-full bg-stone-900 hover:bg-black text-white rounded-xl shadow-lg shadow-stone-200">
                                            <Upload className="w-4 h-4 mr-2" />
                                            Import Records
                                            <input type="file" accept=".xlsx,.xls,.csv" className="hidden" />
                                        </Button>
                                    </label>
                                </div>

                                <div className="pt-8 border-t border-stone-100">
                                    <div className="flex items-center gap-2 text-[10px] font-bold text-stone-400 uppercase tracking-widest mb-4">
                                        <Wifi className="w-3 h-3" />
                                        Sync Status
                                    </div>
                                    <div className="flex justify-between items-center p-4 bg-stone-50 rounded-2xl border border-stone-100">
                                        <div>
                                            <div className="font-bold text-xs text-stone-900">Live Sync</div>
                                            <div className="text-[10px] text-stone-400">Database connected</div>
                                        </div>
                                        <div className="w-2 h-2 rounded-full bg-green-500 animate-pulse" />
                                    </div>
                                </div>
                            </div>
                        </section>

                        <section className="premium-card overflow-hidden">
                            {!loading ? (
                                <MarketingAssets initialAssets={assets} />
                            ) : (
                                <div className="p-8 flex justify-center">
                                    <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-stone-900"></div>
                                </div>
                            )}
                        </section>
                    </div>
                </div>
            </div>
        </AppShell>
    );
}
