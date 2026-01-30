import ExcelJS from 'exceljs';
import Papa from 'papaparse';
import { Contact, Company, Event } from '@/types';

export interface ImportResult<T> {
    data: T[];
    errors: ValidationError[];
    warnings: string[];
}

export interface ValidationError {
    row: number;
    field: string;
    message: string;
}

export class ExcelService {
    /**
     * Export contacts to Excel file
     */
    static async exportContacts(contacts: Contact[]): Promise<Buffer> {
        const workbook = new ExcelJS.Workbook();
        const worksheet = workbook.addWorksheet('Contacts');

        // Define columns
        worksheet.columns = [
            { header: 'First Name', key: 'first_name', width: 15 },
            { header: 'Last Name', key: 'last_name', width: 15 },
            { header: 'Email', key: 'email', width: 30 },
            { header: 'Phone', key: 'phone', width: 15 },
            { header: 'Job Title', key: 'job_title', width: 20 },
            { header: 'Company', key: 'company_name', width: 25 },
            { header: 'LinkedIn', key: 'linkedin_url', width: 40 },
            { header: 'Notes', key: 'notes', width: 50 },
            { header: 'Created Date', key: 'created_at', width: 20 },
        ];

        // Style header row
        worksheet.getRow(1).font = { bold: true };
        worksheet.getRow(1).fill = {
            type: 'pattern',
            pattern: 'solid',
            fgColor: { argb: 'FF4F46E5' },
        };
        worksheet.getRow(1).font = { bold: true, color: { argb: 'FFFFFFFF' } };

        // Add data rows
        contacts.forEach(contact => {
            worksheet.addRow({
                first_name: contact.first_name,
                last_name: contact.last_name || '',
                email: contact.email || '',
                phone: contact.phone || '',
                job_title: contact.job_title || '',
                company_name: contact.company?.name || '',
                linkedin_url: contact.linkedin_url || '',
                notes: contact.notes || '',
                created_at: new Date(contact.created_at).toLocaleDateString(),
            });
        });

        // Generate buffer
        const buffer = await workbook.xlsx.writeBuffer();
        return Buffer.from(buffer);
    }

    /**
     * Export contacts to CSV file
     */
    static exportContactsToCSV(contacts: Contact[]): string {
        const data = contacts.map(contact => ({
            'First Name': contact.first_name,
            'Last Name': contact.last_name || '',
            'Email': contact.email || '',
            'Phone': contact.phone || '',
            'Job Title': contact.job_title || '',
            'Company': contact.company?.name || '',
            'LinkedIn': contact.linkedin_url || '',
            'Notes': contact.notes || '',
            'Created Date': new Date(contact.created_at).toLocaleDateString(),
        }));

        return Papa.unparse(data);
    }

    /**
     * Export companies to Excel file
     */
    static async exportCompanies(companies: Company[]): Promise<Buffer> {
        const workbook = new ExcelJS.Workbook();
        const worksheet = workbook.addWorksheet('Companies');

        // Define columns
        worksheet.columns = [
            { header: 'Company Name', key: 'name', width: 30 },
            { header: 'Website', key: 'website', width: 40 },
            { header: 'Industry', key: 'industry', width: 20 },
            { header: 'Location', key: 'location', width: 25 },
            { header: 'Company Size', key: 'company_size', width: 15 },
            { header: 'Description', key: 'description', width: 50 },
            { header: 'Products/Services', key: 'products_services', width: 50 },
        ];

        // Style header row
        worksheet.getRow(1).font = { bold: true };
        worksheet.getRow(1).fill = {
            type: 'pattern',
            pattern: 'solid',
            fgColor: { argb: 'FF4F46E5' },
        };
        worksheet.getRow(1).font = { bold: true, color: { argb: 'FFFFFFFF' } };

        // Add data rows
        companies.forEach(company => {
            worksheet.addRow({
                name: company.name,
                website: company.website || '',
                industry: company.industry || '',
                location: company.location || '',
                company_size: company.company_size || '',
                description: company.description || '',
                products_services: company.products_services || '',
            });
        });

        const buffer = await workbook.xlsx.writeBuffer();
        return Buffer.from(buffer);
    }

