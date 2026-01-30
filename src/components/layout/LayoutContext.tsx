'use client';

import React, { createContext, useContext, useState, useEffect } from 'react';

interface LayoutContextType {
    isSidebarCollapsed: boolean;
    setSidebarCollapsed: (collapsed: boolean) => void;
    toggleSidebar: () => void;
}

const LayoutContext = createContext<LayoutContextType | undefined>(undefined);

export function LayoutProvider({ children }: { children: React.ReactNode }) {
    const [isSidebarCollapsed, setSidebarCollapsedState] = useState(false);
    const [isInitialized, setIsInitialized] = useState(false);

    useEffect(() => {
        const saved = localStorage.getItem('sidebar-collapsed');
        if (saved !== null) {
            setSidebarCollapsedState(saved === 'true');
        }
        setIsInitialized(true);
    }, []);

    const setSidebarCollapsed = (collapsed: boolean) => {
        setSidebarCollapsedState(collapsed);
        localStorage.setItem('sidebar-collapsed', String(collapsed));
    };

    const toggleSidebar = () => {
        const newState = !isSidebarCollapsed;
        setSidebarCollapsedState(newState);
        localStorage.setItem('sidebar-collapsed', String(newState));
    };

    return (
        <LayoutContext.Provider value={{ isSidebarCollapsed, setSidebarCollapsed, toggleSidebar }}>
            <div className={isInitialized ? 'animate-in fade-in duration-300' : 'opacity-0'}>
                {children}
            </div>
        </LayoutContext.Provider>
    );
}

export function useSidebar() {
    const context = useContext(LayoutContext);
    if (context === undefined) {
        throw new Error('useSidebar must be used within a LayoutProvider');
    }
    return context;
}
