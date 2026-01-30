'use client';

import { useState, useEffect } from 'react';
import { AppShell } from '@/components/layout/AppShell';
import { Input } from '@/components/ui/Input';
import { Textarea } from '@/components/ui/Textarea';
import { Button } from '@/components/ui/Button';
import { Select } from '@/components/ui/Select';
import { getProfile, updateProfile, UserProfile } from '@/app/actions/profile-actions';
import { User, Building2, Briefcase, Save, Loader2 } from 'lucide-react';

import { toast } from 'sonner';

export default function ProfilePage() {
    const [profile, setProfile] = useState<UserProfile>({
        profile_type: 'company',
        name: '',
        ai_tone: 'professional',
    });
    const [isLoading, setIsLoading] = useState(true);
    const [isSaving, setIsSaving] = useState(false);

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
        const savingToast = toast.loading('Saving profile...');
        const result = await updateProfile(profile);
        if (result.success) {
            toast.success('Profile saved successfully!', { id: savingToast });
        } else {
            toast.error('Failed to save profile: ' + result.error, { id: savingToast });
        }
        setIsSaving(false);
    };

    const updateField = (field: keyof UserProfile, value: any) => {
        setProfile({ ...profile, [field]: value });
    };

    if (isLoading) {
        return (
            <AppShell>
                <div className="flex items-center justify-center h-64">
                    <Loader2 className="h-8 w-8 animate-spin text-blue-600" />
                </div>
            </AppShell>
        );
    }

    return (
        <AppShell>
            <div className="max-w-4xl mx-auto">
                <div className="mb-8">
                    <h1 className="text-display mb-2">Company Profile</h1>
                    <p className="text-body">
                        Configure your company or personal information to personalize AI-generated content
                    </p>
                </div>

                {/* Profile Type Selector */}
                <div className="premium-card p-6 mb-6">
                    <div className="flex items-center gap-3 mb-6">
                        <div className="p-2 bg-blue-50 rounded-lg">
                            <User className="w-5 h-5 text-blue-600" />
                        </div>
                        <div>
                            <h3 className="text-card-title">Profile Type</h3>
                            <p className="text-caption">Select how you're using this CRM</p>
                        </div>
                    </div>

                    <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                        <button
                            onClick={() => updateField('profile_type', 'company')}
                            className={`p-4 rounded-lg border-2 transition-all ${profile.profile_type === 'company'
                                ? 'border-blue-500 bg-blue-50'
                                : 'border-gray-200 hover:border-gray-300'
                                }`}
                        >
                            <Building2 className="w-6 h-6 mx-auto mb-2 text-blue-600" />
                            <div className="font-medium text-sm">Company</div>
                            <div className="text-xs text-gray-500">Full company details</div>
                        </button>

                        <button
                            onClick={() => updateField('profile_type', 'individual')}
                            className={`p-4 rounded-lg border-2 transition-all ${profile.profile_type === 'individual'
                                ? 'border-blue-500 bg-blue-50'
                                : 'border-gray-200 hover:border-gray-300'
                                }`}
                        >
                            <User className="w-6 h-6 mx-auto mb-2 text-blue-600" />
                            <div className="font-medium text-sm">Individual</div>
                            <div className="text-xs text-gray-500">Personal brand</div>
                        </button>

                        <button
                            onClick={() => updateField('profile_type', 'employee')}
                            className={`p-4 rounded-lg border-2 transition-all ${profile.profile_type === 'employee'
                                ? 'border-blue-500 bg-blue-50'
                                : 'border-gray-200 hover:border-gray-300'
                                }`}
                        >
                            <Briefcase className="w-6 h-6 mx-auto mb-2 text-blue-600" />
                            <div className="font-medium text-sm">Employee</div>
                            <div className="text-xs text-gray-500">Representing a company</div>
                        </button>
                    </div>
                </div>

                {/* Basic Information */}
                <div className="premium-card p-6 mb-6">
                    <h3 className="text-card-title mb-4">Basic Information</h3>
                    <div className="space-y-4">
                        <Input
                            label={profile.profile_type === 'company' ? 'Company Name' : 'Your Name'}
                            value={profile.name}
                            onChange={(e) => updateField('name', e.target.value)}
                            placeholder={profile.profile_type === 'company' ? 'Acme Corporation' : 'John Doe'}
                            required
                        />

                        <Input
                            label="Tagline"
                            value={profile.tagline || ''}
                            onChange={(e) => updateField('tagline', e.target.value)}
                            placeholder="A short, memorable tagline"
                        />

                        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                            <Input
                                label="Industry"
                                value={profile.industry || ''}
                                onChange={(e) => updateField('industry', e.target.value)}
                                placeholder="Technology, Healthcare, etc."
                            />

                            <Input
                                label="Location"
                                value={profile.location || ''}
                                onChange={(e) => updateField('location', e.target.value)}
                                placeholder="San Francisco, CA"
                            />
                        </div>

                        <Input
                            label="Website"
                            type="url"
                            value={profile.website || ''}
                            onChange={(e) => updateField('website', e.target.value)}
                            placeholder="https://example.com"
                        />
                    </div>
                </div>

                {/* Business Details */}
                <div className="premium-card p-6 mb-6">
                    <h3 className="text-card-title mb-4">Business Details</h3>
                    <div className="space-y-4">
                        <Textarea
                            label="Products/Services"
                            rows={3}
                            value={profile.products_services || ''}
                            onChange={(e) => updateField('products_services', e.target.value)}
                            placeholder="Describe what you offer..."
                        />

                        <Textarea
                            label="Value Proposition"
                            rows={3}
                            value={profile.value_proposition || ''}
                            onChange={(e) => updateField('value_proposition', e.target.value)}
                            placeholder="What makes you unique? What problems do you solve?"
                        />

                        <Textarea
                            label="Target Audience"
                            rows={2}
                            value={profile.target_audience || ''}
                            onChange={(e) => updateField('target_audience', e.target.value)}
                            placeholder="Who are your ideal customers?"
                        />

                        <Textarea
                            label="Key Differentiators"
                            rows={2}
                            value={profile.key_differentiators || ''}
                            onChange={(e) => updateField('key_differentiators', e.target.value)}
                            placeholder="What sets you apart from competitors?"
                        />
                    </div>
                </div>

                {/* Company-specific or Employee-specific */}
                {profile.profile_type === 'company' && (
                    <div className="premium-card p-6 mb-6">
                        <h3 className="text-card-title mb-4">Company Details</h3>
                        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                            <Input
                                label="Company Size"
                                value={profile.company_size || ''}
                                onChange={(e) => updateField('company_size', e.target.value)}
                                placeholder="1-10, 11-50, 51-200, etc."
                            />

                            <Input
                                label="Founded Year"
                                type="number"
                                value={profile.founded_year || ''}
                                onChange={(e) => updateField('founded_year', parseInt(e.target.value) || undefined)}
                                placeholder="2020"
                            />
                        </div>
                    </div>
                )}

                {profile.profile_type === 'employee' && (
                    <div className="premium-card p-6 mb-6">
                        <h3 className="text-card-title mb-4">Employment Details</h3>
                        <div className="space-y-4">
                            <Input
                                label="Company You Represent"
                                value={profile.representing_company || ''}
                                onChange={(e) => updateField('representing_company', e.target.value)}
                                placeholder="Acme Corporation"
                            />

                            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                                <Input
                                    label="Your Role"
                                    value={profile.employee_role || ''}
                                    onChange={(e) => updateField('employee_role', e.target.value)}
                                    placeholder="Sales Manager"
                                />

                                <Input
                                    label="Department"
                                    value={profile.employee_department || ''}
                                    onChange={(e) => updateField('employee_department', e.target.value)}
                                    placeholder="Sales"
                                />
                            </div>
                        </div>
                    </div>
                )}

                {/* Contact & Social */}
                <div className="premium-card p-6 mb-6">
                    <h3 className="text-card-title mb-4">Contact & Social Media</h3>
                    <div className="space-y-4">
                        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                            <Input
                                label="Email"
                                type="email"
                                value={profile.email || ''}
                                onChange={(e) => updateField('email', e.target.value)}
                                placeholder="contact@example.com"
                            />

                            <Input
                                label="Phone"
                                type="tel"
                                value={profile.phone || ''}
                                onChange={(e) => updateField('phone', e.target.value)}
                                placeholder="+1 (555) 123-4567"
                            />
                        </div>

                        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                            <Input
                                label="LinkedIn URL"
                                value={profile.linkedin_url || ''}
                                onChange={(e) => updateField('linkedin_url', e.target.value)}
                                placeholder="https://linkedin.com/company/..."
                            />

                            <Input
                                label="Twitter URL"
                                value={profile.twitter_url || ''}
                                onChange={(e) => updateField('twitter_url', e.target.value)}
                                placeholder="https://twitter.com/..."
                            />
                        </div>
                    </div>
                </div>

                {/* AI Settings */}
                <div className="premium-card p-6 mb-6">
                    <h3 className="text-card-title mb-4">AI Settings</h3>
                    <div className="space-y-4">
                        <Select
                            label="AI Tone"
                            value={profile.ai_tone || 'professional'}
                            onChange={(e) => updateField('ai_tone', e.target.value)}
                        >
                            <option value="professional">Professional</option>
                            <option value="casual">Casual</option>
                            <option value="formal">Formal</option>
                            <option value="friendly">Friendly</option>
                        </Select>

                        <Textarea
                            label="Additional Context for AI"
                            rows={4}
                            value={profile.additional_context || ''}
                            onChange={(e) => updateField('additional_context', e.target.value)}
                            placeholder="Any additional information you'd like the AI to know when generating content (e.g., specific terminology, company culture, communication preferences, etc.)"
                        />
                    </div>
                </div>

                {/* Save Button */}
                <div className="flex justify-end gap-3 mb-8">
                    <Button onClick={handleSave} disabled={isSaving || !profile.name}>
                        {isSaving ? (
                            <>
                                <Loader2 className="w-4 h-4 mr-2 animate-spin" />
                                Saving...
                            </>
                        ) : (
                            <>
                                <Save className="w-4 h-4 mr-2" />
                                Save Profile
                            </>
                        )}
                    </Button>
                </div>
            </div>
        </AppShell>
    );
}
