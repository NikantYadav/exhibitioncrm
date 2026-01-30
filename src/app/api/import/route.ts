import { NextRequest, NextResponse } from 'next/server';
import { ExcelService } from '@/lib/services/excel';
import { createClient } from '@/lib/supabase/server';

export async function POST(request: NextRequest) {
    try {
        const supabase = createClient();

        // Check authentication
        const { data: { user }, error: authError } = await supabase.auth.getUser();
        if (authError || !user) {
            return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
        }

        const formData = await request.formData();
        const file = formData.get('file') as File;

        if (!file) {
            return NextResponse.json(
                { error: 'File is required' },
                { status: 400 }
            );
        }

        let importResult;

        // Determine file type and parse accordingly
        if (file.name.endsWith('.csv')) {
            // Parse CSV file
            const text = await file.text();
            importResult = ExcelService.importContactsFromCSV(text);
        } else if (file.name.endsWith('.xlsx') || file.name.endsWith('.xls')) {
            // Parse Excel file
            const bytes = await file.arrayBuffer();
            const buffer = Buffer.from(bytes);
            importResult = await ExcelService.importContacts(buffer);
        } else {
            return NextResponse.json(
                { error: 'Unsupported file type. Please upload .xlsx, .xls, or .csv file' },
                { status: 400 }
            );
        }

        const { data: contacts, errors, warnings } = importResult;

        if (errors.length > 0) {
            return NextResponse.json({
                data: contacts,
                errors,
                warnings,
                message: 'Import completed with errors',
            }, { status: 400 });
        }

        // Save contacts to database
        const savedContacts = [];
        const saveErrors = [];

        for (let i = 0; i < contacts.length; i++) {
            const contact = contacts[i];

            try {
                // Find or create company if company_name exists in the row data
                let company_id = null;
                const companyName = (contact as any).company_name;

                if (companyName) {
                    const { data: existingCompany } = await supabase
                        .from('companies')
                        .select('id')
                        .eq('name', companyName)
                        .single();

                    if (existingCompany) {
                        company_id = existingCompany.id;
                    } else {
                        const { data: newCompany, error: companyError } = await supabase
                            .from('companies')
                            .insert({ name: companyName })
                            .select('id')
                            .single();

                        if (companyError) {
                            console.error('Error creating company:', companyError);
                        } else {
                            company_id = newCompany?.id;
                        }
                    }
                }

                // Remove company_name from contact data as it's not a column
                const { company_name, ...contactData } = contact as any;

                const { data, error } = await supabase
                    .from('contacts')
                    .insert({
                        ...contactData,
                        company_id,
                    })
                    .select()
                    .single();

                if (!error && data) {
                    savedContacts.push(data);
                } else {
                    saveErrors.push(`Row ${i + 2}: ${error?.message || 'Unknown error'}`);
                }
            } catch (error: any) {
                saveErrors.push(`Row ${i + 2}: ${error.message}`);
            }
        }

        return NextResponse.json({
            data: savedContacts,
            imported: savedContacts.length,
            total: contacts.length,
            errors: saveErrors,
            warnings,
            message: `Successfully imported ${savedContacts.length} of ${contacts.length} contacts`,
        });
    } catch (error) {
        console.error('Import error:', error);
        return NextResponse.json(
            { error: 'Failed to import contacts' },
            { status: 500 }
        );
    }
}
