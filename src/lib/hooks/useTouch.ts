'use client';

import { useState, useEffect, useRef, TouchEvent } from 'react';

export interface SwipeDirection {
    direction: 'left' | 'right' | 'up' | 'down';
    distance: number;
}

export function useTouch() {
    const [touchStart, setTouchStart] = useState<{ x: number; y: number } | null>(null);
    const [touchEnd, setTouchEnd] = useState<{ x: number; y: number } | null>(null);
    const longPressTimer = useRef<NodeJS.Timeout | null>(null);

    const minSwipeDistance = 50;

    const onTouchStart = (e: TouchEvent) => {
        setTouchEnd(null);
        setTouchStart({
            x: e.targetTouches[0].clientX,
            y: e.targetTouches[0].clientY,
        });
    };

    const onTouchMove = (e: TouchEvent) => {
        setTouchEnd({
            x: e.targetTouches[0].clientX,
            y: e.targetTouches[0].clientY,
        });
    };

    const onTouchEnd = (): SwipeDirection | null => {
        if (!touchStart || !touchEnd) return null;

        const distanceX = touchStart.x - touchEnd.x;
        const distanceY = touchStart.y - touchEnd.y;
        const isHorizontalSwipe = Math.abs(distanceX) > Math.abs(distanceY);

        if (isHorizontalSwipe) {
            if (Math.abs(distanceX) > minSwipeDistance) {
                return {
                    direction: distanceX > 0 ? 'left' : 'right',
                    distance: Math.abs(distanceX),
                };
            }
        } else {
            if (Math.abs(distanceY) > minSwipeDistance) {
                return {
                    direction: distanceY > 0 ? 'up' : 'down',
                    distance: Math.abs(distanceY),
                };
            }
        }

        return null;
    };

    const onLongPressStart = (callback: () => void, delay: number = 500) => {
        longPressTimer.current = setTimeout(callback, delay);
    };

    const onLongPressEnd = () => {
        if (longPressTimer.current) {
            clearTimeout(longPressTimer.current);
            longPressTimer.current = null;
        }
    };

    useEffect(() => {
        return () => {
            if (longPressTimer.current) {
                clearTimeout(longPressTimer.current);
            }
        };
    }, []);

    return {
        onTouchStart,
        onTouchMove,
        onTouchEnd,
        onLongPressStart,
        onLongPressEnd,
    };
}
