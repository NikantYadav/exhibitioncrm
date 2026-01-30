'use client';

import { AppShell } from '@/components/layout/AppShell';
import { Input } from '@/components/ui/Input';
import { Button } from '@/components/ui/Button';
import { FileSpreadsheet, Wifi, Download, Upload } from 'lucide-react';
import { MarketingAssets } from '@/components/settings/MarketingAssets';
import { getAssets } from '@/app/actions/assets';

export default async function SettingsPage() {
    const initialAssets = await getAssets();

    return (
        <AppShell>
            <div className="max-w-4xl mx-auto">
                <div className="mb-8">
                    <h1 className="text-display mb-2">Settings</h1>
                    <p className="text-body">Manage your CRM configuration and integrations</p>
                </div>





                {/* Data Management */}
                <div className="premium-card p-6 mb-6">
                    <div className="flex items-center gap-3 mb-6">
                        <div className="p-2 bg-purple-50 rounded-lg">
                            <FileSpreadsheet className="w-5 h-5 text-purple-600" />
                        </div>
                        <div>
                            <h3 className="text-card-title">Data Management</h3>
                            <p className="text-caption">Import and export your contacts and data</p>
                        </div>
                    </div>

                    <div className="space-y-6">
                        <div>
                            <h4 className="text-sm font-semibold text-stone-900 mb-3">Export Data</h4>
                            <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                                <a href="/api/export/excel" className="w-full" download>
                                    <Button variant="secondary" className="w-full justify-center">
                                        <Download className="w-4 h-4 mr-2" />
                                        Excel
                                    </Button>
                                </a>
                                <a href="/api/export/csv" className="w-full" download>
                                    <Button variant="secondary" className="w-full justify-center">
                                        <Download className="w-4 h-4 mr-2" />
                                        CSV
                                    </Button>
                                </a>
                                <a href="/api/export?type=template" className="w-full">
                                    <Button variant="secondary" className="w-full justify-center">
                                        <Download className="w-4 h-4 mr-2" />
                                        Template
                                    </Button>
                                </a>
                            </div>
                        </div>

                        <div className="border-t border-stone-100 pt-6">
                            <h4 className="text-sm font-semibold text-stone-900 mb-3">Import Data</h4>
                            <label className="block w-full">
                                <Button className="w-full sm:w-auto relative">
                                    <Upload className="w-4 h-4 mr-2" />
                                    Import Contacts from Excel/CSV
                                    <input type="file" accept=".xlsx,.xls,.csv" className="absolute inset-0 w-full h-full opacity-0 cursor-pointer" />
                                </Button>
                            </label>
                        </div>
                    </div>
                </div>

                {/* Marketing Assets */}
                <div className="premium-card p-6 mb-6">
                    <div className="flex items-center gap-3 mb-6">
                        <div className="p-2 bg-pink-50 rounded-lg">
                            <FileSpreadsheet className="w-5 h-5 text-pink-600" />
                        </div>
                        <div>
                            <h3 className="text-card-title">Marketing Assets</h3>
                            <p className="text-caption">Manage brochures and catalogs for follow-up emails</p>
                        </div>
                    </div>

                    <MarketingAssets initialAssets={initialAssets} />
                </div>

                {/* Sync Status */}
                <div className="premium-card p-6 mb-6">
                    <div className="flex items-center gap-3 mb-6">
                        <div className="p-2 bg-amber-50 rounded-lg">
                            <Wifi className="w-5 h-5 text-amber-600" />
                        </div>
                        <div>
                            <h3 className="text-card-title">Offline Sync</h3>
                            <p className="text-caption">Monitor and manage offline data synchronization</p>
                        </div>
                    </div>

                    <div className="space-y-3">
                        <div className="flex justify-between items-center p-4 bg-stone-50 rounded-lg">
                            <div>
                                <div className="font-medium text-sm text-stone-900">Sync Queue</div>
                                <div className="text-caption">0 items pending sync</div>
                            </div>
                            <Button variant="secondary" size="sm">
                                Sync Now
                            </Button>
                        </div>

                        <div className="flex justify-between items-center p-4 bg-stone-50 rounded-lg">
                            <div>
                                <div className="font-medium text-sm text-stone-900">Cache Status</div>
                                <div className="text-caption">Last synced: Never</div>
                            </div>
                            <Button variant="secondary" size="sm">
                                Clear Cache
                            </Button>
                        </div>
                    </div>
                </div>


            </div>
        </AppShell>
    );
}