    /**
     * Export companies to CSV file
     */
    static exportCompaniesToCSV(companies: Company[]): string {
        const data = companies.map(company => ({
            'Company Name': company.name,
            'Website': company.website || '',
            'Industry': company.industry || '',
            'Location': company.location || '',
            'Company Size': company.company_size || '',
            'Description': company.description || '',
            'Products/Services': company.products_services || '',
        }));

        return Papa.unparse(data);
    }

    /**
     * Generate Excel template for importing contacts
     */
    static async generateContactTemplate(): Promise<Buffer> {
        const workbook = new ExcelJS.Workbook();
        const worksheet = workbook.addWorksheet('Contact Template');

        worksheet.columns = [
            { header: 'First Name*', key: 'first_name', width: 15 },
            { header: 'Last Name', key: 'last_name', width: 15 },
            { header: 'Email', key: 'email', width: 30 },
            { header: 'Phone', key: 'phone', width: 15 },
            { header: 'Job Title', key: 'job_title', width: 20 },
            { header: 'Company Name', key: 'company_name', width: 25 },
            { header: 'LinkedIn URL', key: 'linkedin_url', width: 40 },
            { header: 'Notes', key: 'notes', width: 50 },
        ];

        // Style header
        worksheet.getRow(1).font = { bold: true };
        worksheet.getRow(1).fill = {
            type: 'pattern',
            pattern: 'solid',
            fgColor: { argb: 'FF4F46E5' },
        };
        worksheet.getRow(1).font = { bold: true, color: { argb: 'FFFFFFFF' } };

        // Add example row
        worksheet.addRow({
            first_name: 'John',
            last_name: 'Doe',
            email: 'john.doe@example.com',
            phone: '+1-555-0100',
            job_title: 'CEO',
            company_name: 'Example Corp',
            linkedin_url: 'https://linkedin.com/in/johndoe',
            notes: 'Met at Tech Conference 2024',
        });

        const buffer = await workbook.xlsx.writeBuffer();
        return Buffer.from(buffer);
    }

    /**
     * Import contacts from Excel file
     */
    static async importContacts(buffer: Buffer): Promise<ImportResult<Partial<Contact>>> {
        const workbook = new ExcelJS.Workbook();
        await workbook.xlsx.load(buffer as any);

        const worksheet = workbook.worksheets[0];
        const contacts: Partial<Contact>[] = [];
        const errors: ValidationError[] = [];
        const warnings: string[] = [];

        worksheet.eachRow((row, rowNumber) => {
            // Skip header row
            if (rowNumber === 1) return;

            const firstName = row.getCell(1).value?.toString().trim();
            const email = row.getCell(3).value?.toString().trim();

            if (!firstName) {
                errors.push({
                    row: rowNumber,
                    field: 'first_name',
                    message: 'First name is required',
                });
                return;
            }

            // Validate email format if provided
            if (email && !this.isValidEmail(email)) {
                warnings.push(`Row ${rowNumber}: Invalid email format - ${email}`);
            }

            const contact: Partial<Contact> = {
                first_name: firstName,
                last_name: row.getCell(2).value?.toString().trim() || undefined,
                email: email || undefined,
                phone: row.getCell(4).value?.toString().trim() || undefined,
                job_title: row.getCell(5).value?.toString().trim() || undefined,
                linkedin_url: row.getCell(7).value?.toString().trim() || undefined,
                notes: row.getCell(8).value?.toString().trim() || undefined,
            };

            contacts.push(contact);
        });

        return { data: contacts, errors, warnings };
    }

