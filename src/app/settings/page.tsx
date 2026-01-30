'use client';

import { useState, useEffect } from 'react';
import { AppShell } from '@/components/layout/AppShell';
import { Button } from '@/components/ui/Button';
import { FileSpreadsheet, Wifi, Download, Upload, Shield, Database, Cloud } from 'lucide-react';
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
                    <h1 className="text-4xl font-black text-stone-900 tracking-tight mb-3">System Control</h1>
                    <p className="text-stone-500 font-medium italic">Configure your environment, identity archives, and marketing assets.</p>
                </div>

                <div className="grid grid-cols-1 xl:grid-cols-3 gap-12">
                    <div className="xl:col-span-2 space-y-12">
                        {/* Integrated Profile Section */}
                        <section>
                            <div className="flex items-center gap-3 mb-6">
                                <div className="p-2 bg-stone-100 rounded-lg">
                                    <Shield className="w-4 h-4 text-stone-600" />
                                </div>
                                <h2 className="text-sm font-bold text-stone-900 uppercase tracking-widest">Security & Identity</h2>
                            </div>
                            <ProfileSection />
                        </section>

                        {/* Marketing Assets */}
                        <section>
                            <div className="flex items-center gap-3 mb-6">
                                <div className="p-2 bg-stone-100 rounded-lg">
                                    <Cloud className="w-4 h-4 text-stone-600" />
                                </div>
                                <h2 className="text-sm font-bold text-stone-900 uppercase tracking-widest">Asset Repository</h2>
                            </div>
                            <div className="premium-card p-1">
                                <MarketingAssets initialAssets={assets} />
                            </div>
                        </section>
                    </div>

                    <div className="space-y-12">
                        {/* Data Management */}
                        <section>
                            <div className="flex items-center gap-3 mb-6">
                                <div className="p-2 bg-stone-100 rounded-lg">
                                    <Database className="w-4 h-4 text-stone-600" />
                                </div>
                                <h2 className="text-sm font-bold text-stone-900 uppercase tracking-widest">Data Stewardship</h2>
                            </div>
                            <div className="premium-card p-8 space-y-8">
                                <div>
                                    <h4 className="text-[10px] font-bold text-stone-400 uppercase tracking-widest mb-4">Export Archives</h4>
                                    <div className="grid grid-cols-2 gap-3">
                                        <a href="/api/export/excel" className="w-full" download>
                                            <Button variant="outline" className="w-full justify-center border-stone-200">
                                                <Download className="w-4 h-4 mr-2" />
                                                Excel
                                            </Button>
                                        </a>
                                        <a href="/api/export/csv" className="w-full" download>
                                            <Button variant="outline" className="w-full justify-center border-stone-200">
                                                <Download className="w-4 h-4 mr-2" />
                                                CSV
                                            </Button>
                                        </a>
                                    </div>
                                </div>

                                <div className="pt-8 border-t border-stone-100">
                                    <h4 className="text-[10px] font-bold text-stone-400 uppercase tracking-widest mb-4">Ingestion</h4>
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
                                    <div className="space-y-3">
                                        <div className="flex justify-between items-center p-4 bg-stone-50 rounded-2xl border border-stone-100">
                                            <div>
                                                <div className="font-bold text-xs text-stone-900">Cache Active</div>
                                                <div className="text-[10px] text-stone-400">0 records pending</div>
                                            </div>
                                            <div className="w-2 h-2 rounded-full bg-green-500 animate-pulse" />
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </section>

                    </div>
                </div>
            </div>
        </AppShell>
    );
}
