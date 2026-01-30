'use client';

import { useEffect, useState, useRef } from 'react';
import { useEditor, EditorContent, Editor } from '@tiptap/react';
import StarterKit from '@tiptap/starter-kit';
import Underline from '@tiptap/extension-underline';
import Link from '@tiptap/extension-link';
import Placeholder from '@tiptap/extension-placeholder';
import { Button } from '@/components/ui/Button';
import {
    Bold,
    Italic,
    Underline as UnderlineIcon,
    List,
    ListOrdered,
    Link as LinkIcon,
    Undo,
    Redo,
    Heading1,
    Heading2,
    Check,
    X,
    ExternalLink
} from 'lucide-react';
import { cn } from '@/lib/utils';

interface RichTextEditorProps {
    value: string;
    onChange: (content: string) => void;
    placeholder?: string;
    className?: string;
}

interface LinkPopoverProps {
    editor: Editor;
    isOpen: boolean;
    onClose: () => void;
    position: { top: number; left: number } | null;
}

const LinkPopover = ({ editor, isOpen, onClose, position }: LinkPopoverProps) => {
    const [url, setUrl] = useState('');
    const [isEditing, setIsEditing] = useState(false);
    const inputRef = useRef<HTMLInputElement>(null);
    const popoverRef = useRef<HTMLDivElement>(null);

    useEffect(() => {
        if (isOpen) {
            const currentUrl = editor.getAttributes('link').href || '';
            setUrl(currentUrl);
            setIsEditing(!currentUrl);
            
            // Focus input after a short delay to ensure it's rendered
            setTimeout(() => {
                inputRef.current?.focus();
                if (currentUrl) {
                    inputRef.current?.select();
                }
            }, 100);
        }
    }, [isOpen, editor]);

    useEffect(() => {
        const handleClickOutside = (event: MouseEvent) => {
            if (popoverRef.current && !popoverRef.current.contains(event.target as Node)) {
                onClose();
            }
        };

        if (isOpen) {
            document.addEventListener('mousedown', handleClickOutside);
            return () => document.removeEventListener('mousedown', handleClickOutside);
        }
    }, [isOpen, onClose]);

    const handleApply = () => {
        if (url.trim()) {
            // Add https:// if no protocol is specified
            const finalUrl = url.match(/^https?:\/\//) ? url : `https://${url}`;
            editor.chain().focus().extendMarkRange('link').setLink({ href: finalUrl }).run();
        } else {
            editor.chain().focus().unsetLink().run();
        }
        onClose();
    };

    const handleRemove = () => {
        editor.chain().focus().unsetLink().run();
        onClose();
    };

    const handleKeyDown = (e: React.KeyboardEvent) => {
        if (e.key === 'Enter') {
            e.preventDefault();
            handleApply();
        } else if (e.key === 'Escape') {
            e.preventDefault();
            onClose();
        }
    };

    if (!isOpen || !position) return null;

    const currentUrl = editor.getAttributes('link').href;
    const isValidUrl = url.trim().length > 0;

    return (
        <div
            ref={popoverRef}
            className="fixed z-50 bg-white border border-stone-200 rounded-lg shadow-lg p-3 min-w-[320px] animate-in fade-in zoom-in-95 duration-200"
            style={{
                top: position.top + 10,
                left: Math.max(10, position.left - 160), // Center the popover and ensure it doesn't go off-screen
            }}
        >
            {currentUrl && !isEditing ? (
                // Display mode - show current link
                <div className="space-y-3">
                    <div className="flex items-center gap-2 p-2 bg-stone-50 rounded border">
                        <ExternalLink className="h-4 w-4 text-stone-400 shrink-0" />
                        <a
                            href={currentUrl}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="text-sm text-indigo-600 hover:underline truncate flex-1"
                        >
                            {currentUrl.replace(/^https?:\/\//, '')}
                        </a>
                    </div>
                    <div className="flex gap-2">
                        <Button
                            size="sm"
                            variant="outline"
                            onClick={() => setIsEditing(true)}
                            className="flex-1 text-xs"
                        >
                            Edit
                        </Button>
                        <Button
                            size="sm"
                            variant="outline"
                            onClick={handleRemove}
                            className="flex-1 text-xs text-red-600 hover:text-red-700 hover:bg-red-50"
                        >
                            Remove
                        </Button>
                    </div>
                </div>
            ) : (
                // Edit mode - input for URL
                <div className="space-y-3">
                    <div>
                        <label className="block text-xs font-medium text-stone-700 mb-1">
                            Link URL
                        </label>
                        <input
                            ref={inputRef}
                            type="text"
                            value={url}
                            onChange={(e) => setUrl(e.target.value)}
                            onKeyDown={handleKeyDown}
                            placeholder="Paste link or type to search..."
                            className="w-full px-3 py-2 text-sm border border-stone-200 rounded focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 outline-none"
                        />
                    </div>
                    <div className="flex gap-2">
                        <Button
                            size="sm"
                            onClick={handleApply}
                            disabled={!isValidUrl}
                            className="flex-1 text-xs bg-indigo-600 hover:bg-indigo-700"
                        >
                            <Check className="h-3 w-3 mr-1" />
                            Apply
                        </Button>
                        <Button
                            size="sm"
                            variant="outline"
                            onClick={onClose}
                            className="flex-1 text-xs"
                        >
                            <X className="h-3 w-3 mr-1" />
                            Cancel
                        </Button>
                    </div>
                </div>
            )}
        </div>
    );
};

const MenuBar = ({ editor, onLinkClick }: { editor: Editor | null; onLinkClick: (event: React.MouseEvent) => void }) => {
    if (!editor) return null;

    return (
        <div className="flex flex-wrap items-center gap-0.5 p-1.5 border-b border-stone-100 bg-stone-50/50">
            <button
                onClick={() => editor.chain().focus().toggleBold().run()}
                className={cn(
                    "p-2 rounded-lg hover:bg-white hover:shadow-sm transition-all active:scale-95",
                    editor.isActive('bold') ? "bg-white shadow-sm text-indigo-600 ring-1 ring-stone-200" : "text-stone-500"
                )}
                title="Bold"
            >
                <Bold className="h-3.5 w-3.5" />
            </button>
            <button
                onClick={() => editor.chain().focus().toggleItalic().run()}
                className={cn(
                    "p-2 rounded-lg hover:bg-white hover:shadow-sm transition-all active:scale-95",
                    editor.isActive('italic') ? "bg-white shadow-sm text-indigo-600 ring-1 ring-stone-200" : "text-stone-500"
                )}
                title="Italic"
            >
                <Italic className="h-3.5 w-3.5" />
            </button>
            <button
                onClick={() => editor.chain().focus().toggleUnderline().run()}
                className={cn(
                    "p-2 rounded-lg hover:bg-white hover:shadow-sm transition-all active:scale-95",
                    editor.isActive('underline') ? "bg-white shadow-sm text-indigo-600 ring-1 ring-stone-200" : "text-stone-500"
                )}
                title="Underline"
            >
                <UnderlineIcon className="h-3.5 w-3.5" />
            </button>
            <button
                onClick={() => editor.chain().focus().toggleHeading({ level: 1 }).run()}
                className={cn(
                    "p-2 rounded-lg hover:bg-white hover:shadow-sm transition-all active:scale-95",
                    editor.isActive('heading', { level: 1 }) ? "bg-white shadow-sm text-indigo-600 ring-1 ring-stone-200" : "text-stone-500"
                )}
                title="Heading 1"
            >
                <Heading1 className="h-3.5 w-3.5" />
            </button>
            <button
                onClick={() => editor.chain().focus().toggleHeading({ level: 2 }).run()}
                className={cn(
                    "p-2 rounded-lg hover:bg-white hover:shadow-sm transition-all active:scale-95",
                    editor.isActive('heading', { level: 2 }) ? "bg-white shadow-sm text-indigo-600 ring-1 ring-stone-200" : "text-stone-500"
                )}
                title="Heading 2"
            >
                <Heading2 className="h-3.5 w-3.5" />
            </button>
            <div className="w-px h-4 bg-stone-200 mx-1.5" />
            <button
                onClick={() => editor.chain().focus().toggleBulletList().run()}
                className={cn(
                    "p-2 rounded-lg hover:bg-white hover:shadow-sm transition-all active:scale-95",
                    editor.isActive('bulletList') ? "bg-white shadow-sm text-indigo-600 ring-1 ring-stone-200" : "text-stone-500"
                )}
                title="Bullet List"
            >
                <List className="h-3.5 w-3.5" />
            </button>
            <button
                onClick={() => editor.chain().focus().toggleOrderedList().run()}
                className={cn(
                    "p-2 rounded-lg hover:bg-white hover:shadow-sm transition-all active:scale-95",
                    editor.isActive('orderedList') ? "bg-white shadow-sm text-indigo-600 ring-1 ring-stone-200" : "text-stone-500"
                )}
                title="Ordered List"
            >
                <ListOrdered className="h-3.5 w-3.5" />
            </button>
            <div className="w-px h-4 bg-stone-200 mx-1.5" />
            <button
                onClick={onLinkClick}
                className={cn(
                    "p-2 rounded-lg hover:bg-white hover:shadow-sm transition-all active:scale-95",
                    editor.isActive('link') ? "bg-white shadow-sm text-indigo-600 ring-1 ring-stone-200" : "text-stone-500"
                )}
                title="Link"
            >
                <LinkIcon className="h-3.5 w-3.5" />
            </button>
            <div className="flex-1" />
            <div className="flex items-center gap-1">
                <button
                    onClick={() => editor.chain().focus().undo().run()}
                    disabled={!editor.can().undo()}
                    className="p-2 rounded-lg hover:bg-white hover:shadow-sm text-stone-400 hover:text-stone-600 disabled:opacity-20 transition-all"
                    title="Undo"
                >
                    <Undo className="h-3.5 w-3.5" />
                </button>
                <button
                    onClick={() => editor.chain().focus().redo().run()}
                    disabled={!editor.can().redo()}
                    className="p-2 rounded-lg hover:bg-white hover:shadow-sm text-stone-400 hover:text-stone-600 disabled:opacity-20 transition-all"
                    title="Redo"
                >
                    <Redo className="h-3.5 w-3.5" />
                </button>
            </div>
        </div>
    );
};

export function RichTextEditor({ value, onChange, placeholder, className }: RichTextEditorProps) {
    const [linkPopover, setLinkPopover] = useState<{ isOpen: boolean; position: { top: number; left: number } | null }>({
        isOpen: false,
        position: null
    });

    const editor = useEditor({
        extensions: [
            StarterKit,
            Underline,
            Link.configure({
                openOnClick: false,
                HTMLAttributes: {
                    class: 'text-indigo-600 underline cursor-pointer',
                },
            }),
            Placeholder.configure({
                placeholder: placeholder || 'Start writing...',
            }),
        ],
        content: value,
        editorProps: {
            attributes: {
                class: 'prose prose-sm font-serif max-w-none focus:outline-none min-h-[300px] p-6 text-stone-700 leading-relaxed',
            },
        },
        onUpdate: ({ editor }) => {
            onChange(editor.getHTML());
        },
        immediatelyRender: false,
    });

    // Sync content if value changes externally (e.g. from AI)
    useEffect(() => {
        if (editor && value !== editor.getHTML()) {
            editor.commands.setContent(value);
        }
    }, [value, editor]);

    const handleLinkClick = (event: React.MouseEvent) => {
        if (!editor) return;

        const { from, to } = editor.state.selection;
        const { view } = editor;
        
        // Get the position of the selection
        const start = view.coordsAtPos(from);
        const end = view.coordsAtPos(to);
        
        // Calculate the center position of the selection
        const rect = {
            top: Math.min(start.top, end.top),
            left: (start.left + end.left) / 2,
        };

        setLinkPopover({
            isOpen: true,
            position: rect
        });
    };

    const handleCloseLinkPopover = () => {
        setLinkPopover({ isOpen: false, position: null });
    };

    // Handle keyboard shortcut for links (Cmd/Ctrl + K)
    useEffect(() => {
        const handleKeyDown = (event: KeyboardEvent) => {
            if ((event.metaKey || event.ctrlKey) && event.key === 'k') {
                event.preventDefault();
                if (editor && editor.state.selection.from !== editor.state.selection.to) {
                    // Text is selected, show link popover
                    const { from, to } = editor.state.selection;
                    const { view } = editor;
                    const start = view.coordsAtPos(from);
                    const end = view.coordsAtPos(to);
                    
                    setLinkPopover({
                        isOpen: true,
                        position: {
                            top: Math.min(start.top, end.top),
                            left: (start.left + end.left) / 2,
                        }
                    });
                }
            }
        };

        document.addEventListener('keydown', handleKeyDown);
        return () => document.removeEventListener('keydown', handleKeyDown);
    }, [editor]);

    if (!editor) {
        return (
            <div className={cn("flex flex-col border border-stone-200 rounded-xl overflow-hidden bg-white", className)}>
                <div className="h-12 bg-stone-50/50 border-b border-stone-100 animate-pulse" />
                <div className="flex-1 min-h-[300px] p-6 bg-stone-50/30 animate-pulse" />
            </div>
        );
    }

    return (
        <>
            <div className={cn("flex flex-col border border-stone-200 rounded-xl overflow-hidden bg-white", className)}>
                <MenuBar editor={editor} onLinkClick={handleLinkClick} />
                <div className="overflow-y-auto flex-1">
                    <EditorContent editor={editor} />
                </div>
            </div>
            
            <LinkPopover
                editor={editor}
                isOpen={linkPopover.isOpen}
                onClose={handleCloseLinkPopover}
                position={linkPopover.position}
            />
        </>
    );
}
