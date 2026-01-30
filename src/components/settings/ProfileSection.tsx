'use client';

import { useState, useEffect } from 'react';
import { Input } from '@/components/ui/Input';
import { Textarea } from '@/components/ui/Textarea';
import { Button } from '@/components/ui/Button';
import { Select } from '@/components/ui/Select';
import { getProfile, updateProfile, UserProfile } from '@/app/actions/profile-actions';
import { User, Building2, Briefcase, Save, Loader2, Edit, X, Globe, Mail, Phone, Linkedin, Twitter } from 'lucide-react';
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

    useEffect(() => {
        loadProfile();
    }, []);

    const loadProfile = async () => {
        setIsLoading(true);
        const result = await getProfile();
        if (result.profile) {
            setProfile(result.profile);
        }
        setIsLoading(false);
    };

    const handleSave = async () => {
        setIsSaving(true);
        const savingToast = toast.loading('Syncing profile archives...');
        const result = await updateProfile(profile);
        if (result.success) {
            toast.success('Identity verified and updated', { id: savingToast });
            setIsEditing(false);
            loadProfile();
        } else {
            toast.error('Sync failed: ' + result.error, { id: savingToast });
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
                    <p className="text-stone-500 font-medium text-sm">Accessing Identity Archives...</p>
                </div>
            </div>
        );
    }

    return (
        <div className="space-y-6">
            <div className="premium-card overflow-hidden">
                <div className="px-8 py-6 border-b border-stone-100 bg-stone-50/30 flex items-center justify-between">
                    <div className="flex items-center gap-3">
                        <div className="p-2 bg-white rounded-lg shadow-sm border border-stone-100">
                            <User className="w-5 h-5 text-stone-600" />
                        </div>
                        <div>
                            <h3 className="text-section-header">Corporate Identity</h3>
                            <p className="text-[10px] font-bold text-stone-400 uppercase tracking-widest">Base context for AI synthesis</p>
                        </div>
                    </div>
                    {!isEditing && (
                        <Button
                            variant="outline"
                            size="sm"
                            onClick={() => setIsEditing(true)}
                            className="rounded-full px-4 border-stone-300 hover:bg-stone-900 hover:text-white transition-all duration-300"
                        >
                            <Edit className="h-4 w-4 mr-2" />
                            Refine Profile
                        </Button>
                    )}
                </div>

                <div className="p-8">
                    {isEditing ? (
                        <div className="space-y-10">
                            {/* Profile Type */}
                            <div className="space-y-4">
                                <span className="text-[10px] font-bold text-stone-400 uppercase tracking-[0.2em]">Deployment Type</span>
                                <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                                    {[
                                        { id: 'company', label: 'Enterprise', icon: Building2, desc: 'Corporate details' },
                                        { id: 'individual', label: 'Executive', icon: User, desc: 'Personal branding' },
                                        { id: 'employee', label: 'Associate', icon: Briefcase, desc: 'Representing entity' }
                                    ].map((type) => (
                                        <button
                                            key={type.id}
                                            onClick={() => updateField('profile_type', type.id)}
                                            className={`p-5 rounded-2xl border-2 transition-all text-left group ${profile.profile_type === type.id
                                                ? 'border-stone-900 bg-stone-900 text-white shadow-xl shadow-stone-200'
                                                : 'border-stone-100 bg-stone-50/50 hover:border-stone-300'
                                                }`}
                                        >
                                            <type.icon className={`w-6 h-6 mb-3 ${profile.profile_type === type.id ? 'text-white' : 'text-stone-400 group-hover:text-stone-900'}`} />
                                            <div className="font-bold text-sm mb-1">{type.label}</div>
                                            <div className={`text-[10px] ${profile.profile_type === type.id ? 'text-stone-400' : 'text-stone-400'}`}>{type.desc}</div>
                                        </button>
                                    ))}
                                </div>
                            </div>

                            {/* Informational Blocks */}
                            <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
                                <div className="space-y-6">
                                    <div className="space-y-4">
                                        <span className="text-[10px] font-bold text-stone-400 uppercase tracking-[0.2em]">Essential Data</span>
                                        <Input
                                            label={profile.profile_type === 'company' ? 'Legal Entity Name' : 'Full Name'}
                                            value={profile.name}
                                            onChange={(e) => updateField('name', e.target.value)}
                                            placeholder="..."
                                            className="bg-stone-50/50 border-stone-200"
                                        />
                                        <Input
                                            label="Public Tagline"
                                            value={profile.tagline || ''}
                                            onChange={(e) => updateField('tagline', e.target.value)}
                                            placeholder="Elevator pitch..."
                                            className="bg-stone-50/50 border-stone-200"
                                        />
                                    </div>

                                    <div className="space-y-4">
                                        <span className="text-[10px] font-bold text-stone-400 uppercase tracking-[0.2em]">Strategy & Value</span>
                                        <Textarea
                                            label="Products/Services"
                                            rows={4}
                                            value={profile.products_services || ''}
                                            onChange={(e) => updateField('products_services', e.target.value)}
                                            placeholder="What do you offer?"
                                            className="bg-stone-50/50 border-stone-200"
                                        />
                                        <Textarea
                                            label="Value Proposition"
                                            rows={4}
                                            value={profile.value_proposition || ''}
                                            onChange={(e) => updateField('value_proposition', e.target.value)}
                                            placeholder="Why you?"
                                            className="bg-stone-50/50 border-stone-200"
                                        />
                                    </div>
                                </div>

                                <div className="space-y-6">
                                    <div className="space-y-4">
                                        <span className="text-[10px] font-bold text-stone-400 uppercase tracking-[0.2em]">AI Intelligence Tuning</span>
                                        <Select
                                            label="AI Persona Tone"
                                            value={profile.ai_tone || 'professional'}
                                            onChange={(e) => updateField('ai_tone', e.target.value)}
                                            className="bg-stone-50/50 border-stone-200"
                                        >
                                            <option value="professional">Architect (Professional)</option>
                                            <option value="casual">Collaborator (Casual)</option>
                                            <option value="formal">Ambassador (Formal)</option>
                                            <option value="friendly">Guide (Friendly)</option>
                                        </Select>
                                        <Textarea
                                            label="Advanced AI Context"
                                            rows={6}
                                            value={profile.additional_context || ''}
                                            onChange={(e) => updateField('additional_context', e.target.value)}
                                            placeholder="Deep context for AI synthesis..."
                                            className="bg-stone-50/50 border-stone-200"
                                        />
                                    </div>

                                    <div className="space-y-4 pt-4">
                                        <span className="text-[10px] font-bold text-stone-400 uppercase tracking-[0.2em]">Public Channels</span>
                                        <div className="grid grid-cols-2 gap-4">
                                            <Input
                                                label="Website"
                                                value={profile.website || ''}
                                                onChange={(e) => updateField('website', e.target.value)}
                                                placeholder="https://..."
                                                className="bg-stone-50/50 border-stone-200"
                                            />
                                            <Input
                                                label="LinkedIn"
                                                value={profile.linkedin_url || ''}
                                                onChange={(e) => updateField('linkedin_url', e.target.value)}
                                                placeholder="Profile URL"
                                                className="bg-stone-50/50 border-stone-200"
                                            />
                                            <Input
                                                label="X (Twitter)"
                                                value={profile.twitter_url || ''}
                                                onChange={(e) => updateField('twitter_url', e.target.value)}
                                                placeholder="Handle or URL"
                                                className="bg-stone-50/50 border-stone-200"
                                            />
                                            <Input
                                                label="Email"
                                                value={profile.email || ''}
                                                onChange={(e) => updateField('email', e.target.value)}
                                                placeholder="contact@..."
                                                className="bg-stone-50/50 border-stone-200"
                                            />
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <div className="flex justify-end gap-3 pt-6 border-t border-stone-100">
                                <Button
                                    variant="ghost"
                                    onClick={() => {
                                        setIsEditing(false);
                                        loadProfile();
                                    }}
                                    className="text-stone-500 hover:text-stone-900"
                                >
                                    Cancel
                                </Button>
                                <Button
                                    onClick={handleSave}
                                    disabled={isSaving || !profile.name}
                                    className="bg-stone-900 hover:bg-black text-white px-8 rounded-full shadow-lg shadow-stone-200"
                                >
                                    {isSaving ? (
                                        <Loader2 className="w-4 h-4 animate-spin mr-2" />
                                    ) : (
                                        <Save className="w-4 h-4 mr-2" />
                                    )}
                                    Verify Changes
                                </Button>
                            </div>
                        </div>
                    ) : (
                        <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
                            <div className="md:col-span-2 space-y-10">
                                <div className="space-y-2">
                                    <h4 className="text-[10px] font-bold text-stone-400 uppercase tracking-[0.2em]">Profile Overview</h4>
                                    <h1 className="text-4xl font-bold text-stone-900">{profile.name}</h1>
                                    <p className="text-xl text-stone-500 font-medium italic">{profile.tagline || 'No tagline set'}</p>
                                </div>

                                <div className="grid grid-cols-1 sm:grid-cols-2 gap-8 pt-6 border-t border-stone-100">
                                    <div className="space-y-4">
                                        <div className="space-y-1">
                                            <span className="text-[10px] font-bold text-stone-400 uppercase tracking-widest">Industry</span>
                                            <p className="text-stone-800 font-semibold">{profile.industry || 'Not specified'}</p>
                                        </div>
                                        <div className="space-y-1">
                                            <span className="text-[10px] font-bold text-stone-400 uppercase tracking-widest">Global Location</span>
                                            <p className="text-stone-800 font-semibold">{profile.location || 'Not specified'}</p>
                                        </div>
                                    </div>
                                    <div className="space-y-4">
                                        <div className="space-y-1">
                                            <span className="text-[10px] font-bold text-stone-400 uppercase tracking-widest">Profile Status</span>
                                            <div className="flex items-center gap-2">
                                                <div className="w-2 h-2 rounded-full bg-green-500" />
                                                <p className="text-stone-800 font-semibold capitalize">{profile.profile_type} Active</p>
                                            </div>
                                        </div>
                                        <div className="space-y-1">
                                            <span className="text-[10px] font-bold text-stone-400 uppercase tracking-widest">AI Tone Tuning</span>
                                            <p className="text-stone-800 font-semibold capitalize">{profile.ai_tone}</p>
                                        </div>
                                    </div>
                                </div>

                                <div className="space-y-6 pt-6 border-t border-stone-100">
                                    <div className="space-y-3">
                                        <span className="text-[10px] font-bold text-stone-400 uppercase tracking-widest">Value Proposition</span>
                                        <p className="text-stone-700 leading-relaxed italic pr-12">
                                            "{profile.value_proposition || 'Define your value to help AI understand your core mission.'}"
                                        </p>
                                    </div>
                                </div>
                            </div>

                            <div className="space-y-8">
                                <div className="premium-card bg-stone-50/50 p-6 space-y-4 border-none shadow-none">
                                    <h4 className="text-[10px] font-bold text-stone-400 uppercase tracking-widest">Public Channels</h4>
                                    <div className="space-y-4">
                                        {[
                                            { icon: Globe, val: profile.website, label: 'Website' },
                                            { icon: Mail, val: profile.email, label: 'Email' },
                                            { icon: Phone, val: profile.phone, label: 'Phone' },
                                            { icon: Linkedin, val: profile.linkedin_url, label: 'LinkedIn' },
                                            { icon: Twitter, val: profile.twitter_url, label: 'X' }
                                        ].map((item, i) => (
                                            <div key={i} className="flex items-center gap-3">
                                                <item.icon className="w-4 h-4 text-stone-400" />
                                                <span className={`text-sm ${item.val ? 'text-stone-900 font-medium' : 'text-stone-300 italic'}`}>
                                                    {item.val || `${item.label} not set`}
                                                </span>
                                            </div>
                                        ))}
                                    </div>
                                </div>

                                <div className="bg-stone-900 rounded-3xl p-6 text-white space-y-3">
                                    <h4 className="text-[10px] font-bold text-stone-600 uppercase tracking-widest">AI Deployment</h4>
                                    <p className="text-xs text-stone-400 leading-relaxed">
                                        Your identity archives are currently accessible by AI for deep context synthesis.
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
