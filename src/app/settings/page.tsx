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
                    <h1 className="text-4xl font-black text-stone-900 tracking-tight leading-tight mb-2">Settings</h1>
                    <p className="text-sm font-medium text-stone-500 italic">Configure your strategic command center and digital assets.</p>
                </div>

                <div className="grid grid-cols-1 xl:grid-cols-3 gap-12">
                    {/* Main Workbench (Profile) */}
                    <div className="xl:col-span-2 space-y-12">
                        <ProfileSection />
                    </div>

                    {/* Sidebar (Data & Assets) */}
                    <div className="space-y-12">
                        <section className="bg-white rounded-[2rem] border border-stone-100 shadow-sm overflow-hidden flex flex-col">
                            <div className="px-8 py-6 border-b border-stone-100 bg-stone-50/30 flex items-center gap-4">
                                <div className="p-2.5 bg-stone-900 text-white rounded-xl shadow-lg ring-4 ring-white">
                                    <Database className="w-4 h-4" strokeWidth={2.5} />
                                </div>
                                <h2 className="text-xs font-black text-stone-900 uppercase tracking-[0.2em]">Data Operations</h2>
                            </div>

                            <div className="p-8 space-y-10">
                                <div>
                                    <h4 className="text-[10px] font-black text-stone-400 uppercase tracking-widest mb-4">Lead Intelligence Export</h4>
                                    <div className="grid grid-cols-2 gap-4">
                                        <a href="/api/export/excel" className="w-full" download>
                                            <Button variant="outline" className="w-full h-11 justify-center border-stone-200 rounded-xl font-bold transition-all hover:bg-stone-50">
                                                <Download className="w-4 h-4 mr-2" />
                                                Excel
                                            </Button>
                                        </a>
                                        <a href="/api/export/csv" className="w-full" download>
                                            <Button variant="outline" className="w-full h-11 justify-center border-stone-200 rounded-xl font-bold transition-all hover:bg-stone-50">
                                                <Download className="w-4 h-4 mr-2" />
                                                CSV
                                            </Button>
                                        </a>
                                    </div>
                                </div>

                                <div className="pt-10 border-t border-stone-50">
                                    <h4 className="text-[10px] font-black text-stone-400 uppercase tracking-widest mb-4">External Data Ingest</h4>
                                    <label className="block w-full">
                                        <Button className="w-full h-12 bg-stone-900 hover:bg-stone-800 text-white rounded-xl shadow-xl shadow-stone-900/10 font-black uppercase tracking-widest text-[10px]">
                                            <Upload className="w-4 h-4 mr-2" strokeWidth={2.5} />
                                            Import Records
                                            <input type="file" accept=".xlsx,.xls,.csv" className="hidden" />
                                        </Button>
                                    </label>
                                </div>

                                <div className="pt-10 border-t border-stone-50">
                                    <div className="flex items-center gap-2 text-[10px] font-black text-stone-400 uppercase tracking-widest mb-4">
                                        <Wifi className="w-3.5 h-3.5" strokeWidth={2.5} />
                                        Live Pulse Status
                                    </div>
                                    <div className="flex justify-between items-center p-5 bg-stone-900 rounded-2xl shadow-xl shadow-stone-900/10 border border-white/10 text-white relative overflow-hidden group">
                                        <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/5 to-transparent -translate-x-full group-hover:translate-x-full transition-transform duration-1000"></div>
                                        <div className="relative z-10">
                                            <div className="font-black text-xs uppercase tracking-widest">Active Sync</div>
                                            <div className="text-[10px] text-white/40 font-bold mt-0.5">Cloud Nexus Connected</div>
                                        </div>
                                        <div className="w-2.5 h-2.5 rounded-full bg-emerald-400 animate-pulse shadow-[0_0_12px_rgba(52,211,153,0.8)] relative z-10" />
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
