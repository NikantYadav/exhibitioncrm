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
        <div className="space-y-6">
            <div className="premium-card overflow-hidden">
                <div className="px-8 py-6 border-b border-stone-100 bg-stone-50/30 flex items-center justify-between">
                    <div className="flex items-center gap-3">
                        <div className="p-2 bg-white rounded-lg shadow-sm border border-stone-100">
                            <User className="w-5 h-5 text-stone-600" />
                        </div>
                        <div>
                            <h3 className="text-section-header">Profile</h3>
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
                            className="rounded-full px-4 border-stone-300 hover:bg-stone-900 hover:text-white transition-all duration-300"
                        >
                            <Edit className="h-4 w-4 mr-2" />
                            Edit Profile
                        </Button>
                    )}
                </div>

                <div className="p-8">
                    {isEditing ? (
                        <div className="space-y-10">
                            {/* Profile Type */}
                            <div className="space-y-4">
                                <span className="text-[10px] font-bold text-stone-400 uppercase tracking-[0.2em]">Profile Type</span>
                                <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                                    {[
                                        { id: 'company', label: 'Company', icon: Building2, desc: 'Corporate details' },
                                        { id: 'individual', label: 'Individual', icon: User, desc: 'Personal branding' },
                                        { id: 'employee', label: 'Employee', icon: Briefcase, desc: 'Work profile' }
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
                                        <span className="text-[10px] font-bold text-stone-400 uppercase tracking-[0.2em]">Basic Info</span>
                                        <Input
                                            label={profile.profile_type === 'company' ? 'Company Name' : 'Full Name'}
                                            value={profile.name}
                                            onChange={(e) => updateField('name', e.target.value)}
                                            placeholder="..."
                                            className="bg-stone-50/50 border-stone-200"
                                        />
                                        <Input
                                            label="Tagline"
                                            value={profile.tagline || ''}
                                            onChange={(e) => updateField('tagline', e.target.value)}
                                            placeholder="A short description..."
                                            className="bg-stone-50/50 border-stone-200"
                                        />
                                    </div>

                                    <div className="space-y-4">
                                        <span className="text-[10px] font-bold text-stone-400 uppercase tracking-[0.2em]">Business Details</span>
                                        <Textarea
                                            label="Products/Services"
                                            rows={4}
                                            value={profile.products_services || ''}
                                            onChange={(e) => updateField('products_services', e.target.value)}
                                            placeholder="What do you offer?"
                                            className="bg-stone-50/50 border-stone-200"
                                        />
                                        <Textarea
                                            label="Who we are"
                                            rows={4}
                                            value={profile.value_proposition || ''}
                                            onChange={(e) => updateField('value_proposition', e.target.value)}
                                            placeholder="A brief description of your company..."
                                            className="bg-stone-50/50 border-stone-200"
                                        />
                                    </div>
                                </div>

                                <div className="space-y-6">
                                    <div className="space-y-4">
                                        <span className="text-[10px] font-bold text-stone-400 uppercase tracking-[0.2em]">AI Tone & Context</span>
                                        <Select
                                            label="AI Voice"
                                            value={profile.ai_tone || 'professional'}
                                            onChange={(e) => updateField('ai_tone', e.target.value)}
                                            className="bg-stone-50/50 border-stone-200"
                                        >
                                            <option value="professional">Professional</option>
                                            <option value="casual">Casual</option>
                                            <option value="formal">Formal</option>
                                            <option value="friendly">Friendly</option>
                                        </Select>
                                        <Textarea
                                            label="Extra context for AI"
                                            rows={6}
                                            value={profile.additional_context || ''}
                                            onChange={(e) => updateField('additional_context', e.target.value)}
                                            placeholder="Anything else for AI to know..."
                                            className="bg-stone-50/50 border-stone-200"
                                        />
                                    </div>

                                    <div className="space-y-4 pt-4">
                                        <span className="text-[10px] font-bold text-stone-400 uppercase tracking-[0.2em]">Contact Links</span>
                                        <div className="space-y-4">
                                            <Input
                                                label="Website"
                                                value={profile.website || ''}
                                                onChange={(e) => updateField('website', e.target.value)}
                                                placeholder="https://..."
                                                className="bg-white border-stone-200 rounded-xl px-4"
                                            />
                                            <Input
                                                label="LinkedIn Username"
                                                value={profile.linkedin_url || ''}
                                                onChange={(e) => updateField('linkedin_url', e.target.value)}
                                                placeholder="e.g. johndoe"
                                                className="bg-white border-stone-200 rounded-xl px-4"
                                            />
                                            <Input
                                                label="Email"
                                                value={profile.email || ''}
                                                onChange={(e) => updateField('email', e.target.value)}
                                                placeholder="example@..."
                                                className="bg-white border-stone-200 rounded-xl px-4"
                                            />
                                        </div>
                                    </div>
                                </div>
                            </div>

                            <div className="flex justify-end gap-3 pt-6 border-t border-stone-100">
                                <Button
                                    variant="ghost"
                                    onClick={() => {
                                        if (initialProfile) {
                                            setProfile(initialProfile);
                                        }
                                        setIsEditing(false);
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
                                    Save Changes
                                </Button>
                            </div>
                        </div>
                    ) : (
                        <div className="space-y-10">
                            <div className="space-y-3">
                                <h4 className="text-[10px] font-bold text-stone-400 uppercase tracking-[0.2em]">Overview</h4>
                                <h1 className="text-4xl font-black text-stone-900 tracking-tight">{profile.name}</h1>
                                <p className="text-xl text-stone-500 font-medium italic leading-relaxed">{profile.tagline || 'No description set'}</p>
                            </div>

                            {/* Unified Info Board */}
                            <div className="bg-stone-50/50 rounded-3xl p-8 border border-stone-200/60 shadow-sm">
                                {/* Key Attributes Grid */}
                                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-8">
                                    <div className="space-y-1">
                                        <span className="text-[10px] font-bold text-stone-400 uppercase tracking-widest">Industry</span>
                                        <p className="text-stone-900 font-bold truncate" title={profile.industry || ''}>{profile.industry || 'Not set'}</p>
                                    </div>
                                    <div className="space-y-1 min-w-0">
                                        <span className="text-[10px] font-bold text-stone-400 uppercase tracking-widest">Location</span>
                                        <p className="text-stone-900 font-bold break-words leading-tight">{profile.location || 'Not set'}</p>
                                    </div>
                                    <div className="space-y-1">
                                        <span className="text-[10px] font-bold text-stone-400 uppercase tracking-widest">Status</span>
                                        <div className="flex items-center gap-2">
                                            <div className="w-2 h-2 rounded-full bg-green-500 shrink-0" />
                                            <p className="text-stone-900 font-bold capitalize truncate">{profile.profile_type}</p>
                                        </div>
                                    </div>
                                    <div className="space-y-1">
                                        <span className="text-[10px] font-bold text-stone-400 uppercase tracking-widest">AI Tone</span>
                                        <p className="text-stone-900 font-bold capitalize truncate">{profile.ai_tone}</p>
                                    </div>
                                </div>

                                <div className="h-px bg-stone-200/80 my-8" />

                                {/* Horizontal Contact Row */}
                                <div className="flex flex-wrap items-center gap-x-12 gap-y-6">
                                    {profile.website && (
                                        <div className="flex items-center gap-3">
                                            <div className="p-1.5 bg-white rounded-lg border border-stone-100 shadow-sm shrink-0">
                                                <Globe className="w-3.5 h-3.5 text-stone-400" />
                                            </div>
                                            <a
                                                href={profile.website.startsWith('http') ? profile.website : `https://${profile.website}`}
                                                target="_blank"
                                                rel="noopener noreferrer"
                                                className="text-sm text-stone-900 font-bold hover:text-indigo-600 underline decoration-stone-200 underline-offset-4 transition-colors"
                                            >
                                                {profile.website.replace(/^https?:\/\//, '')}
                                            </a>
                                        </div>
                                    )}
                                    <div className="flex items-center gap-3">
                                        <div className="p-1.5 bg-white rounded-lg border border-stone-100 shadow-sm shrink-0">
                                            <Mail className="w-3.5 h-3.5 text-stone-400" />
                                        </div>
                                        <span className="text-sm text-stone-900 font-bold whitespace-nowrap">
                                            {profile.email || 'No email'}
                                        </span>
                                    </div>
                                    {profile.phone && (
                                        <div className="flex items-center gap-3">
                                            <div className="p-1.5 bg-white rounded-lg border border-stone-100 shadow-sm shrink-0">
                                                <Phone className="w-3.5 h-3.5 text-stone-400" />
                                            </div>
                                            <span className="text-sm text-stone-900 font-bold whitespace-nowrap">{profile.phone}</span>
                                        </div>
                                    )}
                                    {profile.linkedin_url && (
                                        <div className="flex items-center gap-3">
                                            <div className="p-1.5 bg-white rounded-lg border border-stone-100 shadow-sm shrink-0">
                                                <Linkedin className="w-3.5 h-3.5 text-stone-400" />
                                            </div>
                                            <a
                                                href={profile.linkedin_url.startsWith('http') ? profile.linkedin_url : `https://linkedin.com/in/${profile.linkedin_url}`}
                                                target="_blank"
                                                rel="noopener noreferrer"
                                                className="text-sm text-stone-900 font-bold hover:text-indigo-600 underline decoration-stone-200 underline-offset-4 transition-colors"
                                            >
                                                {profile.linkedin_url.replace(/\/$/, '').split('/').pop() || 'LinkedIn'}
                                            </a>
                                        </div>
                                    )}
                                </div>
                            </div>

                            {/* Full Width Text Sections */}
                            <div className="space-y-12 py-4">
                                <div className="space-y-3">
                                    <span className="text-[10px] font-bold text-stone-400 uppercase tracking-widest">Description</span>
                                    <p className="text-stone-700 leading-relaxed italic text-lg opacity-90">
                                        "{profile.value_proposition || 'Tell your story here.'}"
                                    </p>
                                </div>
                                <div className="space-y-3">
                                    <span className="text-[10px] font-bold text-stone-400 uppercase tracking-widest">Products & Services</span>
                                    <p className="text-stone-700 leading-relaxed font-medium text-lg">
                                        {profile.products_services || 'List your offerings here.'}
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
