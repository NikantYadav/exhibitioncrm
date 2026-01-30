'use client';

import { AppShell } from '@/components/layout/AppShell';
import { Button } from '@/components/ui/Button';
import {
    Plug,
    Zap,
    ShieldCheck,
    Share2,
    Database,
    Mail,
    MessageSquare,
    Globe,
    Lock
} from 'lucide-react';

export default function IntegrationsPage() {
    const plannedIntegrations = [
        {
            name: 'Salesforce',
            description: 'Sync your exhibition leads directly to your CRM with real-time field mapping.',
            icon: Database,
            color: 'bg-blue-50 text-blue-600',
            status: 'Q3 2026'
        },
        {
            name: 'HubSpot',
            description: 'Automated workflow triggers based on lead capture and interaction notes.',
            icon: Zap,
            color: 'bg-orange-50 text-orange-600',
            status: 'Q3 2026'
        },
        {
            name: 'Zapier',
            description: 'Connect with over 5,000+ apps to automate your exhibition follow-up process.',
            icon: Share2,
            color: 'bg-stone-50 text-stone-900',
            status: 'In Development'
        },
        {
            name: 'Outlook & Gmail',
            description: 'Send follow-up drafts directly from your primary business email account.',
            icon: Mail,
            color: 'bg-indigo-50 text-indigo-600',
            status: 'Q2 2026'
        },
        {
            name: 'Slack',
            description: 'Get real-time team notifications when high-priority leads are captured.',
            icon: MessageSquare,
            color: 'bg-purple-50 text-purple-600',
            status: 'Coming Soon'
        },
        {
            name: 'LinkedIn',
            description: 'Directly connect with captured leads and view enriched profile data.',
            icon: Globe,
            color: 'bg-sky-50 text-sky-600',
            status: 'Planned'
        }
    ];

    return (
        <AppShell>
            <div className="max-w-6xl mx-auto py-12 px-4">
                {/* Hero Section */}
                <div className="text-center mb-20 space-y-6">
                    <div className="inline-flex items-center gap-2 px-4 py-2 bg-indigo-50 text-indigo-700 rounded-full text-sm font-semibold mb-4 animate-in fade-in slide-in-from-top-4 duration-500">
                        <Plug className="w-4 h-4" />
                        <span>Integrations Ecosystem</span>
                    </div>
                    <h1 className="text-5xl md:text-6xl font-black text-stone-900 tracking-tight leading-tight">
                        Power up your <span className="text-indigo-600">workstack.</span>
                    </h1>
                    <p className="text-xl text-stone-500 max-w-2xl mx-auto font-medium">
                        Connect your exhibition captures with the tools you use every day.
                        We're building seamless bridges to your favorite CRMs and productivity apps.
                    </p>
                </div>

                {/* Coming Soon Grid */}
                <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6 mb-20">
                    {plannedIntegrations.map((item, index) => (
                        <div
                            key={item.name}
                            className="premium-card p-8 group hover:border-indigo-200 transition-all duration-300 relative overflow-hidden animate-in fade-in slide-in-from-bottom-8"
                            style={{ animationDelay: `${index * 100}ms`, animationFillMode: 'both' }}
                        >
                            <div className="absolute top-0 right-0 p-4 opacity-5 group-hover:opacity-10 transition-opacity">
                                <item.icon size={80} />
                            </div>

                            <div className={`w-14 h-14 rounded-2xl flex items-center justify-center mb-6 shadow-sm ${item.color}`}>
                                <item.icon className="w-7 h-7" />
                            </div>

                            <span className="inline-block text-[10px] font-black uppercase tracking-widest text-indigo-600 mb-2">
                                {item.status}
                            </span>
                            <h3 className="text-xl font-bold text-stone-900 mb-3">{item.name}</h3>
                            <p className="text-sm text-stone-500 leading-relaxed">
                                {item.description}
                            </p>
                        </div>
                    ))}
                </div>


                {/* Footer Security Note */}
                <div className="mt-12 flex items-center justify-center gap-6 text-stone-400 text-sm font-medium">
                    <div className="flex items-center gap-2">
                        <Lock className="w-4 h-4" />
                        <span>Secure API Connections</span>
                    </div>
                    <div className="w-1 h-1 bg-stone-200 rounded-full" />
                    <div className="flex items-center gap-2">
                        <ShieldCheck className="w-4 h-4" />
                        <span>GDPR Compliant Sync</span>
                    </div>
                </div>
            </div>
        </AppShell>
    );
}