    /**
     * Import contacts from CSV file
     */
    static importContactsFromCSV(csvContent: string): ImportResult<Partial<Contact>> {
        const contacts: Partial<Contact>[] = [];
        const errors: ValidationError[] = [];
        const warnings: string[] = [];

        const result = Papa.parse(csvContent, {
            header: true,
            skipEmptyLines: true,
            transformHeader: (header) => header.trim().toLowerCase().replace(/\s+/g, '_'),
        });

        result.data.forEach((row: any, index: number) => {
            const rowNumber = index + 2; // +2 because index is 0-based and we skip header

            const firstName = row.first_name?.trim() || row['first name']?.trim();
            const email = row.email?.trim();

            if (!firstName) {
                errors.push({
                    row: rowNumber,
                    field: 'first_name',
                    message: 'First name is required',
                });
                return;
            }

            // Validate email format if provided
            if (email && !this.isValidEmail(email)) {
                warnings.push(`Row ${rowNumber}: Invalid email format - ${email}`);
            }

            const contact: Partial<Contact> = {
                first_name: firstName,
                last_name: row.last_name?.trim() || row['last name']?.trim() || undefined,
                email: email || undefined,
                phone: row.phone?.trim() || undefined,
                job_title: row.job_title?.trim() || row['job title']?.trim() || undefined,
                linkedin_url: row.linkedin_url?.trim() || row.linkedin?.trim() || undefined,
                notes: row.notes?.trim() || undefined,
            };

            contacts.push(contact);
        });

        return { data: contacts, errors, warnings };
    }

    /**
     * Validate email format
     */
    private static isValidEmail(email: string): boolean {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return emailRegex.test(email);
    }

    /**
     * Export full event data (contacts + companies + interactions)
     */
    static async exportEventData(data: {
        event: Event;
        contacts: Contact[];
        companies: Company[];
    }): Promise<Buffer> {
        const workbook = new ExcelJS.Workbook();

        // Event Info Sheet
        const eventSheet = workbook.addWorksheet('Event Info');
        eventSheet.addRow(['Event Name', data.event.name]);
        eventSheet.addRow(['Location', data.event.location || '']);
        eventSheet.addRow(['Start Date', new Date(data.event.start_date).toLocaleDateString()]);
        eventSheet.addRow(['End Date', data.event.end_date ? new Date(data.event.end_date).toLocaleDateString() : '']);
        eventSheet.addRow(['Type', data.event.event_type]);

        // Contacts Sheet
        const contactsSheet = workbook.addWorksheet('Contacts');
        contactsSheet.columns = [
            { header: 'First Name', key: 'first_name', width: 15 },
            { header: 'Last Name', key: 'last_name', width: 15 },
            { header: 'Email', key: 'email', width: 30 },
            { header: 'Phone', key: 'phone', width: 15 },
            { header: 'Job Title', key: 'job_title', width: 20 },
            { header: 'Company', key: 'company_name', width: 25 },
        ];
        contactsSheet.getRow(1).font = { bold: true };
        data.contacts.forEach(contact => {
            contactsSheet.addRow({
                first_name: contact.first_name,
                last_name: contact.last_name || '',
                email: contact.email || '',
                phone: contact.phone || '',
                job_title: contact.job_title || '',
                company_name: contact.company?.name || '',
            });
        });

        // Companies Sheet
        const companiesSheet = workbook.addWorksheet('Companies');
        companiesSheet.columns = [
            { header: 'Company Name', key: 'name', width: 30 },
            { header: 'Website', key: 'website', width: 40 },
            { header: 'Industry', key: 'industry', width: 20 },
            { header: 'Location', key: 'location', width: 25 },
        ];
        companiesSheet.getRow(1).font = { bold: true };
        data.companies.forEach(company => {
            companiesSheet.addRow({
                name: company.name,
                website: company.website || '',
                industry: company.industry || '',
                location: company.location || '',
            });
        });

        const buffer = await workbook.xlsx.writeBuffer();
        return Buffer.from(buffer);
    }
}
