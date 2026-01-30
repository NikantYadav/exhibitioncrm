'use client';

import { useState, useEffect } from 'react';
import { Input } from '@/components/ui/Input';
import { Textarea } from '@/components/ui/Textarea';
import { Button } from '@/components/ui/Button';
import { Select } from '@/components/ui/Select';
import { getProfile, updateProfile, UserProfile } from '@/app/actions/profile-actions';
import { User, Building2, Briefcase, Save, Loader2, Edit, X, Globe, Mail, Phone, Linkedin } from 'lucide-react';
import { toast } from 'sonner';

export function ProfileSection() {
    const [profile, setProfile] = useState<UserProfile>({
        profile_type: 'company',
        name: '',
        ai_tone: 'professional',
    });
    const [isLoading, setIsLoading] = useState(true);
    const [isSaving, setIsSaving] = useState(false);
    const [isEditing, setIsEditing] = useState(false);
    const [initialProfile, setInitialProfile] = useState<UserProfile | null>(null);

    useEffect(() => {
        loadProfile();
    }, []);

    const loadProfile = async () => {
        setIsLoading(true);
        const result = await getProfile();
        if (result.profile) {
            setProfile(result.profile);
            setInitialProfile(result.profile);
        }
        setIsLoading(false);
    };

    const handleSave = async () => {
        setIsSaving(true);
        const savingToast = toast.loading('Saving profile...');
        const result = await updateProfile(profile);
        if (result.success) {
            toast.success('Profile updated', { id: savingToast });
            setIsEditing(false);
            loadProfile();
        } else {
            toast.error('Failed to save: ' + result.error, { id: savingToast });
        }
        setIsSaving(false);
    };

    const updateField = (field: keyof UserProfile, value: any) => {
        setProfile({ ...profile, [field]: value });
    };

    if (isLoading) {
        return (
            <div className="flex items-center justify-center h-48 premium-card">
                <div className="flex flex-col items-center gap-4">
                    <Loader2 className="h-8 w-8 animate-spin text-stone-400" />
                    <p className="text-stone-500 font-medium text-sm">Loading profile info...</p>
                </div>
            </div>
        );
    }

    return (
        <div className="space-y-8">
            <div className="bg-white rounded-[2.5rem] border border-stone-100 shadow-sm overflow-hidden flex flex-col">
                <div className="px-10 py-8 border-b border-stone-100 bg-stone-50/30 flex items-center justify-between">
                    <div className="flex items-center gap-5">
                        <div className="p-3 bg-stone-900 text-white rounded-2xl shadow-xl shadow-stone-900/10 ring-4 ring-white">
                            <User className="w-5 h-5" strokeWidth={2.5} />
                        </div>
                        <div>
                            <h3 className="text-xl font-black text-stone-900 tracking-tight mb-0.5">Profile Command</h3>
                            <p className="text-[10px] font-black text-stone-400 uppercase tracking-widest italic">Identity Configuration</p>
                        </div>
                    </div>
                    {!isEditing && (
                        <Button
                            variant="outline"
                            size="sm"
                            onClick={() => {
                                setInitialProfile(profile);
                                setIsEditing(true);
                            }}
                            className="rounded-xl px-6 h-10 border-stone-200 hover:bg-stone-900 hover:text-white font-black uppercase tracking-widest text-[10px] transition-all duration-500 shadow-sm"
                        >
                            <Edit className="h-3.5 w-3.5 mr-2" strokeWidth={2.5} />
                            Modify Identity
                        </Button>
                    )}
                </div>

                <div className="p-10">
                    {isEditing ? (
                        <div className="space-y-12">
                            {/* Profile Type */}
                            <div className="space-y-6">
                                <span className="text-[10px] font-black text-stone-400 uppercase tracking-[0.2em]">Deployment Type</span>
                                <div className="grid grid-cols-1 sm:grid-cols-3 gap-6">
                                    {[
                                        { id: 'company', label: 'Company', icon: Building2, desc: 'Enterprise data' },
                                        { id: 'individual', label: 'Individual', icon: User, desc: 'Personal metrics' },
                                        { id: 'employee', label: 'Employee', icon: Briefcase, desc: 'Operator profile' }
                                    ].map((type) => (
                                        <button
                                            key={type.id}
                                            onClick={() => updateField('profile_type', type.id)}
                                            className={`p-6 rounded-[2rem] border-2 transition-all text-left relative overflow-hidden group ${profile.profile_type === type.id
                                                ? 'border-stone-900 bg-stone-900 text-white shadow-[0_20px_40px_rgba(0,0,0,0.1)]'
                                                : 'border-stone-50 bg-stone-50/50 hover:border-stone-200'
                                                }`}
                                        >
                                            <div className={`absolute -top-4 -right-4 p-4 opacity-[0.05] group-hover:scale-125 transition-transform duration-700 ${profile.profile_type === type.id ? 'text-white' : 'text-stone-900'}`}>
                                                <type.icon size={80} strokeWidth={1} />
                                            </div>
                                            <div className={`w-10 h-10 rounded-xl flex items-center justify-center mb-4 transition-all ${profile.profile_type === type.id ? 'bg-white/10 text-white' : 'bg-stone-200 text-stone-500'}`}>
                                                <type.icon className="w-5 h-5" strokeWidth={2.5} />
                                            </div>
                                            <div className="font-black text-sm mb-1 uppercase tracking-tight">{type.label}</div>
                                            <div className={`text-[10px] font-bold ${profile.profile_type === type.id ? 'text-white/40' : 'text-stone-400'}`}>{type.desc}</div>
                                        </button>
                                    ))}
                                </div>
                            </div>

                            {/* Informational Blocks */}
                            <div className="grid grid-cols-1 md:grid-cols-2 gap-10">
                                <div className="space-y-8">
                                    <div className="space-y-6">
                                        <span className="text-[10px] font-black text-stone-400 uppercase tracking-[0.2em]">Core Metadata</span>
                                        <Input
                                            label={profile.profile_type === 'company' ? 'Enterprise Designation' : 'Full Name'}
                                            value={profile.name}
                                            onChange={(e) => updateField('name', e.target.value)}
                                            placeholder="..."
                                            className="h-12 bg-white border-stone-100 rounded-xl shadow-inner focus:shadow-none"
                                        />
                                        <Input
                                            label="Mission Tagline"
                                            value={profile.tagline || ''}
                                            onChange={(e) => updateField('tagline', e.target.value)}
                                            placeholder="Elevator pitch..."
                                            className="h-12 bg-white border-stone-100 rounded-xl shadow-inner focus:shadow-none"
                                        />
                                    </div>

                                    <div className="space-y-6">
                                        <span className="text-[10px] font-black text-stone-400 uppercase tracking-[0.2em]">Value Architecture</span>
                                        <Textarea
                                            label="Strategic Offerings"
                                            rows={4}
                                            value={profile.products_services || ''}
                                            onChange={(e) => updateField('products_services', e.target.value)}
                                            placeholder="What value do you deliver?"
                                            className="bg-white border-stone-100 rounded-2xl p-4 shadow-inner focus:shadow-none"
                                        />
                                        <Textarea
                                            label="Corporate Identity"
                                            rows={4}
                                            value={profile.value_proposition || ''}
                                            onChange={(e) => updateField('value_proposition', e.target.value)}
                                            placeholder="Detailed description..."
                                            className="bg-white border-stone-100 rounded-2xl p-4 shadow-inner focus:shadow-none"
                                        />
                                    </div>
                                </div>

                                <div className="space-y-8">
                                    <div className="space-y-6">
                                        <span className="text-[10px] font-black text-stone-400 uppercase tracking-[0.2em]">Intelligence Parameters</span>
                                        <Select
                                            label="AI Personality Nexus"
                                            value={profile.ai_tone || 'professional'}
                                            onChange={(e) => updateField('ai_tone', e.target.value)}
                                            className="h-12 bg-white border-stone-100 rounded-xl shadow-inner focus:shadow-none"
                                        >
                                            <option value="professional">Professional / Analytical</option>
                                            <option value="casual">Casual / Narrative</option>
                                            <option value="formal">Formal / Institutional</option>
                                            <option value="friendly">Friendly / Collaborative</option>
                                        </Select>
                                        <Textarea
                                            label="Niche Context for AI Synthesis"
                                            rows={6}
                                            value={profile.additional_context || ''}
                                            onChange={(e) => updateField('additional_context', e.target.value)}
                                            placeholder="Industry jargon, secret sauce, specific goals..."
                                            className="bg-white border-stone-100 rounded-2xl p-4 shadow-inner focus:shadow-none"
                                        />
                                    </div>

                                    <div className="space-y-6 pt-4">
                                        <span className="text-[10px] font-black text-stone-400 uppercase tracking-[0.2em]">Cloud Sync Links</span>
                                        <div className="space-y-4">
                                            <Input
                                                label="Global URL"
                                                value={profile.website || ''}
                                                onChange={(e) => updateField('website', e.target.value)}
                                                placeholder="https://..."
                                                className="h-12 bg-white border-stone-100 rounded-xl"
                                            />
                                            <Input
                                                label="LinkedIn Identifier"
                                                value={profile.linkedin_url || ''}
                                                onChange={(e) => updateField('linkedin_url', e.target.value)}
                                                placeholder="Username only..."
                                                className="h-12 bg-white border-stone-100 rounded-xl"
                                            />
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <div className="flex justify-end gap-6 pt-8 border-t border-stone-50">
                                <button
                                    onClick={() => {
                                        if (initialProfile) {
                                            setProfile(initialProfile);
                                        }
                                        setIsEditing(false);
                                    }}
                                    className="text-xs font-black uppercase tracking-widest text-stone-400 hover:text-stone-900 transition-colors"
                                >
                                    Abort
                                </button>
                                <Button
                                    onClick={handleSave}
                                    disabled={isSaving || !profile.name}
                                    className="bg-stone-900 hover:bg-stone-800 text-white px-10 h-12 rounded-xl shadow-xl shadow-stone-900/20 font-black uppercase tracking-widest text-[10px] transition-all active:scale-95"
                                >
                                    {isSaving ? (
                                        <Loader2 className="w-4 h-4 animate-spin mr-2" />
                                    ) : (
                                        <Save className="w-4 h-4 mr-2" strokeWidth={2.5} />
                                    )}
                                    Commit Identity
                                </Button>
                            </div>
                        </div>
                    ) : (
                        <div className="space-y-12 animate-in fade-in duration-700">
                            <div className="space-y-4">
                                <span className="text-[10px] font-black text-stone-400 uppercase tracking-[0.3em]">Identity Profile</span>
                                <h1 className="text-5xl font-black text-stone-900 tracking-tight leading-tight">{profile.name}</h1>
                                <p className="text-xl text-stone-500 font-medium italic leading-relaxed max-w-2xl">
                                    {profile.tagline ? `"${profile.tagline}"` : 'Tactical description not set.'}
                                </p>
                            </div>

                            {/* Unified Info Board */}
                            <div className="bg-white rounded-[2rem] p-10 border border-stone-100 shadow-xl shadow-stone-900/5 relative overflow-hidden group">
                                <div className="absolute top-0 right-0 p-12 opacity-[0.02] group-hover:scale-125 transition-transform duration-1000">
                                    <Globe size={200} strokeWidth={1} />
                                </div>

                                {/* Key Attributes Grid */}
                                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-12 relative z-10">
                                    <div className="space-y-2">
                                        <span className="text-[10px] font-black text-stone-400 uppercase tracking-widest">Industry Cluster</span>
                                        <p className="text-stone-900 font-black text-lg tracking-tight truncate" title={profile.industry || ''}>{profile.industry || 'General'}</p>
                                    </div>
                                    <div className="space-y-2">
                                        <span className="text-[10px] font-black text-stone-400 uppercase tracking-widest">Base Operations</span>
                                        <p className="text-stone-900 font-black text-lg tracking-tight leading-tight">{profile.location || 'Global'}</p>
                                    </div>
                                    <div className="space-y-2">
                                        <span className="text-[10px] font-black text-stone-400 uppercase tracking-widest">Deployment</span>
                                        <div className="flex items-center gap-2">
                                            <div className="w-2.5 h-2.5 rounded-full bg-emerald-500 shadow-[0_0_8px_rgba(16,185,129,0.5)]" />
                                            <p className="text-stone-900 font-black text-lg tracking-tight capitalize">{profile.profile_type}</p>
                                        </div>
                                    </div>
                                    <div className="space-y-2">
                                        <span className="text-[10px] font-black text-stone-400 uppercase tracking-widest">AI Synthesis</span>
                                        <p className="text-stone-900 font-black text-lg tracking-tight capitalize">{profile.ai_tone}</p>
                                    </div>
                                </div>

                                <div className="h-px bg-stone-100 my-10 relative z-10" />

                                {/* Horizontal Contact Row */}
                                <div className="flex flex-wrap items-center gap-x-12 gap-y-8 relative z-10">
                                    {profile.website && (
                                        <div className="flex items-center gap-4 group/item">
                                            <div className="w-10 h-10 bg-stone-900 text-white rounded-xl shadow-lg flex items-center justify-center shrink-0 ring-4 ring-transparent group-hover/item:ring-stone-50 transition-all">
                                                <Globe className="w-4 h-4" strokeWidth={2.5} />
                                            </div>
                                            <a
                                                href={profile.website.startsWith('http') ? profile.website : `https://${profile.website}`}
                                                target="_blank"
                                                rel="noopener noreferrer"
                                                className="text-sm text-stone-900 font-black hover:text-stone-600 transition-colors uppercase tracking-widest border-b-2 border-stone-100 group-hover/item:border-stone-900"
                                            >
                                                {profile.website.replace(/^https?:\/\//, '').replace(/\/$/, '')}
                                            </a>
                                        </div>
                                    )}
                                    <div className="flex items-center gap-4 group/item">
                                        <div className="w-10 h-10 bg-stone-900 text-white rounded-xl shadow-lg flex items-center justify-center shrink-0 ring-4 ring-transparent group-hover/item:ring-stone-50 transition-all">
                                            <Mail className="w-4 h-4" strokeWidth={2.5} />
                                        </div>
                                        <span className="text-sm text-stone-900 font-black uppercase tracking-widest border-b-2 border-transparent">
                                            {profile.email || 'No secure email'}
                                        </span>
                                    </div>
                                    {profile.linkedin_url && (
                                        <div className="flex items-center gap-4 group/item">
                                            <div className="w-10 h-10 bg-stone-900 text-white rounded-xl shadow-lg flex items-center justify-center shrink-0 ring-4 ring-transparent group-hover/item:ring-stone-50 transition-all">
                                                <Linkedin className="w-4 h-4" strokeWidth={2.5} />
                                            </div>
                                            <a
                                                href={profile.linkedin_url.startsWith('http') ? profile.linkedin_url : `https://linkedin.com/in/${profile.linkedin_url}`}
                                                target="_blank"
                                                rel="noopener noreferrer"
                                                className="text-sm text-stone-900 font-black hover:text-stone-600 transition-colors uppercase tracking-widest border-b-2 border-stone-100 group-hover/item:border-stone-900"
                                            >
                                                {profile.linkedin_url.replace(/\/$/, '').split('/').pop()}
                                            </a>
                                        </div>
                                    )}
                                </div>
                            </div>

                            {/* Full Width Text Sections */}
                            <div className="grid grid-cols-1 md:grid-cols-2 gap-16 py-4">
                                <div className="space-y-4">
                                    <span className="text-[10px] font-black text-stone-400 uppercase tracking-[0.2em] flex items-center gap-2">
                                        <div className="w-8 h-px bg-stone-200" />
                                        Narrative
                                    </span>
                                    <p className="text-stone-700 leading-relaxed italic text-lg opacity-90 font-medium">
                                        {profile.value_proposition ? `"${profile.value_proposition}"` : 'No tactical narrative available.'}
                                    </p>
                                </div>
                                <div className="space-y-4">
                                    <span className="text-[10px] font-black text-stone-400 uppercase tracking-[0.2em] flex items-center gap-2">
                                        <div className="w-8 h-px bg-stone-200" />
                                        Strategic Arsenal
                                    </span>
                                    <p className="text-stone-600 leading-relaxed font-bold text-lg">
                                        {profile.products_services || 'No assets configured.'}
                                    </p>
                                </div>
                            </div>
                        </div>
                    )}
                </div>
            </div>
        </div>
    );
}
