'use client';

import { AppShell } from '@/components/layout/AppShell';
import { Button } from '@/components/ui/Button';
import {
    Plug2,
    Zap,
    ShieldCheck,
    Share2,
    Database,
    Mail,
    MessageSquare,
    Globe,
    Lock,
    Command
} from 'lucide-react';

export default function IntegrationsPage() {
    const plannedIntegrations = [
        {
            name: 'Salesforce CRM',
            description: 'Direct bi-directional sync for leads, opportunities, and contact history.',
            icon: Database,
            status: 'Q3 2026'
        },
        {
            name: 'HubSpot Marketing',
            description: 'Automatic campaign tagging and workflow triggers for captured leads.',
            icon: Zap,
            status: 'Q3 2026'
        },
        {
            name: 'Zapier Automation',
            description: 'Connect exhibition data to 5,000+ custom business workflows.',
            icon: Share2,
            status: 'In Development'
        },
        {
            name: 'Microsoft Outlook',
            description: 'Sync drafts and contacts directly to your enterprise mailbox.',
            icon: Mail,
            status: 'Q2 2026'
        },
        {
            name: 'Slack Teams',
            description: 'Real-time alerts for high-value captures and team follow-up coordination.',
            icon: MessageSquare,
            status: 'Coming Soon'
        },
        {
            name: 'LinkedIn Sales',
            description: 'Identify and connect with exhibition leads via LinkedIn Sales Navigator.',
            icon: Globe,
            status: 'Planned'
        }
    ];

    return (
        <AppShell>
            <div className="max-w-5xl mx-auto py-8">
                {/* Hero Section */}
                <div className="mb-16">
                    <div className="flex items-center gap-3 mb-4">
                        <div className="p-2 bg-stone-900 text-white rounded-lg">
                            <Plug2 className="w-5 h-5" />
                        </div>
                        <span className="text-xs font-black uppercase tracking-widest text-stone-400">Integrations</span>
                    </div>
                    <h1 className="text-4xl font-black text-stone-900 tracking-tight leading-tight mb-4">
                        Extend your exhibition <br /><span className="text-stone-400 italic font-medium">capabilities.</span>
                    </h1>
                    <p className="text-lg text-stone-500 max-w-xl font-medium leading-relaxed">
                        We're building mission-critical integrations to ensure your exhibition data flows seamlessly into your existing enterprise stack.
                    </p>
                </div>

                {/* Coming Soon Grid */}
                <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6 mb-16">
                    {plannedIntegrations.map((item, index) => (
                        <div
                            key={item.name}
                            className="bg-white rounded-[2rem] border border-stone-100 p-8 group hover:shadow-2xl hover:border-stone-200 transition-all duration-500 relative flex flex-col items-start overflow-hidden"
                        >
                            <div className="absolute -top-12 -right-12 p-6 opacity-[0.02] group-hover:opacity-[0.05] transition-all duration-700 group-hover:scale-125 group-hover:-rotate-12">
                                <item.icon size={160} strokeWidth={1} />
                            </div>

                            <div className="w-14 h-14 bg-stone-900 text-white rounded-2xl flex items-center justify-center mb-8 shadow-xl shadow-stone-900/10 group-hover:scale-110 group-hover:shadow-stone-900/20 transition-all duration-500 ring-4 ring-stone-50">
                                <item.icon className="w-6 h-6" strokeWidth={2.5} />
                            </div>

                            <div className="mt-auto relative z-10">
                                <span className="inline-block text-[10px] font-black uppercase tracking-[0.2em] text-stone-400 mb-3 group-hover:text-stone-900 transition-colors">
                                    Release: {item.status}
                                </span>
                                <h3 className="text-xl font-black text-stone-900 mb-3 tracking-tight">{item.name}</h3>
                                <p className="text-sm text-stone-500 font-medium leading-relaxed italic">
                                    "{item.description}"
                                </p>
                            </div>
                        </div>
                    ))}
                </div>

                {/* Footer Notes */}
                <div className="pt-12 border-t border-stone-100 flex flex-col md:flex-row items-center justify-between gap-6 opacity-60 grayscale hover:grayscale-0 transition-all">
                    <div className="flex items-center gap-8">
                        <div className="flex items-center gap-2 text-stone-900 text-xs font-bold">
                            <Lock className="w-3.5 h-3.5" />
                            <span>Enterprise Security</span>
                        </div>
                        <div className="flex items-center gap-2 text-stone-900 text-xs font-bold">
                            <ShieldCheck className="w-3.5 h-3.5" />
                            <span>GDPR Compliant</span>
                        </div>
                    </div>

                    <div className="flex items-center gap-2 px-3 py-1 bg-stone-100 rounded-full text-[10px] font-bold text-stone-500">
                        <Command className="w-3 h-3" />
                        <span>Integration Mode: Auto-Sync Only</span>
                    </div>
                </div>
            </div>
        </AppShell>
    );
}
